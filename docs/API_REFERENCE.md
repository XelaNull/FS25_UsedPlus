# UsedPlus Public API Reference

Version: 1.0.0 (introduced in UsedPlus v2.5.2)

This document describes the public API that external mods can use to integrate with UsedPlus.

---

## Quick Start

```lua
-- Check if UsedPlus API is available
if UsedPlusAPI then
    -- Get credit score for current farm
    local score = UsedPlusAPI.getCreditScore(farmId)

    -- Check vehicle DNA
    local dna = UsedPlusAPI.getVehicleDNA(vehicle)
    if UsedPlusAPI.isLegendaryWorkhorse(vehicle) then
        -- This vehicle is nearly immortal!
    end

    -- Subscribe to events
    UsedPlusAPI.subscribe("onCreditScoreChanged", function(farmId, newScore, oldScore)
        print("Credit changed: " .. oldScore .. " -> " .. newScore)
    end)
end
```

---

## Version & Availability

### `UsedPlusAPI.getVersion()`
Returns the API version string (e.g., "1.0.0").

### `UsedPlusAPI.getModVersion()`
Returns the UsedPlus mod version (e.g., "2.5.2").

### `UsedPlusAPI.isReady()`
Returns `true` if UsedPlus is fully initialized and ready to use.

---

## Credit System API

### `UsedPlusAPI.getCreditScore(farmId)`
Get credit score for a farm.
- **farmId**: Farm ID (number)
- **Returns**: Credit score (300-850), or `nil` if unavailable

### `UsedPlusAPI.getCreditRating(farmId)`
Get credit rating tier for a farm.
- **farmId**: Farm ID
- **Returns**: rating (string), level (number 1-5)
- **Tiers**: "Excellent" (1), "Good" (2), "Fair" (3), "Poor" (4), "Very Poor" (5)

### `UsedPlusAPI.getInterestAdjustment(farmId)`
Get interest rate adjustment based on credit score.
- **farmId**: Farm ID
- **Returns**: Percentage points to add to base rate (-1.5 to +3.0)

### `UsedPlusAPI.canFinance(farmId, financeType)`
Check if a farm qualifies for financing.
- **farmId**: Farm ID
- **financeType**: "REPAIR", "VEHICLE_FINANCE", "VEHICLE_LEASE", "LAND_FINANCE", "CASH_LOAN"
- **Returns**: canFinance (boolean), minRequired (number), currentScore (number)

### `UsedPlusAPI.getPaymentStats(farmId)`
Get payment history statistics.
- **Returns**: Table with `totalPayments`, `onTimePayments`, `latePayments`, `missedPayments`, `currentStreak`, `longestStreak`

### `UsedPlusAPI.getOnTimePaymentRate(farmId)`
Get on-time payment rate as percentage (0-100).

### `UsedPlusAPI.getCreditHistory(farmId, limit)`
Get credit history events (newest first).
- **limit**: Optional max entries to return
- **Returns**: Array of history entry tables

---

## Vehicle DNA API

### `UsedPlusAPI.getVehicleDNA(vehicle)`
Get vehicle DNA (workhorse/lemon scale).
- **vehicle**: Vehicle object
- **Returns**: 0.0 (pure lemon) to 1.0 (pure workhorse), or `nil`

### `UsedPlusAPI.isWorkhorse(vehicle)`
Check if vehicle is a workhorse (DNA >= 0.65).
- **Returns**: boolean

### `UsedPlusAPI.isLegendaryWorkhorse(vehicle)`
Check if vehicle is a legendary workhorse (DNA >= 0.90).
Legendary workhorses are immune to repair degradation.
- **Returns**: boolean

### `UsedPlusAPI.isLemon(vehicle)`
Check if vehicle is a lemon (DNA <= 0.35).
- **Returns**: boolean

### `UsedPlusAPI.getDNAClassification(vehicle)`
Get DNA classification as string.
- **Returns**: "Legendary Workhorse", "Workhorse", "Average", "Lemon", or `nil`

