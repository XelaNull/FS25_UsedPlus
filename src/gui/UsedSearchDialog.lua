--[[
    FS25_UsedPlus - Used Search Dialog

     GUI class for used equipment search tier selection
     Pattern from: Game's mission dialogs with option selection
     Reference: FS25_ADVANCED_PATTERNS.md - GUI Dialog Pattern

    Responsibilities:
    - Display store item being searched
    - Show 3 search tier options (Local/National/International)
    - Display tier comparison (cost, duration, success%, match%)
    - Allow single tier selection via checkbox/radio buttons
    - Send RequestUsedItemEvent on "Start Search"

    Search Tiers (REBALANCED to fix Local loophole):
    - Local: 4% cost, 0-1 months, 25% success, 25% match (quick but low odds)
    - Regional: 6% cost, 1-2 months, 55% success, 50% match (best value)
    - National: 10% cost, 2-4 months, 80% success, 70% match (high certainty)
]]

UsedSearchDialog = {}
local UsedSearchDialog_mt = Class(UsedSearchDialog, MessageDialog)

--[[
     Constructor
]]
function UsedSearchDialog.new(target, customMt, i18n)
    local self = MessageDialog.new(target, customMt or UsedSearchDialog_mt)

    -- Controls are automatically mapped by g_gui:loadGui() based on XML id attributes
    -- Available controls after loadGui:
    --   self.itemImage, self.itemNameText, self.itemPriceText
    --   self.localCheckbox, self.localCostText, self.localDurationText, self.localSuccessText, self.localMatchText
    --   self.regionalCheckbox, self.regionalCostText, self.regionalDurationText, self.regionalSuccessText, self.regionalMatchText
    --   self.nationalCheckbox, self.nationalCostText, self.nationalDurationText, self.nationalSuccessText, self.nationalMatchText

    self.storeItem = nil
    self.storeItemIndex = nil
    self.basePrice = 0
    self.farmId = nil
    self.selectedTier = 1  -- Default: Local (1=Local, 2=Regional, 3=National)
    self.selectedQuality = 1  -- Default: Any Condition (1=Any, 2=Poor, 3=Fair, 4=Good, 5=Excellent)
    self.i18n = i18n

    return self
end

--[[
     Called when dialog is created (required by GUI system)
]]
function UsedSearchDialog:onCreate()
    UsedSearchDialog:superClass().onCreate(self)
end

--[[
     Quality tier definitions
     Lower quality = lower price, but needs repairs
     Array order: 1=Any, 2=Poor, 3=Fair, 4=Good, 5=Excellent
     Display order (leftmost to rightmost): Any, Poor, Fair, Good, Excellent
     successModifier affects the base success rate from search tier
]]
UsedSearchDialog.QUALITY_TIERS = {
    {  -- Any Condition (catch-all, may need lots of work)
        name = "Any Condition",
        minCondition = 0.10,
        maxCondition = 0.40,
        priceMultiplier = 0.30,  -- 30% of new price (70% off)
        successModifier = 0.08,  -- +8% easier to find rough equipment
        description = "Cheapest option - may need significant repairs"
    },
    {  -- Poor Condition (worst - may be inoperable!)
        name = "Poor Condition",
        minCondition = 0.05,
        maxCondition = 0.30,
        priceMultiplier = 0.15,  -- 15% of new price (85% off!)
        successModifier = 0.15,  -- +15% easier to find junk
        description = "Bargain bin - may need extensive repairs or be inoperable"
    },
    {  -- Fair Condition
        name = "Fair Condition",
        minCondition = 0.40,
        maxCondition = 0.60,
        priceMultiplier = 0.48,  -- 48% of new price (52% off)
        successModifier = 0.00,  -- Baseline (no modifier)
        description = "Moderate wear - some repairs likely needed"
    },
    {  -- Good Condition
        name = "Good Condition",
        minCondition = 0.60,
        maxCondition = 0.80,
        priceMultiplier = 0.65,  -- 65% of new price (35% off)
        successModifier = -0.08, -- -8% harder to find well-maintained
        description = "Well maintained - minimal repairs needed"
    },
    {  -- Excellent Condition
        name = "Excellent Condition",
        minCondition = 0.80,
        maxCondition = 0.95,
        priceMultiplier = 0.80,  -- 80% of new price (20% off)
        successModifier = -0.15, -- -15% harder to find pristine
        description = "Like new - ready to work immediately"
    }
}

