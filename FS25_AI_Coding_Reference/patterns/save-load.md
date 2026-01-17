# Save/Load Integration

**How to persist mod data to savegames**

Based on patterns from: BuyUsedEquipment, EnhancedLoanSystem, HirePurchasing

---

## Overview

FS25 mods can persist data by:
1. **Extending Farm save/load** - Store data per-farm
2. **Manager save/load hooks** - Store global mod data
3. **Separate XML files** - Custom save files in savegame directory

---

## Pattern 1: Extending Farm Save/Load

Store mod data per-farm by extending the Farm class.

### Setup Farm Extension
```lua
FarmExtension = {}

-- Extend Farm constructor to add custom data
function FarmExtension.new(isServer, superFunc, isClient, spectator, customMt, ...)
    local farm = superFunc(isServer, isClient, spectator, customMt, ...)

    -- Add mod-specific data arrays
    farm.myModItems = {}
    farm.myModSettings = {
        enabled = true,
        level = 1
    }

    return farm
end

-- Hook into Farm.new
Farm.new = Utils.overwrittenFunction(Farm.new, FarmExtension.new)
```

### Save Data
```lua
function FarmExtension:saveToXMLFile(xmlFile, key)
    -- Guard against nil
    if self.myModItems == nil then
        self.myModItems = {}
    end

    -- Save array of items
    xmlFile:setSortedTable(key .. ".myMod.items.item", self.myModItems,
        function(itemKey, item)
            xmlFile:setString(itemKey .. "#id", item.id)
            xmlFile:setInt(itemKey .. "#value", item.value)
            xmlFile:setInt(itemKey .. "#ttl", item.ttl)
            xmlFile:setBool(itemKey .. "#active", item.active)
        end
    )

    -- Save settings
    xmlFile:setBool(key .. ".myMod.settings#enabled", self.myModSettings.enabled)
    xmlFile:setInt(key .. ".myMod.settings#level", self.myModSettings.level)
end

-- Hook into Farm.saveToXMLFile
Farm.saveToXMLFile = Utils.appendedFunction(Farm.saveToXMLFile, FarmExtension.saveToXMLFile)
```

### Load Data
```lua
function FarmExtension:loadFromXMLFile(superFunc, xmlFile, key)
    -- Call original function first
    local returnValue = superFunc(self, xmlFile, key)

    -- Initialize arrays
    self.myModItems = {}

    -- Load items using iterate
    xmlFile:iterate(key .. ".myMod.items.item", function(_, itemKey)
        local item = {
            id = xmlFile:getString(itemKey .. "#id", ""),
            value = xmlFile:getInt(itemKey .. "#value", 0),
            ttl = xmlFile:getInt(itemKey .. "#ttl", 24),
            active = xmlFile:getBool(itemKey .. "#active", true)
        }

        if item.id ~= "" then
            table.insert(self.myModItems, item)
        end
    end)

    -- Load settings with defaults
    self.myModSettings = {
        enabled = xmlFile:getBool(key .. ".myMod.settings#enabled", true),
        level = xmlFile:getInt(key .. ".myMod.settings#level", 1)
    }

    return returnValue
end

-- Hook into Farm.loadFromXMLFile (use overwrittenFunction to get superFunc)
Farm.loadFromXMLFile = Utils.overwrittenFunction(Farm.loadFromXMLFile, FarmExtension.loadFromXMLFile)
```

---

## Pattern 2: Manager Save/Load Hooks

For global mod data not tied to specific farms.

### Hook FSBaseMission Save
```lua
-- In main.lua or manager file
function MyMod:loadMap(filename)
    -- Create manager
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
    -- Load after map is ready
    self:loadFromSavegame()
end

function MyMod:saveToSavegame()
    if g_myManager == nil then return end

    local savegameDir = g_currentMission.missionInfo.savegameDirectory
    if savegameDir == nil then return end

    local xmlPath = savegameDir .. "/myMod.xml"
    local xmlFile = XMLFile.create("myModXML", xmlPath, "myMod")

    if xmlFile then
        g_myManager:saveToXMLFile(xmlFile, "myMod")
        xmlFile:save()
        xmlFile:delete()
    end
end

function MyMod:loadFromSavegame()
    if g_myManager == nil then return end

    local savegameDir = g_currentMission.missionInfo.savegameDirectory
    if savegameDir == nil then return end

    local xmlPath = savegameDir .. "/myMod.xml"

    if fileExists(xmlPath) then
        local xmlFile = XMLFile.load("myModXML", xmlPath)

        if xmlFile then
            g_myManager:loadFromXMLFile(xmlFile, "myMod")
            xmlFile:delete()
        end
    end
end
```

