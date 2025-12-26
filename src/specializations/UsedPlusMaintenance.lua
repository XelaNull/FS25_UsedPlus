--[[
    FS25_UsedPlus - Maintenance System Vehicle Specialization

    Adds hidden reliability scores and maintenance tracking to vehicles.
    Pattern from: HeadlandManagement headlandManagement.lua

    Features:
    - Hidden reliability scores (engine, hydraulic, electrical)
    - Purchase information tracking (used vs new)
    - Maintenance history (repairs, failures)
    - Runtime failure system (stalling, drift, cutout)
    - Speed degradation based on damage + reliability

    Phase 1: Core data model and save/load
    Phase 2: Failure system (stalling, speed degradation)
    Phase 3: Used market integration
    Phase 4: Inspection system
    Phase 5: Polish (hydraulic drift, cutout, resale)
]]

UsedPlusMaintenance = {}

UsedPlusMaintenance.MOD_NAME = g_currentModName
UsedPlusMaintenance.SPEC_NAME = UsedPlusMaintenance.MOD_NAME .. ".UsedPlusMaintenance"

-- Configuration defaults
UsedPlusMaintenance.CONFIG = {
    -- Feature toggles
    enableFailures = true,
    enableInspection = true,
    enableSpeedDegradation = true,
    enableResaleModifier = true,
    enableHydraulicDrift = true,
    enableElectricalCutout = true,

    -- Balance tuning
    failureRateMultiplier = 1.0,      -- Global failure frequency
    speedDegradationMax = 0.5,        -- Max 50% speed reduction
    inspectionCostBase = 200,         -- Base inspection cost
    inspectionCostPercent = 0.01,     -- + 1% of vehicle price

    -- Thresholds
    damageThresholdForFailures = 0.2, -- Failures start at 20% damage
    reliabilityRepairBonus = 0.15,    -- Each repair adds 15% reliability
    maxReliabilityAfterRepair = 0.95, -- Can never fully restore

    -- Timing
    stallCooldownMs = 30000,          -- 30 seconds between stalls
    updateIntervalMs = 1000,          -- Check failures every 1 second

    -- Hydraulic drift settings
    hydraulicDriftSpeed = 0.001,      -- Radians per second of drift
    hydraulicDriftThreshold = 0.5,    -- Only drift if reliability below 50%

    -- Electrical cutout settings
    cutoutCheckIntervalMs = 5000,     -- Check for cutout every 5 seconds
    cutoutDurationMs = 3000,          -- Cutout lasts 3 seconds
    cutoutBaseChance = 0.03,          -- 3% base chance per check
}

--[[
    Prerequisites check
    Return true to allow spec to load
]]
function UsedPlusMaintenance.prerequisitesPresent(specializations)
    return true
end

--[[
    Initialize specialization - Register XML schema for save/load
    Pattern from: HeadlandManagement initSpecialization
]]
function UsedPlusMaintenance.initSpecialization()
    UsedPlus.logDebug("UsedPlusMaintenance.initSpecialization starting schema registration")

    local schemaSavegame = Vehicle.xmlSchemaSavegame
    local key = "vehicles.vehicle(?)." .. UsedPlusMaintenance.SPEC_NAME

    -- Purchase Information
    schemaSavegame:register(XMLValueType.BOOL,  key .. ".purchasedUsed", "Was this vehicle bought used?", false)
    schemaSavegame:register(XMLValueType.FLOAT, key .. ".purchaseDate", "Game time when purchased", 0)
    schemaSavegame:register(XMLValueType.FLOAT, key .. ".purchasePrice", "What player paid", 0)
    schemaSavegame:register(XMLValueType.FLOAT, key .. ".purchaseDamage", "Damage at time of purchase", 0)
    schemaSavegame:register(XMLValueType.FLOAT, key .. ".purchaseHours", "Operating hours at purchase", 0)
    schemaSavegame:register(XMLValueType.BOOL,  key .. ".wasInspected", "Did player pay for inspection?", false)

    -- Hidden Reliability Scores (0.0-1.0, lower = worse)
    schemaSavegame:register(XMLValueType.FLOAT, key .. ".engineReliability", "Engine reliability score", 1.0)
    schemaSavegame:register(XMLValueType.FLOAT, key .. ".hydraulicReliability", "Hydraulic reliability score", 1.0)
    schemaSavegame:register(XMLValueType.FLOAT, key .. ".electricalReliability", "Electrical reliability score", 1.0)

    -- Maintenance History
    schemaSavegame:register(XMLValueType.INT,   key .. ".repairCount", "Times repaired at shop", 0)
    schemaSavegame:register(XMLValueType.FLOAT, key .. ".totalRepairCost", "Lifetime repair spending", 0)
    schemaSavegame:register(XMLValueType.FLOAT, key .. ".lastRepairDate", "Last shop visit game time", 0)
    schemaSavegame:register(XMLValueType.INT,   key .. ".failureCount", "Total breakdowns experienced", 0)

    -- Inspection Cache (for paid inspections on owned vehicles)
    schemaSavegame:register(XMLValueType.BOOL,  key .. ".hasInspectionCache", "Has a paid inspection been done?", false)
    schemaSavegame:register(XMLValueType.FLOAT, key .. ".inspectionCacheHours", "Operating hours at inspection", 0)
    schemaSavegame:register(XMLValueType.FLOAT, key .. ".inspectionCacheDamage", "Damage level at inspection", 0)
    schemaSavegame:register(XMLValueType.FLOAT, key .. ".inspectionCacheWear", "Wear/paint level at inspection", 0)

    UsedPlus.logDebug("UsedPlusMaintenance schema registration complete")
