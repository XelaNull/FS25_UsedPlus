# GUI Dialog Patterns

**How to create custom dialogs in FS25**

Based on patterns from: UsedPlus, BuyUsedEquipment, HirePurchasing, Employment, EnhancedLoanSystem

---

## Validation Status Legend

| Badge | Meaning |
|-------|---------|
| ✅ **VALIDATED** | Actively used in FS25_UsedPlus - includes file:line reference |
| ⚠️ **PARTIAL** | Pattern exists but with variations from documented example |
| 📚 **REFERENCE** | From source mod only - not validated in UsedPlus codebase |

---

## The MessageDialog Pattern

> ✅ **VALIDATED** - 20+ dialogs in UsedPlus use this pattern
> - Example: `FS25_UsedPlus/src/gui/TakeLoanDialog.lua:17` - `Class(TakeLoanDialog, MessageDialog)`
> - Example: `FS25_UsedPlus/src/gui/UnifiedPurchaseDialog.lua:15` - Full implementation

**CRITICAL:** Always use `MessageDialog` as your base class, NOT `DialogElement`.

### Basic Structure

#### XML File (gui/MyDialog.xml)
```xml
<?xml version="1.0" encoding="utf-8" standalone="no" ?>
<GUI onOpen="onOpen" onClose="onClose" onCreate="onCreate">
    <!-- Required layers -->
    <GuiElement profile="newLayer" />
    <Bitmap profile="dialogFullscreenBg" id="dialogBg" />

    <!-- Dialog container -->
    <GuiElement profile="dialogBg" id="dialogElement" size="800px 600px">
        <!-- Background panels (required) -->
        <ThreePartBitmap profile="fs25_dialogBgMiddle" />
        <ThreePartBitmap profile="fs25_dialogBgTop" />
        <ThreePartBitmap profile="fs25_dialogBgBottom" />

        <!-- Content container -->
        <GuiElement profile="fs25_dialogContentContainer">

            <!-- Title -->
            <Text profile="fs25_dialogTitle" id="dialogTitleElement"
                  position="0px -30px" text="My Dialog Title"/>

            <!-- Your content here -->
            <Text profile="fs25_dialogText" id="myText"
                  position="0px -80px" text="Content goes here"/>

        </GuiElement>

        <!-- Button bar (at bottom) -->
        <BoxLayout profile="fs25_dialogButtonBox">
            <Button profile="buttonOK" id="confirmButton"
                    text="Confirm" onClick="onConfirm"/>
            <Bitmap profile="fs25_dialogButtonBoxSeparator"/>
            <Button profile="buttonBack" id="cancelButton"
                    text="Cancel" onClick="onCancel"/>
        </BoxLayout>

    </GuiElement>
</GUI>
```

#### Lua File (src/gui/MyDialog.lua)
```lua
MyDialog = {}
local MyDialog_mt = Class(MyDialog, MessageDialog)

function MyDialog.new(target, custom_mt)
    local self = MessageDialog.new(target, custom_mt or MyDialog_mt)

    -- Store element references
    self.myText = nil

    -- Store callback
    self.callbackFunc = nil

    return self
end

-- Called when XML is loaded
function MyDialog:onGuiSetupFinished()
    MyDialog:superClass().onGuiSetupFinished(self)

    -- Cache element references by ID
    self.myText = self.target:getFirstDescendant("myText")
end

-- Called when dialog opens
function MyDialog:onOpen()
    MyDialog:superClass().onOpen(self)

    -- Initialize state
end

-- Called when dialog closes
function MyDialog:onClose()
    MyDialog:superClass().onClose(self)
end

-- Public method to set data
function MyDialog:setData(data, callback)
    self.callbackFunc = callback

    if self.myText then
        self.myText:setText(data.message or "Default")
    end
end

-- Button callbacks (must match onClick in XML)
function MyDialog:onConfirm()
    if self.callbackFunc then
        self.callbackFunc(true)
    end
    self:close()
end

function MyDialog:onCancel()
    if self.callbackFunc then
        self.callbackFunc(false)
    end
    self:close()
end

-- Close helper
function MyDialog:close()
    g_gui:closeDialog(self)
end
```

---

## YesNoDialog Base Class

> ✅ **VALIDATED** - Used for confirmations throughout UsedPlus
> - Example: `FS25_UsedPlus/src/gui/DealDetailsDialog.lua:487-495` - Early payoff confirmation
> - Example: `FS25_UsedPlus/src/gui/FinanceManagerFrame.lua:1442-1450` - Delete confirmations
> - Note: Uses `YesNoDialog.show()` static method, NOT deprecated class extension

