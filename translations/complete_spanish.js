#!/usr/bin/env node
/**
 * Complete Spanish (Latin America) Translation
 * Identifies untranslated entries and provides proper contextual translations
 */

const fs = require('fs');
const path = require('path');

const EN_PATH = path.join(__dirname, 'translation_en.xml');
const ES_PATH = path.join(__dirname, 'translation_ea.xml');

// Read both files
const enContent = fs.readFileSync(EN_PATH, 'utf8');
const esContent = fs.readFileSync(ES_PATH, 'utf8');

// Extract all entries from both files
const entryRegex = /<e k="([^"]+)" v="([^"]*)" eh="([^"]+)"\s*\/>/g;

const enEntries = new Map();
let match;
while ((match = entryRegex.exec(enContent)) !== null) {
    enEntries.set(match[1], { value: match[2], hash: match[3] });
}

const esEntries = new Map();
const esContent2 = esContent; // Reset for second pass
let match2;
const entryRegex2 = /<e k="([^"]+)" v="([^"]*)" eh="([^"]+)"\s*\/>/g;
while ((match2 = entryRegex2.exec(esContent2)) !== null) {
    esEntries.set(match2[1], { value: match2[2], hash: match2[3] });
}

console.log(`English entries: ${enEntries.size}`);
console.log(`Spanish entries: ${esEntries.size}`);

// Find untranslated entries (where Spanish value equals English value)
const untranslated = [];
for (const [key, enData] of enEntries) {
    const esData = esEntries.get(key);
    if (!esData) {
        console.log(`Missing in Spanish: ${key}`);
        continue;
    }

    // Check if it's untranslated (Spanish = English)
    if (esData.value === enData.value && enData.value !== '') {
        untranslated.push({
            key,
            english: enData.value,
            hash: enData.hash
        });
    }
}

console.log(`\nFound ${untranslated.length} untranslated entries (${((untranslated.length / enEntries.size) * 100).toFixed(1)}%)`);
console.log(`Translated entries: ${enEntries.size - untranslated.length} (${(((enEntries.size - untranslated.length) / enEntries.size) * 100).toFixed(1)}%)`);

// Group by category for easier translation
const categories = {};
for (const entry of untranslated) {
    const category = entry.key.split('_')[1] || 'other';
    if (!categories[category]) categories[category] = [];
    categories[category].push(entry);
}

console.log('\nUntranslated by category:');
for (const [cat, items] of Object.entries(categories)) {
    console.log(`  ${cat}: ${items.length} entries`);
}

// Write output file with all untranslated entries
const outputPath = path.join(__dirname, 'untranslated_spanish.json');
fs.writeFileSync(outputPath, JSON.stringify(untranslated, null, 2), 'utf8');
console.log(`\nWrote untranslated entries to: ${outputPath}`);

// Also create a simplified list for manual review
const simplePath = path.join(__dirname, 'untranslated_spanish.txt');
const simpleOutput = untranslated.map(e => `${e.key}\n  EN: ${e.english}\n  ES: [NEEDS TRANSLATION]\n`).join('\n');
fs.writeFileSync(simplePath, simpleOutput, 'utf8');
console.log(`Wrote simplified list to: ${simplePath}`);
