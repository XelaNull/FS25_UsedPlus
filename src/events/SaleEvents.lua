--[[
    FS25_UsedPlus - Sale Events (Consolidated)

    Network events for vehicle sale operations:
    - CreateSaleListingEvent: Create an agent-based sale listing
    - SaleListingActionEvent: Accept/Decline/Cancel sale offers

    Pattern from: TakeLoanEvent, FS25_ADVANCED_PATTERNS.md
]]

--============================================================================
-- CREATE SALE LISTING EVENT
-- Network event for creating an agent-based sale listing
--============================================================================

CreateSaleListingEvent = {}
local CreateSaleListingEvent_mt = Class(CreateSaleListingEvent, Event)

InitEventClass(CreateSaleListingEvent, "CreateSaleListingEvent")

function CreateSaleListingEvent.emptyNew()
    local self = Event.new(CreateSaleListingEvent_mt)
    return self
end

function CreateSaleListingEvent.new(farmId, vehicleId, saleTier)
    local self = CreateSaleListingEvent.emptyNew()
    self.farmId = farmId
    self.vehicleId = vehicleId
    self.saleTier = saleTier
    return self
end

function CreateSaleListingEvent.sendToServer(farmId, vehicleId, saleTier)
    if g_server ~= nil then
        CreateSaleListingEvent.execute(farmId, vehicleId, saleTier)
    else
        g_client:getServerConnection():sendEvent(
            CreateSaleListingEvent.new(farmId, vehicleId, saleTier)
        )
    end
end

function CreateSaleListingEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId)
    streamWriteInt32(streamId, self.vehicleId)
    streamWriteInt8(streamId, self.saleTier)
end

function CreateSaleListingEvent:readStream(streamId, connection)
    self.farmId = streamReadInt32(streamId)
    self.vehicleId = streamReadInt32(streamId)
    self.saleTier = streamReadInt8(streamId)
    self:run(connection)
end

function CreateSaleListingEvent.execute(farmId, vehicleId, saleTier)
    local vehicle = nil
    if g_currentMission and g_currentMission.vehicleSystem then
        for _, v in pairs(g_currentMission.vehicleSystem.vehicles) do
            if v.id == vehicleId then
                vehicle = v
                break
            end
        end
    end

    if vehicle == nil then
        UsedPlus.logError(string.format("CreateSaleListingEvent - Vehicle %d not found", vehicleId))
        return false
    end

    if vehicle.ownerFarmId ~= farmId then
        UsedPlus.logError(string.format("CreateSaleListingEvent - Vehicle not owned by farm %d", farmId))
        return false
    end

    if saleTier < 1 or saleTier > 3 then
        UsedPlus.logError(string.format("CreateSaleListingEvent - Invalid tier: %d", saleTier))
        return false
    end

    if g_vehicleSaleManager then
        local listing = g_vehicleSaleManager:createSaleListing(farmId, vehicle, saleTier)
        if listing then
            UsedPlus.logDebug(string.format("CreateSaleListingEvent: Created listing %s", listing.id))
            return true
        end
    end

    UsedPlus.logError("CreateSaleListingEvent - Failed to create listing")
    return false
end

function CreateSaleListingEvent:run(connection)
    if not connection:getIsServer() then
        UsedPlus.logError("CreateSaleListingEvent must run on server")
        return
    end

    -- v2.7.2: Validate farm ownership to prevent multiplayer exploits
    local isAuthorized, errorMsg = NetworkSecurity.validateFarmOwnership(connection, self.farmId)
    if not isAuthorized then
        NetworkSecurity.logSecurityEvent("CREATE_SALE_LISTING_REJECTED",
            string.format("Unauthorized create sale listing attempt for farmId %d, vehicle %d: %s",
                self.farmId, self.vehicleId, errorMsg or "unknown"),
            connection)
        return
    end

    CreateSaleListingEvent.execute(self.farmId, self.vehicleId, self.saleTier)
end

--============================================================================
-- SALE LISTING ACTION EVENT
-- Consolidated event for Accept/Decline/Cancel actions
--============================================================================

SaleListingActionEvent = {}
local SaleListingActionEvent_mt = Class(SaleListingActionEvent, Event)

InitEventClass(SaleListingActionEvent, "SaleListingActionEvent")

