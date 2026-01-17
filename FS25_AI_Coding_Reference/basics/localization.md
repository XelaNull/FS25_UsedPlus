# Localization (l10n) Patterns

**Multi-language support for FS25 mods**

Based on patterns from: 164+ working community mods

---

> ✅ **FULLY VALIDATED IN FS25_UsedPlus**
>
> All localization patterns are validated in the UsedPlus codebase with 500+ translation keys.
>
> **UsedPlus Implementation:**
> - `FS25_UsedPlus/translations/translation_en.xml` - English translations
> - `FS25_UsedPlus/translations/translation_de.xml` - German translations
> - `FS25_UsedPlus/modDesc.xml:250` - filenamePrefix pattern
>
> **Validation Details:**
> | Pattern | Status | Notes |
> |---------|--------|-------|
> | External translation files | ✅ | translations/translation_XX.xml |
> | filenamePrefix in modDesc | ✅ | Line 250 |
> | g_i18n:getText() | ✅ | Used throughout all Lua files |
> | g_i18n:formatMoney() | ✅ | UIHelper.lua:formatMoney() |
> | Placeholder formatting (%s, %d) | ✅ | Extensive use |
> | CDATA for descriptions | ✅ | modDesc.xml:18-186 |

---

## Overview

FS25 supports multiple languages through localization files. Two approaches:
1. **Inline l10n** - Translations directly in modDesc.xml (good for few strings)
2. **External files** - Separate XML files per language (preferred for many strings)

---

## External Translation Files

### File Structure
```
MyMod/
├── modDesc.xml
└── translations/
    ├── translation_en.xml
    ├── translation_de.xml
    ├── translation_fr.xml
    └── translation_es.xml
```

### modDesc.xml Reference
```xml
<modDesc descVersion="104">
    <!-- Reference external files with prefix -->
    <l10n filenamePrefix="translations/translation"/>
</modDesc>
```

The game appends `_LANGCODE.xml` to the prefix automatically.

---

## Translation File Format

**File: `translations/translation_en.xml`**

```xml
<?xml version="1.0" encoding="utf-8" standalone="no" ?>
<l10n>
    <texts>
        <!-- General UI -->
        <text name="ui_openMenu" text="Open Menu"/>
        <text name="ui_close" text="Close"/>
        <text name="ui_confirm" text="Confirm"/>
        <text name="ui_cancel" text="Cancel"/>

        <!-- Settings -->
        <text name="setting_enableFeature" text="Enable Feature"/>
        <text name="setting_debugMode" text="Debug Mode"/>

        <!-- Messages -->
        <text name="message_success" text="Operation completed successfully"/>
        <text name="message_error" text="An error occurred: %s"/>

        <!-- With placeholders -->
        <text name="info_progress" text="%d%% completed"/>
        <text name="info_remaining" text="%s remaining"/>
        <text name="info_combined" text="%d%% completed (%s remaining)"/>

        <!-- Store/Shop items -->
        <text name="shopItem_MyBuilding" text="My Building"/>
        <text name="function_MyBuilding" text="Production Facility"/>

        <!-- Input actions -->
        <text name="input_MYMOD_OPEN" text="Open My Mod Menu"/>
    </texts>
</l10n>
```

**File: `translations/translation_de.xml`**

```xml
<?xml version="1.0" encoding="utf-8" standalone="no" ?>
<l10n>
    <texts>
        <text name="ui_openMenu" text="Menü Öffnen"/>
        <text name="ui_close" text="Schließen"/>
        <text name="ui_confirm" text="Bestätigen"/>
        <text name="ui_cancel" text="Abbrechen"/>

        <text name="setting_enableFeature" text="Funktion Aktivieren"/>
        <text name="setting_debugMode" text="Debug-Modus"/>

        <text name="message_success" text="Vorgang erfolgreich abgeschlossen"/>
        <text name="message_error" text="Ein Fehler ist aufgetreten: %s"/>

        <text name="info_progress" text="%d%% abgeschlossen"/>
        <text name="info_remaining" text="%s verbleibend"/>

        <text name="shopItem_MyBuilding" text="Mein Gebäude"/>
        <text name="function_MyBuilding" text="Produktionsanlage"/>

        <text name="input_MYMOD_OPEN" text="Mein Mod-Menü Öffnen"/>
    </texts>
</l10n>
```

---

## Inline Localization (modDesc.xml)

For mods with only a few translated strings:

