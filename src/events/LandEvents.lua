--[[
    FS25_UsedPlus - Land Events (Consolidated)

    Network events for land leasing operations:
    - LandLeaseEvent: Create a land lease
    - LandLeaseBuyoutEvent: Buy out a land lease

    Pattern from: FinanceVehicleEvent, LeaseVehicleEvent
]]

--============================================================================
-- LAND LEASE EVENT
-- Network event for creating land leases
--============================================================================

LandLeaseEvent = {}
local LandLeaseEvent_mt = Class(LandLeaseEvent, Event)

InitEventClass(LandLeaseEvent, "LandLeaseEvent")

function LandLeaseEvent.emptyNew()
    local self = Event.new(LandLeaseEvent_mt)
    return self
end

function LandLeaseEvent.new(farmId, farmlandId, fieldName, landPrice, termYears)
    local self = LandLeaseEvent.emptyNew()
    self.farmId = farmId
    self.farmlandId = farmlandId
    self.fieldName = fieldName
    self.landPrice = landPrice
    self.termYears = termYears
    return self
end

function LandLeaseEvent.sendToServer(farmId, farmlandId, fieldName, landPrice, termYears)
    local event = LandLeaseEvent.new(farmId, farmlandId, fieldName, landPrice, termYears)
    if g_server ~= nil then
        event:run(g_server:getServerConnection())
    else
        g_client:getServerConnection():sendEvent(event)
    end
end

function LandLeaseEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId)
    streamWriteInt32(streamId, self.farmlandId)
    streamWriteString(streamId, self.fieldName or "")
    streamWriteFloat32(streamId, self.landPrice)
    streamWriteInt32(streamId, self.termYears)
end

function LandLeaseEvent:readStream(streamId, connection)
    self.farmId = streamReadInt32(streamId)
    self.farmlandId = streamReadInt32(streamId)
    self.fieldName = streamReadString(streamId)
    self.landPrice = streamReadFloat32(streamId)
    self.termYears = streamReadInt32(streamId)
    self:run(connection)
end

function LandLeaseEvent:run(connection)
    if not connection:getIsServer() then
        UsedPlus.logError("LandLeaseEvent must run on server")
        return
    end

    -- v2.7.2: Validate farm ownership to prevent multiplayer exploits
    local isAuthorized, errorMsg = NetworkSecurity.validateFarmOwnership(connection, self.farmId)
    if not isAuthorized then
        NetworkSecurity.logSecurityEvent("LAND_LEASE_REJECTED",
            string.format("Unauthorized land lease attempt for farmId %d, farmland %d: %s",
                self.farmId, self.farmlandId, errorMsg or "unknown"),
            connection)
        return
    end

    if g_financeManager == nil then
        UsedPlus.logError("FinanceManager not initialized")
        return
    end

    local farm = g_farmManager:getFarmById(self.farmId)
    if farm == nil then
        UsedPlus.logError(string.format("Farm %d not found", self.farmId))
        return
    end

    local validTerms = {1, 3, 5, 10}
    local termValid = false
    for _, t in ipairs(validTerms) do
        if self.termYears == t then
            termValid = true
            break
        end
    end
    if not termValid then
        UsedPlus.logError(string.format("Invalid lease term: %d years", self.termYears))
        return
    end

    local farmland = g_farmlandManager:getFarmlandById(self.farmlandId)
    if farmland == nil then
        UsedPlus.logError(string.format("Farmland %d not found", self.farmlandId))
        return
    end

    local currentOwner = g_farmlandManager:getFarmlandOwner(self.farmlandId)
    if currentOwner ~= 0 then
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
            "This land is already owned and cannot be leased."
        )
        return
    end

    local existingDeals = g_financeManager:getDealsForFarm(self.farmId)
    for _, deal in ipairs(existingDeals) do
        if deal.dealType == 3 and deal.farmlandId == self.farmlandId then
            g_currentMission:addIngameNotification(
                FSBaseMission.INGAME_NOTIFICATION_INFO,
                "You already have a lease on this land."
            )
            return
        end
    end

    UsedPlus.logDebug(string.format("Creating land lease: %s ($%.2f, %d years)",
        self.fieldName, self.landPrice, self.termYears))

    local deal = LandLeaseDeal.new(
        self.farmId, self.farmlandId, self.fieldName, self.landPrice, self.termYears
    )

    g_financeManager:registerDeal(deal)
    g_farmlandManager:setLandOwnership(self.farmlandId, self.farmId)

    if CreditHistory then
        CreditHistory.recordEvent(self.farmId, "LAND_LEASE_STARTED", self.fieldName)
    end

    g_currentMission:addIngameNotification(
        FSBaseMission.INGAME_NOTIFICATION_OK,
        string.format("Land lease started! %s for %d years at %s/month",
            self.fieldName, self.termYears,
            g_i18n:formatMoney(deal.monthlyPayment, 0, true, true))
    )

    UsedPlus.logDebug(string.format("Land lease created: id=%s, monthly=%s",
        deal.id, g_i18n:formatMoney(deal.monthlyPayment, 0, true, true)))
