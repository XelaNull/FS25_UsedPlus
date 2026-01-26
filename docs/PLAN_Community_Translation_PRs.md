# FS25 Community Translation Contribution Plan

**Goal:** Submit pull requests to major FS25 mods to improve their localization
**Status:** Planning Document
**Created:** 2026-01-26

## Target Repositories

| Mod | Repository | Entries | Languages | Opportunity |
|-----|------------|---------|-----------|-------------|
| **Courseplay** | github.com/Courseplay/Courseplay_FS25 | 566 | 26 (many incomplete) | Fill gaps |
| **RVB** | (TBD - find repo) | 210 | 14 | Add 12 missing languages |
| **UYT** | (TBD - find repo) | 7 | 3 | Add 20+ languages (easy!) |

---

## Executive Summary

Courseplay has significant translation gaps that we can fill using AI translation. This is a win-win:
- **For Courseplay:** Better localization for their global user base
- **For Us:** Community goodwill, exposure, and establishing ourselves as a quality-focused mod team
- **For Players:** Indonesian, Vietnamese, and other language speakers get a usable mod

---

## The Opportunity

### Current State Analysis

| Language | Entries | Untranslated | % Missing | Priority |
|----------|---------|--------------|-----------|----------|
| Indonesian (id) | 566 | 420 | **74%** | 🔴 CRITICAL |
| Vietnamese (vi) | 566 | 420 | **74%** | 🔴 CRITICAL |
| French Canadian (fc) | 566 | 279 | **49%** | 🟠 HIGH |
| Finnish (fi) | 566 | 279 | **49%** | 🟠 HIGH |
| Norwegian (no) | 566 | 279 | **49%** | 🟠 HIGH |
| Romanian (ro) | 566 | 279 | **49%** | 🟠 HIGH |
| Dutch (nl) | 566 | 197 | **35%** | 🟡 MEDIUM |
| Japanese (jp) | 566 | 191 | **34%** | 🟡 MEDIUM |
| Danish (da) | 566 | 94 | **17%** | 🟢 LOW |
| Chinese Traditional (ct) | 566 | 85 | **15%** | 🟢 LOW |
| Swedish (sv) | 566 | 82 | **14%** | 🟢 LOW |

### Additional Issues Found

1. **Typos in multiple files:**
   - "to far away" → "too far away" (appears in ~10 language files)
   - "wich results" → "which results" (English source)

2. **Stale URL:**
   - Japanese file references FS22 GitHub instead of FS25

3. **Missing entry:**
   - All files missing 1 key that exists in English

---

## Contribution Strategy

### Phase 1: Low-Risk Quick Wins (Do First)

**Objective:** Build trust with maintainers through small, obviously-correct changes

| Change | Files Affected | Risk | Value |
|--------|----------------|------|-------|
| Fix "wich" → "which" typo | translation_en.xml | Very Low | Medium |
| Fix "to far away" → "too far away" | ~10 files | Low | Medium |
| Fix FS22 → FS25 URL in Japanese | translation_jp.xml | Very Low | Low |

**PR Title:** `fix: Correct typos in English source and propagated translations`

### Phase 2: Gap Filling - Critical Languages

**Objective:** Provide translations for nearly-empty language files

| Language | Entries to Add | Approach |
|----------|----------------|----------|
| Indonesian (id) | 420 | AI translate all missing |
| Vietnamese (vi) | 420 | AI translate all missing |

**PR Title:** `feat(i18n): Add Indonesian and Vietnamese translations`

**Rationale for separate PR:**
- Larger change = more review needed
- Keeps typo fixes unblocked
- Shows our translation quality before larger contributions

### Phase 3: Gap Filling - High Priority Languages

| Language | Entries to Add |
|----------|----------------|
| French Canadian (fc) | 279 |
| Finnish (fi) | 279 |
| Norwegian (no) | 279 |
| Romanian (ro) | 279 |