For simple yes/no dialogs, extend `YesNoDialog` instead:

```lua
WorkHoursDialog = {}
WorkHoursDialog.INSTANCE = nil

local workHoursDialog_mt = Class(WorkHoursDialog, YesNoDialog)

function WorkHoursDialog.new(target, customMt)
    local self = YesNoDialog.new(target, customMt or workHoursDialog_mt)
    self.callback = nil
    return self
end

function WorkHoursDialog:onOpen()
    WorkHoursDialog:superClass().onOpen(self)
end

function WorkHoursDialog:onClose()
    WorkHoursDialog:superClass().onClose(self)
    self:setDialogType(DialogElement.TYPE_QUESTION)
end

function WorkHoursDialog:onClickYes(_)
    self:close()
    if self.callback then
        self.callback(true)
    end
end

function WorkHoursDialog:onClickNo(_)
    self:close()
    if self.callback then
        self.callback(false)
    end
end
```

---

## Singleton Instance Pattern

> ✅ **VALIDATED** - Two approaches used in UsedPlus:
> 1. `ensureLoaded()` + INSTANCE: `FS25_UsedPlus/src/gui/FluidPurchaseDialog.lua:16,47-52`
> 2. `getInstance()` pattern: `FS25_UsedPlus/src/gui/DealDetailsDialog.lua:25-36`

For dialogs shown from multiple places, use a static INSTANCE:

```lua
YourDialog.INSTANCE = nil

function YourDialog.register(optionalDependency)
    local dialog = YourDialog.new()
    dialog.dependency = optionalDependency
    g_gui:loadGui(g_currentModDirectory .. "gui/YourDialog.xml", "YourDialog", dialog)
    YourDialog.INSTANCE = dialog
end

function YourDialog.show(data, callback)
    if YourDialog.INSTANCE == nil then
        YourDialog.register()
    end

    local dialog = YourDialog.INSTANCE
    dialog.callback = callback
    dialog:setData(data)

    g_gui:showDialog("YourDialog")
end
```

---

## Dynamic Dialog Loading

> ✅ **VALIDATED** - All 20+ UsedPlus dialogs use dynamic loading
> - Example: `FS25_UsedPlus/src/gui/DealDetailsDialog.lua:25-36`
> - Note: UsedPlus also uses `DialogLoader` utility (undocumented pattern) for centralized management

**Don't register dialogs in modDesc.xml** - load them dynamically on first use.

### Pattern
```lua
function MyMod:showMyDialog(data, callback)
    -- Check if dialog exists
    if g_gui.guis["MyDialog"] == nil then
        -- Load dialog XML dynamically
        g_gui:loadGui(
            Utils.getFilename("gui/MyDialog.xml", self.modDirectory),
            "MyDialog",
            MyDialog.new()
        )
    end

    -- Get dialog and set data
    local dialog = g_gui.guis["MyDialog"]
    if dialog and dialog.target then
        dialog.target:setData(data, callback)
        g_gui:showDialog("MyDialog")
    end
end
```

---

## TextInput with Validation

> 📚 **REFERENCE** - Pattern documented but NOT used in UsedPlus
> - UsedPlus uses game's built-in `g_gui:showTextInputDialog()` instead
> - Source: Employment mod, custom implementations
> - Consider using game API unless custom validation needed

### XML Structure
```xml
<TextInput profile="myInputProfile" id="amountInput"
           onEnterPressed="onEnterPressed"
           onTextChanged="onTextChanged"
           enterWhenClickOutside="false">
    <ThreePartBitmap profile="fs25_textInputBg" absoluteSizeOffset="0px 0px"/>
    <Bitmap profile="fs25_textInputIconBox" position="0px 0px">
        <Bitmap profile="fs25_textInputIcon" />
    </Bitmap>
</TextInput>

<!-- Profile -->
<Profile name="myInputProfile" extends="fs25_textInput">
    <size value="340px 31px"/>
    <maxCharacters value="9"/>
</Profile>
```

