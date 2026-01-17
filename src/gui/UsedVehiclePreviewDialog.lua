--[[
    FS25_UsedPlus - Used Vehicle Preview Dialog
    v2.7.0: Tiered delayed inspection system

    Shows used vehicle details with option to inspect or buy as-is.
    This is the entry point for the inspection system.
    Pattern from: ScreenElement (NOT MessageDialog - that causes conflicts)

    Flow:
    1. Player views used vehicle listing
    2. This dialog shows visible stats + warning about hidden condition
    3. Player can:
       a) Buy As-Is - Purchase without knowing reliability
       b) Request Inspection - Choose tier (Quick/Standard/Comprehensive)
       c) View Report - If inspection is complete
       d) Cancel - Return to previous screen

    v2.7.0 Changes:
    - Inspections are no longer instant - they take game time
    - Three tiers with different costs, times, and data revealed
    - Shows progress when inspection is in progress
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
    self.search = nil  -- v2.7.0: Need search reference for inspection request
    self.farmId = nil
    self.onPurchaseCallback = nil
    self.callbackTarget = nil
    self.isBackAllowed = true

    -- v2.7.0: Tier costs calculated on show
    self.tierCosts = {}

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
    @param search - (Optional) The search object containing this listing
]]
function UsedVehiclePreviewDialog:show(listing, farmId, onPurchaseCallback, callbackTarget, search)
    self.listing = listing
    self.farmId = farmId
    self.onPurchaseCallback = onPurchaseCallback
    self.callbackTarget = callbackTarget
    self.search = search

    -- v2.7.0: Calculate tier costs
    self.tierCosts = UsedPlusMaintenance.getInspectionTierOptions(listing.price or 0)

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
    v2.7.0: Get current inspection state
    @return "none", "pending", or "complete"
]]
function UsedVehiclePreviewDialog:getInspectionState()
    local listing = self.listing
    if listing == nil then return "none" end

    if listing.inspectionState == "pending" then
        return "pending"
    end
    if listing.inspectionState == "complete" then
        return "complete"
    end

    return "none"
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

    -- v2.7.0: Update based on inspection state
    local inspectionState = self:getInspectionState()

    -- Update section visibility based on state
    self:updateInspectionSections(inspectionState)

    -- Update buttons based on state
    self:updateButtons(inspectionState)
end

--[[
    v2.7.0: Update inspection section visibility
]]
function UsedVehiclePreviewDialog:updateInspectionSections(inspectionState)
    local listing = self.listing

    -- Warning section (not inspected)
    local showWarning = (inspectionState == "none")
    if self.warningBg then self.warningBg:setVisible(showWarning) end
    if self.warningIcon then self.warningIcon:setVisible(showWarning) end
    if self.warningText then self.warningText:setVisible(showWarning) end

    -- Tier selection (not inspected) - show cost summary
    if self.inspectPrompt and showWarning then
        self.inspectPrompt:setVisible(true)
        -- Show tier range instead of single price
        local minCost = self.tierCosts[1] and self.tierCosts[1].cost or 0
        local maxCost = self.tierCosts[3] and self.tierCosts[3].cost or 0
        local promptText = string.format(
            g_i18n:getText("usedplus_preview_inspectionRange") or "Inspection options: %s - %s",
            g_i18n:formatMoney(minCost, 0, true, true),
            g_i18n:formatMoney(maxCost, 0, true, true)
        )
        self.inspectPrompt:setText(promptText)
    elseif self.inspectPrompt then
        self.inspectPrompt:setVisible(false)
    end

    -- Progress section (inspection pending)
    local showProgress = (inspectionState == "pending")
    if self.progressSection then
        self.progressSection:setVisible(showProgress)
    end
    if showProgress and self.progressText then
        local hoursRemaining = 0
        if g_usedVehicleManager then
            hoursRemaining = g_usedVehicleManager:getInspectionHoursRemaining(listing)
        end
        local tierName = "Standard"
        if listing.inspectionTier and UsedPlusMaintenance.CONFIG.inspectionTiers[listing.inspectionTier] then
            tierName = UsedPlusMaintenance.CONFIG.inspectionTiers[listing.inspectionTier].name
        end
        local progressMsg = string.format(
            g_i18n:getText("usedplus_preview_inspectionProgress") or "%s inspection in progress... ~%d hrs remaining",
            tierName, hoursRemaining
        )
        self.progressText:setText(progressMsg)
    end

    -- Inspected section (complete)
    local showInspected = (inspectionState == "complete")
    if self.inspectedSection then
        self.inspectedSection:setVisible(showInspected)
    end
end

