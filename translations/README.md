# FS25_UsedPlus Translations

This folder contains all localization files for the UsedPlus mod.

## Quick Start

```bash
cd translations/
node translation_sync.js status    # See current state
node translation_sync.js sync      # Sync all languages
node translation_sync.js report    # Detailed breakdown
node translation_sync.js help      # Full documentation
```

## Files

| File | Language | Code |
|------|----------|------|
| `translation_en.xml` | English (source) | EN |
| `translation_de.xml` | German | DE |
| `translation_fr.xml` | French | FR |
| `translation_es.xml` | Spanish | ES |
| `translation_it.xml` | Italian | IT |
| `translation_pl.xml` | Polish | PL |
| `translation_ru.xml` | Russian | RU |
| `translation_br.xml` | Brazilian Portuguese | BR |
| `translation_cz.xml` | Czech | CZ |
| `translation_uk.xml` | Ukrainian | UK |

## Entry Format

Each translation entry uses this format:

```xml
<e k="usedplus_finance_title" v="Vehicle Financing" eh="6efef1bd" />
```

| Attribute | Description |
|-----------|-------------|
| `k` | Key - unique identifier referenced in Lua code |
| `v` | Value - the translated text |
| `eh` | English Hash - 8-character MD5 hash of the English source text |

## How Hash-Based Sync Works

The `eh` (English Hash) attribute tracks when translations become stale:

```
English:  <e k="greeting" v="Hello World" eh="a1b2c3d4"/>
German:   <e k="greeting" v="Hallo Welt" eh="a1b2c3d4"/>   <- Same hash = OK
French:   <e k="greeting" v="Bonjour" eh="99999999"/>     <- Different = STALE!
```

When you change English text:
1. Run `sync` - English hash auto-updates
2. Target hashes stay the same (they reflect what was translated FROM)
3. Hash mismatch = translation is STALE (needs re-translation)

## Translation Sync Tool (v3.2.1)

`translation_sync.js` manages translation synchronization and validation.

### Commands

```bash
node translation_sync.js sync      # Add missing keys, update hashes
node translation_sync.js status    # Quick table overview
node translation_sync.js report    # Detailed lists by language
node translation_sync.js check     # Exit code 1 if missing keys
node translation_sync.js validate  # CI-friendly, minimal output
node translation_sync.js help      # Full documentation
```

### What It Detects

| Symbol | Meaning | Action |
|--------|---------|--------|
| ✓ | Translated | Up to date, no action needed |
| ~ | Stale | English changed, needs re-translation |
| ? | Untranslated | Has `[EN]` prefix or matches English exactly |
| - | Missing | Key not in target file (sync adds it) |
| !! | Duplicate | Same key twice in file - remove one! |
| x | Orphaned | Key in target but not English - safe to delete |
| 💥 | Format Error | Wrong `%s`/`%d` specifiers - WILL CRASH GAME! |
| ⚠ | Empty/Whitespace | Empty value or leading/trailing spaces |

### Example Output

**status command:**
```
Language            | Translated |  Stale  | Untranslated | Missing | Dups | Orphaned
──────────────────────────────────────────────────────────────────────────────────────
German              |       1630 |       4 |           51 |       0 |    0 |        0
French              |       1615 |       4 |           66 |       0 |    0 |        0
Spanish             |       1634 |       4 |           47 |       0 |    0 |        0
```

## Workflow

### Adding New Strings

1. Add the new key to `translation_en.xml`
2. Run `node translation_sync.js sync`
3. Script automatically adds key to all languages with `[EN]` prefix
4. Translators update values and remove prefix

### Updating English Text

1. Modify the value in `translation_en.xml`
2. Run `node translation_sync.js sync`
3. Script shows which translations are now STALE
4. Update translations, hashes auto-update on next sync

### Verifying Translations

```bash
node translation_sync.js status    # Quick check
node translation_sync.js report    # See exactly which keys need work
```

## Translation Guidelines

### Placeholders (CRITICAL!)

Format specifiers MUST be preserved exactly - wrong specifiers crash the game:

| Specifier | Type | Example |
|-----------|------|---------|
| `%s` | String | `"Hello %s"` → `"Hola %s"` |
| `%d` | Integer | `"Count: %d"` → `"Anzahl: %d"` |
| `%.1f` | Decimal (1 place) | `"%.1f hours"` → `"%.1f Stunden"` |
| `%.2f` | Decimal (2 places) | `"$%.2f"` → `"%.2f €"` |

The sync tool validates these automatically and reports 💥 FORMAT ERRORS.

### Context Matters

| English | Context | Correct Translation Approach |
|---------|---------|------------------------------|
| Poor | Credit rating | "Bad" quality, not "impoverished" |
| Fair | Credit rating | "Acceptable/Passable", not "just/equitable" |
| Good | Credit rating | Adjective "good", not adverb "well" |

### Special Characters

XML requires escaping these characters:

| Character | Escape Sequence |
|-----------|-----------------|
| `<` | `&lt;` |
| `>` | `&gt;` |
| `&` | `&amp;` |
| `"` | `&quot;` |

Example: `<e k="key" v="Score &lt;600 is poor" />`

## Requirements

- Node.js (any recent version)
- No external dependencies (uses only Node.js standard library)
