--[[
    FS25_UsedPlus - Used Vehicle Preview Dialog

    Shows used vehicle details with option to inspect or buy as-is.
    This is the entry point for the inspection system.
    Pattern from: ScreenElement (NOT MessageDialog - that causes conflicts)

    Flow:
    1. Player views used vehicle listing
    2. This dialog shows visible stats + warning about hidden condition
    3. Player can:
       a) Buy As-Is - Purchase without knowing reliability
       b) Inspect - Pay inspection fee, see InspectionReportDialog
       c) Cancel - Return to previous screen
]]

UsedVehiclePreviewDialog = {}
local UsedVehiclePreviewDialog_mt = Class(UsedVehiclePreviewDialog, ScreenElement)

-- Dialog instance
UsedVehiclePreviewDialog.INSTANCE = nil

--[[
    Constructor - extends ScreenElement, NOT MessageDialog
]]
function UsedVehiclePreviewDialog.new(target, customMt)
    local self = ScreenElement.new(target, customMt or UsedVehiclePreviewDialog_mt)

    self.listing = nil
    self.farmId = nil
    self.onPurchaseCallback = nil
    self.callbackTarget = nil
    self.inspectionCost = 0
    self.isBackAllowed = true

    return self
end

--[[
    Get singleton instance, creating if needed
]]
function UsedVehiclePreviewDialog.getInstance()
    if UsedVehiclePreviewDialog.INSTANCE == nil then
        UsedVehiclePreviewDialog.INSTANCE = UsedVehiclePreviewDialog.new()

        -- Load XML - use UsedPlus.MOD_DIR which persists after mod load
        local xmlPath = UsedPlus.MOD_DIR .. "gui/UsedVehiclePreviewDialog.xml"
        g_gui:loadGui(xmlPath, "UsedVehiclePreviewDialog", UsedVehiclePreviewDialog.INSTANCE)

        UsedPlus.logDebug("UsedVehiclePreviewDialog created and loaded from: " .. xmlPath)
    end
    return UsedVehiclePreviewDialog.INSTANCE
end

--[[
    Show dialog for a used vehicle listing
    @param listing - The used vehicle listing data
    @param farmId - Farm ID of the buyer
    @param onPurchaseCallback - Function(confirmed, listing) called when dialog closes
    @param callbackTarget - Target object for callback
]]
function UsedVehiclePreviewDialog:show(listing, farmId, onPurchaseCallback, callbackTarget)
    self.listing = listing
    self.farmId = farmId
    self.onPurchaseCallback = onPurchaseCallback
    self.callbackTarget = callbackTarget

    -- Calculate inspection cost
    self.inspectionCost = InspectionReportDialog.calculateInspectionCost(listing.price or 0)

    g_gui:showDialog("UsedVehiclePreviewDialog")
end

--[[
    Called when dialog opens
]]
function UsedVehiclePreviewDialog:onOpen()
    UsedVehiclePreviewDialog:superClass().onOpen(self)

    if self.listing then
        self:updateDisplay()
    end
end

--[[
    Called when dialog closes
]]
function UsedVehiclePreviewDialog:onClose()
    UsedVehiclePreviewDialog:superClass().onClose(self)
end

