-- The manage window: which buttons are in the drawer, their order, and how the drawer
-- looks. Opened from the "Set" cell in the drawer or with /bd config.
--
-- Every action is a button: nothing is dragged and nothing hides behind a right-click.

local ADDON, ns = ...

local ROWS, ROW_HEIGHT = 8, 30
local WIDTH, PAD = 520, 12
local BAR = 12                 -- the scroll bar beside the list
local LIST_TOP = 70

-- One flat look: a grey window, darker rows, thin outlines, blue for what is switched on.
local C = {
    panel = { 0.10, 0.10, 0.11, 0.97 }, border = { 0.38, 0.38, 0.40, 1 },
    rowA = { 0.09, 0.10, 0.13, 1 }, rowB = { 0.12, 0.13, 0.17, 1 }, rowHover = { 0.18, 0.26, 0.36, 0.45 },
    button = { 0.15, 0.15, 0.16, 1 }, edge = { 0.28, 0.29, 0.32, 1 }, on = { 0.10, 0.20, 0.31, 1 },
    accent = { 0.52, 0.80, 1.00, 1 }, hover = { 0.58, 0.80, 1.00, 1 }, input = { 0.045, 0.05, 0.065, 1 },
    text = { 0.95, 0.95, 0.96 }, dim = { 0.60, 0.62, 0.68 },
}

local window, rows = nil, {}
local offset = 0
local macroNote
local countText, sizeText, columnsText, hoverSwitch, keepSwitch, upPage, downPage, scrollBar

local function Fill(parent, color, layer)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    return texture
end

