--[[
    FS25_UsedPlus - Vehicle Extension

    Extends vehicle class to handle financed/leased vehicles
    Pattern from: Game's vehicle ownership system
    Reference: FS25_ADVANCED_PATTERNS.md - Vehicle Extension Pattern

    Responsibilities:
    - Prevent selling of leased vehicles
    - Handle finance deal payoff when selling financed vehicles
    - Track lease/finance status on vehicle objects
    - Override sell price calculation for financed vehicles
    - Display warnings when attempting to sell financed/leased vehicles

    Uses Utils.overwrittenFunction to extend Vehicle methods
]]

VehicleExtension = {}

--[[
    Initialize extension
    Hooks into vehicle sell system
]]
function VehicleExtension:init()
    UsedPlus.logDebug("Initializing VehicleExtension")

    -- Hook vehicle sell validation
    Vehicle.getSellPrice = Utils.overwrittenFunction(
        Vehicle.getSellPrice,
        VehicleExtension.getSellPrice
    )

    -- Hook vehicle sell confirmation
    Vehicle.sell = Utils.overwrittenFunction(
        Vehicle.sell,
        VehicleExtension.sell
    )

    UsedPlus.logDebug("VehicleExtension initialized")
    return true
end

--[[
    Override getSellPrice to account for finance deals and reliability
    v1.4.0: Now applies resale modifier based on vehicle reliability
]]
function VehicleExtension.getSellPrice(self, superFunc)
    -- Get base sell price from game
    local baseSellPrice = superFunc(self)

    -- Check if vehicle is financed/leased
    if self.isLeased then
        -- Leased vehicles cannot be sold
        return 0
    end

    -- v1.4.0: Apply reliability-based resale modifier
    -- High reliability vehicles sell for more, low reliability for less
    if UsedPlusMaintenance and UsedPlusMaintenance.CONFIG.enableResaleModifier then
        local reliabilityData = UsedPlusMaintenance.getReliabilityData(self)
        if reliabilityData and reliabilityData.resaleModifier then
            baseSellPrice = math.floor(baseSellPrice * reliabilityData.resaleModifier)
        end
    end

    if self.financeDealId then
        -- Vehicle is financed, deduct remaining balance
        local deal = g_financeManager:getDealById(self.financeDealId)
        if deal then
            local netProceeds = baseSellPrice - deal.currentBalance
            return math.max(0, netProceeds)  -- Cannot be negative
        end
    end

    return baseSellPrice
end

--[[
    Override sell to handle finance/lease restrictions
]]
function VehicleExtension.sell(self, superFunc, noEventSend)
    -- Check if vehicle is leased
    if self.isLeased then
        UsedPlus.logWarn(string.format("Cannot sell leased vehicle: %s", self.getName(self)))

        -- Show error notification
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
            g_i18n:getText("usedplus_error_cannotSellLeasedVehicle")
        )

        return false
    end

    -- Check if vehicle is financed
    if self.financeDealId then
        local deal = g_financeManager:getDealById(self.financeDealId)
        if deal then
            -- Get sell price
            local baseSellPrice = Vehicle.calculateSalePrice(self)

            -- Check if sale proceeds cover remaining balance
            if baseSellPrice < deal.currentBalance then
                UsedPlus.logWarn(string.format("Sell price ($%.2f) < remaining balance ($%.2f)",
                    baseSellPrice, deal.currentBalance))

                -- Show error notification
                g_currentMission:addIngameNotification(
                    FSBaseMission.INGAME_NOTIFICATION_CRITICAL,
                    string.format(g_i18n:getText("usedplus_error_insufficientSalePrice"),
                        g_i18n:formatMoney(deal.currentBalance), g_i18n:formatMoney(baseSellPrice))
                )

                return false
            end

            -- Sell price covers balance, proceed with sale
            UsedPlus.logDebug(string.format("Selling financed vehicle: %s (Sale: $%.2f, Balance: $%.2f, Net: $%.2f)",
                self.getName(self), baseSellPrice, deal.currentBalance, baseSellPrice - deal.currentBalance))

            -- Call original sell function
            local success = superFunc(self, noEventSend)

            if success then
                -- Pay off finance deal from sale proceeds
                -- Server handles this automatically via money change
                -- Mark deal as completed
                deal.status = "completed"
                deal.currentBalance = 0

                -- Remove from active deals
                g_financeManager.deals[deal.id] = nil
                local farmDeals = g_financeManager.dealsByFarm[deal.farmId]
                if farmDeals then
                    for i, d in ipairs(farmDeals) do
                        if d.id == deal.id then
                            table.remove(farmDeals, i)
                            break
                        end
                    end
                end

                UsedPlus.logDebug(string.format("Finance deal %s paid off from sale", deal.id))

                -- Notification
                g_currentMission:addIngameNotification(
                    FSBaseMission.INGAME_NOTIFICATION_OK,
                    string.format(g_i18n:getText("usedplus_notification_dealPaidFromSale"),
                        self.getName(self), g_i18n:formatMoney(deal.currentBalance))
                )
            end

            return success
        end
    end

    -- Not financed/leased, call original sell
    return superFunc(self, noEventSend)
end

--[[
    Mark vehicle as financed
    Called from lease/finance events when vehicle is spawned
]]
function VehicleExtension:markVehicleAsFinanced(vehicle, dealId)
    if vehicle == nil then return end

    vehicle.financeDealId = dealId
    vehicle.isLeased = false

    UsedPlus.logDebug(string.format("Vehicle marked as financed: %s (Deal: %s)", vehicle:getName(), dealId))
end

--[[
    Mark vehicle as leased
    Called from lease event when vehicle is spawned
]]
function VehicleExtension:markVehicleAsLeased(vehicle, dealId)
    if vehicle == nil then return end

    vehicle.isLeased = true
    vehicle.leaseDealId = dealId

    UsedPlus.logDebug(string.format("Vehicle marked as leased: %s (Deal: %s)", vehicle:getName(), dealId))
end

UsedPlus.logInfo("VehicleExtension loaded")