--[[
    Update all display elements
]]
function UsedVehiclePreviewDialog:updateDisplay()
    local listing = self.listing
    if listing == nil then return end

    -- Get store item for image
    local storeItem = g_storeManager:getItemByXMLFilename(listing.storeItemIndex)

    -- Title
    if self.titleText then
        self.titleText:setText(g_i18n:getText("usedplus_preview_title"))
    end

    -- Vehicle name
    if self.vehicleNameText then
        self.vehicleNameText:setText(listing.storeItemName or "Unknown Vehicle")
    end

    -- Price
    if self.priceText then
        self.priceText:setText(g_i18n:formatMoney(listing.price or 0, 0, true, true))
    end

    -- Vehicle image - use UIHelper pattern if available
    if self.vehicleImage and storeItem then
        if UIHelper and UIHelper.Image and UIHelper.Image.setStoreItemImage then
            UIHelper.Image.setStoreItemImage(self.vehicleImage, storeItem)
        else
            -- Fallback: set image directly
            local imagePath = storeItem.imageFilename
            if imagePath then
                self.vehicleImage:setImageFilename(imagePath)
            end
        end
    end

    -- Visible condition stats (values only - labels are in XML)
    if self.ageText then
        self.ageText:setText(string.format(g_i18n:getText("usedplus_preview_ageYears"), listing.age or 0))
    end

    if self.hoursText then
        local hours = listing.operatingHours or 0
        self.hoursText:setText(g_i18n:formatNumber(hours))
    end

    -- Show descriptive condition instead of exact percentages (as if visually inspected)
    if self.damageText then
        local damageDesc = self:getConditionDescription(listing.damage or 0, "mechanical")
        self.damageText:setText(damageDesc)
    end

    if self.wearText then
        local wearDesc = self:getConditionDescription(listing.wear or 0, "cosmetic")
        self.wearText:setText(wearDesc)
    end

    -- Check if already inspected
    local wasInspected = listing.usedPlusData and listing.usedPlusData.wasInspected

    -- Update warning/inspected sections visibility
    if self.warningBg then
        self.warningBg:setVisible(not wasInspected)
    end
    if self.warningIcon then
        self.warningIcon:setVisible(not wasInspected)
    end
    if self.warningText then
        self.warningText:setVisible(not wasInspected)
    end
    if self.inspectPrompt then
        self.inspectPrompt:setVisible(not wasInspected)
        self.inspectPrompt:setText(string.format(g_i18n:getText("usedplus_preview_payForInspection"),
            g_i18n:formatMoney(self.inspectionCost, 0, true, true)))
    end

    if self.inspectedSection then
        self.inspectedSection:setVisible(wasInspected)
    end

    -- Update inspect button text and state
    if self.inspectButton then
        if wasInspected then
            self.inspectButton:setText(g_i18n:getText("usedplus_preview_viewReport"))
        else
            self.inspectButton:setText(string.format(g_i18n:getText("usedPlus_inspectButton"),
                g_i18n:formatMoney(self.inspectionCost, 0, true, true)))
        end
    end
end

--[[
    Close this dialog
]]
function UsedVehiclePreviewDialog:close()
    g_gui:closeDialogByName("UsedVehiclePreviewDialog")
end

--[[
    Button handler: Buy without inspection
]]
function UsedVehiclePreviewDialog:onClickBuyAsIs()
    self:close()

    -- Trigger purchase - callback is a CLOSURE, don't pass target!
    if self.onPurchaseCallback then
        UsedPlus.logDebug("onClickBuyAsIs: Triggering purchase callback")
        self.onPurchaseCallback(true, self.listing)
    end
end

--[[
    Button handler: Pay for inspection
]]
function UsedVehiclePreviewDialog:onClickInspect()
    local listing = self.listing
    local wasInspected = listing.usedPlusData and listing.usedPlusData.wasInspected

    if wasInspected then
        -- Already inspected - just show the report
        self:close()
        local inspectionDialog = InspectionReportDialog.getInstance()
        -- Pass all context needed for Purchase/Decline/Go Back
        inspectionDialog:show(listing, self.farmId, self.onInspectionComplete, self,
            self.onPurchaseCallback, self.callbackTarget)
    else
        -- Need to pay for inspection
        local farm = g_farmManager:getFarmById(self.farmId)
        if farm == nil then
            g_currentMission:showBlinkingWarning("Invalid farm!", 3000)
            return
        end

        -- Check if player can afford inspection
        if farm.money < self.inspectionCost then
            g_currentMission:showBlinkingWarning(
                string.format("Cannot afford inspection (%s required)",
                    g_i18n:formatMoney(self.inspectionCost, 0, true, true)),
                3000
            )
            return
        end

        -- Deduct inspection cost
        g_currentMission:addMoney(-self.inspectionCost, self.farmId, MoneyType.OTHER, true, true)

        -- Mark as inspected
        if listing.usedPlusData then
            listing.usedPlusData.wasInspected = true
        end

        -- Track statistics
        if g_financeManager then
            g_financeManager:incrementStatistic(self.farmId, "inspectionsPurchased", 1)
            g_financeManager:incrementStatistic(self.farmId, "totalInspectionFees", self.inspectionCost)
        end

        UsedPlus.logDebug(string.format("Inspection purchased for %s - cost: %s",
            listing.storeItemName, g_i18n:formatMoney(self.inspectionCost, 0, true, true)))

        -- Show the inspection report
        self:close()
        local inspectionDialog = InspectionReportDialog.getInstance()
        -- Pass all context needed for Purchase/Decline/Go Back
        inspectionDialog:show(listing, self.farmId, self.onInspectionComplete, self,
            self.onPurchaseCallback, self.callbackTarget)
    end