### `UsedPlusAPI.getDNALifetimeMultiplier(vehicle)`
Get DNA-based lifetime multiplier for RVB parts.
- **Returns**: 0.6 to 1.4

---

## Maintenance State API

### `UsedPlusAPI.getFluidLevels(vehicle)`
Get fluid levels for a vehicle.
- **Returns**: Table with `oilLevel`, `hydraulicFluidLevel` (0.0-1.0)

### `UsedPlusAPI.getReliability(vehicle)`
Get reliability values for a vehicle.
- **Returns**: Table with `engine`, `electrical`, `hydraulic`, `overall` (0.0-1.0)

### `UsedPlusAPI.getActiveMalfunctions(vehicle)`
Get currently active malfunctions.
- **Returns**: Table with malfunction states (runaway, hydraulicSurge, implementStuckDown, etc.)

### `UsedPlusAPI.hasActiveMalfunction(vehicle)`
Check if vehicle has any active malfunction.
- **Returns**: boolean

### `UsedPlusAPI.getProgressiveDegradation(vehicle)`
Get progressive degradation info.
- **Returns**: Table with max reliability caps, repair/breakdown counts, total degradation

### `UsedPlusAPI.getTireInfo(vehicle)`
Get tire information (condition, tier, flat status, UYT wear if available).
- **Returns**: Array of tire data objects

---

## Finance Deals API

### `UsedPlusAPI.getActiveDeals(farmId)`
Get all active finance deals for a farm.
- **Returns**: Array of deal objects with id, type, balance, payment, etc.

### `UsedPlusAPI.getTotalDebt(farmId)`
Get total debt for a farm (all active deals + vanilla loan).
- **Returns**: Total debt amount (number)

### `UsedPlusAPI.getMonthlyObligations(farmId)`
Get monthly payment obligations.
- **Returns**: Table with `usedPlusTotal`, `externalTotal` (ELS+HP), `grandTotal`

### `UsedPlusAPI.getTotalAssets(farmId)`
Get total assets for a farm.
- **Returns**: Total asset value (number)

### `UsedPlusAPI.getStatistics(farmId)`
Get lifetime statistics for a farm.
- **Returns**: Table with various statistics

---

## Credit Bureau API

The Credit Bureau API allows external mods to register their loans/leases with UsedPlus, enabling their payment behavior to affect the player's credit score.

### Registration Flow

```lua
-- 1. When your mod creates a loan, register it with UsedPlus
local externalId = UsedPlusAPI.registerExternalDeal("MyFinanceMod", loanId, farmId, {
    dealType = "loan",
    itemName = "Equipment Loan #" .. loanId,
    originalAmount = 50000,
    monthlyPayment = 1500,
    interestRate = 0.08,
    termMonths = 36,
})

-- 2. When the player makes a payment, report it
UsedPlusAPI.reportExternalPayment(externalId, 1500)

-- 3. If the player misses a payment, report it
UsedPlusAPI.reportExternalDefault(externalId, false)  -- false = missed entirely

-- 4. When the loan is paid off or closed
UsedPlusAPI.closeExternalDeal(externalId, "paid_off")
```

### `UsedPlusAPI.registerExternalDeal(modName, dealId, farmId, dealData)`
Register an external deal with UsedPlus credit bureau.
- **modName**: Unique identifier for your mod (e.g., "EnhancedLoanSystem")
- **dealId**: Unique deal ID within your mod
- **farmId**: Farm ID the deal belongs to
- **dealData**: Table with:
  - `dealType`: "loan", "lease", "finance", "credit" (required)
  - `itemName`: Description (required)
  - `originalAmount`: Starting balance (required)
  - `currentBalance`: Current balance (optional)
  - `monthlyPayment`: Expected monthly payment (required)
  - `interestRate`: Interest rate as decimal (optional)
  - `termMonths`: Total term in months (optional)
- **Returns**: externalDealId for future calls, or `nil` on failure

### `UsedPlusAPI.reportExternalPayment(externalDealId, amount)`
Report an on-time payment. This **improves** the player's credit score.
- **externalDealId**: ID from registerExternalDeal
- **amount**: Payment amount
- **Returns**: boolean success

