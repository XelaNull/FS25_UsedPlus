# UsedPlus v2.9.6 Feature Plan

**Planned for:** 2026-01-27
**Status:** Planning Document
**Inspired by:** Courseplay patterns analysis

---

## Overview

Three key improvements to bring UsedPlus closer to Courseplay-level polish:

1. **In-Game Help Menu** - Built-in documentation accessible from game UI
2. **Settings Dual-Persistence** - User preferences survive savegame wipes
3. **5 Additional Languages** - Expand from 15 to 20 languages

---

## Feature 1: In-Game Help Menu

### What Courseplay Does

Courseplay has a `HelpMenu.xml` (~13KB) that provides structured in-game documentation accessible through the game's help system. Players can browse feature explanations without leaving the game or consulting external docs.

### Implementation Plan

#### Files to Create

| File | Purpose |
|------|---------|
| `gui/HelpMenu.xml` | Help content structure with categories and pages |
| `src/gui/HelpMenuExtension.lua` | Hook into game's help system |

#### Help Categories (Suggested Structure)

```
UsedPlus Help
├── Getting Started
│   ├── Finance Manager (Shift+F)
│   ├── Your First Loan
│   └── Credit Score Basics
├── Financing
│   ├── Vehicle Financing (1-15 years)
│   ├── Land Financing (1-30 years)
│   ├── Interest Rates & Credit
│   └── Payment Options
├── Leasing
│   ├── Vehicle Leases
│   ├── Land Leases
│   └── Buyout Options
├── Used Marketplace
│   ├── Agent Tiers (Local/Regional/National)
│   ├── Vehicle Inspection
│   ├── Negotiation Tips
│   └── Seller Personalities
├── Maintenance
│   ├── Fluid Levels & Malfunctions
│   ├── OBD Scanner Usage
│   ├── Service Truck Discovery
│   └── Tire Quality Tiers
├── Vehicle DNA
│   ├── Lemons vs Workhorses
│   ├── Legendary Immortality
│   └── Reliability Ceiling
└── Integration
    ├── RVB Compatibility
    ├── UYT Compatibility
    └── Other Mods
```

#### XML Structure Pattern (from Courseplay)

```xml
<HelpMenu>
    <Category name="usedplus_help_finance" iconFilename="$dataS/menu/hud/hud_elements.png" iconUVs="0.875 0.625 0.0625 0.0625">
        <Page name="usedplus_help_finance_basics">
            <Paragraph title="usedplus_help_title_creditScore">
                <Text name="usedplus_help_text_creditScore"/>
            </Paragraph>
            <Paragraph title="usedplus_help_title_interestRates">
                <Text name="usedplus_help_text_interestRates"/>
            </Paragraph>
        </Page>
    </Category>
</HelpMenu>
```

#### Translation Keys Needed

~50-80 new l10n keys for help content:
- Category names (8-10)
- Page titles (15-20)
- Paragraph titles (25-30)
- Help text bodies (25-30)

#### Integration Point

Hook into `InGameMenu` help tab or create custom menu page accessible from Finance Manager.

### Estimated Effort

- XML structure: 1-2 hours
- Lua integration: 1-2 hours
- Content writing: 2-3 hours
- Translation sync: 30 min

**Total: ~6-8 hours**

---

## Feature 2: Settings Dual-Persistence

### What Courseplay Does

Courseplay saves settings in TWO locations:
1. **User Profile** (`modSettings/Courseplay/`) - Global preferences that survive savegame deletion
2. **Savegame Directory** - Map-specific overrides

This means:
- Your preferred default settings persist across all farms
- Individual savegames can have custom configs
- Deleting a savegame doesn't reset your preferences

### Current UsedPlus Behavior

Settings are stored only in the savegame XML, meaning:
- New savegames start with defaults
- Preferences reset when starting new farms
- No global "my preferred setup" option

### Implementation Plan

#### Files to Create/Modify

| File | Change |
|------|--------|
| `src/settings/SettingsPersistence.lua` | NEW - Handles dual-path save/load |
| `src/settings/UsedPlusSettings.lua` | MODIFY - Use new persistence layer |

#### Save Location Structure

