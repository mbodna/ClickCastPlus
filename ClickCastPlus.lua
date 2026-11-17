local ADDON_NAME, ns = ...

local LABEL = CLICK_CAST_BINDINGS or "Click Casting"

function ns.ToggleClickCasting()
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT or "Can't do that in combat.", 1, 0.1, 0.1)
        return
    end
    if type(ToggleClickBindingFrame) == "function" then
        ToggleClickBindingFrame()
        return
    end
    if not C_AddOns.IsAddOnLoaded("Blizzard_ClickBindingUI") then
        C_AddOns.LoadAddOn("Blizzard_ClickBindingUI")
    end
    local cbf = _G.ClickBindingFrame
    if not cbf then return end
    if cbf:IsShown() then
        HideUIPanel(cbf)
    else
        ShowUIPanel(cbf)
    end
end

function ns.ApplyButtonPosition()
    local psf = _G.PlayerSpellsFrame
    local b = type(psf) == "table" and psf.SCCButton
    if not b then return end
    local db = ns.db or ns.defaults
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", psf, "BOTTOMLEFT", db.buttonX, db.buttonY)
end

local function CreateSpellbookButton()
    local psf = _G.PlayerSpellsFrame
    if type(psf) ~= "table" then return false end
    if psf.SCCButton then return true end

    local sbf = type(psf.SpellBookFrame) == "table" and psf.SpellBookFrame or psf
    local b = CreateFrame("Button", "ClickCastPlusButton", sbf, "UIPanelButtonTemplate")
    b:SetText(LABEL)
    b:SetSize(b:GetFontString():GetStringWidth() + 24, 22)
    b:SetFrameLevel(sbf:GetFrameLevel() + 10)
    psf.SCCButton = b
    ns.ApplyButtonPosition()

    b:SetScript("OnClick", function() ns.ToggleClickCasting() end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(LABEL, 1, 0.82, 0)
        GameTooltip:AddLine("Open the Click Casting window to bind spells to mouse clicks on unit frames.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return true
end

-- PlayerSpellsFrame comes from a load-on-demand addon; retry after each addon loads until it exists.
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name ~= "Blizzard_PlayerSpells" and name ~= ADDON_NAME then return end
    local ok, done = pcall(CreateSpellbookButton)
    if not ok then
        geterrorhandler()(done)
        self:UnregisterAllEvents()
    elseif done then
        self:UnregisterAllEvents()
    end
end)

SLASH_CLICKCASTPLUS1 = "/clickcast"
SlashCmdList.CLICKCASTPLUS = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "list" then
        ns.ToggleCursorList()
    elseif cmd == "settings" or cmd == "config" or cmd == "options" then
        ns.ToggleSettings()
    elseif cmd == "minimap" then
        ns.SetMinimapShown(ns.db.minimap.hide)
    else
        ns.ToggleClickCasting()
    end
end
