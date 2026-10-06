-- Button Drawer - one minimap button that holds every addon's minimap button.
--
-- Addon minimap buttons are taken off the minimap and parked in a drawer. Clicking the
-- drawer button folds them out in a grid; they fold back in when the mouse leaves.
-- The first cell of the drawer is the Lua error button (Errors.lua).
--
--   left-click   open or close the drawer          drag   move around the minimap
--   right-click  Lua error window
--   /bd  |  /bd columns N  |  /bd ignore NAME  |  /bd list  |  /bd reset

local ADDON, ns = ...

local CELL, PAD = 34, 6
local defaults = { angle = 215, columns = 6, ignore = {} }
local db

local main, drawer, errorButton
local adopted = {}             -- frame -> its original parent, points and drag scripts
local laying = false           -- true while this addon itself moves a button
local layoutQueued = false

-- ------------------------------------------------------------------ which frames are addon buttons

-- Blizzard's own things around the minimap. Never collected.
local BLIZZARD = {
    "^Minimap", "^MiniMap", "^GameTime", "^QueueStatus", "^ExpansionLanding", "^AddonCompartment",
    "^TimeManager", "^Garrison", "^ButtonDrawer",
}

local function isAddonButton(frame)
    local ok, forbidden = pcall(frame.IsForbidden, frame)
    if not ok or forbidden then return false end
    local name = frame:GetName()
    if type(name) ~= "string" or adopted[frame] or db.ignore[name] then return false end
    local kind = frame:GetObjectType()
    if kind ~= "Button" and kind ~= "Frame" then return false end
    -- Reparenting a protected frame is blocked in combat; such a button is left where it is.
    if frame:IsProtected() then return false end
    if name:find("^LibDBIcon10_") then return true end
    for _, pattern in ipairs(BLIZZARD) do
        if name:find(pattern) then return false end
    end
    return name:find("MinimapButton") or name:find("MiniMapButton") or name:find("MinimapIcon")
        or name:find("Minimap$") or false
end

-- ------------------------------------------------------------------ layout

local function shownButtons()
    local list = {}
    for frame in pairs(adopted) do
        if frame:IsShown() then list[#list + 1] = frame end
    end
    table.sort(list, function(a, b) return (a:GetName() or "") < (b:GetName() or "") end)
    return list
end

local function layout()
    layoutQueued = false
    if not drawer then return end
    laying = true
    local cells = { errorButton }
    for _, frame in ipairs(shownButtons()) do cells[#cells + 1] = frame end
    local columns = math.max(1, math.min(db.columns, #cells))
    local rows = math.ceil(#cells / columns)
    drawer:SetSize(columns * CELL + PAD * 2, rows * CELL + PAD * 2)
    for i, frame in ipairs(cells) do
        local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
        if frame:GetParent() ~= drawer then frame:SetParent(drawer) end
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", drawer, "TOPLEFT",
                       PAD + col * CELL + CELL / 2, -(PAD + row * CELL + CELL / 2))
    end
    laying = false
    if main then main.count:SetText(#cells - 1 > 0 and tostring(#cells - 1) or "") end
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
    adopted[frame] = { parent = frame:GetParent(), points = points,
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
                if child ~= main and isAddonButton(child) then
                    adopt(child)
                    found = found + 1
                end
            end
        end
    end
    if found > 0 then queueLayout() end
end

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
    if main then main.badge:SetText(n > 0 and tostring(n) or "") end
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
        if mouse == "RightButton" then ns.ToggleErrorWindow() else drawer:SetShown(not drawer:IsShown()) end
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
            "Drag: move around the minimap")
    placeMain()

    drawer = CreateFrame("Frame", "ButtonDrawerFrame", UIParent)
    drawer:SetFrameStrata("DIALOG")
    drawer:SetClampedToScreen(true)
    drawer:SetPoint("TOPRIGHT", main, "BOTTOMLEFT", 0, 0)
    drawer.bg = drawer:CreateTexture(nil, "BACKGROUND")
    drawer.bg:SetAllPoints()
    drawer.bg:SetColorTexture(0.05, 0.05, 0.06, 0.9)
    drawer:Hide()
    -- fold back in a moment after the mouse has left both the drawer and its button
    local away = 0
    drawer:SetScript("OnUpdate", function(self, elapsed)
        if self:IsMouseOver() or main:IsMouseOver() then
            away = 0
        else
            away = away + elapsed
            if away > 1.2 then away = 0 self:Hide() end
        end
    end)

    errorButton = square(drawer, 28, 0.35, 0.35, 0.38)
    errorButton.label = errorButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    errorButton.label:SetPoint("CENTER")
    errorButton:SetScript("OnClick", ns.ToggleErrorWindow)
    tooltip(errorButton, function() return "Lua errors: " .. ns.ErrorCount() end,
            "Click: show them, copy them, clear them")
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
        for _, f in ipairs(shownButtons()) do print("|cffffcc66Button Drawer|r: " .. f:GetName()) end
    elseif cmd == "reset" then
        db.angle, db.columns = defaults.angle, defaults.columns
        wipe(db.ignore)
        placeMain()
        scan()
        layout()
    elseif cmd == "errors" then
        ns.ToggleErrorWindow()
    else
        drawer:SetShown(not drawer:IsShown())
    end
end
