# FS25 Mod Icon Generation Guide

This guide explains how to create programmatically-generated icons for Farming Simulator 25 mods using Node.js and Sharp.

## The Problem

FS25 mods distributed as ZIP files cannot load images specified in XML attributes:
- `imageFilename="gui/icons/myicon.png"` - **FAILS**
- `filename="$moddir$gui/icons/myicon.png"` - **FAILS** (shows corrupted texture atlas)

The game engine cannot resolve paths to images inside ZIP archives when specified in XML.

## The Solution

Set image paths dynamically via Lua using `setImageFilename()`:

1. Create Bitmap elements in XML with an `id` attribute but NO filename
2. In Lua (onCreate or initialization), set the image path using `MOD_DIR`

This works because Lua has access to the full mod directory path at runtime.

---

## Quick Start

### Prerequisites

```bash
# Node.js 16+ required
npm install sharp
```

### Basic Icon Generator Script

Create `tools/generateIcons.js`:

```javascript
const sharp = require('sharp');
const path = require('path');
const fs = require('fs');

// Output directory (relative to script location)
const OUTPUT_DIR = path.join(__dirname, '..', 'gui', 'icons');

// Ensure output directory exists
if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

// Color palette
const COLORS = {
    white: '#FFFFFF',
    green: '#4CAF50',
    greenDark: '#388E3C',
    red: '#F44336',
    redDark: '#D32F2F',
    orange: '#FF9800',
    orangeDark: '#F57C00',
    blue: '#2196F3',
    blueDark: '#1976D2',
    gray: '#757575',
    grayDark: '#616161'
};

// Icon definitions
const ICONS = {
    my_icon: {
        name: 'my_icon',
        bgColor: COLORS.green,
        bgColorDark: COLORS.greenDark,
        svg: (size) => `
            <svg width="${size}" height="${size}" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
                <defs>
                    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
                        <stop offset="0%" style="stop-color:${COLORS.green}"/>
                        <stop offset="100%" style="stop-color:${COLORS.greenDark}"/>
                    </linearGradient>
                </defs>
                <rect width="64" height="64" rx="8" fill="url(#bg)"/>
                <!-- Your icon graphics here -->
                <circle cx="32" cy="32" r="16" fill="${COLORS.white}"/>
            </svg>`
    }
};

// Generate icons
async function generateIcons() {
    const SIZE = 256;  // Output size in pixels

    for (const [key, icon] of Object.entries(ICONS)) {
        const svgContent = icon.svg(SIZE);
        const outputPath = path.join(OUTPUT_DIR, `${icon.name}.png`);

        await sharp(Buffer.from(svgContent))
            .resize(SIZE, SIZE)
            .png()
            .toFile(outputPath);

        console.log(`Generated: ${icon.name}.png`);
    }
}

generateIcons().catch(console.error);
```

Run: `cd tools && node generateIcons.js`

---

## Icon Design Pattern

### SVG Structure

All icons follow a consistent pattern:

```xml
<svg width="${size}" height="${size}" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
    <!-- 1. Gradient definition -->
    <defs>
        <linearGradient id="uniqueId" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" style="stop-color:#LIGHTCOLOR"/>
            <stop offset="100%" style="stop-color:#DARKCOLOR"/>
        </linearGradient>
    </defs>

    <!-- 2. Background rectangle with rounded corners -->
    <rect width="64" height="64" rx="8" fill="url(#uniqueId)"/>

    <!-- 3. Icon graphics (white for contrast) -->
    <g fill="none" stroke="#FFFFFF" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
        <!-- Your shapes here -->
    </g>
</svg>
```

### Key Design Principles

1. **ViewBox**: Always use `viewBox="0 0 64 64"` for consistent scaling
2. **Background**: Rounded rectangle (`rx="8"`) with gradient
3. **Gradient IDs**: Must be UNIQUE per icon (e.g., `bgEngine`, `bgFinance`)
4. **Icon Graphics**: White (`#FFFFFF`) for maximum contrast
5. **Stroke Style**: `stroke-linecap="round"` and `stroke-linejoin="round"` for polished look

### Output Size

- Generate at **256x256 pixels** for crisp rendering
- Display at smaller sizes (20px-48px) in the game
- Sharp automatically handles downscaling with anti-aliasing

---

## XML Integration

### 1. Create Icon Profiles

Add to your dialog's `<GUIProfiles>` section:

```xml
<GUIProfiles>
    <!-- Small inline icons (status badges) -->
    <Profile name="iconProfile20" extends="baseReference">
        <size value="20px 20px"/>
        <imageSliceId value="noSlice"/>
    </Profile>

    <!-- Medium icons (section headers) -->
    <Profile name="iconProfile24" extends="baseReference">
        <size value="24px 24px"/>
        <imageSliceId value="noSlice"/>
    </Profile>

    <!-- Large icons (hero displays) -->
    <Profile name="iconProfile40" extends="baseReference">
        <size value="40px 40px"/>
        <imageSliceId value="noSlice"/>
    </Profile>
</GUIProfiles>
```

**Critical attributes:**
- `extends="baseReference"` - Required for proper image rendering
- `imageSliceId value="noSlice"` - Prevents texture atlas slicing

### 2. Add Bitmap Elements

```xml
<!-- NO filename attribute! Just profile and id -->
<Bitmap profile="iconProfile24" id="myIconElement" position="10px 8px"/>
```

---

## Lua Integration

### Setting Icons in onCreate/onGuiSetupFinished

```lua
function MyDialog:setupIcons()
    local iconDir = MyMod.MOD_DIR .. "gui/icons/"

    if self.myIconElement ~= nil then
        self.myIconElement:setImageFilename(iconDir .. "my_icon.png")
    end
end
```

### Setting Icons Dynamically (per row/status)

