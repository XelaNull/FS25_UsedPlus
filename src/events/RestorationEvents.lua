--[[
    FS25_UsedPlus - Restoration Events for Multiplayer

    Handles synchronization of restoration state between server and clients:
    - StartRestorationEvent: Begin restoration on a vehicle
    - StopRestorationEvent: Stop/complete restoration
    - RestorationProgressEvent: Sync progress updates

    v2.9.0 - Service Truck System
]]

--[[
    ===============================================
    StartRestorationEvent
    Sent when a service truck starts restoring a vehicle
    ===============================================
]]

StartRestorationEvent = {}
StartRestorationEvent_mt = Class(StartRestorationEvent, Event)

InitEventClass(StartRestorationEvent, "StartRestorationEvent")

function StartRestorationEvent.emptyNew()
    local self = Event.new(StartRestorationEvent_mt)
    return self
end

function StartRestorationEvent.new(serviceTruck, targetVehicle, component)
    local self = StartRestorationEvent.emptyNew()
    self.serviceTruck = serviceTruck
    self.targetVehicle = targetVehicle
    self.component = component
    return self
end

function StartRestorationEvent:readStream(streamId, connection)
    self.serviceTruck = NetworkUtil.readNodeObject(streamId)
    self.targetVehicle = NetworkUtil.readNodeObject(streamId)
    self.component = streamReadString(streamId)
    self:run(connection)
end

function StartRestorationEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.serviceTruck)
    NetworkUtil.writeNodeObject(streamId, self.targetVehicle)
    streamWriteString(streamId, self.component or "")
end

function StartRestorationEvent:run(connection)
    if self.serviceTruck ~= nil and self.targetVehicle ~= nil then
        -- Execute on server
        if g_server ~= nil then
            self.serviceTruck:startRestoration(self.targetVehicle, self.component)

            -- Broadcast to all clients
            g_server:broadcastEvent(StartRestorationEvent.new(self.serviceTruck, self.targetVehicle, self.component), nil, connection)
        else
            -- Execute on client (from server broadcast)
            local spec = self.serviceTruck.spec_serviceTruck
            if spec ~= nil then
                spec.isRestoring = true
                spec.restorationData = {
                    targetVehicle = self.targetVehicle,
                    component = self.component,
                    startTime = g_currentMission.time,
                    progress = 0
                }
                self.serviceTruck:immobilizeTarget(self.targetVehicle)
            end
        end
    end
end

function StartRestorationEvent.sendToServer(serviceTruck, targetVehicle, component)
    if g_client ~= nil then
        g_client:getServerConnection():sendEvent(StartRestorationEvent.new(serviceTruck, targetVehicle, component))
    end
end


--[[
    ===============================================
    StopRestorationEvent
    Sent when restoration is stopped or completed
    ===============================================
]]

StopRestorationEvent = {}
StopRestorationEvent_mt = Class(StopRestorationEvent, Event)

InitEventClass(StopRestorationEvent, "StopRestorationEvent")

function StopRestorationEvent.emptyNew()
    local self = Event.new(StopRestorationEvent_mt)
    return self
end

function StopRestorationEvent.new(serviceTruck, releaseVehicle, completed)
    local self = StopRestorationEvent.emptyNew()
    self.serviceTruck = serviceTruck
    self.releaseVehicle = releaseVehicle or false
    self.completed = completed or false
    return self
end

function StopRestorationEvent:readStream(streamId, connection)
    self.serviceTruck = NetworkUtil.readNodeObject(streamId)
    self.releaseVehicle = streamReadBool(streamId)
    self.completed = streamReadBool(streamId)
    self:run(connection)
end

function StopRestorationEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.serviceTruck)
    streamWriteBool(streamId, self.releaseVehicle)
    streamWriteBool(streamId, self.completed)
end

function StopRestorationEvent:run(connection)
    if self.serviceTruck ~= nil then
        if g_server ~= nil then
            self.serviceTruck:stopRestoration(self.releaseVehicle)

            -- Broadcast to all clients
            g_server:broadcastEvent(StopRestorationEvent.new(self.serviceTruck, self.releaseVehicle, self.completed), nil, connection)
        else
            -- Execute on client
            local spec = self.serviceTruck.spec_serviceTruck
            if spec ~= nil then
                if spec.restorationData ~= nil and self.releaseVehicle then
                    self.serviceTruck:releaseTarget(spec.restorationData.targetVehicle)
                end
                spec.isRestoring = false
                spec.restorationData = nil
            end
        end
    end
