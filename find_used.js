#!/usr/bin/env node
/**
 * find_used.js - Static analysis tool for FS25_UsedPlus Lua codebase
 *
 * Scans all Lua files to find potentially UNUSED:
 * - Functions (global and local)
 * - Methods (ClassName:method and ClassName.method)
 * - Classes
 *
 * Requirements: Node.js 14+ (no external dependencies)
 *
 * Usage:
 *   node find_used.js                    # Basic scan
 *   node find_used.js --verbose          # Show file locations
 *   node find_used.js --include-events   # Include FS25 callbacks
 *   node find_used.js --help             # Full help
 */

const fs = require('fs');
const path = require('path');

// ============================================================================
// CONFIGURATION
// ============================================================================

const SCAN_DIRS = ['src', 'gui'];
const LUA_EXTENSIONS = ['.lua'];

// FS25/Giants Engine lifecycle callbacks - called by engine, not our code
const FS25_CALLBACKS = new Set([
    // Vehicle specialization callbacks
    'prerequisitesPresent', 'initSpecialization', 'registerEventListeners',
    'registerOverwrittenFunctions', 'registerFunctions', 'onLoad', 'onPostLoad',
    'onLoadFinished', 'onPreDelete', 'onDelete', 'onReadStream', 'onWriteStream',
    'onUpdate', 'onUpdateTick', 'onDraw', 'onRegisterActionEvents',
    'onEnterVehicle', 'onLeaveVehicle', 'saveToXMLFile', 'loadFromXMLFile',

    // GUI callbacks
    'onOpen', 'onClose', 'onCreate', 'onClickBack', 'onClickActivate',
    'onGuiSetupFinished', 'onFrameOpen', 'onFrameClose',

    // Mission/Manager callbacks
    'loadMapFinished', 'loadMap', 'deleteMap', 'update', 'draw',
    'mouseEvent', 'keyEvent', 'onMissionLoaded',

    // Event callbacks
    'run', 'readStream', 'writeStream',
]);

// Patterns that indicate XML callback (onClick, etc.)
const XML_CALLBACK_PREFIXES = [
    'onClick', 'onFocus', 'onLeave', 'onHighlight', 'onCheck', 'onChange',
    'onButton', 'onPay', 'onInfo', 'onEdit', 'onRow', 'onSlider', 'onToggle',
    'onConfirm', 'onCancel', 'onAccept', 'onDecline', 'onSelect', 'onInput'
];

// Patterns for settings/config callbacks (commonly called via reflection)
const SETTINGS_CALLBACK_PATTERNS = [
    /Changed$/, /Toggle$/, /Confirm$/, /Selected$/
];

// Classes whose methods are intentionally public APIs for external mods
const API_CLASSES = new Set([
    'UsedPlusAPI',       // External mod integration API
]);

// Method name patterns that are DEFINITELY called via reflection/engine
// Keep this list conservative - we WANT to flag potentially unused helpers
const SPECIAL_METHOD_PATTERNS = [
    /^consoleCommand/,   // Game console commands (registered with engine)
    /^sendTo/,           // Network event sending (sendToServer, sendToFarm)
    /^send[A-Z].*To/,    // Other network patterns (sendAllToConnection, sendPresetToServer)
    /^hook/,             // Hook functions stored and called indirectly
    /^saveToXML/,        // Save system callback
    /^loadFromXML/,      // Save system callback
    /^loadMap/,          // Mission lifecycle
    /^deleteMap/,        // Mission lifecycle
    /^applyDelayed/,     // Timer callbacks (addTimer pattern)
];

// Classes that use FS25 extension/hook patterns (methods called by game, not our code)
const EXTENSION_CLASSES = new Set([
    'FarmlandManagerExtension',
    'FinanceMenuExtension',
    'InGameMenuMapFrameExtension',
    'InGameMenuVehiclesFrameExtension',
    'ShopConfigScreenExtension',
    'UsedPlusSettingsMenuExtension',
    'VehicleSellingPointExtension',
    'WorkshopScreenExtension',
]);

