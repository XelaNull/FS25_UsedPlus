# Trigger-Based Automation

**Detect objects and execute automated operations**

Based on patterns from: AutomaticCarWash, AutomaticWater

---

> ✅ **VALIDATED IN FS25_UsedPlus**
>
> Trigger patterns are fully validated in the UsedPlus codebase.
>
> **UsedPlus Implementation:**
> - `FS25_UsedPlus/placeables/FieldServiceKit.lua:206-213` - `addTrigger()` registration
> - `FS25_UsedPlus/placeables/FieldServiceKit.lua:736-759` - Trigger callbacks
> - Full trigger lifecycle (register, callback, cleanup) validated
>
> **Source Mods for Reference:**
> - `FS25_Mods_Extracted/AutomaticCarWash/` - Original pattern source
> - `FS25_Mods_Extracted/AutomaticWater/` - Timer-based triggers

---

## Overview

Triggers detect when objects (vehicles, players) enter/leave zones and execute callbacks. Common uses:
- Automatic washing/repair stations
- Loading/unloading zones
- Player interaction areas
- Automation systems

---

## Basic Trigger Pattern

### XML Configuration
```xml
<placeable type="myAutomation">
    <!-- Trigger configuration -->
    <myAutomation triggerNode="vehicleTrigger"
                  processingRate="-0.05"
                  timerInterval="3000"/>
</placeable>
```

### Specialization Setup
```lua
MyAutomation = {}

function MyAutomation.prerequisitesPresent(specializations)
    return true
end

function MyAutomation.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", MyAutomation)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", MyAutomation)
    SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", MyAutomation)
end

-- Register XML schema
function MyAutomation.initSpecialization()
    local schema = Placeable.xmlSchema
    schema:setXMLSpecializationType("MyAutomation")

    schema:register(XMLValueType.NODE_INDEX,
        "placeable.myAutomation#triggerNode", "Trigger node")
    schema:register(XMLValueType.FLOAT,
        "placeable.myAutomation#processingRate", "Processing rate", -0.1)
    schema:register(XMLValueType.INT,
        "placeable.myAutomation#timerInterval", "Timer interval (ms)", 3000)

    schema:setXMLSpecializationType()
end
```

### Load and Initialize
```lua
function MyAutomation:onLoad(savegame)
    local spec = self.spec_myAutomation

    -- Load from XML
    spec.triggerNode = self.xmlFile:getValue(
        "placeable.myAutomation#triggerNode", nil,
        self.components, self.i3dMappings
    )
    spec.processingRate = self.xmlFile:getValue(
        "placeable.myAutomation#processingRate", -0.1
    )
    spec.timerInterval = self.xmlFile:getValue(
        "placeable.myAutomation#timerInterval", 3000
    )

    -- Initialize state
    spec.vehiclesInTrigger = {}
    spec.timerId = nil
end

function MyAutomation:onFinalizePlacement()
    local spec = self.spec_myAutomation

    -- Register trigger callback (server only)
    if self.isServer and spec.triggerNode ~= nil then
        addTrigger(spec.triggerNode, "onTriggerCallback", self)
    end
end
```

---

## Trigger Callback Pattern

```lua
function MyAutomation:onTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
    local spec = self.spec_myAutomation

    -- Get the object that triggered
    local vehicle = g_currentMission:getNodeObject(otherId)

    if vehicle == nil or vehicle.rootNode == nil then
        return
    end

    if onEnter then
        -- Object entered trigger zone
        if not self:isInTable(vehicle.rootNode, spec.vehiclesInTrigger) then
            table.insert(spec.vehiclesInTrigger, vehicle.rootNode)

            -- Start processing timer
            self:startProcessing()
        end
    end

    if onLeave then
        -- Object left trigger zone
        self:removeFromTable(vehicle.rootNode, spec.vehiclesInTrigger)
    end
end

-- Helper: Check if in table
function MyAutomation:isInTable(node, tbl)
    for _, v in ipairs(tbl) do
        if v == node then
            return true
        end
    end
    return false
end

-- Helper: Remove from table
function MyAutomation:removeFromTable(node, tbl)
    for i, v in ipairs(tbl) do
        if v == node then
            table.remove(tbl, i)
            return
        end
    end
end
```

---

## Self-Managing Timer Pattern

Timers that create and remove themselves automatically:

```lua
function MyAutomation:startProcessing()
    local spec = self.spec_myAutomation

    -- Only create timer if not already running
    if spec.timerId == nil and #spec.vehiclesInTrigger > 0 then
        spec.timerId = addTimer(spec.timerInterval, "processVehicles", self)
    end
end

function MyAutomation:processVehicles()
    local spec = self.spec_myAutomation

    if #spec.vehiclesInTrigger == 0 then
        -- No vehicles, stop timer
        spec.timerId = nil
        return  -- Don't reschedule
    end

    local workDone = false

    -- Process all vehicles in trigger
    for _, vehicleNode in ipairs(spec.vehiclesInTrigger) do
        local vehicle = g_currentMission.nodeToObject[vehicleNode]

        if vehicle ~= nil then
            -- Check if vehicle is stationary
            local speed = 0
            if vehicle.getLastSpeed then
                speed = vehicle:getLastSpeed(true)
            end

            if speed < 0.1 then
                -- Process this vehicle
                workDone = self:processOneVehicle(vehicle) or workDone
            end
        end
    end

    if workDone then
        -- More work to do, keep timer running
        return true  -- Reschedule timer
    else
        -- All done, stop timer
        spec.timerId = nil
        return  -- Don't reschedule
    end
end

function MyAutomation:processOneVehicle(vehicle)
    local spec = self.spec_myAutomation
    local actionDone = false

    -- Example: Clean vehicle
    if vehicle.getDirtAmount and vehicle:getDirtAmount() > 0.001 then
        vehicle:cleanVehicle(spec.processingRate)
        actionDone = true
    end

    return actionDone
end
```