### Manager Save/Load Methods
```lua
function MyManager:saveToXMLFile(xmlFile, key)
    local index = 0

    for farmId, items in pairs(self.itemsByFarm) do
        for _, item in ipairs(items) do
            local itemKey = string.format("%s.items.item(%d)", key, index)

            xmlFile:setInt(itemKey .. "#farmId", farmId)
            item:saveToXMLFile(xmlFile, itemKey)

            index = index + 1
        end
    end
end

function MyManager:loadFromXMLFile(xmlFile, key)
    self.itemsByFarm = {}

    xmlFile:iterate(key .. ".items.item", function(_, itemKey)
        local farmId = xmlFile:getInt(itemKey .. "#farmId", -1)

        if farmId >= 0 then
            local item = MyItem.new()
            if item:loadFromXMLFile(xmlFile, itemKey) then
                local farmItems = self.itemsByFarm[farmId] or {}
                table.insert(farmItems, item)
                self.itemsByFarm[farmId] = farmItems
            end
        end
    end)
end
```

---

## Pattern 3: Using Mission Load Callbacks

Hook into mission loading sequence.

```lua
-- Load when map data loads
Mission00.loadMapData = Utils.appendedFunction(Mission00.loadMapData,
    function(mission, xmlFile, missionInfo, baseDirectory)
        if g_myManager then
            g_myManager:loadMapData(xmlFile, missionInfo)
        end
    end
)

-- Load after map is finished loading
Mission00.loadMapFinished = Utils.appendedFunction(Mission00.loadMapFinished,
    function(mission, ...)
        if g_myManager then
            g_myManager:onMapLoaded()
        end
    end
)
```

---

## XML File API Reference

### New API (XMLFile object)

```lua
-- Create new file
local xmlFile = XMLFile.create("uniqueName", filePath, "rootElement")

-- Load existing file
local xmlFile = XMLFile.load("uniqueName", filePath)

-- Check if exists
if fileExists(filePath) then ... end

-- Read values
local str = xmlFile:getString(key .. "#attribute", "default")
local num = xmlFile:getInt(key .. "#attribute", 0)
local flt = xmlFile:getFloat(key .. "#attribute", 0.0)
local bool = xmlFile:getBool(key .. "#attribute", false)

-- Write values
xmlFile:setString(key .. "#attribute", value)
xmlFile:setInt(key .. "#attribute", value)
xmlFile:setFloat(key .. "#attribute", value)
xmlFile:setBool(key .. "#attribute", value)

-- Check if key exists
if xmlFile:hasProperty(key) then ... end

-- Iterate over children
xmlFile:iterate(key .. ".item", function(index, itemKey)
    local value = xmlFile:getString(itemKey .. "#name")
end)

-- Save sorted table (array)
xmlFile:setSortedTable(key .. ".items", myArray, function(itemKey, item)
    xmlFile:setString(itemKey .. "#name", item.name)
end)

-- Save and cleanup
xmlFile:save()
xmlFile:delete()
```

### Old API (still works)

```lua
-- Create/load
local xmlFile = createXMLFile("name", filePath, "root")
local xmlFile = loadXMLFile("name", filePath)

-- Read
local str = getXMLString(xmlFile, key .. "#attribute")
local num = getXMLInt(xmlFile, key .. "#attribute")
local flt = getXMLFloat(xmlFile, key .. "#attribute")
local bool = getXMLBool(xmlFile, key .. "#attribute")

-- Write
setXMLString(xmlFile, key .. "#attribute", value)
setXMLInt(xmlFile, key .. "#attribute", value)
setXMLFloat(xmlFile, key .. "#attribute", value)
setXMLBool(xmlFile, key .. "#attribute", value)

-- Check existence
if hasXMLProperty(xmlFile, key) then ... end

-- Save and cleanup
saveXMLFile(xmlFile)
delete(xmlFile)
```

---

## Example: Complete Save/Load Flow

