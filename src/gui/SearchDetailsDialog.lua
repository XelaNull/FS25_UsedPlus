--[[
    SearchDetailsDialog.lua
    Dialog showing details about an active used vehicle search

    Displays:
    - Vehicle being searched for
    - Search tier and quality tier
    - Agent fee and success chances
    - Expected pricing and savings
    - Time remaining
]]

SearchDetailsDialog = {}
-- Use ScreenElement, NOT MessageDialog (MessageDialog lacks registerControls)
local SearchDetailsDialog_mt = Class(SearchDetailsDialog, ScreenElement)

-- Static instance
SearchDetailsDialog.instance = nil
SearchDetailsDialog.xmlPath = nil

-- Search tier definitions (must match UsedVehicleSearch)
SearchDetailsDialog.SEARCH_TIERS = {
    { name = "Local Search", feePercent = 0.04, baseSuccess = 0.25 },
    { name = "Regional Search", feePercent = 0.06, baseSuccess = 0.55 },
    { name = "National Search", feePercent = 0.10, baseSuccess = 0.80 }
}

--[[
    Get or create dialog instance
]]
function SearchDetailsDialog.getInstance()
    if SearchDetailsDialog.instance == nil then
        if SearchDetailsDialog.xmlPath == nil then
            SearchDetailsDialog.xmlPath = UsedPlus.MOD_DIR .. "gui/SearchDetailsDialog.xml"
        end

        SearchDetailsDialog.instance = SearchDetailsDialog.new()
        g_gui:loadGui(SearchDetailsDialog.xmlPath, "SearchDetailsDialog", SearchDetailsDialog.instance)
    end

    return SearchDetailsDialog.instance
end

--[[
    Constructor
]]
function SearchDetailsDialog.new(target, customMt)
    local self = ScreenElement.new(target, customMt or SearchDetailsDialog_mt)

    self.search = nil
    self.isBackAllowed = true

    return self
end

--[[
    Called when dialog is created
]]
function SearchDetailsDialog:onCreate()
    -- No superclass call needed for ScreenElement
end

--[[
    Show dialog with search information
    @param search - UsedVehicleSearch object
]]
function SearchDetailsDialog:show(search)
    if search == nil then
        UsedPlus.logError("SearchDetailsDialog:show called with nil search")
        return
    end

    self.search = search

    -- Populate all fields
    self:updateDisplay()

    -- Show the dialog
    g_gui:showDialog("SearchDetailsDialog")
end

