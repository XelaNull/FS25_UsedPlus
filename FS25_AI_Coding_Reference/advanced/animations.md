# Multi-State Animation Patterns

**Complex animations with translation, rotation, scale, and visibility**

Based on patterns from: betterLights, BarnWithShelter, AutomaticCarWash

---

> ⚠️ **REFERENCE ONLY - NOT VALIDATED IN FS25_UsedPlus**
>
> These animation patterns were extracted from community mods but are **NOT used in UsedPlus**.
> The OilServicePoint and FieldServiceKit placeables are static (no animated parts).
>
> **Source Mods for Reference:**
> - `FS25_Mods_Extracted/AutomaticCarWash/` - Gate and door animations
> - `FS25_Mods_Extracted/BarnWithShelter/` - Sliding door animations
> - `FS25_Mods_Extracted/betterLights/` - Light state animations
>
> **EXPLORE:** Listed in `docs/PATTERNS_TO_EXPLORE.md` as medium-effort enhancement
> for OilServicePoint (garage doors, vehicle lifts).

---

## Overview

AnimatedObjects support multiple keyframe types that can be combined:
- **Translation** - Move objects in 3D space
- **Rotation** - Rotate objects
- **Scale** - Resize objects
- **Visibility** - Show/hide objects

---

## Multi-Part Animation Example

### Complex Animation with All Types

```xml
<animatedObjects>
    <animatedObject saveId="post">
        <animation duration="2">
            <!-- Translation animation -->
            <part node="post">
                <keyFrame time="0.00" translation="0 -0.008 0" />
                <keyFrame time="1.00" translation="0 3.973 0" />
            </part>

            <!-- Visibility toggle (delayed) -->
            <part node="postUp">
                <keyFrame time="0.00" visibility="false" />
                <keyFrame time="0.99" visibility="false" />
                <keyFrame time="1.00" visibility="true" />
            </part>
            <part node="postDown">
                <keyFrame time="0.00" visibility="true" />
                <keyFrame time="0.99" visibility="true" />
                <keyFrame time="1.00" visibility="false" />
            </part>

            <!-- Rotation animation (with start/end holds) -->
            <part node="rollHolder_L">
                <keyFrame time="0.00" rotation="0 0 0" />
                <keyFrame time="0.03" rotation="0 0 0" />
                <keyFrame time="0.97" rotation="0 72000 0" />
                <keyFrame time="1.00" rotation="0 72000 0" />
            </part>

            <!-- Scale animation (expand then contract) -->
            <part node="roll_L">
                <keyFrame time="0.00" scale="1 1 1" />
                <keyFrame time="0.04" scale="2 1 2" />
                <keyFrame time="0.96" scale="2 1 2" />
                <keyFrame time="1.00" scale="1 1 1" />
            </part>
        </animation>

        <!-- User controls -->
        <controls triggerNode="startTrigger" posAction="ACTIVATE_HANDTOOL"
                  posText="action_movePostUp" negText="action_movePostDown" />

        <!-- Sound effects at keyframes -->
        <sounds>
            <moving template="machineryHum" />
            <posEnd template="gateOpen" />
            <negEnd template="gateClose" />
        </sounds>
    </animatedObject>
</animatedObjects>
```

---

## Animation Timing Patterns

### Hold at Start/End

Use duplicate keyframes to hold position at start/end:

```xml
<part node="door">
    <!-- Hold closed for first 3% of animation -->
    <keyFrame time="0.00" rotation="0 0 0" />
    <keyFrame time="0.03" rotation="0 0 0" />

    <!-- Animate open -->
    <keyFrame time="0.97" rotation="0 90 0" />

    <!-- Hold open for last 3% -->
    <keyFrame time="1.00" rotation="0 90 0" />
</part>
```

### Delayed Visibility Switch

Switch visibility only at the end of animation:

```xml
<!-- Object visible until animation completes -->
<part node="closedState">
    <keyFrame time="0.00" visibility="true" />
    <keyFrame time="0.99" visibility="true" />
    <keyFrame time="1.00" visibility="false" />
</part>

<!-- Object appears when animation completes -->
<part node="openState">
    <keyFrame time="0.00" visibility="false" />
    <keyFrame time="0.99" visibility="false" />
    <keyFrame time="1.00" visibility="true" />
</part>
```

---

## User Controls Configuration

```xml
<controls
    triggerNode="controlTrigger"       <!-- Node that activates control -->
    posAction="ACTIVATE_HANDTOOL"      <!-- Action to play forward -->
    negAction="ACTIVATE_HANDTOOL"      <!-- Action to play reverse (optional) -->
    posText="action_open"              <!-- Localized text for forward -->
    negText="action_close"             <!-- Localized text for reverse -->
    autoopen="false"                   <!-- Auto-trigger on approach -->
/>
```

---

## Sound Configuration

```xml
<sounds>
    <!-- Continuous sound while animating -->
    <moving template="machineryHum" />

    <!-- Sound when animation reaches end (forward) -->
    <posEnd template="gateOpen" />

    <!-- Sound when animation reaches start (reverse) -->
    <negEnd template="gateClose" />
</sounds>
```

---

## Car Wash Animation Example

From AutomaticCarWash - animation triggered by vehicle detection:

```xml
<animatedObjects>
  <animatedObject saveId="autoWash">
    <animation duration="20">
      <!-- Wash arm moves back and forth -->
      <part node="washArm">
        <keyframe time="0.00" translation="0 0.309 -8.75" />
        <keyframe time="0.50" translation="0 0.309 8.75" />
        <keyframe time="1.00" translation="0 0.309 -8.75" />
      </part>
    </animation>
    <controls triggerNode="startTrigger" posAction="ACTIVATE_HANDTOOL"
              autoopen="false"/>
  </animatedObject>
</animatedObjects>
```

---

## Animation Types Summary

| Type | Values | Usage |
|------|--------|-------|
| translation | "X Y Z" | Move position |
| rotation | "X Y Z" (degrees) | Rotate |
| scale | "X Y Z" | Resize |
| visibility | "true/false" | Show/hide |

---

## Common Pitfalls

### 1. Missing saveId
Always include saveId for state persistence:
```xml
<animatedObject saveId="uniqueId">
```

### 2. Keyframe Time Order
Keyframes must be in ascending time order (0.00 to 1.00).

### 3. Rotation Values
Large rotation values (like 72000) cause multiple rotations during animation.

### 4. Visibility Flicker
Use 0.99 timing instead of direct 0.00/1.00 jumps to avoid flicker.
