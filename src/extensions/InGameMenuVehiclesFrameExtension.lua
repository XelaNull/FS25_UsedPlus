--[[
    FS25_UsedPlus - InGameMenu Vehicles Frame Extension

    Hooks the Sell button in ESC -> Vehicles page
    Replaces vanilla instant-sell with agent-based sale system
    Pattern from: ShopConfigScreenExtension (hook existing UI)

    Flow:
    1. Player selects vehicle in ESC -> Vehicles
    2. Player clicks "Sell"
    3. Instead of vanilla confirmation, show SellVehicleDialog
    4. Player selects agent tier
    5. Create VehicleSaleListing and start agent search
    6. Vehicle remains in inventory until sold
]]

InGameMenuVehiclesFrameExtension = {}

-- Store reference to original sell function
InGameMenuVehiclesFrameExtension.originalOnClickSell = nil
InGameMenuVehiclesFrameExtension.originalGetDisplayName = nil
InGameMenuVehiclesFrameExtension.isInitialized = false

--[[
    Initialize the extension
    Called from main.lua after mission starts
]]
function InGameMenuVehiclesFrameExtension:init()
    if self.isInitialized then
        UsedPlus.logDebug("InGameMenuVehiclesFrameExtension already initialized")
        return
    end

    -- Hook InGameMenuVehiclesFrame.onClickSell
    self:hookSellButton()

    -- Hook vehicle display name to show (LEASED) indicator
    self:hookVehicleDisplayName()

    -- Hook menu buttons to add "Maintenance" button
    self:hookMenuButtons()

    self.isInitialized = true
    UsedPlus.logDebug("InGameMenuVehiclesFrameExtension initialized")
end

--[[
    Hook menu buttons to add Maintenance Report button
    Appends to the frame's menu button info
]]
function InGameMenuVehiclesFrameExtension:hookMenuButtons()
    if InGameMenuVehiclesFrame == nil then
        UsedPlus.logDebug("InGameMenuVehiclesFrame not found, cannot hook menu buttons")
        return
    end

    -- Store original getMenuButtonInfo if it exists
    self.originalGetMenuButtonInfo = InGameMenuVehiclesFrame.getMenuButtonInfo

    -- Hook getMenuButtonInfo to add our button
    InGameMenuVehiclesFrame.getMenuButtonInfo = function(frame)
        local buttons = {}

        -- Get original buttons first
        if InGameMenuVehiclesFrameExtension.originalGetMenuButtonInfo then
            buttons = InGameMenuVehiclesFrameExtension.originalGetMenuButtonInfo(frame) or {}
        end

        -- Add our Maintenance button if a vehicle is selected
        local vehicle = nil
        if frame and frame.getSelectedVehicle then
            vehicle = frame:getSelectedVehicle()
        end

        if vehicle then
            -- Check if vehicle has maintenance data worth showing
            local hasMaintenanceData = false
            if UsedPlusMaintenance and UsedPlusMaintenance.getReliabilityData then
                local data = UsedPlusMaintenance.getReliabilityData(vehicle)
                hasMaintenanceData = (data ~= nil)
            end

            -- Add button (show for all vehicles, but especially useful for used)
            table.insert(buttons, {
                inputAction = InputAction.MENU_EXTRA_1,
                text = "Maintenance",
                callback = function()
                    InGameMenuVehiclesFrameExtension.showMaintenanceReport(vehicle)
                end
            })
        end

        return buttons
    end

    UsedPlus.logDebug("Hooked InGameMenuVehiclesFrame.getMenuButtonInfo for Maintenance button")
end

--[[
    Hook vehicle display name in vehicle lists
    Appends "(LEASED)" to leased vehicle names
]]
function InGameMenuVehiclesFrameExtension:hookVehicleDisplayName()
    -- Hook Vehicle:getName() to append lease status
    if Vehicle == nil then
        UsedPlus.logWarn("Vehicle class not found, cannot hook getName")
        return
    end

    -- Store original getName function
    self.originalGetDisplayName = Vehicle.getName

    -- Replace with our version
    Vehicle.getName = function(vehicle)
        local name = InGameMenuVehiclesFrameExtension.originalGetDisplayName(vehicle)

        -- Check if vehicle is leased via UsedPlus system
        if g_financeManager and g_financeManager:hasActiveLease(vehicle) then
            name = name .. " (LEASED)"
        end

        -- Check if vehicle is pledged as collateral for a cash loan
        if CollateralUtils and CollateralUtils.isVehiclePledged then
            local isPledged = CollateralUtils.isVehiclePledged(vehicle)
            if isPledged then
                name = name .. " (PLEDGED)"
            end
        end

        -- Check maintenance status (Phase 5)
        local maintenanceIndicator = InGameMenuVehiclesFrameExtension.getMaintenanceIndicator(vehicle)
        if maintenanceIndicator then
            name = name .. " " .. maintenanceIndicator
        end

        return name
    end

    UsedPlus.logDebug("Hooked Vehicle.getName for lease and maintenance indicators")