### Lua Validation
```lua
function MyDialog:onOpen()
    MyDialog:superClass().onOpen(self)
    self:resetUI()
    FocusManager:setFocus(self.amountInput)
end

function MyDialog:resetUI()
    self.amountInput:setText("")
    self.amountInput.lastValidText = ""
    self.yesButton:setDisabled(true)
end

function MyDialog:onTextChanged(element, text)
    if text ~= "" then
        if tonumber(text) ~= nil then
            local currentValue = tonumber(text)

            -- Validate against limits
            if currentValue > self.maxValue then
                currentValue = self.maxValue
            end

            local formattedValue = string.format("%.0f", currentValue)
            element:setText(formattedValue)
            element.lastValidText = formattedValue
        else
            -- Invalid input - revert to last valid
            element:setText(element.lastValidText)
        end
    else
        element.lastValidText = ""
    end

    self:updateButtonState()
end

function MyDialog:updateButtonState()
    local hasValidInput = self.amountInput.lastValidText ~= nil
                      and self.amountInput.lastValidText ~= ""
    self.yesButton:setDisabled(not hasValidInput)
end
```

---

## Common UI Elements

### Text Display
```xml
<Text profile="fs25_dialogText" id="labelElement" position="0px -100px" text="Label:"/>
<Text profile="fs25_dialogText" id="valueElement" position="150px -100px" text="Value"/>
```

### Section Headers
```xml
<Text profile="mySectionTitle" position="0px -60px" text="SECTION TITLE"/>

<!-- Custom profile (in GUIProfiles section) -->
<Profile name="mySectionTitle" extends="fs25_dialogText">
    <textSize value="18px"/>
    <textBold value="true"/>
    <textColor value="1 0.8 0 1"/>  <!-- Gold color -->
</Profile>
```

### Quick Buttons (Instead of Sliders!)

> 📚 **REFERENCE** - Pattern documented but NOT yet implemented in UsedPlus
> - Source: TakeLoanDialog patterns from Giants base game
> - UsedPlus uses MultiTextOption dropdowns instead
> - **EXPLORE**: Listed in `docs/PATTERNS_TO_EXPLORE.md` as low-effort UX improvement

```xml
<BoxLayout profile="buttonBox" position="0px -150px">
    <Button profile="buttonOK" id="btn25" text="25%" onClick="onQuick25"/>
    <Button profile="buttonOK" id="btn50" text="50%" onClick="onQuick50"/>
    <Button profile="buttonOK" id="btn75" text="75%" onClick="onQuick75"/>
    <Button profile="buttonOK" id="btn100" text="100%" onClick="onQuick100"/>
</BoxLayout>

<!-- BoxLayout profile -->
<Profile name="buttonBox" extends="emptyPanel" with="anchorTopCenter">
    <size value="600px 40px"/>
    <flowDirection value="horizontal"/>
    <alignmentX value="center"/>
    <elementSpacing value="10px"/>
</Profile>
```

### Dropdown Selection (MultiTextOption)

> ✅ **VALIDATED** - Extensively used throughout UsedPlus (20+ locations)
> - Example: `FS25_UsedPlus/src/gui/TakeLoanDialog.lua:126,420-449`
> - Example: `FS25_UsedPlus/src/gui/SellVehicleDialog.lua:173,183,287` (Agent/price tiers)
> - Uses `:setTexts()` in Lua, not XML `<texts>` children

```xml
<MultiTextOption profile="fs25_multiTextOption" id="termSelector"
                 position="0px -200px" onClick="onTermChanged"/>
```

```lua
-- In onGuiSetupFinished:
self.termSelector = self.target:getFirstDescendant("termSelector")

-- Populate options:
function MyDialog:setupTermOptions()
    if self.termSelector then
        self.termSelector:setTexts({"1 Year", "3 Years", "5 Years", "10 Years"})
        self.termSelector:setState(1)  -- Default to first option (1-indexed)
    end
end

-- Handle change:
function MyDialog:onTermChanged(state)
    local selectedIndex = state  -- 1-indexed
    -- Update calculations based on selection
end
```

### OptionSlider

> ⚠️ **CAUTION** - Documented but reliability issues noted in CLAUDE.md
> - Source: Various mods
> - UsedPlus does NOT use this pattern
> - Consider MultiTextOption as safer alternative

```xml
<OptionSlider profile="fs25_optionSlider" id="targetTimeElement"
              onClick="onClickTargetTime" position="0px 40px" focusInit="onOpen"/>
```

```lua
function MyDialog:onClickTargetTime(index)
    self.selectedTargetTime = index
end

function MyDialog:updateScreen()
    self.targetTimeElement:setTexts(self.options)
    self.targetTimeElement:setState(self.selectedIndex)
end
```