// Additional patterns for --strict mode (commonly false positives)
const LIKELY_CALLBACK_PATTERNS = [
    /^get[A-Z]/,         // Getters - often API methods
    /^set[A-Z]/,         // Setters - often dialog setup
    /^is[A-Z]/,          // Boolean checks - utility
    /^has[A-Z]/,         // Boolean checks - utility
    /^can[A-Z]/,         // Permission checks - utility
    /^should[A-Z]/,      // Conditional checks - utility
    /^calculate[A-Z]/,   // Calculations - utility
    /^format[A-Z]/,      // Formatting - utility
    /^update[A-Z]/,      // Update callbacks
    /^display[A-Z]/,     // Display helpers
    /^validate/,         // Validation
    /^process[A-Z]/,     // Processing callbacks
    /^generate[A-Z]/,    // Generation helpers
    /^create[A-Z]/,      // Creation helpers
    /^add[A-Z]/,         // Add helpers
    /^remove[A-Z]/,      // Remove helpers
    /^reset[A-Z]/,       // Reset helpers
    /^clear[A-Z]/,       // Clear helpers
    /^check[A-Z]/,       // Check helpers
    /^mark[A-Z]/,        // Mark helpers
    /^cleanup[A-Z]/,     // Cleanup callbacks
    /^inject[A-Z]/,      // Injection helpers
    /^reorder[A-Z]/,     // Reorder helpers
    /^focus[A-Z]/,       // Focus helpers
    /^complete[A-Z]/,    // Completion handlers
    /^meets[A-Z]/,       // Requirement checks
    /^estimate[A-Z]/,    // Estimation helpers
    /^recalculate/,      // Recalculation
];

// ============================================================================
// FILE UTILITIES
// ============================================================================

function findLuaFiles(baseDir) {
    const luaFiles = [];

    function walkDir(dir) {
        if (!fs.existsSync(dir)) return;

        const entries = fs.readdirSync(dir, { withFileTypes: true });
        for (const entry of entries) {
            const fullPath = path.join(dir, entry.name);
            if (entry.isDirectory()) {
                walkDir(fullPath);
            } else if (LUA_EXTENSIONS.includes(path.extname(entry.name).toLowerCase())) {
                luaFiles.push(fullPath);
            }
        }
    }

    // Scan configured directories
    for (const scanDir of SCAN_DIRS) {
        walkDir(path.join(baseDir, scanDir));
    }

    // Also check root for .lua files
    const rootEntries = fs.readdirSync(baseDir, { withFileTypes: true });
    for (const entry of rootEntries) {
        if (entry.isFile() && LUA_EXTENSIONS.includes(path.extname(entry.name).toLowerCase())) {
            luaFiles.push(path.join(baseDir, entry.name));
        }
    }

    return [...new Set(luaFiles)].sort();
}

function findXmlFiles(baseDir) {
    const xmlFiles = [];

    function walkDir(dir) {
        if (!fs.existsSync(dir)) return;

        const entries = fs.readdirSync(dir, { withFileTypes: true });
        for (const entry of entries) {
            const fullPath = path.join(dir, entry.name);
            if (entry.isDirectory()) {
                walkDir(fullPath);
            } else if (entry.name.endsWith('.xml')) {
                xmlFiles.push(fullPath);
            }
        }
    }

    walkDir(baseDir);
    return xmlFiles;
}

// ============================================================================
// DEFINITION EXTRACTION
// ============================================================================

