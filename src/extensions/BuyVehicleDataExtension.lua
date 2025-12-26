--[[
    FS25_UsedPlus - Buy Vehicle Data Extension

    Extends BuyVehicleData to support financed purchases
    Pattern from: HirePurchasing BuyVehicleDataExtension.lua
    Reference: FS25_ADVANCED_PATTERNS.md - Extension Pattern

    Responsibilities:
    - Attach finance deal parameters to vehicle purchase
    - Override purchase price to be down payment only
    - Hook into onBought callback to create finance record
    - Handle cash back disbursement
]]

-- Store finance data for pending purchases
local pendingFinanceDeals = {}

--[[
    Store finance parameters before purchase
    Called from FinanceDialog when player accepts finance terms
]]
function BuyVehicleDataExtension_setFinanceDeal(storeItem, farmId, downPayment, termYears, cashBack, interestRate)
    local key = storeItem.xmlFilename
    pendingFinanceDeals[key] = {
        farmId = farmId,
        downPayment = downPayment,
        termYears = termYears,
        cashBack = cashBack or 0,
        interestRate = interestRate,
        storeItem = storeItem
    }

    UsedPlus.logDebug(string.format("Finance deal staged for: %s (Down: $%.2f, Term: %d years)",
        storeItem.name, downPayment, termYears))
end

--[[
    Get pending finance deal for a store item
]]
function BuyVehicleDataExtension_getFinanceDeal(storeItem)
    if storeItem and storeItem.xmlFilename then
        return pendingFinanceDeals[storeItem.xmlFilename]
    end
    return nil
end

--[[
    Clear pending finance deal after purchase completes
]]
function BuyVehicleDataExtension_clearFinanceDeal(storeItem)
    if storeItem and storeItem.xmlFilename then
        pendingFinanceDeals[storeItem.xmlFilename] = nil
    end
end

--[[
    Hook into vehicle purchase completion
    Creates the finance record after vehicle is bought
]]
local function onVehicleBought(vehicle, price, farmId)
    if vehicle == nil then return end

    -- Check if this was a financed purchase
    local storeItem = g_storeManager:getItemByXMLFilename(vehicle.configFileName)
    if storeItem == nil then return end

    local financeDeal = BuyVehicleDataExtension_getFinanceDeal(storeItem)
    if financeDeal == nil then return end

    -- Clear the pending deal first
    BuyVehicleDataExtension_clearFinanceDeal(storeItem)

    -- Create the finance record via FinanceManager
    if g_financeManager then
        local basePrice = StoreItemUtil.getDefaultPrice(storeItem, {})

        -- Get actual configurations price if available
        if vehicle.configurations then
            basePrice = StoreItemUtil.getCosts(storeItem, vehicle.configurations)
        end

        -- Get vehicle name using consolidated utility
        local vehicleName = UIHelper.Vehicle.getFullName(storeItem)

        local deal = g_financeManager:createFinanceDeal(
            financeDeal.farmId,
            "vehicle",
            vehicle.configFileName,
            vehicleName,
            basePrice,
            financeDeal.downPayment,
            financeDeal.termYears,
            financeDeal.cashBack
        )

        if deal then
            -- Store deal reference on vehicle for tracking
            vehicle.financeDealId = deal.id

            -- Disburse cash back to farm
            if financeDeal.cashBack > 0 then
                local farm = g_farmManager:getFarmById(financeDeal.farmId)
                if farm and g_server then
                    g_currentMission:addMoney(financeDeal.cashBack, financeDeal.farmId, MoneyType.OTHER, true, true)
                    UsedPlus.logDebug(string.format("Cash back disbursed: $%.2f to farm %d",
                        financeDeal.cashBack, financeDeal.farmId))
                end
            end

            UsedPlus.logDebug(string.format("Finance deal created for vehicle: %s (Deal ID: %s)",
                storeItem.name, deal.id))
        end
    end
end

--[[
    Hook into FSBaseMission to catch vehicle purchases
    This is called after a vehicle is successfully bought/spawned
]]
FSBaseMission.onVehicleBought = Utils.appendedFunction(FSBaseMission.onVehicleBought, function(self, vehicle, price, farmId)
    onVehicleBought(vehicle, price, farmId)
end)

--[[
    Alternative hook via Vehicle.load completion
    Some vehicles may not trigger onVehicleBought properly
]]
if Vehicle ~= nil and Vehicle.onLoadFinished ~= nil then
    Vehicle.onLoadFinished = Utils.appendedFunction(Vehicle.onLoadFinished, function(self, savegame)
        -- Only process newly purchased vehicles (not loaded from save)
        if savegame == nil and self.isOwned then
            -- Check for pending finance deal
            local storeItem = g_storeManager:getItemByXMLFilename(self.configFileName)
            if storeItem then
                local financeDeal = BuyVehicleDataExtension_getFinanceDeal(storeItem)
                if financeDeal then
                    local farmId = self:getOwnerFarmId()
                    onVehicleBought(self, 0, farmId)
                end
            end
        end
    end)
end

-- Export functions for use by FinanceDialog
g_buyVehicleDataExtension = {
    setFinanceDeal = BuyVehicleDataExtension_setFinanceDeal,
    getFinanceDeal = BuyVehicleDataExtension_getFinanceDeal,
    clearFinanceDeal = BuyVehicleDataExtension_clearFinanceDeal
}

UsedPlus.logInfo("BuyVehicleDataExtension loaded")
