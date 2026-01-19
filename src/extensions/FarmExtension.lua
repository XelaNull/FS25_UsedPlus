--[[
    FS25_UsedPlus - Farm Extension

    Extends Farm class to handle automatic monthly payments
    Pattern from: BuyUsedEquipment FarmExtension.lua
    Reference: FS25_ADVANCED_PATTERNS.md - Extension Pattern

    Responsibilities:
    - Subscribe to PERIOD_CHANGED event (monthly)
    - Process monthly payments for all active finance deals
    - Handle missed payment warnings and consequences
    - Track search queue progress (hourly)
]]

FarmExtension = {}

-- Track if we've already subscribed to events
FarmExtension.initialized = false

-- v2.5.2: Track vanilla loan balances to detect payments
-- The vanilla bank loan (farm.loan) makes automatic payments each period
-- We need to track these to give proper credit score benefits
FarmExtension.lastVanillaLoanBalances = {}

-- v2.5.2: Track which farms have received retroactive credit seeding
-- This is PERSISTED to prevent gaming (take small new loan → get years of free credit)
-- Once seeded, a farm will never be seeded again
FarmExtension.retroactiveCreditSeeded = {}

--[[
    Initialize farm extension
    Subscribe to game events for payment processing
]]
function FarmExtension:init()
    if FarmExtension.initialized then return end

    -- Subscribe to period (month) change for finance payments
    if g_messageCenter then
        g_messageCenter:subscribe(MessageType.PERIOD_CHANGED, FarmExtension.onPeriodChanged, FarmExtension)

        UsedPlus.logDebug("FarmExtension subscribed to PERIOD_CHANGED")
    end

    FarmExtension.initialized = true
end

--[[
    Called every in-game month
    Process automatic payments for all active finance deals
]]
function FarmExtension.onPeriodChanged()
    -- Only server processes payments
    if not g_server then return end

    UsedPlus.logDebug("Processing monthly finance payments...")

    if g_financeManager == nil then
        UsedPlus.logWarn("FinanceManager not available for monthly processing")
        return
    end

    -- Get all farms and process their deals
    local farms = g_farmManager:getFarms()
    for _, farm in pairs(farms) do
        if farm.farmId ~= FarmManager.SPECTATOR_FARM_ID then
            -- v2.5.2: Track vanilla loan payments FIRST (before UsedPlus deals)
            FarmExtension:trackVanillaLoanPayment(farm)

            -- Process UsedPlus finance deals
            FarmExtension:processMonthlyPaymentsForFarm(farm)
        end
    end
end