```
Documents/My Games/FarmingSimulator2025/
├── modSettings/
│   └── UsedPlus/
│       └── userSettings.xml     ← Global user preferences
└── savegameX/
    └── usedplus.xml             ← Savegame-specific (existing)
```

#### userSettings.xml Format

```xml
<?xml version="1.0" encoding="utf-8"?>
<UsedPlusUserSettings version="1">
    <!-- These are user's preferred DEFAULTS for new savegames -->
    <Defaults>
        <overrideShopBuy value="true"/>
        <overrideRvbRepair value="true"/>
        <paintCostMultiplier value="1.0"/>
        <enableFinancing value="true"/>
        <enableLeasing value="true"/>
        <enableLandFinance value="true"/>
        <enableLandLease value="true"/>
        <malfunctionFrequency value="1.0"/>
        <difficultyPreset value="normal"/>
    </Defaults>

    <!-- Optional: Per-savegame overrides remembered -->
    <SavegameOverrides>
        <savegame1 difficultyPreset="hardcore"/>
        <savegame3 malfunctionFrequency="0.5"/>
    </SavegameOverrides>
</UsedPlusUserSettings>
```

#### Load Priority Logic

```lua
function SettingsPersistence.loadSettings(savegameId)
    -- 1. Load user defaults from modSettings/UsedPlus/
    local userDefaults = self:loadUserDefaults()

    -- 2. Load savegame-specific settings (if exists)
    local savegameSettings = self:loadSavegameSettings(savegameId)

    -- 3. Merge: savegame overrides user defaults
    return self:mergeSettings(userDefaults, savegameSettings)
end
```

#### Settings Menu Changes

Add toggle in settings menu:
- **"Save as Default"** button - Saves current settings to userSettings.xml
- **"Reset to Defaults"** button - Loads from userSettings.xml (or built-in defaults)

#### Migration Path

- Existing savegames continue working (load from savegame XML)
- First run with new system creates userSettings.xml from built-in defaults
- User can then customize and save their preferences

### Estimated Effort

- SettingsPersistence.lua: 2-3 hours
- UsedPlusSettings.lua modifications: 1-2 hours
- Settings menu UI changes: 1 hour
- Testing all paths: 1 hour

**Total: ~5-7 hours**

---

## Feature 3: Five Additional Languages

### Target Languages

Based on Courseplay's language support and FS25 community demographics:

| Language | Code | Priority | Notes |
|----------|------|----------|-------|
| **Korean** | kr | High | Large FS community in Korea |
| **Chinese (Simplified)** | ct | High | Massive potential audience |
| **Swedish** | sv | Medium | Nordic farming community |
| **Finnish** | fi | Medium | Strong FS player base |
| **Romanian** | ro | Medium | Active modding community |

### Alternative Options (if above aren't feasible)

- Danish (da)
- Norwegian (no)
- Indonesian (id)
- Vietnamese (vi)

### Implementation Plan

#### Files to Create

| File | Keys |
|------|------|
| `translations/translation_kr.xml` | 1,944 |
| `translations/translation_ct.xml` | 1,944 |
| `translations/translation_sv.xml` | 1,944 |
| `translations/translation_fi.xml` | 1,944 |
| `translations/translation_ro.xml` | 1,944 |

#### Process

1. Update `translation_sync.js` with new language codes
2. Create base XML files with English fallback
3. Run sync to populate all keys
4. Spawn 5 parallel translation agents
5. Run final sync to verify hash updates

#### Translation Quality Notes

For CJK languages (Korean, Chinese):
- Use formal/polite forms appropriate for software UI
- Technical terms may need adaptation (some gaming terms differ)
- Test character rendering in-game (font support)

For European languages:
- Generally straightforward, similar to existing translations
- Some farming terminology may be region-specific

### Estimated Effort

- Sync script updates: 15 min
- File creation: 15 min
- Translation agents: Run in parallel (~30-60 min each)
- Verification: 30 min

**Total: ~2-3 hours (mostly parallel agent time)**

---

## Feature 0: Admin Control Panel Testing (PRIORITY)

### Background

The `upAdminCP` console command and Admin Control Panel were implemented in v2.9.5 but haven't been thoroughly tested in-game yet. Before adding new features, we need to verify this critical testing tool works correctly.

