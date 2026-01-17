# Vehicle Configuration Patterns

**Multi-configuration equipment with attachers, capacity variants, and design options**

Based on patterns from: bresselUndLadeShovel, community equipment mods

---

## Overview

Equipment configurations allow:
- Multiple attachment types (frontloader, telehandler, wheelloader)
- Capacity variants with price scaling
- Design/appearance options
- Configuration sets for bundles

---

## Multiple Input Attacher Configurations

### Attachment Type Options

```xml
<attachable>
    <inputAttacherJointConfigurations>
        <inputAttacherJointConfiguration name="$l10n_configuration_inputAttacher_euro" price="0">
            <inputAttacherJoint node="attacherJoint_euro" jointType="frontloader"/>
            <objectChange node="inputAttacherJoint_euro" visibilityActive="true" visibilityInactive="false"/>
        </inputAttacherJointConfiguration>

        <inputAttacherJointConfiguration name="$l10n_configuration_attacherJoint_teleloader" price="0">
            <inputAttacherJoint node="attacherJoint_teleloader" jointType="telehandler"/>
            <objectChange node="inputAttacherJoint_teleloader" visibilityActive="true" visibilityInactive="false"/>
        </inputAttacherJointConfiguration>

        <inputAttacherJointConfiguration name="$l10n_configuration_attacherJoint_wheelloader" price="0">
            <inputAttacherJoint node="attacherJoint_wheelloader" jointType="wheelLoader"/>
            <objectChange node="inputAttacherJoint_wheelloader" visibilityActive="true" visibilityInactive="false"/>
        </inputAttacherJointConfiguration>
    </inputAttacherJointConfigurations>
</attachable>
```

---

## Design Options with Price Scaling

### Optional Accessories

```xml
<designConfigurations title="$l10n_configuration_braces">
    <designConfiguration name="$l10n_ui_no" price="0"/>
    <designConfiguration name="$l10n_ui_yes" price="500">
        <objectChange node="l16Reinforcements" visibilityActive="true" visibilityInactive="false"/>
    </designConfiguration>
</designConfigurations>
```

---

## Fill Unit Configurations

### Capacity Variants

```xml
<fillUnit>
    <fillUnitConfigurations>
        <fillUnitConfiguration name="$l10n_configuration_capacity_small" price="0">
            <fillUnits>
                <fillUnit unitTextOverride="$l10n_unit_literShort"
                         fillTypes="WATER MILK LIQUIDFERTILIZER"
                         capacity="500"/>
            </fillUnits>
        </fillUnitConfiguration>

        <fillUnitConfiguration name="$l10n_configuration_capacity_medium" price="1500">
            <fillUnits>
                <fillUnit unitTextOverride="$l10n_unit_literShort"
                         fillTypes="WATER MILK LIQUIDFERTILIZER"
                         capacity="1000"/>
            </fillUnits>
        </fillUnitConfiguration>

        <fillUnitConfiguration name="$l10n_configuration_capacity_large" price="3500">
            <fillUnits>
                <fillUnit unitTextOverride="$l10n_unit_literShort"
                         fillTypes="WATER MILK LIQUIDFERTILIZER"
                         capacity="2000"/>
            </fillUnits>
        </fillUnitConfiguration>
    </fillUnitConfigurations>
</fillUnit>
```

---

## Configuration Sets (Bundles)

### Pre-Defined Configuration Combinations

```xml
<configurationSets>
    <configurationSet name="$l10n_configSet_basic">
        <configuration name="inputAttacherJoint" index="1"/>
        <configuration name="fillUnit" index="1"/>
        <configuration name="design" index="1"/>
    </configurationSet>

    <configurationSet name="$l10n_configSet_professional">
        <configuration name="inputAttacherJoint" index="2"/>
        <configuration name="fillUnit" index="3"/>
        <configuration name="design" index="2"/>
    </configurationSet>
</configurationSets>
```

---

## Object Changes for Configurations

### Show/Hide Parts Based on Selection

```xml
<objectChange node="partA" visibilityActive="true" visibilityInactive="false"/>
<objectChange node="partB" visibilityActive="false" visibilityInactive="true"/>

<!-- Translation change -->
<objectChange node="partC" translationActive="0 0.5 0" translationInactive="0 0 0"/>

<!-- Rotation change -->
<objectChange node="partD" rotationActive="0 90 0" rotationInactive="0 0 0"/>
```

---

## Color Configurations

### Material/Color Options

```xml
<baseMaterialConfigurations>
    <baseMaterialConfiguration name="$l10n_color_red" price="0">
        <material node="body" materialId="material_red"/>
    </baseMaterialConfiguration>

    <baseMaterialConfiguration name="$l10n_color_blue" price="200">
        <material node="body" materialId="material_blue"/>
    </baseMaterialConfiguration>
</baseMaterialConfigurations>
```

---

## Wheel Configurations

### Tire Options

```xml
<wheelConfigurations>
    <wheelConfiguration name="$l10n_wheels_standard" price="0">
        <wheels>
            <wheel repr="wheelReprFront" node="wheelFront" physics="true"/>
            <wheel repr="wheelReprRear" node="wheelRear" physics="true"/>
        </wheels>
    </wheelConfiguration>

    <wheelConfiguration name="$l10n_wheels_duals" price="5000">
        <wheels>
            <wheel repr="wheelReprFrontDual" node="wheelFrontDual" physics="true"/>
            <wheel repr="wheelReprRearDual" node="wheelRearDual" physics="true"/>
        </wheels>
        <objectChange node="dualMounts" visibilityActive="true" visibilityInactive="false"/>
    </wheelConfiguration>
</wheelConfigurations>
```

---

## Accessing Configurations in Lua

### Read Current Configuration

```lua
function MySpec:onLoad(savegame)
    local spec = self.spec_mySpec

    -- Get current configuration index
    local configIndex = self.configurations["design"]

    -- Act based on configuration
    if configIndex == 2 then
        spec.hasUpgrade = true
    end
end
```

### Configuration Price Calculation

```lua
-- Get total configured price
local configPrice = StoreItemUtil.getStoreItemPriceFromConfigurations(
    storeItem.xmlFilename,
    self.configurations,
    nil  -- Use default configurations for comparison
)
```

---

## Common Pitfalls

### 1. Missing Object Nodes
All nodes in objectChange must exist in i3d file.

### 2. Configuration Index Mismatch
Indices are 1-based; first configuration is index 1.

### 3. Price Calculation
Configuration prices are additive to base price.

### 4. ConfigurationSet References
Configuration names in sets must match exactly.