--[[
    v2.5.2: Track vanilla bank loan payments for credit score
    The game automatically deducts vanilla loan payments each period.
    We detect this by comparing the current balance to what we stored last period.
    If the balance decreased, that's a payment - record it for credit!

    NOTE: Vanilla loans can't be "missed" - they're automatic. So we only
    record on-time payments. This is fair because the player IS paying.

    COLD START HANDLING (v2.5.2+):
    When loading an existing save that has never had UsedPlus tracking:
    - If player has a loan and has played N periods, they've made ~N payments
    - We seed PaymentTracker with retroactive credit for past payments
    - This ensures players aren't penalized for playing before installing UsedPlus
]]
function FarmExtension:trackVanillaLoanPayment(farm)
    local farmId = farm.farmId
    local currentLoan = farm.loan or 0

    -- Get the previous balance we stored (may be from save file)
    local previousLoan = FarmExtension.lastVanillaLoanBalances[farmId]

    UsedPlus.logDebug(string.format("Farm %d: Vanilla loan check - previous=$%.0f, current=$%.0f",
        farmId, previousLoan or -1, currentLoan))

    -- Store current balance for next period
    FarmExtension.lastVanillaLoanBalances[farmId] = currentLoan

    -- If we don't have a previous balance, this is our first check (fresh install or data loss)
    if previousLoan == nil then
        UsedPlus.logDebug(string.format("Farm %d: Initialized vanilla loan tracking at $%.0f (no previous data)",
            farmId, currentLoan))

        -- COLD START: Seed retroactive credit if player has a loan and has played
        -- NOTE: seedRetroactiveVanillaLoanCredit checks the persisted flag to prevent gaming
        if currentLoan > 0 then
            FarmExtension:seedRetroactiveVanillaLoanCredit(farm, currentLoan)
        else
            -- No loan currently - but mark as "initialized" so future loans don't get retroactive credit
            -- This is CRITICAL: prevents gaming by taking a new loan after playing for months
            if not FarmExtension.retroactiveCreditSeeded[farmId] then
                FarmExtension.retroactiveCreditSeeded[farmId] = true
                UsedPlus.logDebug(string.format(
                    "Farm %d: Marked as initialized (no loan) - future loans won't get retroactive credit",
                    farmId))
            end
        end
        return
    end

    -- If there was no loan before and still no loan, nothing to track
    if previousLoan == 0 and currentLoan == 0 then
        return
    end

    -- Calculate the change in loan balance
    local balanceChange = previousLoan - currentLoan

    -- If balance DECREASED, a payment was made
    if balanceChange > 0 then
        -- Estimate the payment amount (this is principal reduction)
        -- The game also charges interest, so the actual payment is higher
        -- We'll use a rough estimate: payment ≈ principal + (balance * 10%/12)
        local estimatedInterest = previousLoan * (0.10 / 12)  -- ~10% annual rate
        local estimatedPayment = balanceChange + estimatedInterest

        -- Record as on-time payment in PaymentTracker
        if PaymentTracker then
            PaymentTracker.recordPayment(
                farmId,
                "VANILLA_BANK_LOAN",
                PaymentTracker.STATUS_ON_TIME,
                math.floor(estimatedPayment),
                "vanilla_loan"
            )
        end

        -- Record in CreditHistory for event tracking
        if CreditHistory then
            CreditHistory.recordEvent(farmId, "PAYMENT_ON_TIME",
                string.format("Bank Loan: $%d payment", math.floor(estimatedPayment)))
        end

        UsedPlus.logDebug(string.format("Farm %d: Vanilla loan payment detected - $%.0f (balance: $%.0f -> $%.0f)",
            farmId, estimatedPayment, previousLoan, currentLoan))

        -- Check if the loan was fully paid off
        if currentLoan <= 0 and previousLoan > 0 then
            if CreditHistory then
                CreditHistory.recordEvent(farmId, "DEAL_PAID_OFF", "Bank Credit Line paid in full!")
            end

            g_currentMission:addIngameNotification(
                FSBaseMission.INGAME_NOTIFICATION_OK,
                "Congratulations! Your bank loan has been paid off!"
            )

            UsedPlus.logInfo(string.format("Farm %d: Vanilla bank loan paid off!", farmId))
        end
    elseif balanceChange < 0 then
        -- Balance INCREASED - player borrowed more money
        -- This is recorded elsewhere when they take out the loan
        UsedPlus.logDebug(string.format("Farm %d: Vanilla loan increased by $%.0f (new balance: $%.0f)",
            farmId, -balanceChange, currentLoan))
    end
end

