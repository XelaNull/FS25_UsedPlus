# UsedPlus Maintenance System: Complete Integration Plan

## Overview

This document outlines the design and implementation plan for integrating a realistic maintenance/breakdown system into the UsedPlus mod for Farming Simulator 25.

**Key Features:**
- Hidden reliability scores on used vehicles
- Pre-purchase inspection system
- Progressive failure system (stalling, hydraulic drift, implement cutout)
- Speed degradation based on damage
- Maintenance history tracking
- Resale value modifications

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              UsedPlus Mod                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────┐     ┌─────────────────────┐     ┌───────────────┐ │
│  │   Used Market       │     │  Vehicle Ownership  │     │   Maintenance │ │
│  │   System            │◄───►│  Tracking           │◄───►│   System      │ │
│  └─────────────────────┘     └─────────────────────┘     └───────────────┘ │
│           │                           │                          │          │
│           ▼                           ▼                          ▼          │
│  ┌─────────────────────┐     ┌─────────────────────┐     ┌───────────────┐ │
│  │ • Search for used   │     │ • Purchase history  │     │ • Failures    │ │
│  │ • Generate listings │     │ • Repair history    │     │ • Degradation │ │
│  │ • Inspection system │     │ • Ownership duration│     │ • Warnings    │ │
│  │ • Hidden conditions │     │ • Maintenance log   │     │ • Speed limit │ │
│  └─────────────────────┘     └─────────────────────┘     └───────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Proven FS25 APIs Used

| Capability | API/Method | Confirmed Working In |
|------------|------------|----------------------|
| Prevent engine start | `getCanMotorRun()` override | AdvancedMaintenance |
| Stop/start engine | `stopMotor()` / `startMotor()` | Courseplay |
| Check engine state | `getMotorState()` | Courseplay |
| Get/set damage | `getDamageAmount()` / `addDamageAmount()` | Multiple mods |
| Get wear level | `getWearTotalAmount()` | Multiple mods |
| Limit max speed | `setCruiseControlMaxSpeed()` | HeadlandManagement |
| Get engine load | `getMotorLoadPercentage()` | AdvancedMaintenance |
| Get operating hours | `getOperatingTime()` | AdvancedMaintenance |
| Stop AI workers | `stopCurrentAIJob()` | AdvancedMaintenance |
| Raise/lower implements | `setLoweredAll()` | HeadlandManagement |
| Turn implements on/off | `setIsTurnedOn()` | Courseplay |
| Show warnings | `showBlinkingWarning()` | Multiple mods |
| Per-frame updates | `onUpdate` listener | Standard |
| Save/load custom data | `schemaSavegame:register()` | HeadlandManagement, FST99Service |

---

## Data Model

### Per-Vehicle Extended Data (Persisted)

```lua
vehicle.spec_usedPlus = {
    -- Purchase Information
    purchasedUsed = false,           -- Was this bought used?
    purchaseDate = 0,                -- Game time when purchased
    purchasePrice = 0,               -- What player paid
    purchaseDamage = 0,              -- Damage at time of purchase
    purchaseHours = 0,               -- Hours at time of purchase
    wasInspected = false,            -- Did player pay for inspection?

    -- Hidden Reliability Scores (0.0 - 1.0, lower = worse)
    -- These are HIDDEN from player unless inspected
    engineReliability = 1.0,         -- Affects stalling, hard start
    hydraulicReliability = 1.0,      -- Affects implement drift
    electricalReliability = 1.0,     -- Affects implement turn-off

    -- Maintenance History
    repairCount = 0,                 -- Times repaired at shop
    totalRepairCost = 0,             -- Lifetime repair spending
    lastRepairDate = 0,              -- Last shop visit
    failureCount = 0,                -- Total breakdowns experienced

    -- Runtime State (not persisted, calculated)
    currentMaxSpeed = nil,           -- Calculated speed limit
    stallCooldown = 0,               -- Prevents rapid re-stalling
    isStalled = false,               -- Currently stalled?
}
```