--[[
     Credit score modifiers for agent fees
     Better credit = cheaper agent services (they trust you more)
]]
UsedSearchDialog.CREDIT_FEE_MODIFIERS = {
    {minScore = 750, modifier = -0.15, name = "Excellent"},  -- 15% discount
    {minScore = 700, modifier = -0.08, name = "Good"},       -- 8% discount
    {minScore = 650, modifier = 0.00,  name = "Fair"},       -- No change
    {minScore = 600, modifier = 0.10,  name = "Poor"},       -- 10% surcharge
    {minScore = 300, modifier = 0.20,  name = "Very Poor"}   -- 20% surcharge
}

--[[
     Get credit score fee modifier based on player's credit
     @return modifier (negative = discount, positive = surcharge)
]]
function UsedSearchDialog:getCreditFeeModifier()
    local farm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)
    if not farm or not CreditScore then
        return 0
    end

    local score = CreditScore.calculate(farm.farmId)
    for _, tier in ipairs(UsedSearchDialog.CREDIT_FEE_MODIFIERS) do
        if score >= tier.minScore then
            return tier.modifier
        end
    end
    return 0.20  -- Default to worst tier
end

--[[
     Calculate adjusted success rate based on tier and quality
     @param tierSuccessRate - Base success rate from search tier (0.0-1.0)
     @param qualityIndex - Selected quality tier index (1-5)
     @return adjusted success rate (clamped to 0.05-0.95)
]]
function UsedSearchDialog:getAdjustedSuccessRate(tierSuccessRate, qualityIndex)
    local quality = UsedSearchDialog.QUALITY_TIERS[qualityIndex]
    if not quality then
        return tierSuccessRate
    end

    local adjusted = tierSuccessRate + (quality.successModifier or 0)
    -- Clamp to reasonable bounds (5% minimum, 95% maximum)
    return math.max(0.05, math.min(0.95, adjusted))
end

--[[
     Called when dialog opens (required by GUI system)
]]
function UsedSearchDialog:onOpen()
    UsedSearchDialog:superClass().onOpen(self)

    -- Set default selections
    self:selectTier(1)
    self:selectQuality(1)  -- Default to "Any Condition" (index 1, Poor is index 2)
end

