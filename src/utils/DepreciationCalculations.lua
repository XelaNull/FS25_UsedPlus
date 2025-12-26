--[[
    FS25_UsedPlus - Depreciation Calculations Utility

    Handles used vehicle pricing and depreciation
    Pattern from: BuyUsedEquipment "Probabilistic Depreciation System"
    Reference: FS25_ADVANCED_PATTERNS.md - Depreciation patterns
    Reference: FS25_UsedPlus.md lines 1830-1883 (generation tables)

    Functionality:
    - Generation-based depreciation (Recent/Mid-age/Old)
    - Random age, damage, wear, hours within generation ranges
    - Integration with game's built-in depreciation system
    - Realistic used vehicle pricing

    Generations:
    1. Recent (0-3 years): 12-25% discount, low damage/wear
    2. Mid-age (4-7 years): 25-45% discount, medium damage/wear
    3. Old (8-15 years): 45-75% discount, high damage/wear
]]

DepreciationCalculations = {}

--[[
    Generation definitions from BuyUsedEquipment pattern
    Each generation defines ranges for age, discount, hours, damage, wear
]]
DepreciationCalculations.GENERATIONS = {
    {  -- Generation 1: Recent (like new)
        name = "Recent",
        maxAge = 3,                    -- 0-3 years old
        discount = { 0.12, 0.25 },     -- 12% to 25% off
        hours = { 100, 800 },          -- Hours per year
        damage = { 0.02, 0.08 },       -- 2% to 8% paint damage
        wear = { 0.01, 0.10 },         -- 1% to 10% wear
    },
    {  -- Generation 2: Mid-age (used)
        name = "Mid-age",
        maxAge = 7,                    -- 4-7 years old
        discount = { 0.25, 0.45 },     -- 25% to 45% off
        hours = { 200, 1200 },         -- Hours per year
        damage = { 0.08, 0.20 },       -- 8% to 20% paint damage
        wear = { 0.10, 0.25 },         -- 10% to 25% wear
    },
    {  -- Generation 3: Old (well-used)
        name = "Old",
        maxAge = 15,                   -- 8-15 years old
        discount = { 0.45, 0.75 },     -- 45% to 75% off
        hours = { 500, 2500 },         -- Hours per year
        damage = { 0.20, 0.50 },       -- 20% to 50% paint damage
        wear = { 0.25, 0.60 },         -- 25% to 60% wear
    }
}

--[[
    Quality tier definitions - player's desired condition preference
    Lower quality = lower price but more damage/wear to repair
    Higher quality = higher price but less repair needed
    Array order: 1=Any, 2=Poor, 3=Fair, 4=Good, 5=Excellent
    Must match UsedSearchDialog.QUALITY_TIERS order!

    BALANCE NOTE (v1.2): Original discounts were too aggressive (50-75% off),
    making used vehicles always better than new. Rebalanced to 15-45% off
    to keep used competitive but not game-breaking. Combined with reliability
    consequences, used vehicles are now a meaningful tradeoff.
]]
DepreciationCalculations.QUALITY_TIERS = {
    {  -- Any Condition: High damage/wear range (broadest search)
        name = "Any Condition",
        damageRange = { 0.30, 0.70 },   -- 30-70% damage
        wearRange = { 0.35, 0.75 },      -- 35-75% wear
        priceMultiplier = 0.55           -- 45% off (was 70%)
    },
    {  -- Poor Condition: High damage/wear - needs significant repairs
        name = "Poor Condition",
        damageRange = { 0.50, 0.80 },   -- 50-80% damage (needs work)
        wearRange = { 0.55, 0.85 },      -- 55-85% wear
        priceMultiplier = 0.50           -- 50% off (was 75%) - fixer-upper but not free
    },
    {  -- Fair Condition
        name = "Fair Condition",
        damageRange = { 0.15, 0.40 },   -- 15-40% damage
        wearRange = { 0.20, 0.45 },      -- 20-45% wear
        priceMultiplier = 0.68           -- 32% off (was 52%)
    },
    {  -- Good Condition
        name = "Good Condition",
        damageRange = { 0.05, 0.20 },   -- 5-20% damage
        wearRange = { 0.08, 0.25 },      -- 8-25% wear
        priceMultiplier = 0.78           -- 22% off (was 35%)
    },
    {  -- Excellent Condition: Low damage/wear
        name = "Excellent Condition",
        damageRange = { 0.01, 0.10 },   -- 1-10% damage
        wearRange = { 0.02, 0.12 },      -- 2-12% wear
        priceMultiplier = 0.88           -- 12% off (was 20%)
    }
}

