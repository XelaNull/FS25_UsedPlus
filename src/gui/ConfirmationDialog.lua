--[[
    FS25_UsedPlus - Confirmation Dialog

    Simple info/confirmation dialog with just a message and OK button.
    Reusable throughout the mod for showing confirmation messages.

    Pattern from: MessageDialog (standard UsedPlus pattern)

    Usage:
        DialogLoader.show("ConfirmationDialog", "setMessage", "Your message here", "Optional Title")
]]

ConfirmationDialog = {}
local ConfirmationDialog_mt = Class(ConfirmationDialog, MessageDialog)

function ConfirmationDialog.new(target, customMt)
    local self = MessageDialog.new(target, customMt or ConfirmationDialog_mt)

    self.messageText = nil
    self.titleText = nil

    return self
end

function ConfirmationDialog:onCreate()
    ConfirmationDialog:superClass().onCreate(self)
end

function ConfirmationDialog:onOpen()
    ConfirmationDialog:superClass().onOpen(self)
end

--[[
    Set the message to display
    @param message - The message text
    @param title - Optional title (defaults to "Confirmation")
]]
function ConfirmationDialog:setMessage(message, title)
    if self.messageText then
        self.messageText:setText(message or "")
    end

    if self.dialogTitleElement then
        self.dialogTitleElement:setText(title or g_i18n:getText("usedplus_confirmation_title") or "Confirmation")
    end
end

--[[
    OK button callback
]]
function ConfirmationDialog:onClickOk()
    self:close()
end

function ConfirmationDialog:onClose()
    ConfirmationDialog:superClass().onClose(self)
end

UsedPlus.logInfo("ConfirmationDialog loaded")
