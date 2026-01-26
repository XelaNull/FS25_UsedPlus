--[[
    TransactionResponseEvent - Universal response for all transactions

    v2.8.0: Part of GitHub Issue #1 fix - Multiplayer Silent Failures

    Problem: When server rejects a request (validation fails, insufficient funds, etc.),
    the client received NO feedback. The server logged an error and returned, but never
    sent a response back to the requesting client.

    Solution: This event sends success/failure notifications back to the requesting client.
    Pattern copied from UsedItemFoundEvent (existing working pattern for server→client).

    Usage in other events:
        TransactionResponseEvent.sendToClient(connection, farmId, success, "messageKey", arg1, arg2)
]]

TransactionResponseEvent = {}
local TransactionResponseEvent_mt = Class(TransactionResponseEvent, Event)

InitEventClass(TransactionResponseEvent, "TransactionResponseEvent")

function TransactionResponseEvent.emptyNew()
    local self = Event.new(TransactionResponseEvent_mt)
    return self
end

function TransactionResponseEvent.new(farmId, success, messageKey, messageArg1, messageArg2)
    local self = TransactionResponseEvent.emptyNew()
    self.farmId = farmId
    self.success = success
    self.messageKey = messageKey or ""
    self.messageArg1 = messageArg1 or ""
    self.messageArg2 = messageArg2 or ""
    return self
end

--[[
    Send response to the client that made the request
    @param connection - The client connection that sent the original request
    @param farmId - Farm ID to filter notifications on client
    @param success - Boolean indicating success/failure
    @param messageKey - i18n key for the message
    @param arg1 - Optional first format argument (string)
    @param arg2 - Optional second format argument (string)
]]
function TransactionResponseEvent.sendToClient(connection, farmId, success, messageKey, arg1, arg2)
    if g_server ~= nil and connection ~= nil then
        -- Only send to actual client connections, not server's own connection
        if connection ~= nil and not connection:getIsServer() then
            connection:sendEvent(TransactionResponseEvent.new(farmId, success, messageKey,
                tostring(arg1 or ""), tostring(arg2 or "")))
        else
            -- For single-player or host, show notification directly
            TransactionResponseEvent.showLocalNotification(farmId, success, messageKey, arg1, arg2)
        end
    end
end

--[[
    Show notification locally (for single-player or server host)
]]
function TransactionResponseEvent.showLocalNotification(farmId, success, messageKey, arg1, arg2)
    -- Only show to local player's farm
    if g_currentMission and g_currentMission.player then
        if g_currentMission.player.farmId ~= farmId then
            return
        end
    end

    -- Skip empty message keys
    if messageKey == nil or messageKey == "" then
        return
    end

    -- Build message with translation
    local message = g_i18n:getText(messageKey)

    -- Handle format arguments
    if arg1 and arg1 ~= "" then
        if arg2 and arg2 ~= "" then
            message = string.format(message, arg1, arg2)
        else
            message = string.format(message, arg1)
        end
    end

    -- Show notification
    local notificationType = success
        and FSBaseMission.INGAME_NOTIFICATION_OK
        or FSBaseMission.INGAME_NOTIFICATION_CRITICAL

    g_currentMission:addIngameNotification(notificationType, message)
end

function TransactionResponseEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId)
    streamWriteBool(streamId, self.success)
    streamWriteString(streamId, self.messageKey)
    streamWriteString(streamId, self.messageArg1)
    streamWriteString(streamId, self.messageArg2)
end

function TransactionResponseEvent:readStream(streamId, connection)
    self.farmId = streamReadInt32(streamId)
    self.success = streamReadBool(streamId)
    self.messageKey = streamReadString(streamId)
    self.messageArg1 = streamReadString(streamId)
    self.messageArg2 = streamReadString(streamId)
    self:run(connection)
end

function TransactionResponseEvent:run(connection)
    -- Only execute on client (connection IS server means we're on client receiving from server)
    if connection ~= nil and not connection:getIsServer() then
        return
    end

    TransactionResponseEvent.showLocalNotification(
        self.farmId,
        self.success,
        self.messageKey,
        self.messageArg1,
        self.messageArg2
    )
end

UsedPlus.logInfo("TransactionResponseEvent loaded")