--[[
    v2.5.2: Seed retroactive credit for vanilla loan payments
    Called when we first detect a loan on an existing save.

    We estimate past payments based on:
    - Total periods (months) elapsed in the game
    - Current loan balance (estimate typical payment size)

    This is intentionally conservative - we'd rather give slightly less
    credit than give too much for payments that may not have happened.
]]
function FarmExtension:seedRetroactiveVanillaLoanCredit(farm, currentLoan)
    local farmId = farm.farmId

    -- CRITICAL: Check if this farm has EVER been seeded before
    -- This flag is PERSISTED to prevent gaming (new loan → free years of credit)
    if FarmExtension.retroactiveCreditSeeded[farmId] then
        UsedPlus.logDebug(string.format(
            "Farm %d: Already seeded retroactive credit - skipping (anti-gaming)",
            farmId))
        return
    end

    -- Check if PaymentTracker is available
    if not PaymentTracker then
        UsedPlus.logDebug("PaymentTracker not available for retroactive credit")
        return
    end

    -- Additional safety: Check if we already have payment history for this farm's vanilla loan
    local existingPayments = PaymentTracker.getPaymentHistory(farmId) or {}

    for _, payment in ipairs(existingPayments) do
        if payment.dealType == "vanilla_loan" then
            UsedPlus.logDebug(string.format(
                "Farm %d: Already has vanilla loan payment history - skipping retroactive seed",
                farmId))
            -- Mark as seeded so we don't check again
            FarmExtension.retroactiveCreditSeeded[farmId] = true
            return
        end
    end

    -- Calculate periods elapsed
    local environment = g_currentMission.environment
    if not environment then
        UsedPlus.logDebug("Environment not available for retroactive credit calculation")
        return
    end

    local daysPerPeriod = environment.daysPerPeriod or 1
    local currentMonotonicDay = environment.currentMonotonicDay or 0

    -- Calculate how many periods (months) have passed
    local periodsElapsed = math.floor(currentMonotonicDay / daysPerPeriod)

    -- If less than 1 period, no retroactive credit needed (they just started)
    if periodsElapsed < 1 then
        UsedPlus.logDebug(string.format(
            "Farm %d: Less than 1 period elapsed - no retroactive credit",
            farmId))
        return
    end

    -- Cap retroactive payments at a reasonable maximum
    -- (We don't want to give 100+ payments for a very long game save)
    local maxRetroactivePayments = 24  -- 2 years of credit max
    local paymentsToCredit = math.min(periodsElapsed, maxRetroactivePayments)

    -- Estimate a typical payment amount
    -- Vanilla loan is ~10% annual, so monthly payment includes principal + interest
    -- We'll estimate payment as roughly (balance / remaining_term) + monthly_interest
    -- Since we don't know the original term, estimate conservatively
    local estimatedMonthlyPayment = currentLoan * (0.10 / 12) + (currentLoan / 36)
    estimatedMonthlyPayment = math.floor(estimatedMonthlyPayment)

    -- Seed the payments into PaymentTracker
    for i = 1, paymentsToCredit do
        PaymentTracker.recordPayment(
            farmId,
            "VANILLA_BANK_LOAN_RETRO",
            PaymentTracker.STATUS_ON_TIME,
            estimatedMonthlyPayment,
            "vanilla_loan"
        )
    end

    -- Also record a single CreditHistory event summarizing the retroactive credit
    if CreditHistory then
        CreditHistory.recordEvent(farmId, "PAYMENT_ON_TIME",
            string.format("Bank Loan: %d prior monthly payments credited", paymentsToCredit))
    end

    -- Mark this farm as seeded (CRITICAL - prevents gaming)
    FarmExtension.retroactiveCreditSeeded[farmId] = true

    -- Notify the player
    g_currentMission:addIngameNotification(
        FSBaseMission.INGAME_NOTIFICATION_OK,
        string.format("UsedPlus: Credited %d prior bank loan payments to your history!",
            paymentsToCredit)
    )

    UsedPlus.logInfo(string.format(
        "Farm %d: Seeded %d retroactive vanilla loan payments (est. $%d each) - marked as seeded",
        farmId, paymentsToCredit, estimatedMonthlyPayment))
end

--[[
    Process monthly payments for a specific farm
]]
function FarmExtension:processMonthlyPaymentsForFarm(farm)
    local farmId = farm.farmId
    local deals = g_financeManager:getDealsForFarm(farmId)

    if deals == nil or #deals == 0 then return end

    local totalPayments = 0
    local missedPayments = 0

    for _, deal in ipairs(deals) do
        if deal.status == "active" then
            local success = FarmExtension:processPaymentForDeal(farm, deal)
            if success then
                totalPayments = totalPayments + 1
            else
                missedPayments = missedPayments + 1
            end
        end
    end

    if totalPayments > 0 or missedPayments > 0 then
        UsedPlus.logDebug(string.format("Farm %d: %d payments processed, %d missed",
            farmId, totalPayments, missedPayments))

        -- Send summary notification to player
        FarmExtension:sendPaymentSummaryNotification(farm, totalPayments, missedPayments, deals)
    end
end

--[[
    Send consolidated payment summary notification
    Shows total payments made and any missed payments
    Also checks for credit tier changes
]]
function FarmExtension:sendPaymentSummaryNotification(farm, successCount, missedCount, deals)
    -- Calculate total amount paid
    local totalPaid = 0
    for _, deal in ipairs(deals) do
        if deal.status == "active" then
            local payment = deal.monthlyPayment or 0
            -- Only count if payment was successful (farm had money)
            if farm.money >= payment or missedCount == 0 then
                totalPaid = totalPaid + payment
            end
        end
    end

    local message
    if missedCount == 0 then
        -- All payments successful
        message = string.format("Monthly Finance: %d payment%s processed (%s)",
            successCount,
            successCount > 1 and "s" or "",
            g_i18n:formatMoney(totalPaid, 0, true, true))
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_OK,
            message
        )
    else
        -- Some payments missed
        message = string.format("Monthly Finance: %d paid, %d MISSED! Check Finance Manager.",
            successCount, missedCount)
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
            message
        )
    end

    -- Check for credit tier change after payments
    FarmExtension:checkCreditTierChange(farm.farmId)
