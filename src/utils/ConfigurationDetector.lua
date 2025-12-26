--[[
    FS25_UsedPlus - Configuration Detector

    Comprehensive system to detect vehicle configurations
    Tests EVERY possible method to get current shop selections
    Returns comma-delimited string of all configurations
]]

ConfigurationDetector = {}

-- Translation map for common configuration keys
-- Since storeItem.configurations is empty, use this fallback
ConfigurationDetector.CONFIG_NAME_MAP = {
    baseColor = "Color",
    design = "Design",
    wheel = "Wheels",
    wheelBrand = "Wheel Brand",
    rimColor = "Rim Color",
    motor = "Engine",
    fillUnit = "Fuel Tank",
    frontloader = "Front Loader",
    attacherJoint = "Hitch",
    foldingParts = "Folding",
    selectable = "Options",
    workingWidth = "Working Width"
}

--[[
    Main detection function - tries all methods
    Returns: configString (comma-delimited), methodUsed
]]
function ConfigurationDetector.detect(storeItem, storeItemIndex)
    UsedPlus.logTrace("=== [ConfigurationDetector] STARTING COMPREHENSIVE DETECTION ===")
    UsedPlus.logTrace(string.format("[ConfigurationDetector] Store Item: %s", storeItem.name or "unknown"))
    UsedPlus.logTrace(string.format("[ConfigurationDetector] Index: %s", tostring(storeItemIndex)))

    local configs = {}
    local methodUsed = "none"

    -- Try multiple shop screen properties for configuration data
    if g_shopConfigScreen then
        UsedPlus.logTrace("[ConfigurationDetector] Searching shop screen for configuration data...")

        -- Try currentStoreItem
        if g_shopConfigScreen.currentStoreItem and g_shopConfigScreen.currentStoreItem.configurations then
            local configCount = #g_shopConfigScreen.currentStoreItem.configurations
            UsedPlus.logTrace(string.format("[ConfigurationDetector]   currentStoreItem configs count: %d", configCount))
            if configCount > 0 then
                storeItem = g_shopConfigScreen.currentStoreItem
            end
        end

        -- Try storeItem
        if g_shopConfigScreen.storeItem and g_shopConfigScreen.storeItem.configurations then
            local configCount = #g_shopConfigScreen.storeItem.configurations
            UsedPlus.logTrace(string.format("[ConfigurationDetector]   storeItem configs count: %d", configCount))
            if configCount > 0 then
                storeItem = g_shopConfigScreen.storeItem
            end
        end

        -- Try configurationSets
        if g_shopConfigScreen.configurationSets then
            UsedPlus.logTrace(string.format("[ConfigurationDetector]   Found configurationSets: %s", type(g_shopConfigScreen.configurationSets)))
            if type(g_shopConfigScreen.configurationSets) == "table" then
                local count = 0
                for k, v in pairs(g_shopConfigScreen.configurationSets) do
                    count = count + 1
                    if count <= 3 then
                        UsedPlus.logTrace(string.format("[ConfigurationDetector]     [%s] = %s (%s)", tostring(k), tostring(v), type(v)))
                    end
                end
            end
        end
    end

    -- METHOD 1: g_shopConfigScreen.configurationItems (Most Direct)
    local method1Configs = ConfigurationDetector.tryMethod1_ConfigurationItems()
    if #method1Configs > 0 then
        configs = method1Configs
        methodUsed = "Method1_ConfigurationItems"
        UsedPlus.logTrace(string.format("[ConfigurationDetector] ✓ METHOD 1 SUCCESS: Found %d configs", #configs))
    end

    -- METHOD 2: g_shopConfigScreen.configurations (Configuration Sets)
    if #configs == 0 then
        local method2Configs = ConfigurationDetector.tryMethod2_ConfigurationSets(storeItem)
        if #method2Configs > 0 then
            configs = method2Configs
            methodUsed = "Method2_ConfigurationSets"
            UsedPlus.logTrace(string.format("[ConfigurationDetector] ✓ METHOD 2 SUCCESS: Found %d configs", #configs))
        end
    end

    -- METHOD 3: StoreItemUtil.getConfigurationsFromBuyData (Buy Data)
    if #configs == 0 then
        local method3Configs = ConfigurationDetector.tryMethod3_BuyData(storeItem)
        if #method3Configs > 0 then
            configs = method3Configs
            methodUsed = "Method3_BuyData"
            UsedPlus.logTrace(string.format("[ConfigurationDetector] ✓ METHOD 3 SUCCESS: Found %d configs", #configs))
        end
    end

    -- METHOD 4: Shop attributes controller
    if #configs == 0 then
        local method4Configs = ConfigurationDetector.tryMethod4_Attributes()
        if #method4Configs > 0 then
            configs = method4Configs
            methodUsed = "Method4_Attributes"
            UsedPlus.logTrace(string.format("[ConfigurationDetector] ✓ METHOD 4 SUCCESS: Found %d configs", #configs))
        end
    end

    -- METHOD 5: Direct storeItem configurations with currentIndex
    if #configs == 0 then
        local method5Configs = ConfigurationDetector.tryMethod5_StoreItemConfigs(storeItem)
        if #method5Configs > 0 then
            configs = method5Configs
            methodUsed = "Method5_StoreItemConfigs"
            UsedPlus.logTrace(string.format("[ConfigurationDetector] ✓ METHOD 5 SUCCESS: Found %d configs", #configs))
        end
    end

    -- METHOD 6: Parse from shop config screen state
    if #configs == 0 then
        local method6Configs = ConfigurationDetector.tryMethod6_ShopState()
        if #method6Configs > 0 then
            configs = method6Configs
            methodUsed = "Method6_ShopState"
            UsedPlus.logTrace(string.format("[ConfigurationDetector] ✓ METHOD 6 SUCCESS: Found %d configs", #configs))
        end
    end

    -- Convert to comma-delimited string
    local configString = ""
    if #configs > 0 then
        configString = table.concat(configs, ", ")
        UsedPlus.logTrace(string.format("[ConfigurationDetector] FINAL RESULT: %s", configString))
    else
        UsedPlus.logTrace("[ConfigurationDetector] ✗ ALL METHODS FAILED - No configurations found")
    end

    UsedPlus.logTrace(string.format("[ConfigurationDetector] Method Used: %s", methodUsed))
    UsedPlus.logTrace("=== [ConfigurationDetector] DETECTION COMPLETE ===")

    return configString, methodUsed
end

--[[
    METHOD 1: g_shopConfigScreen.configurationItems
    Direct access to configuration UI elements
]]
function ConfigurationDetector.tryMethod1_ConfigurationItems()
    UsedPlus.logTrace("\n--- METHOD 1: configurationItems ---")
    local configs = {}

    if not g_shopConfigScreen then
        UsedPlus.logTrace("[Method1] ✗ g_shopConfigScreen not available")
        return configs
    end

    UsedPlus.logTrace("[Method1] g_shopConfigScreen available")

    if g_shopConfigScreen.configurationItems then
        UsedPlus.logTrace(string.format("[Method1] Found configurationItems: %s", tostring(type(g_shopConfigScreen.configurationItems))))

        for i, item in pairs(g_shopConfigScreen.configurationItems) do
            UsedPlus.logTrace(string.format("[Method1]   Item %s:", tostring(i)))
            UsedPlus.logTrace(string.format("[Method1]     name: %s", tostring(item.name)))
            UsedPlus.logTrace(string.format("[Method1]     title: %s", tostring(item.title)))
            UsedPlus.logTrace(string.format("[Method1]     currentIndex: %s", tostring(item.currentIndex)))

            -- Dump all item properties
            UsedPlus.logTrace(string.format("[Method1]     Dumping all item properties:"))
            for key, value in pairs(item) do
                if type(value) ~= "function" and type(value) ~= "table" then
                    UsedPlus.logTrace(string.format("[Method1]       item.%s = %s", tostring(key), tostring(value)))
                end
            end

            if item.currentIndex and item.currentIndex > 0 then
                local configName = item.name or item.title or "Config"
                local configValue = "Unknown"

                -- Check if elements exists and dump it
                if item.elements then
                    UsedPlus.logTrace(string.format("[Method1]     elements count: %d", #item.elements or 0))

                    if item.elements[item.currentIndex] then
                        local element = item.elements[item.currentIndex]
                        UsedPlus.logTrace(string.format("[Method1]     Current element dump:"))
                        for key, value in pairs(element) do
                            if type(value) ~= "function" then
                                UsedPlus.logTrace(string.format("[Method1]       element.%s = %s (%s)", tostring(key), tostring(value), type(value)))
                            end
                        end

                        configValue = element.name or element.text or element.title or "Selected"
                        UsedPlus.logTrace(string.format("[Method1]     ✓ Found value: %s", configValue))
                    else
                        UsedPlus.logTrace(string.format("[Method1]     ✗ No element at index %d", item.currentIndex))
                    end
                else
                    UsedPlus.logTrace(string.format("[Method1]     ✗ No elements array"))
                end

                table.insert(configs, string.format("%s: %s", configName, configValue))
            end
        end
    else
        UsedPlus.logTrace("[Method1] ✗ No configurationItems property")
    end

    return configs
end

--[[
    METHOD 2: g_shopConfigScreen.configurations
    Configuration sets/groups - GET HUMAN-READABLE NAMES
]]
function ConfigurationDetector.tryMethod2_ConfigurationSets(storeItem)
    UsedPlus.logTrace("\n--- METHOD 2: configurations (sets) ---")
    local configs = {}

    if not g_shopConfigScreen then
        UsedPlus.logTrace("[Method2] ✗ g_shopConfigScreen not available")
        return configs
    end

    if not g_shopConfigScreen.configurations then
        UsedPlus.logTrace("[Method2] ✗ No configurations property")
        return configs
    end

    UsedPlus.logTrace(string.format("[Method2] Found configurations: %s", tostring(type(g_shopConfigScreen.configurations))))

    -- Get human-readable names from storeItem.configurations
    local configDefinitions = {}
    if storeItem and storeItem.configurations then
        UsedPlus.logTrace(string.format("[Method2] storeItem.configurations exists, type: %s", type(storeItem.configurations)))
        UsedPlus.logTrace(string.format("[Method2] configurations count: %d", #storeItem.configurations))

        for i, configDef in ipairs(storeItem.configurations) do
            UsedPlus.logTrace(string.format("[Method2]   Config %d:", i))
            UsedPlus.logTrace(string.format("[Method2]     name: %s", tostring(configDef.name)))
            UsedPlus.logTrace(string.format("[Method2]     title: %s", tostring(configDef.title)))
            UsedPlus.logTrace(string.format("[Method2]     items count: %s", configDef.items and #configDef.items or "nil"))

            if configDef.name then
                configDefinitions[configDef.name] = configDef
                UsedPlus.logTrace(string.format("[Method2]     ✓ Added to definitions"))
            end
        end
    else
        UsedPlus.logTrace("[Method2] ✗ storeItem.configurations is nil or missing")
    end

    UsedPlus.logTrace(string.format("[Method2] Total config definitions loaded: %d", table.getn(configDefinitions) or 0))

    -- Process each configuration
    for configKey, selectedIndex in pairs(g_shopConfigScreen.configurations) do
        UsedPlus.logTrace(string.format("[Method2]   Processing key: %s", tostring(configKey)))
        UsedPlus.logTrace(string.format("[Method2]     selectedIndex type: %s", type(selectedIndex)))
        UsedPlus.logTrace(string.format("[Method2]     selectedIndex value: %s", tostring(selectedIndex)))

        -- Deep inspection of selectedIndex if it's a table
        if type(selectedIndex) == "table" then
            UsedPlus.logTrace(string.format("[Method2]     selectedIndex is a TABLE:"))
            for k, v in pairs(selectedIndex) do
                UsedPlus.logTrace(string.format("[Method2]       [%s] = %s (%s)", tostring(k), tostring(v), type(v)))
            end
        end

        -- Get the configuration definition
        local configDef = configDefinitions[configKey]

        if configDef then
            local configName = configDef.name
            local configTitle = configDef.title or configName

            -- Translate title if it's a l10n key
            if configTitle and type(configTitle) == "string" and configTitle:sub(1, 1) == "$" then
                configTitle = g_i18n:getText(configTitle:sub(2))
            end

            -- Get the selected item name
            local selectedName = "Unknown"
            if type(selectedIndex) == "number" and configDef.items and configDef.items[selectedIndex] then
                local item = configDef.items[selectedIndex]
                selectedName = item.name or item.text or item.title or tostring(selectedIndex)

                -- Translate if l10n key
                if type(selectedName) == "string" and selectedName:sub(1, 1) == "$" then
                    selectedName = g_i18n:getText(selectedName:sub(2))
                end

                UsedPlus.logTrace(string.format("[Method2]     → %s: %s", configTitle, selectedName))
            end

            table.insert(configs, string.format("%s: %s", configTitle, selectedName))
        else
            -- Fallback: use translation map
            UsedPlus.logTrace(string.format("[Method2]     (no definition found, using translation map)"))
            local translatedName = ConfigurationDetector.CONFIG_NAME_MAP[configKey] or configKey
            table.insert(configs, string.format("%s: Option %s", translatedName, tostring(selectedIndex)))
        end
    end

    return configs
end

--[[
    METHOD 3: StoreItemUtil.getConfigurationsFromBuyData
    Use game's built-in configuration getter
]]
function ConfigurationDetector.tryMethod3_BuyData(storeItem)
    UsedPlus.logTrace("\n--- METHOD 3: BuyData ---")
    local configs = {}

    if not StoreItemUtil then
        UsedPlus.logTrace("[Method3] ✗ StoreItemUtil not available")
        return configs
    end

    UsedPlus.logTrace("[Method3] Checking for buy data methods")

    -- Try to get current buy data
    if g_shopConfigScreen and g_shopConfigScreen.buyData then
        UsedPlus.logTrace("[Method3] Found buyData")
        UsedPlus.logTrace(string.format("[Method3]   Type: %s", type(g_shopConfigScreen.buyData)))

        for key, value in pairs(g_shopConfigScreen.buyData) do
            UsedPlus.logTrace(string.format("[Method3]   buyData.%s = %s (%s)", tostring(key), tostring(value), type(value)))
        end

        -- Try to extract configurations from buyData
        if type(g_shopConfigScreen.buyData.configs) == "table" then
            for key, value in pairs(g_shopConfigScreen.buyData.configs) do
                table.insert(configs, string.format("%s: %s", tostring(key), tostring(value)))
            end
        end
    else
        UsedPlus.logTrace("[Method3] ✗ No buyData")
    end

    return configs
end

--[[
    METHOD 4: Attributes Controller
    Shop attributes/options controller
]]
function ConfigurationDetector.tryMethod4_Attributes()
    UsedPlus.logTrace("\n--- METHOD 4: Attributes Controller ---")
    local configs = {}

    if g_shopConfigScreen and g_shopConfigScreen.attributesLayout then
        UsedPlus.logTrace("[Method4] Found attributesLayout")

        if type(g_shopConfigScreen.attributesLayout) == "table" then
            for key, value in pairs(g_shopConfigScreen.attributesLayout) do
                UsedPlus.logTrace(string.format("[Method4]   attributesLayout.%s = %s", tostring(key), tostring(value)))
            end
        end
    end

    if g_shopConfigScreen and g_shopConfigScreen.attributes then
        UsedPlus.logTrace("[Method4] Found attributes")

        if type(g_shopConfigScreen.attributes) == "table" then
            for key, value in pairs(g_shopConfigScreen.attributes) do
                UsedPlus.logTrace(string.format("[Method4]   attributes.%s = %s (%s)", tostring(key), tostring(value), type(value)))

                if type(value) == "string" or type(value) == "number" then
                    table.insert(configs, string.format("%s: %s", tostring(key), tostring(value)))
                end
            end
        end
    end

    return configs
end

--[[
    METHOD 5: StoreItem configurations with indices
    Parse storeItem.configurations structure
]]
function ConfigurationDetector.tryMethod5_StoreItemConfigs(storeItem)
    UsedPlus.logTrace("\n--- METHOD 5: StoreItem Configurations ---")
    local configs = {}

    if not storeItem.configurations then
        UsedPlus.logTrace("[Method5] ✗ storeItem has no configurations")
        return configs
    end

    UsedPlus.logTrace(string.format("[Method5] storeItem.configurations type: %s", type(storeItem.configurations)))

    if type(storeItem.configurations) == "table" then
        for i, config in ipairs(storeItem.configurations) do
            UsedPlus.logTrace(string.format("[Method5]   Config %d:", i))
            UsedPlus.logTrace(string.format("[Method5]     name: %s", tostring(config.name)))
            UsedPlus.logTrace(string.format("[Method5]     title: %s", tostring(config.title)))

            if config.items then
                UsedPlus.logTrace(string.format("[Method5]     items count: %d", #config.items))

                -- Try to find selected item
                if config.selectedIndex or config.currentIndex then
                    local index = config.selectedIndex or config.currentIndex
                    if config.items[index] then
                        local itemName = config.items[index].name or config.items[index].text
                        table.insert(configs, string.format("%s: %s", config.name or "Config", itemName or "Selected"))
                    end
                end
            end
        end
    end

    return configs
end

--[[
    METHOD 6: Shop State/Current Selection
    Dig into shop screen state
]]
function ConfigurationDetector.tryMethod6_ShopState()
    UsedPlus.logTrace("\n--- METHOD 6: Shop State ---")
    local configs = {}

    if not g_shopConfigScreen then
        UsedPlus.logTrace("[Method6] ✗ g_shopConfigScreen not available")
        return configs
    end

    -- Deep dive into g_shopConfigScreen to find configuration value names
    UsedPlus.logTrace("[Method6] Dumping g_shopConfigScreen properties:")
    for key, value in pairs(g_shopConfigScreen) do
        local valueType = type(value)
        if valueType ~= "function" then
            UsedPlus.logTrace(string.format("[Method6]   g_shopConfigScreen.%s = %s (%s)", tostring(key), tostring(value), valueType))

            -- If it's a table, dig deeper (but avoid infinite loops)
            if valueType == "table" and key ~= "target" and key ~= "parent" then
                -- Check for configuration-related properties
                if string.find(string.lower(key), "config") or string.find(string.lower(key), "option") or string.find(string.lower(key), "element") then
                    UsedPlus.logTrace(string.format("[Method6]     → Examining %s:", key))
                    local count = 0
                    for k, v in pairs(value) do
                        count = count + 1
                        if count <= 10 then  -- Limit output
                            UsedPlus.logTrace(string.format("[Method6]       [%s] = %s (%s)", tostring(k), tostring(v), type(v)))
                        end
                    end
                    if count > 10 then
                        UsedPlus.logTrace(string.format("[Method6]       ... and %d more items", count - 10))
                    end
                end
            end
        end
    end

    -- Try to find configurationElements or similar
    if g_shopConfigScreen.configurationElements then
        UsedPlus.logTrace("[Method6] Found configurationElements!")
        for i, elem in pairs(g_shopConfigScreen.configurationElements) do
            UsedPlus.logTrace(string.format("[Method6]   Element %s:", tostring(i)))
            if type(elem) == "table" then
                for k, v in pairs(elem) do
                    if type(v) ~= "function" then
                        UsedPlus.logTrace(string.format("[Method6]     .%s = %s", tostring(k), tostring(v)))
                    end
                end
            end
        end
    end

    return configs
end

UsedPlus.logInfo("ConfigurationDetector loaded")
