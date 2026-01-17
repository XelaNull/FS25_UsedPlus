# Financial Calculations

**Loan amortization, lease payments, and depreciation formulas**

Based on patterns from: HirePurchasing, EnhancedLoanSystem, BuyUsedEquipment

---

## Overview

Financial mods need real-world formulas for:
- Annuity loan calculations
- Lease payment with balloon
- Tiered interest rates
- Equipment depreciation

---

## Annuity Loan Calculation

### Calculate Monthly Payments

```lua
-- Calculate annuity factor
function ELS_loan:calculateAnnuityFactor()
    local r = self.interest / 100  -- Interest rate as decimal
    local n = self.duration        -- Duration in years

    local annuityFactor = (((1 + r)^n) * r) / (((1 + r)^n) - 1)
    return annuityFactor
end

-- Calculate yearly annuity payment
function ELS_loan:calculateAnnuity()
    local annuity = self.amount * self:calculateAnnuityFactor()
    return annuity / 12  -- Monthly payment
end

-- Calculate interest portion for current month
function ELS_loan:calculateInterestPortion()
    local interestPortion = ((self.interest / 100) * self.restAmount)
    return interestPortion / 12
end
```

### Calculate Total Cost of Loan

```lua
function ELS_loan:calculateTotalAmount()
    local annuity = self:calculateAnnuity()
    local currentRestAmount = self.restAmount
    local totalAmount = 0

    -- Simulate payment schedule
    while true do
        local interestPortion = ((self.interest / 100) * currentRestAmount) / 12
        local repaymentPortion = annuity - interestPortion

        if repaymentPortion > currentRestAmount then
            -- Final payment
            totalAmount = totalAmount + currentRestAmount + interestPortion
            break
        else
            totalAmount = totalAmount + annuity
        end

        currentRestAmount = currentRestAmount - repaymentPortion
    end

    return totalAmount
end
```

---

## Lease Payment Calculation

### Monthly Payment with Balloon

```lua
-- Monthly payment formula with future value (balloon payment)
function LeaseDeal:getMonthlyPayment()
    local pv = self.baseCost - self.deposit  -- Present value
    local fv = self.finalFee                 -- Future value (balloon)
    local n = self.durationMonths            -- Number of periods
    local r = self:getInterestRate() / 12    -- Monthly interest rate

    -- Formula: PMT = (PV - FV/(1+r)^n) * (r(1+r)^n) / ((1+r)^n - 1)
    local monthlyPayment = (pv - fv / ((1 + r) ^ n)) * (r * (1 + r) ^ n) / ((1 + r) ^ n - 1)

    return monthlyPayment
end
```

### Tiered Interest Rates

```lua
-- Tiered interest rates based on deposit
function LeaseDeal:getInterestRate()
    local depositRatio = self.deposit / self.baseCost

    if depositRatio <= 0.051 then
        return 0.05    -- 5%
    elseif depositRatio <= 0.11 then
        return 0.04    -- 4%
    elseif depositRatio <= 0.21 then
        return 0.035   -- 3.5%
    elseif depositRatio <= 0.31 then
        return 0.0295  -- 2.95%
    else
        return 0.025   -- 2.5%
    end
end
```

### Early Settlement Amount

```lua
function LeaseDeal:getSettlementCost()
    local remainingMonths = self.durationMonths - self.monthsPaid
    local monthlyPrincipal = (self.baseCost - self.deposit - self.finalFee) / self.durationMonths
    return (monthlyPrincipal * remainingMonths) + self.finalFee
end
```

---

## Equipment Depreciation

### Multi-Generation Depreciation Model

```lua
BuyUsedEquipment.GENERATIONS = {
    {
        maxYear = 0,
        age = { 5, 25 },
        discount = { 0.12, 0.1875 },
        hours = { 2.5, 12.5 },
        damage = { 0.05, 0.25 },
        wear = { 0.045, 0.2375 },
    },
    {
        maxYear = 3,
        age = { 15, 35 },
        discount = { 0.2, 0.3125 },
        hours = { 7.5, 17.5 },
        damage = { 0.15, 0.35 },
        wear = { 0.135, 0.3325 },
    },
    {
        maxYear = 6,
        age = { 25, 45 },
        discount = { 0.3125, 0.4375 },
        hours = { 12.5, 22.5 },
        damage = { 0.25, 0.45 },
        wear = { 0.2275, 0.4275 },
    },
    -- More generations...
}
```

