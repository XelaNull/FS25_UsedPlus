# TestRunner Fixes Plan

**Created:** 2026-01-26
**Target:** v2.9.6 release
**Status:** Ready for tomorrow's session

---

## Overview

GIANTS TestRunner v0.9.13 identified 7 failing modules. This plan addresses each issue in priority order.

---

## Issue 1: ModDescCheck - Version Format (5 minutes)

### Problem
```
error: version number '2.9.5' does not match schema 'a.b.c.d' (with 'a' at least 1)
```

### Fix
```xml
<!-- modDesc.xml line ~4 -->
<version>2.9.5.0</version>
```

### Files
- `modDesc.xml`

### Verification
Re-run TestRunner, ModDescCheck should pass.

---

## Issue 2: DXTCheck - Invalid Compression (15 minutes)

### Problem
2 DDS files using deprecated DXT3 compression (should be DXT5):
- `vehicles/serviceTruck/textures/Smoked.dds`
- `vehicles/serviceTruck/wheels/front_logo.dds`

### Fix Options

**Option A: GIANTS Texture Tool (Recommended)**
```bash
# Convert DXT3 to DXT5
"C:\Program Files\GIANTS Software\GIANTS_Editor_10.0.11\tools\textureTool.exe" -convert -format DXT5 "vehicles/serviceTruck/textures/Smoked.dds"
"C:\Program Files\GIANTS Software\GIANTS_Editor_10.0.11\tools\textureTool.exe" -convert -format DXT5 "vehicles/serviceTruck/wheels/front_logo.dds"
```

**Option B: Export from GIANTS Editor**
1. Open each texture in GIANTS Editor
2. Export as DDS with DXT5 compression

### Files
- `vehicles/serviceTruck/textures/Smoked.dds`
- `vehicles/serviceTruck/wheels/front_logo.dds`

### Also Noted (Optimization)
- `batterie_UV.dds` uses DXT5 but could use DXT1 (no alpha needed) - optional optimization

---

## Issue 3: MipMapCheck - Missing Mipmaps (30 minutes)

### Problem
20 Service Truck textures missing mipmaps:

| File | Used In |
|------|---------|
| blur.dds | C7000.i3d |
| Black.dds | C7000.i3d |
| gasolineCan_diffuse.dds | C7000.i3d |
| IDLE.dds | C7000.i3d |
| gen_dirt_1.dds | C7000.i3d |
| gen_wear_dirt_2.dds | C7000.i3d, wheels1.i3d |
| LP_Squarebody_dashboard.dds | C7000.i3d |
| display.dds | C7000.i3d |
| redglass22.dds | C7000.i3d |
| RadioAlpine.dds | C7000.i3d |
| Smoked.dds | C7000.i3d |
| Unknown-1.dds | C7000.i3d |
| window1.dds | C7000.i3d |
| window_lightdiffuse.dds | C7000.i3d |
| Windshield_Dirty.dds | C7000.i3d |
| window_light_tint.dds | C7000.i3d |
| wheels_specular.dds | wheels1.i3d |
| wheels_specular_1.dds | wheels1.i3d |
| wheels_specular_12.dds | wheels1.i3d |
| batterie_UV.dds | C7000.i3d |

### Fix
```bash
# Generate mipmaps for each file
cd "C:\github\FS25_UsedPlus\vehicles\serviceTruck\textures"
for %f in (*.dds) do "C:\Program Files\GIANTS Software\GIANTS_Editor_10.0.11\tools\textureTool.exe" -mipmap "%f"
```

Or create a batch script:
```batch
@echo off
set TOOL="C:\Program Files\GIANTS Software\GIANTS_Editor_10.0.11\tools\textureTool.exe"
cd /d "C:\github\FS25_UsedPlus\vehicles\serviceTruck\textures"
for %%f in (*.dds) do %TOOL% -mipmap "%%f"
cd /d "C:\github\FS25_UsedPlus\vehicles\serviceTruck\wheels"
for %%f in (*.dds) do %TOOL% -mipmap "%%f"
echo Done!
pause
```

### Files
- All 20 DDS files listed above

---

## Issue 4: TextureCheck - Non-Power-of-2 Dimensions (Low Priority)

