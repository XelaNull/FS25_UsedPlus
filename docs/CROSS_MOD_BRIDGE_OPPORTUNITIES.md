# Cross-Mod Bridge Opportunities

**Created:** 2026-01-17
**Updated:** 2026-01-17 (v2.7.0 Seizure Escalation | Bridges #2, #8 Removed)
**Status:** Bridge #6 COMPLETE - UsedPlus now provides full AM replacement (Bridge #2 removed as redundant)
**Purpose:** Document opportunities for UsedPlus to act as a hub connecting multiple mods

---

## Overview

UsedPlus has compatibility with 7 mods (6 original + 1 discovered):

| Mod | Type | Current Integration | Settings UI? |
|-----|------|---------------------|--------------|
| **RVB** (Real Vehicle Breakdowns) | Maintenance | DEEP - Part data sync, OBD display | ✅ Full |
| **UYT** (Use Your Tyres) | Maintenance | DEEP - Tire wear sync, OBD display | ❌ Minimal (1 setting) |
| **AM** (AdvancedMaintenance) | Maintenance | CHAIN - Engine damage check only | ❌ NONE |
| **HP** (HirePurchasing) | Financial | UI HIDE - Hides Finance button | ❌ NONE |
| **BUE** (BuyUsedEquipment) | Financial | UI HIDE - Hides Search button | ❌ NONE |
| **ELS** (EnhancedLoanSystem) | Financial | FEATURE DISABLE - Disables loans | ✅ Full (7 settings) |
| **VehicleExplorer** | Fleet UI | NOT YET - Opportunity identified | ✅ Full |

**Opportunity:** Rather than just avoiding conflicts, UsedPlus could ACT AS A HUB connecting these mods together, creating synergies where the whole is greater than the sum of parts.

---

## Implementation Status Summary

| Bridge | Status | Notes |
|--------|--------|-------|
| #1 Unified Health Score | ❌ NOT BUILT | No single aggregated metric |
| #3 Consistent Generation | ⚠️ PARTIAL | Has RVB + UYT but NOT AM damage |
| #4 Financial Aggregation | ✅ FULLY BUILT | Finance page shows UP + ELS + HP + Employment |
| #5 Repair Estimation | ❌ NOT BUILT | No unified repair cost calculator |
| #6 Progressive Unreliability | ✅ **ENHANCED v2.7.0** | Complete AM replacement with seizure escalation |
| #7 VehicleExplorer Integration | ❌ NOT BUILT | New opportunity |

---

## Known Issues

### UYT Tire Dialog Conflict

**Problem:** UsedPlus has a separate Tires button (KEY_t via RVB Workshop) that shows TiresDialog with quality selection. UYT has its own button (KEY_r) that shows YesNoDialog for replacement.

| Aspect | UYT | UsedPlus |
|--------|-----|----------|
| Button | `uytReplace` (KEY_r) | `usedPlusTiresButton` (KEY_t) |
| Dialog | Native YesNoDialog | TiresDialog (quality selection) |
| Data Sync | Resets `uytTravelledDist` | Does NOT sync to UYT |

**Impact:** TiresDialog displays UYT per-wheel wear data but doesn't call UYT's replacement event when confirming, so UYT's wear tracking isn't reset.

**Fix Required:** TiresDialog should call `UytReplaceEvent` to sync with UYT's backend, OR without RVB, UsedPlus should override UYT's button entirely.

---

## Bridge #1: Unified Vehicle Health Score

**Mods Bridged:** RVB + UYT + AM + UsedPlus

**Concept:** Aggregate ALL maintenance data into ONE authoritative health score (0-100).

### Implementation

```lua
function ModCompatibility.getUnifiedVehicleHealth(vehicle)
    local components = {}
    local weights = {}
    local totalWeight = 0

    -- RVB CONTRIBUTION (40% weight when installed)
    if ModCompatibility.rvbInstalled then
        local engineLife = ModCompatibility.getRVBPartLife(vehicle, "ENGINE")
        local thermoLife = ModCompatibility.getRVBPartLife(vehicle, "THERMOSTAT")
        local genLife = ModCompatibility.getRVBPartLife(vehicle, "GENERATOR")
        local batLife = ModCompatibility.getRVBPartLife(vehicle, "BATTERY")
        local startLife = ModCompatibility.getRVBPartLife(vehicle, "SELFSTARTER")

        local rvbScore = (engineLife * 0.35 + thermoLife * 0.15 +
                         genLife * 0.20 + batLife * 0.15 + startLife * 0.15)

        components.rvb = rvbScore * 100
        weights.rvb = 0.40
        totalWeight = totalWeight + 0.40
    end

    -- UYT CONTRIBUTION (15% weight when installed)
    if ModCompatibility.uytInstalled then
        local worstTire = ModCompatibility.getWorstUYTTireWear(vehicle)
        components.uyt = (1.0 - worstTire) * 100
        weights.uyt = 0.15
        totalWeight = totalWeight + 0.15
    end

    -- AM CONTRIBUTION (20% weight when installed)
    if ModCompatibility.advancedMaintenanceInstalled then
        local damage = vehicle:getDamageAmount() or 0
        local amScore = (1.0 - damage) * 100
        if damage > 0.28571 then
            amScore = amScore * 0.8  -- Penalty for danger zone
        end
        components.am = amScore
        weights.am = 0.20
        totalWeight = totalWeight + 0.20
    end

    -- USEDPLUS CONTRIBUTION (fills remaining weight)
    local spec = vehicle.spec_usedPlusMaintenance
    if spec then
        local upScore = (spec.engineReliability * 0.4 +
                        spec.hydraulicReliability * 0.35 +
                        spec.electricalReliability * 0.25) * 100
        local upWeight = math.max(0.25, 1.0 - totalWeight)
        components.usedplus = upScore
        weights.usedplus = upWeight
        totalWeight = totalWeight + upWeight
    end

    -- Calculate unified score
    local unifiedScore = 0
    for key, score in pairs(components) do
        unifiedScore = unifiedScore + (score * weights[key])
    end
    if totalWeight > 0 then
        unifiedScore = unifiedScore / totalWeight
    end

    return {
        score = math.floor(unifiedScore),
        grade = getHealthGrade(unifiedScore),
        components = components,
        sources = { rvb = rvbInstalled, uyt = uytInstalled, am = amInstalled }
    }
end
```

### Use Cases
- **Resale Value:** `sellPrice = basePrice * (health.score / 100)`
- **Loan Eligibility:** Banks reject vehicles with grade < C
- **Search Results:** Show health grade on used vehicle listings
- **OBD Scanner:** Display "OVERALL HEALTH: B (72%)" at top

### Value: HIGH | Complexity: MEDIUM

---

## Bridge #3: Consistent Used Vehicle Generation

**Mods Bridged:** RVB + UYT + AM + UsedPlus

**Concept:** When generating a used vehicle listing, ALL mod data is pre-generated CONSISTENTLY based on DNA.

### Current State
- UsedPlus already generates RVB part data for listings
- UsedPlus already generates UYT tire conditions for listings
- UsedPlus generates DNA (workhorseLemonScale)
- **MISSING:** AM-compatible damage level

### What to Add
```lua
-- In UsedVehicleManager:generateListing()

-- Generate AM-compatible damage (matches DNA)
listing.amDamage = 1.0 - listing.condition

-- Ensure lemons have damage above AM threshold
if listing.workhorseLemonScale < 0.30 and listing.amDamage < 0.30 then
    listing.amDamage = 0.30 + math.random() * 0.20
end
```

### Why It Matters
A "lemon" should be consistently bad across ALL systems:
- Bad RVB parts
- Worn UYT tires
- High AM damage
- Low UsedPlus reliability

### Value: HIGH | Complexity: LOW

---

## Bridge #4: Financial Aggregation

**Mods Bridged:** HP + ELS + UsedPlus

**Concept:** Finance Manager shows unified obligations from ALL financial mods.

### Current State
- UsedPlus already reads HP leases via `ModCompatibility.getHPLeases()`
- UsedPlus already reads ELS loans via `ModCompatibility.getELSLoans()`
- Finance Manager displays UsedPlus deals

### What to Add
Unified financial overview function:
```lua
function FinanceManager:getUnifiedFinancialOverview(farmId)
    local overview = {
        totalDebt = 0,
        totalMonthlyPayment = 0,
        sources = {}
    }

    -- UsedPlus deals
    local upDeals = self:getActiveDeals(farmId)
    -- ... aggregate

    -- HP leases (if installed)
    if ModCompatibility.hirePurchasingInstalled then
        local hpLeases = ModCompatibility.getHPLeases(farmId)
        -- ... aggregate
    end

    -- ELS loans (if installed)
    if ModCompatibility.enhancedLoanSystemInstalled then
        local elsLoans = ModCompatibility.getELSLoans(farmId)
        -- ... aggregate
    end

    return overview
end
```

### Display
```
╔════════════════════════════════════════╗
║     UNIFIED FINANCIAL OVERVIEW         ║
╠════════════════════════════════════════╣
║  TOTAL DEBT:        $485,000           ║
║  MONTHLY PAYMENTS:  $12,450            ║
╠════════════════════════════════════════╣
║  BY SOURCE:                            ║
║  ├─ UsedPlus:       $285,000 (3 deals) ║
║  ├─ HirePurchasing: $120,000 (2 lease) ║
║  └─ ELS:            $80,000 (1 loan)   ║
╚════════════════════════════════════════╝
```

### Value: MEDIUM | Complexity: LOW

---

## Bridge #5: Unified Repair Cost Estimation

**Mods Bridged:** RVB + UYT + AM + UsedPlus

**Concept:** Single function estimates total repair cost across all mod systems.

### Implementation
```lua
function ModCompatibility.getUnifiedRepairEstimate(vehicle)
    local estimate = { total = 0, breakdown = {} }
    local basePrice = vehicle:getSellPrice() or 50000

    -- RVB parts needing replacement
    if ModCompatibility.rvbInstalled then
        local rvbCost = 0
        -- Check each part, add replacement cost if life < 30%
        estimate.breakdown.rvb = rvbCost
        estimate.total = estimate.total + rvbCost
    end

    -- UYT tires needing replacement
    if ModCompatibility.uytInstalled then
        local worstWear = ModCompatibility.getWorstUYTTireWear(vehicle)
        if worstWear > 0.70 then
            local tireCost = ModCompatibility.getUYTReplacementCost(vehicle)
            estimate.breakdown.uyt = tireCost
            estimate.total = estimate.total + tireCost
        end
    end

    -- AM damage repair
    if ModCompatibility.advancedMaintenanceInstalled then
        local damage = vehicle:getDamageAmount() or 0
        if damage > 0.28571 then
            local amCost = basePrice * damage * 0.5
            estimate.breakdown.am = amCost
            estimate.total = estimate.total + amCost
        end
    end

    return estimate
end
```

### Value: MEDIUM | Complexity: LOW

---

## Bridge #6: Progressive Engine Unreliability (RVB Enhancement)

**Mods Bridged:** RVB + UsedPlus (COMPLETE replacement for AM)

**Status:** ✅ **IMPLEMENTED v2.7.0** (2026-01-17)

**Concept:** Progressive malfunction frequency AND seizure escalation - makes UsedPlus a complete AdvancedMaintenance replacement.

### What Was Implemented (v2.7.0)

#### Enhancement 1: Progressive Malfunction Frequency

Malfunctions become MORE FREQUENT as reliability drops (quadratic curve):

| Reliability | Malfunction Chance/sec | Per-Minute Chance |
|-------------|------------------------|-------------------|
| 100% | 0.001% | ~0.06% |
| 70% | 0.08% | ~4.7% |
| 50% | 0.25% | ~14% |
| 30% | 0.75% | ~36% |
| 10% | 1.6% | ~62% |
| 0% | 2.5% | ~78% |

**Player Experience:**
- At 50% reliability: Malfunction roughly every 7 minutes of operation
- At 10% reliability: Multiple malfunctions per minute - nearly undrivable!

#### Enhancement 2: Seizure Escalation

When a malfunction triggers below a DNA-variable threshold, roll a die:
- **PASS:** Normal temporary malfunction (existing behavior - stall, cutout, etc.)
- **FAIL:** Permanent seizure requiring repair

**Threshold varies by DNA:**
- **Lemon (DNA 0.0):** Seizure zone starts at 40% reliability
- **Average (DNA 0.5):** Seizure zone starts at 25% reliability
- **Workhorse (DNA 1.0):** Seizure zone starts at 10% reliability

**Seizure Types:**
- **Engine Seized:** Motor won't start at all
- **Hydraulics Seized:** Implements frozen in place
- **Electrical Seized:** All systems dead (lights, PTO, implements)

#### Repair Methods

1. **OBD Scanner (Field Service Kit):**
   - Shows "SEIZED!" on affected components
   - Clicking seized component offers emergency repair
   - Costs 5% of vehicle price per component
   - Restores reliability to at least 30%
   - Consumes the OBD Scanner kit

2. **Workshop Repair:**
   - Any workshop repair automatically clears all seizures
   - Full reliability restoration based on repair percentage

### Why This Is Better Than AM

| Aspect | AdvancedMaintenance | UsedPlus v2.7.0 |
|--------|---------------------|-----------------|
| **Threshold** | Fixed 28.57% | DNA-variable (10%-40%) |
| **Warning** | None | Progressive malfunctions first |
| **Failure Type** | Permanent until workshop | BOTH temporary AND permanent |
| **Recovery** | Workshop only | OBD Scanner OR Workshop |
| **Component Granularity** | Engine only | Engine, Hydraulics, Electrical |
| **Player Agency** | None (random) | DNA affects threshold |

### Configuration Options (in UsedPlusMaintenance.CONFIG)

```lua
-- Progressive Frequency
progressiveFailureExponent = 2.0,         -- Curve steepness
progressiveFailureMultiplier = 0.025,     -- Max failure rate

-- Seizure Escalation
enableSeizureEscalation = true,           -- Master toggle
seizureBaseThreshold = 0.40,              -- Lemon threshold
seizureDNAReduction = 0.30,               -- Workhorse reduction
seizureMinChance = 0.05,                  -- 5% at threshold
seizureMaxChance = 0.50,                  -- 50% at 0% reliability
seizureLemonPenalty = 0.20,               -- Lemons +20% chance

-- Repair
seizureRepairCostMult = 0.05,             -- 5% vehicle price
seizureRepairMinReliability = 0.30,       -- Min restore level
```

### Files Modified

- `UsedPlusMaintenance.lua` - Core seizure system (~250 lines)
- `FieldServiceKitDialog.lua` - OBD Scanner repair (~170 lines)
- `RepairVehicleEvent.lua` - Workshop clears seizures (~10 lines)
- `translation_en.xml` - 11 new translation keys

### Value: VERY HIGH | Complexity: MEDIUM | Status: ✅ COMPLETE

---

## Implementation Priority

| Bridge | Value | Complexity | Priority |
|--------|-------|------------|----------|
| #6 Progressive Engine Unreliability | HIGH | LOW | ✅ DONE |
| #3 Consistent Generation | HIGH | LOW | **1st** |
| #1 Unified Health Score | HIGH | MEDIUM | **2nd** |
| #7 VehicleExplorer Integration | MEDIUM | LOW | 3rd |
| #4 Financial Aggregation | MEDIUM | LOW | ✅ DONE |
| #5 Repair Estimation | MEDIUM | LOW | 4th |

---

## Research Findings (2026-01-17)

### Question 1: AM + RVB Engine Relationship

**ANSWERED: They CONFLICT when both installed.**

| Aspect | AM | RVB |
|--------|----|----|
| What it reads | `getDamageAmount()` | Own part system (8 parts) |
| What it overrides | `getCanMotorRun()` | `getCanMotorRun()` AND `getDamageAmount()` |
| Shutdown trigger | Damage > 28.57% | Part life = 0% |

**The Problem:**
1. Both mods override `getCanMotorRun()` - last mod loaded wins
2. RVB overwrites `getDamageAmount()` to return a synthetic part-average value
3. So when AM checks damage, it gets RVB's synthetic value, not vanilla damage
4. Behavior is unpredictable based on mod load order

**Recommendation:** Players should use RVB **OR** AM, not both. Our bridges should NOT assume both are installed together.

---

### Question 2: Existing Mod Integrations

**ANSWERED: Only ONE cross-mod integration exists.**

| Mod | Integrates With | Direction |
|-----|-----------------|-----------|
| **RVB** | UYT | RVB → UYT (one-way) |
| **UYT** | None | - |
| **AM** | None | Completely isolated |
| **HP** | None | Standalone |
| **BUE** | None | Standalone |
| **ELS** | None | Standalone |

**RVB → UYT Integration Details:**
- Detection: `g_modIsLoaded["FS25_useYourTyres"]`
- Adjusts tire wear constants based on RVB difficulty settings
- Shows per-wheel tire wear in RVB's info HUD
- Workshop button management

**Key Insight:** The financial mods (HP, BUE, ELS) and maintenance mods (RVB, UYT, AM) exist in complete isolation from each other. UsedPlus would be the **first hub** connecting these worlds.

---

### Question 3: Weight Tuning

**STATUS: Still requires playtesting.**

Proposed weights are theoretical estimates. Need actual gameplay testing to determine if:
- RVB 40% feels right (dominates when installed)
- UYT 15% appropriately reflects tire importance
- AM 20% balances with other damage systems

---

## Known Conflicts

### AM + RVB Conflict (Critical)

**Severity:** HIGH - Unpredictable behavior

**What Happens:**
```
Both mods prepend to Vehicle.getCanMotorRun():
- AM: Checks getDamageAmount() > 0.28571 → random shutdown chance
- RVB: Checks if ENGINE part life = 0 → blocks motor

Last mod loaded wins the override!
```

**Additionally:**
RVB overwrites `getDamageAmount()` to return average of all part lives instead of vanilla damage. This breaks AM's damage reading.

**Recommendation for Players:**
- Use RVB for detailed part-based failures, OR
- Use AM for simple damage-based shutdowns
- Do NOT install both simultaneously

**Recommendation for UsedPlus:**
- Bridge #1 (Unified Health Score) should use `if rvbInstalled then ... elseif amInstalled then ...` NOT both
- Bridge #3 (Consistent Generation) should generate for whichever is installed, not both
- **Note:** OBD Scanner AM Section was removed - UsedPlus v2.7.0 IS the complete AM replacement

---

## Open Questions

1. **Weight Tuning:** The health score weights (RVB 40%, UYT 15%, AM 20%, UP 25%) are estimates. Need playtesting to balance.

---

## Notes

- All bridges are OPTIONAL - only activate if the relevant mods are installed
- Each bridge respects the existing integration settings (can be disabled)
- UsedPlus acts as HUB, not replacement - we read from other mods, don't override them

---

## Bridge #7: VehicleExplorer Integration

**Mods Bridged:** VehicleExplorer + UsedPlus

**Concept:** Add financial context to VehicleExplorer's fleet management UI.

### What is VehicleExplorer?

VehicleExplorer is a fleet management UI showing all vehicles in a list with info panels. It provides:
- Custom sorting/ordering of vehicles
- Quick vehicle switching without Tab cycling
- Vehicle status overview (fuel, damage, wear, hours)
- Quick repair from the list

### RVB's Integration Pattern

RVB overrides `VehicleSort.getFillLevel()` to filter battery charge from fill displays:
```lua
if g_modIsLoaded["FS25_VehicleExplorer"] then
    FS25_VehicleExplorer.VehicleSort.getFillLevel = Utils.overwrittenFunction(...)
end
```

### UsedPlus Opportunities

| Feature | Value | Difficulty |
|---------|-------|------------|
| Show loan status badge in vehicle list ("FINANCED") | HIGH | Easy |
| Color-code financed vehicles (gold/orange) | HIGH | Easy |
| Add fleet finance summary to info box | MEDIUM | Easy |
| Show vehicle resale value in info | MEDIUM | Easy |
| Trade-in eligibility indicator | LOW | Medium |

### Implementation Hook Points

- `VehicleSort:getInfoTexts()` - Add UsedPlus data sections
- `VehicleSort:getTextColor()` - Color-code financed vehicles
- `VehicleSort:getFillDisplay()` - Add finance badge to list

### Value: MEDIUM | Complexity: LOW

---

## UsedPlus Malfunctions vs AdvancedMaintenance

**Key Finding:** UsedPlus already has Bridge #6 (Progressive Unreliability) built via its "malfunctions" system. It is MORE sophisticated than AM.

| Aspect | UsedPlus Malfunctions | AdvancedMaintenance |
|--------|----------------------|---------------------|
| **Failure Type** | TEMPORARY (stall → restart after 5 sec) | PERMANENT (blocked until repaired) |
| **Trigger** | Probability: reliability, damage, hours, load, fluids | Simple: damage > 28.57% |
| **Recovery** | 5-second cooldown, player can restart | No recovery - must repair |
| **Speed Governor** | YES - cuts power when overspeed | NO |
| **Overheating** | YES | NO |
| **Misfiring** | YES - brief power cuts | NO |
| **Fluid Integration** | YES - low oil increases chance | NO |
| **RVB Chain** | YES - reads RVB part health | N/A |
| **AM Chain** | YES - chains to AM if installed | N/A |
| **Steering Degradation** | YES - hydraulic wear affects steering | NO |
| **Electrical Cutout** | YES - implements can shut off | NO |

**Conclusion:** UsedPlus malfunctions provide the "progressive unreliability" that AM lacks, plus many additional failure modes. Bridge #6 is effectively ALREADY IMPLEMENTED.

---

## Settings Gap Analysis

Most compatible mods have NO settings UI. UsedPlus could provide a "Mod Settings Hub":

| Mod | Has Settings? | What's Missing |
|-----|---------------|----------------|
| **RVB** | ✅ Full | No individual part toggles (can't disable just battery), no jumper cables |
| **UYT** | ❌ Minimal | Only wear rate (3 presets), no cost multiplier, no feature toggles |
| **AM** | ❌ NONE | Zero settings - damage threshold hardcoded at 28.57% |
| **HP** | ❌ NONE | Interest rates, missed payment limits all hardcoded |
| **BUE** | ❌ NONE | Search fees, condition ranges all hardcoded |
| **ELS** | ✅ Full | Most comprehensive - 7 settings |

### Potential "Settings Hub" Features

UsedPlus could expose settings that other mods don't provide:
- AM damage threshold adjustment
- HP interest rate multiplier
- BUE search fee scaling
- UYT cost multiplier
- RVB individual part toggles (via patching)

---

## Updated Implementation Priority

| Bridge | Value | Complexity | Status | Priority |
|--------|-------|------------|--------|----------|
| #4 Financial Aggregation | MEDIUM | LOW | ✅ DONE | - |
| #6 Progressive Unreliability + Seizure | VERY HIGH | MEDIUM | ✅ **DONE v2.7.0** | - |
| #3 Consistent Generation | HIGH | LOW | ⚠️ PARTIAL | **1st** |
| #1 Unified Health Score | HIGH | MEDIUM | ❌ TODO | **2nd** |
| #7 VehicleExplorer Integration | MEDIUM | LOW | ❌ TODO | 3rd |
| #5 Repair Estimation | MEDIUM | LOW | ❌ TODO | 4th |

---

## Changelog

### 2026-01-17 - Bridges #2 and #8 Removed
- **Bridge #2 (OBD Scanner AM Section) REMOVED** - No longer needed
  - UsedPlus v2.7.0 IS the complete AM replacement
  - No need to display AM data when UsedPlus provides superior functionality
- **Bridge #8 (AutoDrive Integration) REMOVED** - Low ROI
  - Stopping routes on repossession is niche functionality
  - Maintenance burden not worth the limited use case

### 2026-01-17 - v2.7.0 Seizure Escalation System
- **Bridge #6 ENHANCED:** Implemented complete AM replacement
  - Progressive malfunction frequency (quadratic curve)
  - DNA-variable seizure threshold (lemons fail earlier)
  - Three seizure types: Engine, Hydraulics, Electrical
  - OBD Scanner emergency repair for seized components
  - Workshop repair clears all seizures
- UsedPlus now provides SUPERIOR functionality to AdvancedMaintenance
