--[[
    FS25_UsedPlus - Payment Configuration Dialog

    Dialog for configuring loan payment amounts.
    Uses SmoothList for scrollable list of loans.
    Select a loan, then use the dropdown below to change its payment mode.
]]

PaymentConfigDialog = {}
local PaymentConfigDialog_mt = Class(PaymentConfigDialog, MessageDialog)

-- Payment mode constants
PaymentConfigDialog.MODE_SKIP = 0
PaymentConfigDialog.MODE_MINIMUM = 1
PaymentConfigDialog.MODE_STANDARD = 2
PaymentConfigDialog.MODE_EXTRA = 3
PaymentConfigDialog.MODE_CUSTOM = 4

-- Mode display names for dropdown (1-indexed for UI)
PaymentConfigDialog.MODE_TEXTS = {"Skip", "Minimum", "Standard", "Extra (2x)", "Custom"}

-- Mode display names for list (0-indexed)
PaymentConfigDialog.MODE_NAMES = {
    [0] = "Skip",
    [1] = "Min",
    [2] = "Std",
    [3] = "2x",
    [4] = "Custom"
}

function PaymentConfigDialog.new(target, custom_mt, i18n)
    local self = MessageDialog.new(target, custom_mt or PaymentConfigDialog_mt)

    self.i18n = i18n or g_i18n
    self.farmId = nil
    self.deals = {}
    self.dealModes = {}  -- Track selected mode per deal ID
    self.selectedIndex = -1

    return self
end

--[[
    Called when GUI elements are ready
    UI elements auto-populated by g_gui based on XML id attributes
]]
function PaymentConfigDialog:onGuiSetupFinished()
    PaymentConfigDialog:superClass().onGuiSetupFinished(self)
    -- UI elements automatically available: warningText, totalPaymentText, totalMinimumText,
    -- selectedLoanText, modeSelector, loanList

    -- Set up the SmoothList as data source and delegate
    if self.loanList then
        self.loanList:setDataSource(self)
        self.loanList:setDelegate(self)
    end

    -- Set up the MultiTextOption dropdown texts
    if self.modeSelector then
        self.modeSelector:setTexts(PaymentConfigDialog.MODE_TEXTS)
        self.modeSelector:setState(3)  -- Default to "Standard"
        self.modeSelector:setDisabled(true)  -- Disabled until a loan is selected
    end
end

--[[
    Set farm ID and load deals
]]
function PaymentConfigDialog:setFarmId(farmId)
    self.farmId = farmId
    self:loadDeals()
end

