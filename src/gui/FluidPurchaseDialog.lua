--[[
    FS25_UsedPlus - Fluid Purchase Dialog

    Custom dialog for purchasing fluids (Engine Oil or Hydraulic Fluid)
    for the Oil Service Tank placeable.

    Pattern from: FluidsDialog, TiresDialog (singleton pattern)

    v1.9.3 - Custom popup dialog with MultiTextOption
]]

FluidPurchaseDialog = {}
local FluidPurchaseDialog_mt = Class(FluidPurchaseDialog, MessageDialog)

-- Singleton instance
FluidPurchaseDialog.INSTANCE = nil

-- Fluid type definitions
FluidPurchaseDialog.FLUID_TYPES = {"oil", "hydraulic"}
FluidPurchaseDialog.PURCHASE_AMOUNT = 50  -- Liters per purchase

--[[
    Constructor
]]
function FluidPurchaseDialog.new(target, customMt)
    local self = MessageDialog.new(target, customMt or FluidPurchaseDialog_mt)

    -- Reference to the service point
    self.servicePoint = nil

    -- Current selection
    self.selectedFluidType = "oil"
    self.fluidTypeIndex = 1

    -- Tank data (populated on open)
    self.tankLevel = 0
    self.tankCapacity = 500
    self.tankFluidType = nil
    self.pricePerLiter = 5

    return self
end

--[[
    Ensure dialog is loaded (called once)
]]
function FluidPurchaseDialog.ensureLoaded()
    if g_gui.guis["FluidPurchaseDialog"] == nil then
        local xmlPath = UsedPlus.MOD_DIR .. "gui/FluidPurchaseDialog.xml"
        g_gui:loadGui(xmlPath, "FluidPurchaseDialog", FluidPurchaseDialog.new())
        UsedPlus.logDebug("FluidPurchaseDialog loaded from: " .. xmlPath)
    end
end

--[[
    Called when GUI elements are ready
]]
function FluidPurchaseDialog:onGuiSetupFinished()
    FluidPurchaseDialog:superClass().onGuiSetupFinished(self)

    -- v2.8.0: Callback is now bound via XML onClick attribute (not setCallback)
    -- See FluidPurchaseDialog.xml: <MultiTextOption ... onClick="onFluidTypeChanged"/>
end

--[[
    Set the service point reference
    @param servicePoint - The OilServicePoint placeable
]]
function FluidPurchaseDialog:setServicePoint(servicePoint)
    self.servicePoint = servicePoint

    if servicePoint == nil then
        UsedPlus.logError("FluidPurchaseDialog:setServicePoint - No service point provided")
        return
    end

    -- Get current tank status
    local spec = servicePoint.spec_oilServicePoint
    if spec then
        self.tankLevel = spec.currentFluidStorage or 0
        self.tankCapacity = spec.storageCapacity or 500
        self.tankFluidType = spec.currentFluidType
        self.pricePerLiter = spec.oilPricePerLiter or 5
    end

    -- Default selection based on tank contents
    if self.tankFluidType == "hydraulic" then
        self.selectedFluidType = "hydraulic"
        self.fluidTypeIndex = 2
    else
        self.selectedFluidType = "oil"
        self.fluidTypeIndex = 1
    end

    UsedPlus.logDebug(string.format("FluidPurchaseDialog:setServicePoint - tank=%.0f/%.0f, type=%s",
        self.tankLevel, self.tankCapacity, tostring(self.tankFluidType)))
end

--[[
    Called when dialog opens
]]
function FluidPurchaseDialog:onOpen()
    FluidPurchaseDialog:superClass().onOpen(self)

    -- Populate dropdown
    self:populateFluidTypeOptions()

    -- Update display
    self:updateDisplay()
end

--[[
    Populate the fluid type MultiTextOption dropdown
]]
function FluidPurchaseDialog:populateFluidTypeOptions()
    if self.fluidTypeOption == nil then
        return
    end

    local oilName = g_i18n:getText("usedplus_fluid_oil") or "Engine Oil"
    local hydraulicName = g_i18n:getText("usedplus_fluid_hydraulic") or "Hydraulic Fluid"

    self.fluidTypeOption:setTexts({oilName, hydraulicName})
    self.fluidTypeOption:setState(self.fluidTypeIndex)
end

