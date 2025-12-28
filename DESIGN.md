# FS25_UsedPlus - Comprehensive Mod Design & Implementation Guide

**Version:** 3.2
**Last Updated:** 2025-12-28

---

## Table of Contents

1. [Overview](#overview)
2. [Feature Specifications](#feature-specifications)
   - [Finance System](#1-finance-system) ✅ IMPLEMENTED
   - [Credit Score System](#2-credit-score-system) ✅ IMPLEMENTED
   - [Search Used System](#3-search-used-system) ✅ IMPLEMENTED
   - [Vehicle Sales System](#4-vehicle-sales-system) ✅ IMPLEMENTED
   - [Lease System](#5-lease-system) 🔄 PARTIAL
   - [Land Financing](#6-land-financing) ✅ IMPLEMENTED
   - [Land Leasing](#7-land-leasing) ✅ IMPLEMENTED
   - [General Loan System](#8-general-loan-system) ✅ IMPLEMENTED
   - [Partial Repair & Repaint](#9-partial-repair--repaint-system) ✅ IMPLEMENTED
   - [Trade-In System](#10-trade-in-system) ✅ IMPLEMENTED
   - [Finance Manager GUI](#11-finance-manager-gui) ✅ IMPLEMENTED
   - [Financial Dashboard](#12-financial-dashboard) ✅ IMPLEMENTED
   - [Payment Configuration](#13-payment-configuration-system) ❌ NOT STARTED
   - [Vehicle Maintenance System](#14-vehicle-maintenance-system) ✅ IMPLEMENTED (Phase 5)
   - [Vehicle Malfunctions](#15-vehicle-malfunctions) ✅ IMPLEMENTED (Phase 5)
3. [Technical Architecture](#technical-architecture)
4. [Implementation Status](#implementation-status)

---

## Overview

**FS25_UsedPlus** is a comprehensive financial expansion mod for Farming Simulator 2025 that transforms the built-in vehicle shop into a realistic dealership experience.

### Core Systems

| System | Description | Status |
|--------|-------------|--------|
| **Finance System** | Purchase vehicles/equipment with flexible payment plans (1-30 years) | ✅ Complete |
| **Credit Score** | FICO-like scoring (300-850) based on financial behavior | ✅ Complete |
| **Used Vehicle Search** | Agent-based search (Local/Regional/National) for used equipment | ✅ Complete |
| **Vehicle Sales** | Agent-based selling replaces vanilla instant-sell | ✅ Complete |
| **Lease System** | Custom lease system replacing game's built-in lease | 🔄 Partial |
| **Land Financing** | Finance land purchases with lower rates | ✅ Complete |
| **Land Leasing** | Lease farmland with monthly payments, buyout option | ✅ Complete |
| **General Loans** | Collateral-based cash loans | ✅ Complete |
| **Repair/Repaint** | Partial repair with quick buttons and finance option | ✅ Complete |
| **Trade-In** | Trade existing vehicles toward new purchases | ✅ Complete |
| **Finance Manager** | ESC menu for managing all financial deals | ✅ Complete |
| **Dashboard** | Comprehensive financial overview with credit history | ✅ Complete |
| **Maintenance** | Three-component reliability (engine, electrical, hydraulic) | ✅ Complete |
| **Malfunctions** | Realistic breakdowns based on component health | ✅ Complete |
| **Payment Config** | Per-loan payment customization (skip, min, extra) | ❌ Not Started |

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
- Term range: 1-30 years
- Down payment: 0-50%
- Interest rates based on credit score and term
- Monthly automatic payments via HOUR_CHANGED subscription
- Early payoff with prepayment penalty calculation
- Full multiplayer support with network events

#### Technical Implementation
- `FinanceDeal.lua` - Data class with amortization calculations
- `FinanceDialog.lua` - Shop integration dialog
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

FICO-like scoring system that affects interest rates and loan limits.

#### Credit Score Range: 300-850

| Rating | Score Range | Interest Adjustment |
|--------|-------------|---------------------|
| Excellent | 750-850 | -1.5% |
| Good | 650-749 | -0.5% |
| Fair | 550-649 | +1.0% |
| Poor | 300-549 | +3.0% |

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

#### Workflow
1. Player selects vehicle in ESC > Vehicles
2. UsedPlus dialog replaces vanilla sell dialog
3. Player chooses agent tier
4. Agent fee paid (non-refundable)
5. Wait for buyer offers (shown in Finance Manager)
6. Accept/Decline offers (24 hours to respond)
7. Vehicle removed and money credited on acceptance

#### Technical Implementation
- `VehicleSaleListing.lua` - Sale listing data class
- `VehicleSaleManager.lua` - Listing management
- `SellVehicleDialog.lua` - Agent selection
- `SaleOfferDialog.lua` - Accept/decline offers
- `InGameMenuVehiclesFrameExtension.lua` - Hook sell button
- 4 events: CreateSaleListing, AcceptSaleOffer, DeclineSaleOffer, CancelSaleListing

---

### 5. Lease System

**Status:** 🔄 PARTIAL - Core code exists, needs activation

#### Design Goal
**REPLACE** the game's built-in lease system entirely (like we did with vehicle sales).

#### Why Replace?
- Game's lease is basic rental with no financial depth
- No credit score integration
- No damage/wear tracking
- No early termination handling
- Inconsistent with our financial ecosystem

#### Planned Features
- Custom lease terms (1-5 years)
- Lower down payment max (20% vs 50% for finance)
- Residual value (balloon payment) calculation
- Vehicle marked as "LEASED" - cannot sell
- Damage penalties at lease end
- Early termination with fee
- Credit score affects lease rates
- Vehicle automatically returned at lease end

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

#### Current Implementation Status
- ✅ `LeaseDeal.lua` - Complete with balloon calculations
- ✅ `LeaseDialog.lua` - Complete
- ✅ `LeaseVehicleEvent.lua` - Complete
- ✅ `TerminateLeaseEvent.lua` - Complete
- ❌ Shop integration not hooked up
- ❌ Game's lease button not intercepted
- ❌ Vehicle sale prevention not active
- ❌ "LEASED" indicator not shown

---

### 6. Land Financing

**Status:** ✅ IMPLEMENTED (basic functionality)

Finance farmland purchases with lower interest rates.

#### Features
- Lower base rate (3.5% vs 4.5% for vehicles)
- Longer terms available (up to 30 years)
- Down payment: 0-40%
- Land ownership transfers immediately

#### Missing from Original Design
- ❌ Land seizure on missed payments (3 strikes)
- ❌ Warning notification system
- ❌ Different interest rate calculation

#### Technical Implementation
- `LandFinanceDialog.lua` - Land finance dialog
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
- Hooks g_gui:showYesNoDialog for intercept

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

**Status:** ❌ NOT STARTED

Allow players to customize payment amounts per loan.

#### Core Concepts

| Payment Type | Description | Credit Impact |
|--------------|-------------|---------------|
| **Skip** | $0 payment, interest accrues to balance | -25 |
| **Partial** | Less than minimum, some negative amortization | -10 |
| **Minimum** | Interest-only, balance unchanged | 0 |
| **Standard** | Original amortized payment | +5 |
| **Extra** | Above standard, reduces principal faster | +5 |
| **Custom** | Player-defined amount | Based on tier |

#### Minimum Payment Formula
```
Minimum = Current Balance × (Annual Rate / 12)
```
This is the interest-only amount. Paying only this keeps balance unchanged.

#### Negative Amortization
When payment < minimum interest:
- Unpaid interest adds to principal
- Balance grows over time
- "Underwater" warning when balance > original price

#### Term Recalculation Formula
For extra payments, calculate new payoff months:
```
n = -log(1 - (P × r) / M) / log(1 + r)

Where:
P = Current balance
r = Monthly interest rate
M = Configured payment amount
n = Remaining months to payoff
```

#### UI: Payment Configuration Dialog
Access from Finance Manager → "Configure Payments" button

```
┌────────────────────────────────────────────────────────────────────────────┐
│ Configure Monthly Payments                                                 │
├────────────────────────────────────────────────────────────────────────────┤
│ Available Cash: $45,230          Credit Score: 720 (Good)                 │
│                           Minimum    Standard     Configured              │
│ Total Monthly Due:        $4,850     $8,650       $6,450                  │
│                                                                            │
│ ┌────────────────────────────────────────────────────────────────────────┐ │
│ │  Loan                Balance      Min      Std      Payment Setting   │ │
│ │  JD 8R 410          $245,000   $1,020   $4,250   [Standard      ▼]   │ │
│ │  Case Magnum        $180,000   $750     $3,200   [+$500 Extra   ▼]   │ │
│ │  Field 12 (Land)    $320,000   $1,330   $2,600   [Minimum       ▼]   │ │
│ │  Cash Loan           $50,000   $210     $833     [Skip          ▼]   │ │
│ └────────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
│ Impact Preview:                                                            │
│ ⚠ SKIP on Cash Loan: +$210 to balance, -25 credit                        │
│ ✓ EXTRA on Case Magnum: Payoff 8 months early, save $2,400               │
├────────────────────────────────────────────────────────────────────────────┤
│     [Reset All to Standard]                    [Save Configuration]       │
└────────────────────────────────────────────────────────────────────────────┘
```

#### Dropdown Options Per Loan
- Skip ($0)
- Minimum ($X interest-only)
- Standard ($Y amortized)
- +$500 Extra
- +$1,000 Extra
- +$2,000 Extra
- Double Payment
- Custom Amount...
- Pay Off Now

#### Technical Implementation
- `PaymentConfigDialog.lua` - Configuration dialog
- `SetPaymentConfigEvent.lua` - Multiplayer sync
- `FinanceDeal.lua` additions:
  - `configuredPayment` - player's chosen amount
  - `minimumPayment` - calculated interest-only
  - `paymentMode` - enum (SKIP/MIN/STD/EXTRA/CUSTOM)
  - `accruedInterest` - tracks negative amortization
  - `processConfiguredPayment()` - replaces auto-payment

---

### 14. Vehicle Maintenance System

**Status:** ✅ FULLY IMPLEMENTED (Phase 5)

Comprehensive reliability and maintenance system for vehicles.

#### Three-Component Reliability
- **Engine Health**: Affects power output, fuel efficiency, and starting reliability
- **Electrical Health**: Impacts lights, gauges, and electronic systems
- **Hydraulic Health**: Controls implement lift, steering assist, and attachments

#### Hidden Reliability Trait
- Each vehicle has a hidden "lemon or workhorse" trait assigned at spawn
- Lemons experience more frequent breakdowns and faster wear
- Workhorses are more reliable with slower degradation
- Mechanic inspection hints at vehicle's reliability class

#### Tire System
- Three tire quality tiers: Retread, Normal, Quality
- Tire tread wears over time based on usage and terrain
- Worn tires reduce traction and increase slip
- Flat tires cause steering pull and reduce max speed

#### Fluid Systems
- **Engine Oil**: Depletes with use, low oil causes engine damage
- **Hydraulic Fluid**: Powers implements and steering
- **Fuel**: Fuel leaks drain tank over time when detected

#### Technical Implementation
- `UsedPlusMaintenance.lua` - Vehicle specialization
- `InspectionReportDialog.lua` - Inspection results display
- `MaintenanceReportDialog.lua` - Owned vehicle maintenance view
- `FluidsDialog.lua` - Fluid service interface
- `TiresDialog.lua` - Tire service interface

---

### 15. Vehicle Malfunctions

**Status:** ✅ FULLY IMPLEMENTED (Phase 5)

Realistic breakdown events based on component health.

#### Engine Malfunctions
- **Overheating**: Engine temperature rises, power reduces, eventual stall
- **Misfiring**: Random power fluctuations and rough running
- **Stalling**: Engine cuts out unexpectedly, restart required
- **Hard Starting**: Difficulty starting in cold conditions with worn engine

#### Electrical Malfunctions
- **Electrical Cutout**: Temporary loss of electrical systems
- **Gauge Failures**: Instrument readings become unreliable
- **Light Flickering**: Headlights and work lights flicker or fail

#### Hydraulic Malfunctions
- **Hydraulic Drift**: Implements slowly lower when raised
- **Implement Surge**: Sudden unexpected implement movements
- **PTO Toggle**: Power take-off randomly engages or disengages
- **Hitch Failure**: Attachments may unexpectedly disconnect

#### Tire Malfunctions
- **Flat Tire**: Sudden tire failure causing steering pull
- **Slow Leak**: Gradual pressure loss over time
- **Blowout**: High-speed tire failure

#### Fuel System Malfunctions
- **Fuel Leak**: Tank slowly drains fuel when parked or running

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
│   │   └── TradeInCalculations.lua
│   ├── events/                   # Network events (14 total)
│   ├── managers/
│   │   ├── FinanceManager.lua
│   │   ├── UsedVehicleManager.lua
│   │   └── VehicleSaleManager.lua
│   ├── gui/                      # Dialog controllers (13 total)
│   └── extensions/               # Game hooks (8 total)
└── translations/
```

### Key Patterns Used
- **MessageDialog** - All dialogs extend MessageDialog
- **Event Pattern** - `Event.sendToServer()` for multiplayer
- **Manager Pattern** - Singletons with HOUR_CHANGED subscription
- **Extension Pattern** - `Utils.appendedFunction` / `Utils.overwrittenFunction`
- **TTL/TTS Queue** - Async operations for searches and sales

---

## Implementation Status

### Fully Implemented ✅
1. Finance System
2. Credit Score System (enhanced)
3. Used Vehicle Search
4. Vehicle Sales System
5. General Loan System
6. Partial Repair & Repaint
7. Trade-In System
8. Finance Manager GUI
9. Financial Dashboard
10. Admin Console Commands
11. Land Financing
12. Land Leasing
13. Vehicle Maintenance System (Phase 5)
14. Vehicle Malfunctions (Phase 5)

### Partially Implemented 🔄
1. **Vehicle Lease System** - Code exists, needs shop integration

### Not Started ❌
1. **Land Seizure** - Optional enhancement for defaulted land loans
2. **Payment Configuration** - Per-loan payment customization

---

## Version History

**v3.2 (2025-12-28)** - Documentation Sync with Implementation
- Updated Land Leasing status to ✅ IMPLEMENTED
- Added Section 14: Vehicle Maintenance System (Phase 5)
- Added Section 15: Vehicle Malfunctions (Phase 5)
- Updated Core Systems table with Maintenance and Malfunctions
- Synced Implementation Status with actual codebase

**v3.1 (2025-11-27)** - Added Payment Configuration System
- Added Section 13: Payment Configuration System
- Per-loan payment customization (Skip/Min/Std/Extra/Custom)
- Negative amortization and term recalculation formulas
- UI design for PaymentConfigDialog
- Credit score integration for payment behaviors

**v3.0 (2025-11-27)** - Design Document Update
- Added all implemented features not in original design
- Updated lease system to "replace game's system" approach
- Added land leasing as new planned feature
- Marked implementation status for all features
- Updated technical architecture

**v2.0 (2025-11-21)** - Original Comprehensive Design
- Initial comprehensive design document

---

## Next Steps

See **BACKLOG.md** for detailed implementation plan.
