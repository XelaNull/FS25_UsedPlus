--[[
    FS25_UsedPlus - Shop Config Screen Extension

    Extends game's shop screen with Unified Purchase Dialog
    Single "Buy Options" button opens unified dialog for Cash/Finance/Lease
    Pattern from: BuyUsedEquipment (working reference mod)
    Uses button cloning and setStoreItem hook

    Also adds "Inspect" button for owned vehicles to view maintenance/reliability data
]]

ShopConfigScreenExtension = {}

-- Dialog loading now handled by DialogLoader utility

-- Store current item for shop hooks
ShopConfigScreenExtension.currentStoreItem = nil
ShopConfigScreenExtension.currentShopScreen = nil
ShopConfigScreenExtension.currentVehicle = nil  -- Set when viewing owned vehicle

--[[
    Hook callback for shop item selection
    This hook fires every time player selects/views an item in shop
    NEW: Intercepts Buy and Lease buttons to open UnifiedPurchaseDialog
]]
function ShopConfigScreenExtension.setStoreItemHook(self, superFunc, storeItem, ...)
    UsedPlus.logDebug(string.format("ShopConfigScreenExtension.setStoreItemHook called - storeItem: %s",
        tostring(storeItem and storeItem.name or "nil")))

    -- Call original function first and capture return value
    local result = superFunc(self, storeItem, ...)

    -- Wrap our customizations in pcall to prevent breaking the shop if something errors
    local success, err = pcall(function()
        ShopConfigScreenExtension.applyCustomizations(self, storeItem)
    end)

    if not success then
        UsedPlus.logError("ShopConfigScreenExtension error: " .. tostring(err))
    end

    -- Return original function's result to maintain shop flow
    UsedPlus.logDebug("ShopConfigScreenExtension.setStoreItemHook completed successfully")
    return result
end