--[[
    Load all finance deals for the farm
]]
function PaymentConfigDialog:loadDeals()
    self.deals = {}
    self.dealModes = {}

    if g_financeManager == nil then
        UsedPlus.logWarn("FinanceManager not available")
        return
    end

    local allDeals = g_financeManager:getDealsForFarm(self.farmId)
    if allDeals then
        for _, deal in ipairs(allDeals) do
            -- Only include active finance deals (type 1) and loans (type 4)
            if deal.status == "active" and (deal.dealType == 1 or deal.dealType == 4) then
                table.insert(self.deals, deal)
                -- Initialize with current mode or standard
                local mode = PaymentConfigDialog.MODE_STANDARD
                if deal.paymentMode ~= nil then
                    mode = deal.paymentMode
                elseif FinanceDeal and FinanceDeal.PAYMENT_MODE then
                    mode = deal.paymentMode or FinanceDeal.PAYMENT_MODE.STANDARD
                end
                self.dealModes[deal.id] = mode
            end
        end
    end

    UsedPlus.logDebug(string.format("PaymentConfigDialog loaded %d deals for farm %d", #self.deals, self.farmId))
end

--[[
    Called when dialog opens
]]
function PaymentConfigDialog:onOpen()
    PaymentConfigDialog:superClass().onOpen(self)
    self.selectedIndex = -1

    -- Disable mode selector until a loan is selected
    if self.modeSelector then
        self.modeSelector:setDisabled(true)
    end

    self:updateDisplay()
end

--[[
    SmoothList data source: Number of sections
]]
function PaymentConfigDialog:getNumberOfSections()
    return 1
end

--[[
    SmoothList data source: Number of items in section
]]
function PaymentConfigDialog:getNumberOfItemsInSection(list, section)
    return #self.deals
end

--[[
    SmoothList data source: Section header title
]]
function PaymentConfigDialog:getTitleForSectionHeader(list, section)
    return ""
end

--[[
    SmoothList data source: Populate cell with data
]]
function PaymentConfigDialog:populateCellForItemInSection(list, section, index, cell)
    local deal = self.deals[index]
    if deal == nil then
        return
    end

    -- Set loan name (truncate if too long)
    local nameCell = cell:getAttribute("loanName")
    if nameCell then
        local name = deal.itemName or "Unknown"
        if #name > 20 then
            name = string.sub(name, 1, 18) .. ".."
        end
        nameCell:setText(name)
    end

    -- Set balance
    local balanceCell = cell:getAttribute("balance")
    if balanceCell then
        local balance = 0
        if deal.getEffectiveBalance then
            balance = deal:getEffectiveBalance()
        elseif deal.currentBalance then
            balance = deal.currentBalance
        end
        balanceCell:setText(UIHelper.Text.formatMoney(balance))
    end

    -- Set mode name
    local modeCell = cell:getAttribute("mode")
    if modeCell then
        local mode = self.dealModes[deal.id] or PaymentConfigDialog.MODE_STANDARD
        local modeName = PaymentConfigDialog.MODE_NAMES[mode] or "Std"
        modeCell:setText(modeName)
    end

    -- Set payment amount
    local amountCell = cell:getAttribute("amount")
    if amountCell then
        local amount = self:getPaymentForMode(deal, self.dealModes[deal.id])
        amountCell:setText(UIHelper.Text.formatMoney(amount))
    end
end

--[[
    SmoothList delegate: Selection changed
]]
function PaymentConfigDialog:onListSelectionChanged(list, section, index)
    self.selectedIndex = index
    self:updateModeSelector()
end

--[[
    Update the mode selector to reflect the selected loan
]]
function PaymentConfigDialog:updateModeSelector()
    if self.selectedLoanText == nil then
        return
    end

    if self.selectedIndex > 0 and self.selectedIndex <= #self.deals then
        local deal = self.deals[self.selectedIndex]
        local mode = self.dealModes[deal.id] or PaymentConfigDialog.MODE_STANDARD

        -- Update label
        self.selectedLoanText:setText(string.format("Selected: %s", deal.itemName or "Unknown"))

        -- Enable and update dropdown
        if self.modeSelector then
            self.modeSelector:setDisabled(false)
            self.modeSelector:setState(mode + 1)  -- 1-indexed for UI
        end
    else
        self.selectedLoanText:setText(g_i18n:getText("usedplus_paymentconfig_selectLoan"))

        -- Disable dropdown
        if self.modeSelector then
            self.modeSelector:setDisabled(true)
        end
    end
end

--[[
    Called when mode dropdown changes
]]
function PaymentConfigDialog:onModeChanged()
    if self.selectedIndex < 1 or self.selectedIndex > #self.deals then
        return
    end

    local deal = self.deals[self.selectedIndex]
    if deal and self.modeSelector then
        local uiIndex = self.modeSelector:getState()
        local mode = uiIndex - 1  -- Convert from 1-indexed UI to 0-indexed mode

        -- If Custom mode selected, show input dialog
        if mode == PaymentConfigDialog.MODE_CUSTOM then
            self:showCustomAmountDialog(deal)
        else
            self.dealModes[deal.id] = mode
            self:updateDisplay()
        end
    end
end

--[[
    Show text input dialog for custom payment amount
]]
function PaymentConfigDialog:showCustomAmountDialog(deal)
    local standard = deal.monthlyPayment or 0
    local minimum = 0
    if deal.calculateMinimumPayment then
        minimum = deal:calculateMinimumPayment()
    else
        minimum = standard * 0.3
    end
    -- Default to existing custom amount, or minimum payment if none set
    local currentCustom = deal.configuredPayment or minimum

    -- Store deal reference for callback
    self.pendingCustomDeal = deal

    local title = string.format("Custom Payment: %s", deal.itemName or "Loan")
    local defaultValue = tostring(math.floor(currentCustom))

    -- TextInputDialog.show(callback, target, defaultText, title, description, maxChars, confirmText, args)
    TextInputDialog.show(
        self.onCustomAmountEntered,
        self,
        defaultValue,                    -- Pre-filled value in input box
        title,                           -- Dialog title
        string.format("Min: %s | Standard: %s",
            UIHelper.Text.formatMoney(minimum),
            UIHelper.Text.formatMoney(standard)),  -- Description
        10,                              -- Max characters
        g_i18n:getText("button_ok")      -- Confirm button text
    )
end

--[[
    Callback when custom amount is entered
]]
function PaymentConfigDialog:onCustomAmountEntered(value, clickOk)
    local deal = self.pendingCustomDeal
    if deal == nil then
        return
    end

    if clickOk and value ~= nil then
        local amount = tonumber(value)
        if amount and amount >= 0 then
            -- Floor to whole number - no decimals needed
            amount = math.floor(amount)

            -- Get loan balance (max payable toward this loan)
            local loanBalance = 0
            if deal.getEffectiveBalance then
                loanBalance = deal:getEffectiveBalance()
            elseif deal.currentBalance then
                loanBalance = deal.currentBalance
            end

            -- Get player's available money
            local farm = g_farmManager:getFarmById(self.farmId)
            local availableMoney = farm and farm:getBalance() or 0

            -- Validate: can't pay more than loan balance
            if amount > loanBalance then
                g_currentMission:addIngameNotification(
                    FSBaseMission.INGAME_NOTIFICATION_INFO,
                    string.format("Amount exceeds loan balance (%s)", UIHelper.Text.formatMoney(loanBalance))
                )
                if self.modeSelector then
                    self.modeSelector:setState(PaymentConfigDialog.MODE_STANDARD + 1)
                end
            -- Validate: can't pay more than available money
            elseif amount > availableMoney then
                g_currentMission:addIngameNotification(
                    FSBaseMission.INGAME_NOTIFICATION_INFO,
                    string.format("Amount exceeds available funds (%s)", UIHelper.Text.formatMoney(availableMoney))
                )
                if self.modeSelector then
                    self.modeSelector:setState(PaymentConfigDialog.MODE_STANDARD + 1)
                end
            else
                -- Valid amount
                deal.configuredPayment = amount
                self.dealModes[deal.id] = PaymentConfigDialog.MODE_CUSTOM
                self:updateDisplay()
            end
        else
            -- Invalid input, revert to standard
            g_currentMission:addIngameNotification(
                FSBaseMission.INGAME_NOTIFICATION_INFO,
                g_i18n:getText("usedplus_error_invalidAmount")
            )
            if self.modeSelector then
                self.modeSelector:setState(PaymentConfigDialog.MODE_STANDARD + 1)
            end
        end
    else
        -- Cancelled, revert dropdown to previous mode
        local previousMode = self.dealModes[deal.id] or PaymentConfigDialog.MODE_STANDARD
        if self.modeSelector then
            self.modeSelector:setState(previousMode + 1)
        end
    end

    self.pendingCustomDeal = nil
end

--[[
    Update the display with current deal data
]]
function PaymentConfigDialog:updateDisplay()
    -- Reload the list
    if self.loanList then
        self.loanList:reloadData()
    end

    -- Calculate totals
    local totalConfigured = 0
    local totalMinimum = 0
    local totalStandard = 0
    local hasSkippedPayments = false
    local hasNegativeAmortization = false

    for _, deal in ipairs(self.deals) do
        local mode = self.dealModes[deal.id] or PaymentConfigDialog.MODE_STANDARD
        local amount = self:getPaymentForMode(deal, mode)

        totalConfigured = totalConfigured + amount
        local minPayment = 0
        if deal.calculateMinimumPayment then
            minPayment = deal:calculateMinimumPayment()
        end
        totalMinimum = totalMinimum + minPayment
        totalStandard = totalStandard + (deal.monthlyPayment or 0)

        -- Check for warnings
        if mode == PaymentConfigDialog.MODE_SKIP then
            hasSkippedPayments = true
        end
        if amount < minPayment then
            hasNegativeAmortization = true
        end
    end

    -- Update totals using UIHelper
    UIHelper.Element.setText(self.totalPaymentText, UIHelper.Text.formatMoney(totalConfigured))
    UIHelper.Element.setText(self.totalMinimumText,
        string.format("(Min: %s / Std: %s)",
            UIHelper.Text.formatMoney(totalMinimum),
            UIHelper.Text.formatMoney(totalStandard)))

    -- Show warnings
    if self.warningText then
        if hasSkippedPayments then
            self.warningText:setText(g_i18n:getText("usedplus_paymentconfig_warningSkip"))
            self.warningText:setVisible(true)
        elseif hasNegativeAmortization then
            self.warningText:setText(g_i18n:getText("usedplus_paymentconfig_noteNegAmort"))
            self.warningText:setVisible(true)
        else
            self.warningText:setVisible(false)
        end
    end

    self:updateModeSelector()
end

--[[
    Get payment amount for a given mode
]]
function PaymentConfigDialog:getPaymentForMode(deal, mode)
    if mode == PaymentConfigDialog.MODE_SKIP then
        return 0
    elseif mode == PaymentConfigDialog.MODE_MINIMUM then
        if deal.calculateMinimumPayment then
            return deal:calculateMinimumPayment()
        else
            return (deal.monthlyPayment or 0) * 0.3
        end
    elseif mode == PaymentConfigDialog.MODE_STANDARD then
        return deal.monthlyPayment or 0
    elseif mode == PaymentConfigDialog.MODE_EXTRA then
        return (deal.monthlyPayment or 0) * 2
    elseif mode == PaymentConfigDialog.MODE_CUSTOM then
        return deal.configuredPayment or deal.monthlyPayment or 0
    end
    return deal.monthlyPayment or 0
end

--[[
    Apply button clicked - save all payment configurations
]]
function PaymentConfigDialog:onClickApply()
    local farm = g_farmManager:getFarmById(self.farmId)
    if not farm then
        return
    end

    -- Apply modes to all deals
    for _, deal in ipairs(self.deals) do
        local mode = self.dealModes[deal.id]
        if mode ~= nil and deal.setPaymentMode then
            deal:setPaymentMode(mode, deal.configuredPayment)
        end
    end

    -- Send network event if multiplayer
    if SetPaymentConfigEvent then
        for _, deal in ipairs(self.deals) do
            SetPaymentConfigEvent.sendToServer(deal.id, self.dealModes[deal.id], deal.configuredPayment)
        end
    end

    g_currentMission:addIngameNotification(
        FSBaseMission.INGAME_NOTIFICATION_OK,
        "Payment configuration saved!"
    )

    self:close()

    -- Refresh the Finance Manager page using global reference
    if g_usedPlusFinanceFrame then
        g_usedPlusFinanceFrame:updateDisplay()
    end
end

--[[
    Cancel button clicked
]]
function PaymentConfigDialog:onClickCancel()
    self:close()
end

--[[
    Reset all to standard
]]
function PaymentConfigDialog:onClickResetAll()
    for _, deal in ipairs(self.deals) do
        self.dealModes[deal.id] = PaymentConfigDialog.MODE_STANDARD
    end
    self:updateDisplay()
end

UsedPlus.logInfo("PaymentConfigDialog loaded")