--[[
    Search tier condition modifiers
    Higher tier = better chance of finding good condition vehicles
    Local (1): Worse condition, more old vehicles
    Regional (2): Normal condition distribution
    National (3): Better condition, more recent vehicles
]]
DepreciationCalculations.TIER_MODIFIERS = {
    [1] = {  -- Local: Worse quality
        generationWeights = { 0.20, 0.50, 0.30 },  -- 20% recent, 50% mid-age, 30% old
        damageMultiplier = 1.3,   -- 30% more damage
        wearMultiplier = 1.3,     -- 30% more wear
    },
    [2] = {  -- Regional: Normal quality
        generationWeights = { 0.40, 0.40, 0.20 },  -- 40% recent, 40% mid-age, 20% old
        damageMultiplier = 1.0,   -- Normal damage
        wearMultiplier = 1.0,     -- Normal wear
    },
    [3] = {  -- National: Better quality
        generationWeights = { 0.55, 0.35, 0.10 },  -- 55% recent, 35% mid-age, 10% old
        damageMultiplier = 0.7,   -- 30% less damage
        wearMultiplier = 0.7,     -- 30% less wear
    }
}

--[[
    Select random generation
    Can be weighted or forced for specific searches
    searchLevel affects generation distribution
    Returns: generation index (1, 2, or 3)
]]
function DepreciationCalculations.selectGeneration(preferredGeneration, searchLevel)
    if preferredGeneration ~= nil then
        return preferredGeneration
    end

    -- Get tier modifier (default to regional/normal if not specified)
    local tierMod = DepreciationCalculations.TIER_MODIFIERS[searchLevel] or DepreciationCalculations.TIER_MODIFIERS[2]
    local weights = tierMod.generationWeights

    -- Random generation selection based on tier weights
    math.random()  -- Dry run for better randomness
    local roll = math.random()

    if roll <= weights[1] then
        return 1  -- Recent
    elseif roll <= (weights[1] + weights[2]) then
        return 2  -- Mid-age
    else
        return 3  -- Old
    end
end

--[[
    Generate random value within a range
    Uses linear interpolation
]]
function DepreciationCalculations.getRandomValue(range)
    math.random()  -- Dry run
    return range[1] + math.random() * (range[2] - range[1])
end