### Save/Load Schema Registration

```lua
function UsedPlusMaintenance.initSpecialization()
    local schemaSavegame = Vehicle.xmlSchemaSavegame
    local key = "vehicles.vehicle(?).usedPlus"

    -- Purchase info
    schemaSavegame:register(XMLValueType.BOOL,  key..".purchasedUsed", "Bought as used")
    schemaSavegame:register(XMLValueType.FLOAT, key..".purchaseDate", "Purchase game time")
    schemaSavegame:register(XMLValueType.FLOAT, key..".purchasePrice", "Purchase price")
    schemaSavegame:register(XMLValueType.FLOAT, key..".purchaseDamage", "Damage at purchase")
    schemaSavegame:register(XMLValueType.FLOAT, key..".purchaseHours", "Hours at purchase")
    schemaSavegame:register(XMLValueType.BOOL,  key..".wasInspected", "Was inspected before purchase")

    -- Hidden reliability (only saved, never shown directly)
    schemaSavegame:register(XMLValueType.FLOAT, key..".engineReliability", "Engine reliability")
    schemaSavegame:register(XMLValueType.FLOAT, key..".hydraulicReliability", "Hydraulic reliability")
    schemaSavegame:register(XMLValueType.FLOAT, key..".electricalReliability", "Electrical reliability")

    -- Maintenance history
    schemaSavegame:register(XMLValueType.INT,   key..".repairCount", "Repair count")
    schemaSavegame:register(XMLValueType.FLOAT, key..".totalRepairCost", "Total repair spending")
    schemaSavegame:register(XMLValueType.FLOAT, key..".lastRepairDate", "Last repair date")
    schemaSavegame:register(XMLValueType.INT,   key..".failureCount", "Failure count")
end
```

---

## Integration Point 1: Used Vehicle Generation

When UsedPlus generates a used vehicle listing, we add hidden reliability scores.

### Enhanced Generation Flow

```lua
function UsedPlus:generateSaleItem(storeItem, preferredGeneration)
    local generation = GENERATIONS[generationIndex]

    -- Existing values
    local damage = getRandomValue(generation.damage)
    local wear = getRandomValue(generation.wear)
    local hours = getRandomValue(generation.hours)
    local age = getRandomValue(generation.age)

    -- NEW: Generate hidden reliability scores
    -- These are influenced by damage but have variance
    -- A high-damage vehicle MIGHT have good engine, or might not
    local reliabilityBase = 1 - damage

    local engineReliability = math.max(0.1, reliabilityBase + randomVariance(0.2))
    local hydraulicReliability = math.max(0.1, reliabilityBase + randomVariance(0.25))
    local electricalReliability = math.max(0.1, reliabilityBase + randomVariance(0.15))

    -- Clamp to 0-1
    engineReliability = math.min(1, math.max(0, engineReliability))
    hydraulicReliability = math.min(1, math.max(0, hydraulicReliability))
    electricalReliability = math.min(1, math.max(0, electricalReliability))

    -- Store in sale item for transfer to vehicle on purchase
    return {
        -- Existing
        timeLeft = math.random(MIN_SALE_DURATION, MAX_SALE_DURATION),
        xmlFilename = storeItem.xmlFilename,
        age = age,
        price = calculatedPrice,
        damage = damage,
        wear = wear,
        operatingTime = hours * 3600000,

        -- NEW: Hidden reliability data
        usedPlusData = {
            engineReliability = engineReliability,
            hydraulicReliability = hydraulicReliability,
            electricalReliability = electricalReliability,
            wasInspected = false,
        }
    }
end
```

---

## Integration Point 2: Pre-Purchase Inspection

Player can pay for inspection before buying to reveal hidden issues.

