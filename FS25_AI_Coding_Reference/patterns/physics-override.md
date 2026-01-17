# Physics Override Patterns

**Safely override and restore vehicle physics properties**

Based on patterns from: Batch 1 Analysis

---

## Related API Documentation

> 📖 For physics/vehicle APIs, see the [FS25 Community LUADOC](https://github.com/umbraprior/FS25-Community-LUADOC)

| Topic | API Reference | Description |
|-------|---------------|-------------|
| Physics Engine | [Physics/](https://github.com/umbraprior/FS25-Community-LUADOC/tree/main/docs/engine/Physics) | Low-level physics functions |
| Vehicle | [Vehicle/](https://github.com/umbraprior/FS25-Community-LUADOC/tree/main/docs/script/Vehicles) | Vehicle class, motor, wheels |
| VehicleMotor | [VehicleMotor.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/Vehicles/VehicleMotor.md) | Engine properties |

---

## Overview

Override physics properties safely without corrupting vehicle state:
- Backup original values before modifying
- Restore on cleanup or when needed
- Track per-vehicle backups

---

## Physics Property Override Pattern

```lua
PhysicsOverride = {}

function PhysicsOverride:apply(vehicle, overrides)
    if vehicle == nil then
        return
    end

    -- Backup original values
    if self.backups == nil then
        self.backups = {}
    end

    -- Apply overrides selectively
    for property, value in pairs(overrides) do
        if vehicle[property] ~= nil then
            -- Backup original
            if self.backups[vehicle:getName()] == nil then
                self.backups[vehicle:getName()] = {}
            end
            self.backups[vehicle:getName()][property] = vehicle[property]

            -- Apply override
            vehicle[property] = value
        end
    end
end

function PhysicsOverride:restore(vehicle)
    if vehicle == nil or self.backups == nil then
        return
    end

    local vehicleName = vehicle:getName()
    if self.backups[vehicleName] ~= nil then
        for property, originalValue in pairs(self.backups[vehicleName]) do
            vehicle[property] = originalValue
        end
        self.backups[vehicleName] = nil
    end
end
```

---

## Usage Example

```lua
-- Apply temporary speed boost
local overrides = {
    maxSpeed = 100,
    acceleration = 2.0
}

PhysicsOverride:apply(myVehicle, overrides)

-- Later, restore original values
PhysicsOverride:restore(myVehicle)
```

---

## Embedded Translation Systems

For mods needing dynamic translations not in l10n files:

```lua
TranslationManager = {}

function TranslationManager.new()
    local self = {}
    self.strings = {
        en = {},
        de = {},
        fr = {}
    }
    self.currentLanguage = "en"
    return self
end

function TranslationManager:register(key, translations)
    -- translations = {en = "English", de = "German", fr = "French"}
    for lang, text in pairs(translations) do
        if self.strings[lang] ~= nil then
            self.strings[lang][key] = text
        end
    end
end

function TranslationManager:getText(key, language)
    language = language or self.currentLanguage
    local text = self.strings[language] and self.strings[language][key]
    return text or key  -- Fallback to key if not found
end

-- Usage
local i18n = TranslationManager.new()
i18n:register("message_welcome", {
    en = "Welcome",
    de = "Willkommen",
    fr = "Bienvenue"
})

print(i18n:getText("message_welcome"))  -- Welcome (in current language)
```

---

## Manager Interception for Game Balance

### SprayType Manager Modification

Intercept game managers to balance mechanics without modifying core game files:

```lua
-- Append function to manager load
SprayTypeManager.loadMapData = Utils.appendedFunction(
    SprayTypeManager.loadMapData,
    BetterAnimalWasteProducts.loadMapData
)

-- In the intercepted function
function BetterAnimalWasteProducts:loadMapData(xmlFile, missionInfo, baseDirectory)
    -- Get existing values from manager
    local solidFertilizer = g_sprayTypeManager:getSprayTypeByName("FERTILIZER")
    if solidFertilizer == nil or solidFertilizer.litersPerSecond == nil then
        return
    end

    -- Rebalance related types
    local sprayType = g_sprayTypeManager:getSprayTypeByName("MANURE")
    if sprayType ~= nil then
        -- Calculate ratio based on in-game prices
        local oldRatio = sprayType.litersPerSecond / solidFertilizer.litersPerSecond
        local priceRatio = 1419 / 570  -- max_sell_price / silo_cost
        local newRatio = oldRatio / priceRatio

        -- Apply new balance
        sprayType.litersPerSecond = solidFertilizer.litersPerSecond * newRatio
    end
end
```

**Key Pattern**: Intercept manager initialization to adjust game balance; uses real economic values.

---

## Common Pitfalls

### 1. Missing Nil Checks
Always verify vehicle/property exists before modifying.

### 2. Backup Key Collisions
Use unique identifiers (vehicle name + id) for backup keys.

### 3. Orphaned Backups
Clean up backups when vehicles are deleted.

### 4. Order of Operations
Manager interception must happen AFTER original load completes.
