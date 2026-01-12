# FS25_UsedPlus - Cross-Mod Compatibility Guide

**Last Updated:** 2026-01-11
**Version:** 2.5.1 (Comprehensive Hydraulic Malfunctions + RVB Service Integration)

This document analyzes compatibility between UsedPlus and popular FS25 mods that players commonly run together.

---

## Quick Reference

| Mod | Status | Summary |
|-----|--------|---------|
| **CrudeOilProduction** | COMPATIBLE | Pure production mod, no conflicts |
| **SpecialOffers** | COMPATIBLE | Notification utility, no conflicts |
| **Real Vehicle Breakdowns** | INTEGRATED | UsedPlus provides "symptoms before failure" |
| **Use Up Your Tyres** | DEEPLY INTEGRATED | Quality/DNA affects wear rate, two-way sync, per-wheel display |
| **EnhancedLoanSystem** | INTEGRATED | ELS loans display in Finance Manager with Pay Early support |
| **BuyUsedEquipment** | COMPATIBLE | UsedPlus hides search button when BUE detected |
| **HirePurchasing** | INTEGRATED | HP leases display in Finance Manager |
| **AdvancedMaintenance** | COMPATIBLE | Both maintenance systems work together |
| **Employment** | INTEGRATED | Worker wages included in monthly obligations |

---

## Fully Compatible Mods

### CrudeOilProduction

**Status:** FULLY COMPATIBLE

**What it does:** Adds crude oil extraction and refining production chain (oil wells, refineries, selling stations). Pure XML-defined placeable mod with no Lua scripts.

**Why it works:**
- No game hooks or function overrides
- Adds new placeables that can be financed through UsedPlus
- New vehicles integrate with UsedPlus used market naturally
- Different systems - no overlap

**Synergies:**
- Finance oil infrastructure with UsedPlus loans
- Oil equipment creates income to pay off loans
- Higher upkeep costs create financial pressure (realistic gameplay)

---

### SpecialOffers

**Status:** FULLY COMPATIBLE

**What it does:** Notification utility that alerts players when new vehicles appear in the shop sale system.

**Why it works:**
- Read-only access to shop data
- No function hooks or overrides
- Only subscribes to `HOUR_CHANGED` event (safe - multiple subscribers allowed)
- Creates only its own `SpecialOffers.*` namespace

**Synergies:**
- Get notified when new used vehicles appear
- Then finance them through UsedPlus

---

## Integrated Mods (Enhanced Cooperation)

### Real Vehicle Breakdowns (RVB)
**Author:** MathiasHun

**Status:** INTEGRATED (v2.1.0+)

**What it does:** Comprehensive vehicle breakdown simulation tracking 10+ parts with operating hours and failure states.