### Inspection UI Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  USED TRACTOR - John Deere 6R                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Price: $45,000                                                │
│  Age: 8 years | Hours: 3,847                                   │
│                                                                 │
│  VISIBLE CONDITION:                                            │
│  ├── Damage: 35%                                               │
│  └── Wear: 42%                                                 │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  [!] Hidden mechanical condition unknown                 │   │
│  │                                                          │   │
│  │  ► Pay $750 for professional inspection                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  [BUY AS-IS]              [INSPECT FIRST]           [CANCEL]   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### After Inspection

```
┌─────────────────────────────────────────────────────────────────┐
│  INSPECTION REPORT - John Deere 6R                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  MECHANICAL ASSESSMENT:                                         │
│                                                                 │
│  Engine:      ▓▓▓▓▓▓░░░░  58%   ⚠ Below average               │
│  Hydraulics:  ▓▓▓▓▓▓▓▓░░  79%   ✓ Acceptable                   │
│  Electrical:  ▓▓▓▓▓▓▓░░░  71%   ✓ Acceptable                   │
│                                                                 │
│  Inspector Notes:                                               │
│  "Engine shows signs of hard use. Expect occasional            │
│   stalling under load. Hydraulics in fair condition.           │
│   Recommend budget for engine work within 500 hours."          │
│                                                                 │
│  RECOMMENDATION: Negotiate price or budget for repairs         │
│                                                                 │
│  [BUY ANYWAY - $45,000]                             [CANCEL]   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Implementation

```lua
function UsedPlus:performInspection(saleItem)
    local inspectionCost = self:calculateInspectionCost(saleItem.price)

    -- Deduct cost
    g_currentMission:addMoney(-inspectionCost, farmId, MoneyType.SHOP_PROPERTY_BUY, true)

    -- Mark as inspected
    saleItem.usedPlusData.wasInspected = true

    -- Generate inspection report
    local report = {
        engineRating = self:getRatingText(saleItem.usedPlusData.engineReliability),
        hydraulicRating = self:getRatingText(saleItem.usedPlusData.hydraulicReliability),
        electricalRating = self:getRatingText(saleItem.usedPlusData.electricalReliability),
        notes = self:generateInspectorNotes(saleItem.usedPlusData),
    }

    return report
end

function UsedPlus:calculateInspectionCost(vehiclePrice)
    -- Base $200 + 1% of vehicle price, capped at $2000
    local cost = 200 + (vehiclePrice * 0.01)
    return math.min(cost, 2000)
end

function UsedPlus:getRatingText(reliability)
    if reliability >= 0.8 then return "Good", "✓"
    elseif reliability >= 0.6 then return "Acceptable", "✓"
    elseif reliability >= 0.4 then return "Below Average", "⚠"
    elseif reliability >= 0.2 then return "Poor", "⚠"
    else return "Critical", "✗"
    end
end

function UsedPlus:generateInspectorNotes(data)
    local notes = {}

    if data.engineReliability < 0.5 then
        table.insert(notes, "Engine shows signs of hard use. Expect stalling under load.")
    end
    if data.hydraulicReliability < 0.5 then
        table.insert(notes, "Hydraulic system worn. Implements may drift when raised.")
    end
    if data.electricalReliability < 0.5 then
        table.insert(notes, "Electrical issues detected. Implements may cut out unexpectedly.")
    end

    if #notes == 0 then
        table.insert(notes, "Vehicle in acceptable mechanical condition.")
    end

    return table.concat(notes, " ")