--[[
     Initialize dialog with item data
]]
function UsedSearchDialog:setData(storeItem, storeItemIndex, farmId)
    self.storeItem = storeItem
    self.storeItemIndex = storeItemIndex
    self.farmId = farmId

    -- DEBUG - Dump all storeItem properties
    UsedPlus.logTrace("=== STORE ITEM DEBUG ===")
    UsedPlus.logTrace(string.format("storeItem.name: %s", tostring(storeItem.name)))
    UsedPlus.logTrace(string.format("storeItem.category: %s", tostring(storeItem.category)))
    UsedPlus.logTrace(string.format("storeItem.categoryName: %s", tostring(storeItem.categoryName)))
    UsedPlus.logTrace(string.format("storeItem.brand: %s", tostring(storeItem.brand)))
    UsedPlus.logTrace(string.format("storeItem.configurations: %s", tostring(storeItem.configurations)))

    if storeItem.configurations then
        UsedPlus.logTrace(string.format("configurations type: %s", type(storeItem.configurations)))
        if type(storeItem.configurations) == "table" then
            UsedPlus.logTrace(string.format("configurations count: %d", #storeItem.configurations))
            for i, config in ipairs(storeItem.configurations) do
                UsedPlus.logTrace(string.format("  Config %d: name=%s, title=%s", i, tostring(config.name), tostring(config.title)))
            end
        end
    end

    UsedPlus.logTrace("=== END STORE ITEM DEBUG ===")

    self.basePrice = StoreItemUtil.getDefaultPrice(storeItem, {})

    -- Get vehicle name using consolidated utility
    self.vehicleName = UIHelper.Vehicle.getFullName(storeItem)

    -- Populate item details
    if self.itemNameText then
        self.itemNameText:setText(self.vehicleName)
    end

    if self.itemPriceText then
        self.itemPriceText:setText(string.format("%s %s", g_i18n:getText("usedplus_search_newPrice"), g_i18n:formatMoney(self.basePrice)))
    end

    -- Set category text (human-readable) - category only, no brand (brand is in name now)
    if self.itemCategoryText then
        local categoryText = ""

        -- Use categoryName (not category - that's nil!)
        local categoryKey = storeItem.categoryName or storeItem.category
        UsedPlus.logTrace(string.format("Category key: %s", tostring(categoryKey)))

        -- Get human-readable category name
        if categoryKey then
            local category = g_storeManager:getCategoryByName(categoryKey)
            if category then
                UsedPlus.logTrace("  Category object found")
                if category.title then
                    -- category.title might be plain text or l10n key
                    if type(category.title) == "string" and category.title:sub(1, 1) == "$" then
                        -- It's a translation key, translate it
                        categoryText = g_i18n:getText(category.title:sub(2))
                    else
                        -- It's already translated text, use as-is
                        categoryText = category.title
                    end
                    UsedPlus.logTrace(string.format("  Category title: %s", categoryText))
                else
                    categoryText = categoryKey
                end
            else
                UsedPlus.logTrace("  Category object NOT found, using raw key")
                categoryText = categoryKey
            end
        end

        UsedPlus.logTrace(string.format("Final category text: '%s'", categoryText))
        self.itemCategoryText:setText(categoryText)
        self.itemCategoryText:setVisible(true)
    else
        UsedPlus.logWarn("itemCategoryText element not found!")
    end

    -- Set item image with dynamic scaling to prevent stretching
    -- Using 210x105 (2:1 ratio) to match FS25 store image format (512x256)
    if self.itemImage then
        UIHelper.Image.setStoreItemImageScaled(self.itemImage, storeItem, 210, 105)
    end

    -- Define search tier data (matches UsedVehicleSearch.lua)
    -- REBALANCED to fix Local loophole - see UsedVehicleSearch.calculateSearchParams()
    -- Store as instance variable so we can recalculate on quality change
    self.SEARCH_TIERS = {
        { -- Local Search - Quick but expensive per success (impatient tax)
            feePercent = 0.04,       -- 4% of base price
            minMonths = 0, maxMonths = 1,  -- Can be instant!
            successChance = 0.25,    -- 25% success (low odds)
            matchChance = 0.25       -- 25% config match
        },
        { -- Regional Search - Best value, balanced option (smart choice)
            feePercent = 0.06,       -- 6% of base price
            minMonths = 1, maxMonths = 2,  -- 1-2 months
            successChance = 0.55,    -- 55% success
            matchChance = 0.50       -- 50% config match
        },
        { -- National Search - High certainty, worth the wait (certainty premium)
            feePercent = 0.10,       -- 10% of base price
            minMonths = 2, maxMonths = 4,  -- 2-4 months
            successChance = 0.80,    -- 80% success
            matchChance = 0.70       -- 70% config match
        }
    }

    -- Get credit fee modifier (better credit = cheaper agents)
    local creditFeeModifier = self:getCreditFeeModifier()
    self.creditFeeModifier = creditFeeModifier  -- Store for later use

    -- Populate tier displays using UIHelper (with credit-adjusted fees)
    for i, tier in ipairs(self.SEARCH_TIERS) do
        -- Apply credit modifier to fee
        local adjustedFeePercent = tier.feePercent * (1 + creditFeeModifier)
        local cost = math.floor(self.basePrice * adjustedFeePercent)

        local durationText
        if tier.minMonths == 0 then
            -- Local can be instant
            durationText = tier.maxMonths == 1 and "Up to 1 month" or string.format("Up to %d months", tier.maxMonths)
        elseif tier.minMonths == tier.maxMonths then
            durationText = string.format("%d month%s", tier.minMonths, tier.minMonths > 1 and "s" or "")
        else
            durationText = string.format("%d-%d months", tier.minMonths, tier.maxMonths)
        end

        -- Show base success (will be modified by quality selection)
        local successText = UIHelper.Text.formatPercent(tier.successChance, true, 0)
        local matchText = UIHelper.Text.formatPercent(tier.matchChance, true, 0)

        local prefix = ({"local", "regional", "national"})[i]
        UIHelper.Element.setText(self[prefix .. "CostText"], UIHelper.Text.formatMoney(cost))
        UIHelper.Element.setText(self[prefix .. "DurationText"], durationText)
        UIHelper.Element.setText(self[prefix .. "SuccessText"], successText)
        UIHelper.Element.setText(self[prefix .. "MatchText"], matchText)

        -- Show credit discount/surcharge indicator if not neutral
        if creditFeeModifier ~= 0 then
            local discountText = creditFeeModifier < 0
                and string.format(" (-%d%% credit)", math.abs(creditFeeModifier * 100))
                or string.format(" (+%d%% credit)", creditFeeModifier * 100)
            -- Note: Could add a credit indicator element here if desired
        end
    end

    -- Populate quality tier displays using UIHelper
    -- Order matches QUALITY_TIERS: 1=Any, 2=Poor, 3=Fair, 4=Good, 5=Excellent
    local qualityPrefixes = {"anyCondition", "poorCondition", "fairCondition", "goodCondition", "excellentCondition"}
    for i, quality in ipairs(UsedSearchDialog.QUALITY_TIERS) do
        local estimatedPrice = math.floor(self.basePrice * quality.priceMultiplier)

        -- Show success modifier with the price
        local successMod = quality.successModifier or 0
        local modifierText = ""
        if successMod > 0 then
            modifierText = string.format(" +%d%%", successMod * 100)
        elseif successMod < 0 then
            modifierText = string.format(" %d%%", successMod * 100)
        end

        -- Display estimated price and success modifier hint
        UIHelper.Element.setText(self[qualityPrefixes[i] .. "PriceText"], "~" .. UIHelper.Text.formatMoney(estimatedPrice))
    end

    -- Default selection set in onOpen()
    -- Initial rate update will happen after selectTier and selectQuality
end

--[[
     Update displayed success rates based on current tier and quality selection
     Called when either tier or quality selection changes
]]
function UsedSearchDialog:updateDisplayedRates()
    if not self.SEARCH_TIERS then
        return
    end

    local selectedQuality = self.selectedQuality or 2  -- Default to Any
    local quality = UsedSearchDialog.QUALITY_TIERS[selectedQuality]
    local successMod = quality and quality.successModifier or 0

    -- Update each tier's success rate display with quality modifier applied
    local prefixes = {"local", "regional", "national"}
    for i, tier in ipairs(self.SEARCH_TIERS) do
        local adjustedSuccess = self:getAdjustedSuccessRate(tier.successChance, selectedQuality)
        local successText = UIHelper.Text.formatPercent(adjustedSuccess, true, 0)

        -- Add modifier indicator if not baseline
        if successMod ~= 0 then
            local modSign = successMod > 0 and "+" or ""
            successText = successText .. string.format(" (%s%d%%)", modSign, successMod * 100)
        end

        UIHelper.Element.setText(self[prefixes[i] .. "SuccessText"], successText)
    end
end

--[[
     Select a search tier (radio button behavior)
     Only one tier can be selected at a time
]]
function UsedSearchDialog:selectTier(tier)
    self.selectedTier = tier

    -- Colors for selected vs unselected (using FS25 standard orange/gold)
    local selectedTextColor = {1, 0.8, 0, 1}         -- Gold text (matches section titles)
    local unselectedTextColor = {0.7, 0.7, 0.7, 1}   -- Gray text
    local selectedBgColor = {1, 0.5, 0, 0.4}         -- FS25 orange highlight (semi-transparent)
    local unselectedBgColor = {0, 0, 0, 0}           -- Transparent background

    -- Update background colors (solid color highlighting)
    if self.localBg then
        self.localBg:setImageColor(nil, unpack(tier == 1 and selectedBgColor or unselectedBgColor))
    end
    if self.regionalBg then
        self.regionalBg:setImageColor(nil, unpack(tier == 2 and selectedBgColor or unselectedBgColor))
    end
    if self.nationalBg then
        self.nationalBg:setImageColor(nil, unpack(tier == 3 and selectedBgColor or unselectedBgColor))
    end

    -- Change name color when selected
    if self.localName then
        self.localName:setTextColor(unpack(tier == 1 and selectedTextColor or unselectedTextColor))
    end
    if self.regionalName then
        self.regionalName:setTextColor(unpack(tier == 2 and selectedTextColor or unselectedTextColor))
    end
    if self.nationalName then
        self.nationalName:setTextColor(unpack(tier == 3 and selectedTextColor or unselectedTextColor))
    end
end

--[[
     Checkbox callbacks (exclusive selection)
]]
function UsedSearchDialog:onLocalSelected()
    self:selectTier(1)
end

function UsedSearchDialog:onRegionalSelected()
    self:selectTier(2)
end

function UsedSearchDialog:onNationalSelected()
    self:selectTier(3)
end

--[[
     Select a quality tier (radio button behavior)
     Only one quality can be selected at a time
     Quality indices: 1=Poor, 2=Any, 3=Fair, 4=Good, 5=Excellent
]]
function UsedSearchDialog:selectQuality(quality)
    self.selectedQuality = quality

    -- Colors for selected vs unselected (using FS25 standard orange/gold)
    local selectedTextColor = {1, 0.8, 0, 1}         -- Gold text (matches section titles)
    local unselectedTextColor = {0.7, 0.7, 0.7, 1}   -- Gray text
    local selectedBgColor = {1, 0.5, 0, 0.4}         -- FS25 orange highlight (semi-transparent)
    local unselectedBgColor = {0, 0, 0, 0}           -- Transparent background

    -- Update background colors (solid color highlighting)
    -- Indices match QUALITY_TIERS: 1=Any, 2=Poor, 3=Fair, 4=Good, 5=Excellent
    if self.anyBg then
        self.anyBg:setImageColor(nil, unpack(quality == 1 and selectedBgColor or unselectedBgColor))
    end
    if self.poorBg then
        self.poorBg:setImageColor(nil, unpack(quality == 2 and selectedBgColor or unselectedBgColor))
    end
    if self.fairBg then
        self.fairBg:setImageColor(nil, unpack(quality == 3 and selectedBgColor or unselectedBgColor))
    end
    if self.goodBg then
        self.goodBg:setImageColor(nil, unpack(quality == 4 and selectedBgColor or unselectedBgColor))
    end
    if self.excellentBg then
        self.excellentBg:setImageColor(nil, unpack(quality == 5 and selectedBgColor or unselectedBgColor))
    end

    -- Change name color when selected
    -- Indices match QUALITY_TIERS: 1=Any, 2=Poor, 3=Fair, 4=Good, 5=Excellent
    if self.anyName then
        self.anyName:setTextColor(unpack(quality == 1 and selectedTextColor or unselectedTextColor))
    end
    if self.poorName then
        self.poorName:setTextColor(unpack(quality == 2 and selectedTextColor or unselectedTextColor))
    end
    if self.fairName then
        self.fairName:setTextColor(unpack(quality == 3 and selectedTextColor or unselectedTextColor))
    end
    if self.goodName then
        self.goodName:setTextColor(unpack(quality == 4 and selectedTextColor or unselectedTextColor))
    end
    if self.excellentName then
        self.excellentName:setTextColor(unpack(quality == 5 and selectedTextColor or unselectedTextColor))
    end

    -- Update displayed success rates to reflect quality modifier
    self:updateDisplayedRates()
end

--[[
     Quality checkbox callbacks (exclusive selection)
     Indices match QUALITY_TIERS array: 1=Any, 2=Poor, 3=Fair, 4=Good, 5=Excellent
]]
function UsedSearchDialog:onAnyConditionSelected()
    self:selectQuality(1)
end

function UsedSearchDialog:onPoorConditionSelected()
    self:selectQuality(2)
end

function UsedSearchDialog:onFairConditionSelected()
    self:selectQuality(3)
end

function UsedSearchDialog:onGoodConditionSelected()
    self:selectQuality(4)
end

function UsedSearchDialog:onExcellentConditionSelected()
    self:selectQuality(5)
end

--[[
     Start Search button callback
]]
function UsedSearchDialog:onStartSearch()
    if self.storeItem == nil then
        UsedPlus.logError("No item selected for search")
        return
    end

    -- Calculate search fee (includes duration for confirmation message)
    -- REBALANCED values - must match self.SEARCH_TIERS and UsedVehicleSearch.lua
    local SEARCH_TIERS = {
        { feePercent = 0.04, name = "Local", minMonths = 0, maxMonths = 1 },
        { feePercent = 0.06, name = "Regional", minMonths = 1, maxMonths = 2 },
        { feePercent = 0.10, name = "National", minMonths = 2, maxMonths = 4 }
    }

    local tier = SEARCH_TIERS[self.selectedTier]

    -- Apply credit score modifier to fee (better credit = cheaper agents)
    local creditFeeModifier = self:getCreditFeeModifier()
    local adjustedFeePercent = tier.feePercent * (1 + creditFeeModifier)
    local searchFee = math.floor(self.basePrice * adjustedFeePercent)

    -- Get quality tier info
    local qualityTier = UsedSearchDialog.QUALITY_TIERS[self.selectedQuality]
    local estimatedPrice = math.floor(self.basePrice * qualityTier.priceMultiplier)

    -- Validate funds
    local farm = g_farmManager:getFarmById(self.farmId)
    if farm == nil then
        UsedPlus.logError("Farm not found")
        return
    end

    if farm.money < searchFee then
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
            string.format(g_i18n:getText("usedplus_error_insufficientFunds"), g_i18n:formatMoney(searchFee))
        )
        return
    end

    -- Store data for use after dialog closes
    local itemName = self.vehicleName or self.storeItem.name
    local storeItemIndex = self.storeItemIndex
    local basePrice = self.basePrice
    local farmId = self.farmId
    local selectedTier = self.selectedTier
    local selectedQuality = self.selectedQuality

    -- Log before closing (close() may clear data)
    UsedPlus.logDebug(string.format("Search request sent: %s (Tier %d, Quality %d, Fee: $%d)",
        itemName, selectedTier, selectedQuality, searchFee))

    -- Send search request to server with quality level
    RequestUsedItemEvent.sendToServer(
        farmId,
        storeItemIndex,
        itemName,
        basePrice,
        selectedTier,
        selectedQuality  -- Pass quality level instead of configId
    )

    -- Close dialog first
    self:close()

    -- Build confirmation message with duration info
    local tierName = tier.name
    local qualityName = qualityTier.name
    local durationText
    if tier.minMonths == 0 then
        durationText = tier.maxMonths == 1 and "Up to 1 month" or string.format("Up to %d months", tier.maxMonths)
    elseif tier.minMonths == tier.maxMonths then
        durationText = string.format("%d month", tier.minMonths)
    else
        durationText = string.format("%d-%d months", tier.minMonths, tier.maxMonths)
    end

    local confirmationMessage = string.format(
        "Search initiated for %s!\n\n" ..
        "Search Type: %s\n" ..
        "Quality: %s\n" ..
        "Estimated Price: %s\n" ..
        "Search Duration: %s\n\n" ..
        "Your agent will notify you when a match is found.",
        itemName, tierName, qualityName,
        UIHelper.Text.formatMoney(estimatedPrice), durationText
    )

    -- Show confirmation dialog popup (visible even in menus)
    -- Uses our own ConfirmationDialog via DialogLoader
    DialogLoader.show("ConfirmationDialog", "setMessage", confirmationMessage, g_i18n:getText("usedplus_search_confirmTitle") or "Search Initiated")

    -- Also add corner notification for when they exit menus
    g_currentMission:addIngameNotification(
        FSBaseMission.INGAME_NOTIFICATION_OK,
        string.format("Search initiated for %s (%s, %s)", itemName, tierName, durationText)
    )
end

--[[
     Cancel button callback
]]
function UsedSearchDialog:onCancel()
    self:close()
end

--[[
     Cleanup
]]
function UsedSearchDialog:onClose()
    self.storeItem = nil
    self.storeItemIndex = nil
    self.vehicleName = nil
    self.basePrice = 0
    self.farmId = nil
    self.selectedTier = 1
    self.selectedQuality = 1  -- Reset quality selection

    UsedSearchDialog:superClass().onClose(self)
end

UsedPlus.logInfo("UsedSearchDialog loaded")
