# Extending Game Classes

**How to hook into and modify existing game classes**

Based on patterns from: HirePurchasing, BuyUsedEquipment, EnhancedLoanSystem

---

## Related API Documentation

> 📖 For complete function signatures, see the [FS25 Community LUADOC](https://github.com/umbraprior/FS25-Community-LUADOC)

| Class | API Reference | Description |
|-------|---------------|-------------|
| Utils | [Utils.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/Utils/Utils.md) | `appendedFunction()`, `prependedFunction()`, `overwrittenFunction()` |
| TypeManager | [TypeManager.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/Specialization/TypeManager.md) | Vehicle type registration |
| SpecializationManager | [SpecializationManager.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/Specialization/SpecializationManager.md) | Specialization registration |

**Commonly Extended Classes:**
- [Farm.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/Farms/Farm.md) - Per-farm data
- [InGameMenu.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/GUI/InGameMenu.md) - Menu tabs
- [ShopConfigScreen.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/Shop/ShopConfigScreen.md) - Shop customization

---

## Overview

FS25 mods extend game behavior by:
1. **Adding new methods** to existing classes
2. **Hooking existing methods** to run custom code before/after
3. **Overwriting methods** while still calling the original
4. **Subscribing to events** via Message Center

---

## Utils Extension Functions

### Utils.appendedFunction
Runs your code **AFTER** the original function:

```lua
-- Your code runs after original completes
Farm.saveToXMLFile = Utils.appendedFunction(
    Farm.saveToXMLFile,
    function(self, xmlFile, key)
        -- Original save already completed
        -- Now save our custom data
        self:saveMyModData(xmlFile, key)
    end
)
```

### Utils.prependedFunction
Runs your code **BEFORE** the original function:

```lua
-- Your code runs before original
ShopConfigScreen.updateButtons = Utils.prependedFunction(
    ShopConfigScreen.updateButtons,
    function(self, storeItem, vehicle, saleItem)
        -- Do something before buttons update
        self:prepareCustomButtons()
    end
)
```

### Utils.overwrittenFunction
**Replaces** the function but gives you access to call original:

```lua
-- You control when/if original runs
Farm.loadFromXMLFile = Utils.overwrittenFunction(
    Farm.loadFromXMLFile,
    function(self, superFunc, xmlFile, key)
        -- Call original function
        local result = superFunc(self, xmlFile, key)

        -- Then do our custom loading
        self:loadMyModData(xmlFile, key)

        return result
    end
)
```

**Key difference:** With `overwrittenFunction`, `superFunc` is the second parameter.

---

## Adding Methods to Existing Classes

Directly assign new functions to class tables:

```lua
-- Add new method to BuyVehicleData class
function BuyVehicleData:setLeaseDeal(leaseDeal)
    self.leaseDeal = leaseDeal
end

-- Add new method to Farm class
function Farm:getMyModItems()
    return self.myModItems or {}
end

-- Add new method with implementation
function Farm:processMyModHourly()
    for _, item in ipairs(self:getMyModItems()) do
        item.ttl = item.ttl - 1
        if item.ttl <= 0 then
            self:removeMyModItem(item)
        end
    end
end
```

---

## Complete Extension Example

```lua
--[[
    BuyVehicleDataExtension
    Adds leasing functionality to the purchase flow
]]

BuyVehicleDataExtension = {}

-- New method: Set lease deal on purchase data
function BuyVehicleDataExtension:setLeaseDeal(leaseDeal)
    self.leaseDeal = leaseDeal
end

-- Hook: Add lease data to network stream
function BuyVehicleDataExtension:writeStream(streamId, connection)
    streamWriteBool(streamId, self.leaseDeal ~= nil)
    if self.leaseDeal then
        self.leaseDeal:writeStream(streamId, connection)
    end
end

-- Hook: Read lease data from network stream
function BuyVehicleDataExtension:readStream(streamId, connection)
    if streamReadBool(streamId) then
        self.leaseDeal = LeaseDeal.new()
        self.leaseDeal:readStream(streamId, connection)
    else
        self.leaseDeal = nil
    end
end

-- Hook: Process after vehicle is bought
function BuyVehicleDataExtension.onBought(buyVehicleData, loadedVehicles, loadingState, args)
    if loadingState == VehicleLoadingState.OK then
        for _, vehicle in ipairs(loadedVehicles) do
            if buyVehicleData.leaseDeal ~= nil then
                -- Register the lease deal
                buyVehicleData.leaseDeal.objectId = NetworkUtil.getObjectId(vehicle)
                buyVehicleData.leaseDeal.vehicle = vehicle.uniqueId
                g_client:getServerConnection():sendEvent(
                    NewLeaseDealEvent.new(buyVehicleData.leaseDeal)
                )
                break
            end
        end
    end
end

-- Hook: Modify price calculation
function BuyVehicleDataExtension:updatePrice()
    if self.leaseDeal ~= nil then
        -- For leasing, price is just the deposit
        self.price = self.leaseDeal.deposit
    end
end

-- Hook: Pre-process before buy
function BuyVehicleDataExtension:buy()
    if self.leaseDeal ~= nil then
        self:updatePrice()
    end
end

-- Attach all extensions to BuyVehicleData class
BuyVehicleData.setLeaseDeal = BuyVehicleDataExtension.setLeaseDeal

BuyVehicleData.writeStream = Utils.appendedFunction(
    BuyVehicleData.writeStream,
    BuyVehicleDataExtension.writeStream
)

BuyVehicleData.readStream = Utils.appendedFunction(
    BuyVehicleData.readStream,
    BuyVehicleDataExtension.readStream
)

BuyVehicleData.onBought = Utils.prependedFunction(
    BuyVehicleData.onBought,
    BuyVehicleDataExtension.onBought
)

BuyVehicleData.updatePrice = Utils.appendedFunction(
    BuyVehicleData.updatePrice,
    BuyVehicleDataExtension.updatePrice
)

BuyVehicleData.buy = Utils.prependedFunction(
    BuyVehicleData.buy,
    BuyVehicleDataExtension.buy
)
```

---

## Extending Farm Class

Common pattern for adding per-farm data:

```lua
FarmExtension = {}

-- Extend constructor
function FarmExtension.new(isServer, superFunc, isClient, spectator, customMt, ...)
    -- Call original constructor
    local farm = superFunc(isServer, isClient, spectator, customMt, ...)

    -- Add custom data
    farm.myModDeals = {}
    farm.myModSettings = {}

    -- Subscribe to events (server only)
    if g_server ~= nil then
        g_messageCenter:subscribe(
            MessageType.HOUR_CHANGED,
            FarmExtension.onHourChanged,
            farm
        )
    end

    return farm
end

-- Hourly processing
function FarmExtension:onHourChanged()
    for i = #self.myModDeals, 1, -1 do
        local deal = self.myModDeals[i]
        if deal:processHourly() then
            table.remove(self.myModDeals, i)
        end
    end
end

-- Save extension
function FarmExtension:saveToXMLFile(xmlFile, key)
    for i, deal in ipairs(self.myModDeals or {}) do
        local dealKey = string.format("%s.myMod.deals.deal(%d)", key, i - 1)
        deal:saveToXMLFile(xmlFile, dealKey)
    end
end

-- Load extension
function FarmExtension:loadFromXMLFile(superFunc, xmlFile, key)
    local result = superFunc(self, xmlFile, key)

    self.myModDeals = {}
    xmlFile:iterate(key .. ".myMod.deals.deal", function(_, dealKey)
        local deal = MyDeal.new()
        if deal:loadFromXMLFile(xmlFile, dealKey) then
            table.insert(self.myModDeals, deal)
        end
    end)

    return result
end

-- Hook cleanup
function FarmExtension:delete()
    g_messageCenter:unsubscribe(MessageType.HOUR_CHANGED, self)
end

-- Register all extensions
Farm.new = Utils.overwrittenFunction(Farm.new, FarmExtension.new)
Farm.saveToXMLFile = Utils.appendedFunction(Farm.saveToXMLFile, FarmExtension.saveToXMLFile)
Farm.loadFromXMLFile = Utils.overwrittenFunction(Farm.loadFromXMLFile, FarmExtension.loadFromXMLFile)
Farm.delete = Utils.appendedFunction(Farm.delete, FarmExtension.delete)
```

---

## Extending Shop Screen

Add custom buttons to the vehicle shop:

```lua
ShopConfigScreenExtension = {}

function ShopConfigScreenExtension:setStoreItem(superFunc, storeItem, ...)
    -- Call original
    superFunc(self, storeItem, ...)

    -- Add custom button
    if self.myModButton == nil and self.buyButton ~= nil then
        local parent = self.buyButton.parent
        self.myModButton = self.buyButton:clone(parent)
        self.myModButton.name = "myModButton"
        self.myModButton.inputActionName = "MENU_EXTRA_1"
    end

    if self.myModButton then
        -- Configure button based on store item
        if self:canUseMyMod(storeItem) then
            self.myModButton:setDisabled(false)
            self.myModButton:setText(g_i18n:getText("myMod_buttonText"))
            self.myModButton.onClickCallback = function()
                self:onMyModButtonClicked(storeItem)
            end
        else
            self.myModButton:setDisabled(true)
        end
    end
end

function ShopConfigScreenExtension:canUseMyMod(storeItem)
    -- Check if this item qualifies
    return StoreItemUtil.getIsVehicle(storeItem)
end

function ShopConfigScreenExtension:onMyModButtonClicked(storeItem)
    -- Open custom dialog
    local dialog = g_gui:showDialog("MyModDialog")
    if dialog then
        dialog.target:setData(storeItem, self.totalPrice)
    end
end

-- Update button visibility
function ShopConfigScreenExtension:updateButtons(storeItem, vehicle, saleItem)
    if self.myModButton then
        -- Hide when customizing existing vehicle
        self.myModButton:setVisible(vehicle == nil)
    end
end

-- Register extensions
ShopConfigScreen.setStoreItem = Utils.overwrittenFunction(
    ShopConfigScreen.setStoreItem,
    ShopConfigScreenExtension.setStoreItem
)
ShopConfigScreen.updateButtons = Utils.appendedFunction(
    ShopConfigScreen.updateButtons,
    ShopConfigScreenExtension.updateButtons
)
```

---

## Message Center Subscriptions

Subscribe to game events for time-based processing:

```lua
-- Common message types
MessageType.HOUR_CHANGED      -- Every game hour
MessageType.DAY_CHANGED       -- Every game day
MessageType.MONTH_CHANGED     -- Every game month
MessageType.PERIOD_CHANGED    -- Every game period
MessageType.YEAR_CHANGED      -- Every game year
MessageType.MONEY_CHANGED     -- When farm money changes
MessageType.VEHICLE_SOLD      -- When vehicle is sold

-- Subscribe
g_messageCenter:subscribe(MessageType.HOUR_CHANGED, self.onHourChanged, self)

-- Handler
function MyManager:onHourChanged()
    if not g_currentMission:getIsServer() then
        return
    end
    -- Process hourly logic
end

-- Unsubscribe (important for cleanup!)
g_messageCenter:unsubscribe(MessageType.HOUR_CHANGED, self)
```

---

## Best Practices

### 1. Always Call Original Function
```lua
-- WRONG: Breaks original behavior
Farm.saveToXMLFile = function(self, xmlFile, key)
    -- Only saves our data, loses vanilla save!
    self:saveMyData(xmlFile, key)
end

-- CORRECT: Use Utils function
Farm.saveToXMLFile = Utils.appendedFunction(
    Farm.saveToXMLFile,
    function(self, xmlFile, key)
        self:saveMyData(xmlFile, key)
    end
)
```

### 2. Check for Nil Before Extending
```lua
-- WRONG: May crash if class doesn't exist
MyClass.method = Utils.appendedFunction(MyClass.method, myFunc)

-- CORRECT: Check first
if MyClass and MyClass.method then
    MyClass.method = Utils.appendedFunction(MyClass.method, myFunc)
end
```

### 3. Unsubscribe from Events
```lua
function MyManager:delete()
    -- Always unsubscribe to prevent memory leaks
    g_messageCenter:unsubscribe(MessageType.HOUR_CHANGED, self)
    g_messageCenter:unsubscribe(MessageType.DAY_CHANGED, self)
end
```

### 4. Server Check for State Changes
```lua
function MyExtension:onHourChanged()
    -- Only server should modify game state
    if not g_currentMission:getIsServer() then
        return
    end

    -- Process changes
end
```

---

## Common Pitfalls

### 1. Wrong Parameter Order in overwrittenFunction
```lua
-- WRONG: superFunc is not second parameter
Farm.method = Utils.overwrittenFunction(Farm.method,
    function(self, xmlFile, key)  -- Missing superFunc!
        -- ...
    end
)

-- CORRECT: superFunc is second parameter
Farm.method = Utils.overwrittenFunction(Farm.method,
    function(self, superFunc, xmlFile, key)
        local result = superFunc(self, xmlFile, key)
        return result
    end
)
```

### 2. Forgetting Return Value
```lua
-- WRONG: Loses return value
Farm.loadFromXMLFile = Utils.overwrittenFunction(Farm.loadFromXMLFile,
    function(self, superFunc, xmlFile, key)
        superFunc(self, xmlFile, key)  -- Return value lost!
        self:loadMyData(xmlFile, key)
    end
)

-- CORRECT: Preserve return value
Farm.loadFromXMLFile = Utils.overwrittenFunction(Farm.loadFromXMLFile,
    function(self, superFunc, xmlFile, key)
        local result = superFunc(self, xmlFile, key)
        self:loadMyData(xmlFile, key)
        return result
    end
)
```

### 3. Self Reference Issues
```lua
-- WRONG: 'self' in static context
function MyExtension.onBought(buyVehicleData, vehicles, state)
    self.count = self.count + 1  -- 'self' is nil here!
end

-- CORRECT: Use the passed parameter
function MyExtension.onBought(buyVehicleData, vehicles, state)
    buyVehicleData.count = (buyVehicleData.count or 0) + 1
end

-- OR use colon syntax with proper registration
function MyExtension:onBought(vehicles, state)
    self.count = self.count + 1  -- 'self' is buyVehicleData
end
```

### 4. Extending Before Class Exists
```lua
-- WRONG: Class may not be loaded yet
BuyVehicleData.myMethod = function() end  -- May crash!

-- CORRECT: Extend after class is available (usually in loadMap or init)
function MyMod:loadMap()
    if BuyVehicleData then
        BuyVehicleData.myMethod = function() end
    end
end
```