end
```

---

## Integration Point 3: On Vehicle Purchase

When a used vehicle is purchased, transfer hidden data to the vehicle entity.

```lua
function UsedPlus:onVehiclePurchased(vehicle, saleItem)
    local spec = vehicle.spec_usedPlus

    if saleItem ~= nil and saleItem.usedPlusData ~= nil then
        -- This was a used purchase
        spec.purchasedUsed = true
        spec.purchaseDate = g_currentMission.environment.dayTime
        spec.purchasePrice = saleItem.price
        spec.purchaseDamage = saleItem.damage
        spec.purchaseHours = saleItem.operatingTime / 3600000
        spec.wasInspected = saleItem.usedPlusData.wasInspected

        -- Transfer hidden reliability scores
        spec.engineReliability = saleItem.usedPlusData.engineReliability
        spec.hydraulicReliability = saleItem.usedPlusData.hydraulicReliability
        spec.electricalReliability = saleItem.usedPlusData.electricalReliability
    else
        -- New vehicle purchase
        spec.purchasedUsed = false
        spec.engineReliability = 1.0
        spec.hydraulicReliability = 1.0
        spec.electricalReliability = 1.0
    end

    -- Initialize maintenance history
    spec.repairCount = 0
    spec.totalRepairCost = 0
    spec.failureCount = 0
end
```

---

## Integration Point 4: Active Failure System

The core runtime system that causes breakdowns based on reliability + damage.

### Failure Probability Calculation

```lua
function UsedPlusMaintenance:calculateFailureProbability(vehicle, failureType)
    local spec = vehicle.spec_usedPlus
    local damage = vehicle:getDamageAmount()
    local hours = vehicle:getOperatingTime() / 3600000
    local load = vehicle:getMotorLoadPercentage()

    -- Get relevant reliability score
    local reliability = 1.0
    if failureType == "engine" then
        reliability = spec.engineReliability or 1.0
    elseif failureType == "hydraulic" then
        reliability = spec.hydraulicReliability or 1.0
    elseif failureType == "electrical" then
        reliability = spec.electricalReliability or 1.0
    end

    -- Base failure chance (per update tick, roughly per second)
    -- Damage contribution: 0-50% damage = low risk, 50-100% = escalating risk
    local damageRisk = math.max(0, (damage - 0.3) * 2)  -- 0 until 30% damage, then scales

    -- Reliability contribution: lower reliability = higher risk
    local reliabilityRisk = (1 - reliability)

    -- Hours contribution: more hours = slightly higher risk
    local hoursRisk = math.min(hours / 10000, 0.3)  -- Caps at 0.3 after 10k hours

    -- Load contribution: higher load = higher risk
    local loadRisk = load * 0.5  -- 0-0.5 based on load

    -- Combined probability (per-second base)
    local baseChance = 0.0001  -- 0.01% base chance per second
    local totalRisk = damageRisk + reliabilityRisk + hoursRisk + loadRisk

    return baseChance * (1 + totalRisk * 10)
end
```

### Engine Stalling Implementation

```lua
function UsedPlusMaintenance:checkEngineStall(vehicle, dt)
    local spec = vehicle.spec_usedPlus

    -- Cooldown check (prevent stalling every frame)
    if spec.stallCooldown > 0 then
        spec.stallCooldown = spec.stallCooldown - dt
        return
    end

    -- Only check running engines
    if vehicle:getMotorState() == MotorState.OFF then
        return
    end

    local stallChance = self:calculateFailureProbability(vehicle, "engine")

    if math.random() < stallChance then
        -- STALL!
        vehicle:stopMotor()
        spec.isStalled = true
        spec.stallCooldown = 30000  -- 30 second cooldown
        spec.failureCount = (spec.failureCount or 0) + 1

        -- Show warning
        g_currentMission:showBlinkingWarning(
            g_i18n:getText("usedPlus_engineStalled"),
            5000
        )

        -- Stop AI if active
        local rootVehicle = vehicle:getRootVehicle()
        if rootVehicle:getIsAIActive() then
            rootVehicle:stopCurrentAIJob(AIMessageErrorVehicleBroken.new())
        end
    end