end

--[[
    Register event listeners for this specialization
    Pattern from: HeadlandManagement registerEventListeners
]]
function UsedPlusMaintenance.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", UsedPlusMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", UsedPlusMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", UsedPlusMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "saveToXMLFile", UsedPlusMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", UsedPlusMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", UsedPlusMaintenance)
end

--[[
    Register overwritten functions
    Pattern from: HeadlandManagement registerOverwrittenFunctions
]]
function UsedPlusMaintenance.registerOverwrittenFunctions(vehicleType)
    -- Phase 2: Will override getCanMotorRun for hard start/no start
    -- SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanMotorRun", UsedPlusMaintenance.getCanMotorRun)
end

--[[
    Called when vehicle is loaded
    Initialize all spec data with defaults
    Pattern from: HeadlandManagement onLoad
]]
function UsedPlusMaintenance:onLoad(savegame)
    -- Make spec accessible via self.spec_usedPlusMaintenance
    self.spec_usedPlusMaintenance = self["spec_" .. UsedPlusMaintenance.SPEC_NAME]
    local spec = self.spec_usedPlusMaintenance

    if spec == nil then
        UsedPlus.logWarn("UsedPlusMaintenance spec not found for vehicle: " .. tostring(self:getName()))
        return
    end

    -- Create dirty flag for network sync
    spec.dirtyFlag = self:getNextDirtyFlag()

    -- Purchase Information
    spec.purchasedUsed = false
    spec.purchaseDate = 0
    spec.purchasePrice = 0
    spec.purchaseDamage = 0
    spec.purchaseHours = 0
    spec.wasInspected = false

    -- Hidden Reliability Scores (1.0 = perfect, 0.0 = broken)
    spec.engineReliability = 1.0
    spec.hydraulicReliability = 1.0
    spec.electricalReliability = 1.0

    -- Maintenance History
    spec.repairCount = 0
    spec.totalRepairCost = 0
    spec.lastRepairDate = 0
    spec.failureCount = 0

    -- Inspection Cache (for paid inspections)
    spec.hasInspectionCache = false
    spec.inspectionCacheHours = 0
    spec.inspectionCacheDamage = 0
    spec.inspectionCacheWear = 0

    -- Runtime State (not persisted)
    spec.updateTimer = 0
    spec.stallCooldown = 0
    spec.isStalled = false
    spec.currentMaxSpeed = nil

    -- Electrical cutout state
    spec.cutoutTimer = 0
    spec.isCutout = false
    spec.cutoutEndTime = 0

    -- Hydraulic drift state
    spec.isDrifting = false

    UsedPlus.logTrace("UsedPlusMaintenance onLoad complete for: " .. tostring(self:getName()))
end

--[[
    Called after vehicle is fully loaded
    Load saved data from savegame if available
    Pattern from: HeadlandManagement onPostLoad
]]
function UsedPlusMaintenance:onPostLoad(savegame)
    local spec = self.spec_usedPlusMaintenance
    if spec == nil then return end

    if savegame ~= nil then
        local xmlFile = savegame.xmlFile
        local key = savegame.key .. "." .. UsedPlusMaintenance.SPEC_NAME

        -- Load purchase information
        spec.purchasedUsed = xmlFile:getValue(key .. ".purchasedUsed", spec.purchasedUsed)
        spec.purchaseDate = xmlFile:getValue(key .. ".purchaseDate", spec.purchaseDate)
        spec.purchasePrice = xmlFile:getValue(key .. ".purchasePrice", spec.purchasePrice)
        spec.purchaseDamage = xmlFile:getValue(key .. ".purchaseDamage", spec.purchaseDamage)
        spec.purchaseHours = xmlFile:getValue(key .. ".purchaseHours", spec.purchaseHours)
        spec.wasInspected = xmlFile:getValue(key .. ".wasInspected", spec.wasInspected)

        -- Load hidden reliability scores
        spec.engineReliability = xmlFile:getValue(key .. ".engineReliability", spec.engineReliability)
        spec.hydraulicReliability = xmlFile:getValue(key .. ".hydraulicReliability", spec.hydraulicReliability)
        spec.electricalReliability = xmlFile:getValue(key .. ".electricalReliability", spec.electricalReliability)

        -- Load maintenance history
        spec.repairCount = xmlFile:getValue(key .. ".repairCount", spec.repairCount)
        spec.totalRepairCost = xmlFile:getValue(key .. ".totalRepairCost", spec.totalRepairCost)
        spec.lastRepairDate = xmlFile:getValue(key .. ".lastRepairDate", spec.lastRepairDate)
        spec.failureCount = xmlFile:getValue(key .. ".failureCount", spec.failureCount)

        -- Load inspection cache
        spec.hasInspectionCache = xmlFile:getValue(key .. ".hasInspectionCache", spec.hasInspectionCache)
        spec.inspectionCacheHours = xmlFile:getValue(key .. ".inspectionCacheHours", spec.inspectionCacheHours)
        spec.inspectionCacheDamage = xmlFile:getValue(key .. ".inspectionCacheDamage", spec.inspectionCacheDamage)
        spec.inspectionCacheWear = xmlFile:getValue(key .. ".inspectionCacheWear", spec.inspectionCacheWear)

        UsedPlus.logTrace(string.format("UsedPlusMaintenance loaded for %s: used=%s, engine=%.2f, repairs=%d",
            self:getName(), tostring(spec.purchasedUsed), spec.engineReliability, spec.repairCount))
    end