--[[
    Update all display elements
]]
function FluidPurchaseDialog:updateDisplay()
    -- Tank level
    if self.tankLevelText then
        self.tankLevelText:setText(string.format("%.0f / %.0f L", self.tankLevel, self.tankCapacity))
    end

    -- Tank contents
    if self.tankContentsText then
        if self.tankFluidType and self.tankLevel > 0 then
            local fluidName = g_i18n:getText("usedplus_fluid_" .. self.tankFluidType) or self.tankFluidType
            self.tankContentsText:setText(fluidName)
            if self.tankFluidType == "oil" then
                self.tankContentsText:setTextColor(1, 0.8, 0.2, 1)
            else
                self.tankContentsText:setTextColor(0.4, 0.85, 1, 1)
            end
        else
            self.tankContentsText:setText("Empty")
            self.tankContentsText:setTextColor(0.5, 0.5, 0.5, 1)
        end
    end

    -- Calculate purchase details
    local spaceAvailable = self.tankCapacity - self.tankLevel
    local purchaseAmount = math.min(FluidPurchaseDialog.PURCHASE_AMOUNT, spaceAvailable)
    local cost = purchaseAmount * self.pricePerLiter

    -- Amount text
    if self.amountText then
        if spaceAvailable <= 0 then
            self.amountText:setText("Tank Full!")
            self.amountText:setTextColor(1, 0.3, 0.3, 1)
        else
            self.amountText:setText(string.format("%.0f L", purchaseAmount))
            self.amountText:setTextColor(0.4, 0.85, 1, 1)
        end
    end

    -- Cost text
    if self.costText then
        if spaceAvailable <= 0 then
            self.costText:setText("-")
            self.costText:setTextColor(0.5, 0.5, 0.5, 1)
        else
            self.costText:setText(g_i18n:formatMoney(cost, 0, true, true))
            self.costText:setTextColor(0.3, 1, 0.4, 1)
        end
    end

    -- Check if we can purchase the selected fluid type
    local canPurchase = spaceAvailable > 0

    -- Can't mix fluids
    if self.tankFluidType and self.tankLevel > 0 and self.tankFluidType ~= self.selectedFluidType then
        canPurchase = false
        if self.costText then
            local currentFluidName = g_i18n:getText("usedplus_fluid_" .. self.tankFluidType) or self.tankFluidType
            self.costText:setText("Contains " .. currentFluidName)
            self.costText:setTextColor(1, 0.5, 0.2, 1)
        end
    end

    -- Update purchase button
    if self.purchaseButton then
        self.purchaseButton:setDisabled(not canPurchase)
    end
end

--[[
    Fluid type dropdown changed
]]
function FluidPurchaseDialog:onFluidTypeChanged()
    if self.fluidTypeOption == nil then
        return
    end

    local state = self.fluidTypeOption:getState()
    if state == 1 then
        self.selectedFluidType = "oil"
        self.fluidTypeIndex = 1
    elseif state == 2 then
        self.selectedFluidType = "hydraulic"
        self.fluidTypeIndex = 2
    end

    self:updateDisplay()
end

--[[
    Purchase button clicked
]]
function FluidPurchaseDialog:onClickPurchase()
    UsedPlus.logDebug("FluidPurchaseDialog:onClickPurchase - START")

    if self.servicePoint == nil then
        UsedPlus.logError("FluidPurchaseDialog:onClickPurchase - servicePoint is nil!")
        self:close()
        return
    end

    UsedPlus.logDebug(string.format("FluidPurchaseDialog:onClickPurchase - servicePoint exists, tankLevel=%.0f, tankCapacity=%.0f",
        self.tankLevel, self.tankCapacity))

    -- Calculate purchase amount
    local spaceAvailable = self.tankCapacity - self.tankLevel
    local purchaseAmount = math.min(FluidPurchaseDialog.PURCHASE_AMOUNT, spaceAvailable)

    UsedPlus.logDebug(string.format("FluidPurchaseDialog:onClickPurchase - spaceAvailable=%.0f, purchaseAmount=%.0f",
        spaceAvailable, purchaseAmount))

    if purchaseAmount <= 0 then
        UsedPlus.logDebug("FluidPurchaseDialog:onClickPurchase - No space, closing")
        self:close()
        return
    end

    -- Store values before closing
    local servicePoint = self.servicePoint
    local fluidType = self.selectedFluidType

    UsedPlus.logDebug(string.format("FluidPurchaseDialog:onClickPurchase - Calling purchaseFluid with type=%s, amount=%.0f",
        tostring(fluidType), purchaseAmount))

    -- Close dialog
    self:close()

    -- Attempt purchase (after dialog is closed)
    local success = servicePoint:purchaseFluid(fluidType, purchaseAmount)
    UsedPlus.logDebug("FluidPurchaseDialog:onClickPurchase - purchaseFluid returned: " .. tostring(success))
end

--[[
    Cancel button clicked
]]
function FluidPurchaseDialog:onClickCancel()
    self:close()
end

--[[
    Called when dialog closes
]]
function FluidPurchaseDialog:onClose()
    FluidPurchaseDialog:superClass().onClose(self)
end

--[[
    Static method to show the dialog
    @param servicePoint - The OilServicePoint placeable
]]
function FluidPurchaseDialog.show(servicePoint)
    -- Ensure dialog is loaded first
    FluidPurchaseDialog.ensureLoaded()

    -- Get the controller instance from the GUI system
    local guiEntry = g_gui.guis["FluidPurchaseDialog"]
    if guiEntry == nil or guiEntry.target == nil then
        UsedPlus.logError("FluidPurchaseDialog.show - Failed to get dialog instance")
        return
    end

    -- Set service point and show
    guiEntry.target:setServicePoint(servicePoint)
    g_gui:showDialog("FluidPurchaseDialog")
end

UsedPlus.logInfo("FluidPurchaseDialog.lua loaded")
