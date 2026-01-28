#!/usr/bin/env node
/**
 * Complete Danish Translation Tool
 * Identifies untranslated entries (where v="" still contains English) and translates them
 */

const fs = require('fs');
const path = require('path');

const EN_FILE = path.join(__dirname, 'translation_en.xml');
const DA_FILE = path.join(__dirname, 'translation_da.xml');

// Read both files
const enContent = fs.readFileSync(EN_FILE, 'utf8');
const daContent = fs.readFileSync(DA_FILE, 'utf8');

// Parse entries
function parseEntries(content) {
    const entries = new Map();
    const regex = /<e k="([^"]+)" v="([^"]*)" eh="([^"]+)" \/>/g;
    let match;

    while ((match = regex.exec(content)) !== null) {
        entries.set(match[1], {
            key: match[1],
            value: match[2],
            hash: match[3]
        });
    }

    return entries;
}

const enEntries = parseEntries(enContent);
const daEntries = parseEntries(daContent);

// Find untranslated entries (where Danish value matches English value)
const untranslated = [];
for (const [key, daEntry] of daEntries) {
    const enEntry = enEntries.get(key);
    if (enEntry && daEntry.value === enEntry.value) {
        untranslated.push({
            key: key,
            english: enEntry.value,
            hash: daEntry.hash
        });
    }
}

console.log(`\n===== TRANSLATION STATUS =====`);
console.log(`Total entries in English: ${enEntries.size}`);
console.log(`Total entries in Danish: ${daEntries.size}`);
console.log(`Untranslated entries: ${untranslated.length}`);
console.log(`Completion: ${Math.round((daEntries.size - untranslated.length) / daEntries.size * 100)}%`);

// Output untranslated entries for manual review
if (untranslated.length > 0) {
    console.log(`\n===== UNTRANSLATED ENTRIES =====\n`);

    // Group by key prefix for easier review
    const grouped = {};
    for (const entry of untranslated) {
        const prefix = entry.key.split('_')[1] || 'other';
        if (!grouped[prefix]) grouped[prefix] = [];
        grouped[prefix].push(entry);
    }

    for (const [prefix, entries] of Object.entries(grouped)) {
        console.log(`\n--- ${prefix.toUpperCase()} (${entries.length} entries) ---`);
        for (const entry of entries.slice(0, 10)) { // Show first 10
            console.log(`${entry.key}: "${entry.english}"`);
        }
        if (entries.length > 10) {
            console.log(`... and ${entries.length - 10} more`);
        }
    }
}

// Export for translation
fs.writeFileSync(
    path.join(__dirname, 'untranslated_danish.json'),
    JSON.stringify(untranslated, null, 2),
    'utf8'
);

console.log(`\n✓ Untranslated entries exported to untranslated_danish.json`);
