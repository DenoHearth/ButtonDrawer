-- Button Drawer - one minimap button that holds every addon's minimap button.
--
-- Addon minimap buttons are taken off the minimap and parked in a drawer. Clicking the
-- drawer button folds them out in a grid; clicking it again folds them back in.
-- The first cell of the drawer is the Lua error button (Errors.lua).
--
--   left-click   open or close the drawer          drag   move around the minimap
--   right-click  Lua error window
--   the "Set" cell in the drawer, or /bd config: the manage window (Manage.lua)
--   /bd  |  /bd config  |  /bd columns N  |  /bd ignore NAME  |  /bd list  |  /bd reset

local ADDON, ns = ...

local BASE_CELL, PAD = 34, 6
local defaults = { angle = 215, columns = 6, ignore = {}, order = {}, size = 32, hover = false, keepOpen = false }
local db
ns.SIZE_MIN, ns.SIZE_MAX = 20, 48

local main, drawer, errorButton, settingsButton
local adopted = {}             -- frame -> its original parent, points and drag scripts
local laying = false           -- true while this addon itself moves a button
local layoutQueued = false

-- ------------------------------------------------------------------ which frames are addon buttons

-- Blizzard's own things around the minimap. Never collected.
local BLIZZARD = {
    "^Minimap", "^MiniMap", "^GameTime", "^QueueStatus", "^ExpansionLanding", "^AddonCompartment",
    "^TimeManager", "^Garrison", "^ButtonDrawer",
}

-- Things addons put on the minimap that are not launcher buttons: map pins and arrows.
local PINS = { "Pin", "Questie", "GatherMate", "HandyNotes", "TomTom", "Node", "POI", "Blip", "Waypoint" }

-- Blizzard builds its minimap pieces as fields of their parent (Minimap.ZoomIn, ...).
local function isParentField(frame, parent)
    for _, value in pairs(parent) do
        if value == frame then return true end
    end
    return false
end

-- A button sitting on the minimap's rim rather than on the map itself.
local function isOnRim(frame)
    local x, y = frame:GetCenter()
    local mx, my = Minimap:GetCenter()
    if not (x and y and mx and my) then return false end
    local scale = frame:GetEffectiveScale() / Minimap:GetEffectiveScale()
    local dx, dy = x * scale - mx, y * scale - my
    return math.sqrt(dx * dx + dy * dy) >= Minimap:GetWidth() / 2 * 0.75
end

local function isAddonButton(frame, parent)
    local ok, forbidden = pcall(frame.IsForbidden, frame)
    if not ok or forbidden then return false end
    local name = frame:GetName()
    if type(name) ~= "string" then name = nil end
    if adopted[frame] or (name and db.ignore[name]) then return false end
    local kind = frame:GetObjectType()
    if kind ~= "Button" and kind ~= "Frame" then return false end
    -- Reparenting a protected frame is blocked in combat; such a button is left where it is.
    if frame:IsProtected() then return false end
    if name then
        if name:find("^LibDBIcon10_") then return true end
        for _, pattern in ipairs(BLIZZARD) do
            if name:find(pattern) then return false end
        end
        if name:find("MinimapButton") or name:find("MiniMapButton") or name:find("MinimapIcon")
            or name:find("Minimap$") then
            return true
        end
        for _, pattern in ipairs(PINS) do
            if name:find(pattern) then return false end
        end
    end
    -- Everything else: any small clickable button an addon hung on the minimap, whatever it
    -- is called. Blizzard's own pieces and map pins are kept out.
    if kind ~= "Button" or isParentField(frame, parent) then return false end
    if not (frame:GetScript("OnClick") or frame:GetScript("OnMouseUp") or frame:GetScript("OnMouseDown")) then
        return false
    end
    local width, height = frame:GetSize()
    if width < 12 or height < 12 or width > 48 or height > 48 then return false end
    -- A button without a name cannot be told from a map pin by name, so it has to sit on the rim.
    return name ~= nil or isOnRim(frame)
end

-- ------------------------------------------------------------------ layout

-- The place of a button in the drawer: the order set in the manage window, then by name.
local function orderOf(name)
    for index, listed in ipairs(db.order) do
        if listed == name then return index end
    end
    return 1000
end

local function byOrder(a, b)
    local an, bn = a:GetName() or "", b:GetName() or ""
    local ao, bo = orderOf(an), orderOf(bn)
    if ao ~= bo then return ao < bo end
    return an < bn
