# Lua Patterns & Best Practices

**Core Lua patterns for FS25 mod development**

Based on patterns from: 164+ working community mods

---

> ⚠️ **PARTIALLY VALIDATED IN FS25_UsedPlus**
>
> Most patterns validated, some are reference-only from other mods.
>
> **Validation Details:**
> | Pattern | Status | UsedPlus Reference |
> |---------|--------|--------------------|
> | Utils.overwrittenFunction | ✅ | All extension files |
> | Utils.appendedFunction | ✅ | FarmExtension.lua, VehicleExtension.lua |
> | Utils.prependedFunction | ✅ | ShopConfigScreenExtension.lua |
> | Class() metatable pattern | ✅ | All data classes, GUI classes |
> | Debug logging pattern | ✅ | UsedPlusCore.lua:logDebug/logInfo |
> | Safe table operations | ✅ | Throughout codebase |
> | Mod:init() pattern | 📚 | Not used - UsedPlus uses direct global |
> | Specialization registration | ✅ | UsedPlusMaintenance.lua |
>
> **Source References for Unvalidated:**
> - `Mod:init()` pattern: See `FS25_Mods_Extracted/PlayerTriggers/` for example

---

## Mod Initialization Pattern

### Using Mod:init()

```lua
--[[
    Mod Name
    Author: YourName
    Version: 1.0.0
]]

ModName = Mod:init()

-- Source additional files
ModName:source("OtherScript.lua")
ModName:source("EventClass.lua")

-- Constants
ModName.MOD_NAME = "FS25_ModName"
ModName.DEBUG = false

-- Initialize function
function ModName:initialize()
    print("[ModName] Initializing...")

    -- Setup code here

    print("[ModName] Initialized successfully")
end

-- Load function (called when game loads)
function ModName:load()
    self:initialize()
end

-- Register the load function
Mission00.load = Utils.overwrittenFunction(Mission00.load, function(base, ...)
    base(...)
    ModName:load()
end)
```

---

## Object-Oriented Class Pattern

```lua
MyClass = {}
local MyClass_mt = Class(MyClass)

function MyClass.new(param1, param2)
    local self = setmetatable({}, MyClass_mt)

    self.param1 = param1
    self.param2 = param2
    self.data = {}

    return self
end

function MyClass:update(dt)
    -- Update logic
end

function MyClass:delete()
    -- Cleanup
    self.data = nil
end

-- Usage
local instance = MyClass.new("value1", "value2")
instance:update(16.67)
instance:delete()
```

---

## Overriding Game Functions

### Utils.overwrittenFunction (Most Common)

```lua
-- Replace function, call original first
ShopConfigScreen.onOpen = Utils.overwrittenFunction(
    ShopConfigScreen.onOpen,
    function(base, self, ...)
        base(self, ...)  -- Call original function

        -- Your custom code here
        print("Shop screen opened, adding custom button")
    end
)
```

### Utils.appendedFunction (Add After)

```lua
-- Run additional code after original
Farm.deleteVehicle = Utils.appendedFunction(
    Farm.deleteVehicle,
    function(self, vehicle)
        -- Your cleanup code
        print("Vehicle deleted: " .. vehicle.configFileName)
    end
)
```

### Utils.prependedFunction (Add Before)

```lua
-- Run code before original
StoreManager.loadItem = Utils.prependedFunction(
    StoreManager.loadItem,
    function(self, xmlFile, key, baseDir)
        print("About to load item from: " .. key)
    end
)
```

---

## Debug Logging Pattern

```lua
local MOD_NAME = "MyMod"
local DEBUG_MODE = false

local function log(message, level)
    level = level or "INFO"
    print(string.format("[%s][%s] %s", MOD_NAME, level, tostring(message)))
end

local function debugLog(message)
    if DEBUG_MODE then
        log(message, "DEBUG")
    end
end

-- Usage
log("Mod initialized")
debugLog("Debug info: " .. tostring(someVariable))
```

---

## Throttled Update Loops

Reduce performance overhead by processing updates only when needed:

### Frame-Based Throttling

