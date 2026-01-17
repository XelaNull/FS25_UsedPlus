# Used Vehicle Negotiation System (v2.6.0)

A strategic price negotiation feature for used vehicle purchases that rewards patient, weather-aware players.

---

## Overview

When you find a used vehicle through an agent and complete the inspection, you can now **negotiate the price** instead of paying full asking price. The system features:

1. **Mechanic's Whisper** - Intel about the seller's psychology
2. **Weather Window** - Bad weather improves your negotiating position
3. **Seller Personalities** - Four AI personality types with different thresholds
4. **Stand Firm Gamble** - Risk/reward mechanic for aggressive negotiators

---

## How It Works

### Step 1: Find and Inspect a Used Vehicle
1. Hire an agent (Local, Regional, or National) to search for a vehicle
2. When vehicles are found, browse your portfolio
3. Pay for an inspection to see the vehicle's condition and reliability

### Step 2: Make an Offer
After inspection, click **"Make Offer"** (previously "Purchase") to open the Negotiation Dialog.

The dialog shows:
- Vehicle name and asking price
- Vehicle image
- **Mechanic's Whisper** - Hint about seller psychology + weather intel
- **Offer buttons** - 70%, 80%, 85%, 90%, 95%, 100%
- Your offer amount and potential savings

### Step 3: Seller Response
After sending your offer, one of three things happens:

| Response | Meaning | Your Options |
|----------|---------|--------------|
| **Accept** | Deal! You got the price you asked for | Complete purchase |
| **Counter** | Seller wants more, but is willing to negotiate | Accept counter, Stand Firm, or Walk Away |
| **Reject** | Offer too low | Pay full price or walk away |

### Step 4: Stand Firm (Optional)
If the seller counters, you can **Stand Firm** on your original offer:

| Outcome | Chance | What Happens |
|---------|--------|--------------|
| Seller caves | 30% | They accept your original offer |
| Seller holds | 50% | Counter offer remains - take it or leave it |
| Seller walks | 20% | Listing locked for 1 game hour |

---

## Seller Personalities

Each listing is assigned a hidden seller personality that determines their negotiation behavior:

| Personality | Frequency | Accept Threshold | Counter Threshold | Whisper Hints |
|-------------|-----------|------------------|-------------------|---------------|
| **Desperate** | 10% | 65% | 75% | "Seems eager to sell", "In a tough spot" |
| **Motivated** | 25% | 75% | 85% | "Upgrading to bigger equipment", "Could be flexible" |
| **Reasonable** | 40% | 85% | 92% | "Straightforward seller", "Worth making an offer" |
| **Firm** | 25% | 92% | 97% | "Priced it fair", "Knows exactly what it's worth" |

---

## Acceptance Modifiers

The base acceptance threshold is modified by several factors:

### Listing Conditions
| Factor | Modifier | Reason |
|--------|----------|--------|
| Days on market | +0.3% per day (max +10%) | Longer listings = more motivation |
| Damage > 20% | +5% | Harder to sell damaged vehicles |
| Hours > 5000 | +3% | High-hour vehicles move slower |
| Base price > $200,000 | -5% | Premium vehicles, seller knows the value |

### Weather Modifiers
| Weather | Modifier | Psychology |
|---------|----------|------------|
| Hail | +12% | Fear of outdoor equipment damage |
| Storm/Thunder | +8% | Urgency to close before things worsen |
| Rain | +5% | Stuck inside, reflective mood, willing to deal |
| Snow | +5% | Off-season blues, wants equipment gone |
| Fog | +3% | Gloomy outlook, slightly pessimistic |
| Cloudy | +2% | Mildly contemplative |
| Sun | 0% | Baseline - normal conditions |
| Perfect Clear | -3% | Optimistic, no rush, life is good |

---

## The Mechanic's Whisper

Your mechanic provides two types of intel:

### Seller Intel (Always Shown)
Based on seller personality and listing conditions:

| Whisper | Meaning | Negotiation Hint |
|---------|---------|------------------|
| "Between you and me... they seem pretty eager to sell. Might be in a tough spot." | Desperate | Go low (70-80%) |
| "Between you and me... I've seen this rig listed for a while now. Seller might be motivated." | Long listing | Moderate aggression |
| "Between you and me... heard they're upgrading to bigger equipment. Could be flexible." | Motivated | Push a bit (80-90%) |
| "Between you and me... they've priced it fair and know exactly what it's worth." | Firm | Don't lowball (90-100%) |
| "Between you and me... just hit the market. Might not be in a rush to deal." | New listing | Be careful |
| "Between you and me... seems like a straightforward seller. Worth making an offer." | Reasonable | Standard negotiation |

