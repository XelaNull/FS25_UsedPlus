--[[
    SaleListingDetailsDialog.lua
    Dialog showing comprehensive details about a vehicle sale listing

    Displays:
    - Vehicle info and condition
    - Agent tier and fee details
    - Price tier and expected range
    - Value comparison (vs vanilla sell, trade-in)
    - Offer history
]]

SaleListingDetailsDialog = {}
-- Use ScreenElement, NOT MessageDialog (MessageDialog lacks registerControls)
local SaleListingDetailsDialog_mt = Class(SaleListingDetailsDialog, ScreenElement)

-- Static instance
SaleListingDetailsDialog.instance = nil
SaleListingDetailsDialog.xmlPath = nil

--[[
    Get or create dialog instance
]]
function SaleListingDetailsDialog.getInstance()
    if SaleListingDetailsDialog.instance == nil then
        if SaleListingDetailsDialog.xmlPath == nil then
            SaleListingDetailsDialog.xmlPath = UsedPlus.MOD_DIR .. "gui/SaleListingDetailsDialog.xml"
        end

        SaleListingDetailsDialog.instance = SaleListingDetailsDialog.new()
        g_gui:loadGui(SaleListingDetailsDialog.xmlPath, "SaleListingDetailsDialog", SaleListingDetailsDialog.instance)
    end

    return SaleListingDetailsDialog.instance
end

--[[
    Constructor
]]
function SaleListingDetailsDialog.new(target, customMt)
    local self = ScreenElement.new(target, customMt or SaleListingDetailsDialog_mt)

    self.listing = nil
    self.isBackAllowed = true

    return self
end

--[[
    Called when dialog is created
]]
function SaleListingDetailsDialog:onCreate()
    -- No superclass call needed for ScreenElement
end

--[[
    Show dialog with listing information
    @param listing - VehicleSaleListing object
]]
function SaleListingDetailsDialog:show(listing)
    if listing == nil then
        UsedPlus.logError("SaleListingDetailsDialog:show called with nil listing")
        return
    end

    self.listing = listing

    -- Populate all fields
    self:updateDisplay()

    -- Show the dialog
    g_gui:showDialog("SaleListingDetailsDialog")
end