--[[
    Generate complete used vehicle parameters
    searchLevel affects generation distribution (age)
    qualityLevel determines damage/wear ranges (player's condition preference)
    Returns table with: age, damage, wear, hours, discount, generation, qualityLevel
]]
function DepreciationCalculations.generateUsedVehicleParams(preferredGeneration, searchLevel, qualityLevel)
    local generationIndex = DepreciationCalculations.selectGeneration(preferredGeneration, searchLevel)
    local generation = DepreciationCalculations.GENERATIONS[generationIndex]

    -- Get tier modifier for search level adjustments (affects generation probability)
    local tierMod = DepreciationCalculations.TIER_MODIFIERS[searchLevel] or DepreciationCalculations.TIER_MODIFIERS[2]

    -- Get quality tier for damage/wear ranges (player's condition preference)
    qualityLevel = qualityLevel or 1  -- Default to "Any Condition"
    local qualityTier = DepreciationCalculations.QUALITY_TIERS[qualityLevel] or DepreciationCalculations.QUALITY_TIERS[1]

    -- Random values within generation ranges
    local age = math.random(1, generation.maxAge)
    local hoursPerYear = DepreciationCalculations.getRandomValue(generation.hours)
    local discount = DepreciationCalculations.getRandomValue(generation.discount)

    -- Generate damage/wear based on QUALITY TIER (player's preference)
    -- Then apply SEARCH TIER modifier (local finds worse condition, national finds better)
    local baseDamage = DepreciationCalculations.getRandomValue(qualityTier.damageRange)
    local baseWear = DepreciationCalculations.getRandomValue(qualityTier.wearRange)

    local damage = math.min(0.95, math.max(0.01, baseDamage * tierMod.damageMultiplier))
    local wear = math.min(0.95, math.max(0.01, baseWear * tierMod.wearMultiplier))

    -- Calculate total operating hours
    local operatingHours = age * hoursPerYear

    UsedPlus.logDebug(string.format("Generated vehicle params: quality=%s, searchTier=%d",
        qualityTier.name, searchLevel))
    UsedPlus.logDebug(string.format("  Damage: %.1f%%, Wear: %.1f%%, Age: %d years, Hours: %d",
        damage * 100, wear * 100, age, operatingHours))

    return {
        age = age,
        damage = damage,
        wear = wear,
        operatingHours = operatingHours,
        discount = discount,
        generation = generationIndex,
        generationName = generation.name,
        searchLevel = searchLevel,
        qualityLevel = qualityLevel,
        qualityName = qualityTier.name
    }
end

--[[
    Calculate used vehicle price using quality tier multiplier
    The game's calculateSellPrice deducts repair costs which makes poor condition
    vehicles nearly worthless. Instead, we use quality-based pricing that reflects
    what buyers would actually pay for a fixer-upper.
    Returns: usedPrice, repairCost, repaintCost
]]
function DepreciationCalculations.calculateUsedPrice(storeItem, params)
    -- Get base price with configurations
    local defaultPrice = StoreItemUtil.getDefaultPrice(storeItem, {})

    -- Calculate repair and repaint costs using game formulas (for display)
    local repairPrice = 0
    local repaintPrice = 0
    if Wearable and Wearable.calculateRepairPrice then
        repairPrice = Wearable.calculateRepairPrice(defaultPrice, params.damage)
    end
    if Wearable and Wearable.calculateRepaintPrice then
        repaintPrice = Wearable.calculateRepaintPrice(defaultPrice, params.wear)
    end

    -- Get quality tier for price multiplier
    local qualityTier = DepreciationCalculations.QUALITY_TIERS[params.qualityLevel] or DepreciationCalculations.QUALITY_TIERS[1]
    local qualityMultiplier = qualityTier.priceMultiplier or 0.5

    -- Age-based depreciation (vehicles lose value over time)
    -- BALANCE NOTE (v1.2): Reduced from 5%/year (max 50%) to 3%/year (max 25%)
    -- This prevents age from stacking too aggressively with quality discounts
    local ageDepreciation = math.min(0.25, (params.age or 0) * 0.03)
    local ageMultiplier = 1.0 - ageDepreciation

    -- Calculate used price:
    -- Base price * quality multiplier * age multiplier
    -- This gives reasonable prices even for poor condition vehicles
    local usedPrice = defaultPrice * qualityMultiplier * ageMultiplier

    -- Ensure minimum price of 5% of base (vehicles are never completely worthless)
    local minPrice = defaultPrice * 0.05
    usedPrice = math.max(usedPrice, minPrice)

    UsedPlus.logDebug(string.format("Price calc: base=$%.0f, quality=%.0f%%, age=%.0f%%, final=$%.0f",
        defaultPrice, qualityMultiplier * 100, ageMultiplier * 100, usedPrice))

    return math.floor(usedPrice), math.floor(repairPrice), math.floor(repaintPrice)
end

--[[
    Create used vehicle sale entry for game's vehicle sale system
    This adds the vehicle to the in-game used vehicles shop
    Returns: sale ID (or nil if failed)
]]
function DepreciationCalculations.createUsedVehicleSale(storeItem, params, configurations)
    if not g_server then
        UsedPlus.logWarn("createUsedVehicleSale must be called on server")
        return nil
    end

    -- Calculate used price
    local usedPrice, repairPrice, repaintPrice = DepreciationCalculations.calculateUsedPrice(storeItem, params)

    -- Convert operating hours to milliseconds
    local operatingTime = params.operatingHours * 60 * 60 * 1000

    -- Create sale entry (pattern from BuyUsedEquipment)
    local saleEntry = {
        -- Time until sale expires (24-72 hours)
        timeLeft = math.random(24, 72),

        -- Mark as player-generated (not random)
        isGenerated = false,

        -- Vehicle identification
        xmlFilename = storeItem.xmlFilename,

        -- Condition parameters
        age = params.age,
        damage = params.damage,
        wear = params.wear,
        operatingTime = operatingTime,

        -- Pricing
        price = usedPrice,

        -- Configurations (if any)
        configurations = configurations or {}
    }

    -- Add to game's vehicle sale system
    local saleId = g_currentMission.vehicleSaleSystem:addSale(saleEntry)

    return saleId
end

--[[
    Get condition rating text for display
    Based on average of damage and wear
]]
function DepreciationCalculations.getConditionRating(damage, wear)
    local condition = (damage + wear) / 2

    if condition <= 0.10 then
        return g_i18n:getText("usedplus_condition_excellent"), 1
    elseif condition <= 0.25 then
        return g_i18n:getText("usedplus_condition_good"), 2
    elseif condition <= 0.45 then
        return g_i18n:getText("usedplus_condition_fair"), 3
    else
        return g_i18n:getText("usedplus_condition_poor"), 4
    end
end

--[[
    Format vehicle age for display
]]
function DepreciationCalculations.formatAge(ageYears)
    if ageYears == 1 then
        return g_i18n:getText("usedplus_age_oneYear")
    else
        return string.format(g_i18n:getText("usedplus_age_years"), ageYears)
    end
end

--[[
    Format operating hours for display
]]
function DepreciationCalculations.formatOperatingHours(hours)
    return string.format(g_i18n:getText("usedplus_hours"), math.floor(hours))
end

--[[
    Get discount percentage text for display
]]
function DepreciationCalculations.formatDiscount(discount)
    return string.format("%.0f%% OFF", discount * 100)
end

--[[
    Estimate value of player's vehicle for trade-in/credit
    Uses same depreciation system but from current vehicle state
]]
function DepreciationCalculations.estimateVehicleValue(vehicle)
    if vehicle == nil then
        return 0
    end

    -- Get store item for base price
    local storeItem = g_storeManager:getItemByXMLFilename(vehicle.configFileName)
    if storeItem == nil then
        return 0
    end

    -- Get current vehicle condition
    local age = vehicle.age or 0
    local operatingTime = vehicle.operatingTime or 0
    local damage = 0
    local wear = 0

    if vehicle.spec_wearable then
        damage = vehicle.spec_wearable.damage or 0
        wear = vehicle.spec_wearable.wear or 0
    end

    -- Calculate using game's system
    local defaultPrice = storeItem.price
    local repairPrice = Wearable.calculateRepairPrice(defaultPrice, damage)
    local repaintPrice = Wearable.calculateRepaintPrice(defaultPrice, wear)

    local value = Vehicle.calculateSellPrice(
        storeItem,
        age,
        operatingTime,
        defaultPrice,
        repairPrice,
        repaintPrice
    )

    return math.floor(value)
end

UsedPlus.logInfo("DepreciationCalculations utility loaded")
