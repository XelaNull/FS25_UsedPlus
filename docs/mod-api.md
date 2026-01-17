# Mod-to-Mod API Integration

**How to integrate external mods with UsedPlus systems**

Based on: FS25_UsedPlus/src/utils/UsedPlusAPI.lua (v1.0.0)

---

> ✅ **VALIDATED & PRODUCTION READY**
>
> The UsedPlusAPI provides a stable, documented interface for external mods.
>
> **Implementation:** `FS25_UsedPlus/src/utils/UsedPlusAPI.lua` (997 lines)
>
> **API Version:** 1.0.0 | **Mod Version:** 2.5.2+

---

## Overview

The UsedPlusAPI allows external mods to:
- Query credit scores and financial status
- Read vehicle DNA (workhorse/lemon scale)
- Access maintenance states (fluids, malfunctions, reliability)
- Get finance deal information
- **Register external deals with UsedPlus credit bureau**
- Subscribe to UsedPlus events

---

## Quick Start

### Check if UsedPlus is Available

```lua
-- Always check before using the API
if UsedPlusAPI then
    local creditScore = UsedPlusAPI.getCreditScore(farmId)
    local dna = UsedPlusAPI.getVehicleDNA(vehicle)
end

-- More thorough check
if UsedPlusAPI and UsedPlusAPI.isReady() then
    -- Full system is initialized
end
```

### Get API Version

```lua
local apiVersion = UsedPlusAPI.getVersion()      -- "1.0.0"
local modVersion = UsedPlusAPI.getModVersion()   -- "2.5.2"
```

---

## Credit System API

### Get Credit Score

```lua
-- Get raw credit score (300-850)
local score = UsedPlusAPI.getCreditScore(farmId)

-- Get rating tier and level
local rating, level = UsedPlusAPI.getCreditRating(farmId)
-- rating: "Excellent", "Good", "Fair", "Poor", "Very Poor"
-- level: 1-5 (1 = best)

-- Get interest rate adjustment based on credit
local adjustment = UsedPlusAPI.getInterestAdjustment(farmId)
-- Returns -1.5 to +3.0 (percentage points to add to base rate)
```

### Check Financing Eligibility

```lua
local canFinance, minRequired, currentScore = UsedPlusAPI.canFinance(farmId, "VEHICLE_FINANCE")

-- Finance types:
-- "REPAIR", "VEHICLE_FINANCE", "VEHICLE_LEASE", "LAND_FINANCE", "CASH_LOAN"
```

### Payment History

```lua
-- Get payment statistics
local stats = UsedPlusAPI.getPaymentStats(farmId)
-- Returns: { totalPayments, onTimePayments, latePayments, missedPayments, currentStreak, longestStreak }

-- Get on-time payment rate
local rate = UsedPlusAPI.getOnTimePaymentRate(farmId)  -- 0-100 percentage

-- Get credit history events
local history = UsedPlusAPI.getCreditHistory(farmId, 10)  -- Last 10 events
```

---

## Vehicle DNA API

UsedPlus assigns each vehicle a "DNA" value representing its inherent quality on a workhorse/lemon scale.

### Query DNA

```lua
-- Get DNA value (0.0 = pure lemon, 1.0 = pure workhorse)
local dna = UsedPlusAPI.getVehicleDNA(vehicle)

-- Classification helpers
local isWorkhorse = UsedPlusAPI.isWorkhorse(vehicle)           -- DNA >= 0.65
local isLegendary = UsedPlusAPI.isLegendaryWorkhorse(vehicle)  -- DNA >= 0.90
local isLemon = UsedPlusAPI.isLemon(vehicle)                   -- DNA <= 0.35

-- Get classification string
local classification = UsedPlusAPI.getDNAClassification(vehicle)
-- "Legendary Workhorse", "Workhorse", "Average", or "Lemon"

-- Get lifetime multiplier for RVB parts integration
local multiplier = UsedPlusAPI.getDNALifetimeMultiplier(vehicle)
-- 0.6 (lemon) to 1.4 (workhorse)
```

### DNA Thresholds

| DNA Value | Classification | Effects |
|-----------|---------------|---------|
| 0.90+ | Legendary Workhorse | Immune to repair degradation |
| 0.65-0.89 | Workhorse | Reduced breakdown chance |
| 0.36-0.64 | Average | Standard behavior |
| 0.00-0.35 | Lemon | Increased breakdown chance |

---

## Maintenance State API

### Fluid Levels

```lua
local fluids = UsedPlusAPI.getFluidLevels(vehicle)
-- Returns: { oilLevel = 0.0-1.0, hydraulicFluidLevel = 0.0-1.0 }
```

### Reliability

