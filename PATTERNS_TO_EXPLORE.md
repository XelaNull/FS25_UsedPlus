# Patterns to Explore for Future Development

**Created:** 2026-01-17
**Purpose:** Document patterns from our coding reference that could enhance FS25_UsedPlus but haven't been implemented yet.

These patterns were gathered during our 150+ mod analysis but weren't needed for UsedPlus v1.0-v2.6. They represent opportunities for future features.

---

## Quick Wins (Low Effort, High Value)

### 1. Quick Buttons Pattern
**Source:** `docs/patterns/gui-dialogs.md` (lines 312-328)
**Reference Mod:** TakeLoanDialog patterns from Giants base game

**Current State:** UsedPlus uses `MultiTextOption` dropdowns for all selections

**Opportunity:** Side-by-side quick buttons for common selections:
- Down payment presets: `[10%] [20%] [30%] [Custom]`
- Term year quick select: `[1yr] [3yr] [5yr] [10yr]`
- Repair percentage: `[25%] [50%] [75%] [100%]`

**Implementation Notes:**
```xml
<BoxLayout profile="quickButtonRow" position="0px -120px" size="400px 40px">
    <Button profile="buttonActivate" onClick="onQuickSelect10" text="10%"/>
    <Button profile="buttonActivate" onClick="onQuickSelect20" text="20%"/>
    <Button profile="buttonActivate" onClick="onQuickSelect30" text="30%"/>
</BoxLayout>
```

**Benefit:** Faster UX - most users pick standard options, shouldn't need dropdown clicks

**Files to Modify:**
- `gui/TakeLoanDialog.xml` - Add quick buttons for down payment
- `gui/UnifiedPurchaseDialog.xml` - Add quick buttons for term selection
- `src/gui/TakeLoanDialog.lua` - Add click handlers

---

### 2. Utils.prependedFunction()
**Source:** `docs/patterns/extensions.md` (lines 45-62)
**Reference Mod:** HirePurchasing

**Current State:** Only use `appendedFunction` and `overwrittenFunction`

**Opportunity:** Run code BEFORE original function executes:
- Pre-validate purchases before shop processes them
- Block invalid operations early with custom error messages
- Intercept vehicle sales before vanilla processing

**Implementation Notes:**
```lua
-- Run BEFORE the original function
ShopController.buyItem = Utils.prependedFunction(ShopController.buyItem,
    function(self, storeItem, ...)
        -- Return false to abort the original function
        if not UsedPlus.canFinance(storeItem) then
            g_gui:showInfoDialog({text = "Cannot finance this item"})
            return false  -- Stops original from running
        end
    end
)
```

**Benefit:** Cleaner interception than overwrittenFunction for validation

**Files to Modify:**
- `src/extensions/ShopConfigScreenExtension.lua` - Pre-validation hooks

---

## Medium Effort Features

### 3. HUD Overlay Framework
**Source:** `docs/advanced/hud-framework.md`
**Reference Mod:** AnimalsDisplay (FS25_Mods_Extracted/AnimalsDisplay/)

**Current State:** UsedPlus is entirely dialog-based

**Opportunity:** Always-visible HUD elements showing:
- Current credit score (corner badge)
- Next payment due date and amount
- Active search status indicator
- Sale listing countdown

**Implementation Complexity:** MEDIUM
- Need to create HUD box manager
- Handle screen resolution scaling
- Implement show/hide toggle (settings)
- Avoid cluttering player's view

**Reference Files to Study:**
- `FS25_Mods_Extracted/AnimalsDisplay/hlHud.lua`
- `FS25_Mods_Extracted/AnimalsDisplay/hlBox.lua`
- `FS25_Mods_Extracted/AnimalsDisplay/hlUtils.lua`

**Benefit:** At-a-glance financial status without opening menus

---

### 4. Animation Patterns for Placeables
**Source:** `docs/advanced/animations.md`
**Reference Mod:** betterLights, BarnWithShelter, AutomaticCarWash