end

--[[
    Hook the sell button in InGameMenuVehiclesFrame
    Replaces onClickSell with our custom version
]]
function InGameMenuVehiclesFrameExtension:hookSellButton()
    -- Find InGameMenuVehiclesFrame class
    if InGameMenuVehiclesFrame == nil then
        UsedPlus.logWarn("InGameMenuVehiclesFrame not found, cannot hook sell button")
        return
    end

    -- Store original function
    self.originalOnClickSell = InGameMenuVehiclesFrame.onClickSell

    -- Replace with our version
    InGameMenuVehiclesFrame.onClickSell = function(frame)
        InGameMenuVehiclesFrameExtension:onClickSellOverride(frame)
    end

    UsedPlus.logDebug("Hooked InGameMenuVehiclesFrame.onClickSell")
end

--[[
    Override for sell button click
    Shows our SellVehicleDialog instead of vanilla confirmation
    @param frame - The InGameMenuVehiclesFrame instance
]]
function InGameMenuVehiclesFrameExtension:onClickSellOverride(frame)
    -- Get selected vehicle
    local vehicle = frame:getSelectedVehicle()
    if vehicle == nil then
        UsedPlus.logDebug("No vehicle selected for sale")
        return
    end

    -- Get farm ID
    local farmId = g_currentMission:getFarmId()

    -- Check ownership
    if vehicle.ownerFarmId ~= farmId then
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_INFO,
            "You do not own this vehicle."
        )
        return
    end

    -- Check if vehicle is owned (not leased via vanilla system)
    if vehicle.propertyState ~= VehiclePropertyState.OWNED then
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_INFO,
            "Leased vehicles cannot be sold. Terminate the lease first."
        )
        return
    end

    -- Check if vehicle is leased via UsedPlus lease system
    if g_financeManager and g_financeManager:hasActiveLease(vehicle) then
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_ERROR,
            g_i18n:getText("usedplus_error_cannotSellLeasedVehicle")
        )
        return
    end

    -- Check if vehicle is financed
    if TradeInCalculations and TradeInCalculations.isVehicleFinanced then
        if TradeInCalculations.isVehicleFinanced(vehicle, farmId) then
            g_currentMission:addIngameNotification(
                FSBaseMission.INGAME_NOTIFICATION_INFO,
                "Financed vehicles cannot be sold until loan is paid off."
            )
            return
        end
    end

    -- Check if vehicle is pledged as collateral for a cash loan
    if CollateralUtils and CollateralUtils.isVehiclePledged then
        local isPledged, deal = CollateralUtils.isVehiclePledged(vehicle)
        if isPledged then
            local loanBalance = deal and deal.currentBalance or 0
            g_currentMission:addIngameNotification(
                FSBaseMission.INGAME_NOTIFICATION_ERROR,
                string.format("This vehicle is pledged as collateral for a %s loan.\nPay off the loan first to sell.",
                    g_i18n:formatMoney(loanBalance, 0, true, true))
            )
            return
        end
    end

    -- Check if already listed for sale
    if g_vehicleSaleManager and g_vehicleSaleManager:isVehicleListed(vehicle) then
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_INFO,
            "This vehicle is already listed for sale."
        )
        return
    end

    -- Show our custom sell dialog
    self:showSellDialog(vehicle, farmId, frame)
end

--[[
    Show the SellVehicleDialog
    Refactored to use DialogLoader for centralized loading
    @param vehicle - The vehicle to sell
    @param farmId - The owning farm
    @param frame - The vehicles frame (to refresh after)
]]
function InGameMenuVehiclesFrameExtension:showSellDialog(vehicle, farmId, frame)
    -- Use DialogLoader with callback
    local callback = function(selectedTier)
        if selectedTier then
            -- Player selected a tier - create listing
            self:createSaleListing(vehicle, farmId, selectedTier, frame)
        else
            -- Player cancelled
            UsedPlus.logDebug("Sale dialog cancelled")
        end
    end

    DialogLoader.show("SellVehicleDialog", "setVehicle", vehicle, farmId, callback)
end