--[[
    Apply our customizations (separated to allow pcall wrapping)
]]
function ShopConfigScreenExtension.applyCustomizations(self, storeItem)
    local buyButton = self.buyButton

    -- Store reference for any potential future use
    ShopConfigScreenExtension.currentStoreItem = storeItem
    ShopConfigScreenExtension.currentShopScreen = self

    -- Override the game's Buy button to open our UnifiedPurchaseDialog
    if buyButton and ShopConfigScreenExtension.canFinanceItem(storeItem) then
        -- Store original callback on first run
        if not self.usedPlusOriginalBuyCallback then
            self.usedPlusOriginalBuyCallback = buyButton.onClickCallback
        end
        -- Override callback to show our unified dialog (default to Cash mode)
        buyButton.onClickCallback = function()
            ShopConfigScreenExtension.onUnifiedBuyClick(self, storeItem, UnifiedPurchaseDialog.MODE_CASH)
        end
    end

    -- Override the game's Lease button to open our UnifiedPurchaseDialog
    if self.leaseButton then
        -- Store original callback on first run
        if not self.usedPlusOriginalLeaseCallback then
            self.usedPlusOriginalLeaseCallback = self.leaseButton.onClickCallback
        end
        -- Override callback to show our unified dialog in Lease mode
        self.leaseButton.onClickCallback = function()
            if ShopConfigScreenExtension.canLeaseItem(storeItem) then
                ShopConfigScreenExtension.onUnifiedBuyClick(self, storeItem, UnifiedPurchaseDialog.MODE_LEASE)
            elseif self.usedPlusOriginalLeaseCallback then
                -- Fallback to original if we can't handle it
                self.usedPlusOriginalLeaseCallback()
            end
        end
    end

    -- Create Search Used button
    if not self.usedPlusSearchButton and buyButton then
        local parent = buyButton.parent

        -- Log what the Buy button uses for reference
        UsedPlus.logDebug(string.format("Buy button inputActionName: %s", tostring(buyButton.inputActionName)))

        self.usedPlusSearchButton = buyButton:clone(parent)
        self.usedPlusSearchButton.name = "usedPlusSearchButton"
        self.usedPlusSearchButton.inputActionName = "MENU_EXTRA_1"

        -- Try to reorder: move our button to appear just before Buy button
        -- The keybind bar might show buttons in element order
        if parent and parent.elements then
            -- Find and remove our button from its current position
            for i = #parent.elements, 1, -1 do
                if parent.elements[i] == self.usedPlusSearchButton then
                    table.remove(parent.elements, i)
                    break
                end
            end

            -- Find Buy button position and insert just before it
            local buyIndex = nil
            for i, elem in ipairs(parent.elements) do
                if elem == buyButton then
                    buyIndex = i
                    break
                end
            end

            if buyIndex then
                -- Insert AFTER Buy in array (display is reversed, so this appears BEFORE Buy)
                table.insert(parent.elements, buyIndex + 1, self.usedPlusSearchButton)
                UsedPlus.logDebug(string.format("Inserted Search Used at index %d (after Buy in array)", buyIndex + 1))
            else
                -- Fallback: add to end
                table.insert(parent.elements, self.usedPlusSearchButton)
                UsedPlus.logDebug("Added Search Used to end of elements")
            end
        end

        UsedPlus.logDebug("Search Used button created with inputActionName: MENU_EXTRA_1")
    end

    -- Update Search Used callback EVERY TIME setStoreItem is called
    if self.usedPlusSearchButton then
        self.usedPlusSearchButton.onClickCallback = function()
            ShopConfigScreenExtension.onSearchClick(self, storeItem)
        end
        self.usedPlusSearchButton:setText(g_i18n:getText("usedplus_button_searchUsed"))
        local canSearch = ShopConfigScreenExtension.canSearchItem(storeItem)
        self.usedPlusSearchButton:setDisabled(not canSearch)
        self.usedPlusSearchButton:setVisible(canSearch)
    end

    -- Create Inspect button for owned vehicles (maintenance report)
    if not self.usedPlusInspectButton and buyButton then
        local parent = buyButton.parent
        self.usedPlusInspectButton = buyButton:clone(parent)
        self.usedPlusInspectButton.name = "usedPlusInspectButton"
        self.usedPlusInspectButton.inputActionName = "MENU_EXTRA_1"  -- Q key typically
        self.usedPlusInspectButton:setText("Inspect")
        self.usedPlusInspectButton:setVisible(false)  -- Hidden by default, shown for owned vehicles

        UsedPlus.logDebug("Inspect button created in shop")
    end
end

--[[
    Install hooks at load time with safety check
    ShopConfigScreen should exist when mods load
]]
if ShopConfigScreen ~= nil and ShopConfigScreen.setStoreItem ~= nil then
    ShopConfigScreen.setStoreItem = Utils.overwrittenFunction(
        ShopConfigScreen.setStoreItem,
        ShopConfigScreenExtension.setStoreItemHook
    )
    UsedPlus.logDebug("ShopConfigScreenExtension setStoreItem hook installed")
else
    UsedPlus.logWarn("ShopConfigScreen not available at load time")
end

