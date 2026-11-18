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

-- The tooltip's place in an Edit Mode layout (Luxthos UI's updates reset it to his default).
local TOOLTIP_SYSTEM = Enum.EditModeSystem and Enum.EditModeSystem.HudTooltip
local ANCHOR_KEYS = { "point", "relativeTo", "relativePoint", "offsetX", "offsetY" }

local function TooltipSystem(layout)
    for _, s in ipairs(layout and layout.systems or {}) do
        if s.system == TOOLTIP_SYSTEM then
            return s
        end
    end
end

-- { layout = name, anchor = {...} } for the active custom layout, or nil.
local function KeepTooltip()
    if not TOOLTIP_SYSTEM or not EditModeReady() then
        return nil
    end
    local info = C_EditMode.GetLayouts()
    local layout = info.layouts[info.activeLayout - #EditModePresetLayoutManager:GetCopyOfPresetLayouts()]
    local s = TooltipSystem(layout)
    if not s or not s.anchorInfo then
        return nil
    end
    local anchor = {}
    for _, key in ipairs(ANCHOR_KEYS) do
        anchor[key] = s.anchorInfo[key]
    end
    return { layout = layout.layoutName, anchor = anchor }
end

-- Writes a kept tooltip place back into its layout. Returns a message.
local function RestoreTooltip(kept)
    if not kept or not TOOLTIP_SYSTEM or not EditModeReady() then
        return nil
    end
    if EditModeManagerFrame:IsShown() then
        return "Tooltip position not restored: close Edit Mode and type /ft restore again."
    end
    local info = C_EditMode.GetLayouts()
    for _, layout in ipairs(info.layouts) do
        if layout.layoutName == kept.layout then
            local s = TooltipSystem(layout)
            if not s or not s.anchorInfo then
                return "Tooltip position not restored: layout '" .. kept.layout .. "' has no tooltip."
            end
            local changed = false
            for _, key in ipairs(ANCHOR_KEYS) do
                if s.anchorInfo[key] ~= kept.anchor[key] then
                    s.anchorInfo[key], changed = kept.anchor[key], true
                end
            end
            if not changed then
                return "Tooltip position was already yours."
            end
            C_EditMode.SaveLayouts(info)
            return "Tooltip position restored in Edit Mode layout '" .. kept.layout .. "'."
        end
    end
    return "Tooltip position not restored: Edit Mode layout '" .. kept.layout .. "' not found."
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

---------------------------------------------------------------- Keep my EllesmereUI changes across Luxthos UI updates
-- /ft keep stores every EllesmereUI setting that differs from Luxthos's own profile (the one in his pack).
-- /ft restore writes those settings back after an update replaced the profile. Settings Luxthos did not
-- change stay at his new values; only the ones you changed come back.
-- tooltipFixedPos: Luxthos moved the tooltip to Blizzard's Edit Mode, so an old EllesmereUI position must not return.
-- (The Edit Mode tooltip position is kept separately, see KeepTooltip.)
-- bagVisualOrder: item ids sorted into bag categories (inventory state, not a setting).
-- EllesmereUIQuickdraw: the module is off and its listed values are all defaults that EllesmereUI fills in.
-- nextBarId (a counter) and savedZoom (the minimap's last zoom) are state EllesmereUI writes itself.
-- EUI_TooltipAnchor is the same tooltip position as tooltipFixedPos, kept in the layout.
local KEEP_SKIP = {
    cdmSpells = true, unlockLayoutMeta = true, tooltipFixedPos = true,
    bagVisualOrder = true, EllesmereUIQuickdraw = true,
    nextBarId = true, savedZoom = true, EUI_TooltipAnchor = true,
}
local function KeepSkipped(key)
    return type(key) == "string" and (KEEP_SKIP[key] or key:sub(1, 1) == "_")
end

local function SameValue(a, b)
    if type(a) == "number" and type(b) == "number" then
        return math.abs(a - b) < 1e-6
    end
    return a == b
end

-- Every setting in `mine` that is missing from `base` or differs from it, as { path = {keys...}, value = v }.
-- `def` holds EllesmereUI's own defaults for the same place: a profile string leaves out settings that are at
-- their default, so a setting missing from `base` is compared with the default instead.
local function Diff(mine, base, path, out, def)
    for k, v in pairs(mine) do
        if not KeepSkipped(k) then
            path[#path + 1] = k
            local b, d
            if type(base) == "table" then
                b = base[k]
            end
            if type(def) == "table" then
                d = def[k]
            end
            if b == nil and type(d) ~= "table" then
                b = d
            end
            if type(v) == "table" then
                Diff(v, b, path, out, d)
            elseif not SameValue(v, b) then
                local copy = {}
                for i = 1, #path do
                    copy[i] = path[i]
                end
                out[#out + 1] = { path = copy, value = v }
            end
            path[#path] = nil
        end
    end
    return out
end

-- How many of base's settings also exist in mine, out of all of base's: a sanity check that both have the same shape.
local function SharedLeaves(base, mine)
    local shared, total = 0, 0
    for k, v in pairs(base) do
        if not KeepSkipped(k) then
            if type(v) == "table" then
                local s, t = SharedLeaves(v, type(mine) == "table" and mine[k] or nil)
                shared, total = shared + s, total + t
            else
                total = total + 1
                if type(mine) == "table" and mine[k] ~= nil then
                    shared = shared + 1
                end
            end
        end
    end
    return shared, total
end

-- Writes each stored setting into `profile`, creating tables on the way. Returns how many were written.
local function Patch(profile, patch)
    local written = 0
    for _, e in ipairs(patch) do
        local t = profile
        for i = 1, #e.path - 1 do
            local key = e.path[i]
            if t[key] == nil then
                t[key] = {}
            end
            t = t[key]
            if type(t) ~= "table" then
                t = nil
                break
            end
        end
        if t then
            t[e.path[#e.path]] = e.value
            written = written + 1
        end
    end
    return written
end

-- Luxthos's EllesmereUI profile as his pack ships it, decoded by EllesmereUI itself, and the pack's id.
local function LuxProfile()
    local eui, pack = EllesmereUI, LuxthosUI_Pack
    if type(eui) ~= "table" or type(eui.DecodeProfileString) ~= "function" then
        return nil, "EllesmereUI is not loaded."
    end
    if type(pack) ~= "table" or type(pack.profiles) ~= "table" then
        return nil, "Luxthos UI's data is not loaded."
    end
    for _, p in ipairs(pack.profiles) do
        if type(p.import) == "string" and p.import:find("^!EUI_") then
            local data = eui.DecodeProfileString(p.import)
            if type(data) == "table" then
                return data, pack.id
            end
        end
    end
    return nil, "No EllesmereUI profile found in Luxthos UI's data."
end

-- EllesmereUI's default settings per module, shaped like a profile ({ addons = { [folder] = defaults } }).
-- Every module registers its defaults with EllesmereUI.Lite; a module can register more than once.
local function EUIDefaults()
    local addons = {}
    local lite = EllesmereUI and EllesmereUI.Lite
    local registry = type(lite) == "table" and lite._dbRegistry
    if type(registry) ~= "table" then
        return nil
    end
    local function Fill(dest, src)
        for k, v in pairs(src) do
            if type(v) == "table" then
                if type(dest[k]) ~= "table" then
                    dest[k] = {}
                end
                Fill(dest[k], v)
            elseif dest[k] == nil then
                dest[k] = v
            end
        end
    end
    for _, db in ipairs(registry) do
        if type(db) == "table" and type(db.folder) == "string" and type(db._profileDefaults) == "table" then
            addons[db.folder] = addons[db.folder] or {}
            Fill(addons[db.folder], db._profileDefaults)
        end
    end
    return { addons = addons }
end

-- EllesmereUI's modules are separate addons. A module that is installed but not loaded is switched off, and
-- its settings are leftovers, so they are not stored. A folder that is not an addon at all is not a module.
local function ModuleOff(folder)
    if type(folder) ~= "string" then
        return false
    end
    local ok, loaded = pcall(AddOns.IsAddOnLoaded, folder)
    if not ok or loaded then
        return false
    end
    local ok2, name, _, _, _, reason = pcall(AddOns.GetAddOnInfo, folder)
    return ok2 and name ~= nil and reason ~= "MISSING"
end

-- Removes the settings of switched-off modules from `patch`; returns the names of those modules.
local function DropOffModules(patch)
    local off, names, kept = {}, {}, {}
    for _, e in ipairs(patch) do
        local folder = e.path[1] == "addons" and e.path[2] or nil
        if folder and off[folder] == nil then
            off[folder] = ModuleOff(folder)
            if off[folder] then
                names[#names + 1] = (folder:gsub("^EllesmereUI", ""))
            end
        end
        if not (folder and off[folder]) then
            kept[#kept + 1] = e
        end
    end
    table.sort(names)
    return kept, names
end

-- Bar Glows (Cooldown Manager > Bar Glows) are not in the profile: EllesmereUI keeps them per spec in
-- EllesmereUIDB.spellAssignments.profiles[name].specProfiles[spec].barGlows, and a profile string carries
-- them as cdmSpells[spec].barGlows. selectedBar is only the bar last picked in the options.
local function SpecProfiles(name)
    local sa = EllesmereUIDB and EllesmereUIDB.spellAssignments
    local bucket = sa and type(sa.profiles) == "table" and sa.profiles[name]
    local specs = type(bucket) == "table" and bucket.specProfiles
    if type(specs) == "table" then
        return specs
    end
end

-- Tracking Bars (Cooldown Manager > Tracking Bars) live in the same per-spec store: the bars in trackedBuffBars,
-- their positions in tbbPositions and their anchor links in tbbUnlockLinks.
-- section -> the root mark its settings get ("glows" = Bar Glows, "tbars" = Tracking Bars).
local SPEC_SECTIONS = {
    barGlows = "glows", trackedBuffBars = "tbars", tbbPositions = "tbars", tbbUnlockLinks = "tbars",
}
local ROOT_LABEL = { glows = "BarGlows", tbars = "TrackingBars" }

-- Every Bar Glow and Tracking Bar setting in `specs` that differs from Luxthos's (`baseSpecs`, his cdmSpells),
-- with path { spec, section, ... } and a root mark. Spec keys can be numbers or strings on either side.
local function DiffSpecStore(specs, baseSpecs, out)
    for spec, prof in pairs(specs) do
        if type(prof) == "table" then
            local b = type(baseSpecs) == "table" and (baseSpecs[spec] or baseSpecs[tostring(spec)] or baseSpecs[tonumber(spec) or false])
            for section, root in pairs(SPEC_SECTIONS) do
                local mine = prof[section]
                if type(mine) == "table" then
                    local found = Diff(mine, type(b) == "table" and b[section] or nil, { spec, section }, {})
                    for _, e in ipairs(found) do
                        if e.path[3] ~= "selectedBar" then
                            e.root = root
                            out[#out + 1] = e
                        end
                    end
                end
            end
        end
    end
    return out
end

local function ActiveEUIProfile()
    local name = EllesmereUI and EllesmereUI.GetActiveProfileName and EllesmereUI.GetActiveProfileName()
    local profile = name and EllesmereUIDB and EllesmereUIDB.profiles and EllesmereUIDB.profiles[name]
    if type(profile) == "table" then
        return name, profile
    end
end

local function Keep(force)
    local base, id = LuxProfile()
    if not base then
        return Print(id)
    end
    -- Luxthos's pack is newer than the last keep and that keep was not restored for it. Storing now would
    -- replace it, and would count leftovers from his old pack as your changes if his update is not applied yet.
    local last = DB.keep
    if last and id and last.luxId ~= id and last.restoredFor ~= id and not force then
        Print(("Luxthos UI changed since your settings were kept (%s), so nothing was stored."):format(tostring(last.date)))
        Print("Apply his update with /lux, then type /ft restore, then /ft keep. To replace the stored settings with your current ones anyway, type /ft keep force.")
        return
    end
    local name, mine = ActiveEUIProfile()
    if not name then
        return Print("Could not read the active EllesmereUI profile.")
    end
    local shared, total = SharedLeaves(base, mine)
    if total == 0 or shared / total < 0.5 then
        return Print(("Profile '%s' does not look like Luxthos's (%d of %d settings line up), so nothing was stored."):format(name, shared, total))
    end
    local patch, offModules = DropOffModules(Diff(mine, base, {}, {}, EUIDefaults()))
    local specs = SpecProfiles(name)
    if specs then
        DiffSpecStore(specs, base.cdmSpells, patch)
    end
    DB.keep = { profile = name, luxId = id, date = date("%Y-%m-%d %H:%M"), patch = patch, tooltip = Try("keep tooltip", KeepTooltip) }
    local per = {}
    for _, e in ipairs(patch) do
        local group = e.root and (ROOT_LABEL[e.root] or e.root) or tostring(e.path[1] == "addons" and e.path[2] or e.path[1])
        per[group] = (per[group] or 0) + 1
    end
    local list = {}
    for group, n in pairs(per) do
        list[#list + 1] = { group, n }
    end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    local parts = {}
    for i = 1, math.min(8, #list) do
        parts[i] = list[i][1] .. " " .. list[i][2]
    end
    Print(("Kept %d settings of profile '%s' that differ from Luxthos UI%s."):format(#patch, name, #patch > 0 and (": " .. table.concat(parts, ", ")) or ""))
    if #offModules > 0 then
        Print("Not stored, because the module is switched off: " .. table.concat(offModules, ", ") .. ".")
    end
    local tip = DB.keep.tooltip
    if tip then
        Print(("Kept the tooltip position of Edit Mode layout '%s' (%s %.1f, %.1f)."):format(tip.layout, tostring(tip.anchor.point), tip.anchor.offsetX or 0, tip.anchor.offsetY or 0))
    end
    Print("After updating Luxthos UI, type /ft restore.")
end

-- Prints the stored settings, one per line ("Module.path = value"); `filter` keeps lines containing that text.
local function KeepList(filter)
    local k = DB.keep
    if not k then
        return Print("Nothing stored. Type /ft keep first.")
    end
    filter = filter and filter ~= "" and filter:lower() or nil
    local lines = {}
    for _, e in ipairs(k.patch) do
        local parts = {}
        if e.root then
            parts[1] = ROOT_LABEL[e.root] or e.root
        end
        for i, key in ipairs(e.path) do
            -- Bar Glows drop their section name ("barGlows"); Tracking Bars keep theirs, since they have three.
            if not (i == 1 and key == "addons") and not (e.root == "glows" and i == 2) then
                parts[#parts + 1] = tostring(key)
            end
        end
        local value = tostring(e.value)
        if #value > 40 then
            value = value:sub(1, 40) .. "..."
        end
        local line = table.concat(parts, ".") .. " = " .. value
        if not filter or line:lower():find(filter, 1, true) then
            lines[#lines + 1] = line
        end
    end
    table.sort(lines)
    local MAX = 40
    for i = 1, math.min(MAX, #lines) do
        print("|cff999999" .. lines[i] .. "|r")
    end
    Print(("%d of %d kept settings shown%s."):format(math.min(MAX, #lines), #lines,
        #lines > MAX and "; narrow it with /ft keep list <text>, for example /ft keep list quickdraw" or ""))
end

local function Restore()
    local k = DB.keep
    if not k then
        return Print("Nothing stored. Type /ft keep before you update Luxthos UI.")
    end
    if InCombatLockdown() then
        return Print("In combat; type /ft restore when it ends.")
    end
    local tipMessage = Try("restore tooltip", RestoreTooltip, k.tooltip)
    if tipMessage then
        Print(tipMessage)
    end
    local profile = EllesmereUIDB and EllesmereUIDB.profiles and EllesmereUIDB.profiles[k.profile]
    if type(profile) ~= "table" then
        return Print("EllesmereUI profile '" .. k.profile .. "' no longer exists; nothing restored.")
    end
    -- Profile settings go into the profile; Bar Glows and Tracking Bars go into the profile's per-spec store.
    local settings, glows = {}, {}
    for _, e in ipairs(k.patch) do
        local list = e.root and glows or settings
        list[#list + 1] = e
    end
    local written = Patch(profile, settings)
    if #glows > 0 then
        local specs = SpecProfiles(k.profile)
        if specs then
            written = written + Patch(specs, glows)
        else
            Print(("%d kept Bar Glow and Tracking Bar settings were not restored: profile '%s' has no Cooldown Manager spell store."):format(#glows, k.profile))
        end
    end
    k.restoredFor = LuxthosUI_Pack and LuxthosUI_Pack.id or k.luxId
    Print(("Restored %d of %d kept settings into '%s' (stored %s)."):format(written, #k.patch, k.profile, k.date))
    StaticPopup_Show("FOREVERTEMPLATE_KEEP_RELOAD")
end

StaticPopupDialogs["FOREVERTEMPLATE_KEEP_RELOAD"] = {
    text = "Forever Template restored your EllesmereUI changes. Reload the UI to finish?",
    button1 = RELOADUI,
    button2 = CANCEL,
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- A new Luxthos pack since the last /ft keep: remind once per pack.
local function CheckKeepReminder()
    local k = DB.keep
    local id = LuxthosUI_Pack and LuxthosUI_Pack.id
    if k and id and k.luxId ~= id and k.restoredFor ~= id then
        Print("Luxthos UI changed since your settings were kept. Type /ft restore to put your EllesmereUI changes back.")
    end
end

SLASH_FOREVERTEMPLATE1, SLASH_FOREVERTEMPLATE2 = "/ft", "/forevertemplate"
SlashCmdList.FOREVERTEMPLATE = function(msg)
    local cmd, arg = msg:lower():match("^(%S*)%s*(%S*)")
    if cmd == "save" then
        Save()
    elseif cmd == "apply" then
        Apply()
    elseif cmd == "keep" then
        if arg == "list" then
            KeepList(msg:match("^%S+%s+%S+%s+(.-)%s*$"))
        else
            Keep(arg == "force")
        end
    elseif cmd == "restore" then
        Restore()
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
        Print("Commands: /ft save | apply | keep | restore | bars | ignore [addon] | errors | bug | auto on/off | reset | status")
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
        C_Timer.After(6, CheckKeepReminder)
        if DB.template and not CDB.applied and DB.auto then
            C_Timer.After(4, Apply)
        end
    elseif event == "SPELLS_CHANGED" and CDB and CDB.applied then
        C_Timer.After(1, function() Try("bars", ApplyBars) end)
    end
end)
