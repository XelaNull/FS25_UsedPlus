#!/usr/bin/env node
/**
 * Courseplay Translation Helper
 *
 * Analyzes Courseplay translation files and identifies:
 * 1. Untranslated entries (English text in non-English files)
 * 2. Typos and errors
 * 3. Stale translations that don't match source
 *
 * Can generate a report or output files ready for PR
 *
 * Usage:
 *   node courseplay_translation_helper.js --analyze <path_to_courseplay_translations>
 *   node courseplay_translation_helper.js --report <path_to_courseplay_translations>
 *   node courseplay_translation_helper.js --fix <path_to_courseplay_translations> --lang jp
 */

const fs = require('fs');
const path = require('path');

// Courseplay's language codes
const LANGUAGES = {
    'br': 'Portuguese (Brazil)',
    'cs': 'Chinese Simplified',
    'ct': 'Chinese Traditional',
    'cz': 'Czech',
    'da': 'Danish',
    'de': 'German',
    'ea': 'Spanish (Latin America)',
    'en': 'English',
    'es': 'Spanish',
    'fc': 'French Canadian',
    'fi': 'Finnish',
    'fr': 'French',
    'hu': 'Hungarian',
    'id': 'Indonesian',
    'it': 'Italian',
    'jp': 'Japanese',
    'kr': 'Korean',
    'nl': 'Dutch',
    'no': 'Norwegian',
    'pl': 'Polish',
    'pt': 'Portuguese',
    'ro': 'Romanian',
    'ru': 'Russian',
    'sv': 'Swedish',
    'tr': 'Turkish',
    'uk': 'Ukrainian',
    'vi': 'Vietnamese'
};

// Known typos in Courseplay source to fix
const ENGLISH_TYPOS = {
    'wich results': 'which results',
    'to far away': 'too far away',
    'teh ': 'the ',
    'wiht ': 'with '
};

/**
 * Parse Courseplay XML translation file
 */