end

--[[
    Save vehicle data to XML
    Pattern from: HeadlandManagement saveToXMLFile
]]
function UsedPlusMaintenance:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_usedPlusMaintenance
    if spec == nil then return end

    -- Save purchase information
    xmlFile:setValue(key .. ".purchasedUsed", spec.purchasedUsed)
    xmlFile:setValue(key .. ".purchaseDate", spec.purchaseDate)
    xmlFile:setValue(key .. ".purchasePrice", spec.purchasePrice)
    xmlFile:setValue(key .. ".purchaseDamage", spec.purchaseDamage)
    xmlFile:setValue(key .. ".purchaseHours", spec.purchaseHours)
    xmlFile:setValue(key .. ".wasInspected", spec.wasInspected)

    -- Save hidden reliability scores
    xmlFile:setValue(key .. ".engineReliability", spec.engineReliability)
    xmlFile:setValue(key .. ".hydraulicReliability", spec.hydraulicReliability)
    xmlFile:setValue(key .. ".electricalReliability", spec.electricalReliability)

    -- Save maintenance history
    xmlFile:setValue(key .. ".repairCount", spec.repairCount)
    xmlFile:setValue(key .. ".totalRepairCost", spec.totalRepairCost)
    xmlFile:setValue(key .. ".lastRepairDate", spec.lastRepairDate)
    xmlFile:setValue(key .. ".failureCount", spec.failureCount)

    -- Save inspection cache
    xmlFile:setValue(key .. ".hasInspectionCache", spec.hasInspectionCache)
    xmlFile:setValue(key .. ".inspectionCacheHours", spec.inspectionCacheHours)
    xmlFile:setValue(key .. ".inspectionCacheDamage", spec.inspectionCacheDamage)
    xmlFile:setValue(key .. ".inspectionCacheWear", spec.inspectionCacheWear)

    UsedPlus.logTrace(string.format("UsedPlusMaintenance saved for %s", self:getName()))
end

--[[
    Read data from network stream (multiplayer client join)
    Pattern from: HeadlandManagement onReadStream
]]
function UsedPlusMaintenance:onReadStream(streamId, connection)
    local spec = self.spec_usedPlusMaintenance
    if spec == nil then return end

    -- Purchase info
    spec.purchasedUsed = streamReadBool(streamId)
    spec.purchaseDate = streamReadFloat32(streamId)
    spec.purchasePrice = streamReadFloat32(streamId)
    spec.purchaseDamage = streamReadFloat32(streamId)
    spec.purchaseHours = streamReadFloat32(streamId)
    spec.wasInspected = streamReadBool(streamId)

    -- Reliability scores
    spec.engineReliability = streamReadFloat32(streamId)
    spec.hydraulicReliability = streamReadFloat32(streamId)
    spec.electricalReliability = streamReadFloat32(streamId)

    -- Maintenance history
    spec.repairCount = streamReadInt32(streamId)
    spec.totalRepairCost = streamReadFloat32(streamId)
    spec.lastRepairDate = streamReadFloat32(streamId)
    spec.failureCount = streamReadInt32(streamId)

    -- Inspection cache
    spec.hasInspectionCache = streamReadBool(streamId)
    spec.inspectionCacheHours = streamReadFloat32(streamId)
    spec.inspectionCacheDamage = streamReadFloat32(streamId)
    spec.inspectionCacheWear = streamReadFloat32(streamId)

    UsedPlus.logTrace("UsedPlusMaintenance onReadStream complete")
end

--[[
    Write data to network stream (multiplayer)
    Pattern from: HeadlandManagement onWriteStream
]]
function UsedPlusMaintenance:onWriteStream(streamId, connection)
    local spec = self.spec_usedPlusMaintenance
    if spec == nil then return end

    -- Purchase info
    streamWriteBool(streamId, spec.purchasedUsed)
    streamWriteFloat32(streamId, spec.purchaseDate)
    streamWriteFloat32(streamId, spec.purchasePrice)
    streamWriteFloat32(streamId, spec.purchaseDamage)
    streamWriteFloat32(streamId, spec.purchaseHours)
    streamWriteBool(streamId, spec.wasInspected)

    -- Reliability scores
    streamWriteFloat32(streamId, spec.engineReliability)
    streamWriteFloat32(streamId, spec.hydraulicReliability)
    streamWriteFloat32(streamId, spec.electricalReliability)

    -- Maintenance history
    streamWriteInt32(streamId, spec.repairCount)
    streamWriteFloat32(streamId, spec.totalRepairCost)
    streamWriteFloat32(streamId, spec.lastRepairDate)
    streamWriteInt32(streamId, spec.failureCount)

    -- Inspection cache
    streamWriteBool(streamId, spec.hasInspectionCache)
    streamWriteFloat32(streamId, spec.inspectionCacheHours)
    streamWriteFloat32(streamId, spec.inspectionCacheDamage)
    streamWriteFloat32(streamId, spec.inspectionCacheWear)

    UsedPlus.logTrace("UsedPlusMaintenance onWriteStream complete")
