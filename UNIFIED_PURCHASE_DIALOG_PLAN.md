# Unified Purchase Dialog - Design Plan

## ULTRATHINK: Architecture Overview

### Goal
Replace separate Buy, Finance, Lease dialogs with ONE unified dialog that:
- Has mode selector at top: "Buy with Cash" | "Finance" | "Lease"
- Integrates Trade-In for ALL purchase modes
- Dynamically shows/hides sections based on selected mode
- Provides cleaner UX with single entry point from shop

### User Flow
1. Player clicks "Buy" on any shop item (overrides vanilla)
2. UnifiedPurchaseDialog opens with "Buy with Cash" selected by default
3. Player can switch modes via MultiTextOption
4. Trade-In section available for all modes
5. Mode-specific options appear/disappear as needed
6. Single "Confirm Purchase" button handles all modes

---

## Dialog Layout (Top to Bottom)

### Section 1: Item Details (Always Visible)
```
+------------------------------------------+
|  [Vehicle Image]                         |
|  Vehicle Name                            |
|  $125,000 (New Price)                    |
|  Category: Tractors > Large              |
+------------------------------------------+
```

### Section 2: Purchase Mode Selector (Always Visible)
```
+------------------------------------------+
|  PURCHASE METHOD                         |
|  [< Buy with Cash | Finance | Lease >]   |
+------------------------------------------+
```

### Section 3: Trade-In (Always Visible, Collapsible)
```
+------------------------------------------+
|  TRADE-IN (Optional)                [v]  |
|  [ ] Enable Trade-In                     |
|  ----------------------------------------|
|  (When enabled - shows vehicle list)     |
|  Select Vehicle: [MultiTextOption]       |
|  Trade-In Value: $45,000                 |
|  Condition: 78% | Operating Hours: 156   |
+------------------------------------------+
```

### Section 4A: Buy with Cash Mode (Visible when mode = Cash)
```
+------------------------------------------+
|  PAYMENT SUMMARY                         |
|  ----------------------------------------|
|  Vehicle Price:      $125,000            |
|  Trade-In Credit:    -$45,000            |
|  ----------------------------------------|
|  TOTAL DUE:          $80,000             |
+------------------------------------------+
```

### Section 4B: Finance Mode (Visible when mode = Finance)
```
+------------------------------------------+
|  FINANCE TERMS                           |
|  ----------------------------------------|
|  Loan Term     | Down Payment | Cash Back|
|  [5 years]     | [10%]        | [$0]     |
|  ----------------------------------------|
|  Amount Financed:    $72,000             |
|  Interest Rate:      6.5% (Good credit)  |
|  Monthly Payment:    $1,412              |
|  Total Interest:     $12,720             |
|  ----------------------------------------|
|  DUE TODAY:          $8,000              |
|  (Down payment minus trade-in/cashback)  |
+------------------------------------------+
```

### Section 4C: Lease Mode (Visible when mode = Lease)
```
+------------------------------------------+
|  LEASE TERMS                             |
|  ----------------------------------------|
|  Lease Term:    [3 years]                |
|  Down Payment:  [10%]                    |
|  ----------------------------------------|
|  Monthly Payment:    $2,850              |
|  Total Lease Cost:   $102,600            |
|  Buyout at End:      $37,500             |
|  ----------------------------------------|
|  DUE TODAY:          $12,500             |
+------------------------------------------+
```

### Section 5: Action Buttons
```
+------------------------------------------+
|  [Confirm Purchase]  [Cancel]            |
+------------------------------------------+
```

---

## Files to Create/Modify

### New Files
1. `gui/UnifiedPurchaseDialog.xml` - Dialog layout
2. `src/gui/UnifiedPurchaseDialog.lua` - Dialog controller

### Modified Files
1. `src/extensions/ShopConfigScreenExtension.lua` - Hook "Buy" button
2. `modDesc.xml` - Add keybind for Search Used
3. `main.lua` - Register new dialog

---

## UnifiedPurchaseDialog.lua - Key Methods

