# Vehicle Info Box Pattern

**Adding custom information to the vehicle info display (bottom-right when pointing at a vehicle)**

Based on patterns from: InfoDisplayExtension, HirePurchasing, Real Vehicle Breakdowns

---

## Overview

When a player points their mouse at a vehicle while on foot, an info box appears in the bottom-right corner showing vehicle details. Mods can add custom lines to this display.

---

## Quick Start

```lua
-- In your mod's initialization or extension file
function MyMod:showInfo(box)
    -- Add a simple line
    box:addLine(g_i18n:getText("mymod_label"), "Value Text")
end

-- Hook into Vehicle.showInfo (do this at script load time)
Vehicle.showInfo = Utils.appendedFunction(Vehicle.showInfo, MyMod.showInfo)
```

---

## The box:addLine() API

```lua
box:addLine(key, value, accentuate, accentuateColor)
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `key` | string | Yes | Label displayed on left (use `g_i18n:getText()` for localization) |
| `value` | string | Yes | Value displayed on right |
| `accentuate` | boolean | No | If true, highlights line with warning styling |
| `accentuateColor` | table | No | RGBA color `{r, g, b, a}` with values 0-1 |

**Note:** If a line with the same `key` already exists, it updates the value instead of adding a duplicate.

---

## Complete Example: Fluid Levels Display

```lua
-- File: src/extensions/VehicleInfoExtension.lua

VehicleInfoExtension = {}

function VehicleInfoExtension:showInfo(box)
    local spec = self.spec_usedPlusMaintenance
    if spec == nil then return end

    -- Oil Level with color gradient (red when low, green when full)
    if spec.oilLevel ~= nil then
        local level = spec.oilLevel
        local color = {1 - level, level, 0, 1}  -- Red to green
        box:addLine(
            g_i18n:getText("usedplus_oil_level"),
            string.format("%d%%", math.floor(level * 100)),
            level < 0.25,  -- Accentuate if critically low
            color
        )
    end

    -- Hydraulic Fluid
    if spec.hydraulicFluidLevel ~= nil then
        local level = spec.hydraulicFluidLevel
        local color = {1 - level, level, 0, 1}
        box:addLine(
            g_i18n:getText("usedplus_hydraulic_level"),
            string.format("%d%%", math.floor(level * 100)),
            level < 0.25,
            color
        )
    end
end

-- Register the hook
Vehicle.showInfo = Utils.appendedFunction(Vehicle.showInfo, VehicleInfoExtension.showInfo)
```

---

## Common Formatting Patterns

```lua
-- Money
box:addLine(g_i18n:getText("label"), g_i18n:formatMoney(1234, 0, true, true))
-- Output: "Label: $1,234"

-- Percentage
box:addLine(g_i18n:getText("label"), string.format("%d%%", value * 100))
-- Output: "Label: 75%"

-- Weight
box:addLine(g_i18n:getText("label"), string.format("%1.2f t", self:getTotalMass()))
-- Output: "Label: 12.50 t"

-- Time
box:addLine(g_i18n:getText("label"), string.format("%02d:%02d", hours, minutes))
-- Output: "Label: 08:30"

-- Liters/Volume
box:addLine(g_i18n:getText("label"), g_i18n:formatFluid(liters))
-- Output: "Label: 1,500 l"
```

---

## Hooking Methods

### Utils.appendedFunction (Recommended)
Runs your code AFTER the base game code. No need to call superFunc.

```lua
Vehicle.showInfo = Utils.appendedFunction(Vehicle.showInfo, MyMod.showInfo)

function MyMod:showInfo(box)
    -- Your code here - base game already ran
end
```

### Utils.prependedFunction
Runs your code BEFORE the base game code.

```lua
Vehicle.showInfo = Utils.prependedFunction(Vehicle.showInfo, MyMod.showInfo)
```

### Utils.overwrittenFunction
Full control - you MUST call superFunc or base game code won't run!

```lua
Vehicle.showInfo = Utils.overwrittenFunction(Vehicle.showInfo, function(self, superFunc, box)
    superFunc(self, box)  -- REQUIRED: Call original
    -- Your code after
end)
```

---

## Advanced: Modifying Existing Lines

You can access `box.lines` to modify lines added by other mods:

```lua
function MyMod:showInfo(box)
    -- Hide a specific line added by another mod
    for i = #box.lines, 1, -1 do
        if box.lines[i].key == g_i18n:getText("some_other_mod_label") then
            box.lines[i].isActive = false
        end
    end
end
```

Line object properties:
- `key` - The label text
- `value` - The value text
- `isActive` - Boolean controlling visibility
- `accentuate` - Boolean for warning styling
- `accentuateColor` - RGBA color table

---

## Reference Mods

| Mod | Location | Notes |
|-----|----------|-------|
| InfoDisplayExtension | `FS25_Mods_Extracted/` | Best reference for showInfo pattern |
| HirePurchasing | `FS25_Mods_Extracted/FS25_HirePurchasing/src/VehicleExtension.lua` | Simple lease payment display |
| Real Vehicle Breakdowns | `FS25_Mods_Extracted/FS25_gameplay_Real_Vehicle_Breakdowns/scripts/vehicles/rvbVehicle.lua` | Inspection/repair/service display |

---

## Translation Keys

Add to your `translations/l10n_en.xml`:

```xml
<e k="usedplus_oil_level" v="Oil Level"/>
<e k="usedplus_hydraulic_level" v="Hydraulic Fluid"/>
```

---

## Conditional Display

Only show info when relevant:

```lua
function MyMod:showInfo(box)
    local spec = self.spec_mySpecialization

    -- Skip if specialization not present
    if spec == nil then return end

    -- Skip if feature disabled
    if not spec.isEnabled then return end

    -- Only show if value is meaningful
    if spec.someValue > 0.01 then
        box:addLine(g_i18n:getText("label"), string.format("%d%%", spec.someValue * 100))
    end
end
```