SaleListingActionEvent.ACTION_ACCEPT = 1
SaleListingActionEvent.ACTION_DECLINE = 2
SaleListingActionEvent.ACTION_CANCEL = 3

SaleListingActionEvent.ACTION_NAMES = {
    [1] = "Accept",
    [2] = "Decline",
    [3] = "Cancel"
}

function SaleListingActionEvent.emptyNew()
    local self = Event.new(SaleListingActionEvent_mt)
    return self
end

function SaleListingActionEvent.new(listingId, actionType)
    local self = SaleListingActionEvent.emptyNew()
    self.listingId = listingId
    self.actionType = actionType
    return self
end

function SaleListingActionEvent.sendToServer(listingId, actionType)
    if g_server ~= nil then
        SaleListingActionEvent.execute(listingId, actionType)
    else
        g_client:getServerConnection():sendEvent(
            SaleListingActionEvent.new(listingId, actionType)
        )
    end
end

-- Convenience methods
function SaleListingActionEvent.acceptOffer(listingId)
    SaleListingActionEvent.sendToServer(listingId, SaleListingActionEvent.ACTION_ACCEPT)
end

function SaleListingActionEvent.declineOffer(listingId)
    SaleListingActionEvent.sendToServer(listingId, SaleListingActionEvent.ACTION_DECLINE)
end

function SaleListingActionEvent.cancelListing(listingId)
    SaleListingActionEvent.sendToServer(listingId, SaleListingActionEvent.ACTION_CANCEL)
end

function SaleListingActionEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.listingId)
    streamWriteUInt8(streamId, self.actionType)
end

function SaleListingActionEvent:readStream(streamId, connection)
    self.listingId = streamReadString(streamId)
    self.actionType = streamReadUInt8(streamId)
    self:run(connection)
end

function SaleListingActionEvent.execute(listingId, actionType)
    if g_vehicleSaleManager == nil then
        UsedPlus.logError("SaleListingActionEvent - VehicleSaleManager not available")
        return false
    end

    local success = false
    local actionName = SaleListingActionEvent.ACTION_NAMES[actionType] or "Unknown"

    if actionType == SaleListingActionEvent.ACTION_ACCEPT then
        success = g_vehicleSaleManager:acceptOffer(listingId)
    elseif actionType == SaleListingActionEvent.ACTION_DECLINE then
        success = g_vehicleSaleManager:declineOffer(listingId)
    elseif actionType == SaleListingActionEvent.ACTION_CANCEL then
        success = g_vehicleSaleManager:cancelListing(listingId)
    else
        UsedPlus.logError(string.format("SaleListingActionEvent - Unknown action type: %d", actionType))
        return false
    end

    if success then
        UsedPlus.logDebug(string.format("SaleListingActionEvent: %s on listing %s", actionName, listingId))
    else
        UsedPlus.logError(string.format("SaleListingActionEvent - Failed to %s listing %s", actionName:lower(), listingId))
    end

    return success
end

function SaleListingActionEvent:run(connection)
    if not connection:getIsServer() then
        UsedPlus.logError("SaleListingActionEvent must run on server")
        return
    end

    -- v2.7.2 SECURITY: Validate action type is one of the known values
    local validActions = {
        [SaleListingActionEvent.ACTION_ACCEPT] = true,
        [SaleListingActionEvent.ACTION_DECLINE] = true,
        [SaleListingActionEvent.ACTION_CANCEL] = true
    }
    if not validActions[self.actionType] then
        UsedPlus.logError(string.format("[SECURITY] Invalid action type: %s", tostring(self.actionType)))
        return
    end

    -- v2.7.2 SECURITY: Require VehicleSaleManager and listing to exist
    if g_vehicleSaleManager == nil then
        UsedPlus.logError("[SECURITY] VehicleSaleManager not available")
        return
    end

    local listing = g_vehicleSaleManager:getListingById(self.listingId)
    if listing == nil then
        -- Listing not found - could be already processed or invalid ID
        UsedPlus.logWarn(string.format("[SECURITY] Listing %s not found", self.listingId))
        return
    end

    -- v2.7.2: Validate farm ownership to prevent multiplayer exploits
    local isAuthorized, errorMsg = NetworkSecurity.validateFarmOwnership(connection, listing.farmId)
    if not isAuthorized then
        NetworkSecurity.logSecurityEvent("SALE_ACTION_REJECTED",
            string.format("Unauthorized sale action %d for listing %s (farmId %d): %s",
                self.actionType, self.listingId, listing.farmId, errorMsg or "unknown"),
            connection)
        return
    end

    SaleListingActionEvent.execute(self.listingId, self.actionType)