end
```

### Hard Start Implementation

```lua
function UsedPlusMaintenance:getCanMotorRun(vehicle, superFunc)
    local spec = vehicle.spec_usedPlus
    local damage = vehicle:getDamageAmount()

    -- At very high damage, engine may not start at all
    if damage > 0.9 then
        local startChance = (1 - damage) * spec.engineReliability
        if math.random() > startChance then
            -- Failed to start
            g_currentMission:showBlinkingWarning(
                g_i18n:getText("usedPlus_engineWontStart"),
                3000
            )
            return false
        end
    end

    return superFunc(vehicle)
end
```

### Speed Degradation Implementation

```lua
function UsedPlusMaintenance:updateSpeedLimit(vehicle)
    local spec = vehicle.spec_usedPlus
    local damage = vehicle:getDamageAmount()

    -- Calculate speed reduction factor
    -- 0% damage = 100% speed
    -- 50% damage = 85% speed
    -- 100% damage = 50% speed
    local speedFactor = 1 - (damage * 0.5)

    -- Engine reliability also affects max speed
    local reliabilityFactor = 0.7 + (spec.engineReliability * 0.3)

    local finalFactor = speedFactor * reliabilityFactor
    finalFactor = math.max(finalFactor, 0.3)  -- Never below 30% speed

    -- Apply speed limit
    local spec_drivable = vehicle.spec_drivable
    if spec_drivable and spec_drivable.cruiseControl then
        local originalMax = spec_drivable.cruiseControl.maxSpeed
        local limitedMax = originalMax * finalFactor

        if vehicle:getCruiseControlSpeed() > limitedMax then
            vehicle:setCruiseControlMaxSpeed(limitedMax, limitedMax)
        end
    end
end
```

### Hydraulic Drift Implementation

```lua
function UsedPlusMaintenance:checkHydraulicDrift(vehicle, dt)
    local spec = vehicle.spec_usedPlus
    local damage = vehicle:getDamageAmount()

    -- Check all attached implements
    local implements = vehicle:getAttachedImplements()
    for _, implement in pairs(implements) do
        local implVehicle = implement.object

        if implVehicle and implVehicle.getIsLowered and not implVehicle:getIsLowered() then
            -- Implement is raised
            local driftChance = self:calculateFailureProbability(vehicle, "hydraulic")
            driftChance = driftChance * 2  -- Slightly more common than stalls

            if math.random() < driftChance then
                -- Drift down!
                if implVehicle.setLoweredAll then
                    implVehicle:setLoweredAll(true)
                    spec.failureCount = (spec.failureCount or 0) + 1

                    g_currentMission:showBlinkingWarning(
                        g_i18n:getText("usedPlus_hydraulicDrift"),
                        3000
                    )
                end
            end
        end
    end
end
```

### Implement Cutout Implementation

```lua
function UsedPlusMaintenance:checkImplementCutout(vehicle, dt)
    local spec = vehicle.spec_usedPlus

    local implements = vehicle:getAttachedImplements()
    for _, implement in pairs(implements) do
        local implVehicle = implement.object

        if implVehicle and implVehicle.getIsTurnedOn and implVehicle:getIsTurnedOn() then
            local cutoutChance = self:calculateFailureProbability(vehicle, "electrical")

            if math.random() < cutoutChance then
                -- Cut out!
                if implVehicle.setIsTurnedOn then
                    implVehicle:setIsTurnedOn(false)
                    spec.failureCount = (spec.failureCount or 0) + 1

                    g_currentMission:showBlinkingWarning(
                        g_i18n:getText("usedPlus_implementCutout"),
                        3000
                    )
                end
            end
        end
    end
