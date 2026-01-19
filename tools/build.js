#!/usr/bin/env node
/**
 * UsedPlus ModHub Build Script
 * Creates a clean .zip file ready for ModHub submission
 *
 * Usage: node build.js
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const MOD_NAME = 'FS25_UsedPlus';
const SCRIPT_DIR = __dirname;
const MOD_DIR = path.dirname(SCRIPT_DIR);
const OUTPUT_DIR = path.join(MOD_DIR, 'dist');

// Patterns to exclude (relative paths)
const EXCLUDE_PATTERNS = [
    /\.png$/i,
    /\.psd$/i,
    /\.xcf$/i,
    /\.bak$/i,
    /\.log$/i,
    /\.md$/i,
    /\.py$/i,
    /^\.git/,
    /^\.vscode/,
    /^\.idea/,
    /^node_modules/,
    /^dist\//,
    /^\.build_temp/,
    /^tools\//,
    /^FS25_AI_Coding_Reference/,
    /^docs\//,
    /package\.json$/,
    /package-lock\.json$/,
    /\.translation-sync\.json$/,
    /icon_old\.dds\.bak$/,
];

function shouldExclude(relativePath) {
    const normalized = relativePath.replace(/\\/g, '/');
    return EXCLUDE_PATTERNS.some(pattern => pattern.test(normalized));
}

function getAllFiles(dir, baseDir = dir) {
    const files = [];
    const entries = fs.readdirSync(dir, { withFileTypes: true });

    for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        const relativePath = path.relative(baseDir, fullPath);

        if (shouldExclude(relativePath)) continue;

        if (entry.isDirectory()) {
            files.push(...getAllFiles(fullPath, baseDir));
        } else {
            files.push({ fullPath, relativePath });
        }
    }
    return files;
}

function getVersion() {
    const modDescPath = path.join(MOD_DIR, 'modDesc.xml');
    const content = fs.readFileSync(modDescPath, 'utf8');
    const match = content.match(/<version>([^<]+)<\/version>/);
    return match ? match[1] : 'unknown';
}

function getDateStamp() {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    return `${year}${month}${day}`;
}

function createZipWithPowerShell(files, outputPath) {
    const tempDir = path.join(require('os').tmpdir(), 'UsedPlus_Build_' + Date.now());
    fs.mkdirSync(tempDir, { recursive: true });

    for (const file of files) {
        const targetPath = path.join(tempDir, file.relativePath);
        const targetDir = path.dirname(targetPath);
        fs.mkdirSync(targetDir, { recursive: true });
        fs.copyFileSync(file.fullPath, targetPath);
    }

    if (fs.existsSync(outputPath)) {
        fs.unlinkSync(outputPath);
    }

    // Use PowerShell to create zip
    const psCommand = `Compress-Archive -Path '${tempDir.replace(/'/g, "''")}\\*' -DestinationPath '${outputPath.replace(/'/g, "''")}' -Force`;
    execSync(`powershell -Command "${psCommand}"`, { stdio: 'inherit' });

    // Cleanup
    fs.rmSync(tempDir, { recursive: true, force: true });

    return fs.statSync(outputPath).size;
}

function main() {
    console.log('');
    console.log('============================================');
    console.log('  UsedPlus ModHub Build Script');
    console.log('============================================');

    const version = getVersion();
    const dateStamp = getDateStamp();
    const zipName = `${MOD_NAME}_v${version}_${dateStamp}.zip`;
    const outputPath = path.join(OUTPUT_DIR, zipName);

    console.log(`  Version:  ${version}`);
    console.log(`  Date:     ${dateStamp}`);
    console.log(`  Output:   ${zipName}`);
    console.log('============================================');
    console.log('');

    // Create output directory
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });

    // Collect files
    console.log('Collecting files...');
    const files = getAllFiles(MOD_DIR);
    console.log(`  Found ${files.length} files to include`);
    console.log('');

    // Create zip
    console.log('Creating zip file...');
    const size = createZipWithPowerShell(files, outputPath);
    const sizeKB = (size / 1024).toFixed(2);
    const sizeMB = (size / 1024 / 1024).toFixed(2);

    console.log('');
    console.log('============================================');
    console.log('  Build Complete!');
    console.log('============================================');
    console.log(`  Output: ${outputPath}`);
    console.log(`  Size:   ${sizeKB} KB (${sizeMB} MB)`);
    console.log(`  Files:  ${files.length}`);
    console.log('============================================');
    console.log('');
    console.log('To test with GIANTS TestRunner:');
    console.log(`  TestRunner_public.exe "${outputPath}"`);
    console.log('');
}

main();
