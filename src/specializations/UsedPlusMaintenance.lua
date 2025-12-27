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
    enableSteeringDegradation = true, -- v1.5.1: Worn steering feels loose/sloppy
    enableResaleModifier = true,
    enableHydraulicDrift = true,
    enableElectricalCutout = true,
    enableLemonScale = true,          -- Workhorse/Lemon DNA system

    -- Balance tuning
    failureRateMultiplier = 1.0,      -- Global failure frequency
    speedDegradationMax = 0.5,        -- Max 50% speed reduction
    inspectionCostBase = 200,         -- Base inspection cost
    inspectionCostPercent = 0.01,     -- + 1% of vehicle price

    -- Thresholds
    damageThresholdForFailures = 0.2, -- Failures start at 20% damage
    reliabilityRepairBonus = 0.15,    -- Each repair adds 15% reliability
    maxReliabilityAfterRepair = 0.95, -- Can never fully restore (legacy, superseded by ceiling)

    -- Workhorse/Lemon Scale settings (v1.4.0+)
    ceilingDegradationMax = 0.01,     -- Max 1% ceiling loss per repair (for lemons)
    minReliabilityCeiling = 0.30,     -- Ceiling can never go below 30%

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

    -- v1.5.1: Stall recovery settings
    stallRecoveryDurationMs = 5000,   -- 5 seconds before engine can restart after stall
}

--[[
    Inspector Quote System (v1.4.0)
    50 quotes across 10 tiers that hint at vehicle DNA quality
    Each tier has 5 quotes: 2 technical, 2 superstitious, 1 country
]]
UsedPlusMaintenance.INSPECTOR_QUOTES = {
    catastrophic = {  -- 0.00 - 0.09
        "usedplus_quote_cat_1",
        "usedplus_quote_cat_2",
        "usedplus_quote_cat_3",
        "usedplus_quote_cat_4",
        "usedplus_quote_cat_5",
    },
    terrible = {  -- 0.10 - 0.19
        "usedplus_quote_ter_1",
        "usedplus_quote_ter_2",
        "usedplus_quote_ter_3",
        "usedplus_quote_ter_4",
        "usedplus_quote_ter_5",
    },
    poor = {  -- 0.20 - 0.29
        "usedplus_quote_poor_1",
        "usedplus_quote_poor_2",
        "usedplus_quote_poor_3",
        "usedplus_quote_poor_4",
        "usedplus_quote_poor_5",
    },
    belowAverage = {  -- 0.30 - 0.39
        "usedplus_quote_below_1",
        "usedplus_quote_below_2",
        "usedplus_quote_below_3",
        "usedplus_quote_below_4",
        "usedplus_quote_below_5",
    },
    slightlyBelow = {  -- 0.40 - 0.49
        "usedplus_quote_slight_1",
        "usedplus_quote_slight_2",
        "usedplus_quote_slight_3",
        "usedplus_quote_slight_4",
        "usedplus_quote_slight_5",
    },
    average = {  -- 0.50 - 0.59
        "usedplus_quote_avg_1",
        "usedplus_quote_avg_2",
        "usedplus_quote_avg_3",
        "usedplus_quote_avg_4",
        "usedplus_quote_avg_5",
    },
    aboveAverage = {  -- 0.60 - 0.69
        "usedplus_quote_above_1",
        "usedplus_quote_above_2",
        "usedplus_quote_above_3",
        "usedplus_quote_above_4",
        "usedplus_quote_above_5",
    },
    good = {  -- 0.70 - 0.79
        "usedplus_quote_good_1",
        "usedplus_quote_good_2",
        "usedplus_quote_good_3",
        "usedplus_quote_good_4",
        "usedplus_quote_good_5",
    },
    excellent = {  -- 0.80 - 0.89
        "usedplus_quote_exc_1",
        "usedplus_quote_exc_2",
        "usedplus_quote_exc_3",
        "usedplus_quote_exc_4",
        "usedplus_quote_exc_5",
    },
    legendary = {  -- 0.90 - 1.00
        "usedplus_quote_leg_1",
        "usedplus_quote_leg_2",
        "usedplus_quote_leg_3",
        "usedplus_quote_leg_4",
        "usedplus_quote_leg_5",
    },
}

--[[
    Quality Tier → DNA Distribution Correlation (v1.4.0)
    Higher quality tiers bias toward workhorses, lower toward lemons
    This adds risk/reward dynamics to tier selection

    Order: 1=Any, 2=Poor, 3=Fair, 4=Good, 5=Excellent
    Must match UsedSearchDialog.QUALITY_TIERS order!
]]
UsedPlusMaintenance.QUALITY_DNA_RANGES = {
    [1] = { min = 0.00, max = 0.85, avg = 0.40 },  -- Any: Wide variance
    [2] = { min = 0.00, max = 0.70, avg = 0.30 },  -- Poor: High lemon risk (~45%)
    [3] = { min = 0.15, max = 0.85, avg = 0.50 },  -- Fair: Balanced
    [4] = { min = 0.30, max = 0.95, avg = 0.60 },  -- Good: Quality bias (~5% lemon, ~20% workhorse)
    [5] = { min = 0.50, max = 1.00, avg = 0.75 },  -- Excellent: Workhorse bias (~0% lemon, ~40% workhorse)
}