function parseTranslationFile(filePath) {
    const content = fs.readFileSync(filePath, 'utf8');
    const entries = {};

    // Match: <text name="KEY" text="VALUE"/>
    const regex = /<text\s+name="([^"]+)"\s+text="([^"]*)"\s*\/>/g;
    let match;

    while ((match = regex.exec(content)) !== null) {
        entries[match[1]] = match[2];
    }

    return entries;
}

/**
 * Check if text appears to be English
 */
function isLikelyEnglish(text) {
    // Common English patterns
    const englishPatterns = [
        /^[A-Z][a-z]+ [a-z]+/,  // Capitalized word followed by lowercase
        /\b(the|is|are|was|were|has|have|had|will|would|could|should|can|may|might)\b/i,
        /\b(not|no|yes|please|error|warning|failed|success)\b/i,
        /\b(from|to|for|with|without|before|after|during)\b/i
    ];

    // Skip short strings, URLs, placeholders
    if (text.length < 10) return false;
    if (text.includes('http') || text.includes('%s') || text.includes('%d')) return false;

    return englishPatterns.some(pattern => pattern.test(text));
}

/**
 * Analyze a single language file against English source
 */
function analyzeLanguage(englishEntries, langEntries, langCode) {
    const issues = {
        untranslated: [],
        missing: [],
        typos: []
    };

    for (const [key, enText] of Object.entries(englishEntries)) {
        const langText = langEntries[key];

        if (!langText) {
            issues.missing.push({ key, enText });
        } else if (langText === enText && isLikelyEnglish(enText)) {
            // Same as English and looks like a real sentence
            issues.untranslated.push({ key, enText, langText });
        } else {
            // Check for stale copies with typos
            for (const [typo, fix] of Object.entries(ENGLISH_TYPOS)) {
                if (langText.includes(typo)) {
                    issues.typos.push({ key, langText, typo, fix });
                }
            }
        }
    }

    return issues;
}

/**
 * Generate analysis report
 */
function generateReport(translationsPath) {
    const englishPath = path.join(translationsPath, 'translation_en.xml');
    const englishEntries = parseTranslationFile(englishPath);

    console.log('='.repeat(60));
    console.log('COURSEPLAY TRANSLATION ANALYSIS REPORT');
    console.log('='.repeat(60));
    console.log(`Total English entries: ${Object.keys(englishEntries).length}`);
    console.log('');

    const summary = [];

    for (const [langCode, langName] of Object.entries(LANGUAGES)) {
        if (langCode === 'en') continue;

        const langPath = path.join(translationsPath, `translation_${langCode}.xml`);
        if (!fs.existsSync(langPath)) {
            console.log(`[SKIP] ${langCode}: File not found`);
            continue;
        }

        const langEntries = parseTranslationFile(langPath);
        const issues = analyzeLanguage(englishEntries, langEntries, langCode);

        const total = issues.untranslated.length + issues.missing.length + issues.typos.length;

        summary.push({
            code: langCode,
            name: langName,
            untranslated: issues.untranslated.length,
            missing: issues.missing.length,
            typos: issues.typos.length,
            total
        });
    }

    // Sort by total issues
    summary.sort((a, b) => b.total - a.total);

    console.log('SUMMARY BY LANGUAGE (sorted by issues):');
    console.log('-'.repeat(60));
    console.log('Code | Language             | Untrans | Missing | Typos | Total');
    console.log('-'.repeat(60));

    for (const s of summary) {
        console.log(
            `${s.code.padEnd(4)} | ${s.name.padEnd(20)} | ${String(s.untranslated).padStart(7)} | ${String(s.missing).padStart(7)} | ${String(s.typos).padStart(5)} | ${String(s.total).padStart(5)}`
        );
    }

    console.log('-'.repeat(60));
    console.log('');

    // Show sample issues for top problem languages
    const topProblems = summary.slice(0, 3);
    for (const lang of topProblems) {
        if (lang.total === 0) continue;

        const langPath = path.join(translationsPath, `translation_${lang.code}.xml`);
        const langEntries = parseTranslationFile(langPath);
        const issues = analyzeLanguage(englishEntries, langEntries, lang.code);

        console.log(`\nSAMPLE ISSUES FOR ${lang.name.toUpperCase()} (${lang.code}):`);
        console.log('-'.repeat(40));

        if (issues.untranslated.length > 0) {
            console.log('\nUntranslated (still English):');
            issues.untranslated.slice(0, 5).forEach(i => {
                console.log(`  ${i.key}: "${i.enText.substring(0, 50)}..."`);
            });
        }

        if (issues.typos.length > 0) {
            console.log('\nTypos found:');
            issues.typos.slice(0, 5).forEach(i => {
                console.log(`  ${i.key}: "${i.typo}" → "${i.fix}"`);
            });
        }
    }

    return summary;
}

/**
 * Export untranslated entries for a language (for AI translation)
 */
function exportUntranslated(translationsPath, langCode) {
    const englishPath = path.join(translationsPath, 'translation_en.xml');
    const langPath = path.join(translationsPath, `translation_${langCode}.xml`);

    const englishEntries = parseTranslationFile(englishPath);
    const langEntries = parseTranslationFile(langPath);
    const issues = analyzeLanguage(englishEntries, langEntries, langCode);

    const outputPath = `courseplay_untranslated_${langCode}.json`;

    const exportData = {
        language: langCode,
        languageName: LANGUAGES[langCode],
        generatedAt: new Date().toISOString(),
        entries: issues.untranslated.map(i => ({
            key: i.key,
            english: i.enText,
            currentValue: i.langText
        }))
    };

    fs.writeFileSync(outputPath, JSON.stringify(exportData, null, 2));
    console.log(`Exported ${exportData.entries.length} untranslated entries to ${outputPath}`);

    return exportData;
}

// Main
const args = process.argv.slice(2);
const command = args[0];
const translationsPath = args[1] || 'C:/Users/mrath/Downloads/FS25_Mods_Extracted/FS25_Courseplay/translations';

if (command === '--analyze' || command === '--report') {
    generateReport(translationsPath);
} else if (command === '--export') {
    const langCode = args[2] || 'jp';
    exportUntranslated(translationsPath, langCode);
} else {
    console.log('Courseplay Translation Helper');
    console.log('');
    console.log('Usage:');
    console.log('  node courseplay_translation_helper.js --report [path]     Analyze all languages');
    console.log('  node courseplay_translation_helper.js --export [path] jp  Export untranslated JP entries');
    console.log('');
    console.log('Default path: C:/Users/mrath/Downloads/FS25_Mods_Extracted/FS25_Courseplay/translations');
}