--[[
    Hook updateButtons to show/hide Inspect button for owned vehicles
    updateButtons(storeItem, vehicle, saleItem) - vehicle is set when viewing owned vehicle
]]
function ShopConfigScreenExtension.updateButtonsHook(self, storeItem, vehicle, saleItem)
    -- Wrap in pcall to prevent breaking the shop if something errors
    local success, err = pcall(function()
        -- Store current vehicle for inspect handler
        ShopConfigScreenExtension.currentVehicle = vehicle

        -- Show/hide Inspect button based on whether this is an owned vehicle
        if self.usedPlusInspectButton then
            local isOwnedVehicle = vehicle ~= nil
            self.usedPlusInspectButton:setVisible(isOwnedVehicle)

            if isOwnedVehicle then
                -- Set the click callback with the current vehicle
                self.usedPlusInspectButton.onClickCallback = function()
                    ShopConfigScreenExtension.onInspectClick(self, vehicle)
                end
                local vehicleName = vehicle.getName and vehicle:getName() or "Unknown"
                UsedPlus.logDebug("Inspect button shown for owned vehicle: " .. tostring(vehicleName))
            end
        end

        -- Hide Search Used button for owned vehicles (can't search for something you own)
        if self.usedPlusSearchButton then
            local isNewItem = vehicle == nil and saleItem == nil
            self.usedPlusSearchButton:setVisible(isNewItem and ShopConfigScreenExtension.canSearchItem(storeItem))
        end
    end)

    if not success then
        UsedPlus.logError("ShopConfigScreenExtension updateButtons error: " .. tostring(err))
    end
end

if ShopConfigScreen ~= nil and ShopConfigScreen.updateButtons ~= nil then
    ShopConfigScreen.updateButtons = Utils.appendedFunction(
        ShopConfigScreen.updateButtons,
        ShopConfigScreenExtension.updateButtonsHook
    )
    UsedPlus.logDebug("ShopConfigScreenExtension updateButtons hook installed")
end

--[[
    Note on UnifiedPurchaseDialog approach
    We intercept both Buy and Lease buttons to open our UnifiedPurchaseDialog.
    This provides a unified experience with Cash/Finance/Lease modes in one dialog.
    Trade-In is integrated into the UnifiedPurchaseDialog for all purchase modes.
]]

--[[
    Item qualification functions
]]
function ShopConfigScreenExtension.canFinanceItem(storeItem)
    if storeItem == nil then
        return false
    end

    -- Can finance vehicles and placeables
    local isVehicle = storeItem.species == StoreSpecies.VEHICLE
    local isPlaceable = storeItem.categoryName == "PLACEABLES"

    return isVehicle or isPlaceable
end

function ShopConfigScreenExtension.canSearchItem(storeItem)
    if storeItem == nil then
        return false
    end

    -- Can only search for vehicles
    return storeItem.species == StoreSpecies.VEHICLE
end

--[[
    Can this item be leased?
    Leasing is vehicles only (not land, not placeables)
]]
function ShopConfigScreenExtension.canLeaseItem(storeItem)
    if storeItem == nil then
        return false
    end

    -- Can only lease vehicles (not placeables or land)
    return storeItem.species == StoreSpecies.VEHICLE
end

--[[
    Check if player has any vehicles to trade in
]]
function ShopConfigScreenExtension.canTradeInForItem(storeItem)
    if storeItem == nil then
        return false
    end

    -- Can only trade in for vehicle purchases
    if storeItem.species ~= StoreSpecies.VEHICLE then
        return false
    end

    -- Check if player has any eligible vehicles
    if TradeInCalculations then
        local farmId = g_currentMission:getFarmId()
        local eligible = TradeInCalculations.getEligibleVehicles(farmId)
        return #eligible > 0
    end

    return false
end

--[[
    Get current configurations from shop screen
    Returns table of configName -> selectedIndex
]]
function ShopConfigScreenExtension.getCurrentConfigurations(shopScreen)
    local configurations = {}

    -- Try multiple methods to get configurations
    -- Method 1: shopScreen.configurations (direct property)
    if shopScreen and shopScreen.configurations and type(shopScreen.configurations) == "table" then
        for configKey, selectedIndex in pairs(shopScreen.configurations) do
            if type(selectedIndex) == "number" then
                configurations[configKey] = selectedIndex
            end
        end
        if next(configurations) then
            UsedPlus.logTrace("Got configurations from shopScreen.configurations")
        end
    end

    -- Method 2: g_shopConfigScreen.configurations (global)
    if not next(configurations) and g_shopConfigScreen and g_shopConfigScreen.configurations and type(g_shopConfigScreen.configurations) == "table" then
        for configKey, selectedIndex in pairs(g_shopConfigScreen.configurations) do
            if type(selectedIndex) == "number" then
                configurations[configKey] = selectedIndex
            end
        end
        if next(configurations) then
            UsedPlus.logTrace("Got configurations from g_shopConfigScreen.configurations")
        end
    end

    -- Method 3: Try configurationItems array (UI elements)
    if not next(configurations) then
        local configScreen = shopScreen or g_shopConfigScreen
        if configScreen and configScreen.configurationItems then
            for _, item in pairs(configScreen.configurationItems) do
                if item.name and item.state then
                    configurations[item.name] = item.state
                elseif item.name and item.currentIndex then
                    configurations[item.name] = item.currentIndex
                end
            end
            if next(configurations) then
                UsedPlus.logTrace("Got configurations from configurationItems")
            end
        end
    end

    -- Debug log configurations
    local count = 0
    for k, v in pairs(configurations) do
        UsedPlus.logTrace(string.format("  Config: %s = %s", tostring(k), tostring(v)))
        count = count + 1
    end
    UsedPlus.logDebug(string.format("Total configurations captured: %d", count))

    return configurations
end

--[[
    Unified Buy click handler
    Refactored to use DialogLoader for centralized loading
]]
function ShopConfigScreenExtension.onUnifiedBuyClick(shopScreen, storeItem, initialMode)
    UsedPlus.logDebug("Unified Buy clicked for: " .. tostring(storeItem.name) .. " mode: " .. tostring(initialMode))

    g_shopConfigScreen:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)

    -- Use DialogLoader for lazy loading (need to call two methods)
    if not DialogLoader.ensureLoaded("UnifiedPurchaseDialog") then
        return
    end

    local dialog = DialogLoader.getDialog("UnifiedPurchaseDialog")
    if dialog then
        -- Get the configured price for the item
        local price = storeItem.price or 0
        if shopScreen and shopScreen.totalPrice then
            price = shopScreen.totalPrice
        end

        dialog:setVehicleData(storeItem, price, nil)
        dialog:setInitialMode(initialMode or UnifiedPurchaseDialog.MODE_CASH)
        g_gui:showDialog("UnifiedPurchaseDialog")
    end
