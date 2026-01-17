#!/usr/bin/env node
/**
 * ══════════════════════════════════════════════════════════════════════════════
 * UNIVERSAL TRANSLATION SYNC TOOL v2.0.0
 * For Farming Simulator 25 Mods
 * ══════════════════════════════════════════════════════════════════════════════
 *
 * WHAT IS THIS?
 *   A portable tool that keeps your mod's translation files in sync.
 *   Drop this file into your translations folder and run it - that's it!
 *
 * THE PROBLEM IT SOLVES:
 *   When you add a new text key to your English translation file, you have to
 *   manually add it to German, French, Spanish, etc. This is tedious and
 *   error-prone. Keys get missed, translations fall out of sync.
 *
 * HOW IT WORKS:
 *   1. You add a key to your source language (e.g., translation_en.xml)
 *   2. Run: node translation_sync.js sync
 *   3. The script automatically adds the missing key to ALL other language
 *      files with a "[EN] " prefix so translators know it needs work
 *   4. It tells you exactly which keys were added
 *
 * FEATURES:
 *   - Zero configuration needed - just drop in and run!
 *   - Auto-detects XML format (texts or elements pattern)
 *   - Auto-detects which languages to sync from existing files
 *   - Per-key tracking: knows when each key was added and if it's translated
 *   - Lists exactly which keys are added during each sync
 *   - CI-friendly exit codes for build pipelines
 *
 * QUICK START:
 *   1. Put this file in your translations/ folder
 *   2. Run: node translation_sync.js
 *      (First run shows a setup guide with auto-detected settings)
 *   3. Run: node translation_sync.js sync
 *      (Adds missing keys to all languages)
 *
 * COMMANDS:
 *   sync      - Add missing keys to all languages, show what was added
 *   check     - Report status, exit code 1 if any keys are missing
 *   status    - Quick overview: how many keys translated per language
 *   report    - Detailed breakdown with lists of problem keys
 *   init      - Reset the tracking file
 *   validate  - CI-friendly: just exit code, minimal output
 *   help      - Show help (also: --help, -h)
 *
 * SUPPORTED XML FORMATS (auto-detected):
 *   <e k="key" v="value"/>           (elements pattern - used by UsedPlus)
 *   <text name="key" text="value"/>  (texts pattern - most common)
 *
 * FILES:
 *   .translation-sync.json  - Tracking data (auto-created, local state)
 *                             Consider adding to .gitignore
 *
 * CONFIGURATION:
 *   Most mods won't need to change anything - auto-detection handles it!
 *   Languages are detected from existing files (no manual list needed).
 *
 * Author: FS25_UsedPlus Team
 * License: MIT - Free to use, modify, and distribute in any mod
 * Repository: https://github.com/[your-repo] (optional)
 * ══════════════════════════════════════════════════════════════════════════════
 */

const VERSION = '2.0.0';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// ══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION (most users won't need to change anything!)
// ══════════════════════════════════════════════════════════════════════════════
//
// The script auto-detects which languages to sync by scanning for existing
// translation files. If translation_de.xml exists, it syncs German. Simple!
//
// Only edit these if you need to:

const CONFIG = {
    // Source language (the "master" file all others sync from)
    sourceLanguage: 'en',

    // Prefix added to untranslated entries (so translators know what needs work)
    untranslatedPrefix: '[EN] ',

    // File naming pattern: 'auto', 'translation', or 'l10n'
    // 'auto' = Detect from existing files (recommended)
    filePrefix: 'auto',

    // XML format: 'auto', 'texts', or 'elements'
    // 'auto'     = Detect from source file (recommended)
    // 'texts'    = <text name="key" text="value"/>
    // 'elements' = <e k="key" v="value"/>
    xmlFormat: 'auto',
};

// ══════════════════════════════════════════════════════════════════════════════
// LANGUAGE NAME MAPPINGS (for display purposes - add more as needed)
// ══════════════════════════════════════════════════════════════════════════════

const LANGUAGE_NAMES = {
    en: 'English',
    de: 'German',
    fr: 'French',
    es: 'Spanish',
    it: 'Italian',
    pl: 'Polish',
    ru: 'Russian',
    br: 'Portuguese (BR)',
    pt: 'Portuguese (PT)',
    cz: 'Czech',
    cs: 'Czech',
    uk: 'Ukrainian',
    nl: 'Dutch',
    da: 'Danish',
    sv: 'Swedish',
    no: 'Norwegian',
    fi: 'Finnish',
    hu: 'Hungarian',
    ro: 'Romanian',
    tr: 'Turkish',
    ja: 'Japanese',
    ko: 'Korean',
    zh: 'Chinese (Simplified)',
    tw: 'Chinese (Traditional)',
    // Add more as needed - format: 'code': 'Display Name'
};

// ══════════════════════════════════════════════════════════════════════════════
// END OF CONFIGURATION - No need to edit below this line
// ══════════════════════════════════════════════════════════════════════════════