--[[
    v2.7.0: Update button states based on inspection state
]]
function UsedVehiclePreviewDialog:updateButtons(inspectionState)
    -- Update inspect button text based on state
    if self.inspectButton then
        if inspectionState == "complete" then
            -- Show "View Report" button
            self.inspectButton:setText(g_i18n:getText("usedplus_preview_viewReport") or "View Report")
            self.inspectButton:setVisible(true)
        elseif inspectionState == "pending" then
            -- Disable inspect button while in progress
            self.inspectButton:setText(g_i18n:getText("usedplus_preview_inProgress") or "In Progress...")
            self.inspectButton:setDisabled(true)
            self.inspectButton:setVisible(true)
        else
            -- Show "Request Inspection" - clicking opens tier selection
            self.inspectButton:setText(g_i18n:getText("usedplus_preview_requestInspection") or "Request Inspection")
            self.inspectButton:setDisabled(false)
            self.inspectButton:setVisible(true)
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
    Button handler: Inspect button clicked
    v2.7.0: Opens tier selection dialog if not inspected
]]
function UsedVehiclePreviewDialog:onClickInspect()
    local listing = self.listing
    local inspectionState = self:getInspectionState()

    if inspectionState == "complete" then
        -- Already inspected - show the report
        self:close()
        local inspectionDialog = InspectionReportDialog.getInstance()
        inspectionDialog:show(listing, self.farmId, self.onInspectionComplete, self,
            self.onPurchaseCallback, self.callbackTarget)
    elseif inspectionState == "pending" then
        -- In progress - do nothing (button should be disabled)
        g_currentMission:showBlinkingWarning(
            g_i18n:getText("usedplus_inspection_alreadyPending") or "Inspection already in progress!",
            3000
        )
    else
        -- Not inspected - open tier selection dialog
        self:showTierSelectionDialog()
    end
end

--[[
    v2.7.0: Show tier selection dialog
    Uses InfoDialog with options to select inspection tier
]]
function UsedVehiclePreviewDialog:showTierSelectionDialog()
    local listing = self.listing

    -- Build options text
    local options = {}
    for i, tier in ipairs(self.tierCosts) do
        local tierConfig = UsedPlusMaintenance.CONFIG.inspectionTiers[i]
        local optionText = string.format("%s - %s (~%d hrs)",
            tier.name,
            g_i18n:formatMoney(tier.cost, 0, true, true),
            tier.durationHours
        )
        table.insert(options, { text = optionText, tier = i })
    end

    -- Show selection dialog using YesNoDialog pattern
    -- For now, we'll use a simpler approach: show 3 buttons on the dialog
    -- or use InfoDialog with callback

    -- Build description for each tier
    local tierDescriptions = {
        g_i18n:getText("usedplus_tier_quick_desc") or "Overall rating only",
        g_i18n:getText("usedplus_tier_standard_desc") or "Full reliability + parts condition",
        g_i18n:getText("usedplus_tier_comprehensive_desc") or "Full details + DNA hint + repair estimate"
    }

    local messageText = g_i18n:getText("usedplus_selectInspectionTier") or "Select Inspection Type:\n\n"
    for i, tier in ipairs(self.tierCosts) do
        messageText = messageText .. string.format("[%d] %s - %s (~%d hrs)\n    %s\n\n",
            i, tier.name,
            g_i18n:formatMoney(tier.cost, 0, true, true),
            tier.durationHours,
            tierDescriptions[i] or ""
        )
    end

    -- Use TextInputDialog approach or just cycle through with button clicks
    -- For MVP: Use InfoDialog and have 3 separate buttons call tier-specific handlers

    -- Show a yes/no dialog for the recommended (Standard) tier
    local standardTier = self.tierCosts[2]
    local confirmText = string.format(
        g_i18n:getText("usedplus_confirmInspection") or "Request %s inspection for %s?\n\nReady in ~%d hours.",
        standardTier.name,
        g_i18n:formatMoney(standardTier.cost, 0, true, true),
        standardTier.durationHours
    )

    -- Use the correct YesNoDialog.show(callback, target, text) pattern
    YesNoDialog.show(
        function(target, yes)
            if yes then
                self:requestInspectionTier(2)  -- Standard tier
            end
        end,
        self,
        confirmText
    )
end

--[[
    v2.7.0: Request inspection at specified tier
    @param tierIndex - 1=Quick, 2=Standard, 3=Comprehensive
]]
function UsedVehiclePreviewDialog:requestInspectionTier(tierIndex)
    local listing = self.listing

    if g_usedVehicleManager == nil then
        g_currentMission:showBlinkingWarning("Used vehicle system not available!", 3000)
        return
    end

    -- Request the inspection
    local success, errorMsg = g_usedVehicleManager:requestInspection(
        listing,
        self.search,
        tierIndex,
        self.farmId
    )

    if success then
        -- Refresh display to show pending state
        self:updateDisplay()
    else
        g_currentMission:showBlinkingWarning(
            string.format(g_i18n:getText("usedplus_inspection_failed") or "Inspection failed: %s", errorMsg or "Unknown error"),
            3000
        )
    end
end

--[[
    v2.7.0: Tier button handlers (if using dedicated buttons)
]]
function UsedVehiclePreviewDialog:onClickTierQuick()
    self:requestInspectionTier(1)
end

function UsedVehiclePreviewDialog:onClickTierStandard()
    self:requestInspectionTier(2)
end

function UsedVehiclePreviewDialog:onClickTierComprehensive()
    self:requestInspectionTier(3)
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

UsedPlus.logInfo("UsedVehiclePreviewDialog loaded (v2.7.0 - tiered inspection system)")