end

--[[
    Search Used click handler
    Refactored to use DialogLoader for centralized loading
]]
function ShopConfigScreenExtension.onSearchClick(shopScreen, storeItem)
    UsedPlus.logDebug("Search Used button clicked for: " .. tostring(storeItem.name))

    g_shopConfigScreen:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)

    local farmId = g_currentMission:getFarmId()

    -- Use DialogLoader for centralized lazy loading
    DialogLoader.show("UsedSearchDialog", "setData", storeItem, storeItem.xmlFilename, farmId)
end

--[[
    Inspect button click handler
    Shows MaintenanceReportDialog for the owned vehicle
]]
function ShopConfigScreenExtension.onInspectClick(shopScreen, vehicle)
    if vehicle == nil then
        UsedPlus.logDebug("Inspect clicked but no vehicle")
        return
    end

    UsedPlus.logDebug("Inspect button clicked for: " .. tostring(vehicle:getName()))

    g_shopConfigScreen:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)

    -- Show MaintenanceReportDialog
    if MaintenanceReportDialog then
        local dialog = MaintenanceReportDialog.getInstance()
        if dialog then
            dialog:show(vehicle)
            return
        end
    end

    -- Fallback: Show simple info dialog
    local info = "Maintenance information not available."

    if UsedPlusMaintenance and UsedPlusMaintenance.getReliabilityData then
        local data = UsedPlusMaintenance.getReliabilityData(vehicle)
        if data then
            info = string.format(
                "=== Maintenance Report ===\n" ..
                "Vehicle: %s\n\n" ..
                "Engine Reliability: %d%%\n" ..
                "Hydraulic Reliability: %d%%\n" ..
                "Electrical Reliability: %d%%\n\n" ..
                "Breakdowns: %d\n" ..
                "Repairs: %d",
                vehicle:getName() or "Unknown",
                math.floor((data.engineReliability or 1) * 100),
                math.floor((data.hydraulicReliability or 1) * 100),
                math.floor((data.electricalReliability or 1) * 100),
                data.failureCount or 0,
                data.repairCount or 0
            )
        end
    end

    InfoDialog.show(info)
end

UsedPlus.logInfo("ShopConfigScreenExtension loaded")
