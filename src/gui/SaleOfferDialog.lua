--[[
    FS25_UsedPlus - Sale Offer Dialog

     Dialog for accepting or declining sale offers
     Shown when agent finds a buyer for your vehicle
     Pattern from MessageDialog (working reference)

    Features:
    - Shows offer amount and percentage of vanilla sell
    - Expiration countdown
    - Accept (sell vehicle) or Decline (keep searching)
    - Comparison with vanilla sell price
]]

SaleOfferDialog = {}
local SaleOfferDialog_mt = Class(SaleOfferDialog, MessageDialog)

--[[
     Constructor
]]
function SaleOfferDialog.new(target, custom_mt, i18n)
    local self = MessageDialog.new(target, custom_mt or SaleOfferDialog_mt)

    self.i18n = i18n or g_i18n

    -- Data
    self.listing = nil
    self.callback = nil

    return self
end

--[[
     Set the listing with pending offer
    @param listing - VehicleSaleListing with pending offer
    @param callback - Function called with (accepted: boolean) on decision
]]
function SaleOfferDialog:setListing(listing, callback)
    self.listing = listing
    self.callback = callback

    UsedPlus.logDebug(string.format("SaleOfferDialog: Set listing %s with offer $%d",
        listing.id, listing.currentOffer or 0))
end

--[[
     Called when dialog opens
]]
function SaleOfferDialog:onOpen()
    SaleOfferDialog:superClass().onOpen(self)

    self:updateDisplay()
end

--[[
     Update all display elements
     Refactored to use UIHelper utilities for consistent formatting
]]
function SaleOfferDialog:updateDisplay()
    if self.listing == nil then return end

    -- Vehicle name
    UIHelper.Element.setText(self.vehicleNameText, self.listing.vehicleName or "Unknown Vehicle")

    -- Vehicle image (using UIHelper for consistent image handling)
    UIHelper.Image.setImagePath(self.vehicleImage, self.listing.vehicleImageFile)

    -- Agent tier
    UIHelper.Element.setText(self.agentTierText, string.format("via %s", self.listing:getTierName()))

    -- Offer amount (green for money coming in)
    UIHelper.Finance.displayTotalCost(self.offerAmountText, self.listing.currentOffer or 0)

    -- Percentage of vanilla sell
    local percent = 0
    if self.listing.vanillaSellPrice > 0 and self.listing.currentOffer then
        percent = math.floor((self.listing.currentOffer / self.listing.vanillaSellPrice) * 100)
    end
    UIHelper.Element.setText(self.offerPercentText, UIHelper.Text.formatPercent(percent, false))

    -- Expiration time (using UIHelper for consistent time formatting)
    UIHelper.Element.setText(self.expirationText, UIHelper.Text.formatHours(self.listing.offerExpiresIn or 0))

    -- Comparison section: vanilla vs this offer
    UIHelper.Element.setText(self.vanillaSellText, UIHelper.Text.formatMoney(self.listing.vanillaSellPrice or 0))

    -- This offer with green highlight (better than vanilla)
    UIHelper.Element.setTextWithColor(
        self.thisOfferText,
        UIHelper.Text.formatMoney(self.listing.currentOffer or 0),
        UIHelper.Colors.MONEY_GREEN
    )
end

--[[
     Handle accept button click
]]
function SaleOfferDialog:onClickAccept()
    if self.listing == nil then
        self:close()
        return
    end

    -- Call callback with accepted = true
    if self.callback then
        self.callback(true)
    end

    UsedPlus.logDebug(string.format("Offer accepted for %s: $%d",
        self.listing.vehicleName, self.listing.currentOffer or 0))

    self:close()
end

--[[
     Handle decline button click
]]
function SaleOfferDialog:onClickDecline()
    -- Call callback with accepted = false
    if self.callback then
        self.callback(false)
    end

    UsedPlus.logDebug(string.format("Offer declined for %s",
        self.listing and self.listing.vehicleName or "Unknown"))

    self:close()
end

--[[
     Show the offer dialog for a listing
     Static helper function
    @param listing - VehicleSaleListing with pending offer
    @param callback - Function called with (accepted: boolean)
]]
--[[
     Static show method - refactored to use DialogLoader
]]
function SaleOfferDialog.showForListing(listing, callback)
    if listing == nil or not listing:hasPendingOffer() then
        UsedPlus.logError("Cannot show offer dialog - no pending offer")
        return
    end

    -- Use DialogLoader for centralized lazy loading
    DialogLoader.show("SaleOfferDialog", "setListing", listing, callback)
end

UsedPlus.logInfo("SaleOfferDialog loaded")
