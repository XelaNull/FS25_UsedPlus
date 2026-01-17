# Manager Pattern

**Singleton managers for global state and hourly processing**

Based on patterns from: UsedPlus, BuyUsedEquipment, HirePurchasing, EnhancedLoanSystem

---

## Validation Status Legend

| Badge | Meaning |
|-------|---------|
| ✅ **VALIDATED** | Actively used in FS25_UsedPlus - includes file:line reference |
| ⚠️ **PARTIAL** | Pattern exists but with variations from documented example |
| 📚 **REFERENCE** | From source mod only - not validated in UsedPlus codebase |

---

## Overview

> ✅ **VALIDATED** - 5 managers in UsedPlus implement this pattern
> - `FS25_UsedPlus/src/managers/FinanceManager.lua` (37KB, primary)
> - `FS25_UsedPlus/src/managers/UsedVehicleManager.lua` (80KB, largest)
> - `FS25_UsedPlus/src/managers/VehicleSaleManager.lua` (34KB)
> - `FS25_UsedPlus/src/managers/BankInterestManager.lua` (9KB, variant)
> - `FS25_UsedPlus/src/managers/DifficultyScalingManager.lua` (7KB, variant)

Managers are singleton classes that:
- Hold global state (active deals, searches, listings)
- Process time-based updates (hourly payments, TTL countdowns)
- Coordinate between UI and data layers
- Handle save/load integration

---

## Basic Manager Structure

> ✅ **VALIDATED** - All UsedPlus managers follow this structure
> - Example: `FS25_UsedPlus/src/managers/FinanceManager.lua:19-48` - Constructor
> - Example: `FS25_UsedPlus/src/managers/FinanceManager.lua:147-155` - loadMapFinished

```lua
--[[
    MyManager - Manages [description]

    Responsibilities:
    - Track active items for all farms
    - Process hourly updates (HOUR_CHANGED)
    - Provide data to UI components
    - Handle save/load
]]

MyManager = {}
local MyManager_mt = Class(MyManager)

-- Singleton instance (set in main.lua)
g_myManager = nil

function MyManager.new()
    local self = setmetatable({}, MyManager_mt)

    -- State
    self.activeItems = {}
    self.nextItemId = 1

    -- Server check
    self.isServer = false

    return self
end

--[[
    Called after map is fully loaded
    Subscribe to game events here
]]
function MyManager:loadMapFinished()
    self.isServer = g_currentMission:getIsServer()

    if self.isServer then
        -- Subscribe to hourly updates
        g_messageCenter:subscribe(
            MessageType.HOUR_CHANGED,
            self.onHourChanged,
            self
        )
    end
end

--[[
    Called every game hour (server only)
]]
function MyManager:onHourChanged()
    if not self.isServer then return end

    -- Process all farms
    for farmId, farm in pairs(g_farmManager:getFarms()) do
        self:processItemsForFarm(farmId, farm)
    end
end

--[[
    Process items for a single farm
]]
function MyManager:processItemsForFarm(farmId, farm)
    local items = farm.myItems or {}

    for i = #items, 1, -1 do
        local item = items[i]

        -- Update timers
        item.ttl = item.ttl - 1

        -- Check for completion
        if item.ttl <= 0 then
            self:onItemExpired(item, farm, i)
        elseif item.tts <= 0 and item.status == "pending" then
            self:onItemReady(item, farm)
        else
            item.tts = item.tts - 1
        end
    end
end

--[[
    Generate unique ID for new items
]]
function MyManager:generateId()
    local id = string.format("item_%d_%d", g_currentMission.time, self.nextItemId)
    self.nextItemId = self.nextItemId + 1
    return id
end

--[[
    Get items for a specific farm
]]
function MyManager:getItemsForFarm(farmId)
    local farm = g_farmManager:getFarmById(farmId)
    return farm and farm.myItems or {}
end

--[[
    Cleanup on map unload
]]
function MyManager:delete()
    if self.isServer then
        g_messageCenter:unsubscribe(MessageType.HOUR_CHANGED, self)
    end
end
```

---

## Initialization in main.lua

```lua
-- In your main mod file

local MyMod = {}
MyMod.modDirectory = g_currentModDirectory

function MyMod:loadMap(filename)
    -- Create manager singleton
    g_myManager = MyManager.new()
end

function MyMod:loadMapFinished()
    -- Initialize manager after map is loaded
    if g_myManager then
        g_myManager:loadMapFinished()
    end
end

function MyMod:deleteMap()
    -- Cleanup
    if g_myManager then
        g_myManager:delete()
        g_myManager = nil
    end
end

-- Register callbacks
addModEventListener(MyMod)
```

---

## Farm Data Extension

Managers typically store data per-farm. Extend the Farm class:

```lua
-- In FarmExtension.lua or main.lua

local originalFarmNew = Farm.new
Farm.new = function(isServer, isClient, customMt)
    local farm = originalFarmNew(isServer, isClient, customMt)

    -- Add custom data arrays
    farm.myItems = {}
    farm.financeDeals = {}
    farm.vehicleSaleListings = {}

    return farm
end
```

---

## Save/Load Integration

> ✅ **VALIDATED** - All 3 core managers implement full save/load
> - Example: `FS25_UsedPlus/src/managers/FinanceManager.lua:739-829` (saveToXMLFile)
> - Example: `FS25_UsedPlus/src/managers/FinanceManager.lua:835-888` (loadFromXMLFile)
> - Note: UsedPlus uses `XMLFile.loadIfExists()` (not documented here but works)

