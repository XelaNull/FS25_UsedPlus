# UsedPlus Economics & Pricing Model

**Version:** 1.3.3
**Last Updated:** 2025-12-27
**Purpose:** Define the mathematical foundation for all buy/sell transactions in UsedPlus

**Related Documents:**
- [Vehicle Inspection](VEHICLE_INSPECTION.md) - Reliability system, inspection reports, in-game effects
- [Workhorse/Lemon Scale](WORKHORSE_LEMON_SCALE.md) - Hidden vehicle DNA and long-term reliability

---

## Table of Contents

1. [Design Philosophy](#design-philosophy)
2. [Vanilla Baseline](#vanilla-baseline)
3. [Buying Used Vehicles](#buying-used-vehicles)
4. [Selling Vehicles](#selling-vehicles)
5. [Trade-In System](#trade-in-system)
6. [Complete Example: $100,000 Tractor](#complete-example-100000-tractor)
7. [Balance Guidelines](#balance-guidelines)
8. [Implementation Notes](#implementation-notes)

---

## Design Philosophy

### Core Principles

1. **Enhancement, Not Overhaul**: UsedPlus adds depth and options to vanilla FS25, but should not fundamentally break the economy. A player using UsedPlus should have similar financial outcomes to a vanilla player, just with more control over timing and risk.

2. **Risk vs. Reward**: Every discount comes with a tradeoff:
   - Cheaper vehicles need repairs
   - Quick sales get less money
   - Waiting longer gets better prices
   - Wider search costs more but finds better deals

3. **Randomness Within Ranges**: All prices should be RANGES, not fixed values. This:
   - Feels more realistic (like real-world negotiation)
   - Prevents min-maxing
   - Creates emergent gameplay moments ("I got a great deal!")

4. **Time Has Value**: Players can always:
   - Pay more for instant gratification
   - Wait longer for better deals
   - This mirrors real-world economics

### Balance Target

**A player buying a "typical" used vehicle should pay 60-85% of new price** (15-40% savings), with the extremes being:
- Worst case (poor condition, local search): 35-55% of new (needs significant repairs!)
- Best case (excellent condition, national search): 75-90% of new (barely used)

---

## Vanilla Baseline

### What Vanilla FS25 Does

| Action | Vanilla Behavior |
|--------|------------------|
| Buy New | 100% of store price |
| Sell (instant) | ~60-80% of price based on age/condition |
| Used Vehicles | Random spawns in used section, ~30-50% off |

### UsedPlus Deviation Analysis

**Threshold:** Any deviation >25% from vanilla outcomes requires justification.

| Scenario | Vanilla | UsedPlus Range | Max Deviation | Status |
|----------|---------|----------------|---------------|--------|
| **BUYING** | | | | |
| Buy new vehicle | 100% | 100% | 0% | ✓ SAME |
| Buy used (typical) | 50-70% | 50-85% net* | +15% upper | ✓ OK - More options, some premium |
| Buy used (best deal) | 50% | 44% net* | -6% | ✓ OK - High risk for reward |
| Buy used (worst deal) | 70% | 97% net* | +27% | ⚠ HIGH - Justified below |
| **SELLING** | | | | |
| Sell instant | 60-80% | 50-65% trade-in | -15% | ✓ OK - Trade-in is convenience penalty |
| Sell to dealer | 60-80% | 56-92% agent sales | +12% upper | ✓ OK - Time investment for reward |
| Best sale outcome | ~80% | 97-117% premium | +37% | ⚠ HIGH - Justified below |

*Net = purchase price + repair costs

### Deviation Justifications

#### ⚠ Worst Buy Deal (97% net vs vanilla 70%)
**Deviation:** +27% over vanilla worst case
**Justification:**
- This only occurs with Excellent quality tier (nearly new condition)
- Player is CHOOSING to pay premium for minimal repairs
- Equivalent to vanilla's "buy new" at slight discount
- **Value provided:** Certainty of condition, still 3% savings vs new

#### ⚠ Best Sale Outcome (117% vs vanilla 80%)
**Deviation:** +37% over vanilla best case
**Justification:**
- Requires SIGNIFICANT time investment (4-6 months)
- Requires meeting condition thresholds (95% repair, 80% paint)
- Has 25% failure chance even with best agent
- Player invests money upfront (6% fee) with uncertain outcome
- **Value provided:** Reward for patience and vehicle maintenance

### Balance Summary

| Metric | Analysis |
|--------|----------|
| Average player experience | Within ±10% of vanilla |
| Risk/reward balance | Higher variance, similar expected value |
| Time investment | More options = more effort = potential reward |
| Economy stability | No infinite money exploits, all gains require tradeoffs |

**Conclusion:** UsedPlus enhances vanilla through player choice, not power creep. The extreme cases require significant investment (time, risk, or money) and are not easily exploitable.

### Our Enhancement Goals

- Buying: More control over condition/source, appropriate pricing
- Selling: Multiple channels (instant, agents, trade-in) with time/price tradeoffs
- Financing: Can spread payments over time (handled separately)

---

## Buying Used Vehicles

### Overview

When buying used, two independent factors combine:

1. **Search Tier** (WHERE you look): Affects vehicle GENERATION (age/wear probability)
2. **Quality Tier** (WHAT condition you want): Affects BASE PRICE and damage/wear range

### Search Tiers (Agent Location)

Controls the probability distribution of what vehicles you'll find.

| Tier | Fee | Find Time | Generation Distribution | Condition Modifier |
|------|-----|-----------|-------------------------|-------------------|
| **Local** | 1% | 1-7 days | 20% Recent, 50% Mid, 30% Old | +30% worse condition |
| **Regional** | 3% | 1-3 weeks | 40% Recent, 40% Mid, 20% Old | Normal |
| **National** | 5% | 2-6 weeks | 55% Recent, 35% Mid, 10% Old | -30% better condition |

**Vehicle Generations:**
- **Recent** (0-3 years): Lower hours, minimal wear
- **Mid-age** (4-7 years): Moderate use
- **Old** (8-15 years): High hours, more wear expected

### Quality Tiers (Desired Condition)

Controls the price you pay AND the condition of vehicle you receive.

**Design Principle:** Each tier's net cost (purchase + repairs) should have clear separation:
- Repair cost formula: `damage% × 25% × basePrice`
- Repaint cost formula: `wear% × 15% × basePrice`

| Quality | Base Price Range | Damage Range | Wear Range | Est. Net Range | Description |
|---------|------------------|--------------|------------|----------------|-------------|
| **Poor** | 22-38% of new | 55-80% | 60-85% | 44-67% net | Fixer-upper, may be inoperable |
| **Any** | 35-52% of new | 30-60% | 35-65% | 50-72% net | Widest search, anything goes |
| **Fair** | 50-66% of new | 15-35% | 18-40% | 59-79% net | Needs some work |
| **Good** | 65-80% of new | 4-16% | 5-20% | 69-88% net | Ready to use |
| **Excellent** | 80-94% of new | 0-6% | 0-8% | 81-97% net | Like new |

**Tier Separation Guarantee:**
- Poor max net (67%) < Fair min net (59%)? YES, but with ~5% overlap zone for risk/reward
- Fair max net (79%) < Good min net (69%)? YES, but with ~5% overlap zone
- Each tier's EXPECTED net is clearly ordered (no overlap in averages)

*Note: Some overlap in ranges is intentional - it creates risk/reward dynamics where a lucky Poor find might beat an unlucky Fair find.*

### Combined Price Formula

```
Final Price = Base Price × Quality Multiplier × Age Multiplier × Random Variance

Where:
- Base Price = Store price (new)
- Quality Multiplier = RANGE based on quality tier (see table)
- Age Multiplier = 1.0 - (age × 0.03), capped at 0.75 (max 25% age discount)
- Random Variance = 0.92 to 1.08 (±8% randomness)
```

### Display Format (UI)

**Show RANGES, not fixed values:**

Instead of: `"~70% off"`
Display as: `"~60-75% off"` or `"Save 60-75%"`

This communicates that:
- Results will vary
- This is an estimate, not a guarantee
- Players shouldn't expect exact amounts

---

## Selling Vehicles

### Overview

When selling, TWO independent choices combine:

1. **Agent Tier** (WHO sells): Affects timing, reach, and base success rate
2. **Price Tier** (WHAT to ask): Affects price range and success modifier

### Agent Tiers

| Agent | Fee | Duration | Base Success | Notes |
|-------|-----|----------|--------------|-------|
| **Private Sale** | 0% | 3-6 months | 50% | No agent, you do the work |
| **Local Agent** | 2% | 1-2 months | 70% | Quick but limited reach |
| **Regional Agent** | 4% | 2-4 months | 85% | Balanced option |
| **National Agent** | 6% | 4-6 months | 95% | Maximum exposure |

### Price Tiers

| Price Tier | Price Range (of FMV) | Success Mod | Requirements |
|------------|---------------------|-------------|--------------|
| **Quick Sale** | 75-85% | +15% | None |
| **Market Price** | 95-105% | ±0% | None |
| **Premium** | 115-130% | -20% | ≥95% repair, ≥80% paint |

### Combined Success Rate

```
Final Success = Agent Base Success + Price Modifier
Clamped to 10-98%

Examples:
- Local + Quick Sale: 70% + 15% = 85%
- Regional + Market: 85% + 0% = 85%
- National + Premium: 95% - 20% = 75%
- Private + Premium: 50% - 20% = 30% (risky!)
```

### Sale Price Formula

```
Offer Price = FMV × Price Tier Multiplier × Variance

Where:
- FMV = Vehicle's current fair market value (vanilla getSellPrice)
- Price Tier Multiplier = Random within tier's range
- Variance = 0.95 to 1.05 (±5% final randomness)
```

---

## Trade-In System

### Overview

Trade-in is the **LOWEST return option** but is **INSTANT** and only available when purchasing.

### Trade-In Formula

```
Trade-In Value = Vanilla Sell Price × Base Rate × Condition × Maintenance × Brand

Where:
- Vanilla Sell Price = What you'd get selling normally
- Base Rate = 50-65% (random per transaction)
- Condition = 0.70-1.00 (based on damage/wear)
- Maintenance = 0.85-1.10 (based on repair history)
- Brand = +5% if same manufacturer
```

### Value Hierarchy (Same Vehicle, Different Sale Methods)

| Method | % of Vanilla Sell | Time | Notes |
|--------|-------------------|------|-------|
| Trade-In | 50-65% | Instant | Only when buying |
| Quick Sale (Local) | 56-68% | 1-2 months | Low effort |
| Market Sale (Regional) | 80-92% | 2-4 months | Fair return |
| Premium (National) | 97-117% | 4-6 months | Best case |

---

## Complete Example: $100,000 Tractor

Let's trace a John Deere 6R 150 (new price: $100,000) through all scenarios.

### Scenario A: Buying Used

**Setup:** Player searches for a used 6R 150

#### Local Search + Poor Quality
- Search fee: $1,000 (1%)
- Base price range: 22-38% of new = $22,000 - $38,000
- Age factor (random 1-15 years): additional -3% to -15%
- **Expected purchase price: $19,000 - $38,000**
- **But:** Will have 55-80% damage, 60-85% wear
- Repair cost: 55-80% × 25% = $13,750 - $20,000
- Repaint cost: 60-85% × 15% = $9,000 - $12,750
- **Net effective cost: $41,750 - $70,750** (42-71% of new)

#### Regional Search + Fair Quality
- Search fee: $3,000 (3%)
- Base price range: 50-66% of new = $50,000 - $66,000
- Age factor: -3% to -15%
- **Expected purchase price: $43,000 - $66,000**
- **But:** Will have 15-35% damage, 18-40% wear
- Repair cost: 15-35% × 25% = $3,750 - $8,750
- Repaint cost: 18-40% × 15% = $2,700 - $6,000
- **Net effective cost: $49,450 - $80,750** (49-81% of new)

#### National Search + Excellent Quality
- Search fee: $5,000 (5%)
- Base price range: 80-94% of new = $80,000 - $94,000
- Age factor: -3% to -15%
- **Expected purchase price: $68,000 - $94,000**
- **But:** Only 0-6% damage, 0-8% wear (minimal!)
- Repair cost: 0-6% × 25% = $0 - $1,500
- Repaint cost: 0-8% × 15% = $0 - $1,200
- **Net effective cost: $68,000 - $96,700** (68-97% of new)

### Scenario B: Selling a Used Tractor

**Setup:** Player owns a 6R 150, current vanilla sell value $70,000, 85% repair, 90% paint

#### Trade-In (when buying new equipment)
- Base rate: 50-65%
- Condition modifier: ~0.98 (good shape)
- **Trade-in credit: $34,300 - $44,590**
- Time: Instant

#### Local Agent + Quick Sale
- Fee: 2% = $1,190
- Price range: 75-85% of $70,000 = $52,500 - $59,500
- Success rate: 70% + 15% = 85%
- Time: 1-2 months
- **Expected return: $51,310 - $58,310** (minus fee)

#### Regional Agent + Market Price
- Fee: 4% = $2,660
- Price range: 95-105% of $70,000 = $66,500 - $73,500
- Success rate: 85%
- Time: 2-4 months
- **Expected return: $63,840 - $70,840** (minus fee)

#### National Agent + Premium
- Fee: 6% = $4,200 (based on expected mid-price ~$85,000)
- Price range: 115-130% of $70,000 = $80,500 - $91,000
- Success rate: 95% - 20% = 75%
- Time: 4-6 months
- Requires: ≥95% repair (❌ only 85%), ≥80% paint (✓)
- **Not available!** Vehicle doesn't meet premium requirements.

After repairs (cost ~$3,000 to reach 95%):
- **Expected return: $76,300 - $86,800** (minus fee and repair cost)

### Scenario Summary Table

| Scenario | Cost/Return | % of New | Time | Risk |
|----------|-------------|----------|------|------|
| **BUYING** | | | | |
| Local + Poor | $42k-$71k (net) | 42-71% | 1-7 days | High (repairs needed) |
| Regional + Fair | $49k-$81k (net) | 49-81% | 1-3 weeks | Medium |
| National + Excellent | $68k-$97k (net) | 68-97% | 2-6 weeks | Low |
| **SELLING** | | | | |
| Trade-In | $34k-$45k | 49-64% of FMV | Instant | None |
| Local + Quick | $51k-$58k | 73-83% of FMV | 1-2 months | Low |
| Regional + Market | $64k-$71k | 91-101% of FMV | 2-4 months | Low |
| National + Premium | $76k-$87k | 109-124% of FMV | 4-6 months | Medium (25% fail) |

*FMV = Fair Market Value (vanilla sell price)*

---

## Balance Guidelines

### Price Boundaries

To prevent economy-breaking scenarios:

| Boundary | Limit | Reason |
|----------|-------|--------|
| Min used price | 15% of new | Even junk has scrap value |
| Max used discount | 85% off new | Never "basically free" |
| Min sell price | 30% of vanilla sell | Always get something |
| Max sell price | 130% of vanilla sell | No crazy markups |

### Repair Cost Consideration

The discount should approximately equal repair costs at worst:
- 50% discount (~$50k savings on $100k tractor) should roughly equal
- Maximum repair cost (~$25k) + repaint (~$10k) + opportunity cost
- Net savings: $15,000 (reasonable for the hassle)

### Time Value

Player time has value. Rough equivalents:
- 1 month waiting ≈ 5-10% price improvement
- Instant trade-in penalty: ~35-50% vs market sale

---

## Long-Term Ownership: The Hidden DNA Factor

Beyond the initial purchase price and repair costs, every used vehicle has a hidden **Workhorse/Lemon Scale** (0.0-1.0) that dramatically affects long-term costs. See [WORKHORSE_LEMON_SCALE.md](WORKHORSE_LEMON_SCALE.md) for full details.

### Impact on Total Cost of Ownership (TCO)

For a $100,000 tractor operated for 10 years with 20 repairs:

| Vehicle Type | DNA Scale | Ceiling After 20 Repairs | Long-Term Reliability | Est. Extra Repair Costs |
|--------------|-----------|--------------------------|----------------------|-------------------------|
| **Workhorse** | 0.90+ | 98%+ | Excellent | +$0 (minimal failures) |
| **Average** | 0.50 | 90% | Good | +$5,000 (some failures) |
| **Lemon** | 0.10 | 82% | Poor | +$15,000+ (frequent failures) |

### The Hidden Cost of Lemons

A lemon that appears to be a good deal can become a money pit:

```
Initial "savings" on cheap Poor-quality vehicle:  -$30,000
Repair costs over 10 years (accelerated):         +$40,000
Lost productivity from breakdowns:                +$10,000
Resale value reduction (reliability penalty):     +$8,000
───────────────────────────────────────────────────────────
Net 10-year cost vs new:                          +$28,000 WORSE
```

### When Cheap is Actually Expensive

| Scenario | Initial Savings | Hidden DNA | 10-Year TCO | Outcome |
|----------|-----------------|------------|-------------|---------|
| Excellent + Workhorse | -3% | 0.95 | ~$85,000 | ✅ Best value |
| Fair + Average | -20% | 0.50 | ~$95,000 | ✅ Reasonable |
| Poor + Workhorse | -50% | 0.90 | ~$80,000 | ✅ Lucky find! |
| Poor + Lemon | -50% | 0.10 | ~$130,000 | ❌ Money pit |

**Key Insight:** The inspection report's "Mechanic's Assessment" quote hints at the DNA quality. Pay attention to the mechanic's tone - it could save you thousands!

### Resale Value Impact

When selling a vehicle, reliability affects resale value:

```lua
-- Resale modifier formula
avgReliability = (engine + hydraulic + electrical) / 3
reliabilityModifier = 0.7 + (avgReliability * 0.3)  -- Range: 0.7 to 1.0

-- A vehicle with 50% average reliability sells for 85% of normal
-- A vehicle with 90% average reliability sells for 97% of normal
```

---

## Implementation Notes

### Current vs. Proposed Changes

**Current Implementation:**
- Quality tiers show FIXED percentages: "~70% off"
- Prices are calculated with hidden variance

**Proposed Implementation:**
- Quality tiers show RANGES: "~60-75% off"
- Display min-max expected prices
- Keep actual variance in calculations

### Code Locations

| System | File |
|--------|------|
| Buy pricing | `src/utils/DepreciationCalculations.lua` |
| Sell pricing | `src/data/VehicleSaleListing.lua` |
| Trade-in | `src/utils/TradeInCalculations.lua` |
| Search UI | `src/gui/UsedSearchDialog.lua` |
| Sell UI | `src/gui/SellVehicleDialog.lua` |

### Proposed Quality Tier Updates

```lua
-- Current (DepreciationCalculations.lua)
QUALITY_TIERS = {
    { name = "Poor", priceMultiplier = 0.50 },      -- 50% off fixed
    { name = "Any", priceMultiplier = 0.55 },       -- 45% off fixed
    { name = "Fair", priceMultiplier = 0.68 },      -- 32% off fixed
    { name = "Good", priceMultiplier = 0.78 },      -- 22% off fixed
    { name = "Excellent", priceMultiplier = 0.88 }, -- 12% off fixed
}

-- Proposed (with ranges, balanced for tier separation)
QUALITY_TIERS = {
    { name = "Poor",
      priceMin = 0.22, priceMax = 0.38,
      damageMin = 0.55, damageMax = 0.80,
      wearMin = 0.60, wearMax = 0.85,
      displayDiscount = "62-78% off" },
    { name = "Any",
      priceMin = 0.35, priceMax = 0.52,
      damageMin = 0.30, damageMax = 0.60,
      wearMin = 0.35, wearMax = 0.65,
      displayDiscount = "48-65% off" },
    { name = "Fair",
      priceMin = 0.50, priceMax = 0.66,
      damageMin = 0.15, damageMax = 0.35,
      wearMin = 0.18, wearMax = 0.40,
      displayDiscount = "34-50% off" },
    { name = "Good",
      priceMin = 0.65, priceMax = 0.80,
      damageMin = 0.04, damageMax = 0.16,
      wearMin = 0.05, wearMax = 0.20,
      displayDiscount = "20-35% off" },
    { name = "Excellent",
      priceMin = 0.80, priceMax = 0.94,
      damageMin = 0.00, damageMax = 0.06,
      wearMin = 0.00, wearMax = 0.08,
      displayDiscount = "6-20% off" },
}
```

### Display Format Updates

```lua
-- UsedSearchDialog: Show ranges
local minDiscount = math.floor((1 - quality.priceMax) * 100)
local maxDiscount = math.floor((1 - quality.priceMin) * 100)
local discountText = string.format("~%d-%d%% off", minDiscount, maxDiscount)
```

---

## Changelog

### v1.3.3 (2025-12-27)
- **Fixed quality tier separation** - Adjusted price/damage/wear ranges to ensure proper tier ordering
- **Added Vanilla Deviation Analysis** - Documents how far we deviate from base game and justifies extremes
- **Updated example calculations** - $100k tractor example now uses corrected formulas
- **Added damage/wear formulas to quality tiers** - Each tier now specifies expected damage/wear ranges
- **Added Est. Net Range column** - Shows total cost including repairs for each quality tier

### v1.3.2 (2025-12-27)
- Created this document
- Analyzed complete buy/sell economics
- Proposed range-based display for quality tiers
- Documented all formulas and boundaries

### Future Considerations
- [ ] Seasonal price variations (equipment worth more in spring?)
- [ ] Brand reputation effects on resale
- [ ] Bulk discounts for fleet purchases
- [ ] Auction system with bidding

---

*Document maintained by Claude & Samantha*
*Last reviewed: 2025-12-27*