end
```

---

## Integration Point 5: Repair System Hook

When player repairs at shop, update reliability and history.

```lua
function UsedPlusMaintenance:onVehicleRepaired(vehicle, repairCost)
    local spec = vehicle.spec_usedPlus

    -- Update maintenance history
    spec.repairCount = (spec.repairCount or 0) + 1
    spec.totalRepairCost = (spec.totalRepairCost or 0) + repairCost
    spec.lastRepairDate = g_currentMission.environment.dayTime

    -- Repairs improve reliability (but never back to 100%)
    -- Each repair restores some reliability, with diminishing returns
    local repairBonus = 0.15  -- 15% improvement per repair
    local maxReliability = 0.95  -- Can never get back to 100%

    spec.engineReliability = math.min(maxReliability,
        (spec.engineReliability or 0.5) + repairBonus)
    spec.hydraulicReliability = math.min(maxReliability,
        (spec.hydraulicReliability or 0.5) + repairBonus)
    spec.electricalReliability = math.min(maxReliability,
        (spec.electricalReliability or 0.5) + repairBonus)
end

-- Hook into the repair action
Wearable.repairVehicle = Utils.appendedFunction(Wearable.repairVehicle, function(self)
    local repairCost = self:getRepairPrice()
    UsedPlusMaintenance:onVehicleRepaired(self, repairCost)
end)
```

---

## Integration Point 6: Resale Value Calculation

When selling a vehicle, maintenance history affects price.

```lua
function UsedPlus:calculateResaleValue(vehicle)
    local spec = vehicle.spec_usedPlus
    local baseValue = Vehicle.calculateSellPrice(...)  -- Existing calculation

    -- Maintenance history modifier
    local historyFactor = 1.0

    -- Well-maintained (few failures, regular repairs) = bonus
    local failuresPerHour = (spec.failureCount or 0) /
        math.max(1, vehicle:getOperatingTime() / 3600000)

    if failuresPerHour < 0.01 then
        historyFactor = historyFactor + 0.05  -- +5% for reliable vehicle
    elseif failuresPerHour > 0.1 then
        historyFactor = historyFactor - 0.10  -- -10% for problem vehicle
    end

    -- Recent repairs = slight bonus (shows maintenance)
    local hoursSinceRepair = 0  -- Calculate from lastRepairDate
    if spec.repairCount > 0 and hoursSinceRepair < 100 then
        historyFactor = historyFactor + 0.03  -- +3% recently serviced
    end

    -- Hidden reliability affects value (buyers somehow sense quality)
    local avgReliability = ((spec.engineReliability or 1) +
                           (spec.hydraulicReliability or 1) +
                           (spec.electricalReliability or 1)) / 3
    historyFactor = historyFactor + ((avgReliability - 0.5) * 0.1)  -- ±5%

    return baseValue * historyFactor
end
```

---

## Integration Point 7: Vehicle Info Display

Show maintenance info in vehicle details panel.

```lua
function UsedPlusMaintenance:getVehicleInfoText(vehicle)
    local spec = vehicle.spec_usedPlus
    local lines = {}

    if spec.purchasedUsed then
        table.insert(lines, g_i18n:getText("usedPlus_purchasedUsed"))
    end

    -- Show repair history
    if spec.repairCount > 0 then
        table.insert(lines, string.format(
            g_i18n:getText("usedPlus_repairHistory"),
            spec.repairCount,
            g_i18n:formatMoney(spec.totalRepairCost)
        ))
    end

    -- Show failure count as "reliability indicator"
    if spec.failureCount > 0 then
        table.insert(lines, string.format(
            g_i18n:getText("usedPlus_breakdownHistory"),
            spec.failureCount
        ))
    end

    -- Condition assessment (vague, not exact numbers)
    local avgReliability = ((spec.engineReliability or 1) +
                           (spec.hydraulicReliability or 1) +
                           (spec.electricalReliability or 1)) / 3

    local condition = "Unknown"
    if avgReliability > 0.8 then condition = g_i18n:getText("usedPlus_conditionGood")
    elseif avgReliability > 0.5 then condition = g_i18n:getText("usedPlus_conditionFair")
    else condition = g_i18n:getText("usedPlus_conditionPoor")
    end

    table.insert(lines, string.format(
        g_i18n:getText("usedPlus_mechanicalCondition"),
        condition
    ))

    return lines
