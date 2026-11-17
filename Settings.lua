-- Settings window and minimap button.
local ADDON_NAME, ns = ...

local TITLE = "Click Cast Plus"

local settings = CreateFrame("Frame", "ClickCastPlusSettings", UIParent, "BasicFrameTemplateWithInset")
settings:SetSize(320, 590)
settings:SetPoint("CENTER")
settings:SetFrameStrata("DIALOG")
settings:SetMovable(true)
settings:SetClampedToScreen(true)
settings:EnableMouse(true)
settings:RegisterForDrag("LeftButton")
settings:SetScript("OnDragStart", settings.StartMoving)
settings:SetScript("OnDragStop", settings.StopMovingOrSizing)
settings:Hide()
tinsert(UISpecialFrames, "ClickCastPlusSettings")
settings.title = settings:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
settings.title:SetPoint("TOP", 0, -5)
settings.title:SetText(TITLE .. " - Settings")

local controls = {}
local nextY = -36

local function OnChanged()
    ns.ApplyListStyle()
    ns.ApplyButtonPosition()
end

local function AddCheckbox(key, label, onClick)
    local cb = CreateFrame("CheckButton", nil, settings, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", 16, nextY)
    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb.label:SetText(label)
    cb:SetScript("OnClick", function(self)
        if onClick then
            onClick(self:GetChecked())
        else
            ns.db[key] = self:GetChecked() and true or false
            OnChanged()
        end
    end)
    cb.Refresh = function(self)
        if key then self:SetChecked(ns.db[key]) end
    end
    controls[#controls + 1] = cb
    nextY = nextY - 28
    return cb
end

local function AddSlider(key, label, minV, maxV)
    local holder = CreateFrame("Frame", nil, settings)
    holder:SetSize(280, 44)
    holder:SetPoint("TOPLEFT", 20, nextY - 4)

    holder.label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    holder.label:SetPoint("TOPLEFT", 0, 0)
    holder.label:SetText(label)
    holder.value = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    holder.value:SetPoint("TOPRIGHT", 0, 0)

    local s = CreateFrame("Slider", nil, holder, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(220, 17)
    s:SetPoint("TOPLEFT", holder.label, "BOTTOMLEFT", 22, -6)
    s:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(1)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(self:GetValue() + delta)
    end)
    s:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v + 0.5)
        holder.value:SetText(v)
        if ns.db and ns.db[key] ~= v then
            ns.db[key] = v
            OnChanged()
        end
    end)

    local function StepButton(text, delta, point, rel, relPoint, x)
        local b = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
        b:SetSize(20, 18)
        b:SetText(text)
        b:SetPoint(point, s, relPoint, x, 0)
        b:SetScript("OnClick", function() s:SetValue(s:GetValue() + delta) end)
        return b
    end
    StepButton("-", -1, "RIGHT", s, "LEFT", -2)
    StepButton("+", 1, "LEFT", s, "RIGHT", 2)

    holder.Refresh = function()
        s:SetValue(ns.db[key])
        holder.value:SetText(ns.db[key])
    end
    controls[#controls + 1] = holder
    nextY = nextY - 52
    return holder
end

AddCheckbox("cursorList", "Show binding list over unit frames")
AddCheckbox("showIcons", "Show spell icons")
AddCheckbox("outline", "Outline list text")
AddCheckbox("border", "Show list border")
AddCheckbox("background", "Show list background")
local minimapCheck = AddCheckbox(nil, "Show minimap button", function(checked)
    ns.SetMinimapShown(checked)
end)
minimapCheck.Refresh = function(self)
    self:SetChecked(not ns.db.minimap.hide)
end
nextY = nextY - 6
AddSlider("fontSize", "List font size", 6, 24)
AddSlider("backgroundOpacity", "Background opacity (%)", 0, 100)
AddSlider("offsetX", "List X offset (from cursor)", -200, 200)
AddSlider("offsetY", "List Y offset (from cursor)", -200, 200)
AddSlider("buttonX", "Spellbook button X (from bottom left)", 0, 1200)
AddSlider("buttonY", "Spellbook button Y (from bottom left)", 0, 800)

local reset = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
reset:SetSize(120, 22)
reset:SetPoint("BOTTOMLEFT", 14, 12)
reset:SetText("Reset to defaults")
reset:SetScript("OnClick", function()
    for k, v in pairs(ns.defaults) do
        if k ~= "minimap" then ns.db[k] = v end
    end
    OnChanged()
    ns.RefreshSettings()
end)

local open = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
open:SetSize(120, 22)
open:SetPoint("BOTTOMRIGHT", -14, 12)
open:SetText(CLICK_CAST_BINDINGS or "Click Casting")
open:SetScript("OnClick", function() ns.ToggleClickCasting() end)

function ns.RefreshSettings()
    if not ns.db then return end
    for _, c in ipairs(controls) do c:Refresh() end
end
settings:SetScript("OnShow", ns.RefreshSettings)

function ns.ToggleSettings()
    settings:SetShown(not settings:IsShown())
end

-- Minimap button: a LibDataBroker launcher shown by LibDBIcon (same approach as PriceSnipe).
local LDB = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
local LDBIcon = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)

local launcher = LDB and LDB:NewDataObject(ADDON_NAME, {
    type = "launcher",
    text = TITLE,
    icon = "Interface\\CURSOR\\Point",
    OnClick = function(_, mouseButton)
        if mouseButton == "RightButton" then
            ns.ToggleClickCasting()
        else
            ns.ToggleSettings()
        end
    end,
    OnTooltipShow = function(tip)
        tip:AddLine(TITLE)
        tip:AddLine("|cffffffffLeft-click:|r Settings")
        tip:AddLine("|cffffffffRight-click:|r Click Casting window")
        tip:AddLine("|cffffffffDrag:|r Move button")
    end,
})

function ns.SetMinimapShown(show)
    ns.db.minimap.hide = not show
    if LDBIcon then
        if show then LDBIcon:Show(ADDON_NAME) else LDBIcon:Hide(ADDON_NAME) end
    end
    ns.RefreshSettings()
end

-- Called from CursorList.lua once SavedVariables are ready (at ADDON_LOADED).
function ns.OnDBReady()
    if LDBIcon and launcher and not LDBIcon:IsRegistered(ADDON_NAME) then
        LDBIcon:Register(ADDON_NAME, launcher, ns.db.minimap)
    end
end
