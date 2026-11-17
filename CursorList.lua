-- Lists the click-cast bindings for the currently held modifiers next to the cursor
-- while hovering a unit frame.
local ADDON_NAME, ns = ...

local MAX_LINES = 12
local LINE_SPACING = 2
local BACKDROP_PADDING = 6
local UPDATE_INTERVAL = 0.05

ns.defaults = {
    cursorList = true,
    showIcons = false,
    fontSize = 9,
    outline = true,
    border = false,
    background = false,
    backgroundOpacity = 80,
    offsetX = 30,
    offsetY = -10,
    buttonX = 16,
    buttonY = 12,
    minimap = { hide = false },
}

local BUTTON_NAMES = {
    LeftButton = "Left", RightButton = "Right", MiddleButton = "Middle",
    Button4 = "Button 4", Button5 = "Button 5",
}
local BUTTON_ORDER = { LeftButton = 1, RightButton = 2, MiddleButton = 3, Button4 = 4, Button5 = 5 }

local ClickType = Enum.ClickBindingType or { Spell = 1, Macro = 2, Interaction = 3, PetAction = 4 }
local Interaction = Enum.ClickBindingInteraction or { Target = 1, OpenContextMenu = 2 }

local list = CreateFrame("Frame", "ClickCastPlusCursorList", UIParent, "BackdropTemplate")
list:SetFrameStrata("TOOLTIP")
list:SetClampedToScreen(true)
list:EnableMouse(false)
list:Hide()

local fontPath = GameFontHighlightSmall:GetFont()

list.lines = {}
for i = 1, MAX_LINES do
    local row = CreateFrame("Frame", nil, list)
    row:SetSize(1, 1)
    local icon = row:CreateTexture(nil, "OVERLAY")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetJustifyH("LEFT")
    row.icon, row.text = icon, text
    list.lines[i] = row
end

