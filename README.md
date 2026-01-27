<p align="center">
  <img src="icon.png" alt="UsedPlus Logo" width="128" height="128">
</p>

<h1 align="center">UsedPlus</h1>

<p align="center">
  <strong>Transform Your Farm Into a Real Business</strong><br>
  <em>Stop playing with Monopoly money. Start making real financial decisions.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-2.9.5-green" alt="Version">
  <img src="https://img.shields.io/badge/game-FS25-blue" alt="FS25">
  <img src="https://img.shields.io/badge/multiplayer-ready-brightgreen" alt="Multiplayer Ready">
  <img src="https://img.shields.io/badge/languages-15-orange" alt="15 Languages">
  <img src="https://img.shields.io/badge/AI--authored-Claude-purple" alt="AI Authored">
</p>

<p align="center">
  <a href="https://github.com/XelaNull/FS25_UsedPlus">GitHub</a> •
  <a href="https://github.com/XelaNull/FS25_UsedPlus/issues">Report Issues</a> •
  <a href="#installation">Installation</a> •
  <a href="#quick-start">Quick Start</a>
</p>

---

## Companion Mods

UsedPlus integrates deeply with these mods for the ultimate farming experience:

| Mod | What It Adds | Download |
|-----|--------------|----------|
| 🔧 **Real Vehicle Breakdowns** | Part failures, realistic damage | [GitHub](https://github.com/MathiasHun/FS25_Real_Vehicle_Breakdowns_Beta) *(beta)* |
| 🛞 **Use Your Tyres** | Tire wear & replacement | [ModHub](https://www.farming-simulator.com/mod.php?mod_id=321793&title=fs2025) |
| 💰 **EnhancedLoanSystem** | Additional loan types | [ModHub](https://www.farming-simulator.com/mod.php?mod_id=314906&title=fs2025) |
| 📋 **HirePurchasing** | Hire-purchase contracts | [ModHub](https://www.farming-simulator.com/mod.php?mod_id=327821&title=fs2025) |
| 🛒 **BuyUsedEquipment** | Alternative used market | [ModHub](https://www.farming-simulator.com/mod.php?mod_id=312631&title=fs2025) |
| 🤖 **Courseplay** | AI worker automation | [ModHub](https://www.farming-simulator.com/mod.php?mod_id=331515&title=fs2025) / [GitHub](https://github.com/Courseplay/Courseplay_FS25) |
| 🚗 **AutoDrive** | Automated driving routes | [GitHub](https://github.com/Stephan-S/FS25_AutoDrive) |

> **Note:** All mods are optional. UsedPlus works standalone but enhances these mods when detected.

---

## This Isn't Just Another Mod

Most FS25 mods add a feature. A new tractor. A tweak to crop prices. A UI improvement.

**UsedPlus replaces how you think about money.**

In vanilla FS25, every purchase is the same question: *Can I afford it?* Click buy. Done.

But that's not how real farms work. Real farmers:

- **Finance equipment** over 5, 10, or even 30 years
- **Lease land** they can't afford to buy outright
- **Build credit** through payment history
- **Negotiate prices** on used equipment
- **Trade in** old machines toward new purchases
- **Maintain equipment** or face real consequences

UsedPlus brings **all of that** to Farming Simulator 25 - not as separate features bolted on, but as **interconnected systems** that create emergent gameplay.

---

## What Makes This Different

### Everything Connects

| System | Affects |
|--------|---------|
| **Credit Score** | Interest rates, available loan terms, lease eligibility |
| **Vehicle DNA** | Long-term reliability, seller personality, repair outcomes, RVB part lifetimes |
| **Payment History** | Credit score (+5 per payment, -25 per miss), asset seizure risk |
| **Weather** | Negotiation success rates (Hail +12%, Storm +8%, Rain +5%) |
| **Maintenance** | 15+ specific malfunctions, runaway engines, seizures |
| **Fluid Levels** | Malfunction severity (2.6x more likely at 20% fluid) |

This isn't "feature soup" - it's an **economic simulation** where your decisions have consequences that ripple across systems.

### The Numbers

| Metric | Value |
|--------|-------|
| Lines of Code | ~77,000 |
| Source Files | 113 Lua + 45 XML |
| Custom Dialogs | 41 |
| Network Event Systems | 12 |
| Console Commands | 22 |
| Localization Keys | 1,944 |
| Inspector Quotes | 50 unique (5 per DNA tier) |
| Malfunctions | 15+ types |
| Languages | 15 (fully translated) |
| Development | 3 months (Nov 2025 - Jan 2026) |

### The Story

This mod was written **entirely by AI**. Every function, every dialog, every network event.

The human author provided vision, direction, testing, and feedback. The code was written by **Claude** (developer) and reviewed by **Samantha** (co-creator/UX specialist) - AI personas through Anthropic's Claude Code.

We believe this is one of the most ambitious AI-human collaborative software projects released to the public for FS25.

### Your Vehicles Have Stories

Ever find yourself making up backstories for your equipment? With UsedPlus, you don't have to imagine - the stories emerge naturally:

> *"That old Fendt? 80,000 hours and still runs like new. I'll never sell her."*

> *"Got a 'great deal' from a guy who seemed desperate to sell. Now I know why."*

> *"The mechanic warned me. Said something about burning sage. I should have listened."*

> *"Waited for a thunderstorm to close the deal. Seller got nervous. Saved me $40,000."*

> *"Three tractors in, I finally found a keeper. This one's different. You can just tell."*

Every vehicle has hidden qualities. Some become legends. Some become money pits. The mechanic gives you hints, the seller's behavior tells a story, and over hundreds of hours, you'll develop genuine attachment to the machines that earn it.

**We don't spoil how it works here.** Discover it yourself. Pay attention to the details. The systems reward observation.

---

## Features at a Glance

<table>
<tr>
<td align="center" width="25%">
<img src="gui/icons/finance.png" width="48" height="48"><br>
<strong>Finance Everything</strong><br>
<sub>Vehicles, land, repairs</sub>
</td>
<td align="center" width="25%">
<img src="gui/icons/credit_score.png" width="48" height="48"><br>
<strong>Credit Scoring</strong><br>
<sub>300-850 FICO-style</sub>
</td>
<td align="center" width="25%">
<img src="gui/icons/search.png" width="48" height="48"><br>
<strong>Used Marketplace</strong><br>
<sub>Agent-based buying/selling</sub>
</td>
<td align="center" width="25%">
<img src="gui/icons/service_truck.png" width="48" height="48"><br>
<strong>Service Truck</strong><br>
<sub>Restore reliability ceiling</sub>
</td>
</tr>
</table>

### Financial Systems

| Feature | What It Does |
|---------|--------------|
| **Credit Scoring (300-850)** | FICO-style score gates rates and term availability |
| **Vehicle Financing** | 1-15 year terms, 0-50% down, credit-gated (15yr needs Good) |
| **Vehicle Leasing** | Lower payments, balloon at end, early buyout option |
| **Land Financing** | Finance field purchases, up to 30 years, lower rates than equipment |
| **Land Leasing** | 1-10 year terms, progress-based buyout discount (up to 15% off) |
| **General Cash Loans** | Borrow against vehicle collateral |
| **Finance Repairs** | Spread large repair and repaint costs over monthly payments |
| **Flexible Payments** | Skip, minimum, standard, double, or custom amounts |
| **Negative Amortization** | Skip payments and your balance actually grows |

### Marketplace Systems

| Feature | What It Does |
|---------|--------------|
| **Used Vehicle Search** | 3-tier agent system (Local/Regional/National) finds discounted equipment |
| **Price Negotiation** | 5 seller personalities tied to vehicle DNA |
| **Permanent Walk-Away** | Insult the seller and that listing is gone forever |
| **Agent-Based Sales** | Sell for 60-100% value (vs vanilla's instant pennies) |
| **Trade-In** | 50-65% instant value, brand loyalty bonus (+5%) |
| **Inspection System** | 50 unique mechanic quotes reveal hidden condition |

### Vehicle Systems

| Feature | What It Does |
|---------|--------------|
| **Vehicle DNA (0.0-1.0)** | Hidden quality - lemons, average, workhorses, legendaries |
| **Legendary Immortality** | DNA 0.90+ vehicles NEVER degrade with proper maintenance |
| **15+ Malfunctions** | Engine, electrical, hydraulic, tire, and fuel failures |
| **Runaway Engine** | Neglect fluids = 150% speed, 40% brakes |
| **Component Seizure** | Permanent damage requiring expensive repair |
| **Partial Repair** | Fix 25%, 50%, 75% - why fully repair what you're selling? |
| **Partial Repaint** | Same flexibility for cosmetics |
| **3 Tire Tiers** | Retread (cheap/weak), Normal, Quality (expensive/durable) |
| **Fluid Systems** | Oil and hydraulic levels affect malfunction rates |
| **OBD Scanner** | One-time diagnostic boost per system (strategic decision) |
| **Service Truck** | Long-term restoration that can restore reliability ceiling (unique!) |

---

## The Signature Features

### Credit Scoring That Gates Everything

Your financial history creates a 300-850 credit score that **gates what you can do**:

| Credit Range | Rating | Interest | Vehicle Term | Land Term |
|--------------|--------|----------|--------------|-----------|
| 750+ | Excellent | -1.5% | 15 years | **30 years** |
| 700-749 | Good | -0.5% | **15 years** | 20 years |
| 650-699 | Fair | +0.5% | 10 years | 15 years |
| 600-649 | Poor | +1.5% | 5 years | 10 years |
| <600 | Very Poor | +3.0% | 5 years | May be denied |

**Building Credit:**
- On-time payment: **+5 points**
- Pay off loan early: **+50 points**
- Miss a payment: **-25 points**
- Asset seized: **-100 points**

New game? Start at 650 (Fair). Build from there.

---

### Vehicle DNA: Lemons, Workhorses & Immortals

Every vehicle has hidden DNA (0.0-1.0) assigned at spawn. It **never changes**.

| DNA Range | Type | What Happens |
|-----------|------|--------------|
| 0.00-0.29 | **Lemon** | Repairs make it worse. Each repair loses 1% ceiling. Death spiral. |
| 0.30-0.69 | Average | Normal degradation. 0.5% ceiling loss per repair. |
| 0.70-0.89 | **Workhorse** | Minimal degradation. 0.25% ceiling loss per repair. |
| 0.90-1.00 | **Legendary** | **IMMUNE to repair degradation.** Can last forever. |

**The Death Spiral:** A lemon starts at 100% max reliability. After 10 repairs, its ceiling is 90%. After 50 repairs, 50%. Eventually it can never be repaired above 30%. Get rid of it.

**The Immortal:** A legendary workhorse with DNA 0.95 maintains its equipment properly? That tractor can run for 100,000 hours and still be at peak performance. Forever.

#### 50 Inspector Quotes (5 per DNA Tier)

The mechanic doesn't tell you the DNA number - they give you hints:

| DNA Tier | Example Quote |
|----------|---------------|
| Catastrophic (0.0-0.09) | *"I'd burn some sage before driving this one off the lot..."* |
| Terrible (0.10-0.19) | *"The gremlins have set up permanent residence in this one."* |
| Poor (0.20-0.29) | *"She's been ridden hard and put away wet, I'm afraid."* |
| Below Average (0.30-0.39) | *"Nothing a little TLC couldn't improve... eventually."* |
| Average (0.40-0.59) | *"About what you'd expect from the factory."* |
| Above Average (0.60-0.69) | *"Someone took care of this one. You can tell."* |
| Good (0.70-0.79) | *"This is what we call a 'keeper' in the business."* |
| Excellent (0.80-0.89) | *"Built on a Friday when everyone was happy, I reckon."* |
| Outstanding (0.90-0.94) | *"In 30 years, I've seen maybe a dozen this well built."* |
| Legendary (0.95-1.00) | *"If machines had souls, this one's is blessed by the farming gods."* |

---

### Negotiation With Real Consequences

Found used equipment? **Negotiate the price** - but the seller's personality is tied to vehicle DNA:

| Seller Type | Accepts Offers At | Tied To |
|-------------|-------------------|---------|
| Desperate | 65%+ of asking | Lemons (DNA <0.30) |
| Motivated | 75%+ | Below-average (0.30-0.49) |
| Reasonable | 85%+ | Average (0.50-0.69) |
| Firm | 92%+ | Above-average (0.70-0.89) |
| Immovable | 98%+ | Workhorses (DNA 0.90+) |

**The Design Genius:** Desperate sellers often have lemons. Stubborn sellers often have workhorses. That premium might be worth paying.

#### Weather Affects Deals

Storms make sellers anxious:

| Weather | Acceptance Bonus |
|---------|------------------|
| Hail | +12% |
| Storm | +8% |
| Rain/Snow | +5% |
| Fog | +3% |
| Cloudy | +2% |
| Sunny | 0% |
| Clear | -3% |

#### The Risk of Lowballing

| Gap Below Threshold | Result |
|---------------------|--------|
| Within 5% | Always counter-offer |
| 5-10% below | Usually counter |
| 10-15% below | 50/50 chance |
| 15-20% below | Usually reject |
| **>20% below** | **Permanent walk-away. Listing gone forever.** |

---

### 15+ Malfunctions From Neglected Maintenance

#### Engine Malfunctions
| Malfunction | Trigger | Effect |
|-------------|---------|--------|
| Overheating | Low oil, heavy use | Temperature rises, power reduces, eventual stall |
| Misfiring | Low oil | Random power fluctuations, rough running |
| Stalling | Low oil | Engine cuts out unexpectedly |
| Hard Starting | Worn engine, cold | Difficulty starting |

#### Electrical Malfunctions
| Malfunction | Trigger | Effect |
|-------------|---------|--------|
| Electrical Cutout | Low electrical health | Temporary loss of all electrical systems |
| Gauge Failures | Electrical issues | Instrument readings become unreliable |
| Light Flickering | Electrical issues | Headlights/work lights flicker or fail |

#### Hydraulic Malfunctions
| Malfunction | Trigger | Effect |
|-------------|---------|--------|
| Hydraulic Drift | Low fluid | Implements slowly lower when raised |
| Hydraulic Surge | Fluid <60% | Sudden steering loss 5-15 seconds |
| Implement Surge | Low fluid | Sudden unexpected implement movements |
| PTO Toggle | Hydraulic issues | Power take-off randomly engages/disengages |
| Hitch Failure | Hydraulic issues | Attachments may unexpectedly disconnect |

#### Advanced Hydraulic (Severe)
| Malfunction | Trigger | Effect |
|-------------|---------|--------|
| **Runaway Engine** | Oil AND hydraulic <10% | **Speed 150%, brakes 40%** |
| Implement Stuck Down | Hydraulic <25% | Cannot raise for 45+ seconds |
| Implement Stuck Up | Hydraulic <25% | Cannot lower for 45+ seconds |
| Implement Pull | Low hydraulic | Asymmetric drag causes steering pull |
| Implement Drag | Hydraulic <35% | Max speed reduced to 60% |
| Reduced Turning | Low hydraulic | Power steering failure, turning 65% |

#### Tire & Fuel Malfunctions
| Malfunction | Trigger | Effect |
|-------------|---------|--------|
| Flat Tire | Wear, damage | Sudden failure with steering pull |
| Slow Leak | Tire damage | Gradual pressure loss |
| Blowout | High-speed + worn tire | Catastrophic failure |
| Fuel Leak | Damage | Tank slowly drains |

**Runaway Engine** is the signature failure. Neglect both oil AND hydraulic fluid below 10%, and your tractor accelerates uncontrollably at 150% speed with brakes at 40% effectiveness. Good luck stopping.

---

### Deep Mod Integration (Not Just "Compatible")

#### Real Vehicle Breakdowns (RVB)

DNA creates a unified reliability system with RVB:

| DNA Type | RVB Part Lifetime Multiplier | Repair Degradation |
|----------|------------------------------|-------------------|
| Lemon | 0.6x (parts fail faster) | 2% ceiling loss per repair |
| Average | 1.0x (normal) | 1% ceiling loss |
| Workhorse | 1.4x (parts last longer) | 0.4% ceiling loss |
| Legendary | 1.4x | **0% - immune** |

Breakdowns also damage the ceiling: Lemons take full damage (3-8%), legendaries take only 30%.

#### Use Your Tyres (UYT)

DNA and tire quality create a unified wear system:

| Factor | Wear Rate |
|--------|-----------|
| Retread Tires | 2.0x (wear twice as fast) |
| Normal Tires | 1.0x |
| Quality Tires | 0.67x (wear 33% slower) |
| Lemon DNA | 1.4x multiplier |
| Workhorse DNA | 0.6x multiplier |

A workhorse with quality tires: 0.67 × 0.6 = **0.4x wear rate**
A lemon with retread tires: 2.0 × 1.4 = **2.8x wear rate**

Per-wheel wear displays in Tires Dialog. Tire replacement syncs with UYT.

---

### OBD Scanner: One-Time Strategic Decision

The Field Service Kit ($5,000) provides emergency field diagnostics with a twist:

**The Catch:** Each vehicle system (Engine, Electrical, Hydraulic) can only be diagnosed **once** per vehicle. After that: *"This system has already received field service. Further repairs require workshop equipment."*

**Field repair cap:** 80% reliability maximum (or vehicle's aging ceiling, whichever is lower).

**Diagnostic minigame:** Identify the root cause from 4 options. Correct = 8-15% boost. Wrong = 1-3% boost. Choose wisely - you only get one shot per system.

---

### Service Truck: The Ceiling Saver

The OBD Scanner is great for quick field repairs - but it can't fix that lemon's degraded ceiling. For that, you need the **Service Truck**.

**But here's the twist:** The Service Truck isn't in the shop. You have to **discover** it.

| Aspect | OBD Scanner | Service Truck |
|--------|-------------|---------------|
| Item Type | Hand tool ($5,000) | Driveable vehicle ($67,500) |
| Availability | Always in shop | **Must be discovered** |
| Duration | Instant | Hours/days of game time |
| Max Restoration | 80% cap | **100% possible** |
| Ceiling Repair | No | **YES (unique feature)** |
| Payment | Any | **CASH ONLY** |

#### How to Discover It

The Service Truck becomes available through your **National Agent network** - but only when you've proven yourself:

**Prerequisites (ALL required):**
1. ✅ **3+ OBD Scanner uses** - you understand the repair system
2. ✅ **700+ credit score** - you're a serious customer
3. ✅ **Own a vehicle with ceiling < 90%** - you've felt the pain of degradation

**When you complete a National Agent transaction (buy or sell):**
- 20% chance your agent mentions "a connection"
- A retiring mechanic with a fully-equipped service truck
- **Cash only deal** - $67,500 (10% connection discount)
- Accept now, or save the opportunity for up to 30 days

*After 10 eligible transactions without discovery, the pity timer guarantees it.*

#### Why This Design?

The Service Truck is the **endgame tool**. If it were in the shop from day one:
- Players would skip the OBD Scanner entirely
- Ceiling degradation would be meaningless
- The lemon/workhorse dynamic loses its bite

By gating it behind prerequisites, you **earn** the ability to save your lemons. You've built credit, fixed vehicles the hard way, and worked with premium agents. NOW you get access to the premium tool.

#### How Restoration Works

1. **Park near target** - Drive the service truck within 10m of a damaged vehicle
2. **Inspection minigame** - Pass the diagnostic quiz to prove you can handle the job
3. **Restoration begins** - Target vehicle is immobilized (wheels off, can't drive)
4. **Time passes** - 1% reliability per game hour, 0.25% ceiling per hour
5. **Keep it fueled** - Truck consumes diesel/oil/hydraulic + spare parts pallets nearby
6. **Completion** - Vehicle restored, wheels back on, good as new

#### The Risk

If fluids run out during restoration:
- Work pauses immediately
- Warning notifications appear
- **If ignored too long:** target vehicle takes damage

#### Why This Matters

That legendary workhorse with DNA 0.95? Perfect candidate - minimal degradation, maintains peak performance forever with proper care.

That lemon with DNA 0.15? **Now salvageable.** The Service Truck can restore its ceiling back to 100%, giving it a second chance. You can turn a money pit into a usable machine.

**The ceiling restoration is the killer feature.** Nothing else in UsedPlus can repair a degraded reliability ceiling.

---

### Tire Quality Tiers

| Tier | Cost | Traction | Failure Rate | Wear Rate | Starting Wear |
|------|------|----------|--------------|-----------|---------------|
| **Retread** | 40% | 85% | 3x | 2x | +35% worn |
| **Normal** | 100% | 100% | 1x | 1x | Baseline |
| **Quality** | 150% | 110% | 0.5x | 0.67x | -15% (starts fresher) |

Retreads are cheap but risky. Quality tires cost more but last longer and grip better.

---

## Quick Start

### Getting Equipment

| Action | How | What It Does |
|--------|-----|--------------|
| **Buy/Finance/Lease** | Shop buy buttons | Opens Unified Purchase Dialog with all options |
| **Search Used** | Press **U** in shop | Find discounted pre-owned equipment |
| **Trade-In** | Inside purchase dialog | Apply old equipment value toward purchase |

### Managing Your Farm

| Action | How |
|--------|-----|
| **Finance Manager** | **Shift+F** anywhere, or ESC Menu |
| **Repair/Repaint** | Click owned vehicle on map |
| **Buy/Lease Land** | Click unowned field on map |

### In the Finance Manager

- View all active deals (vehicles, land, loans)
- Check your credit score and history
- Make payments (skip, minimum, standard, extra, custom)
- Accept or decline incoming sale offers
- Early payoff with interest savings

---

## Supported Languages

UsedPlus is fully translated into **15 languages**:

| Language | Code | Status |
|----------|------|--------|
| English | en | Complete (primary) |
| German | de | Complete |
| French | fr | Complete |
| Spanish | es | Complete |
| Italian | it | Complete |
| Portuguese (Brazil) | br | Complete |
| Portuguese (Portugal) | pt | Complete |
| Polish | pl | Complete |
| Czech | cz | Complete |
| Russian | ru | Complete |
| Ukrainian | uk | Complete |
| Dutch | nl | Complete |
| Hungarian | hu | Complete |
| Turkish | tr | Complete |
| Japanese | jp | Complete |

This matches or exceeds the language support of other major FS25 mods like [Courseplay](https://github.com/Courseplay/Courseplay_FS25).

**Translation Contributions Welcome!** If you notice any translation issues or want to help improve localization, please submit feedback on [GitHub](https://github.com/XelaNull/FS25_UsedPlus).

---

## Installation

1. Download `FS25_UsedPlus.zip`
2. Place in your mods folder:
   - **Windows:** `Documents\My Games\FarmingSimulator2025\mods\`
   - **Mac:** `~/Library/Application Support/FarmingSimulator2025/mods/`
3. Enable in mod selection
4. Start farming smarter

> Keep either the folder OR the ZIP, not both.

---

## Deep Dive Reference

### Used Marketplace Agents

| Agent | Fee | Search Time | Success Rate | Typical Discount |
|-------|-----|-------------|--------------|------------------|
| Local | 2% | 1-2 months | 85% | 25-40% off |
| Regional | 4% | 2-4 months | 90% | 15-30% off |
| National | 6% | 3-6 months | 95% | 5-20% off |

Used equipment comes with history - damage, wear, operating hours. That "great deal" might need $15,000 in repairs. **Get an inspection before buying.**

> Available for vehicles and implements worth **$10,000+**

### Selling Your Equipment

| Method | Return | Time |
|--------|--------|------|
| Trade-In | 50-65% | Instant |
| Local Agent | 60-75% | 1-2 months |
| Regional Agent | 75-90% | 2-4 months |
| National Agent | 90-100% | 3-6 months |

When a buyer is found, you receive an offer notification. Accept or wait for better.

### Land Leasing

| Term | Monthly Markup |
|------|----------------|
| 1 year | +20% |
| 3 years | +15% |
| 5 years | +10% |
| 10 years | +5% |

- **Buyout Option:** Convert to ownership with progress-based discount (up to 15% off)
- **Warning:** 3 missed payments = seizure + credit damage
- **Expiration Warnings:** At 3 months, 1 month, and 1 week before end

### Payment Flexibility

| Mode | Effect | Credit Impact |
|------|--------|---------------|
| Skip | Balance grows (negative amortization) | -25 points |
| Minimum | Interest only | Neutral |
| Standard | Normal payment | +5 points |
| Extra (2x) | Pay faster, save interest | +5 points |
| Custom | You decide the amount | Varies |

---

## Settings & Configuration

Access via **ESC > Settings > UsedPlus**

| Setting | Options | Purpose |
|---------|---------|---------|
| Override Shop Buy/Lease | On/Off | Disable if conflicts with other mods |
| Override RVB Repair | On/Off | Disable if RVB conflicts |
| Paint Cost Multiplier | 0.25x - 2.0x | Adjust repaint pricing |
| Enable Financing | On/Off | Toggle vehicle financing |
| Enable Leasing | On/Off | Toggle vehicle leasing |
| Enable Land Finance | On/Off | Toggle land financing |
| Enable Land Lease | On/Off | Toggle land leasing |
| Malfunction Frequency | 25% - 200% | How often malfunctions occur |

### Difficulty Presets

| Preset | Interest | Costs | Malfunctions |
|--------|----------|-------|--------------|
| Easy | Lower | Reduced | 25% frequency |
| Challenging | Normal | Normal | 125% frequency |
| Hardcore | Higher | Increased | 200% frequency |

---

## Compatibility

### Deep Integrations

| Mod | Integration | Download |
|-----|-------------|----------|
| **Real Vehicle Breakdowns** | DNA affects part lifetimes (0.6x-1.4x), repair/breakdown degradation | [GitHub](https://github.com/MathiasHun/FS25_Real_Vehicle_Breakdowns_Beta) |
| **Use Your Tyres** | DNA and quality affect wear rates, per-wheel display, two-way sync | [ModHub](https://www.farming-simulator.com/mod.php?mod_id=321793&title=fs2025) |

### Works With

| Mod | Integration | Download |
|-----|-------------|----------|
| **EnhancedLoanSystem** | ELS loans display in Finance Manager with "ELS" marker | [ModHub](https://www.farming-simulator.com/mod.php?mod_id=314906&title=fs2025) |
| **HirePurchasing** | HP leases display in Finance Manager with "HP" marker | [ModHub](https://www.farming-simulator.com/mod.php?mod_id=327821&title=fs2025) |
| **Employment** | Worker wages included in monthly obligations | [ModHub](https://www.farming-simulator.com/mod.php?mod_id=314808&title=fs2025) |
| **BuyUsedEquipment** | UsedPlus hides Search when BUE is active | [ModHub](https://www.farming-simulator.com/mod.php?mod_id=312631&title=fs2025) |

### Also Recommended

| Mod | Description | Download |
|-----|-------------|----------|
| **Courseplay** | AI worker automation - the gold standard | [ModHub](https://www.farming-simulator.com/mod.php?mod_id=331515&title=fs2025) / [GitHub](https://github.com/Courseplay/Courseplay_FS25) |
| **AutoDrive** | Automated driving routes and logistics | [GitHub](https://github.com/Stephan-S/FS25_AutoDrive) |
| **EnhancedVehicle** | Better HUD, diff locks, parking brake | [GitHub](https://github.com/ZhooL/FS25_EnhancedVehicle) |

### Known Conflicts

| Mod | Issue | Solution |
|-----|-------|----------|
| **AdvancedMaintenance** | Both track vehicle condition | Use one or the other |

---

## FAQ

**Why doesn't "Search Used" appear?**
> Only available for vehicles/implements worth $10,000+. Small tools use standard shop.

**Why can't I select a 15-year term?**
> Vehicle terms above 10 years require Good credit (700+). Land can go up to 30 years with Excellent credit.

**Why won't the seller negotiate?**
> Workhorse owners (DNA 0.90+) are "immovable" - they know what they have. That's often a good sign.

**I offered 70% and the seller walked away permanently. What happened?**
> Offers >20% below threshold trigger permanent walk-away. That listing is gone forever.

**How do I know if a vehicle is a lemon?**
> Get a mechanic inspection. Listen for phrases like "burn some sage" or "gremlins." Watch for desperate sellers.

**Why does my legendary workhorse still break down?**
> DNA affects degradation, not immunity to malfunctions. Maintain your fluids!

**Does this work in multiplayer?**
> Yes - full multiplayer support with server-authoritative transactions.

**Another mod conflicts with Buy button. Help?**
> Disable "Override Shop Buy/Lease" in Settings. Use the "Finance" button instead.

---

## For Mod Developers

UsedPlus provides a public API:

```lua
if UsedPlusAPI and UsedPlusAPI.isReady() then
    local score = UsedPlusAPI.getCreditScore(farmId)        -- 300-850
    local dna = UsedPlusAPI.getVehicleDNA(vehicle)          -- 0.0-1.0
    local canFinance = UsedPlusAPI.canFinance(farmId, "VEHICLE_FINANCE")
end
```

Register external loans with our credit bureau:

```lua
local externalId = UsedPlusAPI.registerExternalDeal("MyMod", loanId, farmId, {
    dealType = "loan",
    originalAmount = 50000,
    monthlyPayment = 2500,
})
UsedPlusAPI.reportExternalPayment(externalId, 2500)  -- Builds credit!
```

Full documentation: [docs/mod-api.md](docs/mod-api.md)

---

## Credits

### The Team

| Role | Contributor |
|------|-------------|
| Vision, Direction, Testing | (Human) |
| Architecture, Code, Implementation | **Claude** (AI Developer) |
| UX Design, Edge Cases, Review | **Samantha** (AI Co-Creator) |

### Pattern Sources

Built on the shoulders of giants:

| Mod | Patterns Learned | Download |
|-----|------------------|----------|
| **EnhancedLoanSystem** | Credit scoring, financial math | [ModHub](https://www.farming-simulator.com/mod.php?mod_id=314906&title=fs2025) |
| **BuyUsedEquipment** | Async search, marketplace architecture | [ModHub](https://www.farming-simulator.com/mod.php?mod_id=312631&title=fs2025) |
| **HirePurchasing** | Balloon payments, data extensions | [ModHub](https://www.farming-simulator.com/mod.php?mod_id=327821&title=fs2025) |
| **Real Vehicle Breakdowns** | Part-based failure systems | [GitHub](https://github.com/MathiasHun/FS25_Real_Vehicle_Breakdowns_Beta) |
| **Use Your Tyres** | Per-wheel tracking patterns | [ModHub](https://www.farming-simulator.com/mod.php?mod_id=321793&title=fs2025) |
| **PowerTools** (w33zl) | Hand tool patterns | [ModHub](https://www.farming-simulator.com/mod.php?mod_id=303451&title=fs2025) |
| **Courseplay** | AI worker patterns | [ModHub](https://www.farming-simulator.com/mod.php?mod_id=331515&title=fs2025) / [GitHub](https://github.com/Courseplay/Courseplay_FS25) |

### Special Thanks

- **w33zl** for BuyUsedEquipment and MobileServiceKit
- **Gian FS** for Fuel Barrel model (adapted for Oil Barrel)
- **WMD Modding** for FuelTanksPack (adapted for Oil Tank)
- **Canada FS** for GMC C7000 Service 81-89 model (adapted for Service Truck)

---

## License

**Open for the community.**

- Download, use, study, modify, fork, share
- Copy patterns for your own projects
- Translations welcome

**Please don't:**
- Sell this mod
- Claim you created the original
- Remove credits

---

**v2.9.5** | See [CHANGELOG.md](CHANGELOG.md) for version history

---

*Stop asking "Can I afford it?" Start asking "Is this the right financial decision?"*