```xml
<modDesc descVersion="104">
    <l10n>
        <text name="input_MYMOD_ACTION">
            <en>Toggle Menu</en>
            <de>Menü Umschalten</de>
            <fr>Basculer Le Menu</fr>
            <es>Alternar Menú</es>
            <it>Attiva/Disattiva Menu</it>
        </text>

        <text name="setting_enabled">
            <en>Enabled</en>
            <de>Aktiviert</de>
            <fr>Activé</fr>
        </text>
    </l10n>
</modDesc>
```

---

## Using Translations in Lua

### Basic Usage
```lua
-- Get translated text
local text = g_i18n:getText("ui_openMenu")

-- Get text with mod namespace fallback
local text = g_i18n:getText("ui_openMenu", "FS25_MyMod") or "Default Text"
```

### With Placeholders
```lua
-- Single placeholder
local errorMsg = string.format(g_i18n:getText("message_error"), errorDetails)

-- Multiple placeholders
local progress = 75
local remaining = "2 hours"
local text = string.format(g_i18n:getText("info_combined"), progress, remaining)
-- Result: "75% completed (2 hours remaining)"
```

### Formatting Numbers
```lua
-- Currency formatting (uses game's locale settings)
local priceText = g_i18n:formatMoney(50000)  -- "$50,000" or "50.000 €"

-- Number formatting
local numText = g_i18n:formatNumber(12345.67)  -- "12,345.67" or "12.345,67"
```

---

## Placeholder Reference

| Placeholder | Type | Example |
|-------------|------|---------|
| `%s` | String | `"hello"` |
| `%d` | Integer | `42` |
| `%f` | Float | `3.14159` |
| `%.2f` | Float (2 decimals) | `3.14` |
| `%%` | Literal % | `%` |

```lua
-- Examples
string.format("%s items", "10")        -- "10 items"
string.format("%d%%", 75)              -- "75%"
string.format("$%.2f", 1234.567)       -- "$1234.57"
```

---

## Supported Languages

| Code | Language |
|------|----------|
| `en` | English |
| `de` | German |
| `fr` | French |
| `es` | Spanish |
| `it` | Italian |
| `pl` | Polish |
| `ru` | Russian |
| `pt` | Portuguese |
| `cs` | Czech |
| `nl` | Dutch |
| `hu` | Hungarian |
| `ro` | Romanian |
| `tr` | Turkish |
| `jp` | Japanese |
| `kr` | Korean |
| `cn` | Chinese (Simplified) |
| `ct` | Chinese (Traditional) |

---

## Best Practices

### 1. Always Provide English Fallback
English (`en`) is the default fallback language. Always include it.

### 2. Use Consistent Naming
```xml
<!-- Good: Organized by feature -->
<text name="finance_loanAmount" text="Loan Amount"/>
<text name="finance_interestRate" text="Interest Rate"/>
<text name="finance_term" text="Loan Term"/>

<!-- Avoid: Inconsistent naming -->
<text name="amount" text="Loan Amount"/>
<text name="rate_interest" text="Interest Rate"/>
<text name="loanTerm" text="Loan Term"/>
```

### 3. Use Placeholders for Dynamic Content
```xml
<!-- Good: Flexible -->
<text name="info_vehicleCount" text="%d vehicles found"/>

<!-- Avoid: Hardcoded -->
<text name="info_oneVehicle" text="1 vehicle found"/>
<text name="info_twoVehicles" text="2 vehicles found"/>
```

### 4. Special Characters
Use proper XML encoding for special characters:
- `&amp;` for &
- `&lt;` for <
- `&gt;` for >
- `&quot;` for "
- `&apos;` for '

Or use CDATA for complex text:
```xml
<text name="description"><![CDATA[
This text can contain <special> & characters
without XML encoding.
]]></text>
```

---

## Common Pitfalls

### 1. Missing Translation File
- If a language file is missing, English is used as fallback
- Always test with multiple languages enabled

### 2. Wrong Filename
```
translations/translation_en.xml  ✓ Correct
translations/en.xml              ✗ Won't be found
translations/translation-en.xml  ✗ Wrong separator
```

### 3. Placeholder Mismatch
```lua
-- Translation: "Found %d items in %s"
-- WRONG: Wrong order
string.format(text, "barn", 5)  -- Crashes or wrong output

-- CORRECT: Match order
string.format(text, 5, "barn")  -- "Found 5 items in barn"
```

### 4. Missing text Attribute
```xml
<!-- WRONG: Missing text attribute -->
<text name="ui_button">Click Here</text>

<!-- CORRECT: Use text attribute -->
<text name="ui_button" text="Click Here"/>
```
