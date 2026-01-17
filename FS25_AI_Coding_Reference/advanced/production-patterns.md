# Production & Pallet Patterns

**Multi-input production, pallet spawning, and silo extensions**

Based on patterns from: LiquidFertilizer, Dryer, AutomaticWater

---

## Related API Documentation

> 📖 For production APIs, see the [FS25 Community LUADOC](https://github.com/umbraprior/FS25-Community-LUADOC)

| Class | API Reference | Description |
|-------|---------------|-------------|
| ProductionChainManager | [ProductionChainManager.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/Misc/ProductionChainManager.md) | Production chain management |
| FillTypeManager | [FillTypeManager.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/FillTypes/FillTypeManager.md) | Fill types and categories |
| FillUnit | [FillUnit.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/Specializations/FillUnit.md) | Fill storage specialization |
| Silo | [Silo.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/Specializations/Silo.md) | Silo specialization |

---

> ⚠️ **REFERENCE ONLY - NOT VALIDATED IN FS25_UsedPlus**
>
> These production patterns were extracted from community mods but are **NOT used in UsedPlus**.
> The OilServicePoint uses simple storage mechanics, not full production point recipes.
>
> **Source Mods for Reference:**
> - `FS25_Mods_Extracted/LiquidFertilizer/` - Multi-input production
> - `FS25_Mods_Extracted/Dryer/` - Timed production cycles
> - `FS25_Mods_Extracted/AutomaticWater/` - Silo extensions
>
> **Not recommended for UsedPlus** - Would be scope creep. Current OilServicePoint
> implementation is simpler and works well for maintenance purposes.

---

## Overview

Production systems in FS25:
- Multi-input recipes with ratios
- Pallet-based output spawning
- Silo extensions for automation
- Storage with fill planes

---

## Multi-Input Production

### Multiple Recipe Production Point

```xml
<productionPoint>
  <productions sharedThroughputCapacity="false">

    <!-- Recipe 1: Basic liquid fertilizer -->
    <production id="liquidFertilizer" cyclesPerHour="10" costsPerActiveHour="25">
      <inputs>
        <input fillType="LIME" amount="1"/>
        <input fillType="WATER" amount="5"/>
      </inputs>
      <outputs>
        <output fillType="LIQUIDFERTILIZER" amount="10"/>
      </outputs>
    </production>

    <!-- Recipe 2: Enhanced version -->
    <production id="liquidFertilizerPlus" cyclesPerHour="8" costsPerActiveHour="35">
      <inputs>
        <input fillType="DIGESTATE" amount="500"/>
        <input fillType="WATER" amount="500"/>
        <input fillType="MINERAL_FEED" amount="100"/>
      </inputs>
      <outputs>
        <output fillType="LIQUIDFERTILIZER" amount="1000"/>
      </outputs>
    </production>

  </productions>
</productionPoint>
```

**Key Concepts:**
- `sharedThroughputCapacity="false"` - Each recipe runs independently
- `cyclesPerHour` - How many times inputs are consumed per hour
- `costsPerActiveHour` - Operating cost when production is active

---

## Pallet Output Configuration

### Pallet Spawner with Trigger

```xml
<productionPoint>
  <productions>
    <production id="liquidFertilizer" cyclesPerHour="10" costsPerActiveHour="25">
      <inputs>
        <input fillType="LIME" amount="1"/>
        <input fillType="WATER" amount="5"/>
      </inputs>
      <outputs>
        <output fillType="LIQUIDFERTILIZER" amount="10"/>
      </outputs>
    </production>
  </productions>

  <storage isExtension="false" fillLevelSyncThreshold="50">
    <capacity fillType="LIQUIDFERTILIZER" capacity="10000"/>
    <capacity fillType="WATER" capacity="15000"/>
    <capacity fillType="LIME" capacity="5000"/>
  </storage>

  <sellingStation node="sellingStation" supportsExtension="false">
    <unloadTrigger fillTypes="LIME WATER"/>
    <palletTrigger triggerNode="palletTrigger" fillTypes="LIQUIDFERTILIZER"/>
  </sellingStation>

  <palletSpawner>
    <spawnPlaces>
      <spawnPlace startNode="palletAreaStart01" endNode="palletAreaEnd01"/>
      <spawnPlace startNode="palletAreaStart02" endNode="palletAreaEnd02"/>
    </spawnPlaces>
  </palletSpawner>
</productionPoint>
```

---

## Silo Extension Automation

### Infinite-Source Silo Extension

Create auto-refilling silo extensions for automation:

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

## Storage with Fill Planes

### Visual Fill Level Indicators

```xml
<storage isExtension="false" fillLevelSyncThreshold="100">
  <capacity fillType="GRASS_WINDROW" capacity="400000" />
  <capacity fillType="SILAGE" capacity="400000" />
  <capacity fillType="SILAGE_ADDITIVE" capacity="600" />

  <!-- Visual fill planes -->
  <fillPlane node="grassHeap" fillType="GRASS_WINDROW" minY="0" maxY="3.39" />
  <fillPlane node="silageHeap" fillType="SILAGE" minY="0" maxY="3.39" />
</storage>
```

---

## Loading/Unloading Stations

### Selling Station (Receive Materials)

```xml
<sellingStation node="sellingStation" allowMissions="false"
               appearsOnStats="true" hideFromPricesMenu="true">
  <!-- Trailer unloading -->
  <unloadTrigger exactFillRootNode="exactFillRootNode"
                fillTypes="GRASS_WINDROW SILAGE_ADDITIVE"
                aiNode="aiUnloadingNode"/>

  <!-- Bale consumption -->
  <baleTrigger triggerNode="baleTrigger" deleteLitersPerSecond="10000"
              fillTypes="GRASS_WINDROW STRAW"/>

  <!-- Pallet consumption -->
  <palletTrigger triggerNode="palletTrigger"
                fillTypes="SILAGE_ADDITIVE FERTILIZER"/>
</sellingStation>
```

### Loading Station (Dispense Materials)

```xml
<loadingStation>
  <loadTrigger triggerNode="loadingTrigger" fillLitersPerSecond="2500"
              dischargeNode="dischargeNode" fillTypes="SILAGE FERTILIZER"
              aiNode="aiLoadingNode"/>
</loadingStation>
```

---

## Income-Per-Hour Placeables

Generate passive income from production:

```lua
-- In specialization onHourChanged
function MyProduction:onHourChanged()
    local spec = self.spec_myProduction

    if spec.isActive then
        local income = spec.incomePerHour
        local farmId = self:getOwnerFarmId()

        -- Add money to farm
        g_currentMission:addMoney(income, farmId, MoneyType.HARVEST, true)
    end
end
```

---

## Common FillTypes for Production

```
-- Crops
WHEAT, BARLEY, OAT, CANOLA, SUNFLOWER, SOYBEAN, MAIZE, POTATO, SUGARBEET

-- Processed
GRASS_WINDROW, STRAW, SILAGE, HAY

-- Liquids
LIQUIDMANURE, DIGESTATE, MANURE, WATER, DIESEL, DEF

-- Fertilizers
FERTILIZER, LIQUIDFERTILIZER, LIME, SEEDS

-- Animal Products
MILK, WOOL, EGG

-- Wood
WOOD, WOODCHIPS
```

---

## Common Pitfalls

### 1. FillType Case Sensitivity
FillTypes must be UPPERCASE:
```xml
<input fillType="WHEAT" />      <!-- Correct -->
<input fillType="wheat" />      <!-- Wrong -->
```

### 2. Missing Storage Capacity
If you reference a fillType in production, add storage for it:
```xml
<capacity fillType="GRASS_WINDROW" capacity="400000" />
```

### 3. Spawn Place Configuration
Spawn places need both start and end nodes for area definition.

### 4. fillLevelSyncThreshold
Set appropriate threshold (100-1000) to balance network traffic vs accuracy.
