# modDesc.xml Structure

**The entry point for every FS25 mod**

Based on patterns from: 164+ working community mods

---

## Related Resources

> 📖 For raw modDesc examples, see the [FS25-lua-scripting repo](https://github.com/Dukefarming/FS25-lua-scripting) - includes `modDesc.xml` template

**Official Documentation:** [GIANTS Developer Network](https://gdn.giants-software.com/documentation.php) - Modding Tutorials

---

> ✅ **FULLY VALIDATED IN FS25_UsedPlus**
>
> All modDesc.xml patterns in this document are validated by the UsedPlus codebase.
>
> **UsedPlus Implementation:**
> - `FS25_UsedPlus/modDesc.xml` - Complete reference implementation
> - Version 2.6.0 with all documented patterns in active use
>
> **Validation Details:**
> | Pattern | Status | UsedPlus Lines |
> |---------|--------|----------------|
> | descVersion="104" | ✅ | Line 2 |
> | multiplayer supported | ✅ | Line 244 |
> | l10n filenamePrefix | ✅ | Line 250 |
> | actions/inputBinding | ✅ | Lines 258-282 |
> | extraSourceFiles | ✅ | Lines 301-408 |
> | specializations | ✅ | Lines 411-413 |
> | vehicleTypes | ✅ | Lines 418-422 |
> | placeableSpecializations | ✅ | Lines 425-427 |
> | storeItems | ✅ | Lines 437-440 |

---

## Overview

Every mod must have a `modDesc.xml` file at its root. This file defines:
- Mod metadata (name, version, author)
- Script files to load
- Store items (vehicles, placeables)
- Input actions and keybindings
- Localization (translations)
- Multiplayer compatibility

---

## Minimal modDesc.xml (Script-only Mod)

```xml
<?xml version="1.0" encoding="utf-8" standalone="no" ?>
<modDesc descVersion="104">
    <author>YourName</author>
    <version>1.0.0.0</version>

    <title>
        <en>Mod Name</en>
        <de>Mod-Name</de>
    </title>

    <description>
        <en><![CDATA[
Description here.

Changelog:
v1.0.0.0 - Initial release
        ]]></en>
    </description>

    <iconFilename>icon.dds</iconFilename>
    <multiplayer supported="true"/>

    <extraSourceFiles>
        <sourceFile filename="scripts/main.lua"/>
    </extraSourceFiles>
</modDesc>
```

**Key Points:**
- `descVersion="104"` is the current schema version for FS25
- Version format: `MAJOR.MINOR.PATCH.BUILD`
- `CDATA` blocks for descriptions preserve formatting
- `multiplayer supported="true"` for MP compatibility

---

## modDesc.xml with Localization

```xml
<modDesc descVersion="104">
    <!-- ... basic info ... -->

    <!-- Method 1: Inline l10n -->
    <l10n>
        <text name="setting_myOption">
            <en>My Option</en>
            <de>Meine Option</de>
            <fr>Mon Option</fr>
        </text>
    </l10n>

    <!-- Method 2: External l10n files (preferred for many strings) -->
    <l10n filenamePrefix="translations/translation"/>

    <extraSourceFiles>
        <sourceFile filename="scripts/main.lua"/>
    </extraSourceFiles>
</modDesc>
```

---

## modDesc.xml with Store Items

```xml
<modDesc descVersion="104">
    <!-- ... basic info ... -->

    <l10n>
        <text name="shopItem_MyPlaceable">
            <en>My Placeable Name</en>
            <de>Mein Platzierbarer Name</de>
        </text>
        <text name="function_MyPlaceable">
            <en>Production Facility</en>
            <de>Produktionsanlage</de>
        </text>
    </l10n>

    <storeItems>
        <storeItem xmlFilename="myPlaceable.xml"/>
        <storeItem xmlFilename="anotherPlaceable.xml"/>
    </storeItems>
</modDesc>
```

---

## modDesc.xml with Input Actions

```xml
<modDesc descVersion="104">
    <!-- ... basic info ... -->

    <actions>
        <action name="MYMOD_TOGGLE_MENU" category="ONFOOT VEHICLE"
                axisType="HALF" ignoreComboMask="false">
            <binding device="KB_MOUSE_DEFAULT" input="KEY_lctrl KEY_u"/>
        </action>
    </actions>

    <extraSourceFiles>
        <sourceFile filename="scripts/main.lua"/>
    </extraSourceFiles>
</modDesc>
```

**Action Categories:**
- `ONFOOT` - Only when player is on foot
- `VEHICLE` - Only when in vehicle
- `ONFOOT VEHICLE` - Available in both contexts
- `MENU` - Menu contexts

---

## Complete Example (Full-Featured Mod)

```xml
<?xml version="1.0" encoding="utf-8" standalone="no" ?>
<modDesc descVersion="104">
    <author>YourName</author>
    <version>1.0.0.0</version>

    <title>
        <en>Full Featured Mod</en>
        <de>Voll ausgestatteter Mod</de>
    </title>

    <description>
        <en><![CDATA[
A complete example mod with all features.

Features:
- Custom keybindings
- Localization support
- Multiplayer compatible

Changelog:
v1.0.0.0 - Initial release
        ]]></en>
    </description>

    <iconFilename>icon.dds</iconFilename>
    <multiplayer supported="true"/>

    <!-- External translation files -->
    <l10n filenamePrefix="translations/translation"/>

    <!-- Input actions -->
    <actions>
        <action name="MYMOD_OPEN" category="ONFOOT VEHICLE"
                axisType="HALF" ignoreComboMask="false">
            <binding device="KB_MOUSE_DEFAULT" input="KEY_lctrl KEY_m"/>
        </action>
    </actions>

    <!-- Lua scripts (order matters!) -->
    <extraSourceFiles>
        <sourceFile filename="scripts/events/MyEvent.lua"/>
        <sourceFile filename="scripts/MyManager.lua"/>
        <sourceFile filename="scripts/main.lua"/>
    </extraSourceFiles>

    <!-- Store items (optional) -->
    <storeItems>
        <storeItem xmlFilename="placeables/myBuilding.xml"/>
    </storeItems>
</modDesc>
```

---

## Script Loading Order

**CRITICAL:** Scripts are loaded in the order listed. Events and utilities must be defined BEFORE they are used!

```xml
<!-- WRONG: main.lua tries to use MyEvent before it's defined -->
<extraSourceFiles>
    <sourceFile filename="main.lua"/>
    <sourceFile filename="MyEvent.lua"/>
</extraSourceFiles>

<!-- CORRECT: Define dependencies first -->
<extraSourceFiles>
    <sourceFile filename="MyEvent.lua"/>
    <sourceFile filename="main.lua"/>
</extraSourceFiles>
```

**Recommended Order:**
1. Event classes
2. Data classes
3. Utility functions
4. Managers
5. GUI classes
6. Extensions/hooks
7. Main entry point

---

## Common Attributes Reference

| Attribute | Values | Description |
|-----------|--------|-------------|
| `descVersion` | `104` | FS25 schema version |
| `multiplayer supported` | `true`/`false` | MP compatibility |
| `axisType` | `HALF`/`FULL` | Input axis type |
| `ignoreComboMask` | `true`/`false` | Allow in combo |
| `category` | `ONFOOT`/`VEHICLE`/`MENU` | Input context |

---

## Common Pitfalls

### 1. Wrong descVersion
- FS25 uses `descVersion="104"` (some mods use 96, but 104 is current)

### 2. Missing Icon
- Always include `icon.dds` (256x256 DDS file)
- Without it, mod won't display properly in mod selection

### 3. Script Order
- Events must be defined before they're used
- Check log.txt for "attempt to index a nil value" errors

### 4. Missing Multiplayer Tag
- Add `<multiplayer supported="true"/>` for MP games
- Without it, mod may not load in MP sessions
