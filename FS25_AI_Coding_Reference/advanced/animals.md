# Animal System Integration

**Querying animal data and integrating with husbandry systems**

Based on patterns from: AnimalsDisplay, AutomaticWater_Animals_Greenhouses

---

> ⚠️ **REFERENCE ONLY - NOT VALIDATED IN FS25_UsedPlus**
>
> These patterns were extracted from community mods but are **NOT used in UsedPlus**.
> UsedPlus is focused on vehicle/equipment finance and does not integrate with
> animal husbandry systems.
>
> **Source Mods for Reference:**
> - `FS25_Mods_Extracted/AnimalsDisplay/` - Animal status display
> - `FS25_Mods_Extracted/AutomaticWater_Animals_Greenhouses/` - Automated animal care
>
> **Not planned for UsedPlus** - Out of scope for vehicle/finance focus.

---

## Overview

FS25 animal systems provide:
- Animal stables/husbandries per farm
- Health, food, water, manure tracking
- Product generation (milk, wool, eggs)
- FillType categories for animal feed

---

## Query Animal Stables

### Access Animal Data

```lua
local stable = g_currentMission:getAnimalByTypeAndFarmId(animalType, farmId)
if stable then
  print(stable.health, stable.food, stable.water, stable.manure)
  print("Animals: " .. stable.numAnimals)
  print("Product: " .. stable.productType)
end
```

### Register Mod Dependency

```lua
-- Check if dependent mod is loaded
g_currentMission.hlUtils.modLoad("FS25_AnimalsDisplay")
```

---

## FillType Category System

### Check Animal Feed Categories

```lua
-- Check fill type category membership
if g_fillTypeManager.categoryNameToFillTypes["ANIMAL"][fillTypeId] then
  -- Is animal feed
end

-- Common categories:
-- ANIMAL        - General animal products
-- HORSE         - Horse-specific items
-- CROP          - Harvestable crops
-- FERTILIZER    - Solid fertilizers
-- LIQUIDFERTILIZER - Liquid fertilizers
```

---

## Automatic Water/Feed Systems

### Silo Extension for Automation

Create auto-refilling silo extensions for animal water:

```xml
<placeable type="siloExtension">
  <siloExtension>
    <!-- Capacity and fillLevel set to 999999999 for infinite source -->
    <storage node="storage" fillTypes="WATER"
             capacity="999999999"
             isExtension="true">
      <startFillLevel fillType="WATER" fillLevel="999999999" />
    </storage>
  </siloExtension>
</placeable>
```

**Pattern**: Set both capacity and initial fill to same large value for effective "infinite" supply. Perfect for water automation to stables/greenhouses.

---

## Animal Husbandry Access

### Iterate Farm Animals

```lua
function getAnimalStats(farmId)
    local stats = {}

    -- Get all husbandries
    for _, husbandry in pairs(g_currentMission.husbandries) do
        if husbandry:getOwnerFarmId() == farmId then
            local animals = husbandry:getAnimals()

            for _, animal in ipairs(animals) do
                table.insert(stats, {
                    type = animal.subType.name,
                    health = animal:getHealthFactor(),
                    age = animal:getAge()
                })
            end
        end
    end

    return stats
end
```

---

## Animal Product Monitoring

```lua
function checkAnimalProducts(husbandry)
    -- Check for milk production
    if husbandry.spec_husbandryMilk then
        local fillLevel = husbandry:getFillLevel(FillType.MILK)
        local capacity = husbandry:getCapacity(FillType.MILK)
        print(string.format("Milk: %d / %d", fillLevel, capacity))
    end

    -- Check for manure
    if husbandry.spec_husbandryManure then
        local manure = husbandry:getFillLevel(FillType.MANURE)
        print("Manure level: " .. manure)
    end
end
```

---

## Common Pitfalls

### 1. Nil Checks Required
Always check if animal/husbandry exists before accessing properties.

### 2. Farm ID Filtering
Animals belong to farms - filter by farmId when needed.

### 3. Category vs FillType
Use categories for groups of related fillTypes, not individual checks.

### 4. Infinite Silo Values
999999999 is the effective "infinite" - don't use math.huge.