---

## Cleanup on Delete

Always remove triggers and timers:

```lua
function MyAutomation:onDelete()
    local spec = self.spec_myAutomation

    -- Remove timer
    if spec.timerId ~= nil then
        removeTimer(spec.timerId)
        spec.timerId = nil
    end

    -- Remove trigger
    if spec.triggerNode ~= nil then
        removeTrigger(spec.triggerNode)
    end

    -- Clear references
    spec.vehiclesInTrigger = {}
end
```

---

## Vehicle Modification Methods

Common methods for modifying vehicles in triggers:

```lua
-- Cleaning (reduce dirt)
if vehicle.getDirtAmount and vehicle:getDirtAmount() > 0.001 then
    vehicle:cleanVehicle(-0.05)  -- Negative = clean
end

-- Drying (reduce wetness)
if vehicle.getIsWet and vehicle:getIsWet() then
    vehicle:addWetnessAmount(-0.1)
end

-- Repair (reduce damage)
if vehicle.getDamageAmount and vehicle:getDamageAmount() > 0.001 then
    vehicle:addDamageAmount(-0.02, true)  -- Negative = repair
end

-- Repaint (reduce wear)
if vehicle.getWearTotalAmount and vehicle:getWearTotalAmount() > 0.001 then
    vehicle:addWearAmount(-0.02, true)  -- Negative = repaint
end

-- Check speed
if vehicle.getLastSpeed then
    local speed = vehicle:getLastSpeed(true)  -- true = km/h
    if speed < 0.1 then
        -- Vehicle is stationary
    end
end
```

---

## Complete Example: Auto Wash Station

```lua
AutoWashStation = {}

function AutoWashStation.prerequisitesPresent(specializations)
    return true
end

function AutoWashStation.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", AutoWashStation)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", AutoWashStation)
    SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", AutoWashStation)
end

function AutoWashStation:onLoad(savegame)
    local spec = self.spec_autoWashStation
    spec.triggerNode = self.xmlFile:getValue(
        "placeable.autoWash#triggerNode", nil,
        self.components, self.i3dMappings
    )
    spec.cleanRate = self.xmlFile:getValue("placeable.autoWash#cleanRate", -0.05)
    spec.vehiclesInTrigger = {}
    spec.timerId = nil
end

function AutoWashStation:onFinalizePlacement()
    local spec = self.spec_autoWashStation
    if self.isServer and spec.triggerNode then
        addTrigger(spec.triggerNode, "onTriggerCallback", self)
    end
end

function AutoWashStation:onTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
    local spec = self.spec_autoWashStation
    local vehicle = g_currentMission:getNodeObject(otherId)

    if vehicle and vehicle.rootNode then
        if onEnter then
            table.insert(spec.vehiclesInTrigger, vehicle.rootNode)
            if spec.timerId == nil then
                spec.timerId = addTimer(2000, "washVehicles", self)
            end
        elseif onLeave then
            for i, node in ipairs(spec.vehiclesInTrigger) do
                if node == vehicle.rootNode then
                    table.remove(spec.vehiclesInTrigger, i)
                    break
                end
            end
        end
    end
end

function AutoWashStation:washVehicles()
    local spec = self.spec_autoWashStation

    if #spec.vehiclesInTrigger == 0 then
        spec.timerId = nil
        return
    end

    local needMoreWork = false

    for _, node in ipairs(spec.vehiclesInTrigger) do
        local vehicle = g_currentMission.nodeToObject[node]
        if vehicle and vehicle.getDirtAmount then
            if vehicle:getDirtAmount() > 0.001 then
                vehicle:cleanVehicle(spec.cleanRate)
                needMoreWork = true
            end
        end
    end

    if needMoreWork then
        return true  -- Keep timer running
    else
        spec.timerId = nil
    end
end

function AutoWashStation:onDelete()
    local spec = self.spec_autoWashStation
    if spec.timerId then
        removeTimer(spec.timerId)
    end
    if spec.triggerNode then
        removeTrigger(spec.triggerNode)
    end
end
```

---

## Common Pitfalls

### 1. Forgetting Server Check
Triggers should only be added on server:
```lua
if self.isServer and spec.triggerNode then
    addTrigger(spec.triggerNode, "onTriggerCallback", self)
end
```

### 2. Memory Leaks from Timers
Always remove timers in onDelete.

### 3. Processing Moving Vehicles
Check speed before processing to avoid issues.

### 4. Not Handling nil Vehicles
Always check if vehicle exists before processing.