end

--[[
    Callback from inspection report dialog
]]
function UsedVehiclePreviewDialog:onInspectionComplete(confirmed, listing)
    UsedPlus.logDebug(string.format("UsedVehiclePreviewDialog:onInspectionComplete - confirmed=%s, listing=%s",
        tostring(confirmed), tostring(listing and listing.storeItemName)))

    if confirmed then
        -- Player wants to buy after seeing inspection
        UsedPlus.logDebug("onInspectionComplete: Player confirmed purchase")
        UsedPlus.logDebug(string.format("onInspectionComplete: self.onPurchaseCallback type = %s", type(self.onPurchaseCallback)))
        if self.onPurchaseCallback then
            -- IMPORTANT: The original callback from UsedVehicleManager is a CLOSURE
            -- that expects (confirmed, listing) - NOT a target parameter!
            -- Do NOT pass callbackTarget - it will shift the arguments!
            UsedPlus.logDebug("onInspectionComplete: Calling original callback (confirmed, listing)")
            local success, err = pcall(function()
                self.onPurchaseCallback(true, listing)
            end)
            if not success then
                UsedPlus.logError(string.format("onInspectionComplete: Callback failed with error: %s", tostring(err)))
            else
                UsedPlus.logDebug("onInspectionComplete: Callback completed successfully")
            end
        else
            UsedPlus.logWarn("onInspectionComplete: No onPurchaseCallback set!")
        end
    else
        -- Player declined - just log it, don't re-show (Decline means done)
        UsedPlus.logDebug("onInspectionComplete: Player declined purchase")
    end
end

--[[
    Button handler: Cancel
]]
function UsedVehiclePreviewDialog:onClickCancel()
    self:close()

    -- Callback is a CLOSURE, don't pass target!
    if self.onPurchaseCallback then
        self.onPurchaseCallback(false, self.listing)
    end
end

--[[
    Handle ESC key - same as cancel
]]
function UsedVehiclePreviewDialog:onClickBack()
    self:onClickCancel()
end

--[[
    Get descriptive condition text based on damage/wear value
    Simulates what a person would say looking at the vehicle visually (without exact measurements)
    @param value - 0-1 damage or wear value (0 = perfect, 1 = destroyed)
    @param conditionType - "mechanical" or "cosmetic"
    @return Descriptive string
]]
function UsedVehiclePreviewDialog:getConditionDescription(value, conditionType)
    local isMechanical = (conditionType == "mechanical")

    if value <= 0.05 then
        -- Nearly perfect
        return isMechanical and "Excellent" or "Like new"
    elseif value <= 0.15 then
        -- Very good
        return isMechanical and "Very good" or "Minor scratches"
    elseif value <= 0.30 then
        -- Good
        return isMechanical and "Good condition" or "Some wear visible"
    elseif value <= 0.50 then
        -- Fair
        return isMechanical and "Fair, shows use" or "Faded, needs touch-up"
    elseif value <= 0.70 then
        -- Worn
        return isMechanical and "Worn, needs work" or "Weathered, repaint advised"
    else
        -- Poor
        return isMechanical and "Poor, major repairs needed" or "Poor, significant fading"
    end
end

UsedPlus.logInfo("UsedVehiclePreviewDialog loaded")