### Data Class
```lua
MyItem = {}
local MyItem_mt = Class(MyItem)

function MyItem.new()
    local self = setmetatable({}, MyItem_mt)
    self.id = ""
    self.name = ""
    self.value = 0
    self.active = true
    return self
end

function MyItem:saveToXMLFile(xmlFile, key)
    xmlFile:setString(key .. "#id", self.id)
    xmlFile:setString(key .. "#name", self.name)
    xmlFile:setInt(key .. "#value", self.value)
    xmlFile:setBool(key .. "#active", self.active)
end

function MyItem:loadFromXMLFile(xmlFile, key)
    self.id = xmlFile:getString(key .. "#id", "")
    self.name = xmlFile:getString(key .. "#name", "")
    self.value = xmlFile:getInt(key .. "#value", 0)
    self.active = xmlFile:getBool(key .. "#active", true)
    return self.id ~= ""
end
```

### Manager
```lua
MyManager = {}

function MyManager.new()
    local self = {}
    self.items = {}
    return setmetatable(self, {__index = MyManager})
end

function MyManager:addItem(item)
    table.insert(self.items, item)
end

function MyManager:saveToXMLFile(xmlFile, key)
    for i, item in ipairs(self.items) do
        local itemKey = string.format("%s.items.item(%d)", key, i - 1)
        item:saveToXMLFile(xmlFile, itemKey)
    end
end

function MyManager:loadFromXMLFile(xmlFile, key)
    self.items = {}

    local index = 0
    while true do
        local itemKey = string.format("%s.items.item(%d)", key, index)
        if not xmlFile:hasProperty(itemKey) then
            break
        end

        local item = MyItem.new()
        if item:loadFromXMLFile(xmlFile, itemKey) then
            table.insert(self.items, item)
        end

        index = index + 1
    end
end
```

### Main Integration
```lua
local MyMod = {}

function MyMod:loadMap(filename)
    g_myManager = MyManager.new()

    FSBaseMission.saveSavegame = Utils.appendedFunction(
        FSBaseMission.saveSavegame,
        function() self:save() end
    )
end

function MyMod:loadMapFinished()
    self:load()
end

function MyMod:save()
    local dir = g_currentMission.missionInfo.savegameDirectory
    if not dir then return end

    local xmlFile = XMLFile.create("myMod", dir .. "/myMod.xml", "myMod")
    if xmlFile then
        g_myManager:saveToXMLFile(xmlFile, "myMod")
        xmlFile:save()
        xmlFile:delete()
        print("[MyMod] Saved successfully")
    end
end

function MyMod:load()
    local dir = g_currentMission.missionInfo.savegameDirectory
    if not dir then return end

    local path = dir .. "/myMod.xml"
    if fileExists(path) then
        local xmlFile = XMLFile.load("myMod", path)
        if xmlFile then
            g_myManager:loadFromXMLFile(xmlFile, "myMod")
            xmlFile:delete()
            print("[MyMod] Loaded " .. #g_myManager.items .. " items")
        end
    end
end

addModEventListener(MyMod)
```

---

## Common Pitfalls

### 1. Loading Before Manager Exists
```lua
-- WRONG: Manager may be nil
function MyMod:loadMapFinished()
    g_myManager:load()  -- Crashes if nil
end

-- CORRECT: Check first
function MyMod:loadMapFinished()
    if g_myManager then
        g_myManager:load()
    end
end
```

### 2. Forgetting to Delete XMLFile
```lua
-- WRONG: Memory leak
local xmlFile = XMLFile.load("name", path)
-- ... use file but never delete

-- CORRECT: Always delete
local xmlFile = XMLFile.load("name", path)
if xmlFile then
    -- ... use file
    xmlFile:delete()
end
```

### 3. Wrong Key Format
```lua
-- WRONG: Missing # for attributes
xmlFile:setString("myMod.item.name", value)

-- CORRECT: Use # for attributes
xmlFile:setString("myMod.item#name", value)

-- CORRECT: No # for nested elements
xmlFile:setString("myMod.item.subElement#attribute", value)
```

### 4. Not Handling Missing Savegame Directory
```lua
-- WRONG: Crashes on new game
local path = g_currentMission.missionInfo.savegameDirectory .. "/file.xml"

-- CORRECT: Check first
local dir = g_currentMission.missionInfo.savegameDirectory
if dir == nil then
    return  -- New game, no savegame yet
end
local path = dir .. "/file.xml"
```

### 5. Index Starting at Wrong Number
```lua
-- For iterate callback, index starts at 1 (Lua style)
xmlFile:iterate(key, function(index, itemKey)
    print(index)  -- 1, 2, 3, ...
end)

-- For manual indexing in keys, use 0 (XML style)
local itemKey = string.format("%s.item(%d)", key, 0)  -- First item
local itemKey = string.format("%s.item(%d)", key, 1)  -- Second item
```
