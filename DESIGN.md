# FS25_UsedPlus - Comprehensive Mod Design & Implementation Guide

**Version:** 2.7.0
**Last Updated:** 2026-01-17

---

## Table of Contents

1. [Overview](#overview)
2. [Feature Specifications](#feature-specifications)
   - [Finance System](#1-finance-system) ✅ IMPLEMENTED
   - [Credit Score System](#2-credit-score-system) ✅ IMPLEMENTED
   - [Search Used System](#3-search-used-system) ✅ IMPLEMENTED
   - [Vehicle Sales System](#4-vehicle-sales-system) ✅ IMPLEMENTED
   - [Lease System](#5-lease-system) ✅ IMPLEMENTED
   - [Land Financing](#6-land-financing) ✅ IMPLEMENTED
   - [Land Leasing](#7-land-leasing) ✅ IMPLEMENTED
   - [General Loan System](#8-general-loan-system) ✅ IMPLEMENTED
   - [Partial Repair & Repaint](#9-partial-repair--repaint-system) ✅ IMPLEMENTED
   - [Trade-In System](#10-trade-in-system) ✅ IMPLEMENTED
   - [Finance Manager GUI](#11-finance-manager-gui) ✅ IMPLEMENTED
   - [Financial Dashboard](#12-financial-dashboard) ✅ IMPLEMENTED
   - [Payment Configuration](#13-payment-configuration-system) ✅ IMPLEMENTED
   - [Vehicle Maintenance System](#14-vehicle-maintenance-system) ✅ IMPLEMENTED
   - [Field Service Kit](#15-field-service-kit) ✅ IMPLEMENTED
   - [Vehicle Malfunctions](#16-vehicle-malfunctions) ✅ IMPLEMENTED
   - [Cross-Mod Compatibility](#17-cross-mod-compatibility-system) ✅ IMPLEMENTED
   - [Negotiation System](#18-negotiation-system) ✅ IMPLEMENTED (v2.6.0)
   - [Vehicle DNA System](#19-vehicle-dna-system) ✅ IMPLEMENTED (v2.6.0)
   - [Used Vehicle Inspection](#20-used-vehicle-inspection-system) ✅ IMPLEMENTED
3. [Technical Architecture](#technical-architecture)
4. [Implementation Status](#implementation-status)

---

## Overview

**FS25_UsedPlus** is a comprehensive financial expansion mod for Farming Simulator 2025 that transforms the built-in vehicle shop into a realistic dealership experience.

### Core Systems

| System | Description | Status |
|--------|-------------|--------|
| **Finance System** | Purchase vehicles/equipment with flexible payment plans (1-15 years) | ✅ Complete |
| **Credit Score** | FICO-like scoring (300-850) based on financial behavior | ✅ Complete |
| **Used Vehicle Search** | Agent-based search (Local/Regional/National) for used equipment | ✅ Complete |
| **Vehicle Sales** | Agent-based selling replaces vanilla instant-sell | ✅ Complete |
| **Lease System** | Balloon payment leases integrated into Unified Purchase Dialog | ✅ Complete |
| **Land Financing** | Finance land purchases with lower rates | ✅ Complete |
| **Land Leasing** | Lease farmland with monthly payments, buyout option | ✅ Complete |
| **General Loans** | Collateral-based cash loans | ✅ Complete |
| **Repair/Repaint** | Partial repair with quick buttons and finance option | ✅ Complete |
| **Trade-In** | Trade existing vehicles toward new purchases | ✅ Complete |
| **Finance Manager** | ESC menu for managing all financial deals | ✅ Complete |
| **Dashboard** | Comprehensive financial overview with credit history | ✅ Complete |
| **Maintenance** | Three-component reliability (engine, electrical, hydraulic) | ✅ Complete |
| **Field Service Kit** | Multi-mode OBD diagnostic tool for emergency field repairs | ✅ Complete |
| **Malfunctions** | Realistic breakdowns based on component health | ✅ Complete |
| **Payment Config** | Per-loan payment customization (skip, min, extra) | ✅ Complete |
| **Cross-Mod Compat** | Deep integration with RVB, UYT; feature deferral for ELS/HP/BUE | ✅ Complete |
| **Negotiation** | Counter-offer system with seller personalities and weather effects | ✅ Complete |
| **Vehicle DNA** | Hidden quality trait (0.0-1.0) affecting long-term reliability | ✅ Complete |
| **Inspection** | Pre-purchase inspection revealing hidden condition | ✅ Complete |

### Core Philosophy

- **Realism First** - Real-world financial calculations (interest rates, credit scores, depreciation)
- **Player Choice** - Multiple options at every decision point
- **Risk/Reward** - Better deals for better credit, risks in used equipment searches
- **Integration** - Seamless integration with base game shop and finance systems
- **Replace, Don't Coexist** - Replace vanilla systems entirely (like sales) for consistency

---

## Feature Specifications

### 1. Finance System

**Status:** ✅ FULLY IMPLEMENTED

Finance any vehicle or equipment with flexible terms.

#### Key Features
- Term range: 1-15 years (credit-gated: 1-5 any, 6-10 Fair+, 11-15 Good+)
- Down payment: 0-50%
- Interest rates based on credit score and term
- Monthly automatic payments via HOUR_CHANGED subscription
- Early payoff with prepayment penalty calculation
- Full multiplayer support with network events

#### Technical Implementation
- `FinanceDeal.lua` - Data class with amortization calculations
- `UnifiedPurchaseDialog.lua` - Shop integration dialog (combines Cash/Finance/Lease)
- `FinanceVehicleEvent.lua` - Network event for creating deals
- `FinancePaymentEvent.lua` - Network event for manual payments

#### Amortized Loan Payment Formula
```
P = Principal (amount financed)
r = Monthly interest rate (annual rate / 12)
n = Number of months

M = P × [r(1 + r)^n] / [(1 + r)^n - 1]
```

---

### 2. Credit Score System

**Status:** ✅ FULLY IMPLEMENTED (Enhanced beyond original design)

FICO-like scoring system that affects interest rates and loan availability.

#### Credit Score Range: 300-850

| Rating | Score Range | Interest Adjustment |
|--------|-------------|---------------------|
| Excellent | 750-850 | -1.5% |
| Good | 700-749 | -0.5% |
| Fair | 650-699 | +0.5% |
| Poor | 600-649 | +1.5% |
| Very Poor | <600 | +3.0% |

#### Score Factors
- **Debt-to-Asset Ratio** - Primary factor
- **Payment History** - On-time (+5), Missed (-25), Payoff (+50)
- **Trend Tracking** - Visual indicator (Up/Down/Stable)

#### Technical Implementation
- `CreditScore.lua` - Score calculation logic
- `CreditHistory.lua` - Historical tracking for trends
- Score persists in savegame per farm

---

### 3. Search Used System

**Status:** ✅ FULLY IMPLEMENTED

Agent-based search for used equipment with 3-tier system.

#### Agent Tiers

| Tier | Fee | Time Frame | Success Rate | Discount Range |
|------|-----|------------|--------------|----------------|
| Local | 2% of base | 1-2 months | 85% | 25-40% off |
| Regional | 4% of base | 2-4 months | 90% | 15-30% off |
| National | 6% of base | 3-6 months | 95% | 5-20% off |

#### Minimum Price Threshold
- **$10,000** minimum item price for Search Used availability
- Consumables (seeds, fertilizers) use standard shop flow

#### Mechanics
- TTL (Time To Live) / TTS (Time To Success) countdown
- Probabilistic customization matching per configuration option
- Depreciation based on generation (age, damage, wear, hours)
- Success/failure notifications

#### Technical Implementation
- `UsedVehicleSearch.lua` - Search data class
- `UsedVehicleManager.lua` - Queue processing
- `UsedSearchDialog.lua` - Tier selection dialog
- `RequestUsedItemEvent.lua` / `UsedItemFoundEvent.lua` - Network events

---

### 4. Vehicle Sales System

**Status:** ✅ FULLY IMPLEMENTED

Replaces vanilla instant-sell with agent-based marketplace.

#### Agent Tiers (Selling)

| Tier | Fee | Time Frame | Success Rate | Return Range |
|------|-----|------------|--------------|--------------|
| Local | $50 | 1-2 months | 85% | 60-75% |
| Regional | $200 | 2-4 months | 90% | 75-90% |
| National | $500 | 3-6 months | 95% | 90-100% |

#### Value Hierarchy
1. **Trade-In** (50-65%, instant) - Lowest return, fastest
2. **Local Agent** (60-75%, 1-2 months)
3. **Regional Agent** (75-90%, 2-4 months)
4. **National Agent** (90-100%, 3-6 months) - Highest return, slowest

#### Technical Implementation
- `VehicleSaleListing.lua` - Sale listing data class
- `VehicleSaleManager.lua` - Listing management
- `SellVehicleDialog.lua` - Agent selection
- `SaleOfferDialog.lua` - Accept/decline offers
- `InGameMenuVehiclesFrameExtension.lua` - Hook sell button

---

### 5. Lease System

**Status:** ✅ FULLY IMPLEMENTED (Integrated into Unified Purchase Dialog)

#### Implementation Approach
Leasing is integrated into the **Unified Purchase Dialog** alongside Cash and Finance options, rather than replacing the game's lease system separately.

#### Features
- Custom lease terms (1-5 years)
- Lower down payment max (20% vs 50% for finance)
- Residual value (balloon payment) calculation
- Vehicle marked as "LEASED" - cannot sell
- Damage penalties at lease end
- Early termination with fee
- Credit score affects lease rates

#### Lease Payment Formula (Balloon)
```
P = Price - Down Payment
FV = Residual Value (balloon)
r = Monthly interest rate
n = Term in months

M = (P - FV/(1+r)^n) * [r(1+r)^n] / [(1+r)^n - 1]
```

#### Residual Value by Term
| Term | Residual |
|------|----------|
| 1-2 years | 65% |
| 3 years | 55% |
| 4 years | 45% |
| 5 years | 35% |

#### Technical Implementation
- `LeaseDeal.lua` - Data class with balloon calculations
- `UnifiedPurchaseDialog.lua` - Combined Cash/Finance/Lease dialog
- `LeaseVehicleEvent.lua` - Network event
- `TerminateLeaseEvent.lua` - Early termination

---

### 6. Land Financing

**Status:** ✅ FULLY IMPLEMENTED

Finance farmland purchases with lower interest rates.

#### Features
- Lower base rate (3.5% vs 4.5% for vehicles)
- Longer terms available (up to 30 years)
- Down payment: 0-40%
- Land ownership transfers immediately
- 3 missed payments = land seizure + credit damage

#### Technical Implementation
- `UnifiedLandPurchaseDialog.lua` - Combined Cash/Finance/Lease dialog
- `FarmlandManagerExtension.lua` - Hook land purchase

---

### 7. Land Leasing

**Status:** ✅ FULLY IMPLEMENTED

Lease farmland instead of purchasing outright.

#### Features
- Lease land for 1, 3, 5, or 10-year terms
- Shorter terms have higher markup rates (20% for 1 year, 5% for 10 years)
- Monthly lease payments automatically deducted
- Expiration warnings at 3 months, 1 month, and 1 week before end
- Land reverts to NPC ownership upon lease expiration
- Lease renewal option available before expiration
- Option to buy out lease (convert to purchase) with discount

#### Lease Terms
| Term | Markup Rate | Buyout Discount |
|------|-------------|-----------------|
| 1 year | 20% | 0% |
| 3 years | 12% | 5% |
| 5 years | 8% | 10% |
| 10 years | 5% | 15% |

#### Technical Implementation
- `LandLeaseDialog.lua` - Lease configuration dialog
- `UnifiedLandPurchaseDialog.lua` - Combined Cash/Finance/Lease selection
- `InGameMenuMapFrameExtension.lua` - Map context menu integration

---

### 8. General Loan System

**Status:** ✅ FULLY IMPLEMENTED

Collateral-based cash loans against farm assets.

#### Features
- Access from Finance Manager > "Take Loan" button
- Collateral: 50% of vehicle value + 60% of land value
- Credit score affects max loan and interest rate
- Dropdown selection for amount (% of max) and term
- Real-time payment preview
- Annuity-based repayment

#### Technical Implementation
- `TakeLoanDialog.lua` - Loan configuration
- `TakeLoanEvent.lua` - Network event
- Uses `FinanceDeal` with `dealType = 3` (loan)

---

### 9. Partial Repair & Repaint System

**Status:** ✅ FULLY IMPLEMENTED

Replace game's repair dialog with custom partial repair.

#### Features
- Quick percentage buttons: 25%, 50%, 75%, 100%
- Separate dialogs for repair and repaint
- Real-time cost calculation
- Option to finance repair costs
- Works at all dealers/workshops
- **v2.7.0:** Workshop charges extra for fuel leak (+2% vehicle price) and flat tire (+1% vehicle price) repairs

#### Technical Implementation
- `RepairDialog.lua` - Repair configuration
- `RepairFinanceDialog.lua` - Finance repair option
- `RepairVehicleEvent.lua` - Network event
- `VehicleSellingPointExtension.lua` - Workshop hook

---

### 10. Trade-In System

**Status:** ✅ FULLY IMPLEMENTED

Trade existing vehicles toward new purchases.

#### Features
- Trade-in value: 50-65% of vanilla sell price
- 5% bonus for same-brand purchases
- Condition affects value (damage/wear multipliers)
- Shows vehicle condition before trade
- Only non-financed, owned vehicles eligible

#### Value Calculation
```
Base = Vanilla Sell Price × 0.50 to 0.65
Brand Bonus = +5% if same brand
Condition = × (1 - damage × 0.3) × (1 - wear × 0.2)
Final = Base × Brand Bonus × Condition
```

#### Technical Implementation
- `TradeInDialog.lua` - Vehicle selection
- `TradeInCalculations.lua` - Value calculation

---

### 11. Finance Manager GUI

**Status:** ✅ FULLY IMPLEMENTED

ESC menu for managing all financial operations.

#### Features
- Overview of all active deals (finance, lease, loan)
- Summary statistics (total debt, monthly obligations)
- Detail view with payment options
- Quick buttons: 1 month, 6 months, 1 year, payoff
- Active sale listings section
- Take Loan button
- Hotkey: Shift+F

#### Technical Implementation
- `FinanceManagerFrame.lua` - Main screen
- `FinanceDetailFrame.lua` - Payment screen
- `InGameMenuMapFrameExtension.lua` - ESC menu integration

---

### 12. Financial Dashboard

**Status:** ✅ FULLY IMPLEMENTED

Comprehensive financial overview.

#### Features
- Credit score with trend indicator
- Credit history timeline
- Debt-to-asset ratio meter
- Monthly obligations breakdown by type
- Upcoming payments list

#### Technical Implementation
- `FinancialDashboard.lua` - Dashboard screen

---

### 13. Payment Configuration System

**Status:** ✅ FULLY IMPLEMENTED

Allow players to customize payment amounts per loan.

#### Payment Options

| Payment Type | Description | Credit Impact |
|--------------|-------------|---------------|
| **Skip** | No payment, balance grows (negative amortization) | -25 |
| **Minimum** | Interest-only payment, balance unchanged | 0 |
| **Standard** | Original amortized payment | +5 |
| **1.5x Extra** | 50% extra reduces principal faster | +5 |
| **2x Extra** | Double payment for aggressive payoff | +5 |
| **Custom** | Player-specified amount | Varies |

#### Minimum Payment Formula
```
Minimum = Current Balance × (Annual Rate / 12)
```
This is the interest-only amount. Paying only this keeps balance unchanged but avoids default.

#### Technical Implementation
- Payment multiplier stored in `FinanceDeal.paymentMultiplier`
- `SetPaymentConfigEvent.lua` - Multiplayer sync
- Accessed via Finance Manager → Deal Details → Configure Payment button

---

### 14. Vehicle Maintenance System

**Status:** ✅ FULLY IMPLEMENTED

Comprehensive reliability and maintenance system for vehicles.

#### Three-Component Reliability
- **Engine Health**: Affects power output, fuel efficiency, and starting reliability
- **Electrical Health**: Impacts lights, gauges, and electronic systems
- **Hydraulic Health**: Controls implement lift, steering assist, and attachments

#### Fluid Systems
- **Engine Oil**: Depletes with use, low oil causes engine damage
- **Hydraulic Fluid**: Powers implements and steering
- **Fuel**: Fuel leaks drain tank over time when detected

#### Tire System
- Three tire quality tiers: Retread, Normal, Quality
- Tire tread wears over time based on usage and terrain
- Worn tires reduce traction and increase slip
- Flat tires cause steering pull and reduce max speed

#### Technical Implementation
- `UsedPlusMaintenance.lua` - Vehicle specialization
- `MaintenanceReportDialog.lua` - Owned vehicle maintenance view
- `FluidsDialog.lua` - Fluid service interface
- `TiresDialog.lua` - Tire service interface

---

### 15. Field Service Kit

**Status:** ✅ FULLY IMPLEMENTED (v2.7.0 Multi-Mode)

Portable emergency repair system with OBD diagnostic capabilities.

#### Kit Tiers

| Tier | Price | Reliability Boost | Diagnosis Accuracy |
|------|-------|-------------------|-------------------|
| **Basic** | $5,000 | 15-25% | Standard readings |
| **Professional** | $12,000 | 20-35% | Enhanced readings |
| **Master** | $25,000 | 30-50% | Complete diagnostics |

#### OBD Scanner Modes (v2.7.0)

| Mode | Function |
|------|----------|
| **Diagnose Component** | Original diagnostic minigame for engine/electrical/hydraulic |
| **Locate Malfunctions** | Quick view of all active malfunctions |
| **Tire Service** | Per-wheel inspection and repair options |
| **RVB System Analysis** | Detailed RVB part inspection (only visible when RVB installed) |

#### Gameplay Flow
1. Player buys Field Service Kit from shop
2. Player carries kit to vehicle (it's a hand tool)
3. Player activates kit - OBD scanner dialog opens
4. **Mode Selection**: Choose diagnostic mode
5. **Diagnose Component**:
   - System Selection: Engine, Electrical, or Hydraulic
   - OBD Diagnostic Reading: 3 codes/readings displayed
   - Diagnosis Choice: Pick from 4 possible diagnoses
   - Outcome: Correct diagnosis = better repair outcome
6. Kit is consumed regardless of outcome (single use)

#### Technical Implementation
- `DiagnosisData.lua` - Scenario definitions, outcome calculations
- `FieldServiceKit.lua` - Vehicle specialization (hand tool)
- `FieldServiceKitDialog.lua` - Multi-step diagnostic dialog with mode selection
- `fieldServiceKit.xml` - Store item definition

---

### 16. Vehicle Malfunctions

**Status:** ✅ FULLY IMPLEMENTED

Realistic breakdown events based on component health.

#### Hydraulic Malfunctions (Signature Feature)

| Malfunction | Trigger | Effect |
|-------------|---------|--------|
| **Runaway Engine** | Oil AND hydraulic <10% | Speed 150%, brakes 40% |
| **Implement Stuck** | Hydraulic <25% | Can't raise/lower |
| **Hydraulic Surge** | Hydraulic <60% | Sudden steering pull |
| **Implement Drag** | Hydraulic <35% | Max speed 60% |

#### Engine Malfunctions
- **Overheating**: Engine temperature rises, power reduces, eventual stall
- **Misfiring**: Random power fluctuations and rough running
- **Stalling**: Engine cuts out unexpectedly, restart required
- **Hard Starting**: Difficulty starting in cold conditions with worn engine

#### Electrical Malfunctions
- **Electrical Cutout**: Temporary loss of electrical systems
- **Gauge Failures**: Instrument readings become unreliable
- **Light Flickering**: Headlights and work lights flicker or fail

#### Tire Malfunctions
- **Flat Tire**: Sudden tire failure causing steering pull
- **Slow Leak**: Gradual pressure loss over time

#### Fuel System Malfunctions
- **Fuel Leak**: Tank slowly drains fuel when parked or running

---

### 17. Cross-Mod Compatibility System

**Status:** ✅ FULLY IMPLEMENTED (Deep Integration)

Intelligent integration with popular vehicle maintenance and financial mods.

#### Deeply Integrated Mods

| Mod | Integration Type | Details |
|-----|------------------|---------|
| **Real Vehicle Breakdowns** | Full Integration | DNA affects part lifetimes, workshop injection, OBD display |
| **Use Up Your Tyres** | Full Integration | Two-way sync, quality/DNA wear multipliers, per-wheel display |
| **EnhancedLoanSystem** | Deep Integration | Loans display in Finance Manager, Pay Early works |
| **HirePurchasing** | Deep Integration | Leases display in Finance Manager |
| **Employment** | Deep Integration | Worker wages in monthly obligations |

#### Feature Deferral
- **BuyUsedEquipment** - UsedPlus hides Search button, BUE handles used search
- **AdvancedMaintenance** - NOT RECOMMENDED (conflicts with UsedPlus maintenance)

See **COMPATIBILITY.md** for detailed technical analysis.

---

### 18. Negotiation System

**Status:** ✅ FULLY IMPLEMENTED (v2.6.0)

Counter-offer system for used vehicle purchases with seller personalities.

#### Seller Personalities (DNA-Driven)

| Personality | DNA Range | Minimum Acceptance | Behavior |
|-------------|-----------|-------------------|----------|
| **Desperate** | 0.00-0.29 (Lemons) | 75% | Eager to sell, accepts low offers |
| **Motivated** | 0.30-0.49 | 80% | Room to negotiate |
| **Reasonable** | 0.50-0.69 | 85% | Standard negotiation |
| **Firm** | 0.70-0.79 | 92% | Don't lowball |
| **Immovable** | 0.80-1.00 (Workhorses) | 98% | Know what they have |

#### Walk-Away Risk

| Gap Below Threshold | Risk Level | Result |
|---------------------|------------|--------|
| Within 5% | Safe | Always counter |
| 5-10% below | Low | Usually counter |
| 10-15% below | Medium | 50/50 |
| 15-20% below | High | Usually reject |
| >20% below | Insulted | **Permanent walk-away** |

#### Mechanic's Whisper
Before offering, mechanic hints at seller psychology:
- *"They seem pretty eager to sell..."* = Desperate (go low)
- *"Seems like a reasonable person"* = Reasonable
- *"This seller knows exactly what they have"* = Immovable (don't lowball)

#### Weather Effects
Storms make sellers anxious:
- Hail: +12% acceptance bonus
- Storm: +8% acceptance bonus
- Rain/Snow: +5% acceptance bonus

#### Technical Implementation
- `NegotiationDialog.lua` - Counter-offer interface
- `NegotiationCalculations.lua` - Personality/weather effects
- DNA stored on listing, determines personality at search completion

---

### 19. Vehicle DNA System

**Status:** ✅ FULLY IMPLEMENTED (v2.6.0)

Hidden quality trait affecting long-term vehicle reliability.

#### DNA Ranges

| DNA Range | Classification | Long-Term Effect |
|-----------|---------------|------------------|
| 0.00-0.29 | **Lemon** | Repairs make it worse. Death spiral. |
| 0.30-0.69 | Average | Normal degradation |
| 0.70-0.89 | **Workhorse** | Minimal degradation |
| 0.90-1.00 | **Legendary** | IMMUNE to repair degradation |

#### DNA Effects
- **Repair Degradation** - Each repair slightly reduces max reliability (except Legendary)
- **Tire Wear** - Lemons 1.4x faster, Workhorses 0.6x slower (with UYT)
- **RVB Part Wear** - DNA affects RVB part lifetime multipliers
- **Seller Personality** - DNA determines seller behavior in negotiations

#### Mechanic Inspection Hints
- *"I'd burn some sage before driving this one..."* = Lemon
- *"About what you'd expect from the factory"* = Average
- *"In 30 years, I've seen maybe a dozen this well built"* = Legendary

#### Technical Implementation
- DNA assigned at vehicle spawn (new) or search completion (used)
- Stored in `spec_usedPlusMaintenance.vehicleDNA`
- Persists through save/load

---

### 20. Used Vehicle Inspection System

**Status:** ✅ FULLY IMPLEMENTED

Pre-purchase inspection revealing hidden vehicle condition.

#### Inspection Features
- **Visible Stats** - Age, hours, damage, wear (shown in preview)
- **Hidden Stats** - Reliability, DNA hints (revealed by inspection)
- **RVB Part Data** - Component status if RVB installed
- **UYT Tire Data** - Per-wheel condition if UYT installed

#### Inspection Flow
1. Agent finds used vehicle → UsedVehiclePreviewDialog opens
2. Player sees visible stats and "Not Inspected" warning
3. Player can "Buy As-Is" (risk) or "Request Inspection"
4. Inspection fee paid (based on vehicle value)
5. InspectionReportDialog shows full vehicle condition
6. Player makes informed purchase decision

#### Inspection Report Contents
- Overall Reliability Score
- Engine/Electrical/Hydraulic health
- DNA classification hint (mechanic quote)
- RVB component status (if installed)
- Per-wheel tire condition (if UYT installed)
- Estimated repair costs

#### Technical Implementation
- `UsedVehiclePreviewDialog.lua` - Initial preview with visible stats
- `InspectionReportDialog.lua` - Full inspection results
- Pre-generated RVB/UYT data stored on listing

---

## Technical Architecture

### File Structure
```
FS25_UsedPlus/
├── modDesc.xml
├── icon.dds
├── gui/                          # XML dialog definitions
├── src/
│   ├── main.lua                  # Entry point
│   ├── data/                     # Data classes
│   │   ├── CreditHistory.lua
│   │   ├── CreditScore.lua
│   │   ├── FinanceDeal.lua
│   │   ├── LeaseDeal.lua
│   │   ├── UsedVehicleSearch.lua
│   │   └── VehicleSaleListing.lua
│   ├── utils/                    # Calculations
│   │   ├── FinanceCalculations.lua
│   │   ├── DepreciationCalculations.lua
│   │   ├── ConfigurationDetector.lua
│   │   ├── TradeInCalculations.lua
│   │   ├── NegotiationCalculations.lua
│   │   └── ModCompatibility.lua
│   ├── events/                   # Network events (14+ total)
│   ├── managers/
│   │   ├── FinanceManager.lua
│   │   ├── UsedVehicleManager.lua
│   │   └── VehicleSaleManager.lua
│   ├── specializations/
│   │   ├── UsedPlusMaintenance.lua
│   │   └── FieldServiceKit.lua
│   ├── gui/                      # Dialog controllers (15+ total)
│   └── extensions/               # Game hooks (10+ total)
└── translations/
```

### Key Patterns Used
- **MessageDialog** - All dialogs extend MessageDialog
- **Event Pattern** - `Event.sendToServer()` for multiplayer
- **Manager Pattern** - Singletons with HOUR_CHANGED subscription
- **Extension Pattern** - `Utils.appendedFunction` / `Utils.overwrittenFunction`
- **TTL/TTS Queue** - Async operations for searches and sales
- **DNA System** - Hidden quality affecting multiple subsystems

---

## Implementation Status

### Fully Implemented ✅

1. Finance System
2. Credit Score System (enhanced)
3. Used Vehicle Search
4. Vehicle Sales System
5. Lease System (integrated into Unified Purchase Dialog)
6. General Loan System
7. Partial Repair & Repaint
8. Trade-In System
9. Finance Manager GUI
10. Financial Dashboard
11. Payment Configuration System
12. Land Financing
13. Land Leasing
14. Vehicle Maintenance System
15. Vehicle Malfunctions
16. Field Service Kit (with multi-mode v2.7.0)
17. Cross-Mod Compatibility (RVB, UYT, ELS, HP, Employment)
18. Negotiation System with Seller Personalities
19. Vehicle DNA System
20. Used Vehicle Inspection System

### In Progress 🔄

1. **Delayed Inspection System** (v2.7.0) - Time-delayed inspection where player pays, waits game hours, receives notification when ready

### Future Considerations 📋

1. **Inspection Tiers** - Quick/Standard/Comprehensive with different costs, times, and data revealed
2. **Seasonal Pricing** - Equipment prices fluctuate by season
3. **Auction System** - Competitive bidding on rare equipment

---

## Document History

**2026-01-17 (for v2.7.0)** - Comprehensive Status Update
- Updated all feature statuses to reflect current implementation
- Added Section 18: Negotiation System
- Added Section 19: Vehicle DNA System
- Added Section 20: Used Vehicle Inspection System
- Updated Field Service Kit with multi-mode
- Updated Lease System status to IMPLEMENTED
- Updated Payment Configuration status to IMPLEMENTED
- Added delayed inspection to "In Progress"
- Updated technical architecture

**2025-12-28 (for v2.5.0)** - Documentation Sync
- Updated Land Leasing status
- Added Vehicle Maintenance and Malfunctions sections

**2025-11-27 (for v1.8.0)** - Design Document Update
- Added Payment Configuration System design
- Added implemented features not in original design
- Updated lease system approach
- Marked implementation status

**2025-11-21** - Original Comprehensive Design
- Initial comprehensive design document