end

--[[
    Called every frame when vehicle is active
    Throttled to check failures every 1 second
    Pattern from: HeadlandManagement onUpdate
]]
function UsedPlusMaintenance:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_usedPlusMaintenance
    if spec == nil then return end

    -- Only process on server
    if not self.isServer then return end

    -- Update stall cooldown
    if spec.stallCooldown > 0 then
        spec.stallCooldown = spec.stallCooldown - dt
    end

    -- Throttle failure checks to every 1 second
    spec.updateTimer = (spec.updateTimer or 0) + dt
    if spec.updateTimer < UsedPlusMaintenance.CONFIG.updateIntervalMs then
        return
    end
    spec.updateTimer = 0

    -- Only check failures if feature is enabled
    if UsedPlusMaintenance.CONFIG.enableFailures then
        UsedPlusMaintenance.checkEngineStall(self)
    end

    -- Always update speed limit (speed degradation)
    if UsedPlusMaintenance.CONFIG.enableSpeedDegradation then
        UsedPlusMaintenance.updateSpeedLimit(self)
    end

    -- Hydraulic drift (implements slowly lower)
    if UsedPlusMaintenance.CONFIG.enableHydraulicDrift then
        UsedPlusMaintenance.checkHydraulicDrift(self, dt)
    end

    -- Electrical cutout (implements randomly shut off)
    if UsedPlusMaintenance.CONFIG.enableElectricalCutout then
        UsedPlusMaintenance.checkImplementCutout(self, dt)
    end
end