--[[
    Create a sale listing through the VehicleSaleManager
    @param vehicle - The vehicle to sell
    @param farmId - The owning farm
    @param saleTier - Selected agent tier (1-3)
    @param frame - The vehicles frame (to refresh)
]]
function InGameMenuVehiclesFrameExtension:createSaleListing(vehicle, farmId, saleTier, frame)
    if g_vehicleSaleManager == nil then
        UsedPlus.logError("VehicleSaleManager not initialized")
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_INFO,
            "Sale system error. Please try again."
        )
        return
    end

    -- Create listing through manager
    local listing = g_vehicleSaleManager:createSaleListing(farmId, vehicle, saleTier)

    if listing then
        UsedPlus.logDebug(string.format("Created sale listing: %s (Tier %d, ID: %s)",
            listing.vehicleName, saleTier, listing.id))

        -- Close the InGameMenu to return to game
        -- The notification will already be shown by VehicleSaleManager
    else
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_INFO,
            "Failed to create sale listing. Please try again."
        )
    end
end

--[[
    Get maintenance status indicator for vehicle name display
    Returns nil if no indicator needed, or a string like "[NEEDS SERVICE]"
    Phase 5 feature
    @param vehicle - The vehicle to check
    @return string indicator or nil
]]
function InGameMenuVehiclesFrameExtension.getMaintenanceIndicator(vehicle)
    -- Check if UsedPlusMaintenance is available
    if UsedPlusMaintenance == nil or UsedPlusMaintenance.getReliabilityData == nil then
        return nil
    end

    local reliabilityData = UsedPlusMaintenance.getReliabilityData(vehicle)
    if reliabilityData == nil then
        return nil
    end

    -- Only show indicator for used-purchased vehicles
    if not reliabilityData.purchasedUsed then
        return nil
    end

    -- Check average reliability
    local avgRel = reliabilityData.avgReliability or 1.0

    -- Show different indicators based on condition
    if avgRel < 0.3 then
        return "[CRITICAL]"
    elseif avgRel < 0.5 then
        return "[NEEDS SERVICE]"
    elseif avgRel < 0.6 then
        return "[WORN]"
    end

    -- No indicator if reliability is acceptable
    return nil
end

--[[
    Get detailed maintenance info for tooltip or detail display
    Phase 5 feature
    @param vehicle - The vehicle to check
    @return table with formatted info or nil
]]
function InGameMenuVehiclesFrameExtension.getMaintenanceDetails(vehicle)
    if UsedPlusMaintenance == nil or UsedPlusMaintenance.getReliabilityData == nil then
        return nil
    end

    local data = UsedPlusMaintenance.getReliabilityData(vehicle)
    if data == nil then
        return nil
    end

    -- Get rating texts
    local engineRating, engineIcon = UsedPlusMaintenance.getRatingText(data.engineReliability)
    local hydraulicRating, hydraulicIcon = UsedPlusMaintenance.getRatingText(data.hydraulicReliability)
    local electricalRating, electricalIcon = UsedPlusMaintenance.getRatingText(data.electricalReliability)

    return {
        purchasedUsed = data.purchasedUsed,
        wasInspected = data.wasInspected,

        engineReliability = math.floor(data.engineReliability * 100),
        engineRating = engineRating,
        engineIcon = engineIcon,

        hydraulicReliability = math.floor(data.hydraulicReliability * 100),
        hydraulicRating = hydraulicRating,
        hydraulicIcon = hydraulicIcon,

        electricalReliability = math.floor(data.electricalReliability * 100),
        electricalRating = electricalRating,
        electricalIcon = electricalIcon,

        avgReliability = math.floor(data.avgReliability * 100),
        failureCount = data.failureCount,
        repairCount = data.repairCount,
    }
end

--[[
    Format maintenance details as multi-line string
    Useful for tooltips or info panels
    @param vehicle - The vehicle to check
    @return formatted string or nil
]]
function InGameMenuVehiclesFrameExtension.formatMaintenanceInfo(vehicle)
    local details = InGameMenuVehiclesFrameExtension.getMaintenanceDetails(vehicle)
    if details == nil or not details.purchasedUsed then
        return nil
    end

    local lines = {}
    table.insert(lines, "=== Maintenance History ===")
    table.insert(lines, string.format("Engine: %d%% %s", details.engineReliability, details.engineIcon))
    table.insert(lines, string.format("Hydraulics: %d%% %s", details.hydraulicReliability, details.hydraulicIcon))
    table.insert(lines, string.format("Electrical: %d%% %s", details.electricalReliability, details.electricalIcon))
    table.insert(lines, "")
    table.insert(lines, string.format("Breakdowns: %d", details.failureCount))
    table.insert(lines, string.format("Repairs: %d", details.repairCount))

    if details.wasInspected then
        table.insert(lines, "(Inspected before purchase)")
    end

    return table.concat(lines, "\n")
end