### Calculate Used Price

```lua
function BuyUsedEquipment:calculateUsedPrice(basePrice, age, condition)
    -- Find appropriate generation
    local generation = self:getGenerationForAge(age)

    -- Calculate depreciation
    local ageDepreciation = self:interpolate(
        generation.discount[1],
        generation.discount[2],
        age / generation.age[2]
    )
    local conditionFactor = 1 - (condition * 0.3)  -- Up to 30% impact from condition

    local usedPrice = basePrice * (1 - ageDepreciation) * conditionFactor

    return math.floor(usedPrice)
end

function BuyUsedEquipment:interpolate(min, max, factor)
    factor = math.max(0, math.min(1, factor))
    return min + (max - min) * factor
end
```

---

## Affordability Check

```lua
function canAfford(farmId, amount)
    local farm = g_farmManager:getFarmById(farmId)
    if farm then
        return farm.money >= amount
    end
    return false
end

-- Usage in shop
function MyMod:onPurchaseClick(storeItem)
    local totalCost = self:calculateTotalCost(storeItem)
    local farmId = g_currentMission:getFarmId()

    if not canAfford(farmId, totalCost) then
        g_gui:showInfoDialog({
            text = g_i18n:getText("error_insufficientFunds")
        })
        return
    end

    self:processPurchase(storeItem, totalCost)
end
```

---

## Configurable Payment System

### Payment Mode Enum
```lua
FinanceDeal.PAYMENT_MODE = {
    SKIP = 0,       -- Skip payment (negative amortization)
    MINIMUM = 1,    -- Interest-only payment
    STANDARD = 2,   -- Regular amortized payment
    EXTRA = 3,      -- Double payment
    CUSTOM = 4,     -- User-defined amount
}
```

### Calculate Minimum Payment (Interest-Only)
```lua
function FinanceDeal:calculateMinimumPayment()
    local r = self.interestRate / 12
    return (self.currentBalance + self.accruedInterest) * r
end
```

### Negative Amortization Handling
When payment is less than interest due, unpaid interest is added to balance:
```lua
if paymentAmount < interestDue then
    local unpaidInterest = interestDue - paymentAmount
    self.accruedInterest = self.accruedInterest + unpaidInterest
    self.currentBalance = self.currentBalance + unpaidInterest
end
```

### Recalculate Remaining Term
Show impact of extra payments on payoff timeline:
```lua
function FinanceDeal:recalculateRemainingMonths()
    local payment = self:getConfiguredPaymentAmount()
    local balance = self.currentBalance + self.accruedInterest
    local r = self.interestRate / 12

    if payment <= 0 or r <= 0 then
        return 999  -- Effectively infinite
    end

    -- For interest-only payments, loan never ends
    local minimumPayment = balance * r
    if payment <= minimumPayment then
        return 999
    end

    -- Standard remaining term calculation
    -- n = -log(1 - (r*P/M)) / log(1+r)
    local ratio = (r * balance) / payment
    if ratio >= 1 then
        return 999  -- Payment doesn't cover interest growth
    end

    local n = -math.log(1 - ratio) / math.log(1 + r)
    return math.ceil(n)
end
```

---

## Common Pitfalls

### 1. Integer Division
Use floating point for financial calculations:
```lua
local rate = 5 / 100  -- 0.05, not 0
```

### 2. Rounding
Round final prices, not intermediate calculations:
```lua
local final = math.floor(calculated)
```

### 3. Zero Duration/Rate
Always guard against division by zero:
```lua
if duration > 0 then
    -- calculate
end
```

### 4. Cumulative Rounding Errors
Track actual payments vs calculated to handle pennies.