```lua
local reliability = UsedPlusAPI.getReliability(vehicle)
-- Returns: {
--   engine = 0.0-1.0,
--   electrical = 0.0-1.0,
--   hydraulic = 0.0-1.0,
--   overall = 0.0-1.0
-- }
```

### Active Malfunctions

```lua
-- Check if any malfunction is active
local hasMalfunction = UsedPlusAPI.hasActiveMalfunction(vehicle)

-- Get detailed malfunction info
local malfunctions = UsedPlusAPI.getActiveMalfunctions(vehicle)
-- Returns table with active malfunctions:
-- - runaway: { active, startTime }
-- - hydraulicSurge: { active, endTime }
-- - implementStuckDown: { active, endTime }
-- - implementStuckUp: { active, endTime }
-- - implementPull: { active, direction }
-- - implementDrag: { active }
-- - electricalCutout: { active, endTime }
-- - steeringPull: { active, strength, direction }
```

### Progressive Degradation

```lua
local degradation = UsedPlusAPI.getProgressiveDegradation(vehicle)
-- Returns: {
--   maxEngineReliability = 0.0-1.0 (current cap),
--   maxElectricalReliability = 0.0-1.0,
--   maxHydraulicReliability = 0.0-1.0,
--   repairCount = number,
--   breakdownCount = number,
--   rvbTotalDegradation = number,
--   rvbRepairCount = number,
--   rvbBreakdownCount = number
-- }
```

### Tire Information

```lua
local tires = UsedPlusAPI.getTireInfo(vehicle)
-- Returns array: [{
--   index = 1,
--   condition = 0.0-1.0,
--   tier = 1-3 (1=Retread, 2=Normal, 3=Quality),
--   isFlat = boolean,
--   uytWear = number (if UYT mod installed)
-- }, ...]
```

---

## Finance Deals API

### Query Active Deals

```lua
-- Get all active deals for a farm
local deals = UsedPlusAPI.getActiveDeals(farmId)
-- Returns array: [{
--   id, dealType, itemName, originalAmount, currentBalance,
--   monthlyPayment, interestRate, termMonths, monthsPaid,
--   remainingMonths, missedPayments
-- }, ...]

-- Get total debt (UsedPlus deals + vanilla loan)
local totalDebt = UsedPlusAPI.getTotalDebt(farmId)

-- Get total assets
local totalAssets = UsedPlusAPI.getTotalAssets(farmId)

-- Get monthly payment obligations
local obligations = UsedPlusAPI.getMonthlyObligations(farmId)
-- Returns: { usedPlusTotal, externalTotal, grandTotal }
```

### Resale Value

```lua
-- Get condition-adjusted resale value
local value = UsedPlusAPI.getResaleValue(vehicle)
-- Factors in reliability, DNA, damage, wear
```

---

## Credit Bureau API

**This is the most powerful integration point.** External finance mods can register their deals with UsedPlus to affect credit scores!

### Register an External Deal

```lua
-- When your mod creates a loan/lease, register it with UsedPlus
local externalDealId = UsedPlusAPI.registerExternalDeal(
    "MyFinanceMod",           -- Your mod's unique identifier
    "loan_12345",             -- Your internal deal ID
    farmId,                   -- Farm ID
    {
        dealType = "loan",              -- "loan", "lease", "finance", "credit"
        itemName = "Equipment Loan",    -- Description
        originalAmount = 50000,         -- Starting balance
        currentBalance = 50000,         -- Current balance (optional)
        monthlyPayment = 2500,          -- Expected monthly payment
        interestRate = 0.08,            -- As decimal (optional)
        termMonths = 24,                -- Term in months (optional)
    }
)
```

### Report Payments

```lua
-- When player makes an on-time payment
UsedPlusAPI.reportExternalPayment(externalDealId, 2500)
-- This improves their credit score!

-- When player misses a payment
UsedPlusAPI.reportExternalDefault(externalDealId, false)  -- false = missed entirely
UsedPlusAPI.reportExternalDefault(externalDealId, true)   -- true = paid late
-- This hurts their credit score!

-- Update balance (e.g., interest accrual)
UsedPlusAPI.updateExternalDealBalance(externalDealId, 47500)

-- Close the deal
UsedPlusAPI.closeExternalDeal(externalDealId, "paid_off")
-- reasons: "paid_off", "cancelled", "defaulted", "transferred"
```

### Query External Deals

```lua
-- Get all external deals for a farm
local externalDeals = UsedPlusAPI.getExternalDeals(farmId)

-- Get total external debt
local externalDebt = UsedPlusAPI.getExternalDebt(farmId)

-- Get external monthly payments
local externalPayments = UsedPlusAPI.getExternalMonthlyPayments(farmId)
```

---

## Event Subscription API

Subscribe to UsedPlus events to react to financial and maintenance changes.

### Available Events

