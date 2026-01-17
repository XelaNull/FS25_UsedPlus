# Data Classes with Business Logic

**Standalone classes that encapsulate data and related operations**

Based on patterns from: HirePurchasing, BuyUsedEquipment, EnhancedLoanSystem

---

## Related API Documentation

> 📖 For serialization functions, see the [FS25 Community LUADOC](https://github.com/umbraprior/FS25-Community-LUADOC)

| Topic | API Reference | Description |
|-------|---------------|-------------|
| XML Read/Write | [XML/](https://github.com/umbraprior/FS25-Community-LUADOC/tree/main/docs/engine/XML) | `getXMLInt()`, `setXMLString()`, etc. |
| Network Stream | [Network/](https://github.com/umbraprior/FS25-Community-LUADOC/tree/main/docs/engine/Network) | `streamReadInt32()`, `streamWriteFloat32()`, etc. |
| Class System | [Data/](https://github.com/umbraprior/FS25-Community-LUADOC/tree/main/docs/script/Data) | Base data structures |

---

## Overview

Data classes are standalone Lua classes that:
- Hold structured data (like a deal, loan, or listing)
- Contain business logic methods (calculations, validation)
- Handle their own serialization (save/load, network sync)
- Can be used across the mod

---

## Basic Data Class Structure

```lua
--[[
    MyDataClass - Represents a [description]

    Contains:
    - Data properties
    - Business logic methods
    - Serialization for save/load
    - Serialization for network sync
]]

MyDataClass = {}
local MyDataClass_mt = Class(MyDataClass)

-- Constructor
function MyDataClass.new(param1, param2, param3)
    local self = setmetatable({}, MyDataClass_mt)

    -- Data properties
    self.id = ""
    self.param1 = param1 or 0
    self.param2 = param2 or ""
    self.param3 = param3 or false
    self.createdAt = g_currentMission.time

    return self
end

-- Business logic methods
function MyDataClass:calculate()
    -- Perform calculations using properties
    return self.param1 * 2
end

function MyDataClass:isValid()
    return self.param1 > 0 and self.param2 ~= ""
end

-- Getters/setters
function MyDataClass:getValue()
    return self.param1
end

function MyDataClass:setValue(value)
    self.param1 = value
end
```

---

## Complete Example: Finance Deal

```lua
FinanceDeal = {}
local FinanceDeal_mt = Class(FinanceDeal)

function FinanceDeal.new(dealType, baseCost, deposit, durationMonths, finalFee, monthsPaid)
    local self = setmetatable({}, FinanceDeal_mt)

    -- Core data
    self.id = ""  -- Set by manager
    self.dealType = dealType or 1
    self.baseCost = baseCost or 0
    self.deposit = deposit or 0
    self.durationMonths = durationMonths or 12
    self.finalFee = finalFee or 0
    self.monthsPaid = monthsPaid or 0

    -- References
    self.farmId = -1
    self.vehicleId = ""
    self.objectId = -1

    return self
end

--[[
    Calculate interest rate based on deposit ratio
    Higher deposits = lower interest rates
]]
function FinanceDeal:getInterestRate()
    local depositRatio = self.deposit / self.baseCost

    if depositRatio <= 0.05 then
        return 0.05      -- 5% interest
    elseif depositRatio <= 0.10 then
        return 0.04      -- 4% interest
    elseif depositRatio <= 0.20 then
        return 0.035     -- 3.5% interest
    elseif depositRatio <= 0.30 then
        return 0.0295    -- 2.95% interest
    else
        return 0.025     -- 2.5% interest
    end
end

--[[
    Calculate monthly payment using financial formula
    PMT = (PV - FV/(1+r)^n) * (r*(1+r)^n) / ((1+r)^n - 1)
]]
function FinanceDeal:getMonthlyPayment()
    local amountFinanced = self.baseCost - self.deposit
    local interestRate = self:getInterestRate()
    local monthlyInterest = interestRate / 12

    local pv = amountFinanced
    local fv = self.finalFee
    local n = self.durationMonths
    local r = monthlyInterest

    if r == 0 then
        return (pv - fv) / n
    end

    local monthlyPayment = (pv - fv / ((1 + r) ^ n)) *
                           (r * (1 + r) ^ n) /
                           ((1 + r) ^ n - 1)

    return monthlyPayment
end

--[[
    Get total cost over life of deal
]]
function FinanceDeal:getTotalCost()
    return self.deposit +
           (self:getMonthlyPayment() * self.durationMonths) +
           self.finalFee
end

--[[
    Get remaining balance
]]
function FinanceDeal:getRemainingBalance()
    local monthsRemaining = self.durationMonths - self.monthsPaid
    return self:getMonthlyPayment() * monthsRemaining + self.finalFee
end

--[[
    Check if deal is complete
]]
function FinanceDeal:isComplete()
    return self.monthsPaid >= self.durationMonths
end

--[[
    Process monthly payment
    Returns true if deal is now complete
]]
function FinanceDeal:processMonthlyPayment()
    if self:isComplete() then
        -- Final payment
        return true
    end

    self.monthsPaid = self.monthsPaid + 1
    return self:isComplete()
end
```

---

## Network Serialization

For multiplayer support, data classes need stream read/write methods:

```lua
--[[
    Write data to network stream
    Order MUST match readStream exactly
]]
function FinanceDeal:writeStream(streamId, connection)
    streamWriteString(streamId, self.id)
    streamWriteInt32(streamId, self.dealType)
    streamWriteInt32(streamId, self.baseCost)
    streamWriteInt32(streamId, self.deposit)
    streamWriteInt32(streamId, self.durationMonths)
    streamWriteInt32(streamId, self.finalFee)
    streamWriteInt32(streamId, self.monthsPaid)
    streamWriteInt32(streamId, self.farmId)
    streamWriteInt32(streamId, self.objectId)
    streamWriteString(streamId, self.vehicleId)
end

--[[
    Read data from network stream
    Order MUST match writeStream exactly
]]
function FinanceDeal:readStream(streamId, connection)
    self.id = streamReadString(streamId)
    self.dealType = streamReadInt32(streamId)
    self.baseCost = streamReadInt32(streamId)
    self.deposit = streamReadInt32(streamId)
    self.durationMonths = streamReadInt32(streamId)
    self.finalFee = streamReadInt32(streamId)
    self.monthsPaid = streamReadInt32(streamId)
    self.farmId = streamReadInt32(streamId)
    self.objectId = streamReadInt32(streamId)
    self.vehicleId = streamReadString(streamId)
end
```

---

## Save/Load Serialization

For persistence to savegame XML:

```lua
--[[
    Save to XML file
]]
function FinanceDeal:saveToXMLFile(xmlFile, key)
    xmlFile:setString(key .. "#id", self.id)
    xmlFile:setInt(key .. "#dealType", self.dealType)
    xmlFile:setInt(key .. "#baseCost", self.baseCost)
    xmlFile:setInt(key .. "#deposit", self.deposit)
    xmlFile:setInt(key .. "#durationMonths", self.durationMonths)
    xmlFile:setInt(key .. "#finalFee", self.finalFee)
    xmlFile:setInt(key .. "#monthsPaid", self.monthsPaid)
    xmlFile:setInt(key .. "#farmId", self.farmId)
    xmlFile:setString(key .. "#vehicleId", self.vehicleId)
end

--[[
    Load from XML file
    Returns true if load was successful
]]
function FinanceDeal:loadFromXMLFile(xmlFile, key)
    self.id = xmlFile:getString(key .. "#id", "")
    self.dealType = xmlFile:getInt(key .. "#dealType", 1)
    self.baseCost = xmlFile:getInt(key .. "#baseCost", 0)
    self.deposit = xmlFile:getInt(key .. "#deposit", 0)
    self.durationMonths = xmlFile:getInt(key .. "#durationMonths", 12)
    self.finalFee = xmlFile:getInt(key .. "#finalFee", 0)
    self.monthsPaid = xmlFile:getInt(key .. "#monthsPaid", 0)
    self.farmId = xmlFile:getInt(key .. "#farmId", -1)
    self.vehicleId = xmlFile:getString(key .. "#vehicleId", "")

    -- Validate loaded data
    return self.id ~= "" and self.farmId >= 0
end
```

---

## Alternative XML Functions

Some mods use the older XML API:

```lua
-- Old-style XML functions (still work)
function FinanceDeal:saveToXmlFile(xmlFile, key)
    setXMLString(xmlFile, key .. "#id", self.id)
    setXMLInt(xmlFile, key .. "#baseCost", self.baseCost)
    setXMLFloat(xmlFile, key .. "#interestRate", self.interestRate)
    setXMLBool(xmlFile, key .. "#isActive", self.isActive)
end

function FinanceDeal:loadFromXMLFile(xmlFile, key)
    self.id = getXMLString(xmlFile, key .. "#id") or ""
    self.baseCost = getXMLInt(xmlFile, key .. "#baseCost") or 0
    self.interestRate = getXMLFloat(xmlFile, key .. "#interestRate") or 0.05
    self.isActive = getXMLBool(xmlFile, key .. "#isActive") or false
end
```

---

## Data Class with Status Tracking

```lua
VehicleSaleListing = {}
local VehicleSaleListing_mt = Class(VehicleSaleListing)

-- Status constants
VehicleSaleListing.STATUS = {
    PENDING = 1,      -- Waiting for buyer
    SOLD = 2,         -- Sale complete
    EXPIRED = 3,      -- TTL reached zero
    CANCELLED = 4     -- Manually cancelled
}

function VehicleSaleListing.new()
    local self = setmetatable({}, VehicleSaleListing_mt)

    self.id = ""
    self.farmId = -1
    self.vehicleId = ""
    self.askingPrice = 0
    self.currentOffer = 0
    self.status = VehicleSaleListing.STATUS.PENDING

    -- Time tracking
    self.ttl = 72      -- Hours until expiry
    self.tts = 24      -- Hours until first offer
    self.hoursActive = 0

    return self
end

function VehicleSaleListing:isPending()
    return self.status == VehicleSaleListing.STATUS.PENDING
end

function VehicleSaleListing:isSold()
    return self.status == VehicleSaleListing.STATUS.SOLD
end

function VehicleSaleListing:hasOffer()
    return self.currentOffer > 0
end

function VehicleSaleListing:acceptOffer()
    if not self:hasOffer() then
        return false
    end
    self.status = VehicleSaleListing.STATUS.SOLD
    return true
end

function VehicleSaleListing:processHour()
    if not self:isPending() then
        return
    end

    self.hoursActive = self.hoursActive + 1
    self.ttl = self.ttl - 1

    if self.ttl <= 0 then
        self.status = VehicleSaleListing.STATUS.EXPIRED
    elseif self.tts > 0 then
        self.tts = self.tts - 1
    end
end
```

---

## Best Practices

### 1. Encapsulate Related Logic
Keep calculations and validation inside the data class:
```lua
-- Good: Logic is with the data
function Deal:canAffordPayment(balance)
    return balance >= self:getMonthlyPayment()
end

-- Avoid: Logic scattered elsewhere
if farm.balance >= deal.baseCost * deal.interestRate / 12 then ...
```

### 2. Use Constants for Magic Numbers
```lua
FinanceDeal.DEAL_TYPE = {
    LEASE = 1,
    FINANCE = 2,
    LOAN = 3
}

function FinanceDeal:isLease()
    return self.dealType == FinanceDeal.DEAL_TYPE.LEASE
end
```

### 3. Validate on Load
```lua
function MyData:loadFromXMLFile(xmlFile, key)
    -- Load data...

    -- Validate
    if self.amount < 0 then
        Logging.warning("Invalid amount in save data, using default")
        self.amount = 0
    end

    return self:isValid()
end
```

### 4. Provide Default Values
```lua
function MyData.new(value)
    local self = setmetatable({}, MyData_mt)
    self.value = value or 100  -- Default if not provided
    return self
end
```

---

## Common Pitfalls

### 1. Stream Read/Write Order Mismatch
```lua
-- WRONG: Order doesn't match
function MyData:writeStream(streamId)
    streamWriteInt32(streamId, self.a)
    streamWriteInt32(streamId, self.b)
end
function MyData:readStream(streamId)
    self.b = streamReadInt32(streamId)  -- Wrong!
    self.a = streamReadInt32(streamId)
end

-- CORRECT: Same order
function MyData:writeStream(streamId)
    streamWriteInt32(streamId, self.a)
    streamWriteInt32(streamId, self.b)
end
function MyData:readStream(streamId)
    self.a = streamReadInt32(streamId)
    self.b = streamReadInt32(streamId)
end
```

### 2. Missing Nil Checks
```lua
-- WRONG: May crash if vehicle doesn't exist
function Deal:getVehicleName()
    return self.vehicle:getName()
end

-- CORRECT: Check first
function Deal:getVehicleName()
    if self.vehicle then
        return self.vehicle:getName()
    end
    return "Unknown"
end
```

### 3. Forgetting to Initialize Arrays
```lua
-- WRONG: May be nil
function MyData.new()
    local self = setmetatable({}, MyData_mt)
    -- self.items is nil!
    return self
end

-- CORRECT: Initialize
function MyData.new()
    local self = setmetatable({}, MyData_mt)
    self.items = {}
    return self
end
```