--[[
    Get inspector quote based on workhorse/lemon scale
    Returns localized quote text from the appropriate tier
    @param workhorseLemonScale - The vehicle's hidden quality score (0.0-1.0)
    @return string - Localized quote text
]]
function UsedPlusMaintenance.getInspectorQuote(workhorseLemonScale)
    local quotes = UsedPlusMaintenance.INSPECTOR_QUOTES

    -- Determine tier based on scale (10 tiers, 0.1 each)
    local tier
    if workhorseLemonScale < 0.10 then
        tier = "catastrophic"
    elseif workhorseLemonScale < 0.20 then
        tier = "terrible"
    elseif workhorseLemonScale < 0.30 then
        tier = "poor"
    elseif workhorseLemonScale < 0.40 then
        tier = "belowAverage"
    elseif workhorseLemonScale < 0.50 then
        tier = "slightlyBelow"
    elseif workhorseLemonScale < 0.60 then
        tier = "average"
    elseif workhorseLemonScale < 0.70 then
        tier = "aboveAverage"
    elseif workhorseLemonScale < 0.80 then
        tier = "good"
    elseif workhorseLemonScale < 0.90 then
        tier = "excellent"
    else
        tier = "legendary"
    end

    -- Select random quote from tier
    local tierQuotes = quotes[tier]
    local quoteKey = tierQuotes[math.random(#tierQuotes)]

    -- Return localized text (with fallback)
    local text = g_i18n:getText(quoteKey)
    if text == quoteKey then
        -- Translation not found, return a generic message
        return "Vehicle condition assessed."
    end
    return text
end

--[[
    Generate workhorse/lemon scale for a NEW vehicle (from dealership)
    New vehicles have slight quality bias - dealerships don't sell obvious lemons
    Range: 0.3 to 1.0, average ~0.6
]]
function UsedPlusMaintenance.generateNewVehicleScale()
    -- Bell curve centered at 0.6 using sum of randoms
    local r1 = math.random()
    local r2 = math.random()
    local scale = 0.3 + (r1 * 0.5) + (r2 * 0.2)
    return math.min(1.0, math.max(0.0, scale))
end

--[[
    Generate workhorse/lemon scale for a USED vehicle (from used market)
    DNA distribution is now correlated with quality tier (v1.4.0)

    @param qualityLevel - Optional quality tier (1=Any, 2=Poor, 3=Fair, 4=Good, 5=Excellent)
    @return scale - DNA value 0.0 (lemon) to 1.0 (workhorse)
]]
function UsedPlusMaintenance.generateUsedVehicleScale(qualityLevel)
    -- Get DNA range for quality tier (default to "Any" if not specified)
    local dnaRange = UsedPlusMaintenance.QUALITY_DNA_RANGES[qualityLevel]
    if dnaRange == nil then
        dnaRange = UsedPlusMaintenance.QUALITY_DNA_RANGES[1]  -- Default to "Any"
    end

    -- Bell curve within tier's range using sum of 2 randoms
    local r1 = math.random()
    local r2 = math.random()
    local rangeWidth = dnaRange.max - dnaRange.min
    local scale = dnaRange.min + ((r1 + r2) / 2) * rangeWidth

    UsedPlus.logDebug(string.format("Generated DNA: qualityLevel=%d, range=[%.2f-%.2f], result=%.3f",
        qualityLevel or 1, dnaRange.min, dnaRange.max, scale))

    return math.min(1.0, math.max(0.0, scale))
end

--[[
    Calculate initial ceiling for used vehicle based on previous ownership
    Simulates unknown repair history from age and hours
    @param workhorseLemonScale - The vehicle's DNA (0.0-1.0)
    @param estimatedPreviousRepairs - Estimated from age/hours
    @return Initial ceiling value (0.3-1.0)
]]
function UsedPlusMaintenance.calculateInitialCeiling(workhorseLemonScale, estimatedPreviousRepairs)
    -- Degradation rate based on DNA: Lemons (0.0) = 1%, Workhorses (1.0) = 0%
    local degradationRate = (1 - workhorseLemonScale) * UsedPlusMaintenance.CONFIG.ceilingDegradationMax
    local totalDegradation = degradationRate * estimatedPreviousRepairs
    local ceiling = 1.0 - totalDegradation
    return math.max(UsedPlusMaintenance.CONFIG.minReliabilityCeiling, ceiling)
end

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

    -- Workhorse/Lemon Scale System (v1.4.0+)
    schemaSavegame:register(XMLValueType.FLOAT, key .. ".workhorseLemonScale", "Hidden quality DNA (0=lemon, 1=workhorse)", 0.5)
    schemaSavegame:register(XMLValueType.FLOAT, key .. ".maxReliabilityCeiling", "Current max achievable reliability", 1.0)

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
    -- v1.5.1: Listen for vehicle enter to trigger first-start stall check
    SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", UsedPlusMaintenance)
end

--[[
    Register overwritten functions
    Pattern from: HeadlandManagement registerOverwrittenFunctions
]]
function UsedPlusMaintenance.registerOverwrittenFunctions(vehicleType)
    -- v1.5.1: Override getCanMotorRun for stall recovery period and speed governor
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanMotorRun", UsedPlusMaintenance.getCanMotorRun)

    -- v1.5.1: Override setSteeringInput for steering degradation (loose steering on worn hydraulics)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "setSteeringInput", UsedPlusMaintenance.setSteeringInput)
end

--[[
    v1.5.1: Override getCanMotorRun to enforce:
    1. Stall recovery period (prevents instant restart after stall)
    2. Speed governor (cuts power when over reliability-based max speed)

    The speed governor acts like a rev limiter - when you exceed the max speed
    your engine can sustain, power cuts briefly until you drop back below.
    This is more realistic than applying brakes (no brake lights).
]]
function UsedPlusMaintenance:getCanMotorRun(superFunc)
    local spec = self.spec_usedPlusMaintenance
    if spec == nil then
        return superFunc(self)
    end

    -- Check if in stall recovery period
    if spec.stallRecoveryEndTime and spec.stallRecoveryEndTime > 0 then
        local currentTime = g_currentMission.time or 0
        if currentTime < spec.stallRecoveryEndTime then
            -- Still in recovery - engine cannot run
            return false
        else
            -- Recovery complete - clear the timer
            spec.stallRecoveryEndTime = 0
        end
    end

    -- v1.5.1: Speed governor - cut motor when significantly over reliability-based max speed
    -- This acts like a speed limiter/rev limiter - power cuts when you exceed what the worn engine can sustain
    -- NOTE: Skip governor check during stall recovery (engine is already off, no need for governor warning)
    local inStallRecovery = spec.stallRecoveryEndTime and spec.stallRecoveryEndTime > 0
    if not inStallRecovery and UsedPlusMaintenance.CONFIG.enableSpeedDegradation and spec.maxSpeedFactor and spec.maxSpeedFactor < 0.95 then
        local currentSpeed = 0
        if self.getLastSpeed then
            currentSpeed = self:getLastSpeed()  -- km/h
        end

        -- Calculate max speed based on vehicle's base max and our degradation factor
        local baseMaxSpeed = 50  -- Default fallback
        if self.spec_drivable and self.spec_drivable.cruiseControl then
            baseMaxSpeed = self.spec_drivable.cruiseControl.maxSpeed or 50
        end
        local degradedMaxSpeed = baseMaxSpeed * spec.maxSpeedFactor

        -- Allow 3 km/h grace before cutting (prevents constant flickering at the limit)
        local overspeedThreshold = degradedMaxSpeed + 3

        if currentSpeed > overspeedThreshold then
            -- Over speed - cut power (acts like hitting a governor/rev limiter)
            -- Use pulsing to allow brief power bursts (feels more natural than hard cut)
            spec.governorPulseTimer = (spec.governorPulseTimer or 0) + 1
            if spec.governorPulseTimer % 3 ~= 0 then  -- Cut 2 out of every 3 frames
                -- Show warning first time
                if not spec.hasShownGovernorWarning then
                    g_currentMission:showBlinkingWarning(
                        g_i18n:getText("usedPlus_speedGovernor") or "Engine struggling at this speed!",
                        2000
                    )
                    spec.hasShownGovernorWarning = true
                end
                return false
            end
        else
            spec.governorPulseTimer = 0
            spec.hasShownGovernorWarning = false
        end
    end

    -- Normal check
    return superFunc(self)
end

--[[
    v1.5.1: Override setSteeringInput for steering degradation
    Poor hydraulic reliability causes "loose" steering - the vehicle doesn't hold straight
    Pattern from: HeadlandManagement setSteeringInput
]]
function UsedPlusMaintenance:setSteeringInput(superFunc, inputValue, isAnalog, deviceCategory)
    local spec = self.spec_usedPlusMaintenance

    -- If no maintenance data or steering degradation disabled, pass through
    if spec == nil or not UsedPlusMaintenance.CONFIG.enableSteeringDegradation then
        return superFunc(self, inputValue, isAnalog, deviceCategory)
    end

    -- Only apply steering degradation if hydraulic reliability is below threshold
    local hydraulicReliability = spec.hydraulicReliability or 1.0
    if hydraulicReliability >= 0.7 then
        -- Good hydraulics, no degradation
        return superFunc(self, inputValue, isAnalog, deviceCategory)
    end

    -- Only when moving (steering wander at standstill would be weird)
    local speed = 0
    if self.getLastSpeed then
        speed = self:getLastSpeed()
    end

    if speed > 3 then  -- Above 3 km/h
        -- Calculate slop factor (how loose the steering is)
        -- 70% reliability = 0% slop
        -- 40% reliability = 43% slop
        -- 10% reliability = 86% slop
        local slopFactor = (0.7 - hydraulicReliability) / 0.7
        slopFactor = math.min(slopFactor, 0.9)  -- Max 90% slop

        -- Generate steering wander (random drift that accumulates)
        -- Higher speed = more noticeable wander
        local speedFactor = math.min(speed / 30, 1.0)  -- Maxes out at 30 km/h
        local wanderIntensity = slopFactor * speedFactor * 0.08  -- Max ~7% input modification

        -- Smooth random wander (not jerky)
        spec.steeringWanderTarget = spec.steeringWanderTarget or 0
        spec.steeringWanderCurrent = spec.steeringWanderCurrent or 0

        -- Occasionally change wander target (every ~0.5-2 seconds worth of frames)
        if math.random() < 0.02 then  -- ~2% chance per frame
            spec.steeringWanderTarget = (math.random() - 0.5) * 2 * wanderIntensity
        end

        -- Smoothly approach target (creates gradual drift, not sudden jerks)
        local approach = 0.05  -- 5% per frame toward target
        spec.steeringWanderCurrent = spec.steeringWanderCurrent + (spec.steeringWanderTarget - spec.steeringWanderCurrent) * approach

        -- Apply wander to input
        -- When player is steering hard, wander has less effect (they're actively fighting it)
        local playerInputStrength = math.abs(inputValue)
        local wanderWeight = 1.0 - (playerInputStrength * 0.7)  -- Wander reduced when steering hard
        local finalWander = spec.steeringWanderCurrent * wanderWeight

        inputValue = inputValue + finalWander

        -- Clamp to valid range
        inputValue = math.max(-1, math.min(1, inputValue))

        -- Occasional larger "slip" for very worn steering (dramatic effect)
        if hydraulicReliability < 0.3 and math.random() < 0.001 then  -- Very rare
            local slip = (math.random() - 0.5) * 0.15  -- Up to 15% slip
            inputValue = math.max(-1, math.min(1, inputValue + slip))

            -- Show warning on first slip
            if not spec.hasShownSteeringWarning then
                g_currentMission:showBlinkingWarning(
                    g_i18n:getText("usedPlus_steeringLoose") or "Steering feels loose!",
                    2000
                )
                spec.hasShownSteeringWarning = true
            end
        end
    else
        -- Reset wander when stopped
        spec.steeringWanderCurrent = 0
        spec.steeringWanderTarget = 0
    end

    return superFunc(self, inputValue, isAnalog, deviceCategory)
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

    -- Workhorse/Lemon Scale System (v1.4.0+)
    -- Hidden "DNA" of the vehicle - NEVER changes after creation
    spec.workhorseLemonScale = 0.5   -- Default average, will be set properly on purchase
    spec.maxReliabilityCeiling = 1.0 -- Starts at 100%, degrades over repairs based on DNA

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

    -- v1.5.1: Stall recovery state (prevents immediate restart)
    spec.stallRecoveryEndTime = 0

    -- Warning notification state (reset per session, not persisted)
    -- Speed degradation warnings
    spec.hasShownSpeedWarning = false
    spec.speedWarningTimer = 0
    spec.speedWarningInterval = 300000  -- 5 minutes between reminders

    -- Hydraulic drift warnings
    spec.hasShownDriftWarning = false
    spec.hasShownDriftMidpointWarning = false

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

        -- Load Workhorse/Lemon Scale (v1.4.0+)
        spec.workhorseLemonScale = xmlFile:getValue(key .. ".workhorseLemonScale", spec.workhorseLemonScale)
        spec.maxReliabilityCeiling = xmlFile:getValue(key .. ".maxReliabilityCeiling", spec.maxReliabilityCeiling)

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

    -- Save Workhorse/Lemon Scale (v1.4.0+)
    xmlFile:setValue(key .. ".workhorseLemonScale", spec.workhorseLemonScale)
    xmlFile:setValue(key .. ".maxReliabilityCeiling", spec.maxReliabilityCeiling)

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

    -- Workhorse/Lemon Scale (v1.4.0+)
    spec.workhorseLemonScale = streamReadFloat32(streamId)
    spec.maxReliabilityCeiling = streamReadFloat32(streamId)

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

    -- Workhorse/Lemon Scale (v1.4.0+)
    streamWriteFloat32(streamId, spec.workhorseLemonScale)
    streamWriteFloat32(streamId, spec.maxReliabilityCeiling)

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

    -- v1.5.1: Process first-start stall timer
    if spec.firstStartStallPending and spec.firstStartStallTimer then
        spec.firstStartStallTimer = spec.firstStartStallTimer - dt
        if spec.firstStartStallTimer <= 0 then
            spec.firstStartStallPending = false
            spec.firstStartStallTimer = nil
            -- Trigger the stall with custom first-start message (no duplicate warning)
            UsedPlusMaintenance.triggerEngineStall(self, true)  -- true = isFirstStart
        end
    end

    -- ========== PER-FRAME CHECKS (must run every frame for smooth physics) ==========

    -- v1.5.1: Enforce speed limit with braking (every frame for smooth limiting)
    if UsedPlusMaintenance.CONFIG.enableSpeedDegradation then
        UsedPlusMaintenance.enforceSpeedLimit(self, dt)
    end

    -- v1.5.1: Apply steering degradation (every frame for smooth feel)
    if UsedPlusMaintenance.CONFIG.enableSteeringDegradation then
        UsedPlusMaintenance.applySteeringDegradation(self, dt)
    end

    -- ========== PERIODIC CHECKS (throttled to every 1 second) ==========

    spec.updateTimer = (spec.updateTimer or 0) + dt
    if spec.updateTimer < UsedPlusMaintenance.CONFIG.updateIntervalMs then
        return
    end
    spec.updateTimer = 0

    -- Calculate speed limit factor (updates spec.maxSpeedFactor)
    if UsedPlusMaintenance.CONFIG.enableSpeedDegradation then
        UsedPlusMaintenance.calculateSpeedLimit(self)
    end

    -- Only check failures if feature is enabled
    if UsedPlusMaintenance.CONFIG.enableFailures then
        UsedPlusMaintenance.checkEngineStall(self)
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

    -- v1.5.1 REBALANCED: Low reliability = MUCH higher failure rates
    -- Previous formula was too gentle - 10% reliability only had 0.017% stall chance per second
    -- New formula makes low reliability vehicles ACTUALLY struggle

    -- 1. BASE CHANCE FROM RELIABILITY (dramatically increased!)
    -- 100% reliability = virtually no failures (0.001% per second)
    -- 50% reliability = occasional failures (0.1% per second = ~6% per minute)
    -- 10% reliability = frequent failures (0.5% per second = ~25% per minute)
    -- 0% reliability = constant failures (0.8% per second = ~40% per minute)
    local reliabilityFactor = math.pow(1 - reliability, 1.5)  -- Less aggressive curve, but higher base
    local baseChance = 0.00001 + (reliabilityFactor * 0.008)  -- 0.001% to 0.8% per second

    -- 2. DAMAGE MULTIPLIER (amplifies base chance, doesn't gate it)
    -- 0% damage = 1x multiplier (no change)
    -- 50% damage = 2x multiplier
    -- 100% damage = 3x multiplier
    local damageMultiplier = 1.0 + (damage * 2.0)

    -- 3. HOURS CONTRIBUTION (high hours = slightly more prone to issues)
    -- Caps at +50% after 10,000 hours
    local hoursMultiplier = 1.0 + math.min(hours / 20000, 0.5)

    -- 4. LOAD CONTRIBUTION (high load with low reliability = very risky)
    -- This is significant when EITHER load OR reliability is extreme
    local loadMultiplier = 1.0 + (load * (1 - reliability) * 3.0)

    -- Combined probability
    local probability = baseChance * damageMultiplier * hoursMultiplier * loadMultiplier
    probability = probability * UsedPlusMaintenance.CONFIG.failureRateMultiplier

    -- Cap at 5% per second max (allows for truly terrible engines)
    return math.min(probability, 0.05)
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
    @param vehicle - The vehicle to stall
    @param isFirstStart - Optional: true if this is a first-start stall (different message)
]]
function UsedPlusMaintenance.triggerEngineStall(vehicle, isFirstStart)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec == nil then return end

    -- Stop the motor
    if vehicle.stopMotor then
        vehicle:stopMotor()
    end

    spec.isStalled = true
    spec.stallCooldown = UsedPlusMaintenance.CONFIG.stallCooldownMs
    spec.failureCount = (spec.failureCount or 0) + 1

    -- v1.5.1: Set recovery period - engine cannot restart for X seconds
    -- This defeats auto-start and forces the player to actually stop
    local currentTime = g_currentMission.time or 0
    local recoveryDuration = UsedPlusMaintenance.CONFIG.stallRecoveryDurationMs
    spec.stallRecoveryEndTime = currentTime + recoveryDuration

    -- Show warning to player (include recovery time)
    local recoverySeconds = math.ceil(recoveryDuration / 1000)
    local message
    if isFirstStart then
        -- First-start stall - different message
        message = g_i18n:getText("usedPlus_firstStartStall")
        if message == "usedPlus_firstStartStall" then
            message = "Engine failed to start! Wait %d seconds..."
        else
            message = message .. " Wait %d seconds..."
        end
    else
        -- Normal stall during operation
        message = g_i18n:getText("usedPlus_engineStalledRecovery")
        if message == "usedPlus_engineStalledRecovery" then
            message = "Engine stalled! Wait %d seconds..."
        end
    end
    g_currentMission:showBlinkingWarning(
        string.format(message, recoverySeconds),
        recoveryDuration
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

    UsedPlus.logDebug(string.format("Engine stalled on %s (failures: %d, firstStart: %s)",
        vehicle:getName(), spec.failureCount, tostring(isFirstStart or false)))
end

--[[
    v1.5.1: Called when player enters a vehicle
    Used to check for "first-start" stall on poor reliability vehicles
    This simulates an engine that has trouble starting
]]
function UsedPlusMaintenance:onEnterVehicle(isControlling)
    if not isControlling then return end  -- Only process for controlling player
    if not self.isServer then return end  -- Only on server

    local spec = self.spec_usedPlusMaintenance
    if spec == nil then return end

    -- Only check on poor reliability vehicles
    local engineReliability = spec.engineReliability or 1.0
    if engineReliability >= 0.5 then
        return  -- Good enough reliability, no first-start issues
    end

    -- Don't double-stall if we're already in recovery
    if spec.stallRecoveryEndTime and spec.stallRecoveryEndTime > 0 then
        return
    end

    -- Calculate first-start stall chance based on reliability
    -- 50% reliability = 0% chance
    -- 25% reliability = 50% chance
    -- 10% reliability = 80% chance
    -- 0% reliability = 100% chance
    local stallChance = (0.5 - engineReliability) * 2.0
    stallChance = math.max(0, math.min(stallChance, 1.0))

    -- Roll for first-start stall
    if math.random() < stallChance then
        -- Stall immediately after short delay (feels like "almost started then died")
        -- Use a timer so it happens after the vehicle fully loads
        spec.firstStartStallPending = true
        spec.firstStartStallTimer = 500  -- 500ms delay

        UsedPlus.logDebug(string.format("First-start stall scheduled for %s (reliability: %d%%)",
            self:getName(), math.floor(engineReliability * 100)))
    end
end

--[[
    Calculate speed limit factor based on engine reliability and damage
    This is called periodically (every 1 second) to update spec.maxSpeedFactor
    The actual speed enforcement happens in getCanMotorRun() every frame via the governor

    v1.5.1 FIX: Low reliability NOW reduces speed even when damage is 0!
    v1.5.1: Renamed from updateSpeedLimit, actual enforcement moved to governor
]]
function UsedPlusMaintenance.calculateSpeedLimit(vehicle)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec == nil then return end

    -- Get current damage
    local damage = 0
    if vehicle.getDamageAmount then
        damage = vehicle:getDamageAmount() or 0
    end

    -- Calculate speed factor from RELIABILITY (applies even at 0% damage!)
    -- 100% reliability = 100% speed
    -- 50% reliability = 70% speed
    -- 10% reliability = 46% speed
    -- 0% reliability = 40% speed (absolute minimum)
    local engineReliability = spec.engineReliability or 1.0
    local reliabilitySpeedFactor = 0.4 + (engineReliability * 0.6)

    -- Damage ALSO reduces speed (stacks with reliability)
    local maxReduction = UsedPlusMaintenance.CONFIG.speedDegradationMax
    local damageSpeedFactor = 1 - (damage * maxReduction)

    -- Combined factor (multiplicative stacking)
    local finalFactor = reliabilitySpeedFactor * damageSpeedFactor
    finalFactor = math.max(finalFactor, 0.3)  -- Never below 30% speed

    -- Store for use by getCanMotorRun speed governor
    spec.maxSpeedFactor = finalFactor

    -- Calculate actual limited speed for display/warnings
    local baseMaxSpeed = 50
    if vehicle.spec_drivable and vehicle.spec_drivable.cruiseControl then
        baseMaxSpeed = vehicle.spec_drivable.cruiseControl.maxSpeed or 50
    end
    spec.currentMaxSpeed = baseMaxSpeed * finalFactor

    -- Only show warnings if there's actual degradation (below 95%)
    if finalFactor >= 0.95 then
        spec.hasShownSpeedWarning = false
        spec.speedWarningTimer = 0
        return
    end

    -- Show warning when speed degradation is first noticed
    if not spec.hasShownSpeedWarning then
        local speedPercent = math.floor(finalFactor * 100)
        g_currentMission:showBlinkingWarning(
            string.format(g_i18n:getText("usedPlus_speedDegraded") or "Engine struggling - max speed reduced to %d%%!", speedPercent),
            4000
        )
        spec.hasShownSpeedWarning = true
        spec.speedWarningTimer = 0
        UsedPlus.logDebug(string.format("Speed degradation: %d%% (max %d km/h)", speedPercent, math.floor(spec.currentMaxSpeed)))
    end
end

--[[
    v1.5.1: Placeholder for per-frame speed enforcement (not needed with governor approach)
    The actual enforcement now happens in getCanMotorRun() which is called every frame
]]
function UsedPlusMaintenance.enforceSpeedLimit(vehicle, dt)
    -- Speed enforcement is now handled by the governor in getCanMotorRun()
    -- This function exists for future enhancements (e.g., HUD display updates)
end

--[[
    v1.5.1: Apply steering degradation for worn feel
    Poor hydraulic reliability causes loose, sloppy steering response
    Makes the vehicle feel "old" and worn
]]
function UsedPlusMaintenance.applySteeringDegradation(vehicle, dt)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec == nil then return end

    -- Only apply steering degradation if hydraulic reliability is low
    local hydraulicReliability = spec.hydraulicReliability or 1.0
    if hydraulicReliability >= 0.8 then
        return  -- Steering fine above 80% reliability
    end

    -- Calculate steering "slop" factor (0 = perfect, 1 = very loose)
    -- At 80% reliability: 0% slop
    -- At 50% reliability: 37.5% slop
    -- At 10% reliability: 87.5% slop
    local slopFactor = (0.8 - hydraulicReliability) / 0.8
    slopFactor = math.min(slopFactor, 0.9)  -- Max 90% slop

    -- Add random steering "wander" based on slop
    -- This creates the feeling of loose steering that doesn't hold straight
    if vehicle.spec_drivable and vehicle.spec_drivable.steeringAngle then
        -- Only apply wander when moving
        local speed = 0
        if vehicle.getLastSpeed then
            speed = vehicle:getLastSpeed()
        end

        if speed > 5 then  -- Only above 5 km/h
            -- Random micro-adjustments to steering
            local wanderAmount = slopFactor * 0.002 * (math.random() - 0.5)

            -- Apply steering wander (very subtle)
            spec.steeringWander = (spec.steeringWander or 0) + wanderAmount
            spec.steeringWander = spec.steeringWander * 0.95  -- Decay

            -- Clamp wander
            spec.steeringWander = math.max(-0.03, math.min(0.03, spec.steeringWander))
        else
            spec.steeringWander = 0
        end
    end
end

--[[
    Check for hydraulic drift on attached implements
    Poor hydraulic reliability causes raised implements to slowly lower
    Phase 5 feature
    v1.4.0: Added visual warnings so players understand why implements are lowering
]]
function UsedPlusMaintenance.checkHydraulicDrift(vehicle, dt)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec == nil then return end

    -- Only drift if hydraulic reliability is below threshold
    -- BALANCE NOTE (v1.2): Removed damage gate - low reliability causes drift even when repaired
    if spec.hydraulicReliability >= UsedPlusMaintenance.CONFIG.hydraulicDriftThreshold then
        -- Reset warning flags when hydraulics are healthy (so warnings trigger again if they degrade)
        spec.hasShownDriftWarning = false
        spec.hasShownDriftMidpointWarning = false
        return
    end

    -- v1.4.0: Show one-time warning when drift conditions are first detected
    if not spec.hasShownDriftWarning then
        local reliabilityPercent = math.floor(spec.hydraulicReliability * 100)
        g_currentMission:showBlinkingWarning(
            string.format(g_i18n:getText("usedPlus_hydraulicWeak") or "Hydraulics weak (%d%%) - implements may drift!", reliabilityPercent),
            4000
        )
        spec.hasShownDriftWarning = true
        UsedPlus.logDebug(string.format("Hydraulic drift warning shown: %d%% reliability", reliabilityPercent))
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
            -- Pass parent spec so child can trigger midpoint warning
            UsedPlusMaintenance.applyHydraulicDriftToVehicle(childVehicle, driftSpeed, dt, spec)
        end
    end
end

--[[
    Apply hydraulic drift to a single vehicle's cylindered tools
    @param vehicle - The implement vehicle to check
    @param driftSpeed - How fast to drift (radians per second)
    @param dt - Delta time in milliseconds
    @param parentSpec - The parent vehicle's UsedPlusMaintenance spec (for warning flags)
]]
function UsedPlusMaintenance.applyHydraulicDriftToVehicle(vehicle, driftSpeed, dt, parentSpec)
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
                else
                    -- v1.4.0: Implement just reached midpoint (fully drifted down)
                    -- Show warning once per session when this happens
                    if parentSpec and not parentSpec.hasShownDriftMidpointWarning then
                        g_currentMission:addIngameNotification(
                            FSBaseMission.INGAME_NOTIFICATION_INFO,
                            g_i18n:getText("usedPlus_hydraulicDrifted") or "Implement lowered due to hydraulic failure"
                        )
                        parentSpec.hasShownDriftMidpointWarning = true
                        UsedPlus.logDebug("Hydraulic drift midpoint warning shown - implement fully lowered")
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

    -- v1.5.1 REBALANCED: Calculate cutout probability based on electrical reliability
    -- Previous formula was too gentle - 42% reliability rarely caused cutouts
    -- New formula: Low reliability = significant base chance, damage amplifies
    local baseChance = UsedPlusMaintenance.CONFIG.cutoutBaseChance  -- 3% base
    local electricalReliability = spec.electricalReliability or 1.0

    -- 100% reliability = 0% factor (no cutouts)
    -- 50% reliability = 25% factor
    -- 10% reliability = 81% factor
    local reliabilityFactor = math.pow(1 - electricalReliability, 1.5)  -- Less harsh curve but still significant

    -- Damage amplifies (0% damage = 1x, 100% = 3x)
    local damageMultiplier = 1.0 + (damage * 2.0)

    -- Combined: at 42% reliability, 0% damage = 3% * 0.44 * 1.0 = 1.3% per 5 sec = ~15% per minute
    -- At 10% reliability, 0% damage = 3% * 0.73 * 1.0 = 2.2% per 5 sec = ~24% per minute
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

    v1.4.0: Now transfers workhorseLemonScale and maxReliabilityCeiling
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

    -- v1.4.0: Transfer Workhorse/Lemon Scale data
    spec.workhorseLemonScale = usedPlusData.workhorseLemonScale or 0.5
    spec.maxReliabilityCeiling = usedPlusData.maxReliabilityCeiling or 1.0

    -- Initialize maintenance history
    spec.repairCount = 0
    spec.totalRepairCost = 0
    spec.failureCount = 0

    UsedPlus.logDebug(string.format("Set used purchase data for %s: DNA=%.2f, ceiling=%.1f%%, engine=%.2f, hydraulic=%.2f, electrical=%.2f",
        vehicle:getName(), spec.workhorseLemonScale, spec.maxReliabilityCeiling * 100,
        spec.engineReliability, spec.hydraulicReliability, spec.electricalReliability))

    return true
end

--[[
    PUBLIC API: Get current reliability data for a vehicle
    Used for inspection reports and vehicle info display

    v1.4.0: Now includes workhorseLemonScale and maxReliabilityCeiling
]]
function UsedPlusMaintenance.getReliabilityData(vehicle)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec == nil then
        return nil
    end

    -- Calculate average reliability
    local avgReliability = (spec.engineReliability + spec.hydraulicReliability + spec.electricalReliability) / 3

    -- v1.4.0: Calculate resale modifier based on average reliability
    -- Formula: 0.7 + (avgReliability * 0.3) => Range: 0.7 to 1.0
    -- A 50% reliable vehicle sells for 85% of normal value
    -- A 90% reliable vehicle sells for 97% of normal value
    local resaleModifier = 0.7 + (avgReliability * 0.3)

    return {
        purchasedUsed = spec.purchasedUsed,
        wasInspected = spec.wasInspected,
        engineReliability = spec.engineReliability,
        hydraulicReliability = spec.hydraulicReliability,
        electricalReliability = spec.electricalReliability,
        workhorseLemonScale = spec.workhorseLemonScale,
        maxReliabilityCeiling = spec.maxReliabilityCeiling,
        repairCount = spec.repairCount,
        totalRepairCost = spec.totalRepairCost,
        failureCount = spec.failureCount,
        avgReliability = avgReliability,
        resaleModifier = resaleModifier  -- v1.4.0: Reliability affects resale value
    }
end

--[[
    PUBLIC API: Update reliability after repair
    Called from VehicleSellingPointExtension when repair completes

    v1.4.0: Now implements Workhorse/Lemon Scale system
    - Each repair degrades the reliability CEILING based on vehicle DNA
    - Lemons (0.0) lose 1% ceiling per repair
    - Workhorses (1.0) lose 0% ceiling per repair
    - Reliability scores are capped by the current ceiling, not a fixed 95%
]]
function UsedPlusMaintenance.onVehicleRepaired(vehicle, repairCost)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec == nil then return end

    -- Update maintenance history
    spec.repairCount = spec.repairCount + 1
    spec.totalRepairCost = spec.totalRepairCost + repairCost
    spec.lastRepairDate = g_currentMission.environment.dayTime or 0

    -- v1.4.0: Calculate ceiling degradation based on vehicle DNA
    if UsedPlusMaintenance.CONFIG.enableLemonScale then
        -- Lemon (0.0) = 1% degradation per repair, Workhorse (1.0) = 0% degradation
        local degradationRate = (1 - (spec.workhorseLemonScale or 0.5)) *
            UsedPlusMaintenance.CONFIG.ceilingDegradationMax

        -- Reduce the ceiling
        spec.maxReliabilityCeiling = (spec.maxReliabilityCeiling or 1.0) - degradationRate

        -- Ensure minimum ceiling (vehicle is never completely unrepairable)
        spec.maxReliabilityCeiling = math.max(
            UsedPlusMaintenance.CONFIG.minReliabilityCeiling,
            spec.maxReliabilityCeiling
        )

        UsedPlus.logDebug(string.format("Ceiling degraded: DNA=%.2f, degradation=%.3f%%, newCeiling=%.1f%%",
            spec.workhorseLemonScale or 0.5, degradationRate * 100, spec.maxReliabilityCeiling * 100))
    end

    -- Apply repair bonus, capped by CURRENT ceiling (not fixed 95%)
    local repairBonus = UsedPlusMaintenance.CONFIG.reliabilityRepairBonus
    local ceiling = spec.maxReliabilityCeiling or UsedPlusMaintenance.CONFIG.maxReliabilityAfterRepair

    spec.engineReliability = math.min(ceiling, spec.engineReliability + repairBonus)
    spec.hydraulicReliability = math.min(ceiling, spec.hydraulicReliability + repairBonus)
    spec.electricalReliability = math.min(ceiling, spec.electricalReliability + repairBonus)

    -- v1.4.0: Reset warning flags so they can trigger again if problems return
    -- Speed degradation warnings reset when damage drops below threshold (automatic)
    -- But hydraulic warnings need manual reset since reliability might still be low
    spec.hasShownDriftWarning = false
    spec.hasShownDriftMidpointWarning = false
    -- Speed warning will auto-reset when damage < threshold, but reset timer
    spec.speedWarningTimer = 0

    UsedPlus.logDebug(string.format("Vehicle repaired: %s - ceiling=%.1f%%, engine=%.2f, hydraulic=%.2f, electrical=%.2f",
        vehicle:getName(), ceiling * 100, spec.engineReliability, spec.hydraulicReliability, spec.electricalReliability))
end

--[[
    PUBLIC API: Generate random reliability scores for a used vehicle listing
    Called from UsedVehicleManager when generating sale items

    v1.4.0: Now includes workhorseLemonScale and calculates initial ceiling
    based on estimated previous repairs from age/hours

    @param damage - Vehicle damage level (0-1)
    @param age - Vehicle age in years
    @param hours - Operating hours
    @param qualityLevel - Optional quality tier (1=Any, 2=Poor, 3=Fair, 4=Good, 5=Excellent)
                          Affects DNA distribution - higher tiers bias toward workhorses
]]
function UsedPlusMaintenance.generateReliabilityScores(damage, age, hours, qualityLevel)
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

    -- v1.4.0: Generate workhorse/lemon scale (DNA correlated with quality tier)
    local workhorseLemonScale = UsedPlusMaintenance.generateUsedVehicleScale(qualityLevel)

    -- v1.4.0: Estimate previous repairs from age/hours and calculate initial ceiling
    local estimatedRepairs = math.floor((hours or 0) / 500)  -- ~1 repair per 500 hours
    estimatedRepairs = estimatedRepairs + (age or 0)  -- Plus ~1 per year
    local maxReliabilityCeiling = UsedPlusMaintenance.calculateInitialCeiling(
        workhorseLemonScale, estimatedRepairs)

    -- Cap reliability scores by the calculated ceiling
    engineReliability = math.min(engineReliability, maxReliabilityCeiling)
    hydraulicReliability = math.min(hydraulicReliability, maxReliabilityCeiling)
    electricalReliability = math.min(electricalReliability, maxReliabilityCeiling)

    UsedPlus.logDebug(string.format("Generated reliability: DNA=%.2f, ceiling=%.1f%%, est.repairs=%d",
        workhorseLemonScale, maxReliabilityCeiling * 100, estimatedRepairs))

    return {
        engineReliability = engineReliability,
        hydraulicReliability = hydraulicReliability,
        electricalReliability = electricalReliability,
        workhorseLemonScale = workhorseLemonScale,
        maxReliabilityCeiling = maxReliabilityCeiling,
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
