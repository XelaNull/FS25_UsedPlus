# FS25_UsedPlus Changelog

All notable changes to this project are documented here.

---

## [2.9.0] - 2026-01-25

### Added - Service Truck System
A driveable service truck that performs **long-term vehicle restoration**, including the unique ability to restore the reliability ceiling that degrades on lemons.

**IMPORTANT: Discovery System**
The Service Truck is NOT available in the shop! It must be **discovered** through National Agent transactions:

**Prerequisites (ALL required):**
- 3+ OBD Scanner uses (you understand the basic repair system)
- 700+ credit score (you're a serious customer)
- Own a vehicle with reliability ceiling < 90% (you've felt the pain)

**Discovery Flow:**
1. Complete any National Agent transaction (buy or sell)
2. If prerequisites met: 20% chance agent mentions "a connection"
3. Special opportunity dialog shows: retiring mechanic's service truck
4. **CASH ONLY** - $67,500 (10% connection discount)
5. Accept now or decline (saved to Finance Manager for 30 days)
6. Pity timer: guaranteed discovery after 10 eligible transactions

**Why Gated?**
- Players must EARN the endgame tool
- Prevents trivializing the ceiling degradation mechanic
- Creates a meaningful "aha!" moment when discovered
- Triple gate: skill (OBD uses) + credit (700+) + wealth ($67,500 cash)

**New Files:**
- `vehicles/ServiceTruck.lua` - Main specialization (~750 lines)
- `vehicles/serviceTruck/serviceTruck.xml` - Vehicle definition (hidden from shop)
- `vehicles/sparePartsPallet/sparePartsPallet.xml` - Purchasable spare parts pallet ($500)
- `src/data/RestorationData.lua` - Diagnostic scenarios and restoration parameters
- `src/gui/ServiceTruckDialog.lua` - Inspection minigame and status dialog
- `src/gui/ServiceTruckDiscoveryDialog.lua` - Discovery opportunity popup
- `gui/ServiceTruckDialog.xml` - Dialog UI definition
- `gui/ServiceTruckDiscoveryDialog.xml` - Discovery popup UI
- `src/events/RestorationEvents.lua` - Restoration multiplayer sync
- `src/events/ServiceTruckDiscoveryEvent.lua` - Discovery/purchase MP sync
- `src/managers/ServiceTruckDiscovery.lua` - Discovery prerequisites and state tracking
- `data/fillTypes.xml` - Custom USEDPLUS_SPAREPARTS fill type

**Key Features:**
| Feature | Description |
|---------|-------------|
| **Ceiling Restoration** | Only way to restore degraded reliability ceiling (unique!) |
| **Long-term Process** | 1% reliability per game hour, 0.25% ceiling per hour |
| **Resource Consumption** | Diesel (5L/hr), Oil (0.5L/hr), Hydraulic (0.5L/hr), Spare Parts (2/hr) |
| **Target Immobilization** | Vehicle wheels hidden, engine locked during restoration |
| **Inspection Minigame** | Pass diagnostic quiz to start restoration |
| **48-Hour Cooldown** | Failed inspection = 48 game-hour cooldown per component |
| **Full Multiplayer** | Server-authoritative with progress sync events |

**Service Truck vs OBD Scanner:**
| Aspect | OBD Scanner | Service Truck |
|--------|-------------|---------------|
| Item Type | Hand tool ($5,000) | Driveable vehicle ($67,500-$75,000) |
| Availability | Always in shop | **Must be discovered** |
| Duration | Instant | Hours/days |
| Max Restoration | 80% cap | 100% possible |
| Ceiling Repair | No | **YES** |
| Payment | Cash/Finance/Lease | **CASH ONLY** |

**Spare Parts System:**
- Buy spare parts pallets from shop ($500 for 100 parts)
- Place within 5m of service truck
- Truck auto-consumes 2 parts per game hour
- No parts = work pauses (no damage, just stopped)

**Credits:**
- Vehicle model: **Canada FS** (GMC C7000 Service 81-89 v1.0)

### Changed
- `modDesc.xml` - Added fill types, ServiceTruck specialization, vehicle type, store items
- `UsedPlusMaintenance.lua` - Added restoration state tracking (isBeingRestored, cooldowns)
- `VehicleSpawning.lua` - Hook for National Agent purchase discovery trigger
- `VehicleSaleManager.lua` - Hook for National Agent sale discovery trigger
- `main.lua` - Save/load hooks for ServiceTruckDiscovery state

---

## [2.8.0] - 2026-01-24

### Fixed - Multiplayer Synchronization (GitHub Issue #1 Part 3)
Complete audit and fix of all actions that bypassed network events. Previously, many operations worked in single-player but silently failed on dedicated servers because they called managers directly instead of using network events.

**New Network Events Created:**
- `PurchaseUsedVehicleEvent` - Used vehicle purchases from agent search results
- `TradeInVehicleEvent` - Trade-in vehicle deletion with proper credit
- `PurchaseLandCashEvent` - Land cash purchases with ownership transfer
- `VanillaLoanPaymentEvent` - Vanilla farm.loan payments
- `MaintenanceEvents.lua` (new file):
  - `FieldRepairEvent` - Field service kit seizure repairs
  - `RefillFluidsEvent` - Oil/hydraulic fluid refills
  - `ReplaceTiresEvent` - Tire replacement with quality tiers

**Dialogs Fixed:**
- `VehiclePortfolioDialog` - Used vehicle purchase now uses `PurchaseUsedVehicleEvent`
- `UnifiedLandPurchaseDialog` - Cash/Finance/Lease land purchases now use proper events
- `UnifiedPurchaseDialog` - Trade-in now uses `TradeInVehicleEvent`
- `DealDetailsDialog` - Early payoff now uses `FinancePaymentEvent`
- `FieldServiceKitDialog` - Seizure repairs now use `FieldRepairEvent`
- `FluidsDialog` - Fluid refills now use `RefillFluidsEvent`
- `TiresDialog` - Tire replacement now uses `ReplaceTiresEvent`
- `FinancesPanel` - Vanilla loan payment now uses `VanillaLoanPaymentEvent`

**Extensions Fixed:**
- `InGameMenuVehiclesFrameExtension` - Sale listing creation uses `CreateSaleListingEvent`
- `VehicleSellingPointExtension` - Sale listing creation uses `CreateSaleListingEvent`

**Enhanced Existing Events:**
- `CreateSaleListingEvent` - Now supports dual-tier system (agentTier + priceTier)
- `LandLeaseEvent` - Now accepts termMonths, securityDeposit, monthlyPayment parameters
- `ReplaceTiresEvent` - Now handles quality tiers (1-3) and includes flat tire repair

**Result:** Server is now authoritative for all financial transactions. Clients receive proper success/failure feedback via `TransactionResponseEvent`.

### Fixed - Other
- **Inspection Report showing RVB components when disabled** - Generator, Starter, Battery, Glow Plug were shown even with RVB integration disabled
  - Root cause: `displayIntegratedRVBData()` only checked if listing had RVB data, not if setting was enabled
  - Fix: Added `enableRVBIntegration` setting check before displaying sub-components
- **Duplicate lease end dialogs** - When a lease term completed, TWO dialogs would show
  - `LeaseDeal:completeLease()` showed `LeaseEndDialog` (2 options: Return/Buyout)
  - `FinanceManager` also showed `LeaseRenewalDialog` (3 options: Return/Buyout/Renew)
  - Fix: Removed dialog call from `completeLease()` - now only `LeaseRenewalDialog` shows with all 3 options
  - Note: `LeaseEndDialog.lua` is now deprecated (kept for backwards compatibility but not used)

### Added
- **Malfunction Frequency slider** - New setting to adjust how often malfunctions occur
  - Range: 25% to 200% (default 100%)
  - 25% = very rare malfunctions, 200% = twice as frequent
  - Located in Settings menu right after Malfunctions toggle
  - Presets automatically set appropriate values (Easy: 25%, Challenging: 125%, Hardcore: 200%)
- **Persistence debugging** - WARN-level logging throughout save/load flow
  - Logs when FSBaseMission.loadItemsFinished hook fires with missionInfo status
  - Logs when loadSavegameData is called with savegame directory
  - Logs each search registration with count
  - Logs save/load completion with counts
  - Helps diagnose "searches disappear after save/load" issues

### Changed
- **Farm.new hook** - Now checks if data arrays already exist before initializing
  - Prevents accidental overwriting of loaded search/listing data
  - Logs warning if farm already has searches (indicates unexpected call order)

### Fixed
- **OBD Scanner reliability exploit** - Players could spam OBD kits to restore reliability to 100%
  - **One-time diagnosis per system**: Each component (engine, electrical, hydraulic) can only receive ONE diagnostic boost from OBD Scanner
  - **80% cap**: OBD field repair cannot restore above 80% (shop repair needed for higher)
  - **Respects vehicle ceiling**: Also capped by vehicle's `maxReliabilityCeiling` (aging/wear ceiling)
  - **Effective cap**: min(80%, vehicleCeiling)
  - **Seizure repair is separate**: Fixing a seized component does NOT use up the diagnostic boost - it's emergency repair
  - Seizure repair also respects vehicle ceiling
  - Tracking persists across save/load and syncs in multiplayer
- **Buyer Found popup "Keep Waiting" truncation** - Button text was cut off with "..."
  - Created custom `soKeepWaitingBtn` profile with wider size and `textTruncation="false"`
- **Workshop shows sold vehicle** - Workshop still displayed vehicle after accepting sale offer
  - Added `closeWorkshopIfShowingVehicle()` to close workshop/shop config screen before deleting sold vehicle
  - Checks `g_shopConfigScreen`, `g_workshopScreen`, and `inGameMenu.pageVehicles`
- **OBD Scanner UI improvements** - Multiple visual and UX enhancements:
  - **Diagnose Component**: Removed reliability % display from system buttons (player must diagnose from hints - showing percentages defeated the puzzle)
  - **Scanner Readout**: Enhanced terminal appearance with larger text (13px), better padding, and green diagnostic color scheme
  - **Tire Service vehicle image**: Fixed stretched appearance - now uses proper 140x140 square format with `noSlice`
  - **Tire Service layout**: Reorganized with vehicle centered above 2x2 tire grid for better visual flow
- **OBD Scanner messaging** - Corrected confusing/inaccurate result screen text:
  - Changed "TEMPORARY REPAIR - visit workshop for permanent fix" → "FIELD SERVICE COMPLETE"
  - OBD fixes **reliability** (malfunction chance), workshop fixes **damage** - these are different systems!
  - Updated "kit consumed" message: "Field-serviceable adjustments have been made to this system"
  - Now states "Further diagnostics on this system require workshop equipment"
- **Mechanical repair not working** - Cash payment confirmation showed "Configuration changed" but vehicle wasn't repaired and money wasn't deducted
  - Root cause: Security validation added in v2.7.2 checked for nil values BEFORE default values were applied
  - Optional parameters (`termMonths`, `monthlyPayment`, `downPayment`) are not passed for cash payments
  - Validation saw nil → returned early → skipped both money deduction AND repair
  - Fix: Moved default value assignments to top of execute() function, before validation
- **Oil Service Tank fluid type selection** - Always purchased oil regardless of selecting Hydraulic Fluid
  - Root cause: MultiTextOption callback was missing from XML
  - Fix: Added `onClick="onFluidTypeChanged"` to FluidPurchaseDialog.xml
- **Used vehicle age/hours realism** - Vehicle age is now correlated with operating hours
  - Previously a 3800-hour vehicle could be only 1-2 years old (unrealistic!)
  - Now calculates minimum age from hours (assumes 400-1000 hours/year usage)
  - Vehicle age is actually APPLIED to spawned vehicles (was missing before!)
  - FS25 stores age in months, listing age in years - now converts properly
- **EnhancedLoanSystem (ELS) integration** - ELS loans now display correctly on UsedPlus Finance page
  - Added late-binding detection: checks for `g_els_loanManager` at runtime, not just during init
  - ELS converts vanilla loans in `onStartMission()` which runs after our init
  - Finance panel now checks directly for ELS global, bypassing init-time flag
  - Added robust method checking using `type()` instead of field lookup
  - Wrapped ELS API calls in pcall for error handling
  - Fixed interest rate conversion (ELS stores as %, we convert to decimal)
  - Better loan naming: shows original loan amount in Finance list
  - Comprehensive debug logging for troubleshooting

### Changed
- **ELS detection** - Enhanced to check multiple ELS globals (g_els_loanManager, ELS_loanManager class, ELS_loan class)
- **VehiclePortfolioDialog exploit prevention** - Now closes any open VehiclePortfolioDialog when SearchExpiredDialog opens
  - Prevents player from keeping "Found Vehicles" popup open after search expires to continue inspecting/buying
- **Seller walkaway exploit fix** - When seller walks away insulted, ALL related dialogs now close
  - Closes NegotiationDialog, InspectionReportDialog, UsedVehiclePreviewDialog, and VehiclePortfolioDialog
  - Prevents player from making another offer after seller has walked away
  - Listing is permanently removed so it cannot be offered on again

### Technical
- Added debug logging throughout ELS integration path for easier troubleshooting
- Late-binding pattern allows detection even if mods load in unexpected order

---

## [2.7.3] - 2026-01-21

### Fixed
- **TakeLoanDialog pagination** - Page indicator now correctly shows "2/2" on page 2
  - Fixed maxOffset calculation: changed from scrolling style to paging style
  - Next button now properly disables on last page
- **Inspection complete popup timing** - Dialog now shows "Complete" instead of "In Progress"
  - Added 2-frame delay before opening preview dialog from completion notification
  - Ensures YesNoDialog fully closes before new dialog opens
- **View Report button not opening inspection report** - Fixed dialog instance mismatch
  - Changed from getInstance() pattern to DialogLoader.show() for consistency
  - Fixes both UsedVehiclePreviewDialog → InspectionReportDialog and Go Back navigation
- **RVB Workshop Mechanic's Assessment** - Text no longer truncated
  - Expanded label to 95% container width with centered alignment
  - Disabled text truncation on mechanic quote
- **RVB Workshop Repaint button** - Now properly opens Repaint dialog
  - Fixed g_soundPlayer:playSample() API call (doesn't exist)
  - Wrapped in pcall with g_gui:playSample() fallback
- **Currency formatting consistency** - $ now always appears before amount
  - New UIHelper.Text.formatMoney() uses American format ($X,XXX) throughout mod

### Changed
- **UsedSearchDialog** - "Match Quality" label renamed to "Chance to Match Quality"
  - Removed confusing "(+8%)" modifier display from success rate
  - Dialog height reduced from 755px to 740px
- **UsedVehiclePreviewDialog** - Cancel button now shows "Close" when inspection is in progress/complete

---

## [2.7.2] - 2026-01-18

### Security Hardening (Multiplayer) - OWASP Compliance Update
- **NetworkSecurity utility** - New centralized security validation module
  - `validateFarmOwnership(connection, farmId)` - Verify player owns the farm they claim
  - `hasMasterRights(connection)` - Check for admin permissions
  - `logSecurityEvent(eventType, details, connection)` - Audit trail for security events

- **Farm ownership verification on ALL network events** - Prevents multiplayer exploits
  - FinanceVehicleEvent, FinancePaymentEvent, TakeLoanEvent
  - LeaseVehicleEvent, LeaseEndEvent, TerminateLeaseEvent, LeaseRenewalEvent
  - LandLeaseEvent, LandLeaseBuyoutEvent
  - RequestUsedItemEvent, CancelSearchEvent, DeclineListingEvent
  - CreateSaleListingEvent, SaleListingActionEvent, ModifyListingPriceEvent
  - RepairVehicleEvent, SetPaymentConfigEvent
  - Malicious clients can no longer drain other farms' money or manipulate their deals

- **Unbounded loop prevention (DoS protection)** - All readStream() methods now validate array counts
  - FinanceVehicleEvent: configCount limited to 100 max
  - LeaseVehicleEvent: configCount limited to 100 max
  - TakeLoanEvent: collateralCount limited to 50 max
  - UsedPlusSettingsEvent: settingCount limited to 200 max
  - Prevents server freeze from malicious clients sending billions of iterations

- **Financial parameter validation** - Prevents money generation exploits
  - All monetary amounts validated for NaN/Infinity and reasonable bounds
  - CashBack validated against credit-based maximum
  - Interest rates validated 0-50% range
  - Loan amounts validated against collateral value (max 150%)
  - Negative amounts rejected to prevent reversed money flow

- **Input sanitization** - Lua table injection prevention
  - Configuration keys validated to reject `__metatable`, `__index` etc.
  - Enum values validated before conditional deserialization (LeaseRenewalEvent)
  - Percentage values clamped to 0-1 range (RepairVehicleEvent)

- **Null safety enforcement** - SaleEvents authorization bypass fixed
  - SaleListingActionEvent: Now requires manager AND listing to exist before execute()
  - ModifyListingPriceEvent: Now requires manager AND listing to exist before execute()
  - Price validation added (positive, < $100M)

- **FinanceDeal negative payment exploit fixed**
  - Custom payment amounts now enforce $100 minimum floor
  - Negative amounts rejected and logged

### Fixed
- **VehicleExtension crash bug** - Fixed `Vehicle.calculateSalePrice()` call that doesn't exist
  - Now stores original `getSellPrice` function reference before hooking
  - Properly retrieves base sell price for reliability modifier calculation
- **DEBUG flag disabled** - `UsedPlusCore.lua:19` now sets `DEBUG = false` for release
  - Reduces log verbosity significantly for players
  - Set to `true` only when developing/debugging
- **Removed obsolete TODO** - `main.lua` ESC menu integration comment updated
  - Finance Manager accessible via Shift+F hotkey (works great!)
  - ESC menu button deferred as low priority
- **Removed debug timestamp** - `UsedVehicleManager.lua` debug log cleaned up

### Security Pass #2 Fixes (Additional Hardening)
- **Stream drain logic fixed** - CRITICAL vulnerability patched
  - When array counts are invalid, stream data is now properly consumed
  - Previously, rejecting a count and setting it to 0 would leave stream pointer desynchronized
  - Affected: FinanceEvents, LeaseEvents, UsedPlusSettingsEvent
  - Malicious packets can no longer desync multiplayer sessions

- **Infinity value validation** - CRITICAL vulnerability patched
  - All NaN checks now also check for `math.huge` and `-math.huge`
  - Prevents creation of loans/payments with infinite values
  - Affected: FinanceEvents, RepairVehicleEvent, SaleEvents

- **Division by zero prevention** - Fixed in FinanceDeal:makePayment()
  - Now validates `monthlyPayment > 0` before calculating payment months
  - Prevents crash when deal has invalid configuration

- **Custom payment upper bound** - Fixed in FinanceDeal:setPaymentMode()
  - Custom payments now capped at max(payoffAmount, monthlyPayment * 10, $1M)
  - Prevents absurdly high values from being set

- **SaleListingActionEvent action type validation** - Added explicit enum check
  - Rejects unknown action types before processing
  - Prevents potential undefined behavior from invalid enum values

### RVB Integration Fix (OBD Scanner)
- **Fixed RVB detection in ModCompatibility.lua** - OBD Scanner now properly detects RVB failures
  - Previous detection only checked `g_currentMission.vehicleBreakdowns`
  - Now checks multiple RVB globals: `g_rvbMenu`, `g_vehicleBreakdownsDirectory`, `g_rvbPlayer`
  - Also checks specialization manager for "vehicleBreakdowns" registration
  - Debug logging shows which detection method succeeded

- **Enhanced RVB fault detection** - More robust part failure checking
  - Now checks `part.damaged` boolean in addition to `part.fault` string
  - Added `part.isFailed` check for compatibility with different RVB versions
  - Prefault detection now also checks `part.isWarning` boolean
  - Empty string `""` now treated same as `"empty"` and `nil` for no-fault state

### Steering Pull Malfunction Fix
- **Fixed steering pull not having any effect** - Now uses direct wheel physics manipulation
  - Previous approach: Modified `inputValue` in `setSteeringInput()` hook
  - Problem: FS25's internal input processing ignored/smoothed small input changes
  - Solution: New `applyDirectSteeringPull()` function directly sets `wheel.steeringAngle`
  - Uses `setWheelShapeProps()` to apply changes to physics engine (same as RVB)
  - Hydraulic surge, flat tire pull, and chronic steering degradation all now work
  - Pull effect scales with speed and condition severity
  - Pattern from: VehicleBreakdowns.lua `adjustSteeringAngle()`

### Notes
- Full code audit completed by 6 specialized OWASP security auditors
- Pass #1: 18 Critical/High severity vulnerabilities identified and fixed
- Pass #2: 2 Critical and 4 High severity issues fixed
- All stream desync vulnerabilities eliminated
- All numeric overflow/underflow vectors patched
- Ready for public multiplayer release

---

## [2.7.1] - 2026-01-17

### Added
- **Inspection Completion Popup** - When inspection finishes, a dialog pops up automatically!
  - "View Report" button opens the vehicle preview dialog immediately
  - "Later" button dismisses the popup; find the listing in Finances menu anytime
  - Also shows in-game notification as backup

- **Credit-Based Down Payment Requirements** - Better credit = access to lower down payments
  - Very Poor credit (<600): 25% minimum down required
  - Poor credit (600-649): 20% minimum down required
  - Fair credit (650-699): 10% minimum down required
  - Good credit (700-749): 5% minimum down required
  - Excellent credit (750+): 0% down available
  - Applies to vehicle financing, land financing, and repair financing
  - New players can no longer get 0% down loans without building credit first

### Fixed
- **`g_gui:showInfoDialog()` errors** - Replaced 21 invalid calls with `InfoDialog.show()`
  - Fixed TiresDialog locking when UYT not installed
  - Fixed NegotiationDialog "Make Offer" causing popup to lock
  - Fixed multiple other dialogs that could fail silently
- **UYT (Use Your Tyres) detection** - Now checks both `UseYourTyres` and `useYourTyres` globals
  - Some UYT versions use different capitalization
  - Added `ModCompatibility.uytGlobal` reference for consistent API calls
- **Oil Service Point vehicle action not showing** - Fixed `getIsActivatable()` returning false
  - Now always shows action prompt when vehicle is in range
  - Info-only mode shows status message (e.g., "Tank has Oil - Vehicle needs Hydraulic")
  - Pressing action when can't refill shows a warning message instead of doing nothing

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
- Consolidated debug logging to use `UsedPlus.log*()` functions with single `UsedPlus.DEBUG` flag
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
