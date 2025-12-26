--[[
    FS25_UsedPlus - Used Vehicle Search Data Class

    UsedVehicleSearch represents an active search request
    Pattern from: BuyUsedEquipment "Async Search Queue System"
    Reference: FS25_ADVANCED_PATTERNS.md - Async Operations section

    Functionality:
    - Tracks active used equipment search
    - TTL (Time To Live) countdown in hours
    - TTS (Time To Success) determines outcome
    - Probabilistic success based on search tier
    - Configuration matching for customizations
    - Integration with game's used vehicle system

    Search Tiers:
    1. Local Search: 4% cost, 25% success, 1 month
    2. Regional Search: 6% cost, 55% success, 1-2 months
    3. National Search: 10% cost, 80% success, 2-4 months
]]

UsedVehicleSearch = {}
local UsedVehicleSearch_mt = Class(UsedVehicleSearch)

--[[
    Credit score modifiers for agent fees
    Better credit = cheaper agent services (they trust you more)
    Must match UsedSearchDialog.CREDIT_FEE_MODIFIERS!
]]
UsedVehicleSearch.CREDIT_FEE_MODIFIERS = {
    {minScore = 750, modifier = -0.15, name = "Excellent"},  -- 15% discount
    {minScore = 700, modifier = -0.08, name = "Good"},       -- 8% discount
    {minScore = 650, modifier = 0.00,  name = "Fair"},       -- No change
    {minScore = 600, modifier = 0.10,  name = "Poor"},       -- 10% surcharge
    {minScore = 300, modifier = 0.20,  name = "Very Poor"}   -- 20% surcharge
}

--[[
    Get credit score fee modifier for a farm
    @param farmId - Farm ID to check credit for
    @return modifier (negative = discount, positive = surcharge)
]]
function UsedVehicleSearch.getCreditFeeModifier(farmId)
    if not CreditScore then
        return 0
    end

    local score = CreditScore.calculate(farmId)
    for _, tier in ipairs(UsedVehicleSearch.CREDIT_FEE_MODIFIERS) do
        if score >= tier.minScore then
            return tier.modifier
        end
    end
    return 0.20  -- Default to worst tier
end

--[[
    Quality tier definitions (same as UsedSearchDialog)
    Lower quality = lower price, but needs repairs
    successModifier affects the base success rate from search tier
    1 = Poor (may be inoperable), 2 = Any, 3 = Fair, 4 = Good, 5 = Excellent
]]
UsedVehicleSearch.QUALITY_TIERS = {
    {  -- Poor Condition (worst - may be inoperable!)
        name = "Poor Condition",
        minCondition = 0.05,
        maxCondition = 0.30,
        priceMultiplier = 0.15,  -- 15% of new price (85% off!)
        successModifier = 0.15   -- +15% easier to find junk
    },
    {  -- Any Condition (cheapest working, may need lots of work)
        name = "Any Condition",
        minCondition = 0.10,
        maxCondition = 0.40,
        priceMultiplier = 0.30,  -- 30% of new price (70% off)
        successModifier = 0.08   -- +8% easier to find rough equipment
    },
    {  -- Fair Condition
        name = "Fair Condition",
        minCondition = 0.40,
        maxCondition = 0.60,
        priceMultiplier = 0.48,  -- 48% of new price (52% off)
        successModifier = 0.00   -- Baseline (no modifier)
    },
    {  -- Good Condition
        name = "Good Condition",
        minCondition = 0.60,
        maxCondition = 0.80,
        priceMultiplier = 0.65,  -- 65% of new price (35% off)
        successModifier = -0.08  -- -8% harder to find well-maintained
    },
    {  -- Excellent Condition
        name = "Excellent Condition",
        minCondition = 0.80,
        maxCondition = 0.95,
        priceMultiplier = 0.80,  -- 80% of new price (20% off)
        successModifier = -0.15  -- -15% harder to find pristine
    }
}