**Current State:** OilServicePoint is completely static

**Opportunity:** Animated service station:
- Garage door opens when player approaches trigger
- Vehicle lift raises during inspection
- Fluid pump animates during fill operations
- Service light changes color based on status

**Implementation Notes:**
```xml
<!-- In OilServicePoint i3d mapping -->
<animatedObject saveId="garageDoor">
    <animation duration="2.0">
        <keyFrame time="0.0" rotation="0 0 0"/>
        <keyFrame time="1.0" rotation="90 0 0"/>
    </animation>
</animatedObject>
```

**Reference Files to Study:**
- `FS25_Mods_Extracted/AutomaticCarWash/` - Gate animations
- `FS25_Mods_Extracted/BarnWithShelter/` - Door animations

**Benefit:** More immersive experience, visual feedback

---

## Lower Priority / Scope Creep Warning

### 5. OptionSlider Pattern
**Source:** `docs/patterns/gui-dialogs.md` (lines 355-370)
**Reference Mod:** (Documented but unreliable per CLAUDE.md)

**WARNING:** Documentation notes sliders are unreliable in FS25. Need thorough testing before use.

**Potential Use:** Visual slider for repair/repaint percentage

**Risk Assessment:** May not work reliably - documented as pitfall

**Recommendation:** Test thoroughly in isolated environment before implementing

---

### 6. Production Patterns for OilServicePoint
**Source:** `docs/advanced/production-patterns.md`
**Reference Mod:** LiquidFertilizer, Dryer

**Current State:** OilServicePoint uses simple storage mechanics

**Opportunity:** Convert to full production system:
- Time-based oil changes (takes X hours)
- Fluid mixing recipes (oil + filter = maintenance)
- Multi-input service packages

**Scope Assessment:** HIGH complexity, significant refactor

**Recommendation:** Not recommended - current implementation is simpler and works well. This would be scope creep.

---

### 7. TextInput Custom Validation
**Source:** `docs/patterns/gui-dialogs.md` (lines 224-288)
**Reference Mod:** Custom implementations

**Current State:** Uses game's built-in `g_gui:showTextInputDialog()`

**Opportunity:** Custom validation with:
- Real-time format checking
- Range validation as user types
- Custom keyboard layouts

**Assessment:** Game's built-in dialog is sufficient for current needs

**Recommendation:** Only implement if specific validation requirements arise

---

## Research Needed

### 8. Vehicle Specializations
**Source:** `docs/advanced/vehicles.md`
**Reference Mod:** 164+ community vehicle mods

**Potential Use Cases:**
- Custom maintenance tracking per vehicle (beyond current approach)
- Visual damage indicators on vehicle model
- Custom fill unit for service fluids

**Current Assessment:** Not needed for UsedPlus finance/marketplace focus

**Future Consideration:** If we expand into vehicle modification features

---

## Implementation Priority Matrix

| Pattern | Effort | Value | Priority | Target Version |
|---------|--------|-------|----------|----------------|
| Quick Buttons | LOW | HIGH | 1 | v2.7.x |
| Utils.prependedFunction | LOW | MEDIUM | 2 | v2.7.x |
| HUD Overlay | MEDIUM | HIGH | 3 | v2.8.0 |
| Animations | MEDIUM | MEDIUM | 4 | v3.0.0 |
| OptionSlider | LOW | UNKNOWN | - | Needs Testing |
| Production Patterns | HIGH | LOW | - | Not Recommended |
| Custom TextInput | LOW | LOW | - | As Needed |
| Vehicle Specs | HIGH | LOW | - | Out of Scope |

---

## How to Use This Document

1. **Before starting a new feature:** Check if a pattern here could help
2. **When planning a version:** Pick 1-2 patterns from priority list
3. **After implementing:** Remove pattern from this document
4. **If pattern doesn't work:** Document why in `docs/pitfalls/what-doesnt-work.md`

---

*Document maintained as part of FS25_UsedPlus development planning*
