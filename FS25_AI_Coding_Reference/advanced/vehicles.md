# Vehicle Patterns

**Specializations, state modification, and vehicle systems**

Based on patterns from: 164+ working community mods

---

## Related API Documentation

> 📖 For complete vehicle APIs, see the [FS25 Community LUADOC](https://github.com/umbraprior/FS25-Community-LUADOC)

| Class | API Reference | Description |
|-------|---------------|-------------|
| Vehicle | [Vehicles/](https://github.com/umbraprior/FS25-Community-LUADOC/tree/main/docs/script/Vehicles) | Base vehicle class |
| VehicleMotor | [VehicleMotor.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/Vehicles/VehicleMotor.md) | Engine/motor system |
| Specializations | [Specializations/](https://github.com/umbraprior/FS25-Community-LUADOC/tree/main/docs/script/Specializations) | 150+ specialization classes |
| Attachable | [Attachable.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/Specializations/Attachable.md) | Implement attachment |
| Drivable | [Drivable.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/Specializations/Drivable.md) | Player-controllable |
| Fillable | [Fillable.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/Specializations/Fillable.md) | Fill volumes |

**Also see:** [Raw dataS source](https://github.com/Dukefarming/FS25-lua-scripting) for Vehicle.lua (192KB), VehicleMotor.lua (108KB)

---

> ⚠️ **REFERENCE ONLY - NOT VALIDATED IN FS25_UsedPlus**
>
> These patterns were extracted from community mods during our 150+ mod analysis
> but are **NOT used in the UsedPlus codebase**. UsedPlus focuses on finance/marketplace
> features and does not create custom vehicle specializations.
>
> **Source Mods for Reference:**
> - `FS25_Mods_Extracted/` - Various vehicle mods
> - Vehicle specialization patterns from Giants SDK documentation
>
> **Use with caution** - patterns have not been battle-tested in our production code.
> Consider reviewing the original source mods for working implementations.

---

## Overview

Vehicle modifications in FS25:
- **Specializations** - Add features to vehicle types
- **State Modifications** - Change vehicle properties
- **Implement Processing** - Handle attached equipment
- **AI Integration** - Work with AI drivers

---

## Vehicle Specialization Pattern

### Basic Specialization Structure
```lua
MyVehicleSpec = {}

-- Check if prerequisites are met
function MyVehicleSpec.prerequisitesPresent(specializations)
    return true
end

-- Register custom functions
function MyVehicleSpec.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "myCustomFunction",
        MyVehicleSpec.myCustomFunction)
    SpecializationUtil.registerFunction(vehicleType, "getMyValue",
        MyVehicleSpec.getMyValue)
end

-- Register event listeners
function MyVehicleSpec.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", MyVehicleSpec)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", MyVehicleSpec)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", MyVehicleSpec)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", MyVehicleSpec)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", MyVehicleSpec)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", MyVehicleSpec)
end

-- Called when vehicle loads
function MyVehicleSpec:onLoad(savegame)
    local spec = self.spec_myVehicleSpec

    -- Initialize spec data
    spec.myValue = 0
    spec.isActive = false
end

-- Called after vehicle fully loads
function MyVehicleSpec:onPostLoad(savegame)
    local spec = self.spec_myVehicleSpec

    -- Load saved data
    if savegame ~= nil then
        local key = savegame.key .. ".myVehicleSpec"
        spec.myValue = savegame.xmlFile:getInt(key .. "#myValue", 0)
    end
end

-- Called every frame
function MyVehicleSpec:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_myVehicleSpec

    if not spec.isActive then
        return
    end

    -- Update logic
    spec.myValue = spec.myValue + dt
end

-- Cleanup
function MyVehicleSpec:onDelete()
    local spec = self.spec_myVehicleSpec
    -- Cleanup resources
end

-- Network sync (write)
function MyVehicleSpec:onWriteStream(streamId, connection)
    local spec = self.spec_myVehicleSpec
    streamWriteInt32(streamId, spec.myValue)
    streamWriteBool(streamId, spec.isActive)
end

-- Network sync (read)
function MyVehicleSpec:onReadStream(streamId, connection)
    local spec = self.spec_myVehicleSpec
    spec.myValue = streamReadInt32(streamId)
    spec.isActive = streamReadBool(streamId)
end

-- Custom function
function MyVehicleSpec:myCustomFunction()
    local spec = self.spec_myVehicleSpec
    spec.isActive = not spec.isActive
end

-- Getter
function MyVehicleSpec:getMyValue()
    local spec = self.spec_myVehicleSpec
    return spec.myValue
end
```

---

## Registering Specializations

### In modDesc.xml
```xml
<modDesc descVersion="104">
    <!-- Define specialization -->
    <specializations>
        <specialization name="myVehicleSpec"
                       className="MyVehicleSpec"
                       filename="scripts/MyVehicleSpec.lua" />
    </specializations>

    <!-- Add to vehicle types -->
    <vehicleTypes>
        <type name="myModifiedTractor" parent="baseTractor">
            <specialization name="myVehicleSpec" />
        </type>
    </vehicleTypes>
</modDesc>
```

### Dynamic Registration (All Vehicles)
```lua
function registerSpecialization()
    local modName = g_currentModName

    -- Register specialization class
    g_specializationManager:addSpecialization(
        modName .. ".myVehicleSpec",
        MyVehicleSpec
    )

    -- Add to all vehicle types
    for _, vehicleType in pairs(g_vehicleTypeManager:getVehicleTypes()) do
        if vehicleType ~= nil then
            vehicleType:addSpecialization(modName .. ".myVehicleSpec")
        end
    end
end
```

### Filtered Registration
```lua
function registerSpecialization()
    local modName = g_currentModName

    g_specializationManager:addSpecialization(
        modName .. ".myVehicleSpec",
        MyVehicleSpec
    )

    for _, vehicleType in pairs(g_vehicleTypeManager:getVehicleTypes()) do
        -- Only add to motorized vehicles (tractors, trucks, etc.)
        if vehicleType:hasSpecialization("motorized") then
            vehicleType:addSpecialization(modName .. ".myVehicleSpec")
        end
    end
end

-- Alternative: Only harvesters
for _, vehicleType in pairs(g_vehicleTypeManager:getVehicleTypes()) do
    if vehicleType:hasSpecialization("combine") then
        vehicleType:addSpecialization(modName .. ".myVehicleSpec")
    end
end

-- Alternative: Only implements with fillUnit
for _, vehicleType in pairs(g_vehicleTypeManager:getVehicleTypes()) do
    if vehicleType:hasSpecialization("fillUnit") then
        vehicleType:addSpecialization(modName .. ".myVehicleSpec")
    end
end
```

---

## Available Event Listeners

```lua
-- Lifecycle
"onPreLoad"           -- Before vehicle loads
"onLoad"              -- Vehicle loads
"onPostLoad"          -- After vehicle loads
"onLoadFinished"      -- Loading complete
"onDelete"            -- Vehicle deleted

-- Update loop
"onUpdate"            -- Every frame
"onUpdateTick"        -- Fixed timestep update
"onPostUpdate"        -- After all updates

-- Network
"onReadStream"        -- Receive network data
"onWriteStream"       -- Send network data
"onReadUpdateStream"  -- Receive update sync
"onWriteUpdateStream" -- Send update sync

-- Vehicle state
"onEnterVehicle"      -- Player enters
"onLeaveVehicle"      -- Player leaves
"onRegisterActionEvents" -- Register input actions

-- Attachment
"onPreAttach"         -- Before attaching implement
"onPostAttach"        -- After attaching implement
"onPreDetach"         -- Before detaching
"onPostDetach"        -- After detaching

-- AI
"onAIStart"           -- AI starts driving
"onAIEnd"             -- AI stops driving

-- Fill
"onFillUnitFillLevelChanged" -- Fill level changes
```

---

## Vehicle State Access

### Common Vehicle Properties
```lua
-- Basic info
local name = vehicle:getName()
local brand = vehicle:getBrand()
local price = vehicle:getPrice()
local configFileName = vehicle.configFileName

-- Owner
local farmId = vehicle:getOwnerFarmId()
local farm = vehicle:getOwnerFarm()

-- State
local isActive = vehicle:getIsActive()
local isSelected = vehicle:getIsSelected()
local isControlled = vehicle:getIsControlled()
local isAIActive = vehicle:getIsAIActive()

-- Position
local x, y, z = getWorldTranslation(vehicle.rootNode)
local rx, ry, rz = getWorldRotation(vehicle.rootNode)
```

### Damage and Wear
```lua
-- Get damage (0-1)
if vehicle.getDamageAmount then
    local damage = vehicle:getDamageAmount()
end

-- Get wear (0-1)
if vehicle.getWearTotalAmount then
    local wear = vehicle:getWearTotalAmount()
end

-- Operating time (hours)
if vehicle.operatingTime then
    local hours = vehicle.operatingTime / (1000 * 60 * 60)
end

-- Set damage
if vehicle.setDamageAmount then
    vehicle:setDamageAmount(0.5)  -- 50% damage
end
```

### Fill Units
```lua
-- Get fill level
if vehicle.getFillUnitFillLevel then
    local fillLevel = vehicle:getFillUnitFillLevel(1)  -- Unit index
end

-- Get capacity
if vehicle.getFillUnitCapacity then
    local capacity = vehicle:getFillUnitCapacity(1)
end

-- Get fill type
if vehicle.getFillUnitFillType then
    local fillType = vehicle:getFillUnitFillType(1)
end

-- Add fill
if vehicle.addFillUnitFillLevel then
    vehicle:addFillUnitFillLevel(self:getOwnerFarmId(), 1, amount, fillType)
end
```

---

## AI Vehicle Detection

```lua
function isAIVehicle(vehicle)
    if vehicle == nil then
        return false
    end

    -- Check AI driver specialization
    if vehicle.spec_aiVehicle ~= nil then
        return vehicle:getIsAIActive()
    end

    -- Check if controlled by courseplay or other AI
    if vehicle.getAIVehicle and vehicle:getAIVehicle() ~= nil then
        return true
    end

    return false
end

-- Usage
function MyVehicleSpec:onUpdate(dt, isActiveForInput, ...)
    if isAIVehicle(self) then
        -- AI-specific behavior
        return
    end

    -- Player behavior
end
```

---

## Implement Processing

### Get Attached Implements
```lua
function processAttachedImplements(vehicle)
    if vehicle.getAttachedImplements == nil then
        return
    end

    local implements = vehicle:getAttachedImplements()
    for _, implement in pairs(implements) do
        local impl = implement.object
        if impl ~= nil then
            -- Process implement
            print("Attached: " .. impl:getName())

            -- Recursive for nested implements
            processAttachedImplements(impl)
        end
    end
end
```

### Check Implement Type
```lua
function isHarvesterHeader(implement)
    if implement == nil then
        return false
    end

    -- Check for specific specialization
    if implement.spec_cutter ~= nil then
        return true
    end

    return false
end
```

---

## Vehicle Save Data

### Save to Savegame
```lua
function MyVehicleSpec:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_myVehicleSpec

    xmlFile:setInt(key .. "#myValue", spec.myValue)
    xmlFile:setBool(key .. "#isActive", spec.isActive)
end
```

### Load from Savegame
```lua
function MyVehicleSpec:onPostLoad(savegame)
    local spec = self.spec_myVehicleSpec

    if savegame ~= nil and not savegame.resetVehicles then
        local key = savegame.key .. ".myVehicleSpec"

        spec.myValue = savegame.xmlFile:getInt(key .. "#myValue", 0)
        spec.isActive = savegame.xmlFile:getBool(key .. "#isActive", false)
    end
end
```

---

## Input Actions

```lua
function MyVehicleSpec:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        local spec = self.spec_myVehicleSpec

        -- Only register when vehicle is active for input
        if isActiveForInput then
            local _, actionEventId = self:addActionEvent(
                spec.actionEvents,
                InputAction.MY_ACTION,
                self,
                MyVehicleSpec.actionEventCallback,
                false,  -- triggerUp
                true,   -- triggerDown
                false,  -- triggerAlways
                true    -- startActive
            )

            g_inputBinding:setActionEventText(actionEventId,
                g_i18n:getText("action_myAction"))
            g_inputBinding:setActionEventTextPriority(actionEventId,
                GS_PRIO_NORMAL)
        end
    end
end

function MyVehicleSpec.actionEventCallback(self, actionName, inputValue, ...)
    local spec = self.spec_myVehicleSpec
    self:myCustomFunction()
end
```

---

## Common Pitfalls

### 1. Missing spec Reference
```lua
-- WRONG: spec is nil if specialization not loaded
function MyVehicleSpec:onUpdate(dt)
    self.spec_myVehicleSpec.value = 10  -- May crash!
end

-- CORRECT: Check first
function MyVehicleSpec:onUpdate(dt)
    local spec = self.spec_myVehicleSpec
    if spec == nil then return end

    spec.value = 10
end
```

### 2. Wrong Event Listener Signature
```lua
-- WRONG: Missing parameters
function MyVehicleSpec:onUpdate(dt)
end

-- CORRECT: Include all parameters
function MyVehicleSpec:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
end
```

### 3. Registering for Non-Existent Specialization
```lua
-- WRONG: May not have motorized
for _, vt in pairs(g_vehicleTypeManager:getVehicleTypes()) do
    vt:addSpecialization(modName .. ".mySpec")  -- Added to trailers too!
end

-- CORRECT: Filter appropriately
for _, vt in pairs(g_vehicleTypeManager:getVehicleTypes()) do
    if vt:hasSpecialization("motorized") then
        vt:addSpecialization(modName .. ".mySpec")
    end
end
```

### 4. Network Sync Order
Stream read/write must match exactly (see events.md for details).
