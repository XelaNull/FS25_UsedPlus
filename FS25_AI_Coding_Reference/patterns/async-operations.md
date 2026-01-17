# Async Operations & Queues

**Time-based asynchronous operations using TTL/TTS patterns**

Based on patterns from: BuyUsedEquipment, UsedPlus

---

## Related API Documentation

> 📖 For time/mission APIs, see the [FS25 Community LUADOC](https://github.com/umbraprior/FS25-Community-LUADOC)

| Topic | API Reference | Description |
|-------|---------------|-------------|
| Environment | [Environment.md](https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/Misc/Environment.md) | `g_currentMission.environment` time data |
| Mission | (use `g_currentMission`) | `currentDay`, `time` properties |

**Key Globals:**
- `g_currentMission.time` - Current time in ms
- `g_currentMission.environment.currentDay` - Current day number
- Subscribe to `MessageType.HOUR_CHANGED` for hourly processing

---

## Overview

Many mod features need delayed execution:
- Searching for used vehicles (takes time)
- Processing loan applications
- Waiting for marketplace responses
- Any "pending" operation

FS25 mods implement this using **TTL/TTS queues**:
- **TTL (Time To Live)**: Hours until operation expires/fails
- **TTS (Time To Success)**: Hours until operation completes successfully

---

## Basic TTL/TTS Pattern

### Queue Item Structure
```lua
-- Data structure for async operation
local queueItem = {
    id = "unique_id",
    data = { ... },           -- Any associated data
    ttl = 72,                 -- Hours until expiry (max lifetime)
    tts = 24,                 -- Hours until success (if successful)
    status = "pending",       -- pending, completed, expired
    callback = nil            -- Optional callback function
}
```

### How It Works
1. **Create**: Set TTL (max time) and TTS (success time)
2. **Process**: Every game hour, decrement both counters
3. **Complete**: If TTS reaches 0 first → success
4. **Expire**: If TTL reaches 0 first → failure/timeout

---

## Complete Implementation Example

### Creating Search Assignments
```lua
BuyUsedEquipment = {}

-- Configuration for different search levels
BuyUsedEquipment.SEARCH_LEVELS = {
    {name = "Local (%s)", chance = 0.6, duration = 1, fee = 0.01},    -- 1 day, 60% success
    {name = "Regional (%s)", chance = 0.75, duration = 2, fee = 0.02}, -- 2 days, 75% success
    {name = "National (%s)", chance = 0.9, duration = 3, fee = 0.03},  -- 3 days, 90% success
}

function BuyUsedEquipment:createSearchAssignment(xmlFilename, searchLevel)
    local searchConfig = self.SEARCH_LEVELS[searchLevel]

    return {
        id = self:generateId(),
        filename = xmlFilename,
        level = searchLevel,
        ttl = searchConfig.duration * 24,  -- Convert days to hours
        tts = self:calculateTimeToSuccess(searchConfig),
        createdAt = g_currentMission.time
    }
end

-- Determine when/if search succeeds
function BuyUsedEquipment:calculateTimeToSuccess(searchConfig)
    local chance = searchConfig.chance
    local durationHours = searchConfig.duration * 24

    -- Random check for success
    if math.random() <= chance then
        -- Success! Random time within duration
        return math.random(1, durationHours)
    else
        -- Failure - TTS exceeds TTL so it will expire first
        return durationHours + 1
    end
end
```

### Hourly Processing
```lua
function FarmExtension:onHourChanged()
    -- Only process on server
    if not g_currentMission:getIsServer() then
        return
    end

    local searches = self.activeSearches or {}
    if #searches == 0 then
        return
    end

    -- Process from end to beginning (safe removal during iteration)
    for i = #searches, 1, -1 do
        local search = searches[i]

        -- Decrement timers
        search.ttl = search.ttl - 1
        search.tts = search.tts - 1

        -- Check completion states
        if search.tts <= 0 then
            -- SUCCESS: TTS reached zero first
            self:onSearchComplete(search, true)
            table.remove(searches, i)

        elseif search.ttl <= 0 then
            -- FAILURE: TTL reached zero (expired)
            self:onSearchComplete(search, false)
            table.remove(searches, i)
        end
    end
end

function FarmExtension:onSearchComplete(search, success)
    if success then
        -- Create the used vehicle listing
        BuyUsedEquipment:finalizeSearch(self.farmId, search.filename, true)

        -- Notify player
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_OK,
            g_i18n:getText("search_success")
        )
    else
        -- Refund partial fee or notify failure
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
            g_i18n:getText("search_failed")
        )
    end
end
```

---

## Generic Async Queue Manager

Reusable queue pattern for any async operation:

```lua
AsyncQueue = {}
local AsyncQueue_mt = Class(AsyncQueue)

function AsyncQueue.new()
    local self = setmetatable({}, AsyncQueue_mt)

    self.queue = {}
    self.nextId = 1

    return self
end

--[[
    Add item to queue
    @param data - Any data to associate with the operation
    @param ttl - Hours until expiry
    @param tts - Hours until success (nil = same as ttl)
    @param callbacks - {onSuccess=fn, onExpire=fn, onTick=fn}
    @return id - Queue item ID for tracking
]]
function AsyncQueue:add(data, ttl, tts, callbacks)
    local item = {
        id = self.nextId,
        data = data,
        ttl = ttl,
        tts = tts or ttl,
        callbacks = callbacks or {},
        createdAt = g_currentMission.time
    }

    table.insert(self.queue, item)
    self.nextId = self.nextId + 1

    return item.id
end

--[[
    Process queue (call every game hour)
]]
function AsyncQueue:processHour()
    for i = #self.queue, 1, -1 do
        local item = self.queue[i]

        -- Decrement timers
        item.ttl = item.ttl - 1
        item.tts = item.tts - 1

        -- Optional tick callback
        if item.callbacks.onTick then
            item.callbacks.onTick(item.data, item.ttl, item.tts)
        end

        -- Check completion
        if item.tts <= 0 then
            -- Success
            if item.callbacks.onSuccess then
                item.callbacks.onSuccess(item.data)
            end
            table.remove(self.queue, i)

        elseif item.ttl <= 0 then
            -- Expired
            if item.callbacks.onExpire then
                item.callbacks.onExpire(item.data)
            end
            table.remove(self.queue, i)
        end
    end
end

--[[
    Cancel a queued item
    @return true if found and cancelled
]]
function AsyncQueue:cancel(id)
    for i, item in ipairs(self.queue) do
        if item.id == id then
            if item.callbacks.onCancel then
                item.callbacks.onCancel(item.data)
            end
            table.remove(self.queue, i)
            return true
        end
    end
    return false
end

--[[
    Get item by ID
]]
function AsyncQueue:getById(id)
    for _, item in ipairs(self.queue) do
        if item.id == id then
            return item
        end
    end
    return nil
end

--[[
    Get all items (for display)
]]
function AsyncQueue:getAll()
    return self.queue
end

--[[
    Get remaining time for item
]]
function AsyncQueue:getRemainingTime(id)
    local item = self:getById(id)
    if item then
        return {
            ttl = item.ttl,
            tts = item.tts,
            progress = 1 - (item.tts / (item.tts + (g_currentMission.time - item.createdAt)))
        }
    end
    return nil
end
```

### Usage Example
```lua
-- Create queue
local searchQueue = AsyncQueue.new()

-- Add search operation
local searchId = searchQueue:add(
    {vehicleType = "tractor", farmId = 1},  -- data
    72,  -- TTL: 72 hours max
    24,  -- TTS: 24 hours to success
    {
        onSuccess = function(data)
            print("Found " .. data.vehicleType .. " for farm " .. data.farmId)
            -- Create vehicle listing
        end,
        onExpire = function(data)
            print("Search expired for " .. data.vehicleType)
            -- Notify player, maybe refund
        end,
        onTick = function(data, ttl, tts)
            -- Update UI progress bar
        end
    }
)

-- In hourly handler
function MyMod:onHourChanged()
    searchQueue:processHour()
end

-- Player cancels search
searchQueue:cancel(searchId)
```

---

## Save/Load Queue State

```lua
function AsyncQueue:saveToXMLFile(xmlFile, key)
    for i, item in ipairs(self.queue) do
        local itemKey = string.format("%s.item(%d)", key, i - 1)

        xmlFile:setInt(itemKey .. "#id", item.id)
        xmlFile:setInt(itemKey .. "#ttl", item.ttl)
        xmlFile:setInt(itemKey .. "#tts", item.tts)
        xmlFile:setInt(itemKey .. "#createdAt", item.createdAt)

        -- Save data (customize based on your data structure)
        if item.data.filename then
            xmlFile:setString(itemKey .. "#filename", item.data.filename)
        end
        if item.data.farmId then
            xmlFile:setInt(itemKey .. "#farmId", item.data.farmId)
        end
    end

    -- Save next ID to prevent duplicates
    xmlFile:setInt(key .. "#nextId", self.nextId)
end

function AsyncQueue:loadFromXMLFile(xmlFile, key, callbackFactory)
    self.queue = {}
    self.nextId = xmlFile:getInt(key .. "#nextId", 1)

    local index = 0
    while true do
        local itemKey = string.format("%s.item(%d)", key, index)
        if not xmlFile:hasProperty(itemKey) then
            break
        end

        local item = {
            id = xmlFile:getInt(itemKey .. "#id", 0),
            ttl = xmlFile:getInt(itemKey .. "#ttl", 0),
            tts = xmlFile:getInt(itemKey .. "#tts", 0),
            createdAt = xmlFile:getInt(itemKey .. "#createdAt", 0),
            data = {
                filename = xmlFile:getString(itemKey .. "#filename", ""),
                farmId = xmlFile:getInt(itemKey .. "#farmId", -1)
            },
            callbacks = callbackFactory and callbackFactory(item.data) or {}
        }

        if item.ttl > 0 then  -- Only load non-expired items
            table.insert(self.queue, item)
        end

        index = index + 1
    end
end
```

---

## Common Patterns

### Progress Calculation
```lua
function AsyncQueue:getProgress(id)
    local item = self:getById(id)
    if item == nil then
        return 0
    end

    -- Calculate based on TTS (time to success)
    local totalTime = item.createdAt  -- Need to store original TTS
    local elapsed = totalTime - item.tts
    return elapsed / totalTime
end
```

### Status Display
```lua
function AsyncQueue:getStatusText(id)
    local item = self:getById(id)
    if item == nil then
        return "Unknown"
    end

    if item.tts <= 0 then
        return "Complete"
    elseif item.ttl <= item.tts then
        -- Will succeed
        return string.format("%d hours remaining", item.tts)
    else
        -- Will expire
        return string.format("Expiring in %d hours", item.ttl)
    end
end
```

---

## Best Practices

### 1. Always Process Server-Side
```lua
function MyMod:onHourChanged()
    if not g_currentMission:getIsServer() then
        return  -- Only server processes queue
    end
    self.queue:processHour()
end
```

### 2. Iterate Backwards for Safe Removal
```lua
-- WRONG: Forward iteration breaks when removing
for i, item in ipairs(queue) do
    if item.ttl <= 0 then
        table.remove(queue, i)  -- Breaks iteration!
    end
end

-- CORRECT: Backward iteration
for i = #queue, 1, -1 do
    if queue[i].ttl <= 0 then
        table.remove(queue, i)  -- Safe
    end
end
```

### 3. Persist Queue State
Always save/load queue state to prevent loss on game restart.

### 4. Handle Edge Cases
```lua
-- Handle game time jumps (fast forward)
if timeDelta > 24 then
    -- Process multiple hours at once
    for hour = 1, math.min(timeDelta, item.ttl) do
        item.ttl = item.ttl - 1
        item.tts = item.tts - 1
    end
end
```