| Event | Parameters | When Fired |
|-------|------------|------------|
| `onCreditScoreChanged` | farmId, oldScore, newScore | Credit score changes |
| `onPaymentMade` | farmId, dealId, amount | Payment processed |
| `onPaymentMissed` | farmId, dealId | Payment missed |
| `onDealCreated` | farmId, deal | New deal created |
| `onDealCompleted` | farmId, deal | Deal paid off/closed |
| `onMalfunctionTriggered` | vehicle, malfunctionType | Breakdown occurs |
| `onMalfunctionEnded` | vehicle, malfunctionType | Malfunction resolved |
| `onVehicleRepaired` | vehicle, repairType | Vehicle repaired |

### Subscribe/Unsubscribe

```lua
-- Subscribe to credit score changes
local function onCreditChange(farmId, oldScore, newScore)
    print(string.format("Farm %d credit: %d -> %d", farmId, oldScore, newScore))
end

UsedPlusAPI.subscribe("onCreditScoreChanged", onCreditChange)

-- With context (self)
UsedPlusAPI.subscribe("onMalfunctionTriggered", self.onMalfunction, self)

-- Unsubscribe
UsedPlusAPI.unsubscribe("onCreditScoreChanged", onCreditChange)
```

---

## Cross-Mod Compatibility

### Check Compatible Mods

```lua
local mods = UsedPlusAPI.getCompatibleMods()
-- Returns: {
--   rvbInstalled = boolean,            -- Realistic Vehicle Breakdowns
--   uytInstalled = boolean,            -- Use Your Tires
--   advancedMaintenanceInstalled = boolean,
--   hirePurchasingInstalled = boolean,
--   buyUsedEquipmentInstalled = boolean,
--   enhancedLoanSystemInstalled = boolean,
-- }
```

### Check Feature Availability

```lua
local features = UsedPlusAPI.getFeatureAvailability()
-- Returns: {
--   financeEnabled = boolean,
--   searchEnabled = boolean,
--   loanEnabled = boolean,
--   maintenanceEnabled = boolean,
-- }
```

---

## Complete Integration Example

```lua
-- MyFinanceMod integration with UsedPlus
MyFinanceMod = {}

function MyFinanceMod:createLoan(farmId, amount, term)
    local dealId = self:generateDealId()
    local monthlyPayment = self:calculatePayment(amount, term)

    -- Create our internal loan
    local loan = {
        id = dealId,
        farmId = farmId,
        amount = amount,
        balance = amount,
        term = term,
        monthlyPayment = monthlyPayment,
    }
    self.loans[dealId] = loan

    -- Register with UsedPlus credit bureau (if available)
    if UsedPlusAPI and UsedPlusAPI.isReady() then
        loan.usedPlusId = UsedPlusAPI.registerExternalDeal(
            "MyFinanceMod",
            dealId,
            farmId,
            {
                dealType = "loan",
                itemName = "MyFinanceMod Loan",
                originalAmount = amount,
                monthlyPayment = monthlyPayment,
                termMonths = term,
            }
        )

        -- Check their credit score for interest rate
        local score = UsedPlusAPI.getCreditScore(farmId)
        local adjustment = UsedPlusAPI.getInterestAdjustment(farmId)
        loan.interestRate = self.baseRate + adjustment
    end

    return loan
end

function MyFinanceMod:processPayment(loan, amount)
    loan.balance = loan.balance - amount

    -- Report to UsedPlus
    if loan.usedPlusId and UsedPlusAPI then
        UsedPlusAPI.reportExternalPayment(loan.usedPlusId, amount)
    end

    if loan.balance <= 0 then
        self:closeLoan(loan)
    end
end

function MyFinanceMod:missedPayment(loan)
    -- Report to UsedPlus (hurts their credit!)
    if loan.usedPlusId and UsedPlusAPI then
        UsedPlusAPI.reportExternalDefault(loan.usedPlusId, false)
    end
end
```

---

## API Stability Promise

- **Version 1.x.x**: Breaking changes will increment the major version
- **Graceful degradation**: All functions return nil/false/empty if systems unavailable
- **No exceptions**: API functions are wrapped in pcall internally

---

## Common Pitfalls

### 1. Not Checking API Availability
```lua
-- WRONG: Crashes if UsedPlus not installed
local score = UsedPlusAPI.getCreditScore(farmId)

-- CORRECT: Always check first
if UsedPlusAPI then
    local score = UsedPlusAPI.getCreditScore(farmId)
end
```

### 2. Forgetting to Close Deals
```lua
-- Always close deals when they're done
UsedPlusAPI.closeExternalDeal(externalDealId, "paid_off")
```

### 3. Wrong Farm ID
```lua
-- Use g_currentMission:getFarmId() for current player
local farmId = g_currentMission:getFarmId()
```

---

*Last Updated: 2026-01-17 | UsedPlusAPI v1.0.0*