end
```

---

## File Structure

```
UsedPlus/
├── modDesc.xml
├── icon.dds
├── src/
│   ├── UsedPlus.lua                    -- Main mod entry point
│   ├── market/
│   │   ├── UsedMarket.lua              -- Used vehicle search/generation
│   │   ├── SaleItem.lua                -- Sale listing data structure
│   │   ├── InspectionSystem.lua        -- Pre-purchase inspection
│   │   └── MarketEvents.lua            -- Network events
│   ├── ownership/
│   │   ├── VehicleOwnership.lua        -- Per-vehicle tracking
│   │   ├── MaintenanceHistory.lua      -- Repair/failure logging
│   │   └── ResaleCalculator.lua        -- Sell price calculation
│   ├── maintenance/
│   │   ├── MaintenanceManager.lua      -- Core failure system
│   │   ├── EngineFailures.lua          -- Stalling, hard start
│   │   ├── HydraulicFailures.lua       -- Implement drift
│   │   ├── ElectricalFailures.lua      -- Implement cutout
│   │   ├── SpeedDegradation.lua        -- Max speed reduction
│   │   └── FailureProbability.lua      -- Probability calculations
│   ├── ui/
│   │   ├── InspectionDialog.lua        -- Inspection report UI
│   │   ├── VehicleInfoExtension.lua    -- Extended vehicle info
│   │   └── WarningDisplay.lua          -- In-game warnings
│   └── events/
│       ├── InspectionEvent.lua         -- Multiplayer sync
│       ├── RepairEvent.lua             -- Repair notifications
│       └── FailureEvent.lua            -- Failure sync
└── l10n/
    ├── l10n_en.xml
    └── l10n_de.xml
```

---

## Event Listeners & Registration

```lua
function UsedPlusMaintenance.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", UsedPlusMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", UsedPlusMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", UsedPlusMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", UsedPlusMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "saveToXMLFile", UsedPlusMaintenance)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", UsedPlusMaintenance)
end

function UsedPlusMaintenance.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanMotorRun",
        UsedPlusMaintenance.getCanMotorRun)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getMotorNotAllowedWarning",
        UsedPlusMaintenance.getMotorNotAllowedWarning)
end

function UsedPlusMaintenance:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    -- Throttle checks to every 1 second
    local spec = self.spec_usedPlus
    spec.updateTimer = (spec.updateTimer or 0) + dt

    if spec.updateTimer >= 1000 then
        spec.updateTimer = 0

        UsedPlusMaintenance:checkEngineStall(self, dt)
        UsedPlusMaintenance:checkHydraulicDrift(self, dt)
        UsedPlusMaintenance:checkImplementCutout(self, dt)
        UsedPlusMaintenance:updateSpeedLimit(self)
    end
end
```

---

## Localization Strings

```xml
<!-- l10n_en.xml -->
<l10n>
    <!-- Warnings -->
    <text name="usedPlus_engineStalled" text="Engine stalled!" />
    <text name="usedPlus_engineWontStart" text="Engine won't start - try again" />
    <text name="usedPlus_hydraulicDrift" text="Hydraulic pressure loss!" />
    <text name="usedPlus_implementCutout" text="Implement stalled!" />

    <!-- Inspection -->
    <text name="usedPlus_inspectButton" text="Inspect ($%s)" />
    <text name="usedPlus_inspectionReport" text="Inspection Report" />
    <text name="usedPlus_conditionGood" text="Good" />
    <text name="usedPlus_conditionFair" text="Fair" />
    <text name="usedPlus_conditionPoor" text="Poor" />

    <!-- Vehicle Info -->
    <text name="usedPlus_purchasedUsed" text="Purchased used" />
    <text name="usedPlus_repairHistory" text="Repairs: %d ($%s total)" />
    <text name="usedPlus_breakdownHistory" text="Breakdowns: %d" />
    <text name="usedPlus_mechanicalCondition" text="Mechanical: %s" />
