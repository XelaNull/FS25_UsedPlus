--[[
    FS25_UsedPlus - Used Market Events (Consolidated)

    Network events for used vehicle marketplace:
    - RequestUsedItemEvent: Initiate used vehicle search
    - UsedItemFoundEvent: Notify clients of successful search

    Pattern from: BuyUsedEquipment async search requests
]]

--============================================================================
-- REQUEST USED ITEM EVENT
-- Network event for initiating used vehicle search
--============================================================================

RequestUsedItemEvent = {}
local RequestUsedItemEvent_mt = Class(RequestUsedItemEvent, Event)

InitEventClass(RequestUsedItemEvent, "RequestUsedItemEvent")

function RequestUsedItemEvent.emptyNew()
    local self = Event.new(RequestUsedItemEvent_mt)
    return self
end

function RequestUsedItemEvent.new(farmId, storeItemIndex, storeItemName, basePrice, searchLevel, qualityLevel)
    local self = RequestUsedItemEvent.emptyNew()
    self.farmId = farmId
    self.storeItemIndex = storeItemIndex
    self.storeItemName = storeItemName
    self.basePrice = basePrice
    self.searchLevel = searchLevel
    self.qualityLevel = qualityLevel or 1
    return self
end

function RequestUsedItemEvent.sendToServer(farmId, storeItemIndex, storeItemName, basePrice, searchLevel, qualityLevel)
    if g_server ~= nil then
        RequestUsedItemEvent.execute(farmId, storeItemIndex, storeItemName, basePrice, searchLevel, qualityLevel)
    else
        g_client:getServerConnection():sendEvent(
            RequestUsedItemEvent.new(farmId, storeItemIndex, storeItemName, basePrice, searchLevel, qualityLevel)
        )
    end
end

function RequestUsedItemEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObjectId(streamId, self.farmId)
    streamWriteInt32(streamId, self.storeItemIndex)
    streamWriteString(streamId, self.storeItemName)
    streamWriteFloat32(streamId, self.basePrice)
    streamWriteInt32(streamId, self.searchLevel)
    streamWriteInt32(streamId, self.qualityLevel or 1)
end

function RequestUsedItemEvent:readStream(streamId, connection)
    self.farmId = NetworkUtil.readNodeObjectId(streamId)
    self.storeItemIndex = streamReadInt32(streamId)
    self.storeItemName = streamReadString(streamId)
    self.basePrice = streamReadFloat32(streamId)
    self.searchLevel = streamReadInt32(streamId)
    self.qualityLevel = streamReadInt32(streamId)
    self:run(connection)
end