end

local function shownButtons()
    local list = {}
    for frame in pairs(adopted) do
        if frame:IsShown() then list[#list + 1] = frame end
    end
    table.sort(list, byOrder)
    return list
end

-- The drawer folds out away from the nearest screen edges: left of a minimap on the right
-- side of the screen, down from one at the top, and the other way round.
local function placeDrawer()
    local x, y = main:GetCenter()
    if not x then return end
    local scale = main:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local right = x * scale > UIParent:GetWidth() / 2
    local top = y * scale > UIParent:GetHeight() / 2
    drawer:ClearAllPoints()
    drawer:SetPoint((top and "TOP" or "BOTTOM") .. (right and "RIGHT" or "LEFT"), main,
                    (top and "BOTTOM" or "TOP") .. (right and "LEFT" or "RIGHT"), 0, 0)
end

local function layout()
    layoutQueued = false
    if not drawer then return end
    laying = true
    local factor = db.size / 32
    local cell = math.floor(BASE_CELL * factor + 0.5)
    local buttons = shownButtons()
    local cells = { errorButton }
    for _, frame in ipairs(buttons) do cells[#cells + 1] = frame end
    cells[#cells + 1] = settingsButton
    local columns = math.max(1, math.min(db.columns, #cells))
    local rows = math.ceil(#cells / columns)
    drawer:SetSize(columns * cell + PAD * 2, rows * cell + PAD * 2)
    for i, frame in ipairs(cells) do
        local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
        if frame:GetParent() ~= drawer then frame:SetParent(drawer) end
        -- a collected button keeps its own size and is scaled; the offsets are in its own scale
        local saved = adopted[frame]
        local own = saved and saved.scale * factor or factor
        frame:SetScale(own)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", drawer, "TOPLEFT",
                       (PAD + col * cell + cell / 2) / own, -(PAD + row * cell + cell / 2) / own)
    end
    laying = false
    if main then
        main.count:SetText(#buttons > 0 and tostring(#buttons) or "")
        placeDrawer()
    end
    if ns.RefreshManage then ns.RefreshManage() end
end

local function queueLayout()
    if layoutQueued then return end
    layoutQueued = true
    C_Timer.After(0, layout)
end

-- ------------------------------------------------------------------ taking buttons in, giving them back

local function adopt(frame)
    local points = {}
    for i = 1, frame:GetNumPoints() do points[i] = { frame:GetPoint(i) } end
    adopted[frame] = { parent = frame:GetParent(), points = points, scale = frame:GetScale(),
                       dragStart = frame:GetScript("OnDragStart"),
                       dragStop = frame:GetScript("OnDragStop") }
    -- inside the drawer a button has a fixed cell; dragging it around the minimap makes no sense
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)
    -- The owning addon keeps re-anchoring its button (on login, on profile change). Each
    -- time it does, put the button back in its cell.
    hooksecurefunc(frame, "SetPoint", function() if not laying and adopted[frame] then queueLayout() end end)
    hooksecurefunc(frame, "SetParent", function() if not laying and adopted[frame] then queueLayout() end end)
    frame:HookScript("OnShow", queueLayout)
    frame:HookScript("OnHide", queueLayout)
end

local function release(frame)
    local saved = adopted[frame]
    if not saved then return end
    adopted[frame] = nil
    laying = true
    frame:SetParent(saved.parent)
    frame:SetScale(saved.scale)
    frame:ClearAllPoints()
    for _, p in ipairs(saved.points) do frame:SetPoint(unpack(p)) end
    frame:SetScript("OnDragStart", saved.dragStart)
    frame:SetScript("OnDragStop", saved.dragStop)
    laying = false
end

local function scan()
    if not drawer then return end
    local found = 0
    for _, parent in ipairs({ Minimap, MinimapBackdrop, MinimapCluster }) do
        if parent then
            for _, child in ipairs({ parent:GetChildren() }) do
                if child ~= main and isAddonButton(child, parent) then
                    adopt(child)
                    found = found + 1
                end
            end
        end
    end
    if found > 0 then queueLayout() end
end

-- Opening the drawer looks for buttons first, so one created late is never left outside.
local function toggleDrawer()
    if not drawer:IsShown() then
        scan()
        placeDrawer()
    end
    drawer:SetShown(not drawer:IsShown())
end

-- ------------------------------------------------------------------ for the manage window

-- Every button this addon knows: the ones in the drawer and the ones told to stay on the
-- minimap. name, frame (nil when not found this session), on (in the drawer).
function ns.Buttons()
    local list, seen = {}, {}
    local frames = {}
    for frame in pairs(adopted) do frames[#frames + 1] = frame end
    table.sort(frames, byOrder)
    for _, frame in ipairs(frames) do
        local name = frame:GetName()
        if type(name) == "string" then
            list[#list + 1] = { name = name, frame = frame, on = true }
            seen[name] = true
        end
    end
    local off = {}
    for name in pairs(db.ignore) do
        if not seen[name] then off[#off + 1] = name end
    end
    table.sort(off)
    for _, name in ipairs(off) do list[#list + 1] = { name = name, frame = _G[name], on = false } end
    return list
end

-- on: into the drawer. off: back onto the minimap, and left there from now on.
function ns.SetInDrawer(name, on)
    if on then
        db.ignore[name] = nil
        scan()
    else
        db.ignore[name] = true
        for frame in pairs(adopted) do
            if frame:GetName() == name then release(frame) end
        end
    end
    layout()
end

-- Move a button one place earlier (-1) or later (1) in the drawer.
function ns.MoveButton(name, step)
    local names = {}
    for _, frame in ipairs(shownButtons()) do names[#names + 1] = frame:GetName() or "" end
    for index, listed in ipairs(names) do
        local other = index + step
        if listed == name and names[other] then
            names[index], names[other] = names[other], names[index]
            break
        end
    end
    db.order = names
    layout()
end

function ns.Settings() return db end
function ns.Relayout() layout() end

-- ------------------------------------------------------------------ the pieces

local function square(parent, size, r, g, b)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(size, size)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(r, g, b, 1)
    f.edge = f:CreateTexture(nil, "BORDER")
    f.edge:SetPoint("TOPLEFT", 1, -1)
    f.edge:SetPoint("BOTTOMRIGHT", -1, 1)
    f.edge:SetColorTexture(0.08, 0.08, 0.1, 1)
    f.hover = f:CreateTexture(nil, "HIGHLIGHT")
    f.hover:SetAllPoints()
    f.hover:SetColorTexture(1, 1, 1, 0.15)
    return f
end

local function tooltip(frame, title, ...)
    local lines = { ... }
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(type(title) == "function" and title() or title)
        for _, line in ipairs(lines) do GameTooltip:AddLine(line, 1, 1, 1) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function placeMain()
    local radius = Minimap:GetWidth() / 2 + 8
    local a = math.rad(db.angle)
    main:ClearAllPoints()
    main:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * radius, math.sin(a) * radius)
end

local function refreshErrors()
    local n = ns.ErrorCount()
    if errorButton then
        errorButton.bg:SetColorTexture(n > 0 and 0.85 or 0.35, n > 0 and 0.15 or 0.35, n > 0 and 0.15 or 0.38, 1)
        errorButton.label:SetText(n > 0 and tostring(n) or "!")
    end
    if main then
        main.badge:SetText(n > 0 and tostring(n) or "")
        -- the drawer button itself turns red while there are errors
        main.bg:SetColorTexture(n > 0 and 0.9 or 0.75, n > 0 and 0.2 or 0.6, 0.2, 1)
    end
end

local function build()
    -- the one button on the minimap: a dark tile with three bars, like a drawer handle
    main = square(Minimap, 26, 0.75, 0.6, 0.2)
    main:SetFrameStrata("MEDIUM")
    main:SetFrameLevel(8)
    for i = 1, 3 do
        local bar = main:CreateTexture(nil, "ARTWORK")
        bar:SetSize(14, 2)
        bar:SetPoint("CENTER", 0, 8 - i * 4)
        bar:SetColorTexture(0.9, 0.8, 0.5, 1)
    end
    main.count = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    main.count:SetPoint("BOTTOMRIGHT", 2, -3)
    main.badge = main:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    main.badge:SetPoint("TOPRIGHT", 4, 4)
    main.badge:SetTextColor(1, 0.2, 0.2)
    main:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    main:RegisterForDrag("LeftButton")
    main:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then ns.ToggleErrorWindow() else toggleDrawer() end
    end)
    main:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            db.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
            placeMain()
        end)
    end)
    main:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    tooltip(main, "Button Drawer", "Left-click: open the drawer", "Right-click: Lua errors",
            "Drag: move around the minimap", "Settings: the Set button in the drawer")
    -- optional: the drawer opens when the mouse comes onto the button
    main:HookScript("OnEnter", function()
        if db.hover and not drawer:IsShown() then toggleDrawer() end
    end)
    placeMain()

    drawer = CreateFrame("Frame", "ButtonDrawerFrame", UIParent)
    drawer:SetFrameStrata("DIALOG")
    drawer:SetClampedToScreen(true)
    drawer:SetPoint("TOPRIGHT", main, "BOTTOMLEFT", 0, 0)
    -- opened by mouse-over, it closes again shortly after the mouse has left it
    drawer.away = 0
    drawer:SetScript("OnUpdate", function(self, elapsed)
        if not db.hover or db.keepOpen then return end
        if self:IsMouseOver(8, -8, -8, 8) or main:IsMouseOver(8, -8, -8, 8) then
            self.away = 0
        else
            self.away = self.away + elapsed
            if self.away > 0.6 then
                self.away = 0
                self:Hide()
            end
        end
    end)
    drawer.bg = drawer:CreateTexture(nil, "BACKGROUND")
    drawer.bg:SetAllPoints()
    drawer.bg:SetColorTexture(0.05, 0.05, 0.06, 0.9)
    -- a thin outline, so the drawer also reads on a dark background
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                            { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local edge = drawer:CreateTexture(nil, "BORDER")
        edge:SetColorTexture(0.38, 0.38, 0.40, 1)
        edge:SetPoint(side[1])
        edge:SetPoint(side[2])
        if side[3] then edge:SetHeight(1) else edge:SetWidth(1) end
    end
    -- A plain toggle: the drawer stays open until its button is clicked again.
    drawer:Hide()

    errorButton = square(drawer, 28, 0.35, 0.35, 0.38)
    errorButton.label = errorButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    errorButton.label:SetPoint("CENTER")
    errorButton:SetScript("OnClick", ns.ToggleErrorWindow)
    tooltip(errorButton, function() return "Lua errors: " .. ns.ErrorCount() end,
            "Click: show them, copy them, clear them")
    settingsButton = square(drawer, 28, 0.35, 0.35, 0.38)
    settingsButton.label = settingsButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    settingsButton.label:SetPoint("CENTER")
    settingsButton.label:SetText("Set")
    settingsButton:SetScript("OnClick", function() ns.ToggleManage() end)
    tooltip(settingsButton, "Settings", "Which buttons are in the drawer, their order, size and columns")
    ns.OnErrorsChanged(refreshErrors)
    refreshErrors()
    layout()
end

-- ------------------------------------------------------------------ wiring

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            ButtonDrawerDB = ButtonDrawerDB or {}
            db = ButtonDrawerDB
            for key, value in pairs(defaults) do
                if db[key] == nil then db[key] = type(value) == "table" and {} or value end
            end
        elseif drawer then
            C_Timer.After(1, scan)          -- an addon that loads later brings its button later
        end
    elseif event == "PLAYER_LOGIN" then
        build()
        -- addons create their buttons at different moments during login
        for _, delay in ipairs({ 1, 4, 10 }) do C_Timer.After(delay, scan) end
    end
end)

SLASH_BUTTONDRAWER1 = "/bd"
SLASH_BUTTONDRAWER2 = "/buttondrawer"
SlashCmdList.BUTTONDRAWER = function(msg)
    if not drawer then return end
    local cmd, arg = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "columns" and tonumber(arg) then
        db.columns = math.max(1, math.min(12, math.floor(tonumber(arg))))
        layout()
    elseif cmd == "ignore" and arg ~= "" then
        db.ignore[arg] = true
        for f in pairs(adopted) do if f:GetName() == arg then release(f) end end
        layout()
        print("|cffffcc66Button Drawer|r: " .. arg .. " stays on the minimap.")
    elseif cmd == "list" then
        for _, f in ipairs(shownButtons()) do print("|cffffcc66Button Drawer|r: " .. (f:GetName() or "(unnamed button)")) end
    elseif cmd == "reset" then
        db.angle, db.columns, db.size = defaults.angle, defaults.columns, defaults.size
        wipe(db.ignore)
        wipe(db.order)
        placeMain()
        scan()
        layout()
    elseif cmd == "errors" then
        ns.ToggleErrorWindow()
    elseif cmd == "config" or cmd == "settings" or cmd == "options" then
        ns.ToggleManage()
    else
        toggleDrawer()
    end
end