### Problem (Warnings, not errors)
| File | Dimensions | Issue |
|------|------------|-------|
| RadioAlpine.dds | 2136x2136 | Not power of 2 |
| Unknown-1.dds | 412x124 | Not power of 2 |
| Windshield_Dirty.dds | 1536x? | Width not power of 2 |

### Fix Options
1. **Resize textures** to nearest power of 2 (2048x2048, 512x128, 2048x?)
2. **Leave as-is** - these are warnings, not errors, and work in-game

### Recommendation
Low priority - address only if time permits. These warnings don't affect gameplay.

---

## Issue 5: VehicleCheck (Investigation Needed)

### Problem
TestRunner reported VehicleCheck failed but didn't show specific errors in the excerpt.

### Investigation Steps
1. Open full HTML report: `C:\Users\mrath\Downloads\TestRunner_FS25\testResult_FS25_UsedPlus_FAIL.html`
2. Search for "VehicleCheck" section
3. Document specific errors

### Likely Issues
- Missing wheel XML: `wheels/wheels1.xml` referenced but file might be missing
- Vehicle configuration validation

---

## Issue 6: EditorCheck - I3D Errors (Investigation Needed)

### Problem
```
found 4 errors in 3 i3d file(s)
```

### Investigation Steps
1. Open HTML report
2. Find EditorCheck section
3. Document which i3d files have errors and what the errors are

### Likely Files
- `vehicles/serviceTruck/C7000.i3d`
- `vehicles/serviceTruck/wheels/wheels1.i3d`
- `vehicles/fieldServiceKit/fieldServiceKit.i3d` or `placeables/oilServicePoint.i3d`

---

## Issue 7: ShaderCheckEditor (Investigation Needed)

### Problem
Shader validation failed - need to check HTML report for details.

### Investigation Steps
1. Open HTML report
2. Find ShaderCheckEditor section
3. Document shader issues

---

## Issue 8: ObsoleteFiles - node_modules (Cleanup)

### Problem
TestRunner detected `node_modules/` folder which shouldn't be in the mod.

### Fix
The build script already excludes node_modules from the ZIP. This is only an issue when running TestRunner directly on the source folder.

### Options
1. **Ignore** - ZIP doesn't include it anyway
2. **Add to .gitignore** - Already should be there
3. **Run TestRunner on built ZIP** instead of source folder

### Recommendation
No action needed - this only affects TestRunner on source, not the distributed mod.

---

## Execution Order

### Phase 1: Quick Wins (10 minutes)
- [ ] Fix version format in modDesc.xml (`2.9.5` → `2.9.5.0`)
- [ ] Re-run TestRunner to confirm ModDescCheck passes

### Phase 2: Investigation (15 minutes)
- [ ] Open HTML report in browser
- [ ] Document VehicleCheck errors
- [ ] Document EditorCheck errors (4 errors in 3 files)
- [ ] Document ShaderCheckEditor errors

### Phase 3: Texture Fixes (45 minutes)
- [ ] Convert 2 DXT3 files to DXT5
- [ ] Generate mipmaps for 20 files
- [ ] Re-run TestRunner

### Phase 4: I3D/Vehicle Fixes (Time TBD)
- [ ] Address EditorCheck errors based on investigation
- [ ] Address VehicleCheck errors based on investigation
- [ ] Address ShaderCheckEditor errors based on investigation

### Phase 5: Final Verification
- [ ] Run TestRunner on source folder
- [ ] Run `node tools/build.js`
- [ ] Run TestRunner on built ZIP
- [ ] Commit fixes

---

## Tools Required

| Tool | Path | Purpose |
|------|------|---------|
| GIANTS Texture Tool | `C:\Program Files\GIANTS Software\GIANTS_Editor_10.0.11\tools\textureTool.exe` | DDS conversion, mipmap generation |
| GIANTS Editor | `C:\Program Files\GIANTS Software\GIANTS_Editor_10.0.11\editor.exe` | I3D inspection/fixes |
| TestRunner | `C:\Users\mrath\Downloads\TestRunner_FS25\TestRunner_public.exe` | Validation |

---

## Notes

- Service Truck model is from **Canada FS** (GMC C7000 Service 81-89 v1.0)
- Most texture issues are inherited from the original model
- These are quality/optimization issues, not functionality blockers
- The mod works correctly in-game despite these warnings

---

*Plan created: 2026-01-26 01:35*
*Author: Claude & Samantha*