function RequestUsedItemEvent.execute(farmId, storeItemIndex, storeItemName, basePrice, searchLevel, qualityLevel)
    if g_usedVehicleManager == nil then
        UsedPlus.logError("UsedVehicleManager not initialized")
        return
    end

    local farm = g_farmManager:getFarmById(farmId)
    if farm == nil then
        UsedPlus.logError(string.format("Farm %d not found", farmId))
        return
    end

    if searchLevel < 1 or searchLevel > 3 then
        UsedPlus.logError(string.format("Invalid search level: %d", searchLevel))
        return
    end

    qualityLevel = qualityLevel or 2  -- Default to "Any Condition" (index 2)
    if qualityLevel < 1 or qualityLevel > 5 then
        UsedPlus.logWarn(string.format("Invalid quality level: %d, defaulting to 2", qualityLevel))
        qualityLevel = 2
    end

    -- Fee percentages must match UsedVehicleSearch.calculateSearchParams()
    local SEARCH_TIERS = {
        { feePercent = 0.04 },  -- Local: 4%
        { feePercent = 0.06 },  -- Regional: 6%
        { feePercent = 0.10 }   -- National: 10%
    }

    local tier = SEARCH_TIERS[searchLevel]

    -- Apply credit fee modifier (must match UsedVehicleSearch calculation)
    local creditFeeModifier = 0
    if UsedVehicleSearch and UsedVehicleSearch.getCreditFeeModifier then
        creditFeeModifier = UsedVehicleSearch.getCreditFeeModifier(farmId)
    end
    local adjustedFeePercent = tier.feePercent * (1 + creditFeeModifier)
    local searchFee = math.floor(basePrice * adjustedFeePercent)

    if farm.money < searchFee then
        UsedPlus.logError(string.format("Insufficient funds for search fee ($%d required)", searchFee))
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
            string.format(g_i18n:getText("usedplus_error_insufficientFunds"), g_i18n:formatMoney(searchFee))
        )
        return
    end

    local MAX_ACTIVE_SEARCHES = 5
    local activeSearches = g_usedVehicleManager:getSearchesForFarm(farmId)
    local activeCount = 0
    if activeSearches then
        for _, search in ipairs(activeSearches) do
            if search.status == "active" then
                activeCount = activeCount + 1
            end
        end
    end

    if activeCount >= MAX_ACTIVE_SEARCHES then
        UsedPlus.logError(string.format("Maximum active searches reached (%d/%d)", activeCount, MAX_ACTIVE_SEARCHES))
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
            string.format("Maximum %d active searches allowed.", MAX_ACTIVE_SEARCHES)
        )
        return
    end

    local search = g_usedVehicleManager:createSearchRequest(
        farmId, storeItemIndex, storeItemName, basePrice, searchLevel, qualityLevel
    )

    if search then
        UsedPlus.logDebug(string.format("Search request created: %s (ID: %s, fee: $%d)",
            storeItemName, search.id, searchFee))
    else
        UsedPlus.logError(string.format("Failed to create search request for %s", storeItemName))
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
            g_i18n:getText("usedplus_error_searchFailed")
        )
    end
end

function RequestUsedItemEvent:run(connection)
    if not connection:getIsServer() then
        UsedPlus.logError("RequestUsedItemEvent must run on server")
        return
    end
    RequestUsedItemEvent.execute(
        self.farmId, self.storeItemIndex, self.storeItemName,
        self.basePrice, self.searchLevel, self.qualityLevel
    )
end

--============================================================================
-- USED ITEM FOUND EVENT
-- Server→Client notification of successful search
--============================================================================

UsedItemFoundEvent = {}
local UsedItemFoundEvent_mt = Class(UsedItemFoundEvent, Event)

InitEventClass(UsedItemFoundEvent, "UsedItemFoundEvent")

function UsedItemFoundEvent.emptyNew()
    local self = Event.new(UsedItemFoundEvent_mt)
    return self
end

function UsedItemFoundEvent.new(farmId, listingId, storeItemName, usedPrice, generationName, operatingHours, damage, wear)
    local self = UsedItemFoundEvent.emptyNew()
    self.farmId = farmId
    self.listingId = listingId
    self.storeItemName = storeItemName
    self.usedPrice = usedPrice
    self.generationName = generationName
    self.operatingHours = operatingHours
    self.damage = damage
    self.wear = wear
    return self
end

function UsedItemFoundEvent:sendToClients(farmId, listingId, storeItemName, usedPrice, generationName, operatingHours, damage, wear)
    if g_server ~= nil then
        g_server:broadcastEvent(
            UsedItemFoundEvent.new(farmId, listingId, storeItemName, usedPrice, generationName, operatingHours, damage, wear)
        )
    else
        UsedPlus.logWarn("UsedItemFoundEvent should only be sent by server")
    end
end

function UsedItemFoundEvent:sendToFarm(farmId, listingId, storeItemName, usedPrice, generationName, operatingHours, damage, wear)
    if g_server ~= nil then
        local farm = g_farmManager:getFarmById(farmId)
        if farm == nil then
            UsedPlus.logWarn(string.format("Farm %d not found for notification", farmId))
            return
        end

        local farmManager = g_farmManager:getFarmById(farmId).userId
        if farmManager == nil or farmManager == 0 then
            self:sendToClients(farmId, listingId, storeItemName, usedPrice, generationName, operatingHours, damage, wear)
            return
        end

        local connection = g_server:getClientConnection(farmManager)
        if connection then
            connection:sendEvent(
                UsedItemFoundEvent.new(farmId, listingId, storeItemName, usedPrice, generationName, operatingHours, damage, wear)
            )
        end
    end