function extractDefinitions(filePath, content) {
    const definitions = {
        globalFunctions: [],
        localFunctions: [],
        classMethods: [],
        classes: [],
    };

    const fileName = path.basename(filePath);
    const lines = content.split('\n');

    // Pattern: function GlobalName(...)
    const globalFuncPattern = /^function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/gm;
    let match;

    while ((match = globalFuncPattern.exec(content)) !== null) {
        const lineNum = content.substring(0, match.index).split('\n').length;
        definitions.globalFunctions.push({
            name: match[1],
            file: fileName,
            line: lineNum,
            fullName: match[1]
        });
    }

    // Pattern: local function localName(...)
    const localFuncPattern = /local\s+function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/gm;
    while ((match = localFuncPattern.exec(content)) !== null) {
        const lineNum = content.substring(0, match.index).split('\n').length;
        definitions.localFunctions.push({
            name: match[1],
            file: fileName,
            line: lineNum,
            fullName: `local ${match[1]}`
        });
    }

    // Pattern: function ClassName.methodName(...) or function ClassName:methodName(...)
    const classMethodPattern = /^function\s+([A-Za-z_][A-Za-z0-9_]*)[.:]\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(/gm;
    while ((match = classMethodPattern.exec(content)) !== null) {
        const lineNum = content.substring(0, match.index).split('\n').length;
        definitions.classMethods.push({
            name: match[2],
            className: match[1],
            file: fileName,
            line: lineNum,
            fullName: `${match[1]}:${match[2]}`
        });
    }

    // Pattern: ClassName.methodName = function(...)
    const assignedMethodPattern = /^([A-Za-z_][A-Za-z0-9_]*)\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*function\s*\(/gm;
    while ((match = assignedMethodPattern.exec(content)) !== null) {
        const lineNum = content.substring(0, match.index).split('\n').length;
        definitions.classMethods.push({
            name: match[2],
            className: match[1],
            file: fileName,
            line: lineNum,
            fullName: `${match[1]}.${match[2]}`
        });
    }

    // Pattern: ClassName = {} (class definition)
    const classDefPattern = /^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\{\s*\}/gm;
    while ((match = classDefPattern.exec(content)) !== null) {
        const lineNum = content.substring(0, match.index).split('\n').length;
        definitions.classes.push({
            name: match[1],
            file: fileName,
            line: lineNum
        });
    }

    return definitions;
}

// ============================================================================
// REFERENCE FINDING
// ============================================================================

function countReferences(content, name) {
    const pattern = new RegExp(`\\b${escapeRegex(name)}\\b`, 'g');
    const matches = content.match(pattern);
    return matches ? matches.length : 0;
}

function countMethodCalls(content, methodName) {
    // Match :methodName( or .methodName(
    const pattern = new RegExp(`[.:]${escapeRegex(methodName)}\\s*\\(`, 'g');
    const matches = content.match(pattern);
    return matches ? matches.length : 0;
}

function escapeRegex(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// ============================================================================
// ANALYSIS
// ============================================================================

function isCallbackFunction(funcName, options = {}, className = null) {
    const { includeEvents = false, strict = false } = options;

    if (!includeEvents && FS25_CALLBACKS.has(funcName)) {
        return true;
    }

    // Check if method belongs to a public API class
    if (className && API_CLASSES.has(className)) {
        return true;
    }

    // Check if method belongs to an Extension class (FS25 hooks)
    if (className && EXTENSION_CLASSES.has(className)) {
        return true;
    }

    // Check XML callback prefixes
    for (const prefix of XML_CALLBACK_PREFIXES) {
        if (funcName.startsWith(prefix)) {
            return true;
        }
    }

    // Check settings callback patterns (commonly called via reflection/XML)
    for (const pattern of SETTINGS_CALLBACK_PATTERNS) {
        if (pattern.test(funcName)) {
            return true;
        }
    }

    // Check special method patterns (engine callbacks, networking, etc.)
    for (const pattern of SPECIAL_METHOD_PATTERNS) {
        if (pattern.test(funcName)) {
            return true;
        }
    }

    // In strict mode, also exclude likely callback patterns (more filtering)
    if (strict) {
        for (const pattern of LIKELY_CALLBACK_PATTERNS) {
            if (pattern.test(funcName)) {
                return true;
            }
        }
    }

    return false;
}

function analyzeCodebase(baseDir, options = {}) {
    const { includeEvents = false, verbose = false, strict = false } = options;
    const callbackOptions = { includeEvents, strict };

    const luaFiles = findLuaFiles(baseDir);
    const xmlFiles = findXmlFiles(baseDir);

    if (luaFiles.length === 0) {
        console.log(`No Lua files found in ${baseDir}`);
        return null;
    }

    console.log(`Scanning ${luaFiles.length} Lua files...`);

    // Collect all definitions
    const allDefinitions = {
        globalFunctions: [],
        localFunctions: [],
        classMethods: [],
        classes: [],
    };

    // Read all file contents
    const fileContents = new Map();

    for (const filePath of luaFiles) {
        try {
            const content = fs.readFileSync(filePath, 'utf-8');
            fileContents.set(filePath, content);

            const defs = extractDefinitions(filePath, content);
            allDefinitions.globalFunctions.push(...defs.globalFunctions);
            allDefinitions.localFunctions.push(...defs.localFunctions);
            allDefinitions.classMethods.push(...defs.classMethods);
            allDefinitions.classes.push(...defs.classes);
        } catch (err) {
            console.error(`Error reading ${filePath}: ${err.message}`);
        }
    }

    // Combine all Lua content
    const allLuaContent = [...fileContents.values()].join('\n');

    // Read XML content for onClick references
    let allXmlContent = '';
    for (const xmlFile of xmlFiles) {
        try {
            allXmlContent += fs.readFileSync(xmlFile, 'utf-8') + '\n';
        } catch (err) {
            // Ignore XML read errors
        }
    }

    // Results
    const results = {
        unusedGlobalFunctions: [],
        unusedLocalFunctions: [],
        unusedClassMethods: [],
        unusedClasses: [],
        totalDefinitions: 0,
        totalUnused: 0,
    };

    // Check global functions
    for (const func of allDefinitions.globalFunctions) {
        results.totalDefinitions++;

        if (isCallbackFunction(func.name, callbackOptions)) continue;

        const refs = countReferences(allLuaContent, func.name);
        const xmlRefs = countReferences(allXmlContent, func.name);

        if (refs + xmlRefs <= 1) {
            results.unusedGlobalFunctions.push(func);
            results.totalUnused++;
        }
    }

    // Check class methods
    for (const method of allDefinitions.classMethods) {
        results.totalDefinitions++;

        if (isCallbackFunction(method.name, callbackOptions, method.className)) continue;

        const methodCalls = countMethodCalls(allLuaContent, method.name);
        const xmlRefs = countReferences(allXmlContent, method.name);

        if (methodCalls + xmlRefs <= 1) {
            results.unusedClassMethods.push(method);
            results.totalUnused++;
        }
    }

    // Check local functions (only in their own file)
    for (const func of allDefinitions.localFunctions) {
        results.totalDefinitions++;

        if (isCallbackFunction(func.name, callbackOptions)) continue;

        // Find the file content
        let fileContent = null;
        for (const [fp, content] of fileContents) {
            if (path.basename(fp) === func.file) {
                fileContent = content;
                break;
            }
        }

        if (fileContent) {
            const refs = countReferences(fileContent, func.name);
            if (refs <= 1) {
                results.unusedLocalFunctions.push(func);
                results.totalUnused++;
            }
        }
    }

    // Check classes
    for (const cls of allDefinitions.classes) {
        results.totalDefinitions++;

        const refs = countReferences(allLuaContent, cls.name);
        const hasMethods = allDefinitions.classMethods.some(m => m.className === cls.name);

        if (refs <= 2 && !hasMethods) {
            results.unusedClasses.push(cls);
            results.totalUnused++;
        }
    }

    return results;
}

// ============================================================================
// OUTPUT
// ============================================================================

function printResults(results, verbose = false) {
    console.log('\n' + '='.repeat(70));
    console.log('UNUSED CODE ANALYSIS RESULTS');
    console.log('='.repeat(70));

    console.log(`\nTotal definitions scanned: ${results.totalDefinitions}`);
    console.log(`Potentially unused: ${results.totalUnused}`);

    if (results.unusedGlobalFunctions.length > 0) {
        console.log(`\n${'─'.repeat(70)}`);
        console.log(`UNUSED GLOBAL FUNCTIONS (${results.unusedGlobalFunctions.length})`);
        console.log('─'.repeat(70));

        for (const func of results.unusedGlobalFunctions.sort((a, b) => a.file.localeCompare(b.file))) {
            console.log(`  ${func.fullName}`);
            if (verbose) {
                console.log(`    └─ ${func.file}:${func.line}`);
            }
        }
    }

    if (results.unusedClassMethods.length > 0) {
        console.log(`\n${'─'.repeat(70)}`);
        console.log(`UNUSED CLASS METHODS (${results.unusedClassMethods.length})`);
        console.log('─'.repeat(70));

        // Group by class
        const byClass = new Map();
        for (const method of results.unusedClassMethods) {
            if (!byClass.has(method.className)) {
                byClass.set(method.className, []);
            }
            byClass.get(method.className).push(method);
        }

        for (const [className, methods] of [...byClass.entries()].sort()) {
            console.log(`\n  ${className}:`);
            for (const method of methods.sort((a, b) => a.name.localeCompare(b.name))) {
                console.log(`    - ${method.name}()`);
                if (verbose) {
                    console.log(`      └─ ${method.file}:${method.line}`);
                }
            }
        }
    }

    if (results.unusedLocalFunctions.length > 0) {
        console.log(`\n${'─'.repeat(70)}`);
        console.log(`UNUSED LOCAL FUNCTIONS (${results.unusedLocalFunctions.length})`);
        console.log('─'.repeat(70));

        // Group by file
        const byFile = new Map();
        for (const func of results.unusedLocalFunctions) {
            if (!byFile.has(func.file)) {
                byFile.set(func.file, []);
            }
            byFile.get(func.file).push(func);
        }

        for (const [fileName, funcs] of [...byFile.entries()].sort()) {
            console.log(`\n  ${fileName}:`);
            for (const func of funcs.sort((a, b) => a.line - b.line)) {
                console.log(`    - ${func.name}() [line ${func.line}]`);
            }
        }
    }

    if (results.unusedClasses.length > 0) {
        console.log(`\n${'─'.repeat(70)}`);
        console.log(`UNUSED CLASSES (${results.unusedClasses.length})`);
        console.log('─'.repeat(70));

        for (const cls of results.unusedClasses.sort((a, b) => a.name.localeCompare(b.name))) {
            console.log(`  ${cls.name}`);
            if (verbose) {
                console.log(`    └─ ${cls.file}:${cls.line}`);
            }
        }
    }

    if (results.totalUnused === 0) {
        console.log('\n✓ No unused code detected!');
    } else {
        console.log(`\n⚠ Found ${results.totalUnused} potentially unused definitions`);
        console.log('\nNote: Some may be false positives (called via metatable, reflection, etc.)');
    }

    console.log('\n' + '='.repeat(70));
}

// ============================================================================
// MAIN
// ============================================================================

function printHelp() {
    console.log(`
find_used.js - Find unused code in FS25_UsedPlus Lua codebase

Usage: node find_used.js [options]

Options:
  --verbose, -v      Show detailed output including file locations
  --strict, -s       Strict mode - exclude common patterns (get*, set*, is*, etc.)
                     Shows only unusual method names that are likely truly unused
  --include-events   Include FS25 event callbacks in analysis (normally excluded)
  --help, -h         Show this help message

Examples:
  node find_used.js                    # Basic scan (~100-150 items)
  node find_used.js --strict           # High-confidence only (~20-40 items)
  node find_used.js --verbose          # Show file:line for each finding
  node find_used.js --include-events   # Also check FS25 lifecycle callbacks
`);
}

function main() {
    const args = process.argv.slice(2);

    const options = {
        verbose: args.includes('--verbose') || args.includes('-v'),
        strict: args.includes('--strict') || args.includes('-s'),
        includeEvents: args.includes('--include-events'),
    };

    if (args.includes('--help') || args.includes('-h')) {
        printHelp();
        process.exit(0);
    }

    const baseDir = __dirname;

    console.log(`Analyzing: ${baseDir}`);
    console.log(`Options: verbose=${options.verbose}, strict=${options.strict}, includeEvents=${options.includeEvents}`);

    const results = analyzeCodebase(baseDir, options);

    if (results) {
        printResults(results, options.verbose);
        process.exit(results.totalUnused > 0 ? 1 : 0);
    } else {
        process.exit(1);
    }
}

main();