--[[
    Update all display fields with search data
]]
function SearchDetailsDialog:updateDisplay()
    if self.search == nil then return end

    local search = self.search

    -- Vehicle Info
    if self.vehicleNameText then
        self.vehicleNameText:setText(search.storeItemName or "Unknown Vehicle")
    end

    -- Search Tier
    local searchTier = SearchDetailsDialog.SEARCH_TIERS[search.searchLevel] or SearchDetailsDialog.SEARCH_TIERS[2]
    if self.searchTierText then
        self.searchTierText:setText(searchTier.name)
    end

    if self.agentFeeText then
        local feePercent = searchTier.feePercent * 100
        self.agentFeeText:setText(string.format("%s (%.0f%%)",
            g_i18n:formatMoney(search.searchCost or 0, 0, true, true),
            feePercent))
    end

    if self.baseSuccessText then
        self.baseSuccessText:setText(string.format("%.0f%%", searchTier.baseSuccess * 100))
    end

    -- Quality Tier
    local qualityTier = UsedVehicleSearch.QUALITY_TIERS[search.qualityLevel] or UsedVehicleSearch.QUALITY_TIERS[1]
    if self.qualityTierText then
        self.qualityTierText:setText(qualityTier.name)
    end

    if self.successModText then
        local successMod = (qualityTier.successModifier or 0) * 100
        local modText = string.format("%+.0f%%", successMod)
        self.successModText:setText(modText)

        if successMod > 0 then
            self.successModText:setTextColor(0.3, 1, 0.3, 1)  -- Green - easier
        elseif successMod < 0 then
            self.successModText:setTextColor(1, 0.4, 0.4, 1)  -- Red - harder
        else
            self.successModText:setTextColor(0.7, 0.7, 0.7, 1)  -- Gray
        end
    end

    -- Combined success chance
    if self.combinedChanceText then
        local combinedChance = searchTier.baseSuccess + (qualityTier.successModifier or 0)
        combinedChance = math.max(0.05, math.min(0.95, combinedChance))
        self.combinedChanceText:setText(string.format("%.0f%%", combinedChance * 100))

        -- Color based on chance
        if combinedChance >= 0.70 then
            self.combinedChanceText:setTextColor(0.3, 1, 0.3, 1)  -- Green
        elseif combinedChance >= 0.40 then
            self.combinedChanceText:setTextColor(1, 0.8, 0.3, 1)  -- Yellow
        else
            self.combinedChanceText:setTextColor(1, 0.4, 0.4, 1)  -- Red
        end
    end

    -- Pricing
    local basePrice = search.basePrice or 0
    if self.newPriceText then
        self.newPriceText:setText(g_i18n:formatMoney(basePrice, 0, true, true))
    end

    -- Expected price (based on quality tier)
    local expectedPrice = math.floor(basePrice * (qualityTier.priceMultiplier or 0.5))
    if self.expectedPriceText then
        self.expectedPriceText:setText(g_i18n:formatMoney(expectedPrice, 0, true, true))
    end

    -- Savings percentage
    if self.savingsText then
        local savingsPercent = 0
        if basePrice > 0 then
            savingsPercent = math.floor((1 - (expectedPrice / basePrice)) * 100)
        end
        self.savingsText:setText(string.format("%d%% off", savingsPercent))
    end

    -- Condition range
    if self.conditionRangeText then
        local minCondition = math.floor((qualityTier.minCondition or 0) * 100)
        local maxCondition = math.floor((qualityTier.maxCondition or 1) * 100)
        self.conditionRangeText:setText(string.format("%d%% - %d%%", minCondition, maxCondition))
    end

    -- Price range (based on condition range)
    if self.priceRangeText then
        local minPrice = math.floor(basePrice * (qualityTier.priceMultiplier or 0.5) * 0.9)
        local maxPrice = math.floor(basePrice * (qualityTier.priceMultiplier or 0.5) * 1.1)
        self.priceRangeText:setText(string.format("%s - %s",
            g_i18n:formatMoney(minPrice, 0, true, true),
            g_i18n:formatMoney(maxPrice, 0, true, true)))
    end

    -- Status
    if self.statusText then
        local statusText = "Searching..."
        local statusColor = {0.7, 0.7, 0.7, 1}

        if search.status == "active" then
            statusText = "Searching..."
            statusColor = {0.8, 0.8, 0.3, 1}  -- Yellow
        elseif search.status == "success" then
            statusText = "FOUND!"
            statusColor = {0.3, 1, 0.3, 1}  -- Green
        elseif search.status == "failed" then
            statusText = "No vehicle found"
            statusColor = {1, 0.4, 0.4, 1}  -- Red
        elseif search.status == "cancelled" then
            statusText = "Cancelled"
            statusColor = {0.6, 0.6, 0.6, 1}  -- Gray
        end

        self.statusText:setText(statusText)
        self.statusText:setTextColor(unpack(statusColor))
    end

    -- Time remaining
    if self.timeRemainingText then
        self.timeRemainingText:setText(search:getRemainingTime())
    end

    -- Started / Elapsed
    local createdAt = search.createdAt or 0
    local currentHour = 0
    if g_currentMission and g_currentMission.environment then
        currentHour = g_currentMission.environment.currentHour or 0
    end
    local elapsed = currentHour - createdAt
    if elapsed < 0 then elapsed = 0 end

    if self.startedText then
        -- Calculate days ago
        local daysAgo = math.floor(elapsed / 24)
        if daysAgo > 0 then
            self.startedText:setText(string.format("%d day%s ago", daysAgo, daysAgo > 1 and "s" or ""))
        else
            self.startedText:setText(string.format("%d hours ago", elapsed))
        end
    end

    if self.elapsedText then
        local days = math.floor(elapsed / 24)
        local hours = elapsed % 24
        if days > 0 then
            self.elapsedText:setText(string.format("%d days, %d hrs", days, hours))
        else
            self.elapsedText:setText(string.format("%d hours", hours))
        end
    end

    -- Info text - tips based on search tier
    if self.infoText then
        local tipText = "Regional searches offer the best value for success rate."

        if search.searchLevel == 1 then
            tipText = "Local searches are fast but have low success rates."
        elseif search.searchLevel == 3 then
            tipText = "National searches have the highest success rate but take longer."
        end

        if search.qualityLevel >= 4 then
            tipText = "Good/Excellent quality is harder to find but saves on repairs."
        elseif search.qualityLevel == 1 then
            tipText = "Poor condition vehicles may need significant repairs."
        end

        self.infoText:setText(tipText)
    end
end

--[[
    Handle close button click
    Note: ScreenElement doesn't have close() - use changeScreen to return
]]
function SearchDetailsDialog:onCloseDialog()
    -- Close dialog by changing back to previous screen
    g_gui:changeScreen(nil)
end

--[[
    Handle ESC key / back button
]]
function SearchDetailsDialog:onClickBack()
    g_gui:changeScreen(nil)
    return true  -- Handled
end

--[[
    Called when dialog closes
]]
function SearchDetailsDialog:onClose()
    SearchDetailsDialog:superClass().onClose(self)
    self.search = nil
end

UsedPlus.logInfo("SearchDetailsDialog loaded")