end

function StopRestorationEvent.sendToServer(serviceTruck, releaseVehicle, completed)
    if g_client ~= nil then
        g_client:getServerConnection():sendEvent(StopRestorationEvent.new(serviceTruck, releaseVehicle, completed))
    end
end


--[[
    ===============================================
    RestorationProgressEvent
    Periodic sync of restoration progress
    ===============================================
]]

RestorationProgressEvent = {}
RestorationProgressEvent_mt = Class(RestorationProgressEvent, Event)

InitEventClass(RestorationProgressEvent, "RestorationProgressEvent")

function RestorationProgressEvent.emptyNew()
    local self = Event.new(RestorationProgressEvent_mt)
    return self
end

function RestorationProgressEvent.new(serviceTruck, progress, currentReliability, currentCeiling)
    local self = RestorationProgressEvent.emptyNew()
    self.serviceTruck = serviceTruck
    self.progress = progress or 0
    self.currentReliability = currentReliability or 0
    self.currentCeiling = currentCeiling or 1.0
    return self
end

function RestorationProgressEvent:readStream(streamId, connection)
    self.serviceTruck = NetworkUtil.readNodeObject(streamId)
    self.progress = streamReadFloat32(streamId)
    self.currentReliability = streamReadFloat32(streamId)
    self.currentCeiling = streamReadFloat32(streamId)
    self:run(connection)
end

function RestorationProgressEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.serviceTruck)
    streamWriteFloat32(streamId, self.progress)
    streamWriteFloat32(streamId, self.currentReliability)
    streamWriteFloat32(streamId, self.currentCeiling)
end

function RestorationProgressEvent:run(connection)
    if self.serviceTruck ~= nil then
        local spec = self.serviceTruck.spec_serviceTruck
        if spec ~= nil and spec.restorationData ~= nil then
            spec.restorationData.progress = self.progress

            -- Update target vehicle reliability on client
            local targetVehicle = spec.restorationData.targetVehicle
            if targetVehicle ~= nil and targetVehicle.spec_usedPlusMaintenance ~= nil then
                local maintSpec = targetVehicle.spec_usedPlusMaintenance
                local component = spec.restorationData.component

                if component == "engine" then
                    maintSpec.engineReliability = self.currentReliability
                elseif component == "electrical" then
                    maintSpec.electricalReliability = self.currentReliability
                elseif component == "hydraulic" then
                    maintSpec.hydraulicReliability = self.currentReliability
                end

                maintSpec.maxReliabilityCeiling = self.currentCeiling
            end
        end
    end
end


--[[
    ===============================================
    SetRestorationCooldownEvent
    Sync cooldown state after failed inspection
    ===============================================
]]

SetRestorationCooldownEvent = {}
SetRestorationCooldownEvent_mt = Class(SetRestorationCooldownEvent, Event)

InitEventClass(SetRestorationCooldownEvent, "SetRestorationCooldownEvent")

function SetRestorationCooldownEvent.emptyNew()
    local self = Event.new(SetRestorationCooldownEvent_mt)
    return self
end

function SetRestorationCooldownEvent.new(vehicle, component, cooldownEnd)
    local self = SetRestorationCooldownEvent.emptyNew()
    self.vehicle = vehicle
    self.component = component
    self.cooldownEnd = cooldownEnd
    return self
end

function SetRestorationCooldownEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.component = streamReadString(streamId)
    self.cooldownEnd = streamReadFloat32(streamId)
    self:run(connection)
end

function SetRestorationCooldownEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteString(streamId, self.component or "")
    streamWriteFloat32(streamId, self.cooldownEnd or 0)
end

function SetRestorationCooldownEvent:run(connection)
    if self.vehicle ~= nil then
        RestorationData.setCooldown(self.vehicle, self.component, self.cooldownEnd)

        if g_server ~= nil then
            -- Broadcast to all clients
            g_server:broadcastEvent(SetRestorationCooldownEvent.new(self.vehicle, self.component, self.cooldownEnd), nil, connection)
        end
    end
end

function SetRestorationCooldownEvent.sendToServer(vehicle, component, cooldownEnd)
    if g_client ~= nil then
        g_client:getServerConnection():sendEvent(SetRestorationCooldownEvent.new(vehicle, component, cooldownEnd))
    end
end


UsedPlus.logInfo("RestorationEvents loaded - Multiplayer sync ready")
