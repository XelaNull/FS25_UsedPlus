# Shop UI Integration

**Adding custom buttons and functionality to the vehicle shop**

Based on patterns from: HirePurchasing, BuyUsedEquipment

---

## Overview

Common shop UI modifications:
- Add custom buttons (Finance, Search Used, etc.)
- Modify purchase flow
- Show custom dialogs from shop
- React to shop events

---

## Adding a Button to Shop Screen

### Basic Button Clone Pattern
```lua
ShopConfigScreenExtension = {}

function ShopConfigScreenExtension:setStoreItem(superFunc, storeItem, ...)
    -- Call original function first
    superFunc(self, storeItem, ...)

    -- Clone button if it doesn't exist
    if self.myModButton == nil and self.buyButton ~= nil then
        local parent = self.buyButton.parent
        self.myModButton = self.buyButton:clone(parent)
        self.myModButton.name = "myModButton"
        self.myModButton.inputActionName = "MENU_EXTRA_1"  -- Optional hotkey
    end

    -- Configure button for this store item
    if self.myModButton then
        self:setupMyModButton(storeItem)
    end
end

function ShopConfigScreenExtension:setupMyModButton(storeItem)
    -- Check if button should be enabled
    if self:canUseMyMod(storeItem) then
        self.myModButton:setDisabled(false)
        self.myModButton:setText(g_i18n:getText("myMod_buttonText"))

        -- Set click callback
        self.myModButton.onClickCallback = function()
            self:onMyModButtonClicked(storeItem)
        end
    else
        self.myModButton:setDisabled(true)
        self.myModButton:setText(g_i18n:getText("myMod_notAvailable"))
    end
end

function ShopConfigScreenExtension:canUseMyMod(storeItem)
    -- Example: Only for vehicles, not placeables
    return StoreItemUtil.getIsVehicle(storeItem)
end

function ShopConfigScreenExtension:onMyModButtonClicked(storeItem)
    -- Play click sound
    g_shopConfigScreen:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)

    -- Open custom dialog
    local dialog = g_gui:showDialog("MyModDialog")
    if dialog then
        dialog.target:setData(
            storeItem,
            self.configurations,
            self.licensePlateData,
            self.totalPrice
        )
    end
end

-- Hook into ShopConfigScreen
ShopConfigScreen.setStoreItem = Utils.overwrittenFunction(
    ShopConfigScreen.setStoreItem,
    ShopConfigScreenExtension.setStoreItem
)
```

### Updating Button Visibility
```lua
function ShopConfigScreenExtension:updateButtons(storeItem, vehicle, saleItem)
    if self.myModButton then
        -- Hide when customizing existing vehicle (not new purchase)
        local isNewPurchase = vehicle == nil
        self.myModButton:setVisible(isNewPurchase)
    end
end

ShopConfigScreen.updateButtons = Utils.appendedFunction(
    ShopConfigScreen.updateButtons,
    ShopConfigScreenExtension.updateButtons
)
```

---

## Option Dialog Pattern

Show a selection dialog with multiple options:

```lua
function ShopConfigScreenExtension:onMyModButtonClicked(storeItem)
    g_shopConfigScreen:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)

    -- Build options array
    local options = {}
    for i, level in ipairs(MyMod.LEVELS) do
        local fee = g_i18n:formatMoney(level.fee * storeItem.price)
        local name = string.format(level.name, fee)
        table.insert(options, name)
    end

    -- Show option dialog
    OptionDialog.show(
        function(result)
            if result > 0 then
                -- User selected option (1-based index)
                self:processSelection(storeItem, result)
                g_shopConfigScreen:playSample(GuiSoundPlayer.SOUND_SAMPLES.YES)
            else
                -- User cancelled
                g_shopConfigScreen:playSample(GuiSoundPlayer.SOUND_SAMPLES.NO)
            end
        end,
        g_i18n:getText("myMod_dialogInfo"),   -- Dialog text
        g_i18n:getText("myMod_dialogTitle"),  -- Dialog title
        options                                -- Array of options
    )
end
```

---

## Info Dialog Pattern

Show a simple information dialog:

```lua
function ShopConfigScreenExtension:showConfirmation(message)
    InfoDialog.show(
        message,                              -- Text to display
        nil,                                  -- Callback (optional)
        nil,                                  -- Target (optional)
        DialogElement.TYPE_INFO,              -- Dialog type
        nil,                                  -- Extra data
        nil,                                  -- Buttons config
        nil,                                  -- Input action
        true                                  -- Show immediately
    )
end

-- Usage
self:showConfirmation(
    string.format(g_i18n:getText("myMod_purchaseComplete"), vehicleName)
)
```

---

## Yes/No Confirmation Dialog

```lua
function ShopConfigScreenExtension:confirmPurchase(storeItem, callback)
    local price = g_i18n:formatMoney(self.totalPrice)
    local message = string.format(
        g_i18n:getText("myMod_confirmPurchase"),
        storeItem.name,
        price
    )

    g_gui:showYesNoDialog({
        text = message,
        title = g_i18n:getText("myMod_confirm"),
        callback = function(yes)
            if yes then
                callback(true)
                g_shopConfigScreen:playSample(GuiSoundPlayer.SOUND_SAMPLES.YES)
            else
                callback(false)
                g_shopConfigScreen:playSample(GuiSoundPlayer.SOUND_SAMPLES.NO)
            end
        end
    })
end
```

---

## Complete Finance Button Example

From HirePurchasing mod:

```lua
ShopConfigScreen.setStoreItem = Utils.overwrittenFunction(
    ShopConfigScreen.setStoreItem,
    function(self, superFunc, storeItem, ...)
        superFunc(self, storeItem, ...)

        local sourceButton = self.buyButton
        local financeButton = self.financeButton

        -- Create button if needed
        if not financeButton and sourceButton then
            local parent = sourceButton.parent
            financeButton = sourceButton:clone(parent)
            financeButton.name = "financeButton"
            financeButton.inputActionName = "MENU_EXTRA_1"
            self.financeButton = financeButton
        end

        if financeButton ~= nil then
            -- Check if item is leasable
            if not StoreItemUtil.getIsLeasable(storeItem) then
                financeButton:setDisabled(true)
            else
                financeButton:setDisabled(false)
            end

            financeButton:setText(g_i18n:getText("fl_btn_finance"))

            -- Button callback
            self.onClickFinance = function()
                local dialog = g_gui:showDialog("newFinanceFrame")
                if dialog ~= nil then
                    dialog.target:setData(
                        storeItem,
                        self.configurations,
                        self.licensePlateData,
                        self.totalPrice,
                        self.saleItem,
                        self.configurationData
                    )
                end
            end

            financeButton.onClickCallback = self.onClickFinance
        end
    end
)
```

---

## Store Item Utilities

### Check Item Type
```lua
-- Check if item is a vehicle
local isVehicle = StoreItemUtil.getIsVehicle(storeItem)

-- Check if item is leasable
local isLeasable = StoreItemUtil.getIsLeasable(storeItem)

-- Check if item is a placeable
local isPlaceable = storeItem.species == "placeable"

-- Get item category
local category = storeItem.categoryName
```

### Get Configured Price
```lua
-- Get base price
local basePrice = storeItem.price

-- Get total price with configurations
local totalPrice = self.totalPrice  -- From ShopConfigScreen

-- Get configured price programmatically
local configPrice = StoreItemUtil.getStoreItemPriceFromConfigurations(
    storeItem.xmlFilename,
    self.configurations,
    nil  -- Use default configurations
)
```

### Check Affordability
```lua
function ShopConfigScreenExtension:canAfford(price)
    local farmId = g_currentMission:getFarmId()
    local farm = g_farmManager:getFarmById(farmId)

    if farm then
        return farm.money >= price
    end
    return false
end
```

---

## Modifying Purchase Data

Intercept and modify the purchase process:

```lua
-- Extend BuyVehicleData to add custom data
function BuyVehicleDataExtension:setMyModData(data)
    self.myModData = data
end

BuyVehicleData.setMyModData = BuyVehicleDataExtension.setMyModData

-- In shop callback
function ShopConfigScreenExtension:onMyModPurchase(storeItem)
    -- Get current buy data
    local buyVehicleData = self.buyVehicleData

    -- Add our custom data
    buyVehicleData:setMyModData({
        type = "finance",
        deposit = 10000,
        term = 24
    })

    -- Modify price (e.g., for financing, price = deposit only)
    buyVehicleData.price = buyVehicleData.myModData.deposit

    -- Proceed with purchase
    self:onClickBuy()
end
```

---

## Sound Effects

Play appropriate sounds for user feedback:

```lua
-- Common sound samples
g_shopConfigScreen:playSample(GuiSoundPlayer.SOUND_SAMPLES.CLICK)    -- Button click
g_shopConfigScreen:playSample(GuiSoundPlayer.SOUND_SAMPLES.YES)      -- Confirmation
g_shopConfigScreen:playSample(GuiSoundPlayer.SOUND_SAMPLES.NO)       -- Cancel
g_shopConfigScreen:playSample(GuiSoundPlayer.SOUND_SAMPLES.ERROR)    -- Error
g_shopConfigScreen:playSample(GuiSoundPlayer.SOUND_SAMPLES.HOVER)    -- Hover
```

---

## Common Pitfalls

### 1. Button Not Appearing
```lua
-- WRONG: Creating button before buyButton exists
function ShopConfigScreenExtension:onOpen()
    self.myButton = self.buyButton:clone(...)  -- buyButton may be nil!
end

-- CORRECT: Create in setStoreItem after super call
function ShopConfigScreenExtension:setStoreItem(superFunc, storeItem, ...)
    superFunc(self, storeItem, ...)  -- This sets up buyButton
    if self.buyButton then
        self.myButton = self.buyButton:clone(...)
    end
end
```

### 2. Button Callback Not Working
```lua
-- WRONG: Using string for callback
self.myButton.onClick = "onMyClick"  -- May not work

-- CORRECT: Use onClickCallback with function
self.myButton.onClickCallback = function()
    self:onMyClick()
end
```

### 3. Dialog Data Lost
```lua
-- WRONG: Using local variables
local myData = storeItem
self.myButton.onClickCallback = function()
    -- myData might be garbage collected or changed
end

-- CORRECT: Capture in closure or store on self
local capturedItem = storeItem
self.myButton.onClickCallback = function()
    self:onMyClick(capturedItem)
end
```

### 4. Not Checking for Existing Button
```lua
-- WRONG: Creates duplicate buttons
function ShopConfigScreenExtension:setStoreItem(...)
    self.myButton = self.buyButton:clone(...)  -- Created every time!
end

-- CORRECT: Check first
function ShopConfigScreenExtension:setStoreItem(...)
    if self.myButton == nil and self.buyButton then
        self.myButton = self.buyButton:clone(...)
    end
end
```