--[[
    Constructor for new search request
    Calculates search parameters, success probability, duration
]]
function UsedVehicleSearch.new(farmId, storeItemIndex, storeItemName, basePrice, searchLevel, qualityLevel)
    local self = setmetatable({}, UsedVehicleSearch_mt)

    -- Identity
    self.id = nil  -- Set by UsedVehicleManager when registered
    self.farmId = farmId

    -- Store item information
    self.storeItemIndex = storeItemIndex  -- xmlFilename or index
    self.storeItemName = storeItemName
    self.basePrice = basePrice

    -- Search parameters
    self.searchLevel = searchLevel  -- 1 = local, 2 = regional, 3 = national
    self.qualityLevel = qualityLevel or 1  -- 1=Any, 2=Poor, 3=Fair, 4=Good, 5=Excellent
    self.searchCost = 0            -- Calculated below
    self.configurations = {}  -- Configuration options (empty for now)

    -- Result parameters (calculated when found)
    self.foundCondition = 0  -- Actual condition of found vehicle (0-1)
    self.foundPrice = 0      -- Price based on condition

    -- Timing (in hours)
    self.ttl = 0  -- Time to live (total duration)
    self.tts = 0  -- Time to success (when result determined)

    -- Status
    self.status = "active"  -- active, success, failed
    self.createdAt = g_currentMission.environment.currentHour

    -- Calculate search parameters from tier
    self:calculateSearchParams()

    return self
end

--[[
    Calculate search parameters from search tier
    Determines cost, duration, and success/failure point
]]
function UsedVehicleSearch:calculateSearchParams()
    -- Search tier definitions - REBALANCED to fix Local loophole
    -- Time measured in months (1 game day = 1 month, 1 month = 24 hours)
    -- Design: Local = impatient tax, Regional = smart choice, National = certainty premium
    local SEARCH_TIERS = {
        {  -- Local Search - Quick but expensive per success
            name = "Local Search",
            feePercent = 0.04,      -- 4% of base price (was 2%)
            minMonths = 1,          -- Exactly 1 month (24 hours)
            maxMonths = 1,          -- 1 month only - local is the fast option
            successChance = 0.25,   -- 25% success (was 40%) - quick answer, poor odds
            matchChance = 0.25      -- 25% per customization
        },
        {  -- Regional Search - Best value, balanced option
            name = "Regional Search",
            feePercent = 0.06,      -- 6% of base price (unchanged)
            minMonths = 1,          -- 1-2 months (was 1-3)
            maxMonths = 2,
            successChance = 0.55,   -- 55% success (was 70%)
            matchChance = 0.50      -- 50% per customization
        },
        {  -- National Search - High certainty, worth the wait
            name = "National Search",
            feePercent = 0.10,      -- 10% of base price (was 12%)
            minMonths = 2,          -- 2-4 months (was 2-6)
            maxMonths = 4,
            successChance = 0.80,   -- 80% success (was 85%)
            matchChance = 0.70      -- 70% per customization
        }
    }

    local tier = SEARCH_TIERS[self.searchLevel]

    -- Calculate search cost with credit fee modifier
    -- Better credit = cheaper agents (they trust you more)
    local creditFeeModifier = UsedVehicleSearch.getCreditFeeModifier(self.farmId)
    local adjustedFeePercent = tier.feePercent * (1 + creditFeeModifier)
    self.searchCost = math.floor(self.basePrice * adjustedFeePercent)
    self.creditFeeModifier = creditFeeModifier  -- Store for reference

    -- Calculate duration in hours (1 month = 24 hours game time)
    local durationMonths = math.random(tier.minMonths, tier.maxMonths)
    self.ttl = durationMonths * 24  -- Convert months to hours

    -- Determine if search will succeed
    -- Roll dice once at creation time (from BuyUsedEquipment pattern)
    -- Apply quality modifier: Poor = easier (+15%), Excellent = harder (-15%)
    local qualityTier = UsedVehicleSearch.QUALITY_TIERS[self.qualityLevel]
    local qualityModifier = qualityTier and qualityTier.successModifier or 0
    local adjustedSuccessChance = math.max(0.05, math.min(0.95, tier.successChance + qualityModifier))

    math.random()  -- Dry run for better randomness
    local isSuccess = math.random() <= adjustedSuccessChance

    if isSuccess then
        -- Will succeed - random time within the search duration
        -- Success happens somewhere between 50% and 100% of TTL (agent needs time to find it)
        local minSuccessTime = math.max(1, math.floor(self.ttl * 0.5))
        local maxSuccessTime = math.max(minSuccessTime + 1, self.ttl)
        self.tts = math.random(minSuccessTime, maxSuccessTime)
        UsedPlus.logDebug(string.format("Search will SUCCEED: TTS=%d hours (TTL=%d)", self.tts, self.ttl))
    else
        -- Will fail - tts set to impossibly high so it never triggers
        self.tts = self.ttl + 999
        UsedPlus.logDebug(string.format("Search will FAIL: TTL=%d hours", self.ttl))
    end

    -- Set match chances for configurations
    for configId, config in pairs(self.configurations) do
        config.matchChance = tier.matchChance
    end