### Test Checklist

#### Prerequisites
- [ ] Fresh mod build completed
- [ ] Game launched with UsedPlus v2.9.5
- [ ] Savegame loaded with at least one owned vehicle

#### Console Command Tests
| Test | Expected Result | Status |
|------|-----------------|--------|
| Type `upAdminCP` while on foot | Error: "Must be in a vehicle" | [ ] |
| Type `upAdminCP` in vehicle (non-admin MP) | Error: "Only administrators can use" | [ ] |
| Type `upAdminCP` in vehicle (admin/SP) | Panel opens | [ ] |

#### Tab Navigation Tests
| Test | Expected Result | Status |
|------|-----------------|--------|
| Panel opens to Malfunctions tab | Tab 1 highlighted, content visible | [ ] |
| Click each tab (1-5) | Tab highlights, content switches | [ ] |
| Tab colors change correctly | Active = blue, Inactive = dark | [ ] |

#### Tab 1: Malfunctions Tests
| Button | Expected Result | Status |
|--------|-----------------|--------|
| **Stall** | Engine stalls, status bar confirms | [ ] |
| **Misfire** | Engine misfires, rough running | [ ] |
| **Overheat** | Temperature rises toward threshold | [ ] |
| **Runaway** | Speed 150%, brakes reduced | [ ] |
| **Seizure** | Permanent engine failure | [ ] |
| **Cutout** | Electrical systems fail temporarily | [ ] |
| **Surge L/R** | Hydraulic steering surge | [ ] |
| **Flat L/R** | Tire failure with steering pull | [ ] |
| **Reset Cooldown** | Cooldown cleared, can re-trigger | [ ] |
| **Malf Info** | Shows malfunction state in console | [ ] |
| **Fix All** | All malfunctions cleared | [ ] |

#### Tab 2: Spawning Tests
| Button | Expected Result | Status |
|--------|-----------------|--------|
| **Spawn OBD** | FieldServiceKit appears at player | [ ] |
| **Spawn Truck** | ServiceTruck spawns nearby | [ ] |
| **Spawn Parts** | SparePartsPallet spawns | [ ] |
| **Trigger Discovery** | Discovery dialog appears | [ ] |
| **Reset Discovery** | Discovery state cleared | [ ] |
| **Discovery Status** | Shows prerequisites in console | [ ] |
| **Paint Pristine** | Vehicle 0% damage, 0% wear | [ ] |
| **Paint Worn** | Vehicle 30% wear | [ ] |
| **Paint Beaten** | Vehicle 60% damage, 50% wear | [ ] |
| **Paint Destroyed** | Vehicle 95% damage | [ ] |

#### Tab 3: Finance Tests
| Button | Expected Result | Status |
|--------|-----------------|--------|
| **+$10k** | Farm money increases by $10,000 | [ ] |
| **+$100k** | Farm money increases by $100,000 | [ ] |
| **+$1M** | Farm money increases by $1,000,000 | [ ] |
| **Set $0** | Farm money set to exactly $0 | [ ] |
| **Score 850** | Credit score set to 850 (Excellent) | [ ] |
| **Score 700** | Credit score set to 700 (Good) | [ ] |
| **Score 550** | Credit score set to 550 (Fair) | [ ] |
| **Score 400** | Credit score set to 400 (Poor) | [ ] |
| **Score 300** | Credit score set to 300 (Very Poor) | [ ] |
| **List Deals** | Shows active deals in console | [ ] |
| **Payoff All** | All deals paid off | [ ] |
| **Create Loan** | Test $50k loan created | [ ] |
| **Missed Payment** | Payment missed, credit impacted | [ ] |