</l10n>
```

---

## Configuration

```lua
UsedPlus.CONFIG = {
    -- Feature toggles
    enableFailures = true,
    enableInspection = true,
    enableSpeedDegradation = true,
    enableResaleModifier = true,

    -- Balance tuning
    failureRateMultiplier = 1.0,      -- Global failure frequency
    speedDegradationMax = 0.5,        -- Max 50% speed reduction
    inspectionCostBase = 200,         -- Base inspection cost
    inspectionCostPercent = 0.01,     -- + 1% of vehicle price

    -- Thresholds
    damageThresholdForFailures = 0.2, -- Failures start at 20% damage
    reliabilityRepairBonus = 0.15,    -- Each repair adds 15% reliability
    maxReliabilityAfterRepair = 0.95, -- Can never fully restore

    -- AI behavior
    affectAIVehicles = true,          -- AI vehicles can break down too
}
```

---

## Integration Points Summary

| Integration Point | Trigger | What Happens |
|------------------|---------|--------------|
| **Vehicle Generation** | Used listing created | Hidden reliability scores generated |
| **Pre-Purchase Inspection** | Player clicks Inspect | Reliability revealed, cost deducted |
| **Vehicle Purchase** | Used vehicle bought | Hidden data transferred to vehicle entity |
| **Runtime Failures** | Every second while driving | Stall/drift/cutout checks based on reliability |
| **Speed Degradation** | Continuous | Max speed reduced based on damage + reliability |
| **Repair Hook** | Vehicle repaired at shop | History updated, reliability partially restored |
| **Resale Calculation** | Vehicle sold | Price modified by history and reliability |
| **Vehicle Info** | Player views vehicle | Maintenance history and condition shown |

---

## Failure Types Summary

| Failure | Trigger | Effect | Recovery |
|---------|---------|--------|----------|
| **Engine Stall** | Random, based on damage + reliability | Motor stops | Manual restart |
| **Hard Start** | Damage > 90% | Delayed/failed start | Wait, retry |
| **No Start** | Damage near 100% | Engine won't run | Shop repair only |
| **Speed Loss** | Continuous at any damage | Reduced max speed | Repair |
| **Hydraulic Drop** | Random, raised implements | Implement lowers | Re-raise, repair |
| **Implement Stall** | Random, active implements | Implement turns off | Toggle on, repair |
| **AI Stop** | On any major failure | Worker stops job | Fix issue, restart |

---

## Player Experience Examples

> "My tractor's at 65% damage. I know I should repair it, but I'm trying to finish this field first. The cruise control won't go past 18 km/h anymore. Halfway through, the engine stalls. I restart it. It stalls again 2 minutes later. I finally limp to the shop. Lesson learned."

> "Bought a used harvester, seemed like a good deal. First day, the header keeps turning off randomly. Had to keep toggling it back on. Frustrating but manageable. Second day, engine wouldn't start on the third try. Had to wait and try again. Definitely need to get this thing fixed."

> "Paid $500 to inspect that Fendt before buying. Report said engine was at 58%, hydraulics were fine. Bought it anyway knowing what I was getting into. Saved $30,000 off new price, budgeted $5,000 for repairs. Smart purchase."

---

## Implementation Priority

1. **Phase 1: Core Data Model**
   - Schema registration
   - Save/load functionality
   - Basic vehicle tracking

2. **Phase 2: Failure System**
   - Engine stalling
   - Speed degradation
   - Warning display

3. **Phase 3: Used Market Integration**
   - Reliability generation on sale items
   - Transfer to purchased vehicles

4. **Phase 4: Inspection System**
   - UI dialog
   - Cost calculation
   - Report generation

5. **Phase 5: Polish**
   - Hydraulic drift
   - Implement cutout
   - Resale value modification
   - Vehicle info display