**How UsedPlus integrates:**
- **"Symptoms Before Failure"** - UsedPlus provides gradual degradation symptoms (speed limiting, stalling, steering pull) that warn players BEFORE RVB triggers catastrophic failure
- **Reliability Derivation** - UsedPlus reads RVB part health to calculate symptom severity
- **OBD Repair Integration** - Field Service Kit successful diagnoses reduce RVB operating hours
- **Unique Features Preserved** - Hydraulic drift and steering pull remain unique to UsedPlus (RVB doesn't track hydraulics)

**v2.1.0 Workshop Dialog Integration:**
- **Unified Workshop Experience** - When RVB is installed, UsedPlus hides its own Inspect button from the vanilla workshop screen (RVB replaces it with their Workshop button)
- **Data Injection** - UsedPlus injects its unique data into RVB's Workshop Dialog left pane, appearing seamlessly alongside RVB's vehicle info
- **Displayed in RVB Dialog:**
  - "— UsedPlus —" section divider
  - Hydraulic System: XX% (unique to UsedPlus - RVB doesn't track hydraulics)
  - Maintenance Grade: Excellent/Good/Fair/Poor/Critical
  - Service History: X repairs, Y breakdowns (if notable)
- **Visual Consistency** - Uses RVB's row templates for matching fonts, colors, and alternating row backgrounds

**v2.0.0 OBD Scanner Enhancement:**
- **Activation Prompt** - When OBD Scanner is near a vehicle with RVB issues, prompt shows "Use OBD Scanner - Tractor (RVB)" to indicate external mod problems detected
- **Part Status Display** - OBD Scanner dialog shows individual RVB part statuses:
  - Engine, Thermostat (engine system)
  - Generator, Battery, Starter, Glow Plug (electrical system)
- **Fault Indicators** - Parts showing "FAULT" (red) or "!" prefault warning (orange)
- **Fault Counter** - Shows total number of active faults across all RVB parts

**v2.1.0 Holistic Used Vehicle Inspection:**
- **Pre-Generated Part Data** - When UsedPlus agent finds a used vehicle, RVB-compatible part data is generated:
  - Engine, Thermostat, Generator, Battery, Starter, Glow Plug
  - Each part has a "life" percentage based on vehicle's overall condition with realistic variance
  - Higher quality tier searches produce vehicles with better part conditions
- **Inspection Report Display** - InspectionReportDialog shows "COMPONENT STATUS" section when RVB data exists:
  - 6 parts displayed in 3 columns (Engine/Thermo, Gen/Battery, Starter/Glow)
  - Color-coded: green (>75%) → yellow (>50%) → orange (>30%) → red (critical)
- **Purchase Initialization** - When player buys the used vehicle:
  - RVB's `spec_faultData.parts` operating hours are set to match generated life percentages
  - This ensures the inspection report accurately reflects the vehicle's RVB state after purchase
- **Backwards Compatible** - Old saves without RVB data simply don't show the section
- **Deferred Sync** - If player buys used vehicle WITHOUT RVB, then later installs RVB:
  - RVB parts data is stored on the vehicle's `spec_usedPlusMaintenance`
  - On next vehicle load after RVB installation, data is automatically synced
  - Prevents mismatch between UsedPlus showing "Engine 72%" while RVB shows "Engine 100%"

**v2.5.1 Service Button Integration:**
When player uses RVB's "Service" button in the Workshop Dialog:
- RVB's original service runs (resets RVB part wear)
- **UsedPlus fluids topped up** - Oil and hydraulic fluid restored to 100%
- **Minor leaks fixed** - Oil/hydraulic leak states cleared
- **Small reliability boost** - +3% hydraulic, +1.5% engine reliability (capped at durability ceiling)

This ensures routine maintenance through RVB also maintains the hydraulic system, preventing the gap where engine/electrical get serviced but hydraulics don't.

**What happens with both installed:**
| Feature | Who Handles It |
|---------|---------------|
| Progressive speed limiting | UsedPlus (uses RVB engine health) |
| First-start stalling | UsedPlus (uses RVB engine health) |
| Hydraulic drift | UsedPlus only (unique feature) |
| Steering pull | UsedPlus only (unique feature) |
| **Runaway Engine** | **UsedPlus (v2.5.0 - requires low oil + hydraulic)** |
| **Implement Stuck/Pull/Drag** | **UsedPlus (v2.5.0)** |
| Final engine failure | RVB (7 km/h cap when part exhausted) |
| Final electrical failure | RVB (lights/starter fail) |
| Flat tire trigger | RVB (via UYT integration) |
| Workshop Inspect button | RVB (UsedPlus hides its button) |
| **RVB Service button** | **RVB + UsedPlus fluids (v2.5.1)** |
| **RVB Repair button** | **Opens UsedPlus RepairDialog** |
| **RVB Workshop vehicle info** | **UsedPlus injects (v2.1.0+)** |
| **OBD Part Detail Display** | **UsedPlus (v2.0.0+)** |
| **OBD Fault Warnings** | **UsedPlus (v2.0.0+)** |

---

### Use Up Your Tyres (UYT)
**Author:** 50keda

**Status:** DEEPLY INTEGRATED (v2.3.0)

**What it does:** Distance-based tire wear system with visual progression and friction reduction.

**v2.3.0 Deep Integration (NEW!):**
- **Two-Way Sync** - UsedPlus now syncs BACK to UYT when tires are replaced
  - TiresDialog replacement resets UYT's distance tracking
  - No more desync between UsedPlus and UYT tire states
- **Quality Affects UYT Wear Rate** - UsedPlus tire quality tiers modify UYT wear:

  | Tier | Cost | Traction | Wear Rate | Initial State | Effective Life |
  |------|------|----------|-----------|---------------|----------------|
  | Retread | 40% | 85% | 2x faster | +35% worn | ~32% of Normal |
  | Normal | 100% | 100% | 1x | Fresh | 100% baseline |
  | Quality | 150% | 110% | 0.67x | -15% bonus | ~172% of Normal |

  *5x life difference between cheapest and best options!*
- **DNA Affects UYT Wear Rate** - Vehicle DNA influences tire wear:
  - Lemons (low DNA): 1.4x wear rate (harder on tires)
  - Workhorses (high DNA): 0.6x wear rate (gentler driving)
- **UYT Wear Influences Flat Probability** - Higher UYT wear increases flat tire chance:
  - 0% UYT wear: 1x flat chance (baseline)
  - 100% UYT wear: 3x flat chance (worn tires more likely to fail)
  - Note: UYT itself has no flat tires - UsedPlus adds this as a complementary feature
- **Per-Wheel Display in TiresDialog** - When UYT installed:
  - Shows FL/FR/RL/RR individual conditions
  - "Worst" tire indicator
  - Condition label changes to "Tire Wear (UYT):"

**How UsedPlus integrates:**
- **Tire Condition Sync** - UsedPlus reads UYT wear data to update tire condition displays
- **Flat Tire Enhancement** - UsedPlus uses UYT wear to influence flat probability (complementary to UYT)
- **Low Traction Warnings** - UsedPlus still shows traction warnings based on synced condition

**v2.0.0 OBD Scanner Enhancement:**
- **Activation Prompt** - When OBD Scanner is near a vehicle with >80% tire wear, prompt shows "Use OBD Scanner - Tractor (Tires)" to warn of worn tires
- **Tire Wear Display** - OBD Scanner dialog shows individual wheel conditions:
  - FL (Front Left), FR (Front Right), RL (Rear Left), RR (Rear Right)
  - "Worst" indicator showing the most worn tire
- **Color-Coded Wear** - Green (good) → Yellow → Orange → Red (critical)

**v2.1.0 Holistic Used Vehicle Inspection:**
- **Pre-Generated Tire Data** - When UsedPlus agent finds a used vehicle, UYT-compatible tire conditions are generated:
  - FL (Front Left), FR (Front Right), RL (Rear Left), RR (Rear Right)
  - Front tires generated with higher wear bias (simulate steering wear)
  - Per-tire variance creates realistic non-uniform wear patterns
- **Inspection Report Display** - InspectionReportDialog shows "TIRE CONDITION" section when tire data exists:
  - 4 tires displayed in a row with individual percentages
  - "Worst" indicator highlights the tire needing attention
  - Color-coded: green (>75%) → yellow (>50%) → orange (>30%) → red (critical)
- **Purchase Initialization** - When player buys the used vehicle:
  - UYT wheel wear is set to match generated conditions (if UYT API available)
  - UsedPlus native tire tracking is also initialized
- **Backwards Compatible** - Old saves without tire data simply don't show the section
- **Deferred Sync** - If player buys used vehicle WITHOUT UYT, then later installs UYT:
  - Tire data is stored on the vehicle's `spec_usedPlusMaintenance`
  - On next vehicle load after UYT installation, data is automatically synced
  - Prevents mismatch between UsedPlus showing "FL: 65%" while UYT shows "FL: 100%"

**What happens with both installed:**
| Feature | Who Handles It |
|---------|---------------|
| Tire wear calculation | Both: UYT (distance) + UsedPlus (quality/DNA multipliers) |
| Visual tire degradation | UYT (shader-based) |
| Tire condition display | UsedPlus (synced from UYT) |
| Flat tire trigger | UsedPlus (UYT doesn't have flats) |
| Low traction warning | UsedPlus |
| Tire replacement (shop) | UYT (workshop button) |
| Tire replacement (UsedPlus) | UsedPlus (syncs to UYT) |
| **TiresDialog per-wheel display** | **UsedPlus (v2.3.0+)** |
| **Quality wear multiplier** | **UsedPlus (v2.3.0+)** |
| **DNA wear multiplier** | **UsedPlus (v2.3.0+)** |
| **OBD Tire Detail Display** | **UsedPlus (v2.0.0+)** |
| **OBD Worst Tire Indicator** | **UsedPlus (v2.0.0+)** |

---

## Compatible Mods (Feature Deferral)

These mods were previously marked as "conflicting" but are now **fully compatible** as of v1.8.1. UsedPlus automatically detects them and defers specific features to avoid conflicts.

### EnhancedLoanSystem (ELS)

**Status:** INTEGRATED (v1.8.2+)

**What it does:** Replaces vanilla loan system with annuity-based loans featuring collateral requirements, variable interest rates, and monthly payments.

**How UsedPlus integrates:**
- **Detection:** `g_els_loanManager ~= nil`
- **Finance Manager Display** - ELS loans appear in the Active Finances table with "ELS" type marker
- **Pay Early Button** - Make payments on ELS loans directly from UsedPlus Finance Manager
- **Monthly Totals** - ELS loan payments included in monthly obligations display
- **Debt Totals** - ELS loan balances included in total debt calculation
- **Take Loan button** - Hidden (ELS handles loan creation)
- **Cash loan creation** - Blocked (ELS handles all loans)

**What happens with both installed:**
| Feature | Who Handles It |
|---------|---------------|
| Cash loans (creation) | ELS |
| Loan display in Finance Manager | UsedPlus (reads ELS data) |
| Loan payments via Pay Early | UsedPlus (calls ELS API) |
| Vehicle financing | UsedPlus |
| Vehicle leasing | UsedPlus |
| Used vehicle search | UsedPlus |
| Agent-based sales | UsedPlus |
| Maintenance & symptoms | UsedPlus |
| Credit scoring | Both (independent) |

**Unified Financial View:**
Players see ALL their financial obligations in one place - UsedPlus deals AND ELS loans together in the Finance Manager.

---

### BuyUsedEquipment (BUE)

**Status:** COMPATIBLE (v1.8.1+)

**What it does:** Broker-based used equipment search where players pay a fee, wait for success rolls, and find vehicles in the vanilla shop's Sales tab.

**How UsedPlus handles compatibility:**
- **Detection:** `BuyUsedEquipment ~= nil`
- **Search Used button** - Hidden from shop when BUE detected
- **UsedVehicleManager** - Still initializes (for agent-based selling)
- **Financing** - Still works for all purchases including BUE finds
- **Agent-based sales** - Still works (selling your equipment)

**What happens with both installed:**
| Feature | Who Handles It |
|---------|---------------|
| Used vehicle search | BUE |
| Search button in shop | BUE |
| Vehicle financing | UsedPlus |
| Vehicle leasing | UsedPlus |
| Agent-based sales | UsedPlus |
| Maintenance & symptoms | UsedPlus |

---

### HirePurchasing (HP)

**Status:** INTEGRATED (v1.8.2+)

**What it does:** Hire purchase financing with deposit requirements, 1-10 year terms, and optional balloon payments.

**How UsedPlus integrates:**
- **Detection:** `g_currentMission.LeasingOptions ~= nil`
- **Finance Manager Display** - HP leases appear in the Active Finances table with "HP" type marker
- **Info Dialog** - Click Pay Early on HP leases to see details (HP manages payments automatically)
- **Monthly Totals** - HP lease payments included in monthly obligations display
- **Debt Totals** - HP lease balances included in total debt calculation
- **Finance button** - Hidden from shop (HP handles financing)

**What happens with both installed:**
| Feature | Who Handles It |
|---------|---------------|
| Vehicle financing (hire purchase) | HP |
| Finance button in shop | HP |
| Lease display in Finance Manager | UsedPlus (reads HP data) |
| Automatic lease payments | HP (hourly processing) |
| Vehicle leasing | UsedPlus |
| Used vehicle search | UsedPlus |
| Agent-based sales | UsedPlus |
| Maintenance & symptoms | UsedPlus |

**Note:** HP manages lease payments automatically each hour. UsedPlus displays HP leases for visibility but doesn't process HP payments directly.

---

### AdvancedMaintenance (AM)

**Status:** COMPATIBLE (v1.8.1+)

**What it does:** Prevents engine start at 0% damage and causes random shutdowns when damage exceeds 28%.

**How UsedPlus handles compatibility:**
- **Detection:** Specialization registry check + `AdvancedMaintenance ~= nil`
- **Function chaining** - UsedPlus calls AM's damage check in `getCanMotorRun` chain
- **Both systems active** - UsedPlus symptoms + AM damage-based failures

**What happens with both installed:**
| Feature | Who Handles It |
|---------|---------------|
| Progressive speed limiting | UsedPlus (reliability-based) |
| First-start stalling | UsedPlus (reliability-based) |
| Hydraulic drift | UsedPlus |
| Steering pull | UsedPlus |
| Engine block at 0% damage | AM |
| Random shutdown >28% damage | AM |
| Overheating symptoms | UsedPlus |
| Electrical symptoms | UsedPlus |

**The best of both worlds:**
- UsedPlus provides gradual symptoms as components degrade
- AM provides damage-based catastrophic failures
- Together: realistic progression from "engine struggling" to "engine won't start"

---

### Employment

**Status:** INTEGRATED (v1.8.2+)

**What it does:** Adds worker hiring system with wages and productivity bonuses.

**How UsedPlus integrates:**
- **Detection:** `g_currentMission.employmentSystem ~= nil`
- **Monthly Totals** - Worker wages automatically included in monthly obligations
- **Visual Indicator** - Asterisk (*) shown on monthly total when wages are included
- **Budget Planning** - See true monthly costs including labor

**What happens with both installed:**
| Feature | Who Handles It |
|---------|---------------|
| Worker hiring/management | Employment |
| Wage payments | Employment |
| Wage display in monthly total | UsedPlus |
| Budget visibility | UsedPlus Finance Manager |

**Financial Clarity:**
When Employment mod is installed, your monthly obligations in Finance Manager include:
- Loan payments (UsedPlus + ELS)
- Lease payments (UsedPlus + HP)
- Worker wages (Employment)

This gives you a complete picture of your farm's monthly cash requirements.

---

## Technical Details

### Detection Methods Used by UsedPlus

```lua
-- Integrated mods
ModCompatibility.rvbInstalled = g_currentMission.vehicleBreakdowns ~= nil
ModCompatibility.uytInstalled = UseYourTyres ~= nil

-- Compatible mods (feature deferral)
ModCompatibility.advancedMaintenanceInstalled = AdvancedMaintenance ~= nil
ModCompatibility.hirePurchasingInstalled = g_currentMission.LeasingOptions ~= nil
ModCompatibility.buyUsedEquipmentInstalled = BuyUsedEquipment ~= nil
ModCompatibility.enhancedLoanSystemInstalled = g_els_loanManager ~= nil
```

### Feature Availability Queries

```lua
-- Check if UsedPlus should show its buttons/features
ModCompatibility.shouldShowFinanceButton()    -- false if HP detected
ModCompatibility.shouldShowSearchButton()     -- false if BUE detected
ModCompatibility.shouldShowTakeLoanOption()   -- false if ELS detected
ModCompatibility.shouldEnableLoanSystem()     -- false if ELS detected
```

### Data Access Functions (v1.8.2+)

```lua
-- ELS Integration
ModCompatibility.getELSLoans(farmId)          -- Returns pseudo-deal array for display
ModCompatibility.payELSLoan(pseudoDeal, amt)  -- Make payment via ELS API

-- HP Integration
ModCompatibility.getHPLeases(farmId)          -- Returns pseudo-deal array for display
ModCompatibility.payHPLease(pseudoDeal, amt)  -- Attempt payment (HP manages automatically)
ModCompatibility.settleHPLease(pseudoDeal)    -- Early settlement

-- Employment Integration
ModCompatibility.getEmploymentMonthlyCost(playerId)  -- Worker wages per month

-- Farmland Integration
ModCompatibility.getFarmlandValue(farmId)     -- Total value of owned farmland
ModCompatibility.getFarmlandCount(farmId)     -- Number of owned fields

-- Aggregate Functions
ModCompatibility.getExternalMonthlyObligations(farmId)  -- ELS + HP monthly total
ModCompatibility.getExternalTotalDebt(farmId)           -- ELS + HP debt total
```

### Key UsedPlus Hooks

| Function | Hook Type | Purpose |
|----------|-----------|---------|
| `Farm.new` | overwrittenFunction | Finance data initialization |
| `Farm.saveToXMLFile` | appendedFunction | Persist finance deals |
| `Farm.loadFromXMLFile` | overwrittenFunction | Load finance deals |
| `ShopConfigScreen.setStoreItem` | appendedFunction | Add Finance/Search buttons |
| `BuyVehicleData.buy` | overwrittenFunction | Intercept purchases |
| `Vehicle.showInfo` | appendedFunction | Display finance info |
| `getCanMotorRun` | registerOverwrittenFunction | Engine stall/governor (chains to AM) |

---

## Recommendations for Players

### Best Experience (Recommended Setup)
- **UsedPlus** (financial system, maintenance, marketplace)
- **Real Vehicle Breakdowns** (catastrophic failures)
- **Use Up Your Tyres** (visual tire wear)
- **Employment** (worker management with wages in Finance Manager)
- **CrudeOilProduction** (production chain)
- **SpecialOffers** (shop notifications)

### All Mods Now Compatible
As of v1.8.2, UsedPlus is **deeply integrated** with popular financial/maintenance mods:
- **EnhancedLoanSystem** - Loans display in Finance Manager, Pay Early works
- **HirePurchasing** - Leases display in Finance Manager for unified view
- **Employment** - Worker wages included in monthly obligations
- **BuyUsedEquipment** - Use BUE for search, UsedPlus for financing/sales
- **AdvancedMaintenance** - Both maintenance systems work together

### Mix and Match
You can now run any combination:
- UsedPlus + ELS + HP + Employment = **Unified Financial Dashboard**
- See ALL your obligations in one place: loans, leases, financing, wages
- Each mod handles its specialty, UsedPlus provides the unified view

---

## Version History

**2026-01-11 (v2.3.0)** - UYT Deep Integration
- NEW: Two-way sync - UsedPlus tire replacement now resets UYT distance tracking
- NEW: Quality tiers affect UYT wear rate (Retread 2x faster, Quality 33% slower)
- NEW: Retreads start at 35% wear (reconditioned casings have pre-existing wear)
- NEW: Quality tires get 15% bonus life (premium materials start fresh with extra capacity)
- NEW: DNA affects tire wear rate (Lemons 40% faster, Workhorses 40% slower)
- NEW: UYT wear influences flat tire probability (1x-3x based on worst tire wear)
- NEW: TiresDialog shows per-wheel conditions when UYT installed (FL/FR/RL/RR)
- NEW: TiresDialog shows "Worst" tire indicator
- UYT status upgraded from INTEGRATED to DEEPLY INTEGRATED
- Added `syncTireReplacementWithUYT()`, `applyInitialUYTWear()`, and `getWorstUYTTireWear()` functions

**2026-01-10 (v2.1.0)** - RVB Workshop & Holistic Inspection Integration
- NEW: UsedPlus data now appears in RVB's Workshop Dialog
- Injects Hydraulic System status, Maintenance Grade, and Service History into RVB's left pane
- Hides UsedPlus Inspect button when RVB installed (RVB Workshop button replaces it)
- Uses RVB's row templates for seamless visual integration
- Added l10n strings for maintenance grades (Excellent/Good/Fair/Poor/Critical)
- NEW: **Holistic Used Vehicle Inspection**
  - Used vehicle searches now generate RVB-compatible part data (Engine, Thermostat, Generator, Battery, Starter, Glow Plug)
  - Used vehicle searches now generate UYT-compatible tire conditions (FL, FR, RL, RR)
  - InspectionReportDialog displays "COMPONENT STATUS" section with individual part life percentages
  - InspectionReportDialog displays "TIRE CONDITION" section with per-wheel conditions
  - When purchasing used vehicles, RVB operating hours and UYT tire wear are initialized from inspection data
  - Color-coded part/tire conditions: green (good) → yellow → orange → red (critical)
  - Sections only appear when data exists (backwards compatible with old saves)

**2026-01-05 (v2.0.0)** - OBD Scanner Enhancement
- OBD Scanner now detects RVB part issues in activation prompt
- OBD Scanner now detects UYT tire wear (>80%) in activation prompt
- OBD Scanner dialog shows detailed RVB part status section:
  - Engine, Thermostat, Generator, Battery, Starter, Glow Plug
  - Color-coded life percentages (green/yellow/orange/red)
  - FAULT and prefault (!) indicators
  - Total fault counter
- OBD Scanner dialog shows UYT tire breakdown:
  - Per-wheel condition (FL, FR, RL, RR)
  - Worst tire indicator
- Activation text now shows specific warnings: "Use OBD Scanner - Tractor (RVB, Tires)"

**2025-12-28 (v1.8.2)** - Deep Integration
- ELS loans now display in Finance Manager with "ELS" type marker
- HP leases now display in Finance Manager with "HP" type marker
- Pay Early button works with ELS loans (calls ELS payment API)
- Employment wages included in monthly obligations total
- Farmland count shown in assets display
- Added data access functions for cross-mod integration
- Updated ELS/HP status from COMPATIBLE to INTEGRATED

**2025-12-28 (v1.8.1)** - Extended compatibility
- All previously conflicting mods now COMPATIBLE
- Added automatic mod detection via ModCompatibility.init()
- Added feature deferral for ELS, BUE, HP, AM
- Added function chaining for AM's getCanMotorRun
- Updated quick reference table

**2025-12-28 (v1.8.0)** - Initial compatibility documentation
- Analyzed 6 popular mods for conflicts
- Documented RVB/UYT integration
- Created quick reference table