#### Tab 4: Dialogs Tests
| Button | Expected Dialog | Status |
|--------|-----------------|--------|
| **Take Loan** | TakeLoanDialog opens | [ ] |
| **Loan Approved** | LoanApprovedDialog with mock data | [ ] |
| **Credit Report** | CreditReportDialog opens | [ ] |
| **Payment History** | PaymentHistoryDialog (needs deal) | [ ] |
| **Repossession** | RepossessionDialog with mock data | [ ] |
| **Used Search** | UsedSearchDialog opens | [ ] |
| **Purchase** | UnifiedPurchaseDialog (current vehicle) | [ ] |
| **Negotiation** | NegotiationDialog with mock listing | [ ] |
| **Seller Response** | SellerResponseDialog | [ ] |
| **OBD Scanner** | FieldServiceKitDialog opens | [ ] |
| **Inspection** | InspectionReportDialog (current vehicle) | [ ] |
| **Lease End** | LeaseEndDialog with mock data | [ ] |
| **Lease Renewal** | LeaseRenewalDialog with mock data | [ ] |

#### Tab 5: State Tests
| Button | Expected Result | Status |
|--------|-----------------|--------|
| **Toggle DEBUG** | UsedPlus.DEBUG flips, button text updates | [ ] |
| **Rel 100%** | All systems set to 100% reliability | [ ] |
| **Rel 50%** | All systems set to 50% reliability | [ ] |
| **Rel 10%** | All systems set to 10% reliability | [ ] |
| **Reset Hours** | Operating hours set to 0 | [ ] |
| **Add 1000 Hours** | 1000 hours added to vehicle | [ ] |
| **DNA: Desperate** | Next search forces desperate seller | [ ] |
| **DNA: Reasonable** | Next search forces reasonable seller | [ ] |
| **DNA: Immovable** | Next search forces immovable seller | [ ] |
| **Next Vehicle** | Teleport to next owned vehicle | [ ] |
| **Prev Vehicle** | Teleport to previous owned vehicle | [ ] |

#### Status Bar Tests
| Test | Expected Result | Status |
|------|-----------------|--------|
| Click any button | Status bar shows action feedback | [ ] |
| Wait 5 seconds | Status bar auto-clears | [ ] |
| Rapid button clicks | Status updates correctly each time | [ ] |

#### Edge Case Tests
| Test | Expected Result | Status |
|------|-----------------|--------|
| Open panel, exit vehicle | Panel closes gracefully | [ ] |
| Open panel, vehicle destroyed | Handles gracefully | [ ] |
| Click malfunction with no vehicle context | Error message, no crash | [ ] |
| Spawn items with no valid spawn point | Error message, no crash | [ ] |

### Bug Tracking

| Bug # | Description | Severity | Fix Status |
|-------|-------------|----------|------------|
| | | | |
| | | | |
| | | | |

### Notes

- Test in SINGLE PLAYER first
- Then test in MULTIPLAYER (as admin and non-admin)
- Document any crashes with log.txt excerpts
- Note any buttons that don't provide feedback

---

## Implementation Order (Recommended)

### Session 0: Admin Panel Testing (FIRST PRIORITY)
1. Build fresh mod ZIP
2. Launch game, load savegame with vehicles
3. Run through ALL test checklists above
4. Document any bugs found
5. Fix critical bugs before proceeding

### Session 1: Languages (Quick Win)
1. Add 5 new language files
2. Run translation agents in parallel
3. While agents run, start Help Menu planning

### Session 2: Help Menu
1. Create HelpMenu.xml structure
2. Write help content (can reference README)
3. Create HelpMenuExtension.lua
4. Add translation keys
5. Test integration

### Session 3: Settings Persistence
1. Create SettingsPersistence.lua
2. Modify UsedPlusSettings.lua
3. Add UI elements to settings menu
4. Test all save/load scenarios
5. Verify migration from existing savegames

---

## Success Criteria

### Help Menu
- [ ] Help accessible from game menu
- [ ] All major features documented
- [ ] Content readable and helpful
- [ ] Translations synced

### Settings Persistence
- [ ] Settings survive new savegame creation
- [ ] Per-savegame overrides work
- [ ] "Save as Default" button functional
- [ ] Existing savegames migrate cleanly

### Languages
- [ ] 5 new translation files created
- [ ] All 1,944 keys translated
- [ ] No broken format specifiers
- [ ] Character encoding correct

---

## Version Target

**v2.9.6** with:
- 20 supported languages
- In-game help system
- Persistent user preferences

---

*Plan created: 2026-01-26*
*Author: Claude & Samantha*
