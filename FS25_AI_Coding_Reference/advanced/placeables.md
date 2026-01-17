# Placeable Patterns

**Production points, decorations, and custom specializations**

Based on patterns from: FarmVehicleShop, benchesPack, FS25_Dryer, FS25_liquidfertilizer

---

## Related API Documentation

> 📖 For placeable APIs, see the [FS25 Community LUADOC](https://github.com/umbraprior/FS25-Community-LUADOC)

| Class | API Reference | Description |
|-------|---------------|-------------|
| Placeables | [Placeables/](https://github.com/umbraprior/FS25-Community-LUADOC/tree/main/docs/script/Placeables) | Placeable classes |
| Placeable Specializations | [Specializations/](https://github.com/umbraprior/FS25-Community-LUADOC/tree/main/docs/script/Specializations) | Search "Placeable*" |
| ProductionChainManager | [ProductionChainManager.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/Misc/ProductionChainManager.md) | Production systems |
| Triggers | [Triggers/](https://github.com/umbraprior/FS25-Community-LUADOC/tree/main/docs/script/Triggers) | Trigger classes |

---

> ⚠️ **PARTIALLY VALIDATED IN FS25_UsedPlus**
>
> Core specialization patterns are validated. Production patterns are reference-only.
>
> **Validated in UsedPlus:**
> - ✅ Specialization lifecycle (`registerFunctions`, `registerEventListeners`, `registerXMLPaths`)
> - ✅ `prerequisitesPresent()` pattern
> - ✅ `onLoad()`, `onDelete()`, `saveToXMLFile()` lifecycle
> - ✅ Network sync with `onReadStream()`, `onWriteStream()`
>
> **UsedPlus Implementation:**
> - `FS25_UsedPlus/placeables/OilServicePoint.lua` - Full specialization example
>
> **Reference Only (not used in UsedPlus):**
> - 📚 Production point recipes (cyclesPerHour, costsPerActiveHour)
> - 📚 Pallet spawning systems
> - 📚 Loading/unloading stations

---

## Overview

FS25 placeables fall into several categories:
- **Production Points** - Factories, fermenting facilities, processing plants
- **Decorations** - Benches, fences, decorative objects
- **Functional** - Shops, triggers, special buildings
- **Storage** - Silos, sheds, storage buildings

---

## Basic Placeable XML Structure

All placeables need these minimum elements:

```xml
<?xml version="1.0" encoding="utf-8" standalone="no" ?>
<placeable type="simplePlaceable">
    <storeData>
        <name>$l10n_shopItem_MyPlaceable</name>
        <functions>
            <function>$l10n_function_decoration</function>
        </functions>
        <image>store/store_image.dds</image>
        <price>5000</price>
        <dailyUpkeep>10</dailyUpkeep>
        <lifetime>1000</lifetime>
        <brand>LIZARD</brand>
        <species>placeable</species>
        <category>productionPoints</category>
        <canBeSold>true</canBeSold>
        <showInStore>true</showInStore>
        <brush>
            <type>placeable</type>
            <category>production</category>
            <tab>factories</tab>
        </brush>
    </storeData>

    <base>
        <filename>myPlaceable.i3d</filename>
        <canBeDeleted>true</canBeDeleted>
        <canBeRenamed>true</canBeRenamed>
    </base>

    <placement useRandomYRotation="false" useManualYRotation="true">
        <testAreas>
            <testArea startNode="testAreaStart" endNode="testAreaEnd" />
        </testAreas>
    </placement>

    <clearAreas>
        <clearArea startNode="clearAreaStart" widthNode="clearAreaWidth"
                   heightNode="clearAreaHeight"/>
    </clearAreas>

    <leveling requireLeveling="true" maxSmoothDistance="2"
              maxSlope="75" maxEdgeAngle="30">
        <levelAreas>
            <levelArea startNode="clearAreaStart" widthNode="clearAreaWidth"
                       heightNode="clearAreaHeight" groundType="gravel"/>
        </levelAreas>
    </leveling>

    <i3dMappings>
        <i3dMapping id="clearAreaStart" node="0>0|1|0"/>
        <i3dMapping id="clearAreaWidth" node="0>0|1|0|0"/>
        <i3dMapping id="clearAreaHeight" node="0>0|1|0|1"/>
        <i3dMapping id="testAreaStart" node="0>0|2|0"/>
        <i3dMapping id="testAreaEnd" node="0>0|2|0|0"/>
    </i3dMappings>
</placeable>
```

---

## Production Point Configuration

```xml
<placeable type="productionPoint">
    <!-- storeData and base as above -->

    <productionPoint>
        <productions sharedThroughputCapacity="false">

            <!-- Simple production: Input -> Output -->
            <production id="silage" name="$l10n_fillType_silage"
                       cyclesPerHour="3" costsPerActiveHour="1.5">
                <inputs>
                    <input fillType="GRASS_WINDROW" amount="1800" />
                    <input fillType="SILAGE_ADDITIVE" amount="2" />
                </inputs>
                <outputs>
                    <output fillType="SILAGE" amount="2000" />
                </outputs>
            </production>

            <!-- Multiple input production -->
            <production id="liquidFertilizer" name="$l10n_fillType_liquidFertilizer"
                       cyclesPerHour="2" costsPerActiveHour="2.0">
                <inputs>
                    <input fillType="DIGESTATE" amount="500" />
                    <input fillType="WATER" amount="500" />
                    <input fillType="MINERAL_FEED" amount="100" />
                </inputs>
                <outputs>
                    <output fillType="LIQUIDFERTILIZER" amount="1000" />
                </outputs>
            </production>

        </productions>

        <!-- Unloading point (receive materials) -->
        <sellingStation node="sellingStation" allowMissions="false"
                       appearsOnStats="true" hideFromPricesMenu="true">
            <unloadTrigger exactFillRootNode="exactFillRootNode"
                          fillTypes="GRASS_WINDROW SILAGE_ADDITIVE"
                          aiNode="aiUnloadingNode"/>
            <baleTrigger triggerNode="baleTrigger" deleteLitersPerSecond="10000"
                        fillTypes="GRASS_WINDROW STRAW"/>
            <palletTrigger triggerNode="palletTrigger"
                          fillTypes="SILAGE_ADDITIVE FERTILIZER"/>
        </sellingStation>

        <!-- Loading point (dispense materials) -->
        <loadingStation>
            <loadTrigger triggerNode="loadingTrigger" fillLitersPerSecond="2500"
                        dischargeNode="dischargeNode" fillTypes="SILAGE FERTILIZER"
                        aiNode="aiLoadingNode"/>
        </loadingStation>

        <!-- Storage -->
        <storage isExtension="false" fillLevelSyncThreshold="100">
            <capacity fillType="GRASS_WINDROW" capacity="400000" />
            <capacity fillType="SILAGE" capacity="400000" />
            <capacity fillType="SILAGE_ADDITIVE" capacity="600" />

            <!-- Visual fill planes -->
            <fillPlane node="grassHeap" fillType="GRASS_WINDROW" minY="0" maxY="3.39" />
            <fillPlane node="silageHeap" fillType="SILAGE" minY="0" maxY="3.39" />
        </storage>

        <playerTrigger node="playerTrigger" />
    </productionPoint>

    <!-- Map hotspot -->
    <hotspots>
        <hotspot type="PRODUCTION_POINT" linkNode="mapPosition"
                 teleportNode="teleportNode"/>
    </hotspots>

    <!-- Trigger markers (icons) -->
    <triggerMarkers>
        <triggerMarker node="markerLoading" adjustToGround="true"
                      filename="$data/shared/assets/marker/markerIconLoad.i3d" />
        <triggerMarker node="markerUnloading" adjustToGround="true"
                      filename="$data/shared/assets/marker/markerIconUnload.i3d" />
    </triggerMarkers>
</placeable>
```

**Production Key Concepts:**
- `cyclesPerHour` - How many times inputs are consumed per hour
- `costsPerActiveHour` - Operating cost when production is active
- `fillLevelSyncThreshold` - Network sync threshold (100 = sync every 100 liters change)
- `sharedThroughputCapacity="false"` - Each production runs independently

---

## Decorative Placeable (Minimal)

Decorations need only basic elements - no scripts required:

```xml
<?xml version="1.0" encoding="utf-8" standalone="no"?>
<placeable type="simplePlaceable">
    <storeData>
        <name>$l10n_benches</name>
        <functions><function>$l10n_function_decoration</function></functions>
        <image>store/store_bench1.dds</image>
        <price>50</price>
        <dailyUpkeep>0</dailyUpkeep>
        <lifetime>1000</lifetime>
        <brand>NONE</brand>
        <species>placeable</species>
        <category>decoration</category>
        <canBeSold>true</canBeSold>
        <showInStore>true</showInStore>
        <brush>
            <type>placeable</type>
            <category>decoration</category>
            <tab>decoration</tab>
        </brush>
    </storeData>

    <base>
        <filename>i3d/bench1.i3d</filename>
    </base>

    <clearAreas>
        <clearArea startNode="clearAreaStart" widthNode="clearAreaWidth"
                   heightNode="clearAreaHeight"/>
    </clearAreas>

    <leveling requireLeveling="true" maxSmoothDistance="2" maxSlope="75" maxEdgeAngle="30">
        <levelAreas>
            <levelArea startNode="clearAreaStart" widthNode="clearAreaWidth"
                       heightNode="clearAreaHeight" groundType="gravel"/>
        </levelAreas>
    </leveling>

    <placement useRandomYRotation="false" useManualYRotation="true">
        <testAreas>
            <testArea startNode="testAreaStart" endNode="testAreaEnd" />
        </testAreas>
        <sounds>
            <place template="smallImp" />
        </sounds>
    </placement>

    <i3dMappings>
        <i3dMapping id="clearAreaStart" node="0>0|1|0"/>
        <i3dMapping id="clearAreaWidth" node="0>0|1|0|0"/>
        <i3dMapping id="clearAreaHeight" node="0>0|1|0|1"/>
        <i3dMapping id="testAreaStart" node="0>0|2|0"/>
        <i3dMapping id="testAreaEnd" node="0>0|2|0|0"/>
    </i3dMappings>
</placeable>
```

---

## Custom Placeable Specialization

### modDesc.xml Configuration
```xml
<modDesc descVersion="104">
    <!-- Define specialization -->
    <placeableSpecializations>
        <specialization name="vehicleSpawner"
                       className="PlaceableVehicleSpawner"
                       filename="src/PlaceableVehicleSpawner.lua" />
    </placeableSpecializations>

    <!-- Define placeable type using specialization -->
    <placeableTypes>
        <type name="farmVehicleShop"
              parent="workshop"
              filename="$dataS/scripts/placeables/Placeable.lua">
            <specialization name="vehicleSpawner" />
        </type>
    </placeableTypes>

    <storeItems>
        <storeItem xmlFilename="xml/farmVehicleShop.xml" />
    </storeItems>
</modDesc>
```

### Specialization Lua Implementation
```lua
local modName = g_currentModName

PlaceableVehicleSpawner = {
    DEBUG = false,
    SPEC_TABLE_NAME = "spec_" .. modName .. ".vehicleSpawner",
}

-- Required: Check prerequisites
function PlaceableVehicleSpawner.prerequisitesPresent(...)
    return true
end

-- Register event listeners
function PlaceableVehicleSpawner.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", PlaceableVehicleSpawner)
    SpecializationUtil.registerEventListener(placeableType, "onPostFinalizePlacement", PlaceableVehicleSpawner)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", PlaceableVehicleSpawner)
end

-- Register XML schema paths
function PlaceableVehicleSpawner.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("VehicleSpawner")
    schema:register(XMLValueType.NODE_INDEX,
        basePath .. ".vehicleSpawnAreas#shopTriggerNode", "Shop trigger node")
    schema:register(XMLValueType.NODE_INDEX,
        basePath .. ".vehicleSpawnAreas.vehicleSpawnArea(?)#startNode", "Start node")
    schema:register(XMLValueType.NODE_INDEX,
        basePath .. ".vehicleSpawnAreas.vehicleSpawnArea(?)#endNode", "End node")
    schema:setXMLSpecializationType()
end

-- Called when placeable loads
function PlaceableVehicleSpawner:onLoad(savegame)
    local spec = self[PlaceableVehicleSpawner.SPEC_TABLE_NAME]
    if spec == nil then
        self[PlaceableVehicleSpawner.SPEC_TABLE_NAME] = {}
        spec = self[PlaceableVehicleSpawner.SPEC_TABLE_NAME]
    end

    spec.vehicleSpawnPlaces = {}
end

-- Called after placement is finalized
function PlaceableVehicleSpawner:onPostFinalizePlacement()
    local spec = self[PlaceableVehicleSpawner.SPEC_TABLE_NAME]

    if not self.xmlFile:hasProperty("placeable.vehicleSpawnAreas") then
        Logging.xmlWarning(self.xmlFile, "Missing vehicle spawn areas")
        return
    end

    -- Load spawn areas from XML
    self.xmlFile:iterate("placeable.vehicleSpawnAreas.vehicleSpawnArea", function(_, key)
        local startNode = self.xmlFile:getValue(key .. "#startNode", nil,
            self.components, self.i3dMappings)
        local endNode = self.xmlFile:getValue(key .. "#endNode", nil,
            self.components, self.i3dMappings)

        if startNode and endNode then
            local place = PlacementUtil.loadPlaceFromNode(startNode, endNode)
            table.insert(spec.vehicleSpawnPlaces, place)
        end
    end)

    -- Setup shop trigger
    local triggerNode = self.xmlFile:getValue(
        "placeable.vehicleSpawnAreas#shopTriggerNode", nil,
        self.components, self.i3dMappings)

    if triggerNode then
        spec.shopTrigger = ShopTrigger.new(triggerNode)
    end

    -- Register with global system
    if g_farmVehicleShopSystem then
        g_farmVehicleShopSystem:addFarmVehicleShop(self)
    end
end

-- Cleanup
function PlaceableVehicleSpawner:onDelete()
    local spec = self[PlaceableVehicleSpawner.SPEC_TABLE_NAME]

    if spec and spec.shopTrigger then
        spec.shopTrigger:delete()
    end

    if g_farmVehicleShopSystem then
        g_farmVehicleShopSystem:removeFarmVehicleShop(self)
    end

    self[PlaceableVehicleSpawner.SPEC_TABLE_NAME] = nil
end
```

### Custom Placeable XML
```xml
<placeable type="farmVehicleShop">
    <storeData>
        <name>Farm Vehicle Shop</name>
        <price>5000</price>
        <dailyUpkeep>100</dailyUpkeep>
        <category>tools</category>
    </storeData>

    <base>
        <filename>farmVehicleShop.i3d</filename>
    </base>

    <!-- Custom specialization data -->
    <vehicleSpawnAreas shopTriggerNode="shopTrigger">
        <vehicleSpawnArea startNode="spawnArea1Start" endNode="spawnArea1End" />
        <vehicleSpawnArea startNode="spawnArea2Start" endNode="spawnArea2End" />
    </vehicleSpawnAreas>

    <i3dMappings>
        <i3dMapping id="shopTrigger" node="0>1"/>
        <i3dMapping id="spawnArea1Start" node="0>2|0"/>
        <i3dMapping id="spawnArea1End" node="0>2|1"/>
        <i3dMapping id="spawnArea2Start" node="0>3|0"/>
        <i3dMapping id="spawnArea2End" node="0>3|1"/>
    </i3dMappings>
</placeable>
```

---

## Animated Objects

Add animations to placeables:

```xml
<animatedObjects>
    <animatedObject saveId="gate">
        <animation duration="2">
            <!-- Translation -->
            <part node="gateArm">
                <keyFrame time="0.00" translation="0 0 0" />
                <keyFrame time="1.00" translation="0 3 0" />
            </part>
            <!-- Rotation -->
            <part node="gateWheel">
                <keyFrame time="0.00" rotation="0 0 0" />
                <keyFrame time="1.00" rotation="0 360 0" />
            </part>
            <!-- Visibility -->
            <part node="lightOn">
                <keyFrame time="0.00" visibility="false" />
                <keyFrame time="0.99" visibility="false" />
                <keyFrame time="1.00" visibility="true" />
            </part>
            <!-- Scale -->
            <part node="indicator">
                <keyFrame time="0.00" scale="1 1 1" />
                <keyFrame time="0.50" scale="1.5 1.5 1.5" />
                <keyFrame time="1.00" scale="1 1 1" />
            </part>
        </animation>
        <!-- User controls -->
        <controls triggerNode="controlTrigger"
                  posAction="ACTIVATE_HANDTOOL"
                  posText="action_openGate"
                  negText="action_closeGate" />
        <!-- Sounds -->
        <sounds>
            <moving template="machineryHum" />
            <posEnd template="gateOpen" />
            <negEnd template="gateClose" />
        </sounds>
    </animatedObject>
</animatedObjects>
```

---

## Common FillTypes

```
WHEAT, BARLEY, OAT, CANOLA, SUNFLOWER, SOYBEAN, MAIZE, POTATO, SUGARBEET
GRASS_WINDROW, STRAW, SILAGE, HAY
LIQUIDMANURE, DIGESTATE, MANURE
WATER, DIESEL, DEF
FERTILIZER, LIQUIDFERTILIZER, LIME, SEEDS
MILK, WOOL, EGG
WOOD, WOODCHIPS
```

---

## Common Pitfalls

### 1. Missing i3dMappings
Every node referenced in XML needs a mapping to the i3d file.

### 2. Wrong Placeable Type
- `simplePlaceable` - Basic decorations
- `productionPoint` - Factories with production
- Custom types need `<placeableTypes>` definition

### 3. FillType Case Sensitivity
FillTypes must be UPPERCASE:
```xml
<input fillType="WHEAT" />      <!-- Correct -->
<input fillType="wheat" />      <!-- Wrong -->
```

### 4. Missing Storage Capacity
If you reference a fillType in production, add storage for it:
```xml
<capacity fillType="GRASS_WINDROW" capacity="400000" />
```