-- Applies font, icon, backdrop and spacing settings to the list's widgets.
function ns.ApplyListStyle()
    local db = ns.db
    local size = db.fontSize
    local iconSize = db.showIcons and size + 3 or 0
    local rowHeight = math.max(size, iconSize) + 2
    local pad = (db.border or db.background) and BACKDROP_PADDING or 0

    if db.border or db.background then
        list:SetBackdrop({
            bgFile = db.background and "Interface\\Buttons\\WHITE8X8" or nil,
            edgeFile = db.border and "Interface\\Tooltips\\UI-Tooltip-Border" or nil,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        if db.background then
            list:SetBackdropColor(0, 0, 0, db.backgroundOpacity / 100)
        end
        if db.border then
            list:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        end
    else
        list:SetBackdrop(nil)
    end

    for i, row in ipairs(list.lines) do
        row:SetHeight(rowHeight)
        row:ClearAllPoints()
        if i == 1 then
            row:SetPoint("TOPLEFT", list, "TOPLEFT", pad, -pad)
        else
            row:SetPoint("TOPLEFT", list.lines[i - 1], "BOTTOMLEFT", 0, -LINE_SPACING)
        end
        row.icon:SetSize(math.max(iconSize, 1), math.max(iconSize, 1))
        row.icon:SetShown(db.showIcons)
        row.text:SetFont(fontPath, size, db.outline and "OUTLINE" or "")
        row.text:SetShadowOffset(db.outline and 0 or 1, db.outline and 0 or -1)
        row.text:ClearAllPoints()
        if db.showIcons then
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
        else
            row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
        end
    end
    list.rowHeight, list.iconSize, list.pad = rowHeight, iconSize, pad
    ns.RefreshList()
    if ns.UpdateWatcher then ns.UpdateWatcher() end
end

local function CurrentModifiers()
    if C_ClickBindings and C_ClickBindings.MakeModifiers then
        return C_ClickBindings.MakeModifiers()
    end
end

local function DescribeBinding(info)
    if info.type == ClickType.Spell then
        local name = C_Spell.GetSpellName(info.actionID)
        return name or ("Spell " .. tostring(info.actionID)), C_Spell.GetSpellTexture(info.actionID)
    elseif info.type == ClickType.Macro then
        local name, icon = GetMacroInfo(info.actionID)
        return (name or "Macro") .. " (macro)", icon
    elseif info.type == ClickType.Interaction then
        if info.actionID == Interaction.Target then
            return "Target unit", 132212
        elseif info.actionID == Interaction.OpenContextMenu then
            return "Open unit menu", 134331
        end
        return "Interaction", 134400
    elseif info.type == ClickType.PetAction then
        return "Pet action", 132599
    end
    return "Unknown", 134400
end

local function GetBindingsForModifiers(mods)
    local result = {}
    if not (C_ClickBindings and C_ClickBindings.GetProfileInfo) then return result end
    for _, info in ipairs(C_ClickBindings.GetProfileInfo() or {}) do
        if info.button and info.modifiers == mods then
            local name, icon = DescribeBinding(info)
            result[#result + 1] = {
                order = BUTTON_ORDER[info.button] or 99,
                button = BUTTON_NAMES[info.button] or info.button,
                name = name,
                icon = icon,
            }
        end
    end
    table.sort(result, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.button < b.button
    end)
    return result
end

local function GetHoveredFrame()
    if GetMouseFoci then
        return (GetMouseFoci())[1]
    elseif GetMouseFocus then
        return GetMouseFocus()
    end
end

-- Unit frames are secure unit buttons carrying a "unit" attribute; check the frame and a few parents.
local function IsOverUnitFrame()
    local f = GetHoveredFrame()
    for _ = 1, 4 do
        -- Forbidden frames (e.g. nameplates) error on any method call.
        if not f or f == WorldFrame or f == UIParent or (f.IsForbidden and f:IsForbidden()) then return false end
        if type(f.GetAttribute) == "function" then
            local unit = f:GetAttribute("unit")
            if type(unit) == "string" and unit ~= "" then
                return UnitExists(unit)
            end
        end
        f = type(f.GetParent) == "function" and f:GetParent() or nil
    end
    return false
end

local lastMods, lastX, lastY
local function Refresh(mods)
    lastMods = mods
    local bindings = GetBindingsForModifiers(mods)
    local showIcons = ns.db.showIcons
    local width = 0
    local shown = math.min(#bindings, MAX_LINES)
    for i = 1, MAX_LINES do
        local row, b = list.lines[i], bindings[i]
        if i <= shown then
            if showIcons then row.icon:SetTexture(b.icon or 134400) end
            row.text:SetText("|cffffd100" .. b.button .. ":|r " .. b.name)
            local w = row.text:GetStringWidth() + (showIcons and list.iconSize + 4 or 0)
            row:SetWidth(math.max(w, 1))
            row:Show()
            width = math.max(width, w)
        else
            row:Hide()
        end
    end
    local height = shown > 0 and (shown * list.rowHeight + (shown - 1) * LINE_SPACING) or 0
    list:SetSize(math.max(width + list.pad * 2, 1), math.max(height + list.pad * 2, 1))
    -- Hide the empty frame so an enabled backdrop doesn't show with no bindings.
    list:SetAlpha(shown > 0 and 1 or 0)
end

function ns.RefreshList()
    lastMods, lastX = nil, nil
end

local function PositionAtCursor(force)
    local x, y = GetCursorPosition()
    if not force and x == lastX and y == lastY then return end
    lastX, lastY = x, y
    local scale = UIParent:GetEffectiveScale()
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + ns.db.offsetX, y / scale + ns.db.offsetY)
end

local elapsed = 0
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function(_, dt)
    if not ns.db then return end
    elapsed = elapsed + dt
    if elapsed < UPDATE_INTERVAL then
        if list:IsShown() then PositionAtCursor() end
        return
    end
    elapsed = 0
    if IsOverUnitFrame() then
        if not list:IsShown() then
            Refresh(CurrentModifiers())
            PositionAtCursor(true)
            list:Show()
        else
            if lastMods == nil then Refresh(CurrentModifiers()) end
            PositionAtCursor()
        end
    elseif list:IsShown() then
        list:Hide()
    end
end)

-- The OnUpdate watcher only runs while the list feature is enabled.
function ns.UpdateWatcher()
    local on = ns.db and ns.db.cursorList
    watcher:SetShown(on)
    if not on then list:Hide() end
end

watcher:RegisterEvent("MODIFIER_STATE_CHANGED")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON_NAME then return end
        self:UnregisterEvent("ADDON_LOADED")
        ClickCastPlusDB = ClickCastPlusDB or {}
        local db = ClickCastPlusDB
        for k, v in pairs(ns.defaults) do
            if db[k] == nil then
                db[k] = type(v) == "table" and CopyTable(v) or v
            end
        end
        ns.db = db
        ns.ApplyListStyle()
        ns.ApplyButtonPosition()
        if ns.OnDBReady then ns.OnDBReady() end
        return
    end
    -- Modifier changed: redraw right away instead of waiting for the next tick.
    if list:IsShown() then Refresh(CurrentModifiers()) end
end)

function ns.ToggleCursorList()
    ns.db.cursorList = not ns.db.cursorList
    print("|cffffd100Click Cast Plus:|r cursor list " .. (ns.db.cursorList and "enabled" or "disabled"))
    ns.UpdateWatcher()
    if ns.RefreshSettings then ns.RefreshSettings() end
end
