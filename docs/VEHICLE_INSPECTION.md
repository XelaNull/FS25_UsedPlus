# Vehicle Inspection & Maintenance System

**Version:** 1.4.0
**Last Updated:** 2025-12-27
**Purpose:** Document the hidden reliability system, inspection reports, and in-game consequences for used vehicles

**Related Documents:**
- [Workhorse/Lemon Scale](WORKHORSE_LEMON_SCALE.md) - Hidden vehicle DNA and inspector quotes
- [Economics](ECONOMICS.md) - Buy/sell pricing model

---

## Table of Contents

1. [Design Philosophy](#design-philosophy)
2. [Component Systems](#component-systems)
3. [Reliability Scores](#reliability-scores)
4. [In-Game Effects](#in-game-effects)
5. [Inspection System](#inspection-system)
6. [Repair & Recovery](#repair--recovery)
7. [Complete Flow Example](#complete-flow-example)
8. [Configuration Options](#configuration-options)
9. [Implementation Details](#implementation-details)

---

## Design Philosophy

### Why Hidden Reliability?

Vanilla FS25 has a simple damage system - vehicles take damage, you repair them, they're good as new. This creates a situation where buying used has **no meaningful consequences** after repair.

UsedPlus adds **hidden reliability scores** that persist even after repairs. This creates:

1. **Meaningful Risk**: A cheap used vehicle might have underlying issues that cause problems during operation
2. **Informed Decisions**: Players can pay for inspections to reveal hidden problems
3. **Ongoing Consequences**: Used vehicles are never quite as reliable as new ones
4. **Gameplay Depth**: Breakdowns, stalls, and malfunctions add tension and realism

### The Core Principle

**Damage is visible. Reliability is hidden.**

| Aspect | Visible? | Repairable? | Fully Restorable? |
|--------|----------|-------------|-------------------|
| Damage | Yes | Yes (shop) | Yes (100%) |
| Wear/Paint | Yes | Yes (shop) | Yes (100%) |
| Engine Reliability | **No** | Improved by repair | **No** (dynamic ceiling*) |
| Hydraulic Reliability | **No** | Improved by repair | **No** (dynamic ceiling*) |
| Electrical Reliability | **No** | Improved by repair | **No** (dynamic ceiling*) |

*\*See [Workhorse/Lemon Scale](WORKHORSE_LEMON_SCALE.md) - the reliability ceiling degrades over repairs based on hidden vehicle "DNA"*

---

## Component Systems

UsedPlus tracks THREE independent reliability systems, each affecting different aspects of vehicle operation:

### 1. Engine System

**What it represents:**
- Internal engine components (pistons, bearings, seals)
- Fuel system (injectors, pump, lines)
- Cooling system (radiator, water pump, thermostat)
- General mechanical condition

**What degrades it:**
- Operating hours under load
- Initial condition when purchased used
- Never fully restored by repairs

### 2. Hydraulic System

**What it represents:**
- Hydraulic pump condition
- Cylinder seals and integrity
- Valve body wear
- Hydraulic fluid quality

**What degrades it:**
- Heavy implement use
- Lifting/lowering cycles
- Initial condition when purchased used

### 3. Electrical System

**What it represents:**
- Wiring harness condition
- Alternator output
- Sensor reliability
- ECU/computer systems

**What degrades it:**
- Age and corrosion
- Water exposure (in lore)
- Initial condition when purchased used

---

## Reliability Scores

### Score Range

Each component has a reliability score from **0.0 to 1.0**:

| Score | Rating | Description |
|-------|--------|-------------|
| 0.90-1.00 | Excellent | Like new, minimal issues expected |
| 0.70-0.89 | Good | Occasional minor issues possible |
| 0.50-0.69 | Acceptable | Noticeable problems under stress |
| 0.30-0.49 | Below Average | Frequent issues, expect breakdowns |
| 0.10-0.29 | Poor | Major problems, unreliable |
| 0.00-0.09 | Critical | Barely functional, constant failures |

### How Scores Are Generated

When a used vehicle is created for sale, reliability scores are generated based on:

```lua
-- Base reliability inversely related to damage
reliabilityBase = 1 - damage

-- Add random variance per component
engineReliability = reliabilityBase + random(-0.2, +0.2)
hydraulicReliability = reliabilityBase + random(-0.25, +0.25)
electricalReliability = reliabilityBase + random(-0.15, +0.15)

-- Clamp to valid range (0.1 to 1.0)
-- Note: Even worst case is never 0 (would be unusable)
-- Note: Used vehicles are never 1.0 (always some history)
```

### Example: 60% Damage Vehicle

| Component | Base | Variance | Possible Range |
|-----------|------|----------|----------------|
| Engine | 0.40 | ±0.20 | 0.20 - 0.60 |
| Hydraulic | 0.40 | ±0.25 | 0.15 - 0.65 |
| Electrical | 0.40 | ±0.15 | 0.25 - 0.55 |

This means a heavily damaged vehicle could have:
- A surprisingly good engine (0.60) - "previous owner took care of the motor"
- A terrible hydraulic system (0.15) - "but they ran the loader constantly"
- A mediocre electrical (0.40) - "wiring is showing its age"

**This variance is the CORE VALUE of the inspection system** - you don't know which components are good or bad until you pay to find out!

---

## In-Game Effects

### Engine Effects

#### 1. Engine Stalling

**What happens:** Engine randomly shuts off during operation

**Trigger conditions:**
- Engine reliability below 100% (always some base chance)
- Amplified by current damage level
- Amplified by high engine load
- Amplified by operating hours

**Probability formula:**
```lua
-- Base chance from reliability (exponential curve)
reliabilityFactor = (1 - engineReliability)^2
baseChance = 0.00001 + (reliabilityFactor * 0.0002)

-- Damage amplifies (0% = 1x, 100% = 5x)
damageMultiplier = 1.0 + (damage * 4.0)

-- Hours increase risk slightly (caps at +50%)
hoursMultiplier = 1.0 + min(hours / 20000, 0.5)

-- High load + damage = risky
loadMultiplier = 1.0 + (load * damage * 2.0)

-- Combined (capped at 2% per second max)
stallChance = baseChance * damageMultiplier * hoursMultiplier * loadMultiplier
```

**Practical examples (per 1-second check):**

| Engine Rel. | Damage | Load | Stall Chance |
|-------------|--------|------|--------------|
| 100% | 0% | 50% | ~0.001% |
| 80% | 0% | 50% | ~0.002% |
| 50% | 0% | 50% | ~0.006% |
| 50% | 30% | 80% | ~0.03% |
| 30% | 50% | 100% | ~0.12% |

**Consequences when stall occurs:**
1. Engine stops immediately
2. Player sees warning: "Engine stalled!"
3. 30-second cooldown before next possible stall
4. AI workers are stopped with "Vehicle Broken" error
5. Failure count is incremented (affects resale)

#### 2. Speed Degradation

**What happens:** Maximum speed is reduced based on damage + reliability

**Trigger conditions:**
- Damage above 20% threshold
- Always active when threshold met

**Formula:**
```lua
-- Speed reduction from damage (up to 50%)
speedFactor = 1 - (damage * 0.5)

-- Reliability modifies further (30% contribution)
reliabilityFactor = 0.7 + (engineReliability * 0.3)

-- Combined (never below 30% speed)
finalSpeed = originalMax * speedFactor * reliabilityFactor
finalSpeed = max(finalSpeed, originalMax * 0.3)
```

**Practical examples:**

| Damage | Engine Rel. | Speed Reduction |
|--------|-------------|-----------------|
| 0% | 100% | None |
| 20% | 100% | ~10% slower |
| 50% | 80% | ~32% slower |
| 80% | 50% | ~52% slower |
| 100% | 30% | 70% slower (capped) |

### Hydraulic Effects

#### 3. Hydraulic Drift

**What happens:** Raised implements slowly lower on their own

**Trigger conditions:**
- Hydraulic reliability below 50%
- Implements must be raised above midpoint
- Player not actively moving the implement

**Behavior:**
```lua
-- Base drift speed: 0.001 radians per second
-- Modified by reliability deficit
reliabilityFactor = 1 - hydraulicReliability

-- Damage amplifies drift (up to 3x)
damageMultiplier = 1.0 + (damage * 2.0)

-- Combined drift speed
driftSpeed = 0.001 * reliabilityFactor * damageMultiplier
```

**Practical impact:**
- At 40% hydraulic reliability + 0% damage: Loader bucket slowly lowers over ~60 seconds
- At 30% hydraulic reliability + 50% damage: Loader bucket lowers in ~20 seconds
- At 20% hydraulic reliability + 80% damage: Loader bucket lowers in ~10 seconds

**Player experience:**
- "My loader keeps dropping!"
- Need to re-raise implements periodically
- Can't leave implements raised unattended
- Creates urgency to repair hydraulic system

### Electrical Effects

#### 4. Implement Cutout

**What happens:** Attached implements randomly shut off

**Trigger conditions:**
- Checked every 5 seconds
- Probability based on electrical reliability
- Amplified by damage

**Probability formula:**
```lua
-- Base chance: 3% per check
baseChance = 0.03

-- Reliability factor (exponential)
reliabilityFactor = (1 - electricalReliability)^2

-- Damage amplifies (up to 4x)
damageMultiplier = 1.0 + (damage * 3.0)

-- Combined
cutoutChance = baseChance * reliabilityFactor * damageMultiplier
```

**Practical examples (per 5-second check):**

| Elec. Rel. | Damage | Cutout Chance |
|------------|--------|---------------|
| 100% | 0% | 0% |
| 70% | 0% | ~0.3% |
| 50% | 0% | ~0.75% |
| 50% | 30% | ~1.4% |
| 30% | 50% | ~4.3% |

**Consequences when cutout occurs:**
1. All attached implements stop working
2. Implements raise/turn off automatically
3. Player sees warning: "Electrical fault - implements offline!"
4. Cutout lasts 3 seconds, then auto-recovers
5. AI workers are stopped

---

## Inspection System

### Overview

Before purchasing a used vehicle, players can pay for a professional inspection to reveal the hidden reliability scores.

### Inspection Cost

```lua
inspectionCost = $200 base + (1% of vehicle price)
-- Capped at $2,000 maximum
```

**Examples:**

| Vehicle Price | Inspection Cost |
|---------------|-----------------|
| $10,000 | $300 |
| $50,000 | $700 |
| $100,000 | $1,200 |
| $250,000 | $2,000 (cap) |

### Inspection Report Contents

The inspection report reveals:

1. **Component Ratings**
   - Engine: XX% (Rating: Good/Fair/Poor)
   - Hydraulic: XX% (Rating: Good/Fair/Poor)
   - Electrical: XX% (Rating: Good/Fair/Poor)

2. **Overall Condition**
   - Average of all three components
   - Color-coded (green/gold/red)

3. **Estimated Repair Cost**
   - Based on reliability deficit
   - Formula: `basePrice * (1 - avgReliability) * 0.15`

4. **Inspector Notes**
   - Text warnings based on low scores:
   - Engine < 50%: "Engine shows signs of hard use. Expect occasional stalling under load."
   - Hydraulic < 50%: "Hydraulic system worn. Implements may drift when raised."
   - Electrical < 50%: "Electrical issues detected. Implements may cut out unexpectedly."

5. **Recommendation**
   - 75%+: "Excellent condition - highly recommended"
   - 60-74%: "Good condition - recommended"
   - 45-59%: "Fair condition - proceed with caution"
   - <45%: "Poor condition - significant issues expected"

6. **Mechanic's Assessment** *(NEW - v1.4.0)*
   - A colorful quote from the mechanic hinting at the vehicle's hidden "DNA"
   - Reveals the [Workhorse/Lemon Scale](WORKHORSE_LEMON_SCALE.md) without showing exact numbers
   - Examples:
     - Lemon: *"I'd keep my receipt handy if I were you."*
     - Average: *"About what you'd expect from the factory."*
     - Workhorse: *"In 30 years, I've seen maybe a dozen this well built."*
   - See [Inspector Quote System](WORKHORSE_LEMON_SCALE.md#inspector-quote-system) for full quote library

### Inspection Cache

To prevent players from repeatedly paying for inspections on the same vehicle:

- Inspection results are cached on the vehicle
- Cache is valid as long as:
  - Hours haven't increased by more than 10
  - Damage hasn't changed by more than 5%
  - Wear hasn't changed by more than 5%
- Major repairs invalidate the cache (forcing re-inspection to see improvement)

---

## Repair & Recovery

### How Repairs Affect Reliability

When a vehicle is repaired at the shop:

1. **Damage is fully restored** (visible damage goes to 0%)
2. **Reliability is improved but NOT fully restored**
3. **The reliability ceiling degrades** based on the vehicle's hidden [Workhorse/Lemon Scale](WORKHORSE_LEMON_SCALE.md)

```lua
repairBonus = 0.15  -- Each repair adds 15% to reliability

-- NEW: Dynamic ceiling based on vehicle DNA
-- Workhorse (scale=1.0): ceiling stays at 100%
-- Lemon (scale=0.0): ceiling drops 1% per repair
ceilingDegradation = (1 - workhorseLemonScale) * 0.01
maxReliabilityCeiling = maxReliabilityCeiling - ceilingDegradation

-- After repair (capped by dynamic ceiling):
engineReliability = min(maxReliabilityCeiling, engineReliability + 0.15)
hydraulicReliability = min(maxReliabilityCeiling, hydraulicReliability + 0.15)
electricalReliability = min(maxReliabilityCeiling, electricalReliability + 0.15)
```

### Repair Recovery Examples

**For an AVERAGE vehicle (Workhorse/Lemon Scale = 0.50):**

| Event | Ceiling | Starting Rel. | After Repair |
|-------|---------|---------------|--------------|
| Repair #1 | 99.5% | 30% | 45% |
| Repair #5 | 97.5% | 60% | 75% |
| Repair #10 | 95.0% | 80% | 95% (capped) |
| Repair #20 | 90.0% | 75% | 90% (capped) |

**For a LEMON (Scale = 0.10):**

| Event | Ceiling | Starting Rel. | After Repair |
|-------|---------|---------------|--------------|
| Repair #1 | 99.1% | 30% | 45% |
| Repair #10 | 91.0% | 75% | 90% |
| Repair #20 | 82.0% | 70% | 82% (capped!) |
| Repair #50 | 55.0% | 50% | 55% (capped!) |

**For a WORKHORSE (Scale = 0.95):**

| Event | Ceiling | Starting Rel. | After Repair |
|-------|---------|---------------|--------------|
| Repair #1 | 99.95% | 30% | 45% |
| Repair #20 | 99.0% | 85% | 99% |
| Repair #100 | 95.0% | 90% | 95% |

### Key Insight: The Dynamic Ceiling

**Every vehicle has hidden "DNA" that determines its long-term reliability.**

- **Workhorses** (scale ~1.0): Can repair almost indefinitely, ceiling barely drops
- **Average** (scale ~0.5): Ceiling drops 0.5% per repair, noticeable after 20+ repairs
- **Lemons** (scale ~0.1): Ceiling drops ~0.9% per repair, becomes unrepairable over time

This creates:
- Emergent storytelling ("This tractor just won't die!")
- Meaningful attachment to good vehicles
- Strategic decisions about when to cut losses on lemons

See [Workhorse/Lemon Scale](WORKHORSE_LEMON_SCALE.md) for complete documentation.

---

## Complete Flow Example

### Scenario: Buying a Poor Condition Tractor

**Step 1: Find Vehicle**
- Player searches for a used John Deere 6R 150
- Selects "Poor Condition" quality tier
- Listing shows: $30,000 (70% off $100,000 new) - see [ECONOMICS.md](ECONOMICS.md)
- Visible damage: 70%
- Visible wear: 75%
- Hidden DNA: 0.35 (below average - unknown to player)

**Step 2: Inspect (Optional)**
- Player pays $500 inspection fee ($200 + 1% of $30k)
- Report reveals:
  - Engine: 38% (Below Average) - "Expect stalling under load"
  - Hydraulic: 25% (Poor) - "Implements may drift"
  - Electrical: 50% (Acceptable) - No concerns
  - Overall: 38%
  - Estimated repair cost: $9,300
  - **Mechanic's Quote**: *"She's about as reliable as a screen door on a submarine."*
    - *(Observant players note this is a concerning quote!)*

**Step 3: Purchase Decision**
- Player decides to buy anyway (good price!)
- Total investment so far: $30,000 + $500 = $30,500

**Step 4: Initial Repair**
- Player brings to shop for full repair
- Repair cost: $17,500 (70% damage × 25% × $100k)
- Repaint cost: $11,250 (75% wear × 15% × $100k)
- Total repair: $28,750
- **Ceiling degrades**: 1.0 → 99.35% (DNA 0.35 = 0.65% loss per repair)

**Step 5: Post-Repair State**
- Damage: 0% (fully repaired)
- Wear: 0% (fully repainted)
- Engine: 53% (38% + 15%, capped at 99.35% ceiling)
- Hydraulic: 40% (25% + 15%)
- Electrical: 65% (50% + 15%)

**Step 6: Ongoing Operation**
- Vehicle now operates with these reliability scores
- May still experience:
  - Occasional stalling (engine 53%)
  - Hydraulic drift (hydraulic 40%)
  - Rare cutouts (electrical 65%)

**Step 7: Second Repair (After More Use)**
- **Ceiling degrades**: 99.35% → 98.7%
- New reliability: Engine 68%, Hydraulic 55%, Electrical 80%
- Vehicle improving but ceiling dropping

**Step 8: After 10 Repairs**
- **Ceiling now at 93.5%** (started at 100%, lost 6.5%)
- Reliability scores capped at 93.5% - can never reach original levels
- Player notices vehicle isn't as good as it used to be

**Total Investment (Year 1):**
- Purchase: $30,000
- Inspection: $500
- Initial repairs: $28,750
- **Total Year 1: ~$59,250**

**Long-Term (10 Years, 20 Repairs):**
- Additional repairs: ~$15,000
- Breakdown losses: ~$5,000
- **Total 10-Year TCO: ~$80,000** (vs $100k new)

**Net Savings: ~$20,000** but with:
- Permanent reliability ceiling at ~87%
- Higher breakdown frequency
- Lower resale value (~85% of normal)

*Compare to finding a "Poor + Workhorse" (DNA 0.90) - same initial cost, but ceiling stays at ~98% after 20 repairs = much better long-term value!*

---

## Configuration Options

All values are configurable in `UsedPlusMaintenance.CONFIG`:

### Feature Toggles

| Option | Default | Description |
|--------|---------|-------------|
| `enableFailures` | true | Enable engine stalling |
| `enableSpeedDegradation` | true | Enable max speed reduction |
| `enableHydraulicDrift` | true | Enable implement drift |
| `enableElectricalCutout` | true | Enable implement shutoffs |
| `enableInspection` | true | Enable paid inspections |
| `enableResaleModifier` | true | Reliability affects resale value |

### Balance Tuning

| Option | Default | Description |
|--------|---------|-------------|
| `failureRateMultiplier` | 1.0 | Global failure frequency multiplier |
| `speedDegradationMax` | 0.5 | Max speed reduction (50%) |
| `inspectionCostBase` | 200 | Base inspection fee |
| `inspectionCostPercent` | 0.01 | Inspection fee as % of price |

### Thresholds

| Option | Default | Description |
|--------|---------|-------------|
| `damageThresholdForFailures` | 0.2 | Speed degradation starts at 20% damage |
| `reliabilityRepairBonus` | 0.15 | Each repair adds 15% reliability |
| `maxReliabilityAfterRepair` | 0.95 | Reliability cap after repairs |
| `hydraulicDriftThreshold` | 0.5 | Drift only below 50% hydraulic reliability |

### Timing

| Option | Default | Description |
|--------|---------|-------------|
| `stallCooldownMs` | 30000 | 30s between possible stalls |
| `updateIntervalMs` | 1000 | Check for failures every 1s |
| `cutoutCheckIntervalMs` | 5000 | Check for cutout every 5s |
| `cutoutDurationMs` | 3000 | Cutout lasts 3 seconds |

---

## Implementation Details

### Files

| File | Purpose |
|------|---------|
| `src/specializations/UsedPlusMaintenance.lua` | Core specialization with all logic |
| `src/specializations/UsedPlusMaintenanceRegister.lua` | Registers spec with vehicle types |
| `src/gui/InspectionReportDialog.lua` | Inspection report display |
| `gui/InspectionReportDialog.xml` | Inspection report layout |

### Public API

```lua
-- Set used purchase data (called when buying used)
UsedPlusMaintenance.setUsedPurchaseData(vehicle, usedPlusData)

-- Get reliability data (for display/logic)
UsedPlusMaintenance.getReliabilityData(vehicle)
-- Returns: { engineReliability, hydraulicReliability, electricalReliability, avgReliability, failureCount, repairCount, ... }

-- Update reliability after repair
UsedPlusMaintenance.onVehicleRepaired(vehicle, repairCost)

-- Generate reliability scores for new listing
UsedPlusMaintenance.generateReliabilityScores(damage)

-- Get rating text for display
UsedPlusMaintenance.getRatingText(reliability)
-- Returns: "Good", "Acceptable", "Below Average", "Poor", or "Critical"

-- Generate inspector notes
UsedPlusMaintenance.generateInspectorNotes(reliabilityData)
-- Returns: String with component-specific warnings

-- Inspection cache management
UsedPlusMaintenance.isInspectionCacheValid(vehicle, tolerance)
UsedPlusMaintenance.updateInspectionCache(vehicle)
UsedPlusMaintenance.clearInspectionCache(vehicle)
```

### Data Persistence

All reliability data is saved to vehicle savegame XML:

```xml
<vehicles>
  <vehicle>
    <FS25_UsedPlus.UsedPlusMaintenance
      purchasedUsed="true"
      purchasePrice="45000"
      purchaseDamage="0.65"
      wasInspected="true"
      engineReliability="0.57"
      hydraulicReliability="0.43"
      electricalReliability="0.70"
      repairCount="1"
      failureCount="3"
      totalRepairCost="26750"
    />
  </vehicle>
</vehicles>
```

---

## Changelog

### v1.4.0 (2025-12-27)
- Added Workhorse/Lemon Scale integration (dynamic reliability ceiling)
- Added Mechanic's Assessment quote to inspection reports
- Updated repair examples to show ceiling degradation
- Added cross-references to related documents
- See [WORKHORSE_LEMON_SCALE.md](WORKHORSE_LEMON_SCALE.md) for full system documentation

### v1.3.2 (2025-12-27)
- Created this comprehensive documentation
- Documented all three component systems
- Explained probability formulas for all failure types
- Added complete flow example with real numbers
- Documented configuration options

### v1.2.0 (Previous)
- BALANCE: Removed damage gates - reliability now matters even after repair
- Added hydraulic drift system
- Added electrical cutout system
- Improved failure probability formula (exponential curve)

### v1.0.0 (Initial)
- Core reliability tracking system
- Engine stalling
- Speed degradation
- Inspection reports
- Save/load persistence

---

*Document maintained by Claude & Samantha*
*Last reviewed: 2025-12-27*