end

--[[
    Update search timers (called every hour)
    Decrements TTL and TTS
]]
function UsedVehicleSearch:update()
    self.ttl = self.ttl - 1
    self.tts = self.tts - 1
end

--[[
    Check if search is complete (success or failure)
    Returns: nil (still active), "success", or "failed"
]]
function UsedVehicleSearch:checkCompletion()
    if self.tts <= 0 and self.status == "active" then
        -- TTS reached - search succeeded
        return "success"
    elseif self.ttl <= 0 and self.status == "active" then
        -- TTL expired - search failed
        return "failed"
    end

    return nil  -- Still active
end

--[[
    Generate condition and price for found vehicle
    Called when search succeeds
    Returns condition (0-1) and price based on quality tier
]]
function UsedVehicleSearch:generateFoundVehicleDetails()
    local qualityTier = UsedVehicleSearch.QUALITY_TIERS[self.qualityLevel]
    if qualityTier == nil then
        qualityTier = UsedVehicleSearch.QUALITY_TIERS[1]  -- Default to "Any"
    end

    -- Random condition within tier range
    math.random()  -- Dry run for better randomness
    local conditionRange = qualityTier.maxCondition - qualityTier.minCondition
    self.foundCondition = qualityTier.minCondition + (math.random() * conditionRange)

    -- Price based on condition with some variance
    -- Base price multiplier from tier, adjusted by actual condition
    local conditionFactor = self.foundCondition / qualityTier.maxCondition
    local priceVariance = 0.9 + (math.random() * 0.2)  -- 90-110% variance
    self.foundPrice = math.floor(self.basePrice * qualityTier.priceMultiplier * conditionFactor * priceVariance)

    UsedPlus.logDebug(string.format("Generated found vehicle: %s", self.storeItemName))
    UsedPlus.logDebug(string.format("  Quality tier: %s", qualityTier.name))
    UsedPlus.logDebug(string.format("  Condition: %.1f%%", self.foundCondition * 100))
    UsedPlus.logDebug(string.format("  Price: $%d (base: $%d)", self.foundPrice, self.basePrice))

    return self.foundCondition, self.foundPrice
end

--[[
    Get quality tier name for display
]]
function UsedVehicleSearch:getQualityName()
    local qualityTier = UsedVehicleSearch.QUALITY_TIERS[self.qualityLevel]
    if qualityTier then
        return qualityTier.name
    end
    return "Unknown"
end

--[[
    Generate matched configurations for found vehicle
    Rolls dice for each configuration option
    Returns table of configId -> index (or nil for no match)
]]
function UsedVehicleSearch:generateMatchedConfigurations()
    local matched = {}

    -- Roll for each player-selected configuration
    for configId, config in pairs(self.configurations) do
        math.random()  -- Dry run for better randomness
        local roll = math.random()

        if roll <= config.matchChance then
            -- Configuration matches player's selection
            matched[configId] = config.index
        else
            -- Configuration is random
            -- UsedVehicleManager will select random index for this config
            matched[configId] = nil
        end
    end

    return matched
end

--[[
    Get search tier name for display
]]
function UsedVehicleSearch:getTierName()
    if self.searchLevel == 1 then
        return g_i18n:getText("usedplus_searchTier_local")
    else
        return g_i18n:getText("usedplus_searchTier_national")
    end
end

