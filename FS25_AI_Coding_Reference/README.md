# FS25 AI Coding Reference

**Battle-tested patterns for Farming Simulator 2025 mod development**

Created by the UsedPlus team with Claude AI assistance. This reference was built by analyzing 164+ community mods and validated against a production mod with 83 Lua files and 30+ custom dialogs.

---

## Documentation Stats

| Metric | Value |
|--------|-------|
| Total Documentation Files | **27** |
| Total Lines of Documentation | **9,334** |
| Validated Patterns | **70+** |
| Pitfalls Documented | **17** |
| Source Mods Analyzed | **164+** |

### Validation Coverage

| Category | Files | Validation Status |
|----------|-------|-------------------|
| basics/ | 4 | ✅ 100% validated |
| patterns/ | 12 | ✅ 100% validated |
| advanced/ | 8 | ⚠️ 38% validated (rest are reference) |
| pitfalls/ | 1 | ✅ 100% battle-tested |

### Validation Badges Legend

| Badge | Meaning |
|-------|---------|
| ✅ | **Validated** - Pattern used in production UsedPlus code |
| ⚠️ | **Partial/Caution** - Some aspects validated, use carefully |
| 📚 | **Reference Only** - Extracted from source mods, not validated |

---

## Quick Navigation

### Getting Started (basics/)
| File | Description | When to Use |
|------|-------------|-------------|
| [modDesc.md](basics/modDesc.md) | modDesc.xml structure and examples | Starting a new mod |
| [localization.md](basics/localization.md) | Translation (l10n) patterns | Adding multi-language support |
| [input-bindings.md](basics/input-bindings.md) | Keyboard/controller bindings | Adding hotkeys |
| [lua-patterns.md](basics/lua-patterns.md) | Core Lua patterns & best practices | Writing Lua code |

### Core Patterns (patterns/)
| File | Description | When to Use |
|------|-------------|-------------|
| [gui-dialogs.md](patterns/gui-dialogs.md) | MessageDialog pattern, XML structure | Creating custom dialogs |
| [events.md](patterns/events.md) | Network events for multiplayer | Any multiplayer feature |
| [managers.md](patterns/managers.md) | Singleton manager pattern | Global state management |
| [data-classes.md](patterns/data-classes.md) | Data classes with business logic | Finance, deals, listings |
| [save-load.md](patterns/save-load.md) | Persistence to savegame | Saving mod data |
| [extensions.md](patterns/extensions.md) | Hooking game classes | Modifying game behavior |
| [shop-ui.md](patterns/shop-ui.md) | Shop screen customization | Adding shop buttons/dialogs |
| [async-operations.md](patterns/async-operations.md) | TTL/TTS queues | Delayed operations |
| [message-center.md](patterns/message-center.md) | Game event subscription | Time/economy events |
| [financial-calculations.md](patterns/financial-calculations.md) | Loans, leases, depreciation | Financial systems |
| [physics-override.md](patterns/physics-override.md) | Safe property modification | Game balance mods |
| [mod-api.md](patterns/mod-api.md) | **UsedPlus API for external mods** | Cross-mod integration |

### Advanced Topics (advanced/)
| File | Description | Validation |
|------|-------------|------------|
| [placeables.md](advanced/placeables.md) | Production points, decorations | ⚠️ Partial |
| [triggers.md](advanced/triggers.md) | Trigger zones with timers | ✅ Validated |
| [vehicle-configs.md](advanced/vehicle-configs.md) | Equipment configurations | ✅ Validated |
| [vehicles.md](advanced/vehicles.md) | Specializations, vehicle state | 📚 Reference |
| [hud-framework.md](advanced/hud-framework.md) | Interactive HUD displays | 📚 Reference |
| [animations.md](advanced/animations.md) | Multi-state animations | 📚 Reference |
| [animals.md](advanced/animals.md) | Husbandry integration | 📚 Reference |
| [production-patterns.md](advanced/production-patterns.md) | Multi-input production, pallets | 📚 Reference |

### Pitfalls & Solutions (pitfalls/)
| File | Description | When to Use |
|------|-------------|-------------|
| [what-doesnt-work.md](pitfalls/what-doesnt-work.md) | 17 common mistakes and fixes | Debugging issues |

### Future Development
| File | Description |
|------|-------------|
| [PATTERNS_TO_EXPLORE.md](PATTERNS_TO_EXPLORE.md) | 10 patterns worth exploring for future mods |

---

## Critical Quick Reference

### GUI Coordinate System
**FS25 uses BOTTOM-LEFT origin:**
- Y=0 is at BOTTOM, increases upward
- X=0 is at LEFT, increases rightward

```xml
<!-- 640px container: header at TOP needs HIGH Y value -->
<GuiElement position="0px 600px" size="600px 40px"/>  <!-- Header (top) -->
<GuiElement position="0px 100px" size="600px 500px"/> <!-- Content (middle) -->
<GuiElement position="0px 0px" size="600px 100px"/>   <!-- Footer (bottom) -->
```

### What DOESN'T Work (Top 5)

| Don't Use | Use Instead | Why |
|-----------|-------------|-----|
| `os.time()` | `g_currentMission.time` | Sandboxed Lua |
| `goto` / `::label::` | `if not then` pattern | FS25 = Lua 5.1 |
| `Slider` widgets | Quick buttons or `MultiTextOption` | Unreliable events |
| `DialogElement` base | `MessageDialog` pattern | Rendering issues |
| `g_gui:showYesNoDialog()` | `YesNoDialog.show()` | Method doesn't exist |

### Key Global Objects
```lua
g_currentMission    -- Current game session
g_server            -- Server instance (nil on client)
g_client            -- Client instance
g_farmManager       -- Farm data access
g_storeManager      -- Shop/store items
g_vehicleTypeManager -- Vehicle type registry
g_gui               -- GUI system
g_i18n              -- Localization
g_messageCenter     -- Event pub/sub system
```

### Common MessageTypes
```lua
MessageType.HOUR_CHANGED     -- Every game hour
MessageType.DAY_CHANGED      -- Every game day
MessageType.PERIOD_CHANGED   -- Season change
MessageType.YEAR_CHANGED     -- New year
MessageType.MONEY_CHANGED    -- Farm money changes
```

---

## Source Attribution

This documentation was built by analyzing patterns from these community mods:

**Primary References (Used extensively):**
- FS25_EnhancedLoanSystem - Loan/credit patterns
- FS25_BuyUsedEquipment - Used vehicle marketplace
- FS25_SellVehicles - Vehicle sales
- FS25_TradeIn - Trade-in mechanics

**Secondary References (Specific patterns):**
- FS25_AutomaticCarWash - Trigger patterns
- FS25_AnimalsDisplay - HUD framework
- FS25_LiquidFertilizer - Production patterns
- FS25_betterLights - Animation patterns
- FS25_PlayerTriggers - Player detection

All patterns marked as 📚 Reference Only include source mod citations for verification.

---

## Contributing

Found a pattern that should be documented? Discovered a pitfall the hard way?

1. Check if relevant doc file exists
2. Add pattern with validation status badge
3. Include source mod reference if not from UsedPlus
4. Always include: complete example, common pitfalls

---

## License

This documentation is provided freely to the FS25 modding community. Use it, share it, improve it.

Created with assistance from **Claude AI** (Anthropic) as part of the **UsedPlus** mod development.

---

*Last Updated: 2026-01-17 | UsedPlus v2.6.2*