end

function UsedItemFoundEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObjectId(streamId, self.farmId)
    streamWriteString(streamId, self.listingId)
    streamWriteString(streamId, self.storeItemName)
    streamWriteFloat32(streamId, self.usedPrice)
    streamWriteString(streamId, self.generationName)
    streamWriteInt32(streamId, self.operatingHours)
    streamWriteFloat32(streamId, self.damage)
    streamWriteFloat32(streamId, self.wear)
end

function UsedItemFoundEvent:readStream(streamId, connection)
    self.farmId = NetworkUtil.readNodeObjectId(streamId)
    self.listingId = streamReadString(streamId)
    self.storeItemName = streamReadString(streamId)
    self.usedPrice = streamReadFloat32(streamId)
    self.generationName = streamReadString(streamId)
    self.operatingHours = streamReadInt32(streamId)
    self.damage = streamReadFloat32(streamId)
    self.wear = streamReadFloat32(streamId)
    self:run(connection)
end

function UsedItemFoundEvent:run(connection)
    UsedPlus.logDebug(string.format("Used vehicle found: %s (Listing ID: %s, Price: $%.2f)",
        self.storeItemName, self.listingId, self.usedPrice))

    local isLocalFarm = false
    if g_currentMission and g_currentMission.player then
        isLocalFarm = (g_currentMission.player.farmId == self.farmId)
    end

    if isLocalFarm then
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_OK,
            string.format(g_i18n:getText("usedplus_notification_vehicleFound"),
                self.storeItemName, self.generationName, g_i18n:formatMoney(self.usedPrice))
        )

        if g_soundManager then
            g_soundManager:playSample(SoundManager.SOUND_SAMPLES.NOTIFICATION_MONEY)
        end
    end
end

--============================================================================
-- CANCEL SEARCH EVENT
-- Network event for cancelling an active used vehicle search
--============================================================================

CancelSearchEvent = {}
local CancelSearchEvent_mt = Class(CancelSearchEvent, Event)

InitEventClass(CancelSearchEvent, "CancelSearchEvent")

function CancelSearchEvent.emptyNew()
    local self = Event.new(CancelSearchEvent_mt)
    return self
end

function CancelSearchEvent.new(searchId)
    local self = CancelSearchEvent.emptyNew()
    self.searchId = searchId
    return self
end

--[[
    Send cancel request to server
    Convenience method for client-side calls
]]
function CancelSearchEvent.sendToServer(searchId)
    if g_server ~= nil then
        -- Single player or server - execute directly
        CancelSearchEvent.execute(searchId)
    else
        -- Multiplayer client - send to server
        g_client:getServerConnection():sendEvent(CancelSearchEvent.new(searchId))
    end
end

function CancelSearchEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.searchId)
end

function CancelSearchEvent:readStream(streamId, connection)
    self.searchId = streamReadString(streamId)
    self:run(connection)
end

--[[
    Execute the cancellation on server
]]
function CancelSearchEvent.execute(searchId)
    if g_usedVehicleManager == nil then
        UsedPlus.logError("UsedVehicleManager not initialized for cancel")
        return false
    end

    return g_usedVehicleManager:cancelSearch(searchId)
end

function CancelSearchEvent:run(connection)
    if not connection:getIsServer() then
        UsedPlus.logError("CancelSearchEvent must run on server")
        return
    end
    CancelSearchEvent.execute(self.searchId)
end

--============================================================================

UsedPlus.logInfo("UsedMarketEvents loaded (RequestUsedItemEvent, UsedItemFoundEvent, CancelSearchEvent)")
