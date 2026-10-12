-- Button Drawer - Lua error catcher and its window.
--
-- Loaded first, so errors raised by addons that load after this one are caught too.
-- Nothing here depends on another addon or library.

local ADDON, ns = ...

ns.errors = {}                 -- this session, oldest first
local MAX_KEPT, MAX_SAVED = 100, 50
local listeners = {}

function ns.OnErrorsChanged(fn) listeners[#listeners + 1] = fn end

local function changed()
    for _, fn in ipairs(listeners) do pcall(fn) end
end

-- An error object can be anything, and on this client it can be a secret value.
local function plain(v)
    if issecretvalue and issecretvalue(v) then return "<secret value>" end
    return tostring(v)
end

local recording = false

function ns.RecordError(msg, stack, kind)
    if recording then return end           -- an error while recording must not loop
    recording = true
    msg = plain(msg)
    local known
    for _, e in ipairs(ns.errors) do
        if e.msg == msg then known = e break end
    end
    if known then
        known.count = known.count + 1
        known.last = date("%H:%M:%S")
    else
        ns.errors[#ns.errors + 1] = { msg = msg, stack = stack or "", kind = kind or "error",
                                      count = 1, first = date("%Y-%m-%d %H:%M:%S"),
                                      last = date("%H:%M:%S") }
        if #ns.errors > MAX_KEPT then table.remove(ns.errors, 1) end
    end
    recording = false
    changed()
end

function ns.ErrorCount()
    local n = 0
    for _, e in ipairs(ns.errors) do n = n + e.count end
    return n
end

function ns.ClearErrors()
    wipe(ns.errors)
    changed()
end

-- The client calls this for every Lua error. It replaces the default popup: the drawer's
-- error button is the display.
seterrorhandler(function(msg)
    local ok, stack = pcall(debugstack, 3)
    ns.RecordError(msg, ok and plain(stack) or "", "error")
end)

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_LOGOUT")
watcher:RegisterEvent("ADDON_ACTION_BLOCKED")
watcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")
watcher:RegisterEvent("LUA_WARNING")
watcher:SetScript("OnEvent", function(_, event, a, b)
    if event == "ADDON_LOADED" then
        if a == ADDON then ButtonDrawerDB = ButtonDrawerDB or {} end
    elseif event == "PLAYER_LOGOUT" then
        -- kept on disk so the errors of a session can be read after the game is closed
        local saved = {}
        for i = math.max(1, #ns.errors - MAX_SAVED + 1), #ns.errors do
            saved[#saved + 1] = ns.errors[i]
        end
        if ButtonDrawerDB then ButtonDrawerDB.errors = saved end
    elseif event == "LUA_WARNING" then
        ns.RecordError(plain(a), "", "warning")
    else
        local what = event == "ADDON_ACTION_BLOCKED" and "blocked" or "forbidden"
        ns.RecordError(plain(a) .. " was " .. what .. " from calling " .. plain(b) ..
                       " (reserved for the Blizzard UI)", "", what)
    end
end)

-- ------------------------------------------------------------------ window

local window

-- One error at a time, newest first: page 1 is the newest. (Until 1.1.2 the window held all
-- of them in one long text; he asked for them apart, with buttons to go through them.)
local page = 1

local function shown()
    return ns.errors[#ns.errors - page + 1]
end

local function report()
    local e = shown()
    if not e then return "No Lua errors this session." end
    return string.format("[%s] x%d  (%s, last %s)\n%s\n%s", e.kind, e.count, e.first, e.last, e.msg, e.stack)
end

local function build()
    local f = CreateFrame("Frame", "ButtonDrawerErrorWindow", UIParent)
    f:SetSize(620, 400)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.06, 0.95)
    local bar = f:CreateTexture(nil, "BORDER")
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(26)
    bar:SetColorTexture(0.45, 0.1, 0.1, 1)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 10, -6)

    local scroll = CreateFrame("ScrollFrame", "ButtonDrawerErrorScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -34)
    scroll:SetPoint("BOTTOMRIGHT", -30, 40)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(570)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    scroll:SetScrollChild(edit)
    f.edit = edit

    local function button(label, x, onClick)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(110, 22)
        b:SetPoint("BOTTOMLEFT", x, 10)
        b:SetText(label)
        b:SetScript("OnClick", onClick)
        return b
    end
    -- The game keeps the clipboard for its own UI: an addon calling CopyToClipboard gets a
    -- "forbidden" report each time (seen on the live beta, 2026-10-12; pcall does not stop it).
    -- So the button marks the whole report and the copy itself is Ctrl+C.
    f.previous = button("Previous", 10, function() page = page - 1 f:Refresh() end)
    f.next = button("Next", 130, function() page = page + 1 f:Refresh() end)
    f.copy = button("Mark", 250, function()
        edit:SetFocus()
        edit:HighlightText()
        f.title:SetText("Marked - now press Ctrl+C.")
        C_Timer.After(4, function() if f:IsShown() then f:Refresh() end end)
    end)
    button("Clear", 370, function() ns.ClearErrors() end)
    button("Close", 490, function() f:Hide() end)

    function f:Refresh()
        local count = #ns.errors
        page = math.max(1, math.min(page, math.max(count, 1)))
        local e = shown()
        if e then
            self.title:SetText(string.format("Lua error %d of %d   -   this one happened %d time%s", page, count, e.count, e.count == 1 and "" or "s"))
        else
            self.title:SetText("Lua errors: none")
        end
        self.previous:SetEnabled(page > 1)
        self.next:SetEnabled(page < count)
        self.copy:SetEnabled(e ~= nil)
        self.edit:SetText(report())
        self.edit:SetCursorPosition(0)
        self.edit:ClearFocus()
    end
    -- a new error goes to the front: stay on the one being read
    local seen = #ns.errors
    ns.OnErrorsChanged(function()
        if #ns.errors > seen and f:IsShown() then page = page + (#ns.errors - seen) end
        if #ns.errors == 0 then page = 1 end
        seen = #ns.errors
        if f:IsShown() then f:Refresh() end
    end)
    f:Hide()
    return f
end

function ns.ToggleErrorWindow()
    window = window or build()
    if window:IsShown() then
        window:Hide()
    else
        page = 1                    -- opens on the newest
        window:Refresh()
        window:Show()
    end
end