---

## BoxLayout for Vertical/Horizontal Layouts

```xml
<Profile name="myVerticalLayout" extends="emptyPanel" with="anchorMiddleCenter">
    <size value="350px 200px" />
    <flowDirection value="vertical" />  <!-- or "horizontal" -->
    <useFullVisibility value="false" />
    <alignmentX value="center" />
    <alignmentY value="middle" />
    <elementSpacing value="20px" />
</Profile>
```

---

## Standard FS25 Profiles Reference

**Dialog Profiles (Always Available):**
| Profile | Usage |
|---------|-------|
| `fs25_dialogBg` | Dialog background container |
| `fs25_dialogContentContainer` | Content area |
| `fs25_dialogTitle` | Title text |
| `fs25_dialogText` | Body text |
| `fs25_dialogButtonBox` | Button container |
| `fs25_dialogButtonBoxSeparator` | Button separator |
| `buttonOK` | OK/Yes button |
| `buttonBack` | Back/Cancel button |
| `fs25_textInput` | Text input field |
| `fs25_textInputBg` | Input background |
| `fs25_textDefault` | Default text |
| `fs25_optionSlider` | Option slider |
| `fs25_multiTextOption` | Dropdown selector |
| `emptyPanel` | Empty container |
| `newLayer` | Dialog layer |
| `dialogFullscreenBg` | Fullscreen overlay |

**Anchor Modifiers:**
| Modifier | Effect |
|----------|--------|
| `anchorMiddleCenter` | Center alignment |
| `anchorTopCenter` | Top center |
| `anchorStretchingX` | Stretch horizontally |

---

## Coordinate System Reminder

> ✅ **VALIDATED** - Critical pattern used throughout UsedPlus
> - Example: `FS25_UsedPlus/gui/TakeLoanDialog.xml:14` - `position="0px -30px"` (title near top)
> - Example: All 33 GUI XML files follow this pattern correctly

**Y=0 is at BOTTOM, increases UPWARD!**

```xml
<!-- In a 600px tall dialog content area -->
<Text position="0px -30px"/>   <!-- Near TOP (30px from top) -->
<Text position="0px -300px"/>  <!-- MIDDLE -->
<Text position="0px -550px"/>  <!-- Near BOTTOM -->
```

Negative Y values offset FROM THE TOP of the container.

---

## Common Pitfalls

### 1. Dialog Won't Open
- Check console for XML parsing errors
- Ensure `dialogBg` element has `profile="dialogBg"`
- Verify all required layers are present

### 2. Buttons Don't Work
- `onClick` must exactly match Lua method name
- Method must exist on the dialog class
- Check for typos in method names

### 3. Elements Not Visible
- Check Y coordinates (remember bottom-left origin)
- Verify element is within container bounds
- Check profile exists and is visible

### 4. Text Not Updating
- Cache element reference in `onGuiSetupFinished`
- Verify element ID matches XML
- Call `:setText()` after element is cached

### 5. Dialog Appears Behind Other UI
- Ensure `<GuiElement profile="newLayer" />` is first
- Ensure `<Bitmap profile="dialogFullscreenBg" />` is second

### 6. Input Validation Issues
- Store validated text in `element.lastValidText`
- Revert to last valid on invalid input
- Use `FocusManager:setFocus()` for initial focus

---

## Minimal Working Example

**MinimalDialog.xml:**
```xml
<GUI onOpen="onOpen" onClose="onClose">
    <GuiElement profile="newLayer"/>
    <Bitmap profile="dialogFullscreenBg"/>

    <GuiElement profile="myDialog" id="dialogElement">
        <GuiElement profile="fs25_dialogContentContainer">
            <Text profile="fs25_dialogTitle" text="Hello Dialog"/>
        </GuiElement>

        <BoxLayout profile="fs25_dialogButtonBox">
            <Button profile="buttonOK" text="OK" onClick="onClickOk"/>
        </BoxLayout>
    </GuiElement>

    <GUIProfiles>
        <Profile name="myDialog" extends="fs25_dialogBg">
            <size value="400px 200px"/>
        </Profile>
    </GUIProfiles>
</GUI>
```