### Weather Intel (When Significant)
If weather provides +5% or more advantage:
- *"Plus, with that storm rolling in, they might want to close quick."*
- *"Rain's keeping everyone cooped up... good time to push for a deal."*
- *"That hail's got folks worried about their gear sitting out."*
- *"Snow falling... off-season always makes sellers more flexible."*

If weather provides -3% or worse disadvantage:
- *"Beautiful day like this though... don't expect any favors."*

---

## Negotiation Lock

If you push too hard and the seller walks away (20% chance on Stand Firm), the listing becomes **locked for 1 game hour**.

- You cannot make another offer during the lockout
- Dialog shows "Seller is unavailable. Try again in X minutes."
- The lock expires automatically after 1 game hour
- This creates risk for aggressive negotiation tactics

---

## Statistics Tracking

The following statistics are tracked per farm:

| Statistic | Description |
|-----------|-------------|
| `negotiationsAttempted` | Total offers made |
| `negotiationsWon` | Offers accepted at your price |
| `negotiationsCountered` | Counter offers accepted |
| `negotiationsRejected` | Walked away or paid full price |
| `totalNegotiationSavings` | Money saved through negotiation |

---

## Strategic Tips

### Maximize Your Savings
1. **Check the weather forecast** - Wait for bad weather before negotiating
2. **Listen to the whisper** - Desperate sellers accept lower offers
3. **Consider the listing age** - Long-listed vehicles have motivated sellers
4. **Watch for high damage/hours** - These listings are easier to negotiate

### Minimize Risk
1. **Start with 85-90%** for unknown sellers
2. **Only go 70-80%** if whisper indicates desperate seller
3. **Avoid Stand Firm** unless you can afford to lose access for an hour
4. **Perfect weather days** - Expect to pay closer to asking price

### The Magic Strategy
The best deals happen when:
- Seller personality is Desperate or Motivated
- Vehicle has been listed for 2+ weeks
- Weather is bad (storm, hail, rain)
- You can wait for the perfect moment

**Example:** You see a tractor listed for $85,000. Whisper says seller's been listing for a while. You check weather - storm coming in 2 hours. You wait. Storm hits. You offer 75% ($63,750). Seller accepts. You saved $21,250!

---

## Files

### Lua Files
| File | Purpose |
|------|---------|
| `src/gui/NegotiationDialog.lua` | Main negotiation interface |
| `src/gui/SellerResponseDialog.lua` | Accept/Counter/Reject display |
| `src/gui/InspectionReportDialog.lua` | Modified to show "Make Offer" |
| `src/data/UsedVehicleSearch.lua` | Seller personality generation |
| `src/managers/FinanceManager.lua` | Negotiation statistics |

### XML Files
| File | Purpose |
|------|---------|
| `gui/NegotiationDialog.xml` | Negotiation UI layout |
| `gui/SellerResponseDialog.xml` | Response UI layout |

### Translation Keys
All negotiation text is localized. Key prefixes:
- `usedplus_neg_*` - Negotiation dialog text
- `usedplus_whisper_*` - Mechanic whisper messages
- `usedplus_response_*` - Seller response messages
- `usedplus_standfirm_*` - Stand firm outcomes

---

## Technical Implementation

### Weather API
```lua
-- Correct way to get current weather type in FS25
local environment = g_currentMission.environment
if environment and environment.weather and environment.weather.getCurrentWeatherType then
    local weatherType = environment.weather:getCurrentWeatherType()
    -- weatherType is an integer: 0=Sun, 1=Cloudy, 2=Rain, etc.
end
```

**Important:** Use `getCurrentWeatherType()` (no parameters), NOT `getWeatherTypeAtTime()` (requires time parameter).

### Acceptance Formula
```lua
-- Effective threshold = base - modifiers (lower = easier to accept)
local effectiveThreshold = baseThreshold - modifier

if offerPercent >= effectiveThreshold then
    return "accept"
elseif offerPercent >= effectiveThreshold - 0.10 then
    return "counter"
else
    return "reject"
end
```

### Stand Firm RNG
```lua
local roll = math.random()
if roll < 0.30 then
    return "seller_caves"  -- Accept original offer
elseif roll < 0.80 then
    return "seller_holds"  -- Counter remains
else
    return "seller_walks"  -- Listing locked
end
```

---

## Version History

### v2.6.0 (2026-01-14)
- Initial implementation of negotiation system
- NegotiationDialog with 6 offer percentage buttons
- SellerResponseDialog with Accept/Counter/Reject flows
- Mechanic's Whisper with seller intel
- Weather modifier system
- 4 seller personalities with weighted distribution
- Stand Firm gamble mechanic
- Negotiation lock on seller walkaway
- Statistics tracking for negotiations
- Full translation support (EN, DE)

---

*"I waited for the hailstorm and saved 20% on that combine!" - That's the story players will tell their friends.*