end

--[[
    Check if credit score tier changed and notify player
    Called after monthly payments are processed
]]
function FarmExtension:checkCreditTierChange(farmId)
    if not CreditScore or not CreditHistory then return end

    -- Get stored previous score (or calculate fresh)
    local previousScore = FarmExtension.lastCreditScores and FarmExtension.lastCreditScores[farmId]
    local currentScore = CreditScore.calculate(farmId)

    -- Store for next comparison
    if not FarmExtension.lastCreditScores then
        FarmExtension.lastCreditScores = {}
    end
    FarmExtension.lastCreditScores[farmId] = currentScore

    -- Only check if we have a previous score to compare
    if previousScore and previousScore ~= currentScore then
        CreditHistory.checkTierChange(farmId, previousScore, currentScore)
    end
end

--[[
    Process a single payment for a deal
    Returns true if payment successful, false if missed

    IMPORTANT: Records to BOTH PaymentTracker (primary credit factor)
    AND CreditHistory (legacy event tracking)
]]
function FarmExtension:processPaymentForDeal(farm, deal)
    local monthlyPayment = deal.monthlyPayment or 0
    local dealType = FarmExtension:getDealTypeName(deal)

    -- Check if farm can afford payment
    if farm.money < monthlyPayment then
        -- Missed payment
        deal.missedPayments = (deal.missedPayments or 0) + 1

        -- Record missed payment in PaymentTracker (PRIMARY credit system)
        if PaymentTracker then
            PaymentTracker.recordPayment(
                farm.farmId,
                deal.id or "unknown",
                PaymentTracker.STATUS_MISSED,
                monthlyPayment,
                dealType
            )
        end

        -- Also record in CreditHistory (legacy)
        if CreditHistory then
            CreditHistory.recordEvent(farm.farmId, "PAYMENT_MISSED", deal.itemName or "Unknown")
        end

        FarmExtension:handleMissedPayment(farm, deal)
        return false
    end

    -- Calculate interest and principal portions
    local interestRate = deal.interestRate or 0
    local currentBalance = deal.currentBalance or 0
    local monthlyInterest = (interestRate / 12) * currentBalance
    local principalPortion = monthlyPayment - monthlyInterest

    -- Apply payment
    deal.currentBalance = currentBalance - principalPortion
    deal.monthsPaid = (deal.monthsPaid or 0) + 1
    deal.totalInterestPaid = (deal.totalInterestPaid or 0) + monthlyInterest
    deal.missedPayments = 0  -- Reset missed counter on successful payment

    -- Deduct from farm balance
    if g_server then
        g_currentMission:addMoney(-monthlyPayment, farm.farmId, MoneyType.OTHER, true, true)
    end

    -- Record successful payment in PaymentTracker (PRIMARY credit system)
    if PaymentTracker then
        PaymentTracker.recordPayment(
            farm.farmId,
            deal.id or "unknown",
            PaymentTracker.STATUS_ON_TIME,
            monthlyPayment,
            dealType
        )
    end

    -- Also record in CreditHistory (legacy)
    if CreditHistory then
        CreditHistory.recordEvent(farm.farmId, "PAYMENT_ON_TIME", deal.itemName or "Unknown")
    end

    -- Check if deal is paid off
    if deal.currentBalance <= 0.01 or deal.monthsPaid >= deal.termMonths then
        deal.status = "paid_off"
        deal.currentBalance = 0

        -- Record deal completion in credit history (major bonus!)
        if CreditHistory then
            CreditHistory.recordEvent(farm.farmId, "DEAL_PAID_OFF", deal.itemName or "Unknown")
        end

        -- Notify player
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_OK,
            string.format("%s has been paid off!", deal.itemName or "Finance deal")
        )

        UsedPlus.logDebug(string.format("Deal paid off: %s", deal.id))
    end

    return true
