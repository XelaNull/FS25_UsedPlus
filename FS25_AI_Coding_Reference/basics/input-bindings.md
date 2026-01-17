# Input Bindings & Actions

**How to add keyboard and controller bindings to FS25 mods**

Based on patterns from: 164+ working community mods

---

> ✅ **FULLY VALIDATED IN FS25_UsedPlus**
>
> Input binding patterns are validated in UsedPlus with 5 custom actions.
>
> **UsedPlus Implementation:**
> - `FS25_UsedPlus/modDesc.xml:258-282` - Action definitions
> - `FS25_UsedPlus/src/main.lua` - Input registration
> - `FS25_UsedPlus/src/extensions/ShopConfigScreenExtension.lua` - Context-specific bindings
>
> **Validated Actions:**
> | Action | Binding | Category |
> |--------|---------|----------|
> | USEDPLUS_OPEN_FINANCE_MANAGER | Shift+F | ONFOOT VEHICLE |
> | USEDPLUS_SEARCH_USED | U | MENU |
> | USEDPLUS_INSPECT_VEHICLE | I | MENU |
> | USEDPLUS_ACTIVATE_OBD | O | ONFOOT |
> | USEDPLUS_TIRES | T | MENU |

---

## Overview

Input bindings allow players to trigger mod functionality via:
- Keyboard shortcuts
- Key combinations (Ctrl+Key, Alt+Key)
- Gamepad buttons

---

## Defining Actions in modDesc.xml

### Simple Key Press
```xml
<actions>
    <action name="MYMOD_TOGGLE" category="ONFOOT VEHICLE"
            axisType="HALF" ignoreComboMask="false">
        <binding device="KB_MOUSE_DEFAULT" input="KEY_u"/>
    </action>
</actions>
```

### Key Combination (Ctrl + U)
```xml
<actions>
    <action name="MYMOD_MENU" category="ONFOOT VEHICLE"
            axisType="HALF" ignoreComboMask="false">
        <binding device="KB_MOUSE_DEFAULT" input="KEY_lctrl KEY_u"/>
    </action>
</actions>
```

### Gamepad Binding
```xml
<actions>
    <action name="MYMOD_ACCEPT" category="VEHICLE"
            axisType="HALF" ignoreComboMask="false">
        <binding device="GAMEPAD_DEFAULT" input="BUTTON_5"/>
    </action>
</actions>
```

### Multiple Bindings (Keyboard + Gamepad)
```xml
<actions>
    <action name="MYMOD_ACTION" category="ONFOOT VEHICLE"
            axisType="HALF" ignoreComboMask="false">
        <binding device="KB_MOUSE_DEFAULT" input="KEY_lctrl KEY_m"/>
        <binding device="GAMEPAD_DEFAULT" input="BUTTON_6"/>
    </action>
</actions>
```

---

## Action Categories

| Category | When Active |
|----------|-------------|
| `ONFOOT` | Only when player is walking |
| `VEHICLE` | Only when in a vehicle |
| `ONFOOT VEHICLE` | Both walking and in vehicle |
| `MENU` | When in menu/UI screens |

```xml
<!-- Player on foot only -->
<action name="MYMOD_WALK_ACTION" category="ONFOOT" .../>

<!-- Vehicle only -->
<action name="MYMOD_DRIVE_ACTION" category="VEHICLE" .../>

<!-- Both contexts -->
<action name="MYMOD_UNIVERSAL" category="ONFOOT VEHICLE" .../>
```

---

## Common Key Codes

### Letters & Numbers
```
KEY_a through KEY_z
KEY_0 through KEY_9
```

### Modifiers
```
KEY_lctrl    - Left Control
KEY_rctrl    - Right Control
KEY_lalt     - Left Alt
KEY_ralt     - Right Alt
KEY_lshift   - Left Shift
KEY_rshift   - Right Shift
```

### Function Keys
```
KEY_f1 through KEY_f12
```

### Special Keys
```
KEY_space    - Spacebar
KEY_return   - Enter
KEY_escape   - Escape
KEY_tab      - Tab
KEY_backspace
KEY_delete
KEY_insert
KEY_home
KEY_end
KEY_pageup
KEY_pagedown
```

### Arrow Keys
```
KEY_up
KEY_down
KEY_left
KEY_right
```

### Numpad
```
KEY_KP_0 through KEY_KP_9
KEY_KP_plus
KEY_KP_minus
KEY_KP_multiply
KEY_KP_divide
KEY_KP_enter
```

---

## Gamepad Buttons

```
BUTTON_1 through BUTTON_12
AXIS_1 through AXIS_6
```

Common mappings (vary by controller):
- `BUTTON_1` - A/X
- `BUTTON_2` - B/Circle
- `BUTTON_3` - X/Square
- `BUTTON_4` - Y/Triangle
- `BUTTON_5` - LB/L1
- `BUTTON_6` - RB/R1

---

## Registering Action Events in Lua

### Basic Registration
```lua
function MyMod:registerInputActions()
    -- Register input action
    local _, actionEventId = g_inputBinding:registerActionEvent(
        'MYMOD_TOGGLE',       -- Action name from modDesc.xml
        self,                  -- Target object
        self.onToggleAction,   -- Callback function
        false,                 -- triggerUp
        true,                  -- triggerDown
        false,                 -- triggerAlways
        true                   -- startActive
    )

    -- Store the event ID for cleanup
    self.actionEventId = actionEventId

    -- Set display text (shown in help menu)
    g_inputBinding:setActionEventText(actionEventId, g_i18n:getText("input_MYMOD_TOGGLE"))
    g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
end
```