**MinimalDialog.lua:**
```lua
MinimalDialog = {}
local MinimalDialog_mt = Class(MinimalDialog, MessageDialog)

function MinimalDialog.new()
    return MessageDialog.new(nil, MinimalDialog_mt)
end

function MinimalDialog:onOpen()
    MinimalDialog:superClass().onOpen(self)
end

function MinimalDialog:onClickOk()
    self:close()
end

-- Singleton registration
MinimalDialog.INSTANCE = nil

function MinimalDialog.show()
    if MinimalDialog.INSTANCE == nil then
        MinimalDialog.INSTANCE = MinimalDialog.new()
        g_gui:loadGui(g_currentModDirectory .. "gui/MinimalDialog.xml",
                      "MinimalDialog", MinimalDialog.INSTANCE)
    end
    g_gui:showDialog("MinimalDialog")
end
```

**Usage:**
```lua
-- In your mod initialization
source(g_currentModDirectory .. "MinimalDialog.lua")

-- Anywhere in your code
MinimalDialog.show()
```

---

## Simple Yes/No Confirmation Dialogs

For quick yes/no confirmations without creating a full dialog class, use `YesNoDialog.show()`:

### Pattern
```lua
-- YesNoDialog.show(callback, target, text, title, yesText, noText, ...)
YesNoDialog.show(
    function(yes)
        if yes then
            -- User clicked Yes
            self:processAction()
        end
    end,
    nil,  -- target (usually nil)
    "Are you sure you want to proceed?",  -- text
    "Confirm Action"  -- title
)
```

### Full Example (From Employment mod)
```lua
function MyFrame:onClickDelete()
    YesNoDialog.show(
        MyFrame.onDeleteConfirmed,  -- callback function
        self,                        -- target (self for method callback)
        "Are you sure you want to delete this item?\n\nThis cannot be undone.",
        "Confirm Deletion"
    )
end

function MyFrame:onDeleteConfirmed(yes)
    if yes then
        -- Perform delete
        self:deleteSelectedItem()
    end
end
```

### IMPORTANT: g_gui:showYesNoDialog Does NOT Exist!

**Common mistake:** Using `g_gui:showYesNoDialog({...})` - this method does NOT exist in FS25!

```lua
-- WRONG - Will cause error "attempt to call missing method 'showYesNoDialog'"
g_gui:showYesNoDialog({
    title = "Confirm",
    text = "Are you sure?",
    callback = function(yes) end
})

-- CORRECT - Use YesNoDialog.show() directly
YesNoDialog.show(
    function(yes) end,
    nil,
    "Are you sure?",
    "Confirm"
)
```

---

## Button Profiles Reference

Use these standard game button profiles:

| Profile | Usage | Example |
|---------|-------|---------|
| `buttonOK` | Confirm/OK buttons | Accept, Yes, OK |
| `buttonBack` | Back/Cancel buttons | Cancel, Back, No |
| `buttonActivate` | Action buttons | Start, Apply, Reset |
| `buttonBuy` | Purchase buttons | Buy, Purchase |
| `buttonCancel` | Cancel/decline | Cancel, Decline |

**WRONG profiles (don't exist):**
- `fs25_button` - Does not exist!
- `fs25_buttonText` - Does not exist!
- `fs25_buttonOK` - Does not exist!

### Button XML Pattern
```xml
<!-- WRONG - fs25_button doesn't exist, child Text doesn't work -->
<Button profile="fs25_button">
    <Text profile="fs25_buttonText" text="PAY"/>
</Button>

<!-- CORRECT - Use valid profile and text attribute -->
<Button profile="buttonActivate" text="PAY" onClick="onClickPay"/>
```

---

## ScreenElement Base Class (Advanced)

> ✅ **VALIDATED** - Used for 11 complex dialogs in UsedPlus
> - Example: `FS25_UsedPlus/src/gui/DealDetailsDialog.lua:11`
> - Example: `FS25_UsedPlus/src/gui/NegotiationDialog.lua:19`
> - Example: `FS25_UsedPlus/src/gui/VehiclePortfolioDialog.lua:11`

**When to use ScreenElement instead of MessageDialog:**
- Complex multi-section layouts
- Dialogs with scrollable lists
- Dialogs with multiple interactive states

```lua
-- Pattern for ScreenElement-based dialogs
MyComplexDialog = {}
local MyComplexDialog_mt = Class(MyComplexDialog, ScreenElement)

function MyComplexDialog.new(target, custom_mt)
    local self = ScreenElement.new(target, custom_mt or MyComplexDialog_mt)
    -- ScreenElement provides more layout control than MessageDialog
    return self
end
```

**Note:** This pattern is used extensively in UsedPlus but was not originally documented. Added based on codebase validation.