--[[
    Get remaining time in human-readable format
]]
function UsedVehicleSearch:getRemainingTime()
    local hours = self.ttl
    local months = math.floor(hours / 24)
    local remainingHours = hours % 24

    if months > 0 then
        return string.format("%d month%s, %d hours", months, months > 1 and "s" or "", remainingHours)
    else
        return string.format("%d hours", hours)
    end
end

--[[
    Save search to XML savegame
    Preserves search state across save/load
]]
function UsedVehicleSearch:saveToXMLFile(xmlFile, key)
    xmlFile:setString(key .. "#id", self.id)
    xmlFile:setInt(key .. "#farmId", self.farmId)
    xmlFile:setString(key .. "#storeItemIndex", self.storeItemIndex)
    xmlFile:setString(key .. "#storeItemName", self.storeItemName)
    xmlFile:setFloat(key .. "#basePrice", self.basePrice)
    xmlFile:setInt(key .. "#searchLevel", self.searchLevel)
    xmlFile:setInt(key .. "#qualityLevel", self.qualityLevel or 1)
    xmlFile:setFloat(key .. "#searchCost", self.searchCost)
    xmlFile:setInt(key .. "#ttl", self.ttl)
    xmlFile:setInt(key .. "#tts", self.tts)
    xmlFile:setString(key .. "#status", self.status)
    xmlFile:setInt(key .. "#createdAt", self.createdAt)
    xmlFile:setFloat(key .. "#foundCondition", self.foundCondition or 0)
    xmlFile:setFloat(key .. "#foundPrice", self.foundPrice or 0)

    -- Save configurations
    local configIndex = 0
    for configId, config in pairs(self.configurations) do
        local configKey = string.format("%s.configuration(%d)", key, configIndex)
        xmlFile:setString(configKey .. "#id", configId)
        xmlFile:setInt(configKey .. "#index", config.index)
        xmlFile:setFloat(configKey .. "#matchChance", config.matchChance)
        xmlFile:setString(configKey .. "#name", config.name or "")
        configIndex = configIndex + 1
    end
end

--[[
    Cancel this search
    Called by UsedVehicleManager when player cancels
    No refund - agent fee is a sunk cost (commitment)
]]
function UsedVehicleSearch:cancel()
    self.status = "cancelled"
    UsedPlus.logDebug(string.format("Search %s cancelled: %s", self.id, self.storeItemName))
end

--[[
    Load search from XML savegame
    Returns true if successful, false if corrupt
]]
function UsedVehicleSearch:loadFromXMLFile(xmlFile, key)
    self.id = xmlFile:getString(key .. "#id")

    -- Validate required fields
    if self.id == nil or self.id == "" then
        UsedPlus.logWarn("Corrupt search request in savegame, skipping")
        return false
    end

    self.farmId = xmlFile:getInt(key .. "#farmId")
    self.storeItemIndex = xmlFile:getString(key .. "#storeItemIndex")
    self.storeItemName = xmlFile:getString(key .. "#storeItemName")
    self.basePrice = xmlFile:getFloat(key .. "#basePrice")
    self.searchLevel = xmlFile:getInt(key .. "#searchLevel")
    self.qualityLevel = xmlFile:getInt(key .. "#qualityLevel", 1)
    self.searchCost = xmlFile:getFloat(key .. "#searchCost")
    self.ttl = xmlFile:getInt(key .. "#ttl")
    self.tts = xmlFile:getInt(key .. "#tts")
    self.status = xmlFile:getString(key .. "#status", "active")
    self.createdAt = xmlFile:getInt(key .. "#createdAt")
    self.foundCondition = xmlFile:getFloat(key .. "#foundCondition", 0)
    self.foundPrice = xmlFile:getFloat(key .. "#foundPrice", 0)

    -- Load configurations
    self.configurations = {}
    xmlFile:iterate(key .. ".configuration", function(_, configKey)
        local configId = xmlFile:getString(configKey .. "#id")
        if configId ~= nil then
            self.configurations[configId] = {
                index = xmlFile:getInt(configKey .. "#index"),
                matchChance = xmlFile:getFloat(configKey .. "#matchChance"),
                name = xmlFile:getString(configKey .. "#name", "")
            }
        end
    end)

    return true
end

UsedPlus.logInfo("UsedVehicleSearch class loaded")