end

-- Legacy compatibility aliases
AcceptSaleOfferEvent = {
    sendToServer = function(listingId) SaleListingActionEvent.acceptOffer(listingId) end
}
DeclineSaleOfferEvent = {
    sendToServer = function(listingId) SaleListingActionEvent.declineOffer(listingId) end
}
CancelSaleListingEvent = {
    sendToServer = function(listingId) SaleListingActionEvent.cancelListing(listingId) end
}

--============================================================================
-- MODIFY LISTING PRICE EVENT
-- Network event for changing the asking price of an active listing
--============================================================================

ModifyListingPriceEvent = {}
local ModifyListingPriceEvent_mt = Class(ModifyListingPriceEvent, Event)

InitEventClass(ModifyListingPriceEvent, "ModifyListingPriceEvent")

function ModifyListingPriceEvent.emptyNew()
    local self = Event.new(ModifyListingPriceEvent_mt)
    return self
end

function ModifyListingPriceEvent.new(listingId, newPrice)
    local self = ModifyListingPriceEvent.emptyNew()
    self.listingId = listingId
    self.newPrice = newPrice
    return self
end

function ModifyListingPriceEvent.sendToServer(listingId, newPrice)
    if g_server ~= nil then
        ModifyListingPriceEvent.execute(listingId, newPrice)
    else
        g_client:getServerConnection():sendEvent(
            ModifyListingPriceEvent.new(listingId, newPrice)
        )
    end
end

function ModifyListingPriceEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.listingId)
    streamWriteFloat32(streamId, self.newPrice)
end

function ModifyListingPriceEvent:readStream(streamId, connection)
    self.listingId = streamReadString(streamId)
    self.newPrice = streamReadFloat32(streamId)
    self:run(connection)
end

function ModifyListingPriceEvent.execute(listingId, newPrice)
    if g_vehicleSaleManager == nil then
        UsedPlus.logError("ModifyListingPriceEvent - VehicleSaleManager not available")
        return false
    end

    return g_vehicleSaleManager:modifyAskingPrice(listingId, newPrice)
end

function ModifyListingPriceEvent:run(connection)
    if not connection:getIsServer() then
        UsedPlus.logError("ModifyListingPriceEvent must run on server")
        return
    end

    -- v2.7.2 SECURITY: Helper to check for NaN and Infinity values
    local function isInvalidNumber(v)
        return v == nil or v ~= v or v == math.huge or v == -math.huge
    end

    -- v2.7.2 SECURITY: Validate price is positive and reasonable (including infinity check)
    if isInvalidNumber(self.newPrice) or self.newPrice <= 0 or self.newPrice > 100000000 then
        UsedPlus.logError(string.format("[SECURITY] Invalid price: %s", tostring(self.newPrice)))
        return
    end

    -- v2.7.2 SECURITY: Require VehicleSaleManager and listing to exist
    if g_vehicleSaleManager == nil then
        UsedPlus.logError("[SECURITY] VehicleSaleManager not available")
        return
    end

    local listing = g_vehicleSaleManager:getListingById(self.listingId)
    if listing == nil then
        UsedPlus.logWarn(string.format("[SECURITY] Listing %s not found", self.listingId))
        return
    end

    -- v2.7.2: Validate farm ownership to prevent multiplayer exploits
    local isAuthorized, errorMsg = NetworkSecurity.validateFarmOwnership(connection, listing.farmId)
    if not isAuthorized then
        NetworkSecurity.logSecurityEvent("MODIFY_PRICE_REJECTED",
            string.format("Unauthorized price modify for listing %s (farmId %d): %s",
                self.listingId, listing.farmId, errorMsg or "unknown"),
            connection)
        return
    end

    ModifyListingPriceEvent.execute(self.listingId, self.newPrice)
end

--============================================================================

UsedPlus.logInfo("SaleEvents loaded (CreateSaleListingEvent, SaleListingActionEvent, ModifyListingPriceEvent)")
