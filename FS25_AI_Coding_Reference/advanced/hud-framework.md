# HUD & UI Framework Systems

**Interactive HUD displays with click areas and mouse cursor management**

Based on patterns from: AnimalsDisplay, HUD System mods

---

## Related API Documentation

> 📖 For HUD APIs, see the [FS25 Community LUADOC](https://github.com/umbraprior/FS25-Community-LUADOC)

| Class | API Reference | Description |
|-------|---------------|-------------|
| HUDElement | [HUDElement.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/GUI/HUDElement.md) | Base HUD element |
| HUDDisplayElement | [HUDDisplayElement.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/GUI/HUDDisplayElement.md) | Display components |
| HUDTextDisplay | [HUDTextDisplay.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/GUI/HUDTextDisplay.md) | Text overlays |
| InfoDisplay | [InfoDisplay.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/GUI/InfoDisplay.md) | Info panels |
| Overlay | [Overlay.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/GUI/Overlay.md) | Screen overlays |

---

> ⚠️ **REFERENCE ONLY - NOT VALIDATED IN FS25_UsedPlus**
>
> These patterns were extracted from community mods but are **NOT used in UsedPlus**.
> UsedPlus uses a dialog-based architecture (MessageDialog/ScreenElement) rather than
> HUD overlay systems.
>
> **Source Mods for Reference:**
> - `FS25_Mods_Extracted/AnimalsDisplay/hlHud.lua` - HUD box manager
> - `FS25_Mods_Extracted/AnimalsDisplay/hlBox.lua` - Click area handling
> - `FS25_Mods_Extracted/AnimalsDisplay/hlUtils.lua` - Utility functions
>
> **EXPLORE:** Listed in `docs/PATTERNS_TO_EXPLORE.md` as potential future feature
> for real-time financial status display.

---

## Overview

Complex HUD displays require modular architecture with separate concerns for:
- Layout and positioning
- Input handling (mouse, keyboard)
- Rendering
- State persistence

---

## HUD Box Architecture

### Core HUD Box Structure

```lua
-- Core HUD box structure with click area registration
hlBox.generate(args)
-- args: {name, displayName, info, width, height, show, autoZoomOutIn, etc.}

function hlBox:setClickArea(args)
  -- args: {whatClick, areaClick, x, y, width, height, onClick}
  if self.clickAreas[whatClick] == nil then
    self.clickAreas[whatClick] = {}
  end
  table.insert(self.clickAreas[whatClick], {
    x, y, width, height,  -- Click area boundaries
    onClick = function(args) ... end,  -- Callback when clicked
    areaClick = areaClick  -- Type identifier for settings/close/etc
  })
end
```

**Key Pattern**: Separate click areas into organized tables, iterate in priority order.

---

## Click Area Organization

### Priority-Based Hit Detection

Organize clickable regions in priority-based tables for efficient hit detection:

```lua
-- Structure areas by type
self.clickAreas = {
    settings = {},  -- High priority
    close = {},     -- High priority
    menu = {},      -- Medium priority
    content = {}    -- Low priority
}

-- Check clicks in priority order
function hlBox:checkClick(x, y)
    -- Check highest priority first
    for _, area in ipairs(self.clickAreas.settings) do
        if self:isInArea(x, y, area) then
            area.onClick()
            return true  -- Consume event
        end
    end

    for _, area in ipairs(self.clickAreas.close) do
        if self:isInArea(x, y, area) then
            area.onClick()
            return true
        end
    end

    -- Continue to lower priority...
    return false
end
```

**Pattern**:
- Structure areas by type (settings, close, menu, content)
- Iterate in priority order
- Consume events at correct level
- Callback pattern for extensibility

---

## Mouse Cursor Toggle System

### Input Action Registration

```xml
<!-- modDesc.xml -->
<actions>
  <action name="HL_ONOFFMOUSECURSOR" ignoreComboMask="false"
          axisType="HALF" category="ONFOOT VEHICLE" />
</actions>

<inputBinding>
  <actionBinding action="HL_ONOFFMOUSECURSOR">
    <binding device="KB_MOUSE_DEFAULT" input="KEY_f9"
             axisComponent="+" neutralInput="0" index="1"/>
  </actionBinding>
</inputBinding>
```

### Cursor State Management

```lua
PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(
  PlayerInputComponent.registerGlobalPlayerActionEvents,
  function(self, controlling)
    local _, eventId = g_inputBinding:registerActionEvent(
        InputAction.HL_ONOFFMOUSECURSOR,
        self,
        self.hlHudSystemActionKeyMouse,
        false, true, false, true, nil, true
    )
  end
)

function PlayerInputComponent:hlHudSystemActionKeyMouse(actionName, inputValue)
  if actionName == "HL_ONOFFMOUSECURSOR" then
    g_currentMission.hlUtils.mouseOnOff(not g_currentMission.hlUtils.isMouseCursor)
  end
end
```

---

## Progressive/Lazy Script Loading

Load code modules only when needed to reduce memory footprint:

```lua
function Animals_Display:loadSource(phase)
  if phase == 1 then
    source(Animals_Display.modDir.."Animals_DisplaySetGet.lua")
  elseif phase == 3 then
    source(Animals_Display.modDir.."draw/Animals_Display_DrawBox.lua")
    source(Animals_Display.modDir.."xml/Animals_Display_XmlBox.lua")
  end
end

Animals_Display:loadSource(1)  -- Load essentials at startup
-- Later, when UI needed:
Animals_Display:loadSource(3)  -- Load UI code on demand
```

---

## User Settings Storage

### Folder Hierarchy Creation

```lua
createFolder(getUserProfileAppPath().. "modSettings/")
createFolder(getUserProfileAppPath().. "modSettings/HL/")
createFolder(getUserProfileAppPath().. "modSettings/HL/HudSystem/languages/")
createFolder(getUserProfileAppPath().. "modSettings/HL/HudSystem/hud/")

local settingsPath = getUserProfileAppPath().. "modSettings/HL/HudSystem/config.xml"
```

### Settings Hierarchy Pattern

Organize user settings with predictable structure:
- Level 1: `modSettings/`
- Level 2: Author directory (`modSettings/HL/`)
- Level 3: Mod directory (`modSettings/HL/HudSystem/`)
- Level 4: Type directories (`languages/`, `hud/`, `config/`)

Prevents conflicts and aids user management.

---

## Modular UI Architecture

Complex UI systems require modular architecture with separated concerns:

| Component | Responsibility |
|-----------|----------------|
| hlHudSystem | Main orchestrator |
| hlHud, hlBox, hlPda | Specific UI components |
| hlHudSystemDraw | Centralized rendering |
| hlHudSystemMouseKeyEvents | Input routing |
| hlHudSystemXml | Persistence |

Each layer handles its responsibility independently.

---

## Common Pitfalls

### 1. Click Area Z-Order
Always check higher priority areas before lower ones.

### 2. Mouse Cursor State Conflicts
Track cursor state globally to avoid multiple mods fighting over cursor.

### 3. Memory from Lazy Loading
Still clean up lazily loaded modules in onDelete.

### 4. Settings Path Issues
Always use `getUserProfileAppPath()` for cross-platform compatibility.