```lua
function MyDialog:updateRowIcon(iconElement, status)
    local iconDir = MyMod.MOD_DIR .. "gui/icons/"

    if iconElement == nil then return end

    if status == "GOOD" then
        iconElement:setImageFilename(iconDir .. "status_good.png")
    elseif status == "WARNING" then
        iconElement:setImageFilename(iconDir .. "status_warning.png")
    else
        iconElement:setImageFilename(iconDir .. "status_bad.png")
    end
end
```

---

## Build Script Integration

Ensure your build script includes PNG files from the icons directory:

```javascript
// In build.js
const filesToInclude = [
    // ... other files
    'gui/icons/*.png'  // Include all generated icons
];
```

---

## Icon Design Examples

### Status Icons (Circle + Symbol)

```javascript
// Status Good - Green circle with checkmark
status_good: {
    svg: (size) => `
        <svg width="${size}" height="${size}" viewBox="0 0 64 64">
            <defs>
                <linearGradient id="bgGood" x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%" style="stop-color:#4CAF50"/>
                    <stop offset="100%" style="stop-color:#388E3C"/>
                </linearGradient>
            </defs>
            <rect width="64" height="64" rx="8" fill="url(#bgGood)"/>
            <circle cx="32" cy="32" r="20" fill="none" stroke="#FFF" stroke-width="3"/>
            <polyline points="22,32 28,38 42,24" fill="none" stroke="#FFF"
                      stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>`
}
```

### Navigation Arrows

```javascript
// Arrow Right - Gray background with chevron
arrow_right: {
    svg: (size) => `
        <svg width="${size}" height="${size}" viewBox="0 0 64 64">
            <defs>
                <linearGradient id="bgArrow" x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%" style="stop-color:#757575"/>
                    <stop offset="100%" style="stop-color:#616161"/>
                </linearGradient>
            </defs>
            <rect width="64" height="64" rx="8" fill="url(#bgArrow)"/>
            <polyline points="26,14 42,32 26,50" fill="none" stroke="#FFF"
                      stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>`
}
```

### System/Category Icons (Complex Shapes)

```javascript
// Engine System - Piston/gear representation
sys_engine: {
    svg: (size) => `
        <svg width="${size}" height="${size}" viewBox="0 0 64 64">
            <defs>
                <linearGradient id="bgEngine" x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%" style="stop-color:#607D8B"/>
                    <stop offset="100%" style="stop-color:#455A64"/>
                </linearGradient>
            </defs>
            <rect width="64" height="64" rx="8" fill="url(#bgEngine)"/>
            <g transform="translate(12, 12)" fill="none" stroke="#FFF"
               stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <rect x="8" y="12" width="24" height="20" rx="2"/>
                <line x1="20" y1="2" x2="20" y2="12"/>
                <circle cx="20" cy="22" r="6"/>
                <line x1="20" y1="32" x2="20" y2="38"/>
            </g>
        </svg>`
}
```

---

## Color Guidelines

### Semantic Colors

| Purpose | Primary | Dark (Gradient End) |
|---------|---------|---------------------|
| Success/Good | `#4CAF50` | `#388E3C` |
| Warning/Attention | `#FF9800` | `#F57C00` |
| Error/Bad | `#F44336` | `#D32F2F` |
| Info/Neutral | `#2196F3` | `#1976D2` |
| Inactive/Disabled | `#757575` | `#616161` |

### Specialty Colors

| Purpose | Primary | Dark |
|---------|---------|------|
| Finance/Money | `#4CAF50` | `#388E3C` |
| Gold/Premium | `#FFB300` | `#FF8F00` |
| Purple/Lease | `#9C27B0` | `#7B1FA2` |
| Teal/Trade | `#009688` | `#00796B` |

---

## Accessibility

### Colorblind Considerations

Always use **shape + color** together:
- Checkmark = Good (not just green)
- X = Bad (not just red)
- ! = Warning (not just orange)
- Clock = Pending (not just blue)

This ensures icons remain distinguishable even without color perception.

### Contrast

- Icon graphics should always be white (`#FFFFFF`) or near-white
- Background gradients should have sufficient darkness for contrast
- Test at small sizes (20px) to ensure readability

---

## Troubleshooting

### Icon Not Showing

1. Check profile has `imageSliceId value="noSlice"`
2. Check profile `extends="baseReference"`
3. Verify icon element exists: `if self.myIcon ~= nil then`
4. Check MOD_DIR path includes trailing slash

### Icon Shows as White/Blank Square

- Missing `imageSliceId value="noSlice"` in profile
- The engine is trying to slice it as a texture atlas

### Icon Shows Corrupted

- Trying to use XML path instead of Lua setImageFilename
- Check that the PNG was generated correctly (open in image viewer)

### Gradient Not Showing

- Gradient ID collision (using same ID in multiple icons)
- Each icon must have a UNIQUE gradient ID

---

## File Structure

```
your_mod/
├── gui/
│   ├── icons/              # Generated PNG files (256x256)
│   │   ├── finance.png
│   │   ├── status_good.png
│   │   └── ...
│   └── YourDialog.xml      # References icons via Bitmap elements
├── src/
│   └── gui/
│       └── YourDialog.lua  # Sets icons via setImageFilename()
└── tools/
    └── generateIcons.js    # Icon generator script
```

---

## Reference Implementation

See these files in FS25_UsedPlus for working examples:

- **Icon Generator**: `tools/generateIcons.js`
- **XML Profiles**: `gui/FinanceManagerFrame.xml` (GUIProfiles section)
- **Lua Setup**: `src/gui/FinanceManagerFrame.lua` (setupSectionIcons function)

---

*Document Version: 1.0 | Created: 2026-01-25 | FS25_UsedPlus v2.8.0*
