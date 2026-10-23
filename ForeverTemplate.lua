-- Forever Template: /ft save on the patient-zero character, then every new character applies it once on first login.
-- Account-wide things (keybinds, macros, addon profiles, Edit Mode layouts) are already shared by the game, so this
-- covers what is left per character: CVars, the active Edit Mode layout, enabled addons, chat windows and, for the
-- same class, action bars.

local ADDON = ...
local DB, CDB

-- Per-character CVars worth copying (from config-cache.wtf). Tracked quests, currencies and camera are left out.
local CVARS = {
    "cooldownViewerEnabled", "enableMultiActionBars", "minimapZoom", "showQuestLevel", "raidFramesDisplayClassColor",
    "nameplateSelectedScale", "nameplateMaxDistance", "nameplateTargetBehindMaxDistance", "nameplateMinScale",
    "nameplateMaxScale", "nameplateMinAlpha", "nameplateMaxAlpha", "nameplateMinAlphaDistance", "nameplateMaxAlphaDistance",
}

local DB_VERSION = 1

-- Addons this one never switches on or off: itself, Blizzard's own, and anything on the player's ignore list.
local function Protected(name)
    return name == ADDON or name:find("^Blizzard_") ~= nil or DB.ignore[name] == true
end

local function Print(...)
    print("|cff66ccffForeverTemplate:|r", ...)
end

local function PlayerClass()
    return (select(2, UnitClass("player")))
end

-- Classic-era and Retail builds differ in which of these exist.
local AddOns = C_AddOns or {
    GetNumAddOns = GetNumAddOns, GetAddOnInfo = GetAddOnInfo, GetAddOnEnableState = GetAddOnEnableState,
    EnableAddOn = EnableAddOn, DisableAddOn = DisableAddOn, IsAddOnLoaded = IsAddOnLoaded,
}
local GetSpellName = C_Spell and C_Spell.GetSpellName or GetSpellInfo
local function GetSpellID(name)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(name)
        return info and info.spellID
    end
    return select(7, GetSpellInfo(name))
end
local function PickupSpellByID(id)
    return (C_Spell and C_Spell.PickupSpell or PickupSpell)(id)
end