### Saving Data
```lua
function MyManager:saveToXMLFile(xmlFile, key)
    -- Save for each farm
    for farmId, farm in pairs(g_farmManager:getFarms()) do
        if farm.myItems and #farm.myItems > 0 then
            local farmKey = string.format("%s.farm(%d)", key, farmId)
            xmlFile:setInt(farmKey .. "#farmId", farmId)

            for i, item in ipairs(farm.myItems) do
                local itemKey = string.format("%s.item(%d)", farmKey, i - 1)
                item:saveToXMLFile(xmlFile, itemKey)
            end
        end
    end
end
```

### Loading Data
```lua
function MyManager:loadFromXMLFile(xmlFile, key)
    local farmIndex = 0

    while true do
        local farmKey = string.format("%s.farm(%d)", key, farmIndex)

        if not xmlFile:hasProperty(farmKey) then
            break
        end

        local farmId = xmlFile:getInt(farmKey .. "#farmId")
        local farm = g_farmManager:getFarmById(farmId)

        if farm then
            farm.myItems = {}
            local itemIndex = 0

            while true do
                local itemKey = string.format("%s.item(%d)", farmKey, itemIndex)

                if not xmlFile:hasProperty(itemKey) then
                    break
                end

                local item = MyItem.new()
                if item:loadFromXMLFile(xmlFile, itemKey) then
                    table.insert(farm.myItems, item)
                end

                itemIndex = itemIndex + 1
            end
        end

        farmIndex = farmIndex + 1
    end
end
```

### Hook Save/Load in main.lua
```lua
function MyMod:loadMap(filename)
    g_myManager = MyManager.new()

    -- Hook save
    FSBaseMission.saveSavegame = Utils.appendedFunction(
        FSBaseMission.saveSavegame,
        function(mission)
            MyMod:saveToSavegame()
        end
    )
end

function MyMod:loadMapFinished()
    g_myManager:loadMapFinished()
    self:loadFromSavegame()
end

function MyMod:saveToSavegame()
    if g_myManager == nil then return end

    local xmlPath = g_currentMission.missionInfo.savegameDirectory .. "/myMod.xml"
    local xmlFile = XMLFile.create("myModXML", xmlPath, "myMod")

    if xmlFile then
        g_myManager:saveToXMLFile(xmlFile, "myMod")
        xmlFile:save()
        xmlFile:delete()
    end
end

function MyMod:loadFromSavegame()
    if g_myManager == nil then return end

    local xmlPath = g_currentMission.missionInfo.savegameDirectory .. "/myMod.xml"

    if fileExists(xmlPath) then
        local xmlFile = XMLFile.load("myModXML", xmlPath)

        if xmlFile then
            g_myManager:loadFromXMLFile(xmlFile, "myMod")
            xmlFile:delete()
        end
    end
end
```

---

## Message Center Events

> ⚠️ **PARTIAL** - UsedPlus uses a subset of documented events
> - ✅ HOUR_CHANGED: `UsedVehicleManager.lua:64`, `VehicleSaleManager.lua:75`
> - ✅ PERIOD_CHANGED: `FinanceManager.lua:151` (for monthly payments)
> - 📚 DAY_CHANGED, MONTH_CHANGED, VEHICLE_SOLD, MONEY_CHANGED: Not used in UsedPlus

### Common Events to Subscribe To
```lua
-- Hourly updates (most common)
g_messageCenter:subscribe(MessageType.HOUR_CHANGED, self.onHourChanged, self)

-- Daily updates
g_messageCenter:subscribe(MessageType.DAY_CHANGED, self.onDayChanged, self)

-- Monthly updates
g_messageCenter:subscribe(MessageType.MONTH_CHANGED, self.onMonthChanged, self)

-- Vehicle sold
g_messageCenter:subscribe(MessageType.VEHICLE_SOLD, self.onVehicleSold, self)

-- Money changed
g_messageCenter:subscribe(MessageType.MONEY_CHANGED, self.onMoneyChanged, self)
```

### Unsubscribe on Cleanup
```lua
function MyManager:delete()
    g_messageCenter:unsubscribe(MessageType.HOUR_CHANGED, self)
    g_messageCenter:unsubscribe(MessageType.DAY_CHANGED, self)
end
```

---

## Common Pitfalls

> ✅ **VALIDATED** - All 4 pitfalls properly avoided in UsedPlus
> - Server checks: `FinanceManager.lua:163`, `UsedVehicleManager.lua:79`, `VehicleSaleManager.lua:96`
> - Unsubscribe in delete(): All managers properly cleanup
> - Memory leak fix: `FarmExtension.lua:627-645` added during this audit

### 1. Processing on Client
- Always check `self.isServer` before processing
- Hourly updates should only run on server
- Clients receive state via sync events

### 2. Missing Farm Data
- Always nil-check farm before accessing custom arrays
- Initialize arrays in Farm.new extension
- Handle missing farms gracefully

### 3. Save/Load Order
- Manager must exist before loadFromSavegame
- Subscribe to events AFTER loading saved state
- Save BEFORE map cleanup

### 4. Memory Leaks
- Unsubscribe from all events in delete()
- Clear references to deleted vehicles
- Remove completed items from arrays