end

--============================================================================
-- LAND LEASE BUYOUT EVENT
-- Network event for buying out a land lease
--============================================================================

LandLeaseBuyoutEvent = {}
local LandLeaseBuyoutEvent_mt = Class(LandLeaseBuyoutEvent, Event)

InitEventClass(LandLeaseBuyoutEvent, "LandLeaseBuyoutEvent")

function LandLeaseBuyoutEvent.emptyNew()
    local self = Event.new(LandLeaseBuyoutEvent_mt)
    return self
end

function LandLeaseBuyoutEvent.new(dealId)
    local self = LandLeaseBuyoutEvent.emptyNew()
    self.dealId = dealId
    return self
end

function LandLeaseBuyoutEvent.sendToServer(dealId)
    local event = LandLeaseBuyoutEvent.new(dealId)
    if g_server ~= nil then
        event:run(g_server:getServerConnection())
    else
        g_client:getServerConnection():sendEvent(event)
    end
end

function LandLeaseBuyoutEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.dealId)
end

function LandLeaseBuyoutEvent:readStream(streamId, connection)
    self.dealId = streamReadString(streamId)
    self:run(connection)
end

function LandLeaseBuyoutEvent:run(connection)
    if not connection:getIsServer() then
        UsedPlus.logError("LandLeaseBuyoutEvent must run on server")
        return
    end

    if g_financeManager == nil then
        UsedPlus.logError("FinanceManager not initialized")
        return
    end

    local deal = g_financeManager:getDealById(self.dealId)
    if deal == nil then
        UsedPlus.logError(string.format("Land lease deal %s not found", self.dealId))
        return
    end

    -- v2.7.2: Validate farm ownership to prevent multiplayer exploits
    local isAuthorized, errorMsg = NetworkSecurity.validateFarmOwnership(connection, deal.farmId)
    if not isAuthorized then
        NetworkSecurity.logSecurityEvent("LAND_BUYOUT_REJECTED",
            string.format("Unauthorized land buyout attempt for deal %s (farmId %d): %s",
                self.dealId, deal.farmId, errorMsg or "unknown"),
            connection)
        return
    end

    if deal.dealType ~= 3 then
        UsedPlus.logError(string.format("Deal %s is not a land lease (type: %d)", self.dealId, deal.dealType))
        return
    end

    if deal.status ~= "active" then
        UsedPlus.logError(string.format("Deal %s is not active (status: %s)", self.dealId, deal.status))
        return
    end

    local farm = g_farmManager:getFarmById(deal.farmId)
    if farm == nil then
        UsedPlus.logError(string.format("Farm %d not found", deal.farmId))
        return
    end

    local buyoutPrice = deal:calculateBuyoutPrice()

    if farm.money < buyoutPrice then
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_ERROR,
            string.format("Insufficient funds for buyout. Need %s",
                g_i18n:formatMoney(buyoutPrice, 0, true, true))
        )
        return
    end

    g_currentMission:addMoney(-buyoutPrice, deal.farmId, MoneyType.PURCHASE_LAND, true, true)

    deal.status = "completed"
    g_financeManager:removeDeal(deal.id)

    if CreditHistory then
        CreditHistory.recordEvent(deal.farmId, "LAND_LEASE_BUYOUT", deal.landName)
    end

    g_currentMission:addIngameNotification(
        FSBaseMission.INGAME_NOTIFICATION_OK,
        string.format("Congratulations! %s is now fully yours for %s",
            deal.landName, g_i18n:formatMoney(buyoutPrice, 0, true, true))
    )

    UsedPlus.logDebug(string.format("Land lease bought out: %s for $%.2f", deal.landName, buyoutPrice))
end

--============================================================================

UsedPlus.logInfo("LandEvents loaded (LandLeaseEvent, LandLeaseBuyoutEvent)")
