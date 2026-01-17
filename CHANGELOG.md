# FS25_UsedPlus Changelog

All notable changes to this project are documented here.

---

## [2.7.0] - 2026-01-17

### Added
- **Delayed Inspection System** - Inspections now take game time instead of being instant!
  - **Three Inspection Tiers** with different costs, times, and data revealed:
    - **Quick Glance**: $1,000 + 2% (cap $2,500), 2 hours, overall rating only
    - **Standard**: $2,000 + 3% (cap $5,000), 6 hours, full reliability + parts
    - **Comprehensive**: $4,000 + 5% (cap $10,000), 12 hours, full details + DNA hint
  - Uses `HOUR_CHANGED` subscription - time scales with game speed
  - In-game notification when inspection completes
  - Progress display shows remaining hours

- **Listing Hold System** - Listings don't expire during inspection
  - `listingOnHold` flag prevents expiration while mechanic is working
  - Protects player's investment in the inspection fee

- **Credit-Gated Finance Terms** - Longer loan terms require better credit
  - Max vehicle finance term reduced from 20 to 15 years
  - 1-5 years: Any credit (300+)
  - 6-10 years: Fair credit (650+)
  - 11-15 years: Good credit (700+)
  - Term selector dynamically adjusts based on player's credit score

- **Shop Buy/Lease Override Toggle** - New setting for mod compatibility
  - `overrideShopBuyLease` setting in ESC > Settings > UsedPlus (default: ON)
  - When ON: Buy/Lease buttons open UnifiedPurchaseDialog (current behavior)
  - When OFF: Buy/Lease use vanilla behavior; use Finance button for UsedPlus features
  - Applies to both shop Buy/Lease AND farmland Buy on the map
  - Allows peaceful coexistence with other mods that also modify shop buttons

- **RVB Repair Override Toggle** - New setting for Real Vehicle Breakdowns users
  - `overrideRVBRepair` setting in ESC > Settings > UsedPlus (default: ON)
  - When ON: RVB's Repair button opens UsedPlus partial repair dialog
  - When OFF: RVB handles repair natively; use Map > "Repair Vehicle" for UsedPlus features
  - Only appears in settings when RVB is installed
  - Allows peaceful coexistence with other mods that also modify RVB

### Changed
- **Inspection fees significantly increased** (was $200 base + 1% capped at $2,000)
- **"Inspect" button now shows "Request Inspection"** when not yet inspected
- **"View Report" button** only appears after inspection is complete
- Preview dialog shows inspection state: Not Inspected → In Progress → Complete

### Fixed
- **FinanceDetailFrame payment buttons not working** - XML callbacks were misnamed
  - `onMakePayment()` → `onClickMakePayment()` (matches XML `onClick="onClickMakePayment"`)
  - `onEndLease()` → `onClickEndLease()` (matches XML `onClick="onClickEndLease"`)
- **DNA-based breakdown degradation not applied** - `applyBreakdownDegradation()` was defined but never called
  - Now called on engine overheat (Engine component)
  - Now called on hydraulic drop (Hydraulic component)
  - Now called on hitch failure (Hydraulic component)
  - Lemons (low DNA) now properly degrade faster on breakdowns
- **Repair event not updating vehicle reliability** - `onVehicleRepaired()` callback was orphaned
  - RepairVehicleEvent now calls `UsedPlusMaintenance.onVehicleRepaired()` after repairs
  - Lemon/Workhorse repair degradation now properly applied
- **Flat tire not cleared after repair** - `repairFlatTire()` was never called
  - TiresDialog: Tire replacement now clears flat tire state
  - FieldServiceKitDialog: OBD Scanner tire patch/plug now clears flat tire state
  - RepairVehicleEvent: Workshop repair now clears flat tire state
- **Fuel leak not fixed after repair** - `repairFuelLeak()` was orphaned
  - RepairVehicleEvent: Workshop engine repair now clears fuel leak
  - FieldServiceKitDialog: OBD Scanner engine diagnosis now clears fuel leak (good/perfect outcome)