-- One failing section (chat, bars...) must not stop the others. Errors are kept for /ft errors.
local errors = {}
local function Try(label, fn, ...)
    local r = { pcall(fn, ...) }
    if not r[1] then
        errors[#errors + 1] = label .. ": " .. tostring(r[2])
        if #errors > 20 then
            table.remove(errors, 1)
        end
        return nil
    end
    return unpack(r, 2)
end

---------------------------------------------------------------- CVars
local function SaveCVars()
    local out = {}
    for _, name in ipairs(CVARS) do
        local value = (C_CVar and C_CVar.GetCVar or GetCVar)(name)
        if value ~= nil then
            out[name] = value
        end
    end
    return out
end

local function ApplyCVars(cvars)
    for name, value in pairs(cvars or {}) do
        pcall(C_CVar and C_CVar.SetCVar or SetCVar, name, value)
    end
end

---------------------------------------------------------------- Edit Mode
local function EditModeReady()
    return C_EditMode ~= nil and EditModeManagerFrame ~= nil and EditModeManagerFrame.accountSettings ~= nil and EditModePresetLayoutManager ~= nil
end

-- The name of the active layout; nil for one of Blizzard's presets.
local function ActiveLayoutName()
    local info = C_EditMode.GetLayouts()
    local layout = info.layouts[info.activeLayout - #EditModePresetLayoutManager:GetCopyOfPresetLayouts()]
    return layout and layout.layoutName
end

local function ApplyEditMode(name)
    if not name then
        return true
    end
    if not EditModeReady() then
        return false
    end
    local merged = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
    for _, layout in ipairs(C_EditMode.GetLayouts().layouts) do
        merged[#merged + 1] = layout
    end
    for i, layout in ipairs(merged) do
        if layout.layoutName == name then
            C_EditMode.SetActiveLayout(i)
            return true
        end
    end
    Print("Edit Mode layout '" .. name .. "' not found on this account. Create or import it, then type /ft apply.")
    return true
end

---------------------------------------------------------------- Addons
local function AddonEnabled(name)
    local ok, state = pcall(AddOns.GetAddOnEnableState, name, UnitGUID("player"))
    return ok and type(state) == "number" and state > 0
end

local function SaveAddons()
    local out = {}
    for i = 1, AddOns.GetNumAddOns() do
        local name = AddOns.GetAddOnInfo(i)
        if name and not Protected(name) then
            out[name] = AddonEnabled(name)
        end
    end
    return out
end

-- Returns whether anything changed (a reload is needed).
local function ApplyAddons(addons)
    local changed = false
    for name, wanted in pairs(addons or {}) do
        if AddOns.GetAddOnInfo(name) and AddonEnabled(name) ~= wanted then
            local call = wanted and AddOns.EnableAddOn or AddOns.DisableAddOn
            if pcall(call, name, UnitGUID("player")) then
                changed = true
            end
        end
    end
    return changed
end

---------------------------------------------------------------- Chat
local function SaveChat()
    local out = {}
    for i = 1, NUM_CHAT_WINDOWS do
        local name, size, r, g, b, a, shown, locked, docked = GetChatWindowInfo(i)
        if name and name ~= "" and (shown or docked) then
            out[i] = {
                name = name, size = size, r = r, g = g, b = b, a = a, locked = locked, docked = docked,
                groups = { GetChatWindowMessages(i) }, channels = { GetChatWindowChannels(i) },
            }
        end
    end
    return out
end

local function ApplyChat(chat)
    for i = 1, NUM_CHAT_WINDOWS do
        local saved = chat and chat[i]
        local frame = _G["ChatFrame" .. i]
        if saved and frame and i ~= 2 then -- 2 is the combat log
            if not frame:IsShown() and not frame.isDocked and i > 2 then
                pcall(FCF_OpenNewWindow, saved.name)
                frame = _G["ChatFrame" .. i]
            end
            pcall(FCF_SetWindowName, frame, saved.name)
            pcall(FCF_SetChatWindowFontSize, nil, frame, saved.size)
            pcall(FCF_SetWindowColor, frame, saved.r, saved.g, saved.b)
            pcall(FCF_SetWindowAlpha, frame, saved.a)
            ChatFrame_RemoveAllMessageGroups(frame)
            for _, group in ipairs(saved.groups) do
                ChatFrame_AddMessageGroup(frame, group)
            end
            ChatFrame_RemoveAllChannels(frame)
            for j = 1, #saved.channels, 2 do
                pcall(ChatFrame_AddChannel, frame, saved.channels[j])
            end
        end
    end
end

---------------------------------------------------------------- Action bars (same class only)
local function SaveBars()
    local out = {}
    for slot = 1, 120 do
        local kind, id = GetActionInfo(slot)
        if kind == "spell" then
            local name = GetSpellName(id)
            if name then
                out[slot] = { kind = "spell", name = name }
            end
        elseif kind == "macro" then
            local name = GetMacroInfo(id)
            if name then
                out[slot] = { kind = "macro", name = name }
            end
        elseif kind == "item" then
            out[slot] = { kind = "item", id = id }
        end
    end
    return out
end

-- Fills empty slots only, and each slot once per saved entry, so anything cleared on purpose stays cleared.
-- Called again as spells are learned, so new abilities land on the bar while leveling. Returns how many slots it
-- filled and how many saved entries are still waiting (spell not learned yet, macro or item missing).
local function ApplyBars()
    local bars = DB.bars and DB.bars[PlayerClass()]
    if not bars or InCombatLockdown() then
        return 0, 0
    end
    CDB.placed = CDB.placed or {}
    local placed, waiting = 0, 0
    for slot, entry in pairs(bars) do
        local key = slot .. ":" .. (entry.name or entry.id)
        if not CDB.placed[key] and not GetActionInfo(slot) then
            if entry.kind == "spell" then
                local id = GetSpellID(entry.name)
                if id and ((IsPlayerSpell and IsPlayerSpell(id)) or IsSpellKnown(id)) then
                    PickupSpellByID(id)
                end
            elseif entry.kind == "macro" then
                local index = GetMacroIndexByName(entry.name)
                if index and index > 0 then
                    PickupMacro(index)
                end
            elseif entry.kind == "item" then
                C_Item.PickupItem(entry.id)
            end
            if GetCursorInfo() then
                PlaceAction(slot)
                ClearCursor()
                CDB.placed[key] = true
                placed = placed + 1
            else
                waiting = waiting + 1
            end
        end
    end
    return placed, waiting
end

-- ReloadUI is protected: an addon can only call it from a click, never from a timer.
StaticPopupDialogs["FOREVERTEMPLATE_RELOAD"] = {
    text = "Forever Template changed your addon list. Reload the UI to finish?",
    button1 = RELOADUI,
    button2 = CANCEL,
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

---------------------------------------------------------------- Branded UI pieces
-- Gameforce look: near-black fill, 1 px white border, white text; buttons invert on hover.
local BUG_URL = "https://github.com/gameforce/ForeverTemplate/issues" -- keep identical to the Report a bug link in site/html/index.html
local WHITE8x8 = "Interface\\Buttons\\WHITE8x8"

local function StyleFrame(f)
    f:SetBackdrop({ bgFile = WHITE8x8, edgeFile = WHITE8x8, edgeSize = 1 })
    f:SetBackdropColor(0.04, 0.04, 0.04, 0.97)
    f:SetBackdropBorderColor(1, 1, 1, 1)
end

local function MakeButton(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or 110, 24)
    StyleFrame(b)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.label:SetPoint("CENTER")
    b.label:SetText(text)
    b.label:SetTextColor(1, 1, 1)
    b:SetScript("OnEnter", function(self)
        self:SetBackdropColor(1, 1, 1, 1)
        self.label:SetTextColor(0, 0, 0)
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.04, 0.04, 0.04, 0.97)
        self.label:SetTextColor(1, 1, 1)
    end)
    b:SetScript("OnClick", onClick)
    return b
end

---------------------------------------------------------------- Bug report window
local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

local function Diagnostics()
    local clientVersion, build, _, interface = GetBuildInfo()
    local t = DB.template
    local ignored = {}
    for name in pairs(DB.ignore) do
        ignored[#ignored + 1] = name
    end
    table.sort(ignored)
    local lines = {
        "ForeverTemplate " .. (GetMeta and GetMeta(ADDON, "Version") or "?"),
        ("Client %s build %s interface %s project %s"):format(clientVersion, build, interface, tostring(WOW_PROJECT_ID)),
        "Class " .. PlayerClass(),
        t and ("Template from %s (%s) saved %s"):format(t.from, t.class, t.date) or "No template saved",
        "This character: " .. (CDB.applied and ("applied " .. CDB.applied) or "not applied"),
        "Auto-apply " .. (DB.auto and "on" or "off"),
        "Ignored addons: " .. (#ignored > 0 and table.concat(ignored, ", ") or "none"),
        "Errors this session: " .. (#errors > 0 and "" or "none"),
    }
    for _, line in ipairs(errors) do
        lines[#lines + 1] = "  " .. line
    end
    return table.concat(lines, "\n")
end

local bugFrame
local function ShowBugReport()
    local text = Diagnostics()
    if not bugFrame then
        local f = CreateFrame("Frame", "ForeverTemplateBugFrame", UIParent, "BackdropTemplate")
        f:SetSize(480, 340)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        StyleFrame(f)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        tinsert(UISpecialFrames, "ForeverTemplateBugFrame")

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetTextColor(1, 1, 1)
        title:SetText("FOREVER TEMPLATE  |  REPORT A BUG")

        local help = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        help:SetWidth(450)
        help:SetJustifyH("LEFT")
        help:SetText("Press Ctrl+A then Ctrl+C to copy this, and paste it into a report at:\n" .. BUG_URL)

        local scroll = CreateFrame("ScrollFrame", "ForeverTemplateBugScroll", f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 14, -72)
        scroll:SetPoint("BOTTOMRIGHT", -34, 46)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(430)
        edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function() f:Hide() end)
        edit:SetScript("OnTextChanged", function(self)
            if self.text and self:GetText() ~= self.text then
                self:SetText(self.text) -- selectable and copyable, not editable
            end
        end)
        scroll:SetScrollChild(edit)
        f.edit = edit

        MakeButton(f, "Close", 90, function() f:Hide() end):SetPoint("BOTTOMRIGHT", -14, 12)
        bugFrame = f
    end
    bugFrame.edit.text = text
    bugFrame.edit:SetText(text)
    bugFrame:Show()
    bugFrame.edit:SetFocus()
    bugFrame.edit:HighlightText()
end

---------------------------------------------------------------- Save / apply
local function Save()
    DB.template = {
        from = UnitName("player"), class = PlayerClass(), date = date("%Y-%m-%d %H:%M"),
        cvars = Try("save cvars", SaveCVars), editMode = EditModeReady() and Try("save edit mode", ActiveLayoutName) or nil,
        addons = Try("save addons", SaveAddons), chat = Try("save chat", SaveChat),
    }
    DB.bars = DB.bars or {}
    DB.bars[PlayerClass()] = Try("save bars", SaveBars) or DB.bars[PlayerClass()]
    CDB.applied = DB.template.date
    Print("Saved template from " .. DB.template.from .. " (action bars for " .. PlayerClass() .. ").")
end

local function Apply(tries)
    local t = DB.template
    if not t then
        return Print("No template saved. Log in on your patient-zero character and type /ft save.")
    end
    if InCombatLockdown() then
        return Print("In combat; type /ft apply when it ends.")
    end
    if t.editMode and not EditModeReady() and (tries or 0) < 5 then
        return C_Timer.After(2, function() Apply((tries or 0) + 1) end)
    end
    local failed = #errors
    Try("cvars", ApplyCVars, t.cvars)
    Try("edit mode", ApplyEditMode, t.editMode)
    Try("chat", ApplyChat, t.chat)
    local placed, waiting = Try("bars", ApplyBars)
    local reload = Try("addons", ApplyAddons, t.addons)
    CDB.applied = t.date
    Print("Applied template from " .. t.from .. ".")
    if placed and (placed > 0 or waiting > 0) then
        Print(("Action bars: %d placed%s."):format(placed, waiting > 0 and (", " .. waiting .. " waiting for spells or items") or ""))
    end
    if #errors > failed then
        Print(#errors - failed .. " part(s) failed; type /ft errors for details.")
    end
    if AddOns.IsAddOnLoaded("LuxthosUI") then
        Print("Luxthos UI: run /lux once for this class's Cooldown Manager layout.")
    end
    if reload then
        Print("Addon list changed; click Reload in the popup (or type /reload).")
        StaticPopup_Show("FOREVERTEMPLATE_RELOAD")
    end
end

local function Status()
    local t = DB.template
    if not t then
        return Print("No template saved.")
    end
    Print(("Template from %s (%s) saved %s. Edit Mode layout: %s."):format(t.from, t.class, t.date, t.editMode or "preset"))
    local classes = {}
    for class in pairs(DB.bars or {}) do
        classes[#classes + 1] = class
    end
    Print("Action bars saved for: " .. (#classes > 0 and table.concat(classes, ", ") or "none"))
    Print("This character: " .. (CDB.applied and ("applied " .. CDB.applied) or "not applied") .. "; auto-apply " .. (DB.auto and "on" or "off"))
end

SLASH_FOREVERTEMPLATE1, SLASH_FOREVERTEMPLATE2 = "/ft", "/forevertemplate"
SlashCmdList.FOREVERTEMPLATE = function(msg)
    local cmd, arg = msg:lower():match("^(%S*)%s*(%S*)")
    if cmd == "save" then
        Save()
    elseif cmd == "apply" then
        Apply()
    elseif cmd == "bars" then
        DB.bars = DB.bars or {}
        DB.bars[PlayerClass()] = Try("save bars", SaveBars) or DB.bars[PlayerClass()]
        Print("Saved action bars for " .. PlayerClass() .. ".")
    elseif cmd == "auto" and (arg == "on" or arg == "off") then
        DB.auto = arg == "on"
        Print("Auto-apply on first login: " .. arg)
    elseif cmd == "bug" then
        ShowBugReport()
    elseif cmd == "errors" then
        if #errors == 0 then
            Print("No errors this session.")
        end
        for _, line in ipairs(errors) do
            Print(line)
        end
    elseif cmd == "ignore" then
        local name = msg:match("^%S+%s+(.-)%s*$")
        if not name or name == "" then
            local list = {}
            for addon in pairs(DB.ignore) do
                list[#list + 1] = addon
            end
            table.sort(list)
            Print("Addons never switched on or off: " .. (#list > 0 and table.concat(list, ", ") or "none") .. ". /ft ignore <AddonFolder> toggles one.")
        else
            DB.ignore[name] = not DB.ignore[name] or nil
            Print(name .. (DB.ignore[name] and " is now ignored." or " is no longer ignored.") .. " Takes effect at the next /ft save and /ft apply.")
        end
    elseif cmd == "reset" then
        CDB.applied, CDB.placed = nil, nil
        Print("Cleared this character's applied flag; /ft apply or relog applies again.")
    elseif cmd == "status" or cmd == "" then
        Status()
        Print("Commands: /ft save | apply | bars | ignore [addon] | errors | bug | auto on/off | reset | status")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("SPELLS_CHANGED")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        local fresh = ForeverTemplateDB == nil
        ForeverTemplateDB = ForeverTemplateDB or { auto = true }
        ForeverTemplateCharDB = ForeverTemplateCharDB or {}
        DB, CDB = ForeverTemplateDB, ForeverTemplateCharDB
        if (DB.version or 0) < 1 then
            -- Before versioning, Luxthos UI was hardcoded as untouchable; keep that for existing installs.
            DB.ignore = DB.ignore or (fresh and {} or { LuxthosUI = true, LuxthosUI_Data = true })
            DB.version = DB_VERSION
        end
        DB.ignore = DB.ignore or {}
        DB.tracker, DB.keepTracker = nil, nil -- the tracker fix was removed; drop what it saved
    elseif event == "PLAYER_LOGIN" then
        if DB.template and not CDB.applied and DB.auto then
            C_Timer.After(4, Apply)
        end
    elseif event == "SPELLS_CHANGED" and CDB and CDB.applied then
        C_Timer.After(1, function() Try("bars", ApplyBars) end)
    end
end)