const TRACKING_FILE = '.translation-sync.json';

// Change to script directory
process.chdir(__dirname);

// ──────────────────────────────────────────────────────────────────────────────
// Utility Functions
// ──────────────────────────────────────────────────────────────────────────────

function getHash(text) {
    return crypto.createHash('md5').update(text, 'utf8').digest('hex').substring(0, 8);
}

function escapeRegex(str) {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function escapeXml(str) {
    return str
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

function getDateString() {
    return new Date().toISOString().split('T')[0];
}

function getTimestamp() {
    return new Date().toISOString();
}

function getEnabledLanguages() {
    // Auto-detect languages by scanning for existing translation files
    const filePrefix = autoDetectFilePrefix();
    if (!filePrefix) return [];

    const files = fs.readdirSync('.');
    const pattern = new RegExp(`^${filePrefix}_([a-z]{2})\\.xml$`, 'i');
    const languages = [];

    for (const file of files) {
        const match = file.match(pattern);
        if (match) {
            const code = match[1].toLowerCase();
            // Skip the source language
            if (code !== CONFIG.sourceLanguage) {
                languages.push({
                    code,
                    name: LANGUAGE_NAMES[code] || code.toUpperCase()
                });
            }
        }
    }

    // Sort alphabetically by code for consistent output
    return languages.sort((a, b) => a.code.localeCompare(b.code));
}

// ──────────────────────────────────────────────────────────────────────────────
// Auto-Detection Functions
// ──────────────────────────────────────────────────────────────────────────────

function autoDetectFilePrefix() {
    if (CONFIG.filePrefix !== 'auto') return CONFIG.filePrefix;

    if (fs.existsSync(`translation_${CONFIG.sourceLanguage}.xml`)) return 'translation';
    if (fs.existsSync(`l10n_${CONFIG.sourceLanguage}.xml`)) return 'l10n';

    // Try to find any translation file
    const files = fs.readdirSync('.');
    for (const file of files) {
        if (file.match(/^translation_[a-z]{2}\.xml$/i)) return 'translation';
        if (file.match(/^l10n_[a-z]{2}\.xml$/i)) return 'l10n';
    }

    return null;
}

function autoDetectXmlFormat(content) {
    if (CONFIG.xmlFormat !== 'auto') return CONFIG.xmlFormat;

    if (content.includes('<e k="')) return 'elements';
    if (content.includes('<text name="')) return 'texts';

    return null;
}

function autoDetectContainerTag(format) {
    if (format === 'elements') return 'elements';
    if (format === 'texts') return 'texts';
    return null;
}

function getSourceFilePath(filePrefix) {
    return `${filePrefix}_${CONFIG.sourceLanguage}.xml`;
}

function getLangFilePath(filePrefix, langCode) {
    return `${filePrefix}_${langCode}.xml`;
}

// ──────────────────────────────────────────────────────────────────────────────
// XML Parsing (supports both formats)
// ──────────────────────────────────────────────────────────────────────────────

function parseTranslationFile(filepath, format) {
    const content = fs.readFileSync(filepath, 'utf8');
    const entries = new Map();
    const orderedKeys = [];

    let pattern;
    if (format === 'elements') {
        // <e k="key" v="value" [eh="hash"] />
        pattern = /<e k="([^"]+)" v="([^"]*)"(?:\s+eh="([^"]*)")?\s*\/>/g;
    } else {
        // <text name="key" text="value"/>
        pattern = /<text name="([^"]+)" text="([^"]*)"\s*\/>/g;
    }

    let match;
    while ((match = pattern.exec(content)) !== null) {
        const key = match[1];
        const value = match[2];
        const hash = match[3] || null; // Only exists for elements format
        entries.set(key, { value, hash });
        orderedKeys.push(key);
    }

    return { entries, orderedKeys, rawContent: content };
}

function formatNewEntry(key, value, hash, format) {
    const escapedValue = escapeXml(value);
    if (format === 'elements') {
        return `<e k="${key}" v="${escapedValue}" eh="${hash}" />`;
    } else {
        return `<text name="${key}" text="${escapedValue}"/>`;
    }
}

function findInsertPosition(content, key, enOrderedKeys, langKeys, format) {
    // Find the key's position in English ordering
    const enIndex = enOrderedKeys.indexOf(key);

    // Look for the nearest preceding key that exists in this language
    for (let i = enIndex - 1; i >= 0; i--) {
        const prevKey = enOrderedKeys[i];
        if (langKeys.has(prevKey)) {
            let pattern;
            if (format === 'elements') {
                pattern = new RegExp(`<e k="${escapeRegex(prevKey)}" v="[^"]*"(?:\\s+eh="[^"]*")?\\s*/>`, 'g');
            } else {
                pattern = new RegExp(`<text name="${escapeRegex(prevKey)}" text="[^"]*"\\s*/>`, 'g');
            }
            const match = pattern.exec(content);
            if (match) {
                return match.index + match[0].length;
            }
        }
    }

    // Fallback: insert before closing container tag
    const containerTag = autoDetectContainerTag(format);
    const closeTagIndex = content.indexOf(`</${containerTag}>`);
    if (closeTagIndex !== -1) {
        const beforeClose = content.substring(0, closeTagIndex);
        let lastEntryPattern;
        if (format === 'elements') {
            lastEntryPattern = /.*<e k="[^"]+" v="[^"]*"(?:\s+eh="[^"]*")?\s*\/>/s;
        } else {
            lastEntryPattern = /.*<text name="[^"]+" text="[^"]*"\s*\/>/s;
        }
        const lastEntryMatch = beforeClose.match(lastEntryPattern);
        if (lastEntryMatch) {
            return lastEntryMatch.index + lastEntryMatch[0].length;
        }
    }

    return -1;
}

// ──────────────────────────────────────────────────────────────────────────────
// Tracking File Management
// ──────────────────────────────────────────────────────────────────────────────

function loadTracking() {
    if (!fs.existsSync(TRACKING_FILE)) {
        return null;
    }
    try {
        return JSON.parse(fs.readFileSync(TRACKING_FILE, 'utf8'));
    } catch (e) {
        console.error(`Warning: Could not parse ${TRACKING_FILE}, will recreate.`);
        return null;
    }
}

function saveTracking(tracking) {
    fs.writeFileSync(TRACKING_FILE, JSON.stringify(tracking, null, 2), 'utf8');
}

function createNewTracking() {
    return {
        schemaVersion: 1,
        toolVersion: VERSION,
        sourceLanguage: CONFIG.sourceLanguage,
        created: getTimestamp(),
        lastSync: null,
        stats: {
            totalKeys: 0,
            syncCount: 0
        },
        keys: {}
    };
}

function updateTrackingForKey(tracking, key, sourceHash, langCode, status) {
    if (!tracking.keys[key]) {
        tracking.keys[key] = {
            v: 1,
            added: getDateString(),
            sourceHash: sourceHash,
            translations: {}
        };
    }

    const keyData = tracking.keys[key];

    // Check if source changed
    if (keyData.sourceHash !== sourceHash) {
        keyData.v++;
        keyData.sourceHash = sourceHash;
        keyData.modified = getDateString();
        // Mark all existing translations as stale
        for (const lang of Object.keys(keyData.translations)) {
            if (keyData.translations[lang].s === 'ok') {
                keyData.translations[lang].s = 'stale';
            }
        }
    }

    // Update this language's status
    keyData.translations[langCode] = {
        s: status,
        h: sourceHash
    };
}

// ──────────────────────────────────────────────────────────────────────────────
// SYNC Command
// ──────────────────────────────────────────────────────────────────────────────

function syncTranslations() {
    console.log("══════════════════════════════════════════════════════════════════════");
    console.log(`SYNC v${VERSION} - Enforcing key parity`);
    console.log("══════════════════════════════════════════════════════════════════════");
    console.log();

    // Auto-detect file prefix
    const filePrefix = autoDetectFilePrefix();
    if (!filePrefix) {
        console.error("ERROR: Could not find source translation file.");
        console.error(`Looking for: translation_${CONFIG.sourceLanguage}.xml or l10n_${CONFIG.sourceLanguage}.xml`);
        console.error("Make sure the source file exists in this directory.");
        process.exit(1);
    }

    const sourceFile = getSourceFilePath(filePrefix);
    if (!fs.existsSync(sourceFile)) {
        console.error(`ERROR: Source file not found: ${sourceFile}`);
        process.exit(1);
    }

    // Load source and detect format
    const sourceContent = fs.readFileSync(sourceFile, 'utf8');
    const format = autoDetectXmlFormat(sourceContent);
    if (!format) {
        console.error("ERROR: Could not detect XML format from source file.");
        console.error("Expected either <e k=\"...\" v=\"...\"/> or <text name=\"...\" text=\"...\"/> patterns.");
        process.exit(1);
    }

    const { entries: sourceEntries, orderedKeys: sourceOrderedKeys } = parseTranslationFile(sourceFile, format);

    // Compute hashes for source entries
    for (const [key, data] of sourceEntries) {
        data.hash = getHash(data.value);
    }

    console.log(`Source: ${sourceFile} (${sourceEntries.size} keys)`);
    console.log(`Format: ${format} (${format === 'elements' ? '<e k="" v=""/>' : '<text name="" text=""/>'})`);
    console.log();

    // Load or create tracking
    let tracking = loadTracking() || createNewTracking();
    tracking.lastSync = getTimestamp();
    tracking.stats.syncCount++;

    const enabledLangs = getEnabledLanguages();
    let totalAdded = 0;

    for (const { code: langCode, name: langName } of enabledLangs) {
        const langFile = getLangFilePath(filePrefix, langCode);

        if (!fs.existsSync(langFile)) {
            console.log(`  ${langName.padEnd(18)}: FILE NOT FOUND - skipping`);
            continue;
        }

        let { entries: langEntries, orderedKeys: langKeys, rawContent: content } = parseTranslationFile(langFile, format);
        const langKeySet = new Set(langKeys);

        let added = 0;
        const missingKeys = [];

        // Find missing keys
        for (const sourceKey of sourceOrderedKeys) {
            if (!langEntries.has(sourceKey)) {
                missingKeys.push(sourceKey);
            }
        }

        // Add missing keys
        for (const key of missingKeys) {
            const sourceData = sourceEntries.get(key);
            const placeholderValue = CONFIG.untranslatedPrefix + sourceData.value;
            const newEntry = `\n    ${formatNewEntry(key, placeholderValue, sourceData.hash, format)}`;

            const insertPos = findInsertPosition(content, key, sourceOrderedKeys, langKeySet, format);

            if (insertPos !== -1) {
                content = content.substring(0, insertPos) + newEntry + content.substring(insertPos);
                langKeySet.add(key);
                added++;
            } else {
                // Fallback: insert before closing tag
                const containerTag = autoDetectContainerTag(format);
                const closeTagIndex = content.indexOf(`</${containerTag}>`);
                if (closeTagIndex !== -1) {
                    content = content.substring(0, closeTagIndex) + newEntry + '\n    ' + content.substring(closeTagIndex);
                    langKeySet.add(key);
                    added++;
                }
            }

            // Update tracking
            updateTrackingForKey(tracking, key, sourceData.hash, langCode, 'new');
        }

        // Update hashes for existing entries (elements format only)
        if (format === 'elements') {
            for (const [key, sourceData] of sourceEntries) {
                if (langEntries.has(key)) {
                    const langData = langEntries.get(key);
                    const pattern = new RegExp(
                        `<e k="${escapeRegex(key)}" v="([^"]*)"(?:\\s+eh="[^"]*")?\\s*/>`,
                        'g'
                    );
                    content = content.replace(pattern, (match, v) => {
                        return `<e k="${key}" v="${v}" eh="${sourceData.hash}" />`;
                    });

                    // Determine status based on langData.value (already parsed)
                    let status = 'ok';
                    if (langData.value.startsWith(CONFIG.untranslatedPrefix) || langData.value === sourceData.value) {
                        status = 'new';
                    } else if (langData.hash && langData.hash !== sourceData.hash) {
                        status = 'stale';
                    }
                    updateTrackingForKey(tracking, key, sourceData.hash, langCode, status);
                }
            }
        } else {
            // For texts format, update tracking based on value comparison
            for (const [key, sourceData] of sourceEntries) {
                if (langEntries.has(key)) {
                    const langData = langEntries.get(key);
                    let status = 'ok';
                    if (langData.value.startsWith(CONFIG.untranslatedPrefix) || langData.value === sourceData.value) {
                        status = 'new';
                    }
                    updateTrackingForKey(tracking, key, sourceData.hash, langCode, status);
                }
            }
        }

        fs.writeFileSync(langFile, content, 'utf8');

        if (added > 0) {
            console.log(`  ${langName.padEnd(18)}: +${added} keys added`);
            for (const key of missingKeys) {
                console.log(`    + ${key}`);
            }
            totalAdded += added;
        } else {
            console.log(`  ${langName.padEnd(18)}: OK (all keys present)`);
        }
    }

    // Update tracking stats
    tracking.stats.totalKeys = sourceEntries.size;
    saveTracking(tracking);

    console.log();
    console.log("──────────────────────────────────────────────────────────────────────");
    if (totalAdded > 0) {
        console.log(`Tracking: ${TRACKING_FILE} updated (${sourceEntries.size} keys tracked)`);
        console.log(`New entries have "${CONFIG.untranslatedPrefix}" prefix - they need translation!`);
    } else {
        console.log(`SYNC COMPLETE: All languages have all keys.`);
        console.log(`Tracking: ${TRACKING_FILE} updated`);
    }
    console.log("──────────────────────────────────────────────────────────────────────");
}

// ──────────────────────────────────────────────────────────────────────────────
// CHECK Command
// ──────────────────────────────────────────────────────────────────────────────

function checkSync() {
    console.log("══════════════════════════════════════════════════════════════════════");
    console.log(`CHECK v${VERSION} - Analyzing translation sync status`);
    console.log("══════════════════════════════════════════════════════════════════════");
    console.log();

    const filePrefix = autoDetectFilePrefix();
    if (!filePrefix) {
        console.error("ERROR: Could not find source translation file.");
        process.exit(1);
    }

    const sourceFile = getSourceFilePath(filePrefix);
    if (!fs.existsSync(sourceFile)) {
        console.error(`ERROR: Source file not found: ${sourceFile}`);
        process.exit(1);
    }

    const sourceContent = fs.readFileSync(sourceFile, 'utf8');
    const format = autoDetectXmlFormat(sourceContent);
    const { entries: sourceEntries } = parseTranslationFile(sourceFile, format);

    for (const [key, data] of sourceEntries) {
        data.hash = getHash(data.value);
    }

    console.log(`Source: ${sourceFile} (${sourceEntries.size} keys)\n`);

    let hasProblems = false;
    const summary = [];
    const enabledLangs = getEnabledLanguages();

    for (const { code: langCode, name: langName } of enabledLangs) {
        const langFile = getLangFilePath(filePrefix, langCode);

        if (!fs.existsSync(langFile)) {
            console.log(`  ${langName.padEnd(18)}: FILE NOT FOUND`);
            hasProblems = true;
            summary.push({ name: langName, total: 0, missing: -1, stale: 0, untranslated: 0 });
            continue;
        }

        const { entries: langEntries } = parseTranslationFile(langFile, format);

        const missing = [];
        const stale = [];
        const untranslated = [];

        for (const [key, sourceData] of sourceEntries) {
            if (!langEntries.has(key)) {
                missing.push(key);
            } else {
                const langData = langEntries.get(key);
                if (langData.value.startsWith(CONFIG.untranslatedPrefix) || langData.value === sourceData.value) {
                    untranslated.push(key);
                } else if (format === 'elements' && langData.hash && langData.hash !== sourceData.hash) {
                    stale.push(key);
                }
            }
        }

        const issues = [];
        if (missing.length > 0) issues.push(`${missing.length} MISSING`);
        if (stale.length > 0) issues.push(`${stale.length} stale`);
        if (untranslated.length > 0) issues.push(`${untranslated.length} untranslated`);

        if (issues.length === 0) {
            console.log(`  ${langName.padEnd(18)}: OK (${langEntries.size} keys)`);
        } else {
            if (missing.length > 0) hasProblems = true;
            console.log(`  ${langName.padEnd(18)}: ${issues.join(', ')}`);

            if (missing.length > 0) {
                console.log(`    MISSING (${missing.length}):`);
                for (const key of missing.slice(0, 5)) {
                    console.log(`      - ${key}`);
                }
                if (missing.length > 5) {
                    console.log(`      ... and ${missing.length - 5} more`);
                }
            }
        }

        summary.push({
            name: langName,
            total: langEntries.size,
            missing: missing.length,
            stale: stale.length,
            untranslated: untranslated.length
        });
    }

    console.log();
    console.log("──────────────────────────────────────────────────────────────────────");
    console.log("SUMMARY:");
    console.log("──────────────────────────────────────────────────────────────────────");
    console.log("Language            | Total  | Missing | Stale | Untranslated");
    console.log("──────────────────────────────────────────────────────────────────────");

    for (const s of summary) {
        const status = (s.missing > 0) ? '!!' : '  ';
        const totalStr = s.missing === -1 ? '  N/A' : String(s.total).padStart(6);
        const missingStr = s.missing === -1 ? '  N/A' : String(s.missing).padStart(7);
        console.log(`${status}${s.name.padEnd(18)} | ${totalStr} | ${missingStr} | ${String(s.stale).padStart(5)} | ${String(s.untranslated).padStart(12)}`);
    }
    console.log("──────────────────────────────────────────────────────────────────────");
    console.log(`Source has ${sourceEntries.size} keys - all languages should match.`);

    if (hasProblems) {
        console.log();
        console.log("CRITICAL: Missing keys detected! Run 'node translation_sync.js sync' to fix.");
        process.exit(1);
    } else {
        console.log();
        if (summary.some(s => s.untranslated > 0)) {
            console.log("KEY PARITY OK - All languages have all keys.");
            console.log(`Note: Untranslated entries have "${CONFIG.untranslatedPrefix}" prefix and need translation.`);
        } else {
            console.log("All translations are in sync!");
        }
        process.exit(0);
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// STATUS Command
// ──────────────────────────────────────────────────────────────────────────────

function showStatus() {
    const tracking = loadTracking();

    if (!tracking) {
        console.log("No tracking file found. Run 'node translation_sync.js sync' first.");
        return;
    }

    console.log();
    console.log("Translation Status (from .translation-sync.json)");
    console.log("────────────────────────────────────────────────────────────────");
    console.log(`Tool version: ${tracking.toolVersion}`);
    console.log(`Source: ${tracking.sourceLanguage.toUpperCase()} (${tracking.stats.totalKeys} keys)`);
    console.log(`Last sync: ${tracking.lastSync || 'Never'}`);
    console.log(`Sync count: ${tracking.stats.syncCount}`);
    console.log();

    // Aggregate stats per language
    const enabledLangs = getEnabledLanguages();
    const langStats = {};

    for (const { code } of enabledLangs) {
        langStats[code] = { ok: 0, new: 0, stale: 0 };
    }

    for (const [key, keyData] of Object.entries(tracking.keys)) {
        for (const [langCode, langData] of Object.entries(keyData.translations)) {
            if (langStats[langCode]) {
                const status = langData.s || 'ok';
                langStats[langCode][status] = (langStats[langCode][status] || 0) + 1;
            }
        }
    }

    console.log("Language            |   OK   |  New  | Stale");
    console.log("────────────────────────────────────────────────────────────────");

    for (const { code, name } of enabledLangs) {
        const stats = langStats[code] || { ok: 0, new: 0, stale: 0 };
        console.log(`${name.padEnd(20)}| ${String(stats.ok).padStart(6)} | ${String(stats.new).padStart(5)} | ${String(stats.stale).padStart(5)}`);
    }

    console.log("────────────────────────────────────────────────────────────────");
}

// ──────────────────────────────────────────────────────────────────────────────
// INIT Command
// ──────────────────────────────────────────────────────────────────────────────

function initTracking() {
    console.log("Initializing tracking file...\n");

    const filePrefix = autoDetectFilePrefix();
    if (!filePrefix) {
        console.error("ERROR: Could not find source translation file.");
        process.exit(1);
    }

    const sourceFile = getSourceFilePath(filePrefix);
    if (!fs.existsSync(sourceFile)) {
        console.error(`ERROR: Source file not found: ${sourceFile}`);
        process.exit(1);
    }

    const sourceContent = fs.readFileSync(sourceFile, 'utf8');
    const format = autoDetectXmlFormat(sourceContent);
    const { entries: sourceEntries } = parseTranslationFile(sourceFile, format);

    const tracking = createNewTracking();
    tracking.lastSync = getTimestamp();
    tracking.stats.totalKeys = sourceEntries.size;

    // Initialize all keys
    for (const [key, data] of sourceEntries) {
        const hash = getHash(data.value);
        tracking.keys[key] = {
            v: 1,
            added: getDateString(),
            sourceHash: hash,
            translations: {}
        };
    }

    // Scan existing translations
    const enabledLangs = getEnabledLanguages();
    for (const { code: langCode } of enabledLangs) {
        const langFile = getLangFilePath(filePrefix, langCode);
        if (!fs.existsSync(langFile)) continue;

        const { entries: langEntries } = parseTranslationFile(langFile, format);

        for (const [key, sourceData] of sourceEntries) {
            const sourceHash = getHash(sourceData.value);
            if (langEntries.has(key)) {
                const langData = langEntries.get(key);
                let status = 'ok';
                if (langData.value.startsWith(CONFIG.untranslatedPrefix) || langData.value === sourceData.value) {
                    status = 'new';
                }
                tracking.keys[key].translations[langCode] = { s: status, h: sourceHash };
            }
        }
    }

    saveTracking(tracking);
    console.log(`Created ${TRACKING_FILE} with ${sourceEntries.size} keys.`);
    console.log("Tracking is now active for future syncs.");
}

// ──────────────────────────────────────────────────────────────────────────────
// REPORT Command
// ──────────────────────────────────────────────────────────────────────────────

function generateReport() {
    console.log("══════════════════════════════════════════════════════════════════════");
    console.log(`TRANSLATION SYNC DETAILED REPORT v${VERSION}`);
    console.log("══════════════════════════════════════════════════════════════════════");
    console.log();

    const filePrefix = autoDetectFilePrefix();
    if (!filePrefix) {
        console.error("ERROR: Could not find source translation file.");
        process.exit(1);
    }

    const sourceFile = getSourceFilePath(filePrefix);
    const sourceContent = fs.readFileSync(sourceFile, 'utf8');
    const format = autoDetectXmlFormat(sourceContent);
    const { entries: sourceEntries } = parseTranslationFile(sourceFile, format);

    for (const [key, data] of sourceEntries) {
        data.hash = getHash(data.value);
    }

    console.log(`Source: ${sourceFile} (${sourceEntries.size} keys)\n`);

    const enabledLangs = getEnabledLanguages();

    for (const { code: langCode, name: langName } of enabledLangs) {
        const langFile = getLangFilePath(filePrefix, langCode);

        if (!fs.existsSync(langFile)) {
            console.log(`${langName} (${langCode.toUpperCase()}): FILE NOT FOUND\n`);
            continue;
        }

        const { entries: langEntries } = parseTranslationFile(langFile, format);

        const inSync = [];
        const missing = [];
        const stale = [];
        const untranslated = [];

        for (const [key, sourceData] of sourceEntries) {
            if (!langEntries.has(key)) {
                missing.push({ key, enValue: sourceData.value });
            } else {
                const langData = langEntries.get(key);

                if (langData.value.startsWith(CONFIG.untranslatedPrefix)) {
                    untranslated.push({ key, marker: 'prefix' });
                } else if (langData.value === sourceData.value) {
                    untranslated.push({ key, marker: 'exact match' });
                } else if (format === 'elements' && langData.hash && langData.hash !== sourceData.hash) {
                    stale.push({ key, enValue: sourceData.value });
                } else {
                    inSync.push(key);
                }
            }
        }

        console.log(`${langName} (${langCode.toUpperCase()}):`);
        console.log(`  Total keys:    ${langEntries.size}`);
        console.log(`  In sync:       ${inSync.length}`);
        console.log(`  Missing:       ${missing.length}`);
        console.log(`  Stale:         ${stale.length}`);
        console.log(`  Untranslated:  ${untranslated.length}`);

        if (missing.length > 0) {
            console.log(`\n  --- MISSING KEYS ---`);
            for (const { key } of missing.slice(0, 10)) {
                console.log(`    - ${key}`);
            }
            if (missing.length > 10) {
                console.log(`    ... and ${missing.length - 10} more`);
            }
        }

        if (stale.length > 0 && stale.length <= 15) {
            console.log(`\n  --- STALE (source changed) ---`);
            for (const { key } of stale) {
                console.log(`    - ${key}`);
            }
        }

        console.log();
    }

    console.log("══════════════════════════════════════════════════════════════════════");
    console.log("Commands: sync | check | status | report | init | validate");
    console.log("══════════════════════════════════════════════════════════════════════");
}

// ──────────────────────────────────────────────────────────────────────────────
// VALIDATE Command
// ──────────────────────────────────────────────────────────────────────────────

function validateSync() {
    const filePrefix = autoDetectFilePrefix();
    if (!filePrefix) {
        console.log("FAIL: No translation files found");
        process.exit(1);
    }

    const sourceFile = getSourceFilePath(filePrefix);
    if (!fs.existsSync(sourceFile)) {
        console.log("FAIL: Source file not found");
        process.exit(1);
    }

    const sourceContent = fs.readFileSync(sourceFile, 'utf8');
    const format = autoDetectXmlFormat(sourceContent);
    const { entries: sourceEntries } = parseTranslationFile(sourceFile, format);

    let hasProblems = false;
    const enabledLangs = getEnabledLanguages();

    for (const { code: langCode } of enabledLangs) {
        const langFile = getLangFilePath(filePrefix, langCode);
        if (!fs.existsSync(langFile)) {
            hasProblems = true;
            break;
        }

        const { entries: langEntries } = parseTranslationFile(langFile, format);

        for (const [key] of sourceEntries) {
            if (!langEntries.has(key)) {
                hasProblems = true;
                break;
            }
        }

        if (hasProblems) break;
    }

    if (hasProblems) {
        console.log("FAIL: Translation files out of sync");
        process.exit(1);
    } else {
        console.log("OK: All translation files in sync");
        process.exit(0);
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Help & First Run Detection
// ──────────────────────────────────────────────────────────────────────────────

function isFirstRun() {
    return !fs.existsSync(TRACKING_FILE);
}

function detectEnvironment() {
    const filePrefix = autoDetectFilePrefix();
    const sourceFile = filePrefix ? getSourceFilePath(filePrefix) : null;
    const sourceExists = sourceFile && fs.existsSync(sourceFile);

    let format = null;
    let keyCount = 0;

    if (sourceExists) {
        const content = fs.readFileSync(sourceFile, 'utf8');
        format = autoDetectXmlFormat(content);
        if (format) {
            const { entries } = parseTranslationFile(sourceFile, format);
            keyCount = entries.size;
        }
    }

    const enabledLangs = getEnabledLanguages();

    return { filePrefix, sourceFile, sourceExists, format, keyCount, enabledLangs };
}

function showFirstRunGuide() {
    const env = detectEnvironment();

    console.log(`
══════════════════════════════════════════════════════════════════════════════
   UNIVERSAL TRANSLATION SYNC TOOL v${VERSION}
   First-Time Setup Guide
══════════════════════════════════════════════════════════════════════════════

Welcome! This tool helps keep your mod's translation files in sync.

WHAT THIS TOOL DOES:
  - Ensures every translation key in your source language exists in ALL
    other language files (key parity)
  - Automatically adds missing keys with a "${CONFIG.untranslatedPrefix}" prefix so translators
    know what needs work
  - Tracks changes over time so you know when keys were added or modified
  - Lists exactly which keys are added during each sync

CURRENT DETECTION:
`);

    if (env.sourceExists) {
        console.log(`  ✓ Source file found: ${env.sourceFile}`);
        console.log(`  ✓ Format detected:   ${env.format} (${env.format === 'elements' ? '<e k="" v=""/>' : '<text name="" text=""/>'})`);
        console.log(`  ✓ Keys found:        ${env.keyCount}`);
        if (env.enabledLangs.length > 0) {
            const langCodes = env.enabledLangs.map(l => l.code.toUpperCase()).join(', ');
            console.log(`  ✓ Languages found:   ${env.enabledLangs.length} (${langCodes})`);
        } else {
            console.log(`  ✗ No language files found besides source`);
        }
    } else {
        console.log(`  ✗ No source file found!`);
        console.log(`    Looking for: translation_${CONFIG.sourceLanguage}.xml or l10n_${CONFIG.sourceLanguage}.xml`);
        console.log(`    Make sure this script is in the same folder as your translation files.`);
    }

    console.log(`
WHAT HAPPENS WHEN YOU RUN 'sync':
  1. Reads all keys from your source file (${CONFIG.sourceLanguage.toUpperCase()})
  2. Scans for existing translation files (translation_de.xml, translation_fr.xml, etc.)
  3. For each language file found:
     - Checks which keys are missing
     - Adds missing keys with "${CONFIG.untranslatedPrefix}" prefix as placeholder
     - Updates the tracking file with key status
  4. Shows you exactly which keys were added to each language

GETTING STARTED:
  1. Create your translation files (translation_de.xml, translation_fr.xml, etc.)
     - The script auto-detects which languages to sync based on existing files
     - No configuration needed!

  2. Run:  node translation_sync.js sync
     - This will add any missing keys to your language files
     - A tracking file (${TRACKING_FILE}) will be created

  3. Later, run:  node translation_sync.js check
     - To verify all languages have all keys
     - Exit code 1 if any keys are missing (useful for CI)

ZERO CONFIG NEEDED:
  The script auto-detects everything:
  - File naming pattern (translation_XX.xml or l10n_XX.xml)
  - XML format (elements or texts pattern)
  - Which languages to sync (based on existing files)

FILES CREATED:
  ${TRACKING_FILE}  <- Per-key tracking data (auto-created, local state)
                                   Consider adding to .gitignore

COMMANDS REFERENCE:
  sync      - Add missing keys, update tracking (START HERE)
  check     - Report status, exit 1 if missing keys
  status    - Quick overview from tracking file
  report    - Detailed breakdown by language
  init      - Reset tracking file
  validate  - CI-friendly minimal output

══════════════════════════════════════════════════════════════════════════════
Ready? Run:  node translation_sync.js sync
══════════════════════════════════════════════════════════════════════════════
`);
}

function showHelp() {
    console.log(`
══════════════════════════════════════════════════════════════════════════════
UNIVERSAL TRANSLATION SYNC TOOL v${VERSION}
══════════════════════════════════════════════════════════════════════════════

A portable translation synchronization tool for Farming Simulator 25 mods.
Ensures every key in your source language exists in all other languages.

COMMANDS:
  sync      - Enforce key parity: add missing keys with ${CONFIG.untranslatedPrefix}prefix
              Shows exactly which keys are added to each language
  check     - Report all issues, exit code 1 if MISSING keys exist
  status    - Quick overview from tracking file (keys per language, status)
  report    - Detailed breakdown by language with lists of problem keys
  init      - Initialize/reset the tracking file
  validate  - CI-friendly: minimal output, exit codes only

USAGE EXAMPLES:
  node translation_sync.js sync       # Add missing keys to all languages
  node translation_sync.js check      # Verify all languages are complete
  node translation_sync.js status     # See translation progress

ZERO CONFIG NEEDED:
  Languages are auto-detected from existing files!
  If translation_de.xml exists → German will be synced
  If translation_fr.xml exists → French will be synced
  ...and so on

OPTIONAL CONFIG (edit CONFIG section at top of this script):
  sourceLanguage      '${CONFIG.sourceLanguage}'             <- Your master language
  untranslatedPrefix  '${CONFIG.untranslatedPrefix}'       <- Prefix for new entries
  filePrefix          '${CONFIG.filePrefix}'            <- 'auto', 'translation', or 'l10n'
  xmlFormat           '${CONFIG.xmlFormat}'            <- 'auto', 'texts', or 'elements'

TRACKING:
  ${TRACKING_FILE} stores per-key version history:
  - When each key was added
  - Version number (increments when source text changes)
  - Translation status per language (ok, new, stale)

  This file is auto-created on first sync. Consider adding to .gitignore
  as it's local state, not meant to be version-controlled.

SUPPORTED XML FORMATS (auto-detected):
  <e k="key" v="value" eh="hash"/>     (elements pattern)
  <text name="key" text="value"/>       (texts pattern)

WORKFLOW:
  1. Add new key to translation_${CONFIG.sourceLanguage}.xml
  2. Run: node translation_sync.js sync
  3. Script adds "${CONFIG.untranslatedPrefix}Your text" to all language files
  4. Translators update entries, removing the prefix
  5. Run: node translation_sync.js check  (or use in CI pipeline)

MORE INFO:
  Run with no arguments on first use to see the Getting Started guide.

══════════════════════════════════════════════════════════════════════════════
`);
}

// ──────────────────────────────────────────────────────────────────────────────
// Main
// ──────────────────────────────────────────────────────────────────────────────

const command = process.argv[2]?.toLowerCase();

switch (command) {
    case 'sync':
        syncTranslations();
        break;
    case 'check':
        checkSync();
        break;
    case 'status':
        showStatus();
        break;
    case 'report':
        generateReport();
        break;
    case 'init':
        initTracking();
        break;
    case 'validate':
        validateSync();
        break;
    case 'help':
    case '--help':
    case '-h':
        showHelp();
        break;
    default:
        // First run with no args? Show getting started guide
        if (!command && isFirstRun()) {
            showFirstRunGuide();
        } else {
            showHelp();
        }
}