--[[
    Get the selected vehicle from the frame
    Helper method that handles different ways to get selected vehicle
    @param frame - The InGameMenuVehiclesFrame
    @return vehicle or nil
]]
function InGameMenuVehiclesFrameExtension.getSelectedVehicle(frame)
    -- Try different methods to get selected vehicle
    if frame.selectedVehicle then
        return frame.selectedVehicle
    end

    if frame.getSelectedVehicle then
        return frame:getSelectedVehicle()
    end

    -- Try getting from list selection
    if frame.vehicleList and frame.vehicleList.selectedIndex then
        local index = frame.vehicleList.selectedIndex
        if frame.vehicles and frame.vehicles[index] then
            return frame.vehicles[index]
        end
    end

    return nil
end

--[[
    Show maintenance report for a vehicle
    Can be called from anywhere with a vehicle reference
    @param vehicle - The vehicle to show maintenance for
]]
function InGameMenuVehiclesFrameExtension.showMaintenanceReport(vehicle)
    if vehicle == nil then
        UsedPlus.logDebug("showMaintenanceReport: No vehicle provided")
        return false
    end

    -- Check if MaintenanceReportDialog is available
    if MaintenanceReportDialog == nil then
        UsedPlus.logWarn("MaintenanceReportDialog not loaded")
        -- Fallback: show info as a simple message
        local info = InGameMenuVehiclesFrameExtension.formatMaintenanceInfo(vehicle)
        if info then
            InfoDialog.show(info)
        else
            InfoDialog.show("No maintenance data available for this vehicle.")
        end
        return true
    end

    -- Show the maintenance report dialog
    local dialog = MaintenanceReportDialog.getInstance()
    dialog:show(vehicle)
    return true
end

--[[
    Show maintenance report for currently selected vehicle in vehicles frame
    Used by keybind or button
    @param frame - The InGameMenuVehiclesFrame (optional, will try to find)
]]
function InGameMenuVehiclesFrameExtension.showMaintenanceReportForSelected(frame)
    -- Try to get the frame if not provided
    if frame == nil then
        if g_gui and g_gui.currentGui and g_gui.currentGui.target then
            frame = g_gui.currentGui.target
        end
    end

    local vehicle = InGameMenuVehiclesFrameExtension.getSelectedVehicle(frame)
    if vehicle then
        InGameMenuVehiclesFrameExtension.showMaintenanceReport(vehicle)
    else
        UsedPlus.logDebug("showMaintenanceReportForSelected: No vehicle selected")
        g_currentMission:showBlinkingWarning("No vehicle selected", 2000)
    end
end

--[[
    Restore original sell behavior
    Called on mod unload
]]
function InGameMenuVehiclesFrameExtension:restore()
    if self.originalOnClickSell and InGameMenuVehiclesFrame then
        InGameMenuVehiclesFrame.onClickSell = self.originalOnClickSell
        UsedPlus.logDebug("Restored original InGameMenuVehiclesFrame.onClickSell")
    end

    if self.originalGetDisplayName and Vehicle then
        Vehicle.getName = self.originalGetDisplayName
        UsedPlus.logDebug("Restored original Vehicle.getName")
    end

    if self.originalGetMenuButtonInfo and InGameMenuVehiclesFrame then
        InGameMenuVehiclesFrame.getMenuButtonInfo = self.originalGetMenuButtonInfo
        UsedPlus.logDebug("Restored original InGameMenuVehiclesFrame.getMenuButtonInfo")
    end

    self.isInitialized = false
end

-- Try to install hook at load time
-- This runs at script load time, but InGameMenuVehiclesFrame may not exist yet
-- The init() function will also try to install the hook after mission loads
if InGameMenuVehiclesFrame and InGameMenuVehiclesFrame.onClickSell then
    InGameMenuVehiclesFrameExtension.originalOnClickSell = InGameMenuVehiclesFrame.onClickSell

    InGameMenuVehiclesFrame.onClickSell = function(frame)
        -- Only use our override if manager is ready
        if g_vehicleSaleManager and UsedPlus and UsedPlus.instance then
            InGameMenuVehiclesFrameExtension:onClickSellOverride(frame)
        elseif InGameMenuVehiclesFrameExtension.originalOnClickSell then
            -- Fall back to original if not initialized
            InGameMenuVehiclesFrameExtension.originalOnClickSell(frame)
        end
    end

    InGameMenuVehiclesFrameExtension.isInitialized = true
    UsedPlus.logDebug("InGameMenuVehiclesFrameExtension: Sell button hook installed at load time")
else
    UsedPlus.logDebug("InGameMenuVehiclesFrameExtension: Hook will be installed after mission loads")
end

UsedPlus.logInfo("InGameMenuVehiclesFrameExtension loaded")
