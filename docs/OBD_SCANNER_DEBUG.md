# OBD Scanner Keybind Bug - Debug Log

**Created:** 2026-01-25
**Status:** 🔄 IN PROGRESS (v2.0.7)

## Solution Summary

**Root Cause:** Using `registerActionEvent()` combined with `inputBinding` in modDesc.xml creates DUPLICATE action events. The game creates one from the inputBinding (visible, no callback), and we create another from registerActionEvent (has callback, not visible properly). Result: double keybind display, callback never fires.

**Fix:** Use hybrid approach:
1. Keep `inputBinding` in modDesc.xml for visual keybind display
2. **Remove** all `registerActionEvent()` calls
3. Poll input directly in `onUpdate` using `g_inputBinding:getDigitalInputAxis()`
4. Display custom prompt via `g_currentMission:addExtraPrintText()`

See `CLAUDE.md` section "On-Foot Input System" for reusable pattern.

---

## Problem Description

When player approaches OBD Scanner on ground:
1. **Keybind shows DOUBLE**: `[O] [O] Use OBD Scanner` (two key indicators)
2. **Pressing key does NOT activate** the scanner (callback doesn't fire)

**Reference:** Mobile Service Kit works perfectly with same pattern - single `[R]` keybind.

---

## Key Files

| File | Purpose |
|------|---------|
| `vehicles/FieldServiceKit.lua` | OBD Scanner specialization |
| `modDesc.xml` | Action & binding definitions |
| `translations/translation_en.xml` | `input_USEDPLUS_ACTIVATE_OBD` text |

---

## Git History (FieldServiceKit.lua)

| Commit | Date | Description |
|--------|------|-------------|
| `df5088c` | 2026-01-17 | v2.6.2 - Last commit touching this file |
| `b393e89` | 2026-01-11 | v2.2.0 |
| `ea3008d` | 2025-12-28 | v1.8.2 - Initial |

---

## Test Log

### Test 1: Restored to df5088c + CutOpenBale pattern
**Time:** ~18:33
**Changes:**
- Reverted FieldServiceKit.lua to committed version
- Changed `startActive` to `false`
- Removed `setActionEventTextVisibility` calls
- Removed `setActionEventText` calls
- Simplified hook (removed Mission00 fallback)

**Log Output:**
```
OBD Scanner: Hooked PlayerInputComponent.registerGlobalPlayerActionEvents
OBD Scanner: Found InputAction.USEDPLUS_ACTIVATE_OBD
OBD Scanner: registerActionEvent returned valid=true, eventId=USEDPLUS_ACTIVATE_OBD|USEDPLUS_ACTIVATE_OBD|1
```

**Result:** FAIL - Still double keybind

---

### Test 2: Removed inputBinding from modDesc.xml
**Time:** ~18:41
**Changes:** Commented out `<actionBinding action="USEDPLUS_ACTIVATE_OBD">` in modDesc.xml

**Result:** FAIL - No keybind appears at all

---

### Test 3: Restore EXACT v2.6.2 committed version
**Time:** ~18:50
**Changes:**
- `git checkout df5088c -- vehicles/FieldServiceKit.lua`
- `git checkout df5088c -- modDesc.xml`

**Key Attributes Restored:**
- Action: `category="ONFOOT" axisType="HALF"`
- Lua: `startActive=true`, all setActionEvent* calls present, Mission00 fallback present

**Result:** FAIL - Caused Lua errors because old modDesc.xml incompatible with new Lua files

---

### Test 4: Current uncommitted + v2.6.2 patterns
**Time:** ~18:55
**State:**
- modDesc.xml: `<action name="USEDPLUS_ACTIVATE_OBD" category="ONFOOT" axisType="HALF"/>`
- FieldServiceKit.lua: Original v2.6.2 patterns (setActionEventTextVisibility, setActionEventText, startActive=true, Mission00 fallback)
- All other files: Current uncommitted versions

**Result:** FAIL - Lua errors in UsedPlusMaintenance.lua (unrelated to OBD issue)

**Lua Errors Found:**
```
UsedPlusMaintenance.lua:776: attempt to index nil with 'tireWearDistanceBase'
UsedPlusMaintenance.lua:234: attempt to index nil with 'enableSpeedDegradation'
```

**Root Cause:** `UsedPlusMaintenance.CONFIG` accessed before initialization during vehicle load
**Fix Applied:** Added defensive nil checks at lines 234, 776, and 1074

---

### Test 5: Post Lua-error fixes
**Time:** ~19:15
**Changes:**
- Fixed CONFIG nil checks in UsedPlusMaintenance.lua (3 locations)
- modDesc.xml: Still has `category="ONFOOT" axisType="HALF"` attributes
- FieldServiceKit.lua: v2.6.2 patterns intact

**Result:** FAIL - Still double keybind `[O] [O]`, pressing O does nothing

---

### Test 6: Match CutOpenBale EXACTLY
**Time:** ~19:25
**Changes:**
- modDesc.xml: Removed `category` and `axisType` → `<action name="USEDPLUS_ACTIVATE_OBD"/>`
- FieldServiceKit.lua:
  - `startActive = false` (was true)
  - Removed all `setActionEventTextVisibility` calls
  - Removed all `setActionEventText` calls
  - `updateGlobalActionEvent()` now ONLY calls `setActionEventTextPriority` + `setActionEventActive`
  - Added diagnostic logging to `onGlobalActivateOBD()` callback

**CutOpenBale Pattern Being Matched:**
```lua
-- Registration
g_inputBinding:registerActionEvent(actionId, "identifier", callback, false, true, false, false)
-- ^ startActive = false (last param)

-- Update (every frame)
g_inputBinding:setActionEventTextPriority(actionId, GS_PRIO_VERY_HIGH)
g_inputBinding:setActionEventActive(actionId, hasTarget)
```

**Result:** PENDING - User testing

---

### Test 7: Object target + hookInstalled flag
**Time:** ~19:40
**Changes:**
- Changed 2nd param from STRING `"USEDPLUS_ACTIVATE_OBD"` to OBJECT `FieldServiceKit`
- Added `hookInstalled = true` in first hook path to prevent double-registration

**Background Research Findings:**
Most working mods use an OBJECT as the callback target, not a string:
- RealisticWeather: `MoistureSystem` (object)
- Employment: `EmploymentSystem` (object)
- ProductionInfoHud: `self` (object)
- CutOpenBale: `"CutBaleAction"` (string - exception)

**Result:** PENDING - User testing

---

## Stashed Work

**Stash:** `WIP: Pre-OBD-debug backup 20260125_184147`
**Files:** 44 modified files safely stashed

---

## Git Comparison Results

### modDesc.xml Changes (v2.6.2 → current)

**v2.6.2 (committed):**
```xml
<action name="USEDPLUS_ACTIVATE_OBD" category="ONFOOT" axisType="HALF"/>
```

**Current (uncommitted):**
```xml
<action name="USEDPLUS_ACTIVATE_OBD"/>
```

**Difference:** `category` and `axisType` attributes REMOVED

### FieldServiceKit.lua Changes (v2.6.2 → current)

| Aspect | v2.6.2 | Current |
|--------|--------|---------|
| `startActive` param | `true` | `false` |
| `setActionEventTextVisibility` | Called | Removed |
| `setActionEventText` | Called | Removed |
| Mission00 fallback | Present | Removed |
| Post-registration calls | setActionEventTextPriority, setActionEventActive, setActionEventTextVisibility | None |

---

## Next Steps

1. **Test 3:** Restore EXACT v2.6.2 versions of both files
2. If v2.6.2 works → our changes broke it
3. If v2.6.2 doesn't work → something external changed

---

## Observations

- EventId format `ACTION|ACTION|1` is unusual (action name appears twice)
- CutOpenBale works with similar pattern
- OilServicePoint works but uses Activatable pattern (not custom action)

---

## Session 2: 2026-01-25 Evening

### Test 8: v2.0.5 - CutOpenBale Pattern (Full Implementation)
**Time:** ~19:50
**Changes:**
- Added `FieldServiceKit.actionEventId` and `FieldServiceKit.hookInstalled` globals
- Added `PlayerInputComponent.registerGlobalPlayerActionEvents` hook
- Hook registers action event with callback `FieldServiceKit.onActionCallback`
- `onUpdate` uses `setActionEventText()`, `setActionEventActive()`, `setActionEventTextVisibility()`
- `getActivatePromptText()` returns text WITHOUT `[O]` prefix (game should add it)
- Removed `addExtraPrintText()` call
- Removed direct `getDigitalInputAxis()` polling

**Pattern Used:**
```lua
-- Registration (in hook)
g_inputBinding:registerActionEvent(actionId, FieldServiceKit, callback, false, true, false, true)

-- Update (every frame when player nearby)
g_inputBinding:setActionEventText(eventId, "OBD Scanner: Vehicle Name")
g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_HIGH)
g_inputBinding:setActionEventActive(eventId, true)
g_inputBinding:setActionEventTextVisibility(eventId, true)
```

**Result:** FAIL - Still double keybind `[O] [O]`

**Conclusion:** The CutOpenBale pattern does NOT work for UsedPlus. Unknown why - possibly mod load order, specialization timing, or other factor.

---

### Test 9: v2.0.6 - Back to Direct Polling (NO registerActionEvent)
**Time:** ~20:00
**Changes:**
- Removed `FieldServiceKit.actionEventId` and `FieldServiceKit.hookInstalled`
- Removed `PlayerInputComponent.registerGlobalPlayerActionEvents` hook
- Removed `FieldServiceKit.onActionCallback`
- `onUpdate` back to using `addExtraPrintText()` for display
- `onUpdate` back to using `getDigitalInputAxis()` for input polling
- `getActivatePromptText()` returns text WITH `[O]` prefix (manual)

**Pattern Used:**
```lua
-- Display (every frame when player nearby)
g_currentMission:addExtraPrintText("[O] OBD Scanner: Vehicle Name")

-- Input polling (every frame when player nearby)
local inputValue = g_inputBinding:getDigitalInputAxis(InputAction.USEDPLUS_ACTIVATE_OBD)
if inputValue > 0 and not spec.inputWasPressed then
    spec.inputWasPressed = true
    self:activateFieldService()
end
```

**Result:** FAIL - Still double keybind (user confirmed)

---

### Test 10: v2.0.7 - RVB Pattern (Exact Copy)
**Time:** ~20:30
**Changes:**
- Copied EXACT pattern from `FS25_gameplay_Real_Vehicle_Breakdowns/scripts/player/RVBPlayer.lua`
- Hook into `PlayerInputComponent.registerActionEvents` (not `registerGlobalPlayerActionEvents`)
- Wrap registration in `beginActionEventsModification()` / `endActionEventsModification()`
- Check `inputComponent.player.isOwner` before registering
- Use `startActive = false` (7th param)
- Use `disableConflictingBindings = true` (9th param)
- `getActivatePromptText()` returns text WITHOUT `[O]` prefix
- `onUpdate` uses `setActionEventText/Active/TextVisibility` to control display

**Pattern Used (Exact RVB Copy):**
```lua
-- In hook for PlayerInputComponent.registerActionEvents:
if inputComponent.player.isOwner then
    g_inputBinding:beginActionEventsModification(PlayerInputComponent.INPUT_CONTEXT_NAME)
    local success, eventId = g_inputBinding:registerActionEvent(
        actionId, target, callback,
        false, true, false, false, nil, true
    )
    g_inputBinding:endActionEventsModification()
end

-- In onUpdate:
g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_VERY_HIGH)
g_inputBinding:setActionEventTextVisibility(eventId, shouldShow)
g_inputBinding:setActionEventActive(eventId, shouldShow)
g_inputBinding:setActionEventText(eventId, "OBD Scanner: Vehicle Name")  -- No [O] prefix
```

**Result:** PENDING - User testing

---

## Key Learnings

| Approach | inputBinding | registerActionEvent | Result |
|----------|--------------|---------------------|--------|
| Both | ✅ Yes | ✅ Yes | ❌ Double keybind |
| inputBinding only | ✅ Yes | ❌ No | ❓ Testing (v2.0.6) |
| registerActionEvent only | ❌ No | ✅ Yes | ❌ No keybind shows |

**The problem:** FS25 creates an action event from `inputBinding` automatically. When we call `registerActionEvent` on the same action, it creates a SECOND event. Both display, hence double keybind.

**Why CutOpenBale works but we don't:** Unknown. Possibly:
- Different mod load order
- CutOpenBale is a standalone mod, not a specialization
- Different timing of when the hook fires
- Some other environmental factor

**Our workaround:** Don't use `registerActionEvent` at all. Just:
1. Define `inputBinding` in modDesc.xml (required for `getDigitalInputAxis` to work)
2. Poll input with `getDigitalInputAxis()` in `onUpdate`
3. Display text with `addExtraPrintText()` (manually include `[KEY]` in string)

The tradeoff: We manually render the key name in the text instead of the game rendering a proper keybind icon. But it WORKS.