end

--[[
    Get human-readable deal type name
]]
function FarmExtension:getDealTypeName(deal)
    if deal.dealType == 1 then
        return "finance"
    elseif deal.dealType == 2 then
        return "lease"
    elseif deal.dealType == 3 then
        return "loan"
    elseif deal.dealType == 4 then
        return "land"
    else
        return "unknown"
    end
end

--[[
    Handle missed payment with warnings and consequences
    Spec: 1st miss = Warning, 2nd = Urgent, 3rd = Seizure (for land)
]]
function FarmExtension:handleMissedPayment(farm, deal)
    local missedCount = deal.missedPayments or 1
    local itemName = deal.itemName or "Unknown"

    if missedCount == 1 then
        -- First warning
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
            string.format("Warning: Missed payment on %s! ($%.2f due)",
                itemName, deal.monthlyPayment)
        )
    elseif missedCount == 2 then
        -- Urgent warning
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
            string.format("URGENT: Second missed payment on %s! One more and it will be seized!",
                itemName)
        )
    elseif missedCount >= 3 then
        -- Seizure (primarily for land)
        if deal.itemType == "land" then
            FarmExtension:seizeLand(farm, deal)
        else
            -- For vehicles, just keep warning (no auto-repo implemented)
            g_currentMission:addIngameNotification(
                FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
                string.format("CRITICAL: %d missed payments on %s! Contact your lender immediately!",
                    missedCount, itemName)
            )
        end
    end

    UsedPlus.logDebug(string.format("Missed payment #%d for deal %s", missedCount, deal.id))
end

--[[
    Seize land due to non-payment
    Returns ownership to unowned and closes the deal
]]
function FarmExtension:seizeLand(farm, deal)
    local fieldId = deal.itemId  -- For land, itemId is the field ID

    -- Transfer ownership to unowned (farmId = 0)
    if g_farmlandManager and fieldId then
        local farmland = g_farmlandManager:getFarmlandById(tonumber(fieldId))
        if farmland then
            g_farmlandManager:setLandOwnership(tonumber(fieldId), FarmManager.SPECTATOR_FARM_ID)

            g_currentMission:addIngameNotification(
                FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
                string.format("Field #%s has been SEIZED due to non-payment!", fieldId)
            )

            UsedPlus.logDebug(string.format("Land seized: Field %s from farm %d", fieldId, farm.farmId))
        end
    end

    -- Close the deal
    deal.status = "seized"
    deal.currentBalance = 0
