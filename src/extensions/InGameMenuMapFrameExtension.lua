--[[
    FS25_UsedPlus - InGameMenuMapFrame Extension

    Adds "Finance Land" option to farmland context menu
    Pattern from: FS25_FieldLeasing mod (working reference)

    This adds a "Finance Land" option alongside "Visit", "Buy", "Tag Place"
    when clicking on unowned farmland in the map.

    Key hooks:
    - onLoadMapFinished: Register new action in InGameMenuMapFrame.ACTIONS
    - setMapInputContext: Control when action is visible (when Buy is available)
]]

InGameMenuMapFrameExtension = {}

-- Dialog loading now handled by DialogLoader utility

--[[
    Hook onLoadMapFinished to register new actions
    Only register REPAIR_VEHICLE, NOT Finance/Lease Land (those are handled by intercepting Buy)
]]
function InGameMenuMapFrameExtension.onLoadMapFinished(self, superFunc)
    -- Count existing actions to get next ID
    local count = 0
    for _ in pairs(InGameMenuMapFrame.ACTIONS) do
        count = count + 1
    end

    -- Register REPAIR_VEHICLE action if not already added
    if InGameMenuMapFrame.ACTIONS.REPAIR_VEHICLE == nil then
        InGameMenuMapFrame.ACTIONS["REPAIR_VEHICLE"] = count + 1
        count = count + 1

        self.contextActions[InGameMenuMapFrame.ACTIONS.REPAIR_VEHICLE] = {
            ["title"] = g_i18n:getText("usedplus_button_repairVehicle"),
            ["callback"] = InGameMenuMapFrameExtension.onRepairVehicle,
            ["isActive"] = false
        }

        UsedPlus.logDebug("Registered REPAIR_VEHICLE action in InGameMenuMapFrame")
    end

    -- Call original function FIRST so contextActions are set up
    superFunc(self)

    -- Override the BUY action callback to open our dialog for farmland
    -- The action is called "BUY" not "BUY_FARMLAND" in FS25
    -- Must be AFTER superFunc because contextActions are set up there
    if InGameMenuMapFrame.ACTIONS.BUY and self.contextActions[InGameMenuMapFrame.ACTIONS.BUY] then
        -- Store original callback
        InGameMenuMapFrameExtension.originalBuyCallback = self.contextActions[InGameMenuMapFrame.ACTIONS.BUY].callback
        -- Replace with our callback
        self.contextActions[InGameMenuMapFrame.ACTIONS.BUY].callback = InGameMenuMapFrameExtension.onBuyFarmland
        UsedPlus.logDebug("Intercepted BUY action callback (ID=" .. tostring(InGameMenuMapFrame.ACTIONS.BUY) .. ")")
    else
        UsedPlus.logWarn("Could not intercept BUY action")
    end
end

--[[
    Hook setMapInputContext to show Repair option
    Removed Finance/Lease Land since Buy now opens our unified dialog
]]
function InGameMenuMapFrameExtension.setMapInputContext(self, superFunc, enterVehicleActive, resetVehicleActive, sellVehicleActive, visitPlaceActive, setMarkerActive, removeMarkerActive, buyFarmlandActive, sellFarmlandActive, manageActive)

    -- Show "Repair Vehicle" when "Sell Vehicle" is available (owned vehicle selected)
    if sellVehicleActive and self.contextActions[InGameMenuMapFrame.ACTIONS.REPAIR_VEHICLE] then
        self.contextActions[InGameMenuMapFrame.ACTIONS.REPAIR_VEHICLE].isActive = true
    elseif self.contextActions[InGameMenuMapFrame.ACTIONS.REPAIR_VEHICLE] then
        self.contextActions[InGameMenuMapFrame.ACTIONS.REPAIR_VEHICLE].isActive = false
    end

    -- Call original function
    superFunc(self, enterVehicleActive, resetVehicleActive, sellVehicleActive, visitPlaceActive, setMarkerActive, removeMarkerActive, buyFarmlandActive, sellFarmlandActive, manageActive)
end

--[[
    Install hooks at load time with safety check
    InGameMenuMapFrame should exist when mods load
]]
if InGameMenuMapFrame ~= nil then
    -- Hook into onLoadMapFinished
    if InGameMenuMapFrame.onLoadMapFinished ~= nil then
        InGameMenuMapFrame.onLoadMapFinished = Utils.overwrittenFunction(
            InGameMenuMapFrame.onLoadMapFinished,
            InGameMenuMapFrameExtension.onLoadMapFinished
        )
        UsedPlus.logDebug("InGameMenuMapFrame.onLoadMapFinished hook installed")
    end

    -- Hook into setMapInputContext
    if InGameMenuMapFrame.setMapInputContext ~= nil then
        InGameMenuMapFrame.setMapInputContext = Utils.overwrittenFunction(
            InGameMenuMapFrame.setMapInputContext,
            InGameMenuMapFrameExtension.setMapInputContext
        )
        UsedPlus.logDebug("InGameMenuMapFrame.setMapInputContext hook installed")
    end
else
    UsedPlus.logWarn("InGameMenuMapFrame not available at load time")
end