-- A one pixel outline; the returned function recolours it.
local function Outline(frame, color)
    local edges = {}
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
        { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local edge = frame:CreateTexture(nil, "BORDER")
        edge:SetPoint(side[1])
        edge:SetPoint(side[2])
        if side[3] then edge:SetHeight(1) else edge:SetWidth(1) end
        edges[#edges + 1] = edge
    end
    local function Paint(c)
        for _, edge in ipairs(edges) do edge:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
    end
    Paint(color)
    return Paint
end

local function Text(parent, text, template, color)
    local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlightSmall")
    label:SetText(text)
    color = color or C.text
    label:SetTextColor(color[1], color[2], color[3])
    return label
end

local function Heading(parent, text)
    local label = Text(parent, text, "GameFontHighlightSmall", C.accent)
    local rule = parent:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
    rule:SetSize(26, 1)
    rule:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.55)
    return label
end

local function Tooltip(frame, title, body)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(title, 1, 1, 1)
        if body then GameTooltip:AddLine(body, 0.8, 0.8, 0.85, true) end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Paint(button)
    local fill, edge = C.button, C.edge
    if button.lit then fill, edge = C.on, C.accent end
    local r, g, b = fill[1], fill[2], fill[3]
    if button.hovered and button:IsEnabled() then
        r, g, b = r + 0.05, g + 0.06, b + 0.08
        if edge == C.edge then edge = C.hover end
    end
    button.fill:SetColorTexture(r, g, b, 1)
    button.outline(edge)
    local text = (not button:IsEnabled() and C.dim) or button.textColor or C.text
    button.label:SetTextColor(text[1], text[2], text[3])
    button:SetAlpha(button:IsEnabled() and 1 or 0.45)
end

local function Flat(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 20)
    button.fill = Fill(button, C.button)
    button.outline = Outline(button, C.edge)
    button.label = Text(button, text)
    button.label:SetPoint("CENTER", 0, 0)
    button:SetScript("OnEnter", function(self) self.hovered = true Paint(self) end)
    button:SetScript("OnLeave", function(self) self.hovered = false Paint(self) end)
    button:SetScript("OnClick", function(self) onClick(self) end)
    function button:SetUsable(usable)
        self:SetEnabled(usable and true or false)
        Paint(self)
    end
    Paint(button)
    return button
end

-- A switch: a button with a tick box. Blue and ticked when on.
local function Switch(parent, text, width, onClick)
    local button = Flat(parent, text, width, function(self) onClick(not self.on) end)
    local box = CreateFrame("Frame", nil, button)
    box:SetSize(10, 10)
    box:SetPoint("LEFT", 6, 0)
    Fill(box, C.input)
    local boxEdge = Outline(box, C.border)
    local tick = box:CreateTexture(nil, "ARTWORK")
    tick:SetPoint("TOPLEFT", 2, -2)
    tick:SetPoint("BOTTOMRIGHT", -2, 2)
    tick:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT", box, "RIGHT", 5, 0)
    function button:Set(on)
        self.on = on and true or false
        self.lit = self.on
        self.textColor = self.on and C.text or C.dim
        tick:SetShown(self.on)
        boxEdge(self.on and C.accent or C.border)
        Paint(self)
    end
    button:Set(false)
    return button
end

-- "- value +": returns the value text.
local function Stepper(parent, anchor, width, onStep)
    local smaller = Flat(parent, "-", 22, function() onStep(-1) end)
    smaller:SetPoint("LEFT", anchor, "RIGHT", 8, 0)
    local value = Text(parent, "")
    value:SetPoint("LEFT", smaller, "RIGHT", 4, 0)
    value:SetWidth(width)
    local bigger = Flat(parent, "+", 22, function() onStep(1) end)
    bigger:SetPoint("LEFT", value, "RIGHT", 4, 0)
    return value, bigger
end

-- A readable name for a button frame: "LibDBIcon10_Questie" is "Questie".
local function DisplayName(name)
    local short = string.gsub(name, "^LibDBIcon10_", "")
    short = string.gsub(short, "Mini[Mm]apButton$", "")
    short = string.gsub(short, "MinimapIcon$", "")
    short = string.gsub(short, "_+$", "")
    return short ~= "" and short or name
end

-- The picture on a minimap button: its icon field, or its first plain texture.
local function IconOf(frame)
    if not frame then return nil end
    local icon = frame.icon
    if type(icon) == "table" and icon.GetTexture and icon:GetTexture() then return icon:GetTexture() end
    for _, layer in ipairs({ "ARTWORK", "BACKGROUND" }) do
        for _, region in ipairs({ frame:GetRegions() }) do
            if region:GetObjectType() == "Texture" and region:GetDrawLayer() == layer and region:GetTexture() then
                return region:GetTexture()
            end
        end
    end
end

-- ------------------------------------------------------------------ macros
-- A macro that does what a click on a button would do, so an addon's window can be opened
-- from an action bar like a spell. The macro is made (or brought up to date) and put on the
-- cursor; one click on an action bar slot puts it there.

local MACRO_NAME_MAX = 16          -- the game cuts longer macro names
-- Never the question mark (134400): the game reads that as "choose the icon from the macro
-- text", finds nothing to show in "/click" or "/bd", and after a while draws a green square.
local QUESTION_MARK = 134400
local ICON_ADDON = "INV_Misc_EngGizmos_19"
local ICON_ERRORS = "INV_Misc_Note_02"
local ICON_SETTINGS = "INV_Misc_Wrench_01"

-- A macro icon from a button's picture: a file id as it is, an Interface\Icons path as its
-- icon name; any other picture (addon art outside the icon folder) gets the fallback.
local function MacroIcon(icon, fallback)
    if type(icon) == "number" and icon > 0 and icon ~= QUESTION_MARK then return icon end
    if type(icon) == "string" then
        local short = string.match(string.lower(icon), "^interface[\\/]+icons[\\/]+([%w_]+)")
        if short and string.lower(short) ~= "inv_misc_questionmark" then return short end
    end
    return fallback
end

local function Say(text, r, g, b)
    if macroNote then
        macroNote:SetText(text)
        macroNote:SetTextColor(r or C.text[1], g or C.text[2], b or C.text[3])
    end
    print("|cff84ccffButton Drawer:|r " .. text)
end

-- name: macro name; icon: a file id or icon name (already through MacroIcon); body: the macro text.
local function MakeMacro(name, icon, body)
    if InCombatLockdown() then
        Say("Macros cannot be made in combat. Try again after the fight.", 1, 0.4, 0.4)
        return
    end
    name = string.sub(name, 1, MACRO_NAME_MAX)
    local index = GetMacroIndexByName(name)
    local made
    if index and index > 0 then
        EditMacro(index, name, icon, body)
    else
        local account, character = GetNumMacros()
        local consts = Constants and Constants.MacroConsts
        local accountMax = consts and consts.MAX_ACCOUNT_MACROS or 120
        local characterMax = consts and consts.MAX_CHARACTER_MACROS or 30
        if (account or 0) < accountMax then
            index = CreateMacro(name, icon, body, false)
        elseif (character or 0) < characterMax then
            index = CreateMacro(name, icon, body, true)
        else
            Say("Your macro list is full. Delete a macro in /macro first.", 1, 0.4, 0.4)
            return
        end
        made = true
    end
    if not index or index == 0 then
        Say("The game did not make the macro.", 1, 0.4, 0.4)
        return
    end
    PickupMacro(index)
    Say(string.format("Macro \"%s\" %s and is on your mouse: click an action bar slot to put it there.",
        name, made and "made" or "updated"), C.accent[1], C.accent[2], C.accent[3])
end

-- Macros made by 1.3.x carry the question mark and turn green. Give every "BD ..." macro of
-- ours a fixed icon again; called once after login, out of combat.
function ns.RepairMacros()
    if InCombatLockdown() or not GetNumMacros then return end
    local account, character = GetNumMacros()
    local consts = Constants and Constants.MacroConsts
    local accountMax = consts and consts.MAX_ACCOUNT_MACROS or 120
    local indexes = {}
    for i = 1, account or 0 do indexes[#indexes + 1] = i end
    for i = 1, character or 0 do indexes[#indexes + 1] = accountMax + i end
    for _, index in ipairs(indexes) do
        local name, _, body = GetMacroInfo(index)
        if name and body and string.sub(name, 1, 3) == "BD " then
            local icon
            local target = string.match(body, "^/click ([%w_]+)%s*$")
            if target then
                icon = MacroIcon(IconOf(_G[target]), ICON_ADDON)
            elseif string.match(body, "^/bd errors%s*$") then
                icon = ICON_ERRORS
            elseif string.match(body, "^/bd config%s*$") then
                icon = ICON_SETTINGS
            end
            if icon then EditMacro(index, name, icon, body) end
        end
    end
end

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, window)
    row:SetSize(WIDTH - 2 * PAD - BAR - 4, ROW_HEIGHT - 2)
    row:SetPoint("TOPLEFT", PAD, -LIST_TOP - (index - 1) * ROW_HEIGHT)
    row:EnableMouse(true)
    Fill(row, index % 2 == 1 and C.rowA or C.rowB)
    local glow = row:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(C.rowHover[1], C.rowHover[2], C.rowHover[3], C.rowHover[4])

    row.on = Switch(row, "On", 42, function(on)
        if row.entry then ns.SetInDrawer(row.entry.name, on) end
    end)
    row.on:SetPoint("LEFT", 6, 0)
    Tooltip(row.on, "In the drawer", "Unticked: this button goes back onto the minimap and stays there.")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", 56, 0)

    row.name = Text(row, "", "GameFontHighlight")
    row.name:SetPoint("LEFT", 86, 0)
    row.name:SetWidth(138)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.note = Text(row, "", "GameFontHighlightSmall", C.dim)
    row.note:SetPoint("LEFT", 228, 0)

    row.down = Flat(row, "Down", 44, function()
        if row.entry then ns.MoveButton(row.entry.name, 1) end
    end)
    row.down:SetPoint("RIGHT", -6, 0)
    Tooltip(row.down, "Later in the drawer")
    row.up = Flat(row, "Up", 30, function()
        if row.entry then ns.MoveButton(row.entry.name, -1) end
    end)
    row.up:SetPoint("RIGHT", row.down, "LEFT", -4, 0)
    Tooltip(row.up, "Earlier in the drawer")
    row.macro = Flat(row, "Macro", 50, function()
        local entry = row.entry
        if entry and entry.frame then
            MakeMacro("BD " .. DisplayName(entry.name), MacroIcon(IconOf(entry.frame), ICON_ADDON), "/click " .. entry.name)
        end
    end)
    row.macro:SetPoint("RIGHT", -90, 0)
    Tooltip(row.macro, "Make a macro",
        "Makes a macro that clicks this button, and puts it on your mouse. Click an action bar slot to put it there; " ..
        "pressing it then opens this addon's window like a click on its minimap button.")
    return row
end

function ns.RefreshManage()
    if not window or not window:IsShown() then return end
    local db = ns.Settings()
    local list = ns.Buttons()
    local maxOffset = math.max(0, #list - ROWS)
    if offset > maxOffset then offset = maxOffset end
    local inDrawer = 0
    for _, entry in ipairs(list) do
        if entry.on then inDrawer = inDrawer + 1 end
    end
    for index = 1, ROWS do
        local row = rows[index]
        local entry = list[index + offset]
        row.entry = entry
        if entry then
            row.on:Set(entry.on)
            row.icon:SetTexture(IconOf(entry.frame) or 134400)
            row.icon:SetDesaturated(not entry.on)
            row.name:SetText(DisplayName(entry.name))
            local color = entry.on and C.text or C.dim
            row.name:SetTextColor(color[1], color[2], color[3])
            row.note:SetText(entry.on and "" or "stays on the minimap")
            row.up:SetShown(entry.on)
            row.down:SetShown(entry.on)
            row.macro:SetUsable(entry.frame ~= nil)
            row:Show()
        else
            row:Hide()
        end
    end
    window.empty:SetShown(#list == 0)
    countText:SetText(string.format("%d in the drawer, %d on the minimap", inDrawer, #list - inDrawer))
    upPage:SetUsable(offset > 0)
    downPage:SetUsable(offset < maxOffset)
    upPage:SetShown(maxOffset > 0)
    downPage:SetShown(maxOffset > 0)
    -- the bar is always there; with nothing to scroll its handle is dim and does not move
    scrollBar.setting = true
    scrollBar:SetMinMaxValues(0, maxOffset)
    scrollBar:SetValue(offset)
    scrollBar.setting = false
    scrollBar:SetEnabled(maxOffset > 0)
    scrollBar.thumb:SetAlpha(maxOffset > 0 and 1 or 0.35)
    sizeText:SetText(tostring(db.size))
    columnsText:SetText(tostring(db.columns))
    hoverSwitch:Set(db.hover)
    keepSwitch:Set(db.keepOpen)
    keepSwitch:SetUsable(db.hover)
end

local function CreateWindow()
    local listBottom = LIST_TOP + ROWS * ROW_HEIGHT
    window = CreateFrame("Frame", "ButtonDrawerManage", UIParent)
    window:SetSize(WIDTH, listBottom + 232)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    tinsert(UISpecialFrames, "ButtonDrawerManage")
    Fill(window, C.panel)
    Outline(window, C.border)

    local title = Text(window, "Button Drawer", "GameFontNormalLarge", { 1, 1, 1 })
    title:SetPoint("TOP", 0, -10)
    local version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or ""
    local subtitle = Text(window, "v" .. version .. "  Forever", "GameFontHighlightSmall", C.dim)
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() window:Hide() end)

    local listTitle = Heading(window, "MINIMAP BUTTONS")
    listTitle:SetPoint("TOPLEFT", PAD, -48)
    for index = 1, ROWS do rows[index] = CreateRow(index) end
    window.empty = Text(window, "No addon minimap buttons found yet.", "GameFontHighlight", C.dim)
    window.empty:SetPoint("TOP", 0, -LIST_TOP - 40)

    -- the list scrolls with the bar beside it, two buttons, and the mouse wheel
    scrollBar = CreateFrame("Slider", nil, window)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetSize(BAR, ROWS * ROW_HEIGHT - 2)
    scrollBar:SetPoint("TOPRIGHT", -PAD, -LIST_TOP)
    Fill(scrollBar, C.input)
    Outline(scrollBar, C.edge)
    scrollBar.thumb = scrollBar:CreateTexture(nil, "ARTWORK")
    scrollBar.thumb:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    scrollBar.thumb:SetSize(BAR - 4, 44)
    scrollBar:SetThumbTexture(scrollBar.thumb)
    scrollBar:SetValueStep(1)
    scrollBar:SetObeyStepOnDrag(true)
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValue(0)
    scrollBar:SetScript("OnValueChanged", function(self, value)
        if self.setting then return end
        offset = math.floor(value + 0.5)
        ns.RefreshManage()
    end)
    Tooltip(scrollBar, "Scroll the list")
    countText = Text(window, "", "GameFontHighlightSmall", C.dim)
    countText:SetPoint("TOPLEFT", PAD, -listBottom - 6)
    downPage = Flat(window, "Scroll down", 84, function()
        offset = offset + 1
        ns.RefreshManage()
    end)
    downPage:SetPoint("TOPRIGHT", -PAD, -listBottom - 2)
    upPage = Flat(window, "Scroll up", 70, function()
        offset = math.max(0, offset - 1)
        ns.RefreshManage()
    end)
    upPage:SetPoint("RIGHT", downPage, "LEFT", -4, 0)
    window:EnableMouseWheel(true)
    window:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, offset - delta)
        ns.RefreshManage()
    end)

    local top = -listBottom - 34
    local lookTitle = Heading(window, "LOOK")
    lookTitle:SetPoint("TOPLEFT", PAD, top)

    local sizeLabel = Text(window, "Icon size", "GameFontHighlightSmall", C.text)
    sizeLabel:SetPoint("TOPLEFT", PAD, top - 26)
    sizeText = Stepper(window, sizeLabel, 26, function(step)
        local db = ns.Settings()
        db.size = math.max(ns.SIZE_MIN, math.min(ns.SIZE_MAX, db.size + step * 2))
        ns.Relayout()
    end)
    local columnsLabel = Text(window, "Columns", "GameFontHighlightSmall", C.text)
    columnsLabel:SetPoint("TOPLEFT", PAD + 180, top - 26)
    columnsText = Stepper(window, columnsLabel, 20, function(step)
        local db = ns.Settings()
        db.columns = math.max(1, math.min(12, db.columns + step))
        ns.Relayout()
    end)

    hoverSwitch = Switch(window, "Open on mouse-over", 150, function(on)
        ns.Settings().hover = on
        ns.RefreshManage()
    end)
    hoverSwitch:SetPoint("TOPLEFT", PAD, top - 52)
    Tooltip(hoverSwitch, "Open on mouse-over",
        "The drawer opens when the mouse comes onto its button, and closes shortly after the mouse has left.")
    keepSwitch = Switch(window, "Keep open", 96, function(on)
        ns.Settings().keepOpen = on
        ns.RefreshManage()
    end)
    keepSwitch:SetPoint("LEFT", hoverSwitch, "RIGHT", 6, 0)
    Tooltip(keepSwitch, "Keep open", "Opened by mouse-over, the drawer stays open until its button is clicked.")

    local macroTitle = Heading(window, "MACROS FOR YOUR ACTION BARS")
    macroTitle:SetPoint("TOPLEFT", PAD, top - 90)
    local macroHelp = Text(window, "Each addon above has a Macro button. These two open Button Drawer's own windows:",
        "GameFontHighlightSmall", C.dim)
    macroHelp:SetPoint("TOPLEFT", PAD, top - 112)
    macroHelp:SetWidth(WIDTH - 2 * PAD)
    macroHelp:SetJustifyH("LEFT")
    local errorsMacro = Flat(window, "Lua errors macro", 130, function()
        MakeMacro("BD Lua errors", ICON_ERRORS, "/bd errors")
    end)
    errorsMacro:SetPoint("TOPLEFT", PAD, top - 130)
    Tooltip(errorsMacro, "Lua errors macro", "Makes a macro that opens the Lua error window, and puts it on your mouse.")
    local setMacro = Flat(window, "Settings macro", 120, function()
        MakeMacro("BD Settings", ICON_SETTINGS, "/bd config")
    end)
    setMacro:SetPoint("LEFT", errorsMacro, "RIGHT", 6, 0)
    Tooltip(setMacro, "Settings macro", "Makes a macro that opens this window, and puts it on your mouse.")
    macroNote = Text(window, "", "GameFontHighlightSmall", C.text)
    macroNote:SetPoint("TOPLEFT", PAD, top - 158)
    macroNote:SetWidth(WIDTH - 2 * PAD)
    macroNote:SetJustifyH("LEFT")

    window:SetScript("OnShow", ns.RefreshManage)
    window:Hide()       -- a new frame starts out shown; the toggle below opens it
end

function ns.ToggleManage()
    if not window then CreateWindow() end
    if window:IsShown() then
        window:Hide()
    else
        window:Show()
        ns.RefreshManage()
    end
end