--[[
    Calculate failure probability based on damage, reliability, hours, and load
    Returns probability per second (0.0-1.0)

    BALANCE NOTE (v1.2): Completely rewritten so reliability matters even at 0% damage.
    Old system: damage < 20% = no failures (reliability was meaningless after repair)
    New system: Low reliability = baseline failure chance, damage amplifies it

    A vehicle with 50% engine reliability will have ~5x the failure rate of a 100% one.
    Damage now AMPLIFIES failure rate rather than gating it entirely.
]]
function UsedPlusMaintenance.calculateFailureProbability(vehicle, failureType)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec == nil then return 0 end

    -- Get current damage
    local damage = 0
    if vehicle.getDamageAmount then
        damage = vehicle:getDamageAmount() or 0
    end

    -- Get operating hours
    local hours = 0
    if vehicle.getOperatingTime then
        hours = (vehicle:getOperatingTime() or 0) / 3600000  -- Convert ms to hours
    end

    -- Get engine load (0-1)
    local load = 0
    if vehicle.getMotorLoadPercentage then
        load = vehicle:getMotorLoadPercentage() or 0
    end

    -- Get relevant reliability score
    local reliability = 1.0
    if failureType == "engine" then
        reliability = spec.engineReliability or 1.0
    elseif failureType == "hydraulic" then
        reliability = spec.hydraulicReliability or 1.0
    elseif failureType == "electrical" then
        reliability = spec.electricalReliability or 1.0
    end

    -- NEW FORMULA: Reliability is the PRIMARY driver, damage is a multiplier

    -- 1. BASE CHANCE FROM RELIABILITY (this is the key change!)
    -- 100% reliability = virtually no failures (0.001% per second)
    -- 50% reliability = noticeable failures (0.01% per second)
    -- 30% reliability = frequent failures (0.02% per second)
    local reliabilityFactor = math.pow(1 - reliability, 2)  -- Exponential curve
    local baseChance = 0.00001 + (reliabilityFactor * 0.0002)  -- 0.001% to 0.021%

    -- 2. DAMAGE MULTIPLIER (amplifies base chance, doesn't gate it)
    -- 0% damage = 1x multiplier (no change)
    -- 50% damage = 3x multiplier
    -- 100% damage = 5x multiplier
    local damageMultiplier = 1.0 + (damage * 4.0)

    -- 3. HOURS CONTRIBUTION (high hours = slightly more prone to issues)
    -- Caps at +50% after 10,000 hours
    local hoursMultiplier = 1.0 + math.min(hours / 20000, 0.5)

    -- 4. LOAD CONTRIBUTION (high load while damaged = risky)
    -- Only significant when both load AND damage are high
    local loadMultiplier = 1.0 + (load * damage * 2.0)

    -- Combined probability
    local probability = baseChance * damageMultiplier * hoursMultiplier * loadMultiplier
    probability = probability * UsedPlusMaintenance.CONFIG.failureRateMultiplier

    -- Cap at 2% per second max (prevents absurd failure rates)
    return math.min(probability, 0.02)
end

--[[
    Check for engine stall
    Stalling more likely with high damage + low reliability + high load
]]
function UsedPlusMaintenance.checkEngineStall(vehicle)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec == nil then return end

    -- Cooldown check (prevent stalling every frame)
    if spec.stallCooldown > 0 then
        return
    end

    -- Only check running engines
    if vehicle.getIsMotorStarted and not vehicle:getIsMotorStarted() then
        return
    end

    -- Calculate stall probability
    local stallChance = UsedPlusMaintenance.calculateFailureProbability(vehicle, "engine")

    if math.random() < stallChance then
        -- STALL!
        UsedPlusMaintenance.triggerEngineStall(vehicle)
    end
end

--[[
    Actually perform the engine stall
    Stops the motor and notifies the player
]]
function UsedPlusMaintenance.triggerEngineStall(vehicle)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec == nil then return end

    -- Stop the motor
    if vehicle.stopMotor then
        vehicle:stopMotor()
    end

    spec.isStalled = true
    spec.stallCooldown = UsedPlusMaintenance.CONFIG.stallCooldownMs
    spec.failureCount = (spec.failureCount or 0) + 1

    -- Show warning to player
    g_currentMission:showBlinkingWarning(
        g_i18n:getText("usedPlus_engineStalled") or "Engine stalled!",
        5000
    )

    -- Stop AI worker if active
    local rootVehicle = vehicle:getRootVehicle()
    if rootVehicle and rootVehicle.getIsAIActive and rootVehicle:getIsAIActive() then
        if rootVehicle.stopCurrentAIJob then
            -- Try to create error message
            local errorMessage = nil
            if AIMessageErrorVehicleBroken and AIMessageErrorVehicleBroken.new then
                errorMessage = AIMessageErrorVehicleBroken.new()
            end
            rootVehicle:stopCurrentAIJob(errorMessage)
        end
    end

    UsedPlus.logDebug(string.format("Engine stalled on %s (failures: %d)", vehicle:getName(), spec.failureCount))
end

--[[
    Update speed limit based on damage and reliability
    High damage + low reliability = reduced max speed
]]
function UsedPlusMaintenance.updateSpeedLimit(vehicle)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec == nil then return end

    -- Get current damage
    local damage = 0
    if vehicle.getDamageAmount then
        damage = vehicle:getDamageAmount() or 0
    end

    -- Only affect speed if damage is above threshold
    if damage < UsedPlusMaintenance.CONFIG.damageThresholdForFailures then
        spec.currentMaxSpeed = nil  -- No speed limit
        return
    end

    -- Calculate speed reduction factor
    -- 0% damage = 100% speed
    -- 50% damage = 85% speed
    -- 100% damage = 50% speed
    local maxReduction = UsedPlusMaintenance.CONFIG.speedDegradationMax
    local speedFactor = 1 - (damage * maxReduction)

    -- Engine reliability also affects max speed
    local reliabilityFactor = 0.7 + (spec.engineReliability * 0.3)

    local finalFactor = speedFactor * reliabilityFactor
    finalFactor = math.max(finalFactor, 0.3)  -- Never below 30% speed

    -- Apply speed limit via cruise control
    local spec_drivable = vehicle.spec_drivable
    if spec_drivable and spec_drivable.cruiseControl then
        local originalMax = spec_drivable.cruiseControl.maxSpeed or 50
        local limitedMax = originalMax * finalFactor

        -- Store for reference
        spec.currentMaxSpeed = limitedMax

        -- Only limit if cruise control is active and above our limit
        if vehicle.getCruiseControlSpeed and vehicle:getCruiseControlSpeed() > limitedMax then
            if vehicle.setCruiseControlMaxSpeed then
                vehicle:setCruiseControlMaxSpeed(limitedMax, limitedMax)
            end
        end
    end
end

--[[
    Check for hydraulic drift on attached implements
    Poor hydraulic reliability causes raised implements to slowly lower
    Phase 5 feature
]]
function UsedPlusMaintenance.checkHydraulicDrift(vehicle, dt)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec == nil then return end

    -- Only drift if hydraulic reliability is below threshold
    -- BALANCE NOTE (v1.2): Removed damage gate - low reliability causes drift even when repaired
    if spec.hydraulicReliability >= UsedPlusMaintenance.CONFIG.hydraulicDriftThreshold then
        return
    end

    -- Get current damage - amplifies drift speed but doesn't gate it
    local damage = 0
    if vehicle.getDamageAmount then
        damage = vehicle:getDamageAmount() or 0
    end

    -- Calculate drift speed based on reliability (lower = faster drift)
    -- Damage amplifies drift speed (up to 3x at 100% damage)
    local baseSpeed = UsedPlusMaintenance.CONFIG.hydraulicDriftSpeed
    local reliabilityFactor = 1 - spec.hydraulicReliability  -- 0.5 reliability = 0.5 factor
    local damageMultiplier = 1.0 + (damage * 2.0)  -- 0% damage = 1x, 100% = 3x
    local driftSpeed = baseSpeed * reliabilityFactor * damageMultiplier * (dt / 1000)  -- Convert to per-second

    -- Check all child vehicles (attached implements)
    local childVehicles = vehicle:getChildVehicles()
    if childVehicles then
        for _, childVehicle in pairs(childVehicles) do
            UsedPlusMaintenance.applyHydraulicDriftToVehicle(childVehicle, driftSpeed, dt)
        end
    end
end

--[[
    Apply hydraulic drift to a single vehicle's cylindered tools
    @param vehicle - The implement vehicle to check
    @param driftSpeed - How fast to drift (radians per second)
    @param dt - Delta time in milliseconds
]]
function UsedPlusMaintenance.applyHydraulicDriftToVehicle(vehicle, driftSpeed, dt)
    if vehicle.spec_cylindered == nil then return end

    local spec = vehicle.spec_cylindered
    local movingTools = spec.movingTools

    if movingTools == nil then return end

    for i, tool in pairs(movingTools) do
        -- Only process if tool is NOT actively being moved by player
        if tool.move == 0 and tool.node and tool.rotationAxis then
            local curRot = {getRotation(tool.node)}
            local currentAngle = curRot[tool.rotationAxis] or 0

            -- Check if tool is raised (near max rotation)
            local maxRot = tool.rotMax or 0
            local minRot = tool.rotMin or 0

            -- Only drift if above 50% of range (considered "raised")
            local range = maxRot - minRot
            local midpoint = minRot + (range * 0.5)

            if currentAngle > midpoint then
                -- Apply drift toward minimum (lowering)
                local newAngle = currentAngle - driftSpeed

                -- Don't go below midpoint
                if newAngle > midpoint then
                    curRot[tool.rotationAxis] = newAngle
                    setRotation(tool.node, curRot[1], curRot[2], curRot[3])

                    -- Mark dirty for network sync
                    if Cylindered and Cylindered.setDirty then
                        Cylindered.setDirty(vehicle, tool)
                    end

                    -- Only log occasionally to avoid spam
                    if math.random() < 0.01 then
                        UsedPlus.logTrace("Hydraulic drift active on implement")
                    end
                end
            end
        end
    end
end

--[[
    Check for electrical cutout on attached implements
    Poor electrical reliability causes random implement shutoffs
    Phase 5 feature
]]
function UsedPlusMaintenance.checkImplementCutout(vehicle, dt)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec == nil then return end

    -- Handle active cutout
    if spec.isCutout then
        if g_currentMission.time >= spec.cutoutEndTime then
            -- Cutout ended, restore power
            spec.isCutout = false
            UsedPlus.logDebug("Electrical cutout ended - implements restored")
        end
        return  -- Don't check for new cutout while one is active
    end

    -- Update cutout check timer
    spec.cutoutTimer = (spec.cutoutTimer or 0) + dt
    if spec.cutoutTimer < UsedPlusMaintenance.CONFIG.cutoutCheckIntervalMs then
        return
    end
    spec.cutoutTimer = 0

    -- BALANCE NOTE (v1.2): Removed damage gate - low reliability causes cutouts even when repaired
    -- Get current damage (amplifies chance but doesn't gate it)
    local damage = 0
    if vehicle.getDamageAmount then
        damage = vehicle:getDamageAmount() or 0
    end

    -- Calculate cutout probability based on electrical reliability
    -- NEW FORMULA: Low reliability = base chance, damage amplifies it
    local baseChance = UsedPlusMaintenance.CONFIG.cutoutBaseChance
    local reliabilityFactor = math.pow(1 - spec.electricalReliability, 2)  -- Exponential: 50% = 0.25, 30% = 0.49
    local damageMultiplier = 1.0 + (damage * 3.0)  -- 0% damage = 1x, 100% = 4x
    local cutoutChance = baseChance * reliabilityFactor * damageMultiplier * UsedPlusMaintenance.CONFIG.failureRateMultiplier

    if math.random() < cutoutChance then
        -- CUTOUT!
        UsedPlusMaintenance.triggerImplementCutout(vehicle)
    end
end

--[[
    Trigger an electrical cutout - implements stop working temporarily
]]
function UsedPlusMaintenance.triggerImplementCutout(vehicle)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec == nil then return end

    spec.isCutout = true
    spec.cutoutEndTime = g_currentMission.time + UsedPlusMaintenance.CONFIG.cutoutDurationMs
    spec.failureCount = (spec.failureCount or 0) + 1

    -- Try to raise/stop implements
    if vehicle.getAttachedAIImplements then
        local implements = vehicle:getAttachedAIImplements()
        if implements then
            for _, implement in pairs(implements) do
                if implement.object and implement.object.aiImplementEndLine then
                    implement.object:aiImplementEndLine()
                end
            end
        end
    end

    -- Also try direct child vehicles
    local childVehicles = vehicle:getChildVehicles()
    if childVehicles then
        for _, childVehicle in pairs(childVehicles) do
            if childVehicle.aiImplementEndLine then
                childVehicle:aiImplementEndLine()
            end
            -- Turn off PTO if possible
            if childVehicle.setIsTurnedOn then
                childVehicle:setIsTurnedOn(false)
            end
        end
    end

    -- Show warning to player
    g_currentMission:showBlinkingWarning(
        g_i18n:getText("usedPlus_electricalCutout") or "Electrical fault - implements offline!",
        3000
    )

    -- Stop AI worker if active
    local rootVehicle = vehicle:getRootVehicle()
    if rootVehicle and rootVehicle.getIsAIActive and rootVehicle:getIsAIActive() then
        if rootVehicle.stopCurrentAIJob then
            local errorMessage = nil
            if AIMessageErrorVehicleBroken and AIMessageErrorVehicleBroken.new then
                errorMessage = AIMessageErrorVehicleBroken.new()
            end
            rootVehicle:stopCurrentAIJob(errorMessage)
        end
    end

    UsedPlus.logDebug(string.format("Electrical cutout on %s (failures: %d)", vehicle:getName(), spec.failureCount))
end

--[[
    PUBLIC API: Set maintenance data when purchasing a used vehicle
    Called from UsedVehicleManager when purchase completes
]]
function UsedPlusMaintenance.setUsedPurchaseData(vehicle, usedPlusData)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec == nil then
        UsedPlus.logWarn("Cannot set used purchase data - spec not found")
        return false
    end

    -- Mark as purchased used
    spec.purchasedUsed = true
    spec.purchaseDate = g_currentMission.environment.dayTime or 0
    spec.purchasePrice = usedPlusData.price or 0
    spec.purchaseDamage = usedPlusData.damage or 0
    spec.purchaseHours = usedPlusData.operatingHours or 0
    spec.wasInspected = usedPlusData.wasInspected or false

    -- Transfer hidden reliability scores
    spec.engineReliability = usedPlusData.engineReliability or 1.0
    spec.hydraulicReliability = usedPlusData.hydraulicReliability or 1.0
    spec.electricalReliability = usedPlusData.electricalReliability or 1.0

    -- Initialize maintenance history
    spec.repairCount = 0
    spec.totalRepairCost = 0
    spec.failureCount = 0

    UsedPlus.logDebug(string.format("Set used purchase data for %s: engine=%.2f, hydraulic=%.2f, electrical=%.2f",
        vehicle:getName(), spec.engineReliability, spec.hydraulicReliability, spec.electricalReliability))

    return true
end

--[[
    PUBLIC API: Get current reliability data for a vehicle
    Used for inspection reports and vehicle info display
]]
function UsedPlusMaintenance.getReliabilityData(vehicle)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec == nil then
        return nil
    end

    return {
        purchasedUsed = spec.purchasedUsed,
        wasInspected = spec.wasInspected,
        engineReliability = spec.engineReliability,
        hydraulicReliability = spec.hydraulicReliability,
        electricalReliability = spec.electricalReliability,
        repairCount = spec.repairCount,
        totalRepairCost = spec.totalRepairCost,
        failureCount = spec.failureCount,
        avgReliability = (spec.engineReliability + spec.hydraulicReliability + spec.electricalReliability) / 3
    }
end

--[[
    PUBLIC API: Update reliability after repair
    Called from VehicleSellingPointExtension when repair completes
]]
function UsedPlusMaintenance.onVehicleRepaired(vehicle, repairCost)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec == nil then return end

    -- Update maintenance history
    spec.repairCount = spec.repairCount + 1
    spec.totalRepairCost = spec.totalRepairCost + repairCost
    spec.lastRepairDate = g_currentMission.environment.dayTime or 0

    -- Repairs improve reliability (but never back to 100%)
    local repairBonus = UsedPlusMaintenance.CONFIG.reliabilityRepairBonus
    local maxReliability = UsedPlusMaintenance.CONFIG.maxReliabilityAfterRepair

    spec.engineReliability = math.min(maxReliability, spec.engineReliability + repairBonus)
    spec.hydraulicReliability = math.min(maxReliability, spec.hydraulicReliability + repairBonus)
    spec.electricalReliability = math.min(maxReliability, spec.electricalReliability + repairBonus)

    UsedPlus.logDebug(string.format("Vehicle repaired: %s - reliability now: engine=%.2f, hydraulic=%.2f, electrical=%.2f",
        vehicle:getName(), spec.engineReliability, spec.hydraulicReliability, spec.electricalReliability))
end

--[[
    PUBLIC API: Generate random reliability scores for a used vehicle listing
    Called from UsedVehicleManager when generating sale items
]]
function UsedPlusMaintenance.generateReliabilityScores(damage)
    -- Base reliability inversely related to damage
    local reliabilityBase = 1 - (damage or 0)

    -- Add variance - a high-damage vehicle MIGHT have good engine, or might not
    local function randomVariance(maxVariance)
        return (math.random() * 2 - 1) * maxVariance
    end

    local engineReliability = reliabilityBase + randomVariance(0.2)
    local hydraulicReliability = reliabilityBase + randomVariance(0.25)
    local electricalReliability = reliabilityBase + randomVariance(0.15)

    -- Clamp to 0.1-1.0 (never completely dead, never perfect if used)
    engineReliability = math.max(0.1, math.min(1.0, engineReliability))
    hydraulicReliability = math.max(0.1, math.min(1.0, hydraulicReliability))
    electricalReliability = math.max(0.1, math.min(1.0, electricalReliability))

    return {
        engineReliability = engineReliability,
        hydraulicReliability = hydraulicReliability,
        electricalReliability = electricalReliability,
        wasInspected = false
    }
end

--[[
    PUBLIC API: Get rating text for reliability score
    Returns rating string and icon for inspection reports
]]
function UsedPlusMaintenance.getRatingText(reliability)
    if reliability >= 0.8 then
        return "Good", "✓"
    elseif reliability >= 0.6 then
        return "Acceptable", "✓"
    elseif reliability >= 0.4 then
        return "Below Average", "⚠"
    elseif reliability >= 0.2 then
        return "Poor", "⚠"
    else
        return "Critical", "✗"
    end
end

--[[
    PUBLIC API: Generate inspector notes based on reliability data
    Used in inspection reports
]]
function UsedPlusMaintenance.generateInspectorNotes(reliabilityData)
    local notes = {}

    if reliabilityData.engineReliability < 0.5 then
        table.insert(notes, "Engine shows signs of hard use. Expect occasional stalling under load.")
    end
    if reliabilityData.hydraulicReliability < 0.5 then
        table.insert(notes, "Hydraulic system worn. Implements may drift when raised.")
    end
    if reliabilityData.electricalReliability < 0.5 then
        table.insert(notes, "Electrical issues detected. Implements may cut out unexpectedly.")
    end

    if #notes == 0 then
        table.insert(notes, "Vehicle in acceptable mechanical condition.")
    end

    return table.concat(notes, " ")
end

--[[
    PUBLIC API: Get current vehicle state for inspection comparison
    Returns hours, damage, wear values
]]
function UsedPlusMaintenance.getCurrentVehicleState(vehicle)
    local hours = 0
    if vehicle.getOperatingTime then
        hours = math.floor((vehicle:getOperatingTime() or 0) / 3600000)  -- Convert ms to hours
    end

    local damage = 0
    if vehicle.getDamageAmount then
        damage = vehicle:getDamageAmount() or 0
    end

    local wear = 0
    if vehicle.getWearTotalAmount then
        wear = vehicle:getWearTotalAmount() or 0
    end

    return {
        hours = hours,
        damage = damage,
        wear = wear
    }
end

--[[
    PUBLIC API: Check if inspection cache is still valid
    Returns true if cache exists AND vehicle state hasn't changed significantly
    @param vehicle - The vehicle to check
    @param tolerance - How much change is allowed before requiring new inspection (default 0.05 = 5%)
]]
function UsedPlusMaintenance.isInspectionCacheValid(vehicle, tolerance)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec == nil then
        return false
    end

    -- No cache exists
    if not spec.hasInspectionCache then
        return false
    end

    tolerance = tolerance or 0.05  -- 5% tolerance by default

    -- Get current state
    local currentState = UsedPlusMaintenance.getCurrentVehicleState(vehicle)

    -- Compare with cached values
    local hoursDiff = math.abs(currentState.hours - spec.inspectionCacheHours)
    local damageDiff = math.abs(currentState.damage - spec.inspectionCacheDamage)
    local wearDiff = math.abs(currentState.wear - spec.inspectionCacheWear)

    -- Hours: allow 10 hours difference before requiring new inspection
    if hoursDiff > 10 then
        UsedPlus.logDebug(string.format("Inspection cache invalid: hours changed by %d", hoursDiff))
        return false
    end

    -- Damage: any significant change invalidates cache
    if damageDiff > tolerance then
        UsedPlus.logDebug(string.format("Inspection cache invalid: damage changed by %.1f%%", damageDiff * 100))
        return false
    end

    -- Wear: any significant change invalidates cache
    if wearDiff > tolerance then
        UsedPlus.logDebug(string.format("Inspection cache invalid: wear changed by %.1f%%", wearDiff * 100))
        return false
    end

    UsedPlus.logDebug("Inspection cache is still valid")
    return true
end

--[[
    PUBLIC API: Update inspection cache with current vehicle state
    Called after player pays for inspection
    @param vehicle - The vehicle to cache
]]
function UsedPlusMaintenance.updateInspectionCache(vehicle)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec == nil then
        UsedPlus.logWarn("Cannot update inspection cache - spec not found")
        return false
    end

    local currentState = UsedPlusMaintenance.getCurrentVehicleState(vehicle)

    spec.hasInspectionCache = true
    spec.inspectionCacheHours = currentState.hours
    spec.inspectionCacheDamage = currentState.damage
    spec.inspectionCacheWear = currentState.wear

    UsedPlus.logDebug(string.format("Inspection cache updated: hours=%d, damage=%.1f%%, wear=%.1f%%",
        currentState.hours, currentState.damage * 100, currentState.wear * 100))

    return true
end

--[[
    PUBLIC API: Clear inspection cache (e.g., after major repairs)
    @param vehicle - The vehicle to clear cache for
]]
function UsedPlusMaintenance.clearInspectionCache(vehicle)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec == nil then
        return
    end

    spec.hasInspectionCache = false
    spec.inspectionCacheHours = 0
    spec.inspectionCacheDamage = 0
    spec.inspectionCacheWear = 0

    UsedPlus.logDebug("Inspection cache cleared")
end

--[[
    Inspection fee constant
]]
UsedPlusMaintenance.INSPECTION_FEE = 500

UsedPlus.logInfo("UsedPlusMaintenance specialization loaded")