```lua
UnifiedPurchaseDialog = {}
local UnifiedPurchaseDialog_mt = Class(UnifiedPurchaseDialog, MessageDialog)

-- Purchase modes
UnifiedPurchaseDialog.MODE_CASH = 1
UnifiedPurchaseDialog.MODE_FINANCE = 2
UnifiedPurchaseDialog.MODE_LEASE = 3

function UnifiedPurchaseDialog:new()
    -- Initialize with default mode = Cash
end

function UnifiedPurchaseDialog:setVehicleData(storeItem, vehicle, configs, saleItem)
    -- Store vehicle info for purchase
    -- Calculate base prices
    -- If saleItem provided, it's a used vehicle
end

function UnifiedPurchaseDialog:setInitialMode(mode)
    -- Set starting mode (used when Lease button clicked)
end

function UnifiedPurchaseDialog:onModeChanged()
    -- Called when mode selector changes
    -- Show/hide appropriate sections
    -- Recalculate all values
end

function UnifiedPurchaseDialog:updateSectionVisibility()
    -- MODE_CASH: Show cashSection, hide financeSection, hide leaseSection
    -- MODE_FINANCE: Hide cashSection, show financeSection, hide leaseSection
    -- MODE_LEASE: Hide cashSection, hide financeSection, show leaseSection
end

function UnifiedPurchaseDialog:onTradeInToggled()
    -- Enable/disable trade-in
    -- Show/hide trade-in vehicle selector
    -- Recalculate totals
end

function UnifiedPurchaseDialog:onTradeInVehicleSelected()
    -- Update trade-in value display
    -- Recalculate all totals
end

function UnifiedPurchaseDialog:calculateTotals()
    -- Based on current mode and trade-in, calculate:
    -- - Total price
    -- - Trade-in credit (if enabled)
    -- - Amount to finance/lease (if applicable)
    -- - Due today
    -- - Monthly payment (if applicable)
end

function UnifiedPurchaseDialog:onConfirmPurchase()
    -- Route to appropriate handler based on mode
    if self.currentMode == MODE_CASH then
        self:executeCashPurchase()
    elseif self.currentMode == MODE_FINANCE then
        self:executeFinancePurchase()
    elseif self.currentMode == MODE_LEASE then
        self:executeLeasePurchase()
    end
end

function UnifiedPurchaseDialog:executeCashPurchase()
    -- Handle trade-in if enabled
    -- Deduct money
    -- Spawn vehicle
end

function UnifiedPurchaseDialog:executeFinancePurchase()
    -- Handle trade-in (reduces down payment needed)
    -- Create FinanceDeal
    -- Spawn vehicle
end

function UnifiedPurchaseDialog:executeLeasePurchase()
    -- Handle trade-in (reduces upfront payment)
    -- Create LeaseDeal
    -- Spawn vehicle
end
```

---

## Trade-In Integration

### How Trade-In Works with Each Mode

**Buy with Cash:**
- Trade-in value directly reduces purchase price
- If trade-in >= price, player receives difference as cash

**Finance:**
- Trade-in value acts as additional down payment
- Reduces amount financed
- Can reduce "due today" to $0 or negative (player gets cash back)

**Lease:**
- Trade-in value reduces upfront payment
- Does NOT reduce monthly payment (lease is based on full vehicle value)
- Excess trade-in value returned as cash

### Trade-In Vehicle Eligibility
- Must be owned by player (not financed with balance remaining)
- Must be on the map (not stored)
- Cannot trade in the vehicle you're currently in

---

## Section Visibility Logic

```lua
function UnifiedPurchaseDialog:updateSectionVisibility()
    local isCash = (self.currentMode == MODE_CASH)
    local isFinance = (self.currentMode == MODE_FINANCE)
    local isLease = (self.currentMode == MODE_LEASE)

    -- Cash section
    if self.cashSection then
        self.cashSection:setVisible(isCash)
    end

    -- Finance section
    if self.financeSection then
        self.financeSection:setVisible(isFinance)
    end

    -- Lease section
    if self.leaseSection then
        self.leaseSection:setVisible(isLease)
    end

    -- Trade-in section always visible
    -- Trade-in details only visible when enabled
    if self.tradeInDetailsSection then
        self.tradeInDetailsSection:setVisible(self.tradeInEnabled)
    end
end
```

---

## Shop Integration

### Override Vanilla Buy Button
```lua
-- In ShopConfigScreenExtension.lua
function ShopConfigScreenExtension.onClickBuy(self, superFunc)
    -- Don't call superFunc
    -- Instead, open UnifiedPurchaseDialog with MODE_CASH
    UnifiedPurchaseDialog.show(storeItem, vehicle, configs, nil, MODE_CASH)
end
```

### Override Vanilla Lease Button (if exists)
```lua
function ShopConfigScreenExtension.onClickLease(self, superFunc)
    -- Don't call superFunc
    -- Open UnifiedPurchaseDialog with MODE_LEASE
    UnifiedPurchaseDialog.show(storeItem, vehicle, configs, nil, MODE_LEASE)
end
```

### Remove Separate Finance/Lease Buttons
- No longer need separate "Finance" button in shop
- No longer need separate "Lease" button
- Just the one "Buy" button that opens unified dialog

---

## Keybind for Search Used

Instead of including Search Used in the dialog:
```xml
<!-- In modDesc.xml -->
<actions>
    <action name="USEDPLUS_SEARCH_USED" axisType="HALF" />
</actions>

<inputBinding>
    <actionBinding action="USEDPLUS_SEARCH_USED">
        <binding device="KB_MOUSE_DEFAULT" input="KEY_u" />
    </actionBinding>
</inputBinding>
```

When pressed in shop with item selected:
- Opens SearchUsedDialog for that item
- Available from shop screen only

---

## Implementation Order

1. Create UnifiedPurchaseDialog.xml with all sections
2. Create UnifiedPurchaseDialog.lua with mode switching
3. Test basic mode switching works
4. Add Trade-In functionality
5. Connect to ShopConfigScreenExtension
6. Add Search Used keybind
7. Remove old separate Finance/Lease buttons from shop
8. Test full flow

---

## Estimated Complexity
- XML Layout: Medium (lots of sections, but straightforward)
- Lua Logic: Medium-High (mode switching, trade-in calculations)
- Integration: Medium (shop hooks already exist)
- Total: ~400-600 lines of code

---

## Questions to Resolve
1. Should trade-in vehicle list be a dropdown or scrollable list?
   - DECISION: Dropdown (MultiTextOption) for simplicity

2. What happens if trade-in value exceeds purchase price?
   - DECISION: Player gets cash back, shown as negative "Due Today"

3. Should we animate section transitions?
   - DECISION: No, just instant show/hide for simplicity
