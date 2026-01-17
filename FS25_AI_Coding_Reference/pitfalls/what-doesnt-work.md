# What Doesn't Work in FS25

**Common mistakes and their solutions**

Based on hard-won experience from UsedPlus development.

---

## Related API Documentation

> 📖 **Verify before using!** Check the [FS25 Community LUADOC](https://github.com/umbraprior/FS25-Community-LUADOC) to confirm function signatures and availability.

**Key Reference Links:**
- [Gui.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/GUI/Gui.md) - Dialog/GUI API (no `showYesNoDialog`!)
- [Utils.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/Utils/Utils.md) - Utility functions
- [XML Engine](https://github.com/umbraprior/FS25-Community-LUADOC/tree/main/docs/engine/XML) - XML parsing functions
- [Raw dataS source](https://github.com/Dukefarming/FS25-lua-scripting) - See how Giants implements things

---

> ✅ **100% VALIDATED FROM USEDPLUS DEVELOPMENT**
>
> Every pitfall documented here was encountered and solved during UsedPlus development.
> These are battle-tested lessons, not theoretical warnings.
>
> **Evidence Trail:**
> - v1.0.13.0 changelog: os.time() crashes, MessageDialog conversion
> - v1.0.5.0 changelog: DialogElement → MessageDialog rewrite
> - v1.0.6.0 changelog: Slider replaced with quick buttons
> - v2.6.0 codebase: All solutions actively in production use
>
> **Key Files Demonstrating Solutions:**
> - `FS25_UsedPlus/src/gui/*.lua` - MessageDialog base class pattern
> - `FS25_UsedPlus/src/events/*.lua` - sendToServer pattern with g_server check
> - `FS25_UsedPlus/src/data/CreditSystem.lua` - g_currentMission.time usage
> - `FS25_UsedPlus/src/utils/FinanceCalculations.lua` - Lua 5.1 compatible code

---

## Critical Issues

### 1. `os.time()` and `os.date()` are NOT Available

> ✅ **Validated:** `FS25_UsedPlus/src/data/CreditSystem.lua:223-227` - Uses g_currentMission.environment.currentDay

**Problem:** Lua's standard `os.time()` and `os.date()` functions don't exist in FS25's sandboxed Lua environment.

**Error:**
- `os.time()`: `attempt to call a nil value (field 'time')`
- `os.date()`: `attempt to index nil with 'date'` (when using `os.date("*t")`)

**Solution:**
```lua
-- WRONG
local timestamp = os.time()
local date = os.date("*t")
local dateStr = string.format("%04d%02d%02d", date.year, date.month, date.day)

-- CORRECT
local timestamp = g_currentMission.time  -- Game time in ms
local timestamp = g_time                  -- Also works

-- For hours/days, use environment
local currentHour = g_currentMission.environment.currentHour
local currentDay = g_currentMission.environment.currentDay
local currentMonth = g_currentMission.environment.currentMonth
local currentYear = g_currentMission.environment.currentYear

-- For unique IDs, use counter + game day
local id = string.format("ITEM_D%d_%08d", currentDay, self.nextId)
```

---

### 2. FS25 Uses Lua 5.1 - NO `goto` Statements

> ✅ **Validated:** All UsedPlus Lua files use `if not condition then` pattern instead of goto

**Problem:** Using `goto` statements or labels (`::label::`) which are Lua 5.2+ features. FS25 uses Lua 5.1 which doesn't support these.

**Error:** `Lua compiler error: Incomplete statement: expected assignment or a function call`

**Symptoms:**
- Mod fails to load entirely
- All vehicle specializations using your mod fail with "unknown specialization"
- Other mod features that depend on your code break

**Solution:** Replace `goto continue` patterns with nested `if` statements.

```lua
-- WRONG (Lua 5.2+ only):
for i, item in pairs(items) do
    if skipCondition then goto continue end

    -- Process item
    doSomething(item)

    ::continue::
end

-- CORRECT (Lua 5.1 compatible):
for i, item in pairs(items) do
    if not skipCondition then
        -- Process item
        doSomething(item)
    end
end

-- ALSO CORRECT: Early return in function for single processing
local function processItem(item)
    if skipCondition then return end
    doSomething(item)
end

for i, item in pairs(items) do
    processItem(item)
end
```

**Other Lua 5.1 limitations to remember:**
- No bitwise operators (`&`, `|`, `~`, `>>`, `<<`) - use `bit32` library if available
- No `continue` keyword (Lua has never had this)
- No integer division `//` operator - use `math.floor(a/b)`

---

### 3. Slider Widgets Don't Work Reliably

> ✅ **Validated:** `FS25_UsedPlus/src/gui/TakeLoanDialog.lua` - Uses MultiTextOption for term/amount selection

**Problem:** The `Slider` GUI element doesn't fire change events properly and is difficult to configure.

**Symptoms:**
- Slider appears but doesn't respond to input
- onChange callback never fires
- Value doesn't update

**Solution:** Use quick buttons or MultiTextOption dropdowns instead.

```xml
<!-- WRONG: Slider -->
<Slider profile="fs25_slider" id="amountSlider" onChange="onAmountChanged"/>

<!-- CORRECT: Quick buttons -->
<BoxLayout profile="buttonBox" position="0px -100px">
    <Button profile="buttonOK" id="btn25" text="25%" onClick="onQuick25"/>
    <Button profile="buttonOK" id="btn50" text="50%" onClick="onQuick50"/>
    <Button profile="buttonOK" id="btn75" text="75%" onClick="onQuick75"/>
    <Button profile="buttonOK" id="btn100" text="100%" onClick="onQuick100"/>
</BoxLayout>

<!-- CORRECT: Dropdown -->
<MultiTextOption profile="fs25_multiTextOption" id="amountSelector"
                 onClick="onAmountChanged"/>
```

```lua
-- MultiTextOption setup
function MyDialog:setupAmountOptions()
    if self.amountSelector then
        self.amountSelector:setTexts({"25%", "50%", "75%", "100%"})
        self.amountSelector:setState(2)  -- Default to 50%
    end
end
```

---

### 4. DialogElement Base Class is Broken

> ✅ **Validated:** All 30+ dialogs in `FS25_UsedPlus/src/gui/` use MessageDialog base class

**Problem:** Using `DialogElement` as a base class for custom dialogs causes various issues including rendering problems and callback failures.

**Symptoms:**
- White boxes instead of dialog background
- Buttons don't respond
- Dialog doesn't close properly

**Solution:** Always use `MessageDialog` as base class.

```lua
-- WRONG
MyDialog = {}
local MyDialog_mt = Class(MyDialog, DialogElement)

-- CORRECT
MyDialog = {}
local MyDialog_mt = Class(MyDialog, MessageDialog)

function MyDialog.new(target, custom_mt)
    local self = MessageDialog.new(target, custom_mt or MyDialog_mt)
    return self
end
```

---

### 5. Custom GUI Profiles Fail Silently

> ✅ **Validated:** All UsedPlus dialog XML files use `extends="fs25_*"` profiles exclusively

**Problem:** Creating entirely new GUI profiles often doesn't work - the profile is ignored with no error message.

**Solution:** Always extend existing `fs25_*` profiles.

```xml
<!-- WRONG: Custom profile from scratch -->
<Profile name="myCustomProfile">
    <textSize value="18px"/>
    <textColor value="1 1 1 1"/>
</Profile>

<!-- CORRECT: Extend existing profile -->
<Profile name="myCustomProfile" extends="fs25_dialogText">
    <textSize value="18px"/>
    <textColor value="1 0.8 0 1"/>
</Profile>
```

---

### 6. Registering Dialogs in modDesc.xml

> ✅ **Validated:** `FS25_UsedPlus/src/utils/DialogLoader.lua` - Dynamic loading pattern

**Problem:** Registering custom dialogs via `<gui>` elements in modDesc.xml is unreliable.

**Solution:** Load dialogs dynamically on first use.

```xml
<!-- WRONG: In modDesc.xml -->
<gui>
    <gui xmlFilename="gui/MyDialog.xml" />
</gui>
```

```lua
-- CORRECT: Dynamic loading in Lua
function MyMod:showMyDialog()
    if g_gui.guis["MyDialog"] == nil then
        g_gui:loadGui(
            Utils.getFilename("gui/MyDialog.xml", self.modDirectory),
            "MyDialog",
            MyDialog.new()
        )
    end
    g_gui:showDialog("MyDialog")
end
```

---

## GUI Coordinate Issues

### 7. Y=0 is at BOTTOM, Not Top

> ✅ **Validated:** All UsedPlus dialog XML files use correct coordinate system

**Problem:** Putting elements at low Y values expecting them at top of container.

**Symptoms:**
- Headers appear at bottom
- Content overlaps footer
- Layout is "upside down"

**Solution:** Remember FS25 uses bottom-left origin.

```xml
<!-- In a 600px tall container -->

<!-- WRONG thinking: Y=0 is top -->
<Text position="0px 0px"/>     <!-- Actually at BOTTOM! -->
<Text position="0px 500px"/>   <!-- Actually at TOP! -->

<!-- CORRECT: High Y = top of container -->
<Text position="0px 560px"/>   <!-- Header (near top) -->
<Text position="0px 300px"/>   <!-- Middle content -->
<Text position="0px 40px"/>    <!-- Footer (near bottom) -->
```

---

### 8. Negative Positions in Dialog Content

> ✅ **Validated:** `FS25_UsedPlus/gui/*.xml` - All dialogs use negative Y in content containers

**Problem:** Inside `fs25_dialogContentContainer`, positions work differently - negative Y goes DOWN from top.

```xml
<GuiElement profile="fs25_dialogContentContainer">
    <!-- Negative Y offsets from TOP of container -->
    <Text position="0px -30px"/>   <!-- 30px from top -->
    <Text position="0px -100px"/>  <!-- 100px from top -->
    <Text position="0px -200px"/>  <!-- 200px from top -->
</GuiElement>
```

---

## Network/Multiplayer Issues

### 9. Forgetting Server Check in sendToServer

> ✅ **Validated:** `FS25_UsedPlus/src/events/FinanceEvents.lua:65-73` - g_server check pattern

**Problem:** Not checking if running on server before sending network event.

```lua
-- WRONG: Always sends event
function MyEvent.sendToServer(data)
    g_client:getServerConnection():sendEvent(MyEvent.new(data))
end

-- CORRECT: Execute directly on server/single-player
function MyEvent.sendToServer(data)
    if g_server ~= nil then
        -- Server or single-player: execute directly
        MyEvent.execute(data)
    else
        -- Client: send to server
        g_client:getServerConnection():sendEvent(MyEvent.new(data))
    end
end
```

---

### 10. Stream Read/Write Order Mismatch

> ✅ **Validated:** All 19 events in UsedPlus maintain consistent read/write order

**Problem:** Reading stream data in different order than it was written.

```lua
-- WRONG: Order mismatch causes data corruption
function MyEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId)
    streamWriteString(streamId, self.name)
end

function MyEvent:readStream(streamId, connection)
    self.name = streamReadString(streamId)  -- WRONG ORDER!
    self.farmId = streamReadInt32(streamId)
end

-- CORRECT: Same order for write and read
function MyEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId)
    streamWriteString(streamId, self.name)
end

function MyEvent:readStream(streamId, connection)
    self.farmId = streamReadInt32(streamId)
    self.name = streamReadString(streamId)
    self:run(connection)
end
```

---

## Miscellaneous Issues

### 11. Accessing Vehicle Before It's Ready

> ✅ **Validated:** `FS25_UsedPlus/src/extensions/BuyVehicleDataExtension.lua` - Uses callbacks

**Problem:** Trying to access vehicle properties during purchase before vehicle is fully initialized.

**Solution:** Use callbacks or delayed execution.

```lua
-- WRONG: Immediate access may fail
local vehicle = purchaseVehicle(...)
local damage = vehicle:getDamageAmount()  -- May be nil!

-- CORRECT: Access in callback or next frame
function onVehiclePurchased(vehicle)
    if vehicle and vehicle.getDamageAmount then
        local damage = vehicle:getDamageAmount()
    end
end
```

---

### 12. Not Nil-Checking Manager Access

> ✅ **Validated:** UsedPlus uses `if g_financeManager then` checks throughout

**Problem:** Accessing global manager without checking if it exists.

```lua
-- WRONG: Crashes if manager not initialized
local items = g_myManager:getItems()

-- CORRECT: Always nil-check
if g_myManager then
    local items = g_myManager:getItems()
end
```

---

### 13. g_gui:showYesNoDialog Does NOT Exist

> ✅ **Validated:** `FS25_UsedPlus/src/gui/RepairDialog.lua` - Uses YesNoDialog.show()

**Problem:** Using `g_gui:showYesNoDialog({...})` which doesn't exist in FS25.

**Error:** `attempt to call missing method 'showYesNoDialog' of table`

**Solution:** Use `YesNoDialog.show()` directly.

```lua
-- WRONG - This method doesn't exist!
g_gui:showYesNoDialog({
    title = "Confirm",
    text = "Are you sure?",
    callback = function(yes) end
})

-- CORRECT - Use YesNoDialog.show()
YesNoDialog.show(
    function(yes)
        if yes then
            -- User confirmed
        end
    end,
    nil,  -- target
    "Are you sure?",  -- text
    "Confirm"  -- title
)
```

---

### 14. Invalid Button Profile Names

> ✅ **Validated:** All UsedPlus dialogs use `buttonOK`, `buttonBack`, `buttonActivate`

**Problem:** Using `fs25_button` or `fs25_buttonText` profiles which don't exist.

**Symptoms:**
- Warning in log: `Could not retrieve GUI profile 'fs25_button'`
- Buttons may not render correctly

**Solution:** Use valid game profiles.

```xml
<!-- WRONG - These profiles don't exist! -->
<Button profile="fs25_button">
    <Text profile="fs25_buttonText" text="Click Me"/>
</Button>

<!-- CORRECT - Use valid profiles with text attribute -->
<Button profile="buttonOK" text="Click Me" onClick="onClickButton"/>
<Button profile="buttonBack" text="Cancel" onClick="onClickCancel"/>
<Button profile="buttonActivate" text="Action" onClick="onClickAction"/>
```

**Valid button profiles:** `buttonOK`, `buttonBack`, `buttonActivate`, `buttonBuy`, `buttonCancel`

---

### 15. Direct Farmland Property Access

> ✅ **Validated:** `FS25_UsedPlus/src/extensions/FarmlandManagerExtension.lua` - Uses getter APIs

**Problem:** Trying to access farmland ownership directly via `farmland.ownerFarmId` or `g_farmlandManager.farmlands`.

**Symptoms:**
- Owned land shows as $0 collateral
- Farmland iteration returns nothing
- `nil` value errors when accessing ownership

**Solution:** Use the proper API methods.

```lua
-- WRONG: Direct property access
if g_farmlandManager.farmlands then
    for _, farmland in pairs(g_farmlandManager.farmlands) do
        if farmland.ownerFarmId == farmId then  -- DOESN'T WORK!
            -- ...
        end
    end
end

-- CORRECT: Use getter methods
local farmlands = g_farmlandManager:getFarmlands()
if farmlands then
    for _, farmland in pairs(farmlands) do
        local ownerId = g_farmlandManager:getFarmlandOwner(farmland.id)
        if ownerId == farmId then
            -- This farmland is owned by the farm
            local value = farmland.price or 0
        end
    end
end
```

**Pattern source:** FS25_EnhancedLoanSystem `calculateFarmlandAmount`

---

## Quick Reference Table

| Don't Use | Use Instead | Reason |
|-----------|-------------|--------|
| `goto` / `::label::` | Nested `if` statements | FS25 uses Lua 5.1 (no goto) |
| `os.time()` | `g_currentMission.time` | Not available in FS25 Lua |
| `os.date()` | `g_currentMission.environment.currentDay/Hour` | Not available in FS25 Lua |
| `Slider` widget | Quick buttons / `MultiTextOption` | Unreliable events |
| `DialogElement` | `MessageDialog` | Rendering issues |
| Custom profiles | Extend `fs25_*` profiles | Silent failures |
| modDesc.xml gui registration | Dynamic `g_gui:loadGui()` | More reliable |
| Low Y for top elements | High Y for top elements | Bottom-left origin |
| Direct event send | `sendToServer()` pattern | Server/client handling |
| `g_gui:showYesNoDialog()` | `YesNoDialog.show()` | Method doesn't exist |
| `fs25_button` profile | `buttonOK`, `buttonBack`, etc. | Profile doesn't exist |
| `fs25_buttonText` profile | `text` attribute on Button | Profile doesn't exist |
| `g_farmlandManager.farmlands` | `g_farmlandManager:getFarmlands()` | Direct property access fails |
| `farmland.ownerFarmId` | `g_farmlandManager:getFarmlandOwner(id)` | Property doesn't exist |

---

## Financial Logic Issues

### 16. Counting Financed Assets as Collateral

> ✅ **Validated:** `FS25_UsedPlus/src/utils/FinanceCalculations.lua:calculateMaxLoanAmount()` - Excludes financed items

**Problem:** When calculating loan collateral, counting assets that are already financed/mortgaged. This allows "double-dipping" - using the same asset as collateral twice.

**Symptoms:**
- Max loan amount increases after financing land/vehicles
- Player can borrow against already-mortgaged assets

**Solution:** Track financed items and exclude them from collateral calculations.

```lua
-- WRONG: Counts ALL owned assets
for _, farmland in pairs(farmlands) do
    if ownerId == farm.farmId then
        landCollateral = landCollateral + (farmland.price * 0.6)
    end
end

-- CORRECT: Build lookup of financed items first, then exclude
local financedLandIds = {}
local deals = g_financeManager:getDealsForFarm(farm.farmId)
for _, deal in pairs(deals) do
    if deal.status == "active" and deal.itemType == "land" then
        financedLandIds[tostring(deal.itemId)] = true
    end
end

for _, farmland in pairs(farmlands) do
    if ownerId == farm.farmId then
        local isFinanced = financedLandIds[tostring(farmland.id)] or false
        if not isFinanced then
            landCollateral = landCollateral + (farmland.price * 0.6)
        end
    end
end
```

**Important distinction:**
- **Credit Score**: Count ALL assets vs ALL debts (debt-to-asset ratio)
- **Loan Collateral**: Count only UNENCUMBERED assets (can't pledge twice)

---

### 17. Wrong Farmland Area Property Name

> ✅ **Validated:** `FS25_UsedPlus/src/gui/UnifiedLandPurchaseDialog.lua` - Uses farmland.areaInHa

**Problem:** Trying to access farmland area with wrong property names like `areaInSqMeters`, `totalFieldArea`, or `area`.

**Symptoms:**
- Field size displays as "--" or "0"
- Area calculation fails silently

**Solution:** Use `farmland.areaInHa` (already in hectares).

```lua
-- WRONG: These properties don't exist
local area = farmland.areaInSqMeters  -- nil
local area = farmland.totalFieldArea  -- nil
local area = farmland.area            -- nil

-- CORRECT: Use areaInHa (already in hectares)
local farmland = g_farmlandManager:getFarmlandById(fieldId)
local areaHa = farmland.areaInHa or 0

-- Use game's localized area formatting
local areaText = string.format("%.2f %s", g_i18n:getArea(areaHa), g_i18n:getAreaUnit())
```

**Pattern source:** FS25_FarmlandOverview