end

--[[
    Save FarmExtension data to XML
    Called from FinanceManager save
]]
function FarmExtension.saveToXMLFile(xmlFile, key)
    -- Save retroactive credit seeding flags
    local farmIndex = 0
    for farmId, seeded in pairs(FarmExtension.retroactiveCreditSeeded) do
        if seeded then
            local farmKey = string.format("%s.retroactiveSeeded.farm(%d)", key, farmIndex)
            xmlFile:setInt(farmKey .. "#farmId", farmId)
            farmIndex = farmIndex + 1
        end
    end

    UsedPlus.logDebug(string.format("FarmExtension: Saved %d retroactive seeding flags", farmIndex))

    -- v2.5.2: Save vanilla loan balances for payment detection across sessions
    local balanceIndex = 0
    for farmId, balance in pairs(FarmExtension.lastVanillaLoanBalances) do
        local balanceKey = string.format("%s.vanillaLoanBalances.farm(%d)", key, balanceIndex)
        xmlFile:setInt(balanceKey .. "#farmId", farmId)
        xmlFile:setFloat(balanceKey .. "#balance", balance)
        balanceIndex = balanceIndex + 1
    end

    UsedPlus.logDebug(string.format("FarmExtension: Saved %d vanilla loan balances", balanceIndex))
end

--[[
    Load FarmExtension data from XML
    Called from FinanceManager load
]]
function FarmExtension.loadFromXMLFile(xmlFile, key)
    -- Reset state
    FarmExtension.retroactiveCreditSeeded = {}
    FarmExtension.lastVanillaLoanBalances = {}

    -- Load retroactive credit seeding flags
    local count = 0
    xmlFile:iterate(key .. ".retroactiveSeeded.farm", function(_, farmKey)
        local farmId = xmlFile:getInt(farmKey .. "#farmId")
        if farmId then
            FarmExtension.retroactiveCreditSeeded[farmId] = true
            count = count + 1
        end
    end)

    UsedPlus.logDebug(string.format("FarmExtension: Loaded %d retroactive seeding flags", count))

    -- v2.5.2: Load vanilla loan balances for payment detection
    local balanceCount = 0
    xmlFile:iterate(key .. ".vanillaLoanBalances.farm", function(_, balanceKey)
        local farmId = xmlFile:getInt(balanceKey .. "#farmId")
        local balance = xmlFile:getFloat(balanceKey .. "#balance")
        if farmId and balance then
            FarmExtension.lastVanillaLoanBalances[farmId] = balance
            balanceCount = balanceCount + 1
        end
    end)

    UsedPlus.logDebug(string.format("FarmExtension: Loaded %d vanilla loan balances", balanceCount))
end

--[[
    Cleanup on mission unload
    Unsubscribe from MessageCenter events to prevent memory leaks
]]
function FarmExtension:delete()
    if g_messageCenter then
        g_messageCenter:unsubscribe(MessageType.PERIOD_CHANGED, FarmExtension)
        UsedPlus.logDebug("FarmExtension unsubscribed from events")
    end

    -- Reset state
    FarmExtension.initialized = false
    FarmExtension.lastVanillaLoanBalances = {}
    FarmExtension.retroactiveCreditSeeded = {}
    FarmExtension.lastCreditScores = nil

    UsedPlus.logInfo("FarmExtension cleaned up")
end

--[[
    Initialize on mission load
]]
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function(mission, node)
    FarmExtension:init()
end)

--[[
    Cleanup on mission unload
]]
Mission00.delete = Utils.appendedFunction(Mission00.delete, function(mission)
    FarmExtension:delete()
end)

UsedPlus.logInfo("FarmExtension loaded")