--[[
    Callback when "Finance Land" is clicked
    Refactored to use DialogLoader for centralized loading
]]
function InGameMenuMapFrameExtension.onFinanceLand(inGameMenuMapFrame, element)
    if inGameMenuMapFrame.selectedFarmland == nil then
        return true
    end

    local selectedFarmland = inGameMenuMapFrame.selectedFarmland
    local farmId = g_currentMission:getFarmId()

    -- Check if there's a mission running on this farmland
    if g_missionManager:getIsMissionRunningOnFarmland(selectedFarmland) then
        InfoDialog.show(g_i18n:getText(InGameMenuMapFrame.L10N_SYMBOL.DIALOG_BUY_FARMLAND_ACTIVE_MISSION))
        return false
    end

    -- Use DialogLoader for centralized lazy loading
    local shown = DialogLoader.show("LandFinanceDialog", "setData", selectedFarmland.id, selectedFarmland.price, farmId)

    if shown then
        -- Hide context boxes after opening dialog
        InGameMenuMapUtil.hideContextBox(inGameMenuMapFrame.contextBox)
        InGameMenuMapUtil.hideContextBox(inGameMenuMapFrame.contextBoxPlayer)
        InGameMenuMapUtil.hideContextBox(inGameMenuMapFrame.contextBoxFarmland)
    end

    return true
end

--[[
    Callback when "Lease Land" is clicked
    Refactored to use DialogLoader for centralized loading
]]
function InGameMenuMapFrameExtension.onLeaseLand(inGameMenuMapFrame, element)
    if inGameMenuMapFrame.selectedFarmland == nil then
        return true
    end

    local selectedFarmland = inGameMenuMapFrame.selectedFarmland
    local farmId = g_currentMission:getFarmId()

    -- Check if there's a mission running on this farmland
    if g_missionManager:getIsMissionRunningOnFarmland(selectedFarmland) then
        InfoDialog.show(g_i18n:getText(InGameMenuMapFrame.L10N_SYMBOL.DIALOG_BUY_FARMLAND_ACTIVE_MISSION))
        return false
    end

    -- Use DialogLoader for centralized lazy loading
    local shown = DialogLoader.show("LandLeaseDialog", "setData", selectedFarmland.id, selectedFarmland.price, farmId)

    if shown then
        -- Hide context boxes after opening dialog
        InGameMenuMapUtil.hideContextBox(inGameMenuMapFrame.contextBox)
        InGameMenuMapUtil.hideContextBox(inGameMenuMapFrame.contextBoxPlayer)
        InGameMenuMapUtil.hideContextBox(inGameMenuMapFrame.contextBoxFarmland)
    end

    return true
end

--[[
    Callback when "Repair Vehicle" is clicked
    Refactored to use DialogLoader for centralized loading
]]
function InGameMenuMapFrameExtension.onRepairVehicle(inGameMenuMapFrame, element)
    -- Get the selected vehicle from the current hotspot
    local vehicle = nil

    if inGameMenuMapFrame.currentHotspot ~= nil then
        -- Try to get vehicle from hotspot
        if InGameMenuMapUtil and InGameMenuMapUtil.getHotspotVehicle then
            vehicle = InGameMenuMapUtil.getHotspotVehicle(inGameMenuMapFrame.currentHotspot)
        end

        -- Fallback: try direct vehicle reference
        if vehicle == nil and inGameMenuMapFrame.currentHotspot.vehicle then
            vehicle = inGameMenuMapFrame.currentHotspot.vehicle
        end
    end

    if vehicle == nil then
        UsedPlus.logError("No vehicle selected for repair")
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
            "No vehicle selected"
        )
        return true
    end

    local farmId = g_currentMission:getFarmId()

    -- Check if player owns the vehicle
    if vehicle.ownerFarmId ~= farmId then
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
            "You do not own this vehicle"
        )
        return true
    end

    -- Use DialogLoader for centralized lazy loading
    local shown = DialogLoader.show("RepairDialog", "setVehicle", vehicle, farmId)

    if shown then
        -- Hide context boxes after opening dialog
        InGameMenuMapUtil.hideContextBox(inGameMenuMapFrame.contextBox)
        InGameMenuMapUtil.hideContextBox(inGameMenuMapFrame.contextBoxPlayer)
        InGameMenuMapUtil.hideContextBox(inGameMenuMapFrame.contextBoxFarmland)
    end

    return true
end

--[[
    Callback when "Buy" farmland is clicked
    Refactored to use DialogLoader for centralized loading
]]
function InGameMenuMapFrameExtension.onBuyFarmland(inGameMenuMapFrame, element)
    if inGameMenuMapFrame.selectedFarmland == nil then
        return true
    end

    local selectedFarmland = inGameMenuMapFrame.selectedFarmland

    -- Check if there's a mission running on this farmland
    if g_missionManager:getIsMissionRunningOnFarmland(selectedFarmland) then
        InfoDialog.show(g_i18n:getText(InGameMenuMapFrame.L10N_SYMBOL.DIALOG_BUY_FARMLAND_ACTIVE_MISSION))
        return false
    end

    -- Use DialogLoader for centralized lazy loading
    local shown = DialogLoader.show("UnifiedLandPurchaseDialog", "setLandData", selectedFarmland.id, selectedFarmland, selectedFarmland.price)

    if shown then
        -- Hide context boxes after opening dialog
        InGameMenuMapUtil.hideContextBox(inGameMenuMapFrame.contextBox)
        InGameMenuMapUtil.hideContextBox(inGameMenuMapFrame.contextBoxPlayer)
        InGameMenuMapUtil.hideContextBox(inGameMenuMapFrame.contextBoxFarmland)
    end

    return true
end

UsedPlus.logInfo("InGameMenuMapFrameExtension loaded")