### `UsedPlusAPI.reportExternalDefault(externalDealId, isLate)`
Report a missed or late payment. This **hurts** the player's credit score.
- **externalDealId**: ID from registerExternalDeal
- **isLate**: `true` if paid late, `false` if missed entirely
- **Returns**: boolean success

### `UsedPlusAPI.updateExternalDealBalance(externalDealId, newBalance)`
Update the current balance (e.g., after interest accrual).
- **Returns**: boolean success

### `UsedPlusAPI.closeExternalDeal(externalDealId, reason)`
Close an external deal.
- **reason**: "paid_off", "cancelled", "defaulted", "transferred"
- **Returns**: boolean success

### `UsedPlusAPI.getExternalDeals(farmId)`
Get all active external deals for a farm.
- **Returns**: Array of deal objects

### `UsedPlusAPI.getExternalDebt(farmId)`
Get total debt from external deals.
- **Returns**: Total external debt (number)

### `UsedPlusAPI.getExternalMonthlyPayments(farmId)`
Get total monthly obligations from external deals.
- **Returns**: Total external monthly payments (number)

---

## Resale Value API

### `UsedPlusAPI.getResaleValue(vehicle)`
Get adjusted resale value considering condition, reliability, and DNA.
- **Returns**: Adjusted sale value (number)

---

## Event Subscription API

### `UsedPlusAPI.subscribe(eventName, callback, context)`
Subscribe to a UsedPlus event.

**Available Events:**

| Event | Parameters | Description |
|-------|------------|-------------|
| `onCreditScoreChanged` | farmId, newScore, oldScore, newRating, oldRating | Credit score changed |
| `onPaymentMade` | farmId, dealId, amount, dealType | Payment successfully made |
| `onPaymentMissed` | farmId, dealId, dealType | Payment was missed |
| `onDealCreated` | farmId, deal | New finance deal created |
| `onDealCompleted` | farmId, deal | Finance deal paid off |
| `onMalfunctionTriggered` | vehicle, type, message | Malfunction started |
| `onMalfunctionEnded` | vehicle, type | Malfunction ended |
| `onVehicleRepaired` | vehicle | Vehicle was repaired |

**Example:**
```lua
UsedPlusAPI.subscribe("onCreditScoreChanged", function(farmId, newScore, oldScore)
    if newScore < 600 then
        -- Show warning to player about poor credit
    end
end)

UsedPlusAPI.subscribe("onMalfunctionTriggered", function(vehicle, malfType, message)
    if malfType == "runaway" then
        -- Emergency! Vehicle has runaway engine
    end
end)
```

### `UsedPlusAPI.unsubscribe(eventName, callback)`
Unsubscribe from an event.

---

## Cross-Mod Compatibility

### `UsedPlusAPI.getCompatibleMods()`
Get detected compatible mods status.
- **Returns**: Table with boolean flags for each mod (rvbInstalled, uytInstalled, etc.)

### `UsedPlusAPI.getFeatureAvailability()`
Get feature availability based on detected mods.
- **Returns**: Table with financeEnabled, searchEnabled, loanEnabled, maintenanceEnabled

---

## Best Practices

### Always Check Availability
```lua
if UsedPlusAPI and UsedPlusAPI.isReady() then
    -- Safe to use API
end
```

### Handle nil Returns
```lua
local score = UsedPlusAPI.getCreditScore(farmId)
if score then
    -- Use score
else
    -- Handle missing data
end
```

### Clean Up Subscriptions
```lua
local myCallback = function(...) end
UsedPlusAPI.subscribe("onCreditScoreChanged", myCallback)

-- Later, when your mod unloads:
UsedPlusAPI.unsubscribe("onCreditScoreChanged", myCallback)
```

---

## Version History

### 1.0.0 (v2.5.2)
- Initial public API release
- Credit system queries
- Vehicle DNA queries
- Maintenance state queries
- Finance deal queries
- Event subscription system
- **Credit Bureau API** - External mods can register deals and report payments to affect credit scores