```lua
MySystem = {}

function MySystem.new()
    local self = {}
    self.updateCounter = 0
    self.updateInterval = 10  -- Update every 10 frames
    return self
end

function MySystem:update(dt)
    self.updateCounter = self.updateCounter + 1

    -- Only process every N frames
    if self.updateCounter >= self.updateInterval then
        self.updateCounter = 0
        self:processUpdate()
    end
end

function MySystem:processUpdate()
    -- Expensive operation here
    print("Processing expensive update")
end
```

### Time-Based Throttling

```lua
function MySystem:updateWithTime(dt)
    if self.lastUpdate == nil then
        self.lastUpdate = 0
    end

    self.lastUpdate = self.lastUpdate + dt

    if self.lastUpdate >= 1000 then  -- Update every 1 second (1000ms)
        self.lastUpdate = 0
        self:processUpdate()
    end
end
```

---

## Multi-Fallback Mod Registration

Handle missing or optional dependencies gracefully:

```lua
function registerWithFallback()
    local modName = g_currentModName
    local registered = false

    -- Try primary registration
    if g_modManager:isModLoaded("PrimaryModName") then
        registerWithPrimaryMod()
        registered = true
    end

    -- Fallback to secondary mod
    if not registered and g_modManager:isModLoaded("SecondaryModName") then
        registerWithSecondaryMod()
        registered = true
    end

    -- Fallback to vanilla behavior
    if not registered then
        registerStandalone()
    end

    print(string.format("[%s] Initialized (fallback chain: %s)",
        modName, registered and "primary" or "vanilla"))
end
```

---

## Specialization Registration with Filtering

```lua
function registerSpecialization()
    local modName = g_currentModName

    -- Define specialization
    local MySpecialization = {}

    function MySpecialization.prerequisitesPresent(specializations)
        return true
    end

    function MySpecialization.registerEventListeners(vehicleType)
        SpecializationUtil.registerEventListener(vehicleType, "onLoad", MySpecialization)
    end

    -- Register with filtering
    g_specializationManager:addSpecialization(modName .. ".mySpecialization", MySpecialization)

    -- Apply to specific vehicle types
    for _, vehicleType in ipairs(g_vehicleTypeManager:getVehicleTypes()) do
        -- Filter: only apply to motorized vehicles
        if vehicleType:hasSpecialization("motorized") then
            vehicleType:addSpecialization(modName .. ".mySpecialization")
        end
    end
end
```

---

## Safe Table Operations

### Nil-Safe Table Access

```lua
-- WRONG: Can crash on nil
local value = myTable.nested.value

-- CORRECT: Safe navigation
local value = myTable and myTable.nested and myTable.nested.value
```

### Safe Iteration

```lua
-- WRONG: pairs on nil crashes
for k, v in pairs(maybeNilTable) do end

-- CORRECT: Check first
if maybeNilTable then
    for k, v in pairs(maybeNilTable) do end
end
```

---

## String Formatting

```lua
-- Format numbers
local formatted = string.format("%.2f", 123.456)  -- "123.46"

-- Format with placeholders
local message = string.format("Player %s has %d vehicles", name, count)

-- Money formatting (use game function)
local money = g_i18n:formatMoney(50000)  -- "$50,000"
```

---

## Common Pitfalls

### 1. Using os.time()
```lua
-- WRONG: os.time() is forbidden
local time = os.time()

-- CORRECT: Use game time
local time = g_currentMission.time
```

### 2. Missing Self in Callbacks
```lua
-- WRONG: self is nil in callback
button.onClickCallback = self.onClick

-- CORRECT: Closure captures self
button.onClickCallback = function()
    self:onClick()
end
```

### 3. Modifying Tables During Iteration
```lua
-- WRONG: Undefined behavior
for i, v in ipairs(items) do
    if shouldRemove(v) then
        table.remove(items, i)
    end
end

-- CORRECT: Iterate backwards
for i = #items, 1, -1 do
    if shouldRemove(items[i]) then
        table.remove(items, i)
    end
end
```

### 4. Global Variable Pollution
```lua
-- WRONG: Creates global
myVar = "value"

-- CORRECT: Use local
local myVar = "value"
```
