--[[
    FS25_UsedPlus - Land Lease Dialog

     GUI class for farmland leasing
     Pattern from: LandFinanceDialog.lua and LeaseDialog.lua
     Reference: FS25_ADVANCED_PATTERNS.md - GUI Dialog Pattern

    Responsibilities:
    - Display field details (number, size, price)
    - Provide term selection (1, 3, 5, or 10 years)
    - Show monthly payment, total cost, and buyout price
    - Preview markup rates based on term length
    - Send LandLeaseEvent to server

    Land Lease Terms:
    - 1 year: 20% markup, no buyout discount
    - 3 years: 15% markup, 5% buyout discount
    - 5 years: 10% markup, 10% buyout discount
    - 10 years: 5% markup, 15% buyout discount
]]

LandLeaseDialog = {}
local LandLeaseDialog_mt = Class(LandLeaseDialog, MessageDialog)

--[[
     Constructor
]]
function LandLeaseDialog.new(target, customMt, i18n)
    local self = MessageDialog.new(target, customMt or LandLeaseDialog_mt)

    -- Data for current lease configuration
    self.fieldId = nil
    self.fieldPrice = 0
    self.farmId = nil
    self.i18n = i18n
    self.isDataSet = false

    -- Current selected term (index 1-4)
    self.selectedTermIndex = 2  -- Default to 3 years

    return self
end

--[[
     Called when dialog is created
]]
function LandLeaseDialog:onCreate()
    LandLeaseDialog:superClass().onCreate(self)
end

-- Term options for land leases (in years)
LandLeaseDialog.TERM_OPTIONS = {1, 3, 5, 10}

--[[
     Called when dialog opens
]]
function LandLeaseDialog:onOpen()
    LandLeaseDialog:superClass().onOpen(self)

    -- Initialize term selector using helper
    UIHelper.Element.populateTermSelector(self.termOption, LandLeaseDialog.TERM_OPTIONS, "year", self.selectedTermIndex)

    -- Update preview if data is set
    if self.isDataSet then
        self:updatePreview()
    end
end

--[[
     Initialize dialog with field data
     Called by InGameMenuMapFrameExtension when lease option selected
]]
function LandLeaseDialog:setData(fieldId, fieldPrice, farmId)
    self.fieldId = fieldId
    self.fieldPrice = fieldPrice
    self.farmId = farmId

    UsedPlus.logDebug(string.format("Land Lease setData called: fieldId=%s, price=%s, farmId=%s",
        tostring(fieldId), tostring(fieldPrice), tostring(farmId)))

    -- Display field number
    if self.fieldNumberText then
        self.fieldNumberText:setText(string.format("Field %d", fieldId))
    end

    -- Get field info from game (safely)
    -- Correct property is areaInHa (already in hectares)
    -- Pattern from: FS25_FarmlandOverview
    local farmland = g_farmlandManager:getFarmlandById(fieldId)
    if farmland and self.fieldSizeText then
        local areaHa = farmland.areaInHa or 0
        if areaHa > 0 then
            -- Use game's localized area formatting
            self.fieldSizeText:setText(string.format("%.2f %s", g_i18n:getArea(areaHa), g_i18n:getAreaUnit()))
        else
            self.fieldSizeText:setText("--")
        end
    elseif self.fieldSizeText then
        self.fieldSizeText:setText("--")
    end

    -- Display land price
    if self.fieldPriceText then
        self.fieldPriceText:setText(g_i18n:formatMoney(self.fieldPrice, 0, true, true))
    end

    -- Mark data as set
    self.isDataSet = true

    -- Update preview with new data
    if self.termOption then
        self:updatePreview()
    end
end