### Technical
- New inspection fields on listing: `inspectionState`, `inspectionTier`, `inspectionRequestedAtHour`, `inspectionCompletesAtHour`, `inspectionFarmId`, `inspectionCostPaid`, `listingOnHold`
- `UsedVehicleManager.totalGameHours` tracks time for inspection completion
- `UsedVehicleManager:requestInspection()` - request inspection for a listing
- `UsedVehicleManager:processInspectionCompletions()` - called every game hour
- `UsedVehicleManager:getInspectionHoursRemaining()` - helper for UI
- `UsedPlusMaintenance.calculateInspectionCostForTier()` - tier cost calculation
- All inspection state persists to savegame
- Added `find_used.js` - Static analysis tool to find unused code
- Removed dead code: `selectCollateralForAmount()`, `showSearchFailedDialog()`, legacy payment functions

---

## [2.6.3] - 2026-01-17

### Fixed
- **Shop buttons no longer intercept non-vehicle items** (seeds, fertilizers, consumables)
  - Buy button: Now checks `canFinanceItem()` before swapping callback; restores vanilla for items we don't handle
  - Lease button: Same pattern - only intercepts leaseable vehicles
  - Search Used button: Added $2,500 minimum price check to `canSearchItem()`
  - Previously: Clicking Buy on seeds did nothing (callback intercepted but no fallback)
  - Previously: Search Used appeared on seed pallets (they're StoreSpecies.VEHICLE in FS25)
  - Now: Seeds, fertilizers, and other cheap consumables use vanilla shop flow correctly

- **On-time payments now build credit for ALL UsedPlus financial products**
  - FinanceDeal.lua: Added PaymentTracker.recordPayment() for vehicle/land/cash loan payments
  - LeaseDeal.lua: Added PaymentTracker.recordPayment() for vehicle lease payments
  - LandLeaseDeal.lua: Added PaymentTracker.recordPayment() for land lease payments
  - Previously only vanilla bank loans and external API payments built credit history
  - Now all on-time payments contribute to credit score (was asymmetric: missed payments hurt, but on-time didn't help)

- **UYT tire wear now properly applied to purchased used vehicles**
  - Implemented delayed UYT tire wear application (750ms after spawn)
  - Previously tire wear was applied immediately during vehicle spawn, before UYT wheel data structures were ready
  - Now poor quality vehicles will show visually worn tires via UYT
  - Follows same pattern as delayed dirt application which was already working

### Changed
- Credit system now symmetric: on-time payments build credit just like missed payments hurt credit
- UYT tire initialization uses delayed timer pattern for reliability

---

## [2.6.2] - 2026-01-17

### Added
- **DNA-Driven Seller Behavior** - Sellers now KNOW what they have!
  - Vehicle DNA (workhorseLemonScale) DETERMINES seller personality, not random
  - DNA 0.00-0.20 → desperate (lemon sellers want to unload)
  - DNA 0.20-0.40 → motivated (seller suspects issues)
  - DNA 0.40-0.60 → reasonable (seller doesn't know either way)
  - DNA 0.60-0.80 → firm (seller knows it runs well)
  - DNA 0.80-1.00 → **immovable** (workhorse sellers WON'T NEGOTIATE)
- **New "Immovable" Seller Personality** - For workhorses (DNA 0.80+)
  - Only accepts offers at 98%+ of asking price
  - Will NOT counter - just rejects and holds firm
  - 90% walk-away chance on any lowball (even 95%)
  - Weather modifiers still work but can't overcome immovable sellers
- **Permanent Walk-Away Mechanic** - Insulted sellers = lost sales
  - New "walkaway" response type when seller is insulted
  - Listing is PERMANENTLY removed from search - cannot be accessed again
  - Walk-away chance varies by personality: desperate 5%, motivated 15%, reasonable 35%, firm 60%, immovable 90%
  - Shows special dialog: "Your offer insulted the seller. This vehicle is no longer available."
- Translation keys for walkaway messages (usedplus_walkaway_title, usedplus_walkaway_message)
- Translation keys for disabled modes (usedplus_mode_finance_disabled, etc.)
- **Cross-Mod Integration Settings** - All 6 compatible mod integrations now have failsafe toggles
  - Settings appear in ESC > Settings > Game Settings > Mod Compatibility
  - Toggles only show if the corresponding mod is detected
  - **RVB Integration** (enableRVBIntegration) - Toggle Real Vehicle Breakdowns integration
  - **UYT Integration** (enableUYTIntegration) - Toggle Use Your Tyres integration
  - **AM Integration** (enableAMIntegration) - Toggle AdvancedMaintenance engine damage chaining
  - **HP Integration** (enableHPIntegration) - Toggle HirePurchasing (shows/hides Finance button)
  - **BUE Integration** (enableBUEIntegration) - Toggle BuyUsedEquipment (shows/hides Search button)
  - **ELS Integration** (enableELSIntegration) - Toggle EnhancedLoanSystem (enables/disables loans)
  - Disabling integration = UsedPlus behaves as if that mod isn't installed
  - Comprehensive documentation added to ModCompatibility.lua header

### Fixed
- **Walk Away button not closing dialog** - Used deferred close pattern like Complete Purchase
- **OBD Scanner buttons not working** - Typo: `UsedPlus.logInfoDebug()` → `UsedPlus.logDebug()`
- **Purchase dialogs not honoring Settings toggles** - Finance/Lease mode validation
  - UnifiedPurchaseDialog now checks `UsedPlusSettings:isSystemEnabled("Finance")` and `isSystemEnabled("Lease")`
  - UnifiedLandPurchaseDialog now checks the same settings
  - Mode selector shows "(Disabled)" text when system is turned off
  - Attempting to switch to disabled mode shows info dialog and reverts to Cash
- **Base Search Success % setting not working** - UsedVehicleSearch.lua:421 used old setting name `searchSuccessPercent` instead of renamed `baseSearchSuccessPercent`. Slider now actually affects search success rates.
- **enableRepairSystem master toggle not enforced** - Complete settings audit and fix
  - VehicleSellingPointExtension: Added guard in repair/repaint dialog interception (2 locations)
  - RepairDialog.setVehicle(): Added master toggle check
  - RepairFinanceDialog.setData(): Added master toggle check
  - RVBWorkshopIntegration: Added guards in hookRepairButton, injectRepaintButton, click handlers
- **enableVehicleSaleSystem only checked in 1 of 4 entry points**
  - InGameMenuVehiclesFrameExtension.onClickSellOverride(): Added setting check with vanilla fallback
  - VehicleSellingPointExtension SellItemDialog intercept: Added setting check
  - WorkshopScreenExtension.hookSellButton(): Added setting check in callback
- **baseTradeInPercent setting not used** - All trade-in calculations were hardcoded to 50-65%
  - UnifiedPurchaseDialog.getCreditTradeInMultiplier(): Now uses setting as base + credit bonus
  - SellVehicleDialog.updateComparisonDisplay(): Now uses setting for range display
  - SaleListingDetailsDialog: Trade-in estimate now uses setting
- **Finance/Lease events missing setting validation** - Multiplayer exploit fix
  - FinanceVehicleEvent.execute(): Validates enableFinanceSystem before processing
  - TakeLoanEvent.execute(): Validates enableFinanceSystem before processing
  - LeaseVehicleEvent:run(): Validates enableLeaseSystem before processing
- **enableCreditSystem didn't bypass credit checks** - canFinance() still rejected low credit when disabled
  - CreditScore.canFinance(): Now returns true immediately when credit system is disabled

### Changed
- Weather still influences negotiation (preserved from v2.6.0)
- UsedVehicleManager now derives personality from DNA when creating listings

---

## [2.6.1] - 2026-01-15

### Added
- **Graduated rejection risk for negotiation** - Lowballing now has real consequences!
  - 0-5% below threshold: Always counter (safe)
  - 5-10% below: Usually counter, 0-30% reject chance (low risk)
  - 10-15% below: 50/50 counter vs reject (medium risk)
  - 15-20% below: Usually reject, 0-30% counter chance (high risk)
  - >20% below: Always reject - insulting offer! (extreme risk)
- **Personality tolerance modifiers** - Sellers react differently to lowballs
  - Desperate: +8% tolerance (forgiving)
  - Motivated: +4% tolerance
  - Reasonable: 0% (baseline)
  - Firm: -5% tolerance (easily insulted)
- Cash validation for used vehicle purchases
  - Checks in NegotiationDialog:onClickSendOffer() before submitting
  - Checks in SellerResponseDialog:onClickPrimary() before completing purchase
  - Shows clear error with shortfall amount and current balance

### Fixed
- **SellerResponseDialog $0 price bug** - Counter offer popup showed "Your Offer: $0"
  - Root cause 1: SellerResponseDialog used custom `getInstance()` pattern instead of DialogLoader
  - Root cause 2: `setTextColorByName()` doesn't exist in FS25 - crashes before display
  - Fix: Converted to DialogLoader pattern, replaced all `setTextColorByName()` with `setTextColor(r,g,b,a)`
- **Dialog not closing after Complete Purchase** - Deferred callback to next frame
- Converted NegotiationDialog to DialogLoader pattern
- Widened counter offer dialog (+100px) - 600px → 700px to fit 3 buttons

### Changed
- Accept mode buttons - Only shows "Complete Purchase", no Cancel (deal is done)
- Registered both dialogs in DialogLoader.registerAll()

---

## [2.6.0] - 2026-01-14

### Added
- **Negotiation System** - Full implementation
  - Mechanic's Whisper hints about seller psychology
  - Weather Window - bad weather = better deals
  - Seller personality system (desperate/motivated/reasonable/firm)
  - Counter offer mechanic with Stand Firm gamble

### Fixed
- **NegotiationDialog $0 price bug** - Dialog crashed before displaying offer amount
  - Root cause: `getWeatherTypeAtTime()` requires a time parameter, but was called without one
  - Fix: Changed to `getCurrentWeatherType()` which requires no parameters

---

## [2.5.0] - 2026-01-11

### Added
- **VEHICLE_IMAGE_DISPLAY.md documentation** - Comprehensive guide on correct vehicle image display
  - Key finding: Must use `imageSliceId="noSlice"` and square dimensions
  - Documented the correct XML profile and Lua loading pattern

### Changed
- **Standardized ALL vehicle image profiles across 13 XML files**
  - All now use: `extends="baseReference"`, `size="180px 180px"`, `imageSliceId="noSlice"`
  - Position standardized to `-185px 75px`
  - Size reduced 10% from RVB's 200x200 for better fit
- Simplified UIHelper.Image to single `set()` function with auto-detection

---

## [2.0.0] - 2026-01-05

### Added
- **OBD Scanner v2.0.0 - Full RVB/UYT Cross-Mod Integration**
  - `findNearbyVehicles()` uses ModCompatibility to detect RVB part failures and UYT tire wear
  - Activation prompt shows specific warning sources
  - RVB PART STATUS section: Engine, Thermostat, Generator, Battery, Starter, Glow Plug
  - TIRE WEAR (UYT) section: Per-wheel condition FL, FR, RL, RR
  - Color-coded values: green → yellow → orange → red

---

## [1.9.7] - 2026-01-01

### Added
- **RepossessionDialog** for loan default notifications
  - Shows item name, value, missed payments, balance owed, credit impact warning
  - Handles vehicles, land, and mixed collateral

### Fixed
- **Field Service Kit shop purchase flow** - Was showing customization screen
  - Fix: Category `misc` → `misc objectMisc`
- **Shop extension intercepting hand tools**
  - Fix: Added `storeItem.financeCategory == "SHOP_HANDTOOL_BUY"` check
- **SearchExpiredDialog not showing** - Wrong property names, getInstance() pattern

---

## [1.9.6] - 2025-12-28

### Added
- **SaleOfferDialog UX overhaul**
  - Deal quality rating with stars (★★★★☆ Great Deal)
  - Expected range section showing Min/Offer/Max values
  - "Your Options" section comparing: Sell Instantly vs Accept Offer vs Keep Waiting
  - Title: "BUYER FOUND!" instead of "Sale Offer Received"
  - "Decline" → "Keep Waiting"

### Fixed
- **Field Service Kit "Unknown type" error**
  - Fix: `parent="handTool"` → `parent="base"`
  - Fix: Remove mod prefix from own specializations
- **SaleOfferDialog not closing after Accept**
  - Fix: Close dialog BEFORE calling callback, cache values first

---

## [1.9.5] - 2025-12-25

### Added
- **LoanApprovedDialog** - Styled replacement for plain InfoDialog
  - Sections for Amount Deposited, Loan Terms, Payment Schedule, Credit Impact
  - Color-coded values
- Safe X positioning documentation
- Category column to TakeLoanDialog collateral table

### Fixed
- **UsedSearchDialog text positioning** - anchorTopLeft vs anchorTopCenter origin behavior
- **TakeLoanDialog collateral double-pledge bug** - Same vehicle used for multiple loans
- **TakeLoanDialog section padding** - Content touching bottom edge
- **UnifiedPurchaseDialog left-side overflow** - Elements beyond safe X range

---

## [1.9.0] - 2025-11-30

### Fixed
- **Critical Lua syntax error** - UsedPlusMaintenance.lua used `goto continue` (Lua 5.2+)
  - FS25 uses Lua 5.1 - replaced with nested `if not condition then ... end`
- **Used vehicle search not completing** - UsedVehicleManager.lua used `os.date()`
  - Fixed `generateListingId()` to use `g_currentMission.environment.currentDay`

### Added
- Phase 5: Hydraulic drift, electrical cutout, resale value modifier, vehicle name indicators

---

## [1.8.0] - 2025-11-29

### Added
- **UIHelper.lua** - Centralized text formatting, image handling, element helpers
- **UsedPlusUI.lua** - High-level components (sections, label-value, tables, cards)

### Changed
- Consolidated Sale Events (3→1): AcceptSaleOfferEvent, DeclineSaleOfferEvent, CancelSaleListingEvent → SaleListingActionEvent

### Removed
- Deleted unused: FinanceDialog.lua/xml, LeaseDialog.lua/xml, TradeInDialog.lua/xml

---

## [1.7.0] - 2025-11-27

### Changed
- **Full modular docs/ restructure** - 24 focused documentation files
  - basics/: modDesc.md, localization.md, input-bindings.md, lua-patterns.md
  - patterns/: gui-dialogs, events, managers, data-classes, save-load, extensions, shop-ui, async-operations, message-center, financial-calculations, physics-override
  - advanced/: placeables.md, vehicles.md, triggers.md, hud-framework.md, animations.md, animals.md, production-patterns.md, vehicle-configs.md
  - pitfalls/: what-doesnt-work.md

### Removed
- Legacy monolithic docs: FS25_MODDING_REFERENCE.md, FS25_ADVANCED_PATTERNS.md

---

## [1.5.0] - 2025-11-26

### Added
- Partial repair & repaint system
- Take Loan feature

### Fixed
- Multiple GUI dialog issues

---

## [1.0.0] - 2025-11-22

### Added
- Initial release
- Vehicle/equipment financing (1-30 years)
- Dynamic credit scoring (300-850 FICO-like)
- General cash loans against collateral
- Used Vehicle Marketplace (agent-based buying AND selling)
- Trade-in with condition display
- Full multiplayer support