**PR Title:** `feat(i18n): Complete French Canadian, Finnish, Norwegian, Romanian translations`

### Phase 4: Gap Filling - Medium Priority Languages

| Language | Entries to Add |
|----------|----------------|
| Dutch (nl) | 197 |
| Japanese (jp) | 191 |
| Danish (da) | 94 |
| Chinese Traditional (ct) | 85 |
| Swedish (sv) | 82 |

**PR Title:** `feat(i18n): Fill remaining translation gaps for nl, jp, da, ct, sv`

---

## Technical Implementation

### Step 1: Fork and Clone Courseplay

```bash
# Fork on GitHub first, then:
cd C:\github
git clone https://github.com/XelaNull/Courseplay_FS25.git
cd Courseplay_FS25
git remote add upstream https://github.com/Courseplay/Courseplay_FS25.git
```

### Step 2: Create Analysis Script

We already created `tools/courseplay_translation_helper.js` which:
- Parses their XML format
- Identifies untranslated entries
- Exports entries for AI translation
- Detects typos

### Step 3: Export Untranslated Entries

```bash
# Export untranslated entries for each language
node courseplay_translation_helper.js --export translations id
node courseplay_translation_helper.js --export translations vi
# ... etc
```

Output: `courseplay_untranslated_id.json`, `courseplay_untranslated_vi.json`, etc.

### Step 4: AI Translation Process

For each language file:

1. **Load the JSON export**
2. **Spawn translation agent** with context:
   ```
   Translate these Courseplay (Farming Simulator 25 mod) UI strings
   from English to [LANGUAGE].

   Context: Courseplay is an AI helper mod for autonomous vehicle control.
   Key terms:
   - "course" = driving path/route
   - "fieldwork" = agricultural field operations
   - "unloader" = vehicle that receives harvested crops
   - "headland" = edge of field where vehicle turns

   Maintain:
   - %s, %d, %.1f placeholders exactly
   - Technical accuracy
   - Concise UI-appropriate length
   ```

3. **Generate translated entries**
4. **Write back to XML file**

### Step 5: XML Writer Script

Create `tools/courseplay_translation_writer.js`:

```javascript
/**
 * Writes translated entries back to Courseplay XML format
 *
 * Input: JSON with translations
 * Output: Updated XML file with translations inserted
 */
function writeTranslations(xmlPath, translations) {
    let content = fs.readFileSync(xmlPath, 'utf8');

    for (const [key, value] of Object.entries(translations)) {
        // Find: <text name="KEY" text="ENGLISH"/>
        // Replace with: <text name="KEY" text="TRANSLATED"/>
        const regex = new RegExp(
            `(<text\\s+name="${key}"\\s+text=")([^"]*)("/>)`,
            'g'
        );
        content = content.replace(regex, `$1${escapeXml(value)}$3`);
    }

    fs.writeFileSync(xmlPath, content, 'utf8');
}
```

### Step 6: Validation

Before submitting PR:

1. **XML validity check:**
   ```bash
   xmllint --noout translations/*.xml
   ```

2. **Placeholder preservation check:**
   - Ensure all %s, %d, %.1f are preserved
   - Count should match English

3. **Length check:**
   - Translations shouldn't be dramatically longer (UI overflow)
   - Flag any >150% length increase

4. **Manual spot check:**
   - Review 10 random entries per language
   - Verify technical terms are correct

---

## PR Content Templates

### PR #1: Typo Fixes

**Title:** `fix(i18n): Correct typos in source and translated files`

**Description:**
```markdown
## Summary
Fixes minor typos found in translation files.

## Changes
- English source: "wich" → "which" in CP_vehicle_setting_useJps_tooltip
- Multiple languages: "to far away" → "too far away" in error messages
- Japanese: Updated GitHub URL from FS22 to FS25

## Testing
- Verified XML validity
- No functional changes

## Notes
Found these while analyzing translation coverage for a community contribution.
Happy to help with larger translation efforts if maintainers are interested.
```

### PR #2: Indonesian & Vietnamese

**Title:** `feat(i18n): Add Indonesian and Vietnamese translations (840 entries)`

**Description:**
```markdown
## Summary
Adds translations for 420 previously-untranslated entries in Indonesian and Vietnamese.

## Background
These languages were ~74% untranslated. We used AI-assisted translation with
manual review to fill the gaps.

## Translation Approach
- AI translation using Claude with agricultural/farming context
- Preserved all placeholders (%s, %d, etc.)
- Maintained consistent terminology throughout
- Technical terms verified against Indonesian/Vietnamese farming communities

## Changes
- `translation_id.xml`: 420 entries translated
- `translation_vi.xml`: 420 entries translated

## Validation
- [x] XML validity verified
- [x] All placeholders preserved
- [x] Length within reasonable bounds
- [x] Spot-checked 20 entries per language

## Notes
We're the team behind UsedPlus (Finance & Marketplace mod). We built translation
infrastructure for our mod and wanted to contribute back to the community.

If there are issues with any translations, please let us know - we're happy to
iterate and improve.
```

---

## File Changes Summary

### Phase 1 (Typos)
| File | Change |
|------|--------|
| translation_en.xml | Fix "wich" → "which" |
| translation_fc.xml | Fix "to far away" (3 occurrences) |
| translation_fi.xml | Fix "to far away" (3 occurrences) |
| translation_no.xml | Fix "to far away" (3 occurrences) |
| translation_ro.xml | Fix "to far away" (3 occurrences) |
| translation_nl.xml | Fix "to far away" (3 occurrences) |
| translation_jp.xml | Fix "to far away" (3 occurrences) + URL |
| translation_da.xml | Fix "to far away" (1 occurrence) |
| translation_ct.xml | Fix "to far away" (1 occurrence) |
| translation_sv.xml | Fix "to far away" (1 occurrence) |

### Phase 2 (ID/VI)
| File | Entries Changed |
|------|-----------------|
| translation_id.xml | 420 translations added |
| translation_vi.xml | 420 translations added |

### Phase 3 (FC/FI/NO/RO)
| File | Entries Changed |
|------|-----------------|
| translation_fc.xml | 279 translations added |
| translation_fi.xml | 279 translations added |
| translation_no.xml | 279 translations added |
| translation_ro.xml | 279 translations added |

### Phase 4 (NL/JP/DA/CT/SV)
| File | Entries Changed |
|------|-----------------|
| translation_nl.xml | 197 translations added |
| translation_jp.xml | 191 translations added |
| translation_da.xml | 94 translations added |
| translation_ct.xml | 85 translations added |
| translation_sv.xml | 82 translations added |

---

## Timeline

### Session 1: Setup & Phase 1 (~1-2 hours)
1. Fork Courseplay repository
2. Create branch for typo fixes
3. Make typo corrections
4. Submit PR #1
5. Wait for maintainer response

### Session 2: Phase 2 (~2-3 hours)
1. Export Indonesian untranslated entries
2. Export Vietnamese untranslated entries
3. Run translation agents (parallel)
4. Validate translations
5. Write back to XML
6. Submit PR #2

### Session 3: Phase 3 (~2-3 hours)
1. Export FC/FI/NO/RO entries
2. Run 4 translation agents (parallel)
3. Validate and write back
4. Submit PR #3

### Session 4: Phase 4 (~2-3 hours)
1. Export NL/JP/DA/CT/SV entries
2. Run 5 translation agents (parallel)
3. Validate and write back
4. Submit PR #4

---

## Risk Mitigation

### Risk: Maintainers reject AI translations
**Mitigation:**
- Start with typo PR to build trust
- Be transparent about AI use
- Offer to iterate on feedback
- Emphasize "better than nothing" for 74% untranslated languages

### Risk: Translation quality issues
**Mitigation:**
- Provide context to AI about Courseplay terminology
- Validate placeholder preservation
- Spot-check entries
- Invite native speakers to review

### Risk: Stepping on community translators' toes
**Mitigation:**
- Only fill MISSING entries, never override existing
- Credit approach in PR description
- Offer to remove/adjust if someone wants to take over

### Risk: Merge conflicts if Courseplay updates
**Mitigation:**
- Work on one language batch at a time
- Keep PRs small and focused
- Rebase before submitting

---

## Success Metrics

| Metric | Target |
|--------|--------|
| PRs merged | 4 of 4 |
| Entries translated | ~2,100 total |
| Languages improved | 11 |
| Community response | Positive/neutral |

---

## Tools Created

| Tool | Purpose | Location |
|------|---------|----------|
| `courseplay_translation_helper.js` | Analyze & export | `tools/` |
| `courseplay_translation_writer.js` | Write back XML | `tools/` (to create) |

---

## Open Questions

1. **Should we contact maintainers first?**
   - Pro: Get buy-in before doing work
   - Con: They might say "we'll handle it" then not
   - Recommendation: Submit typo PR first, gauge response

2. **Should we do all languages or focus on worst?**
   - Recommendation: Start with ID/VI (most impact), expand based on reception

3. **Should we include this in our README?**
   - "UsedPlus team contributed translations to Courseplay"
   - Wait until PRs are merged

---

## Appendix: Courseplay Terminology

Key terms for translation context:

| English | Meaning |
|---------|---------|
| Course | Driving path/route for AI vehicle |
| Fieldwork | Agricultural operations on a field |
| Headland | Edge of field where vehicle turns |
| Unloader | Vehicle receiving harvested crops |
| Pathfinding | Route calculation algorithm |
| Waypoint | Point on a course |
| Giants | The game developer (GIANTS Software) |
| Silo | Storage structure for crops |
| Bunker silo | Drive-over silo for silage |
| PTO | Power Take-Off (implement power) |

---

---

# PART 2: RVB (Real Vehicle Breakdowns) Translation Contribution

## Overview

RVB has solid translations for 14 languages but is missing 12 languages that Courseplay supports.
This is an opportunity to add NEW language files rather than fixing gaps.

## Current State

| Metric | Value |
|--------|-------|
| **Total entries** | 210 |
| **Current languages** | 14 (BR, CZ, DE, EN, ES, FR, HU, IT, NL, PL, PT, RU, TR, UK) |
| **Translation quality** | ✅ Excellent (fully translated, not placeholders) |
| **XML format** | `<e k="KEY" v="VALUE"/>` (same as UsedPlus!) |

## Languages to Add

| Language | Code | Priority | Notes |
|----------|------|----------|-------|
| Japanese | jp | HIGH | Large FS community |
| Korean | kr | HIGH | Growing market |
| Chinese Simplified | cs | HIGH | Huge potential audience |
| Chinese Traditional | ct | MEDIUM | Taiwan/HK market |
| Indonesian | id | MEDIUM | Large SEA community |
| Vietnamese | vi | MEDIUM | Growing SEA market |
| Danish | da | LOW | Nordic community |
| Swedish | sv | LOW | Nordic community |
| Finnish | fi | LOW | Nordic community |
| Norwegian | no | LOW | Nordic community |
| Romanian | ro | LOW | Active modding community |
| French Canadian | fc | LOW | Could copy French with minor tweaks |

**Total new entries:** 12 languages × 210 entries = **2,520 translations**

## Implementation Plan

### Step 1: Find RVB Repository
- Search GitHub for "Real Vehicle Breakdowns FS25"
- Check if they accept PRs
- Review their contribution guidelines

### Step 2: Create Language Files
```bash
# For each new language, create l10n_XX.xml based on l10n_en.xml structure
cp l10n_en.xml l10n_jp.xml
# Then translate all entries
```

### Step 3: Translation Process
For each language:
1. Export English entries to JSON
2. Run translation agent with RVB context:
   ```
   Translate these Real Vehicle Breakdowns (FS25 mod) UI strings.

   Context: RVB simulates realistic vehicle breakdowns and maintenance.
   Key terms:
   - "breakdown" = vehicle malfunction/failure
   - "jumper cables" = battery jump-start cables
   - "service interval" = maintenance schedule
   - "part wear" = component degradation
   ```
3. Write translations back to XML
4. Validate XML and placeholders

### Step 4: PR Submission

**PR Title:** `feat(i18n): Add 12 new language translations (JP, KR, CS, CT, ID, VI, DA, SV, FI, NO, RO, FC)`

**PR Description:**
```markdown
## Summary
Adds translations for 12 new languages, expanding RVB from 14 to 26 languages.

## New Languages
- Japanese (jp) - 210 entries
- Korean (kr) - 210 entries
- Chinese Simplified (cs) - 210 entries
- Chinese Traditional (ct) - 210 entries
- Indonesian (id) - 210 entries
- Vietnamese (vi) - 210 entries
- Danish (da) - 210 entries
- Swedish (sv) - 210 entries
- Finnish (fi) - 210 entries
- Norwegian (no) - 210 entries
- Romanian (ro) - 210 entries
- French Canadian (fc) - 210 entries

## Translation Approach
AI-assisted translation with agricultural/mechanical context.
All placeholders (%s, %d) preserved.

## Validation
- [x] XML validity verified
- [x] All 210 entries present in each file
- [x] Placeholders preserved
- [x] Spot-checked 10 entries per language
```

## Timeline

| Task | Estimated Time |
|------|----------------|
| Find repo & fork | 15 min |
| Create 12 language files | 30 min |
| Run translation agents (parallel) | 1-2 hours |
| Validate all files | 30 min |
| Submit PR | 15 min |

**Total: ~3 hours**

---

---

# PART 3: UYT (Use Your Tyres) Translation Contribution

## Overview

UYT is the **easiest** contribution opportunity - only 7 translation entries!
Currently supports only 3 languages (EN, DE, PL).

## Current State

| Metric | Value |
|--------|-------|
| **Total entries** | 7 |
| **Current languages** | 3 (EN, DE, PL) |
| **Format** | Embedded in modDesc.xml |
| **Translation quality** | ✅ Good |

## The 7 Entries to Translate

```xml
<text name="input_UYT_REPLACE_TYRES">
    <en>Replace Tyres</en>
</text>
<text name="ui_uytReplaceDialog">
    <en>Do you want to replace tyres for %s?</en>
</text>
<text name="infohud_uytTyresWear">
    <en>Tyres wear</en>
</text>
<text name="infohud_uytTyresWearUnsupported">
    <en>Unsupported!</en>
</text>
<text name="ui_uytSettingsTitle">
    <en>Use up Your Tyres</en>
</text>
<text name="ui_uytSettingsTyreDistanceTitle">
    <en>Tyre Usage Rate</en>
</text>
<text name="ui_uytSettingsTyreDistanceDescription">
    <en>How quickly tyres will get fully used.</en>
</text>
```

## Languages to Add

We can add **20+ languages** with minimal effort:

| Language | Code | Sample Translation of "Replace Tyres" |
|----------|------|--------------------------------------|
| French | fr | Remplacer les pneus |
| Spanish | es | Reemplazar neumáticos |
| Italian | it | Sostituire pneumatici |
| Portuguese | pt | Substituir pneus |
| Dutch | nl | Banden vervangen |
| Czech | cz | Vyměnit pneumatiky |
| Hungarian | hu | Gumik cseréje |
| Russian | ru | Заменить шины |
| Turkish | tr | Lastikleri değiştir |
| Japanese | jp | タイヤを交換 |
| Korean | kr | 타이어 교체 |
| Chinese | cs | 更换轮胎 |
| And more... | | |

**Total work:** 7 entries × 20 languages = **140 translations** (trivial!)

## Implementation Plan

### Step 1: Find UYT Repository
- Search GitHub for "Use Your Tyres FS25" or "50keda" (author name from modDesc)
- Check if they accept PRs

### Step 2: Prepare Translations

Create a simple translation table:

```javascript
const UYT_TRANSLATIONS = {
    "input_UYT_REPLACE_TYRES": {
        fr: "Remplacer les pneus",
        es: "Reemplazar neumáticos",
        it: "Sostituire pneumatici",
        // ... etc
    },
    "ui_uytReplaceDialog": {
        fr: "Voulez-vous remplacer les pneus pour %s ?",
        es: "¿Quieres reemplazar los neumáticos por %s?",
        // ... etc (preserve %s placeholder!)
    },
    // ... all 7 entries
};
```

### Step 3: Generate modDesc.xml Patch

```xml
<text name="input_UYT_REPLACE_TYRES">
    <de>Reifen ersetzen</de>
    <en>Replace Tyres</en>
    <pl>Wymiana opon</pl>
    <!-- NEW -->
    <fr>Remplacer les pneus</fr>
    <es>Reemplazar neumáticos</es>
    <it>Sostituire pneumatici</it>
    <pt>Substituir pneus</pt>
    <br>Substituir pneus</br>
    <nl>Banden vervangen</nl>
    <cz>Vyměnit pneumatiky</cz>
    <hu>Gumik cseréje</hu>
    <ru>Заменить шины</ru>
    <uk>Замінити шини</uk>
    <tr>Lastikleri değiştir</tr>
    <jp>タイヤを交換</jp>
    <kr>타이어 교체</kr>
    <cs>更换轮胎</cs>
</text>
<!-- Repeat for all 7 entries -->
```

### Step 4: PR Submission

**PR Title:** `feat(i18n): Add 17 new language translations`

**PR Description:**
```markdown
## Summary
Expands UYT from 3 languages to 20 languages.

## New Languages Added
FR, ES, IT, PT, BR, NL, CZ, HU, RU, UK, TR, JP, KR, CS, CT, DA, SV

## Changes
- Modified `modDesc.xml` to add translations for all 7 UI strings
- All %s placeholders preserved
- Tested XML validity

## Notes
These translations were generated with AI assistance and reviewed for accuracy.
Happy to iterate if any native speakers spot issues!
```

## Timeline

| Task | Estimated Time |
|------|----------------|
| Find repo & fork | 10 min |
| Translate 7 entries × 17 languages | 30 min |
| Update modDesc.xml | 15 min |
| Validate XML | 5 min |
| Submit PR | 10 min |

**Total: ~1 hour** (easiest PR of the three!)

---

---

# Combined Contribution Summary

## Total Impact

| Mod | New Translations | Languages Improved | Effort |
|-----|------------------|-------------------|--------|
| **Courseplay** | ~2,100 entries | 11 languages | 8-10 hours |
| **RVB** | ~2,520 entries | 12 new languages | 3 hours |
| **UYT** | ~140 entries | 17 new languages | 1 hour |
| **TOTAL** | **~4,760 entries** | **40 language improvements** | **12-14 hours** |

## Recommended Order

1. **UYT First** (1 hour) - Quick win, builds confidence
2. **RVB Second** (3 hours) - Medium effort, good impact
3. **Courseplay Last** (8-10 hours) - Largest effort, highest visibility

## PR Strategy

| PR # | Mod | Type | Risk Level |
|------|-----|------|------------|
| 1 | UYT | Add 17 languages | Very Low |
| 2 | Courseplay | Fix typos | Very Low |
| 3 | RVB | Add 12 languages | Low |
| 4 | Courseplay | Fill ID/VI gaps | Low |
| 5 | Courseplay | Fill FC/FI/NO/RO | Low |
| 6 | Courseplay | Fill NL/JP/DA/CT/SV | Low |

---

*Plan created: 2026-01-26*
*Authors: Claude & Samantha*
*Targets: Courseplay FS25, RVB, UYT*