--[[
     Update preview with current term selection
]]
function LandLeaseDialog:updatePreview()
    if not self.isDataSet then return end
    if self.fieldPrice == nil or self.fieldPrice == 0 then return end

    -- Get current term from selector
    local termIndex = self.selectedTermIndex
    if self.termOption then
        termIndex = self.termOption:getState()
        self.selectedTermIndex = termIndex
    end

    -- Get term from class constants
    local termYears = LandLeaseDialog.TERM_OPTIONS[termIndex] or 3
    local termMonths = termYears * 12

    -- Get term configuration from LandLeaseDeal
    local termConfig = LandLeaseDeal.getTermConfig(termYears)
    local markupRate = termConfig.markupRate
    local buyoutDiscount = termConfig.buyoutDiscount

    -- Calculate lease costs
    local totalLeaseCost = self.fieldPrice * (1 + markupRate)
    local monthlyPayment = totalLeaseCost / termMonths
    local yearlyPayment = monthlyPayment * 12
    local totalMarkup = self.fieldPrice * markupRate

    -- Calculate buyout price (available during lease)
    local baseBuyoutPrice = self.fieldPrice * (1 - buyoutDiscount)

    -- Update text displays using UIHelper
    UIHelper.Element.setText(self.markupRateText, string.format("%s markup", UIHelper.Text.formatPercent(markupRate, true, 0)))
    UIHelper.Finance.displayMonthlyPayment(self.monthlyPaymentText, monthlyPayment)
    UIHelper.Element.setText(self.yearlyPaymentText, UIHelper.Text.formatMoney(yearlyPayment))
    UIHelper.Element.setText(self.totalCostText, UIHelper.Text.formatMoney(totalLeaseCost))
    UIHelper.Element.setTextWithColor(self.totalMarkupText,
        UIHelper.Text.formatMoney(totalMarkup), UIHelper.Colors.COST_ORANGE)
    UIHelper.Element.setText(self.buyoutPriceText, UIHelper.Text.formatMoney(baseBuyoutPrice))

    -- Buyout discount (green if available)
    if buyoutDiscount > 0 then
        UIHelper.Element.setTextWithColor(self.buyoutDiscountText,
            string.format("%s discount", UIHelper.Text.formatPercent(buyoutDiscount, true, 0)),
            UIHelper.Colors.MONEY_GREEN)
    else
        UIHelper.Element.setText(self.buyoutDiscountText, "No discount")
    end

    -- Update term description
    if self.termDescriptionText then
        local descriptions = {
            "Short term, high cost. No buyout discount.",
            "Medium term, moderate cost. 5% buyout discount.",
            "Long term, lower cost. 10% buyout discount.",
            "Very long term, lowest cost. 15% buyout discount."
        }
        self.termDescriptionText:setText(descriptions[termIndex] or "")
    end
end

--[[
     Callback when term selection changes
]]
function LandLeaseDialog:onTermChanged()
    if self.isDataSet then
        self:updatePreview()
    end
end

--[[
     Callback when "Accept Lease" button clicked
]]
function LandLeaseDialog:onAcceptLease()

    if self.fieldId == nil then
        UsedPlus.logError("No field selected for leasing")
        return
    end

    -- Get final term value
    local termIndex = self.selectedTermIndex
    if self.termOption then
        termIndex = self.termOption:getState()
    end

    -- Get term from class constants
    local termYears = LandLeaseDialog.TERM_OPTIONS[termIndex] or 3

    -- Get field name
    local fieldName = string.format("Field %d", self.fieldId)

    -- Send land lease event
    if LandLeaseEvent then
        LandLeaseEvent.sendToServer(
            self.farmId,
            self.fieldId,
            fieldName,
            self.fieldPrice,
            termYears
        )
    else
        UsedPlus.logError("LandLeaseEvent not available")
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
            "Error: Land lease system not initialized"
        )
        return
    end

    -- Close dialog
    self:close()
end

--[[
     Callback when "Cancel" button clicked
]]
function LandLeaseDialog:onCancel()
    self:close()
end

--[[
     Cleanup when dialog closes
]]
function LandLeaseDialog:onClose()
    self.fieldId = nil
    self.fieldPrice = 0
    self.farmId = nil
    self.isDataSet = false

    LandLeaseDialog:superClass().onClose(self)
end

UsedPlus.logInfo("LandLeaseDialog loaded")