--[[
    Update all display fields with listing data
]]
function SaleListingDetailsDialog:updateDisplay()
    if self.listing == nil then return end

    local listing = self.listing

    -- Vehicle Info
    if self.vehicleNameText then
        self.vehicleNameText:setText(listing.vehicleName or "Unknown Vehicle")
    end

    if self.conditionText then
        local repairPct = listing.repairPercent or 100
        local paintPct = listing.paintPercent or 100
        self.conditionText:setText(string.format("%d%% / %d%%", repairPct, paintPct))

        -- Color based on condition (green if good, yellow if fair, red if poor)
        local avgCondition = (repairPct + paintPct) / 2
        if avgCondition >= 80 then
            self.conditionText:setTextColor(0.3, 1, 0.3, 1)  -- Green
        elseif avgCondition >= 50 then
            self.conditionText:setTextColor(1, 0.8, 0.3, 1)  -- Yellow
        else
            self.conditionText:setTextColor(1, 0.4, 0.4, 1)  -- Red
        end
    end

    if self.hoursText then
        self.hoursText:setText(tostring(listing.operatingHours or 0))
    end

    -- Status
    if self.statusText then
        local statusText = listing:getStatusText()
        self.statusText:setText(statusText)

        -- Color based on status
        if listing.status == VehicleSaleListing.STATUS.OFFER_PENDING then
            self.statusText:setTextColor(0.3, 1, 0.3, 1)  -- Green - offer ready!
        elseif listing.status == VehicleSaleListing.STATUS.ACTIVE then
            self.statusText:setTextColor(0.7, 0.7, 0.7, 1)  -- Gray - searching
        elseif listing.status == VehicleSaleListing.STATUS.SOLD then
            self.statusText:setTextColor(0.3, 1, 0.3, 1)  -- Green - sold
        elseif listing.status == VehicleSaleListing.STATUS.EXPIRED then
            self.statusText:setTextColor(1, 0.4, 0.4, 1)  -- Red - expired
        else
            self.statusText:setTextColor(0.7, 0.7, 0.7, 1)
        end
    end

    if self.timeRemainingText then
        self.timeRemainingText:setText(listing:getRemainingTime())
    end

    -- Agent Tier
    local agentTier = listing:getAgentTierConfig()
    if self.agentTierText then
        self.agentTierText:setText(agentTier.name or "Unknown")
    end

    if self.agentFeeText then
        local feePercent = (agentTier.feePercent or 0) * 100
        self.agentFeeText:setText(string.format("%s (%.0f%%)",
            g_i18n:formatMoney(listing.agentFee or 0, 0, true, true),
            feePercent))
    end

    if self.baseSuccessText then
        local baseSuccess = (agentTier.baseSuccessRate or 0) * 100
        self.baseSuccessText:setText(string.format("%.0f%%", baseSuccess))
    end

    -- Price Tier
    local priceTier = listing:getPriceTierConfig()
    if self.priceTierText then
        self.priceTierText:setText(priceTier.name or "Unknown")
    end

    if self.priceRangeText then
        self.priceRangeText:setText(string.format("%s - %s",
            g_i18n:formatMoney(listing.expectedMinPrice or 0, 0, true, true),
            g_i18n:formatMoney(listing.expectedMaxPrice or 0, 0, true, true)))
    end

    if self.successModText then
        local successMod = (priceTier.successModifier or 0) * 100
        local modText = string.format("%+.0f%%", successMod)
        self.successModText:setText(modText)

        -- Color: green if positive, red if negative, white if zero
        if successMod > 0 then
            self.successModText:setTextColor(0.3, 1, 0.3, 1)
        elseif successMod < 0 then
            self.successModText:setTextColor(1, 0.4, 0.4, 1)
        else
            self.successModText:setTextColor(0.7, 0.7, 0.7, 1)
        end
    end

    -- Value Comparison
    local vanillaSell = listing.vanillaSellPrice or 0
    if self.vanillaSellText then
        self.vanillaSellText:setText(g_i18n:formatMoney(vanillaSell, 0, true, true))
    end

    if self.tradeInValueText then
        -- Trade-in is roughly 50-65% of vanilla
        local tradeInEstimate = math.floor(vanillaSell * 0.575)  -- Midpoint of 50-65%
        self.tradeInValueText:setText(g_i18n:formatMoney(tradeInEstimate, 0, true, true))
    end

    -- Expected value (midpoint of range)
    local expectedMid = math.floor((listing.expectedMinPrice + listing.expectedMaxPrice) / 2)
    if self.expectedValueText then
        self.expectedValueText:setText(g_i18n:formatMoney(expectedMid, 0, true, true))
    end

    -- Bonus vs vanilla
    if self.bonusVsVanillaText then
        local bonus = expectedMid - vanillaSell
        local bonusPercent = 0
        if vanillaSell > 0 then
            bonusPercent = math.floor((bonus / vanillaSell) * 100)
        end

        if bonus >= 0 then
            self.bonusVsVanillaText:setText(string.format("+%s (+%d%%)",
                g_i18n:formatMoney(bonus, 0, true, true), bonusPercent))
            self.bonusVsVanillaText:setTextColor(0.3, 1, 0.3, 1)
        else
            self.bonusVsVanillaText:setText(string.format("%s (%d%%)",
                g_i18n:formatMoney(bonus, 0, true, true), bonusPercent))
            self.bonusVsVanillaText:setTextColor(1, 0.4, 0.4, 1)
        end
    end

    -- Net amount (expected minus fee)
    if self.netAmountText then
        local netAmount = expectedMid - (listing.agentFee or 0)
        self.netAmountText:setText(g_i18n:formatMoney(netAmount, 0, true, true))
    end

    -- Offer History
    if self.offersReceivedText then
        self.offersReceivedText:setText(tostring(listing.offersReceived or 0))
    end

    if self.offersDeclinedText then
        self.offersDeclinedText:setText(tostring(listing.offersDeclined or 0))
    end

    if self.listedDurationText then
        local hoursElapsed = listing.hoursElapsed or 0
        local days = math.floor(hoursElapsed / 24)
        local hours = hoursElapsed % 24

        if days > 0 then
            self.listedDurationText:setText(string.format("%d days, %d hrs", days, hours))
        else
            self.listedDurationText:setText(string.format("%d hours", hours))
        end
    end

    -- Info text - tips based on status
    if self.infoText then
        local tipText = "Higher agent tiers have wider reach but longer wait times."

        if listing.status == VehicleSaleListing.STATUS.OFFER_PENDING then
            tipText = "You have a pending offer! Accept from the Finance Manager."
        elseif listing.offersDeclined > 0 then
            tipText = "Declining offers reduces remaining time for new offers."
        elseif listing.priceTier == 3 then
            tipText = "Premium pricing requires patience - fewer buyers can afford it."
        elseif listing.priceTier == 1 then
            tipText = "Quick sale pricing attracts buyers fast but at a discount."
        end

        self.infoText:setText(tipText)
    end
end

--[[
    Handle close button click
]]
function SaleListingDetailsDialog:onCloseDialog()
    g_gui:closeDialogByName("SaleListingDetailsDialog")
end

--[[
    Called when dialog closes
]]
function SaleListingDetailsDialog:onClose()
    SaleListingDetailsDialog:superClass().onClose(self)
    self.listing = nil
end

UsedPlus.logInfo("SaleListingDetailsDialog loaded")