### Callback Function
```lua
function MyMod:onToggleAction(actionName, inputValue)
    -- inputValue is 1 when pressed, 0 when released (for triggerUp)
    print("Toggle action triggered!")
    self:toggleMenu()
end
```

### Cleanup on Unload
```lua
function MyMod:cleanup()
    if self.actionEventId ~= nil then
        g_inputBinding:removeActionEvent(self.actionEventId)
        self.actionEventId = nil
    end
end
```

---

## Parameter Reference

### registerActionEvent Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `actionName` | string | Action name from modDesc.xml |
| `target` | object | Object to call callback on |
| `callback` | function | Function to call when triggered |
| `triggerUp` | bool | Fire when key released |
| `triggerDown` | bool | Fire when key pressed |
| `triggerAlways` | bool | Fire continuously while held |
| `startActive` | bool | Active immediately |

### Common Configurations

```lua
-- Fire once on key press
g_inputBinding:registerActionEvent('ACTION', self, callback, false, true, false, true)

-- Fire once on key release
g_inputBinding:registerActionEvent('ACTION', self, callback, true, false, false, true)

-- Fire continuously while held
g_inputBinding:registerActionEvent('ACTION', self, callback, false, true, true, true)

-- Fire on both press and release
g_inputBinding:registerActionEvent('ACTION', self, callback, true, true, false, true)
```

---

## Text Priority Levels

Controls where action appears in the help display:

```lua
g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_HIGH)  -- Always visible
g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_HIGH)
g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_NORMAL)     -- Standard
g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_LOW)
g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_LOW)   -- May be hidden
```

---

## Visibility Control

### Show/Hide Based on Context
```lua
function MyMod:updateActionVisibility()
    if self.actionEventId ~= nil then
        -- Show only when conditions are met
        local isVisible = self:shouldShowAction()
        g_inputBinding:setActionEventActive(self.actionEventId, isVisible)
    end
end

function MyMod:shouldShowAction()
    -- Example: Only show when player has a vehicle selected
    return g_currentMission.controlledVehicle ~= nil
end
```

### Update Text Dynamically
```lua
function MyMod:updateActionText()
    if self.actionEventId ~= nil then
        local newText = self.isEnabled and "Disable Feature" or "Enable Feature"
        g_inputBinding:setActionEventText(self.actionEventId, newText)
    end
end
```

---

## Complete Example

### modDesc.xml
```xml
<modDesc descVersion="104">
    <actions>
        <action name="MYMOD_OPEN_MENU" category="ONFOOT VEHICLE"
                axisType="HALF" ignoreComboMask="false">
            <binding device="KB_MOUSE_DEFAULT" input="KEY_lctrl KEY_m"/>
        </action>
        <action name="MYMOD_QUICK_ACTION" category="VEHICLE"
                axisType="HALF" ignoreComboMask="false">
            <binding device="KB_MOUSE_DEFAULT" input="KEY_numpad1"/>
            <binding device="GAMEPAD_DEFAULT" input="BUTTON_5"/>
        </action>
    </actions>

    <l10n>
        <text name="input_MYMOD_OPEN_MENU">
            <en>Open My Mod Menu</en>
            <de>Mein Mod-Menü öffnen</de>
        </text>
        <text name="input_MYMOD_QUICK_ACTION">
            <en>Quick Action</en>
            <de>Schnellaktion</de>
        </text>
    </l10n>
</modDesc>
```

### Lua Implementation
```lua
MyMod = {}

function MyMod:loadMap()
    self:registerInputActions()
end

function MyMod:registerInputActions()
    -- Menu action (Ctrl+M)
    local _, menuEventId = g_inputBinding:registerActionEvent(
        'MYMOD_OPEN_MENU', self, self.onOpenMenu, false, true, false, true
    )
    self.menuEventId = menuEventId
    g_inputBinding:setActionEventText(menuEventId, g_i18n:getText("input_MYMOD_OPEN_MENU"))
    g_inputBinding:setActionEventTextPriority(menuEventId, GS_PRIO_NORMAL)

    -- Quick action (Numpad 1 or gamepad button)
    local _, quickEventId = g_inputBinding:registerActionEvent(
        'MYMOD_QUICK_ACTION', self, self.onQuickAction, false, true, false, true
    )
    self.quickEventId = quickEventId
    g_inputBinding:setActionEventText(quickEventId, g_i18n:getText("input_MYMOD_QUICK_ACTION"))
    g_inputBinding:setActionEventTextPriority(quickEventId, GS_PRIO_LOW)
end

function MyMod:onOpenMenu(actionName, inputValue)
    print("Opening menu...")
    -- Open your custom menu
end

function MyMod:onQuickAction(actionName, inputValue)
    print("Quick action triggered!")
    -- Perform quick action
end

function MyMod:deleteMap()
    if self.menuEventId then
        g_inputBinding:removeActionEvent(self.menuEventId)
    end
    if self.quickEventId then
        g_inputBinding:removeActionEvent(self.quickEventId)
    end
end

addModEventListener(MyMod)
```

---

## Common Pitfalls

### 1. Action Name Mismatch
Action name in Lua must exactly match modDesc.xml:
```xml
<action name="MYMOD_ACTION" .../>
```
```lua
-- Must match exactly (case-sensitive)
g_inputBinding:registerActionEvent('MYMOD_ACTION', ...)  -- ✓
g_inputBinding:registerActionEvent('mymod_action', ...)  -- ✗
```

### 2. Forgetting Cleanup
Always remove action events when mod unloads to prevent memory leaks.

### 3. Conflicting Keybindings
- Avoid common game keybindings (WASD, E, Q, etc.)
- Use modifier keys (Ctrl, Alt) for mod-specific actions
- Check other popular mods for conflicts

### 4. Not Setting Text
Without `setActionEventText`, your action won't appear in the help display.
