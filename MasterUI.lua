-- Master menu for the main Softcore UI.

local SC = Softcore

local function SavePosition(key, frame)
    SoftcoreDB = SoftcoreDB or {}
    SoftcoreDB.ui = SoftcoreDB.ui or {}
    SoftcoreDB.ui[key] = { x = frame:GetLeft(), y = frame:GetTop() }
end

local function RestorePosition(key, frame, defaultX, defaultY)
    local pos = SoftcoreDB and SoftcoreDB.ui and SoftcoreDB.ui[key]
    frame:ClearAllPoints()
    if pos and pos.x and pos.y then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", defaultX or 0, defaultY or 0)
    end
end

local TAB_RUN = "RUN"
local TAB_OVERVIEW = "OVERVIEW"
local TAB_VIOLATIONS = "VIOLATIONS"
local TAB_LOG = "LOG"
local TAB_ACHIEVEMENTS = "ACHIEVEMENTS"

local DISALLOWED_OUTCOME = "WARNING"
local PANEL_WIDTH = 710
local PANEL_HEIGHT = 500
local LOG_ROWS = 24
local LOG_ROW_TOP = -66
local LOG_ROW_HEIGHT = 18
local VIOLATION_ROWS = LOG_ROWS
local VIOLATION_ROW_TOP = LOG_ROW_TOP
local VIOLATION_ROW_HEIGHT = LOG_ROW_HEIGHT
local BODY_TEXT = { r = 0.94, g = 0.86, b = 0.68 }
local MUTED_TEXT = { r = 0.68, g = 0.56, b = 0.38 }
local GOLD_TEXT = { r = 1.00, g = 0.82, b = 0.20 }
local GREEN_TEXT = { r = 0.42, g = 1.00, b = 0.54 }
local RED_TEXT = { r = 1.00, g = 0.30, b = 0.25 }
local BLUE_TEXT = { r = 0.38, g = 0.66, b = 1.00 }
local PURPLE_TEXT = { r = 0.78, g = 0.58, b = 1.00 }
local ORANGE_TEXT = { r = 1.00, g = 0.58, b = 0.22 }
local MENU_LOGO_TEXTURE = "Interface\\AddOns\\Softcore\\Assets\\SoftcoreLogoMenu"

local GROUPING_OPTIONS = {
    { text = "Group", value = "SYNCED_GROUP_ALLOWED" },
    { text = "Solo Only", value = "SOLO_SELF_FOUND" },
}

local GEAR_OPTIONS = {
    { text = "Any gear", value = "ALLOWED" },
    { text = "White/gray only", value = "WHITE_GRAY_ONLY" },
    { text = "Green or lower", value = "GREEN_OR_LOWER" },
    { text = "Blue or lower", value = "BLUE_OR_LOWER" },
}

local ECONOMY_RULES = {
    { label = "Allow Auction House", key = "auctionHouse" },
    { label = "Allow Mailbox", key = "mailbox" },
    { label = "Allow Trade", key = "trade" },
    { label = "Allow Bank", key = "bank" },
    { label = "Allow Warband Bank", key = "warbandBank" },
    { label = "Allow Guild Bank", key = "guildBank" },
}

local MOVEMENT_RULES = {
    { label = "Allow Mounts", key = "mounts" },
    { label = "Allow Flying Mounts", key = "flying" },
    { label = "Allow Flight Paths", key = "flightPaths" },
}

local EDITABLE_RULE_ORDER = {
    "groupingMode",
    "auctionHouse",
    "mailbox",
    "trade",
    "bank",
    "warbandBank",
    "guildBank",
    "mounts",
    "flying",
    "flightPaths",
    "gearQuality",
    "heirlooms",
    "maxLevelGap",
    "maxLevelGapValue",
    "dungeonRepeat",
    "consumables",
    "instancedPvP",
    "firstPersonOnly",
    "actionCam",
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r " .. tostring(message))
end

local function FormatTime(timestamp)
    if not timestamp then return "never" end
    return date("%Y-%m-%d %H:%M:%S", timestamp)
end

local function FormatElapsed(startTime)
    if not startTime then return "" end
    local elapsed = time() - startTime
    if elapsed < 0 then elapsed = 0 end
    local h = math.floor(elapsed / 3600)
    local m = math.floor((elapsed % 3600) / 60)
    if h > 0 then
        return string.format("%dh %02dm", h, m)
    end
    return string.format("%dm", m)
end

local function Trunc(str, maxLen)
    str = tostring(str or "")
    if #str <= maxLen then return str end
    return string.sub(str, 1, maxLen - 2) .. ".."
end

local function FormatPlayerLabel(playerKey)
    if SC.FormatPlayerLabel then
        return SC:FormatPlayerLabel(playerKey)
    end

    local name = string.match(tostring(playerKey or "Unknown"), "^([^-]+)")
    return name or tostring(playerKey or "Unknown")
end

local function SetLine(fontString, label, value)
    fontString:SetText(label .. ": " .. tostring(value))
end

local LOG_EVENT_GROUP_COLORS = {
    achievement = GOLD_TEXT,
    character = GREEN_TEXT,
    failure = RED_TEXT,
    party = BLUE_TEXT,
    proposal = ORANGE_TEXT,
    rules = PURPLE_TEXT,
    run = GREEN_TEXT,
    system = MUTED_TEXT,
    violation = GOLD_TEXT,
    world = BODY_TEXT,
}

local LOG_HIDDEN_EVENTS = {
    GROUP_ROSTER = true,
    ZONE_CHANGED = true,
}

local LOG_EVENT_DISPLAY = {
    ACHIEVEMENT_EARNED = { label = "Achievement", group = "achievement" },
    DEATH = { label = "Death", group = "failure" },
    GROUP_ROSTER = { label = "Group Changed", group = "party" },
    INSTANCE_ENTERED = { label = "Instance", group = "world" },
    LEVEL_GAP_EXCEEDED = { label = "Level Gap", group = "party" },
    LEVEL_UP = { label = "Level Up", group = "character" },
    PARTICIPANT_ADDED = { label = "Joined Run", group = "party" },
    PARTICIPANT_DISCOVERED = { label = "Party Synced", group = "party" },
    PARTICIPANT_FAILED = { label = "Member Failed", group = "failure" },
    PARTICIPANT_OUT_OF_PARTY = { label = "Left Party", group = "party" },
    PARTICIPANT_RETIRED = { label = "Retired", group = "failure" },
    PROPOSAL_ACCEPT_SYNC = { label = "Accepted", group = "proposal" },
    PROPOSAL_ACCEPTED = { label = "Accepted", group = "proposal" },
    PROPOSAL_BUSY_DECLINED = { label = "Proposal Busy", group = "proposal" },
    PROPOSAL_CANCELLED = { label = "Cancelled", group = "proposal" },
    PROPOSAL_CONFIRMED = { label = "Confirmed", group = "proposal" },
    PROPOSAL_CREATED = { label = "Proposal", group = "proposal" },
    PROPOSAL_DECLINED = { label = "Declined", group = "proposal" },
    PROPOSAL_DECLINE_SYNC = { label = "Declined", group = "proposal" },
    PROPOSAL_EXPIRED = { label = "Expired", group = "proposal" },
    PROPOSAL_HASH_MISMATCH = { label = "Rules Mismatch", group = "proposal" },
    PROPOSAL_OBSERVED = { label = "Proposal Seen", group = "proposal" },
    PROPOSAL_RESPONSE_UNKNOWN = { label = "Unknown Reply", group = "proposal" },
    PROPOSAL_VERSION_MISMATCH = { label = "Version Mismatch", group = "proposal" },
    RULE_AMENDMENT_ACCEPTED = { label = "Rule Accepted", group = "rules" },
    RULE_AMENDMENT_APPLIED = { label = "Rules Applied", group = "rules" },
    RULE_AMENDMENT_DECLINED = { label = "Rule Declined", group = "rules" },
    RULE_AMENDMENT_PROPOSED = { label = "Rule Proposal", group = "rules" },
    RULE_AMENDMENT_RECEIVED = { label = "Rule Proposal", group = "rules" },
    RULE_CHANGED = { label = "Rule Changed", group = "rules" },
    RULE_LOG = { label = "Rule Notice", group = "rules" },
    RULE_UNKNOWN_OUTCOME = { label = "Rule Notice", group = "rules" },
    RUN_RESET = { label = "Run Reset", group = "run" },
    RUN_START = { label = "Run Started", group = "run" },
    RUN_SYNCED = { label = "Run Synced", group = "run" },
    VIOLATION_ADDED = { label = "Violation", group = "violation" },
    VIOLATION_CLEARED = { label = "Cleared", group = "violation" },
    ZONE_CHANGED = { label = "Zone", group = "world" },
}

local function HumanizeEventKind(kind)
    local text = string.gsub(string.lower(tostring(kind or "")), "_", " ")
    text = string.gsub(text, "(%a)([%w']*)", function(first, rest)
        return string.upper(first) .. rest
    end)
    return text ~= "" and text or "Event"
end

local function FormatLogEvent(entry)
    local kind = tostring(entry and entry.kind or "")
    local display = LOG_EVENT_DISPLAY[kind]

    if display then
        return display.label, LOG_EVENT_GROUP_COLORS[display.group] or BODY_TEXT
    end

    return HumanizeEventKind(kind), LOG_EVENT_GROUP_COLORS.system
end

local function ShouldShowLogEntry(entry)
    return not LOG_HIDDEN_EVENTS[tostring(entry and entry.kind or "")]
end

local function GetVisibleLogEntries(log)
    local entries = {}

    for index = #log, 1, -1 do
        local entry = log[index]
        if ShouldShowLogEntry(entry) then
            table.insert(entries, entry)
        end
    end

    return entries
end

local LOG_VIOLATION_LABELS = {
    auctionHouse = "Auction House",
    bank = "Bank",
    consumables = "Consumable",
    death = "Death",
    flying = "Flying",
    gearQuality = "Gear",
    guildBank = "Guild Bank",
    mailbox = "Mailbox",
    mounts = "Mount",
    trade = "Trade",
    warbandBank = "Warband Bank",
}

local function FormatViolationLogLabel(violationType)
    local raw = tostring(violationType or "")
    return LOG_VIOLATION_LABELS[raw] or HumanizeEventKind(raw)
end

local function ExtractItemLink(text)
    local raw = tostring(text or "")
    return string.match(raw, "(|c.-|Hitem:.-|h%[.-%]|h|r)")
        or string.match(raw, "(|Hitem:.-|h%[.-%]|h)")
end

local function FindViolationById(violationId)
    if not violationId then return nil end

    local db = SC.db or SoftcoreDB
    for _, violation in ipairs((db and db.violations) or {}) do
        if violation.id == violationId or violation.violationId == violationId then
            return violation
        end
    end

    return nil
end

local function SetCompactText(fontString, message, maxLen)
    if string.find(tostring(message or ""), "|Hitem:", 1, true) then
        fontString:SetText(message)
        return
    end

    fontString:SetText(Trunc(message, maxLen))
end

local function FormatViolationDetail(violation)
    local detail = violation and violation.detail
    local itemLink = ExtractItemLink(detail)

    if itemLink then
        return "Item: " .. itemLink
    end

    return tostring(detail or "")
end

local function FormatViolationLogMessage(kind, violationType, violationDetail, entry)
    local label = FormatViolationLogLabel(violationType)
    local sourceViolation = entry and FindViolationById(entry.violationId)
    local itemLink = ExtractItemLink(violationDetail)
        or ExtractItemLink(entry and entry.message)
        or ExtractItemLink(sourceViolation and sourceViolation.detail)

    if itemLink then
        return label .. " Violation: " .. itemLink
    end

    if violationType == "gearQuality" then
        if kind == "VIOLATION_CLEARED" then
            return "Cleared gear violation."
        end

        return "Gear violation."
    end

    if kind == "VIOLATION_CLEARED" then
        return "Cleared " .. label .. "."
    end

    if violationDetail and violationDetail ~= "" then
        return label .. ": " .. tostring(violationDetail)
    end

    return label .. " violation."
end

local function FormatLogMessage(entry)
    local kind = tostring(entry and entry.kind or "")
    local violationType = entry and entry.violationType
    local violationDetail = entry and (entry.violationDetail or entry.message)

    if kind == "VIOLATION_ADDED" and violationType then
        return FormatViolationLogMessage(kind, violationType, violationDetail, entry)
    end

    if kind == "VIOLATION_CLEARED" and violationType then
        return FormatViolationLogMessage(kind, violationType, violationDetail, entry)
    end

    if kind == "RUN_START" then
        local level = string.match(tostring(entry and entry.message or ""), "level (%d+)")
        if level then
            return "Started at level " .. level .. "."
        end
    end

    return tostring(entry and entry.message or "")
end

local function IsActiveRun()
    local db = SC.db or SoftcoreDB
    return db and db.run and db.run.active
end

local function GetDefaultTab()
    return IsActiveRun() and TAB_OVERVIEW or TAB_RUN
end

local function NormalizeTab(tab)
    if tab == "START" or tab == "RULES" then
        return TAB_RUN
    end

    if tab == "STATUS" or tab == "PARTY" then
        return TAB_OVERVIEW
    end

    if tab == TAB_LOG or tab == TAB_RUN or tab == TAB_OVERVIEW or tab == TAB_VIOLATIONS or tab == TAB_ACHIEVEMENTS then
        return tab
    end

    return GetDefaultTab()
end

local function CreateButton(parent, label, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 90, height or 24)
    button:SetText(label)
    return button
end

local function CreatePanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, -110)
    return panel
end

local function ApplyParchmentBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = false, edgeSize = 32,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.12, 0.075, 0.035, 0.98)
    frame:SetBackdropBorderColor(0.72, 0.56, 0.22, 1)
end

local function CreateDivider(parent, x, y, width)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    divider:SetWidth(width or PANEL_WIDTH)
    divider:SetColorTexture(0.72, 0.49, 0.18, 0.42)
    return divider
end

local function CreateSectionHeader(parent, text, x, y, width)
    local header = CreateFrame("Frame", nil, parent)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    header:SetSize(width or 260, 22)
    local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    fs:SetWidth(width or 260)
    fs:SetJustifyH("LEFT")
    fs:SetText("|cffffd100" .. text .. "|r")
    CreateDivider(header, 0, -18, width or 260)
    return header
end

local function CreateField(parent, x, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(width or (PANEL_WIDTH - 40))
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(BODY_TEXT.r, BODY_TEXT.g, BODY_TEXT.b)
    fs:SetText("")
    return fs
end

local function CreateLabel(parent, text, x, y, template, width)
    local fs = CreateField(parent, x, y, width or 220)
    fs:SetFontObject(_G[template or "GameFontNormalSmall"])
    if template == "GameFontNormal" then
        fs:SetTextColor(GOLD_TEXT.r, GOLD_TEXT.g, GOLD_TEXT.b)
    else
        fs:SetTextColor(BODY_TEXT.r, BODY_TEXT.g, BODY_TEXT.b)
    end
    fs:SetText(text)
    return fs
end

local function GetOptionText(options, value)
    for _, option in ipairs(options) do
        if option.value == value then
            return option.text
        end
    end

    return tostring(value or "")
end

local function CreateDropdown(parent, name, options, selectedValue, onSelect, width)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, width or 145)
    UIDropDownMenu_SetText(dropdown, GetOptionText(options, selectedValue))
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        for _, option in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.func = function()
                UIDropDownMenu_SetText(dropdown, option.text)
                onSelect(option.value)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    return dropdown
end

local STATUS_COLORS = {
    VALID   = "|cff4ade80",
    ACTIVE  = "|cff4ade80",
    FAILED  = "|cffff4444",
    BLOCKED = "|cfffbbf24",
    CONFLICT = "|cfffbbf24",
    VIOLATION = "|cfffbbf24",
    UNSYNCED = "|cff9ca3af",
    INACTIVE = "|cff9ca3af",
    NOT_IN_RUN = "|cff9ca3af",
}
local COLOR_RESET = "|r"

local STATUS_LABELS = {
    VALID = "Valid",
    ACTIVE = "Active",
    FAILED = "Failed",
    BLOCKED = "Blocked",
    CONFLICT = "Conflict",
    VIOLATION = "Violation",
    WARNING = "Violation",
    UNSYNCED = "Unsynced",
    INACTIVE = "Inactive",
    NOT_IN_RUN = "Not in Run",
    OUT_OF_PARTY = "Out of Party",
    RETIRED = "Retired",
    RUN_MISMATCH = "Run Conflict",
    RULESET_MISMATCH = "Rules Conflict",
    ADDON_VERSION_MISMATCH = "Version Conflict",
}

local function FriendlyStatus(statusStr)
    local raw = tostring(statusStr or "")
    local base, detail = string.match(raw, "^(%u+)%s*%((.*)%)$")
    base = base or raw
    local label = STATUS_LABELS[base] or raw
    if detail and detail ~= "" then
        return label .. " (" .. detail .. ")"
    end
    return label
end

local function ColorStatus(statusStr)
    if not statusStr then return "" end
    local base = string.match(statusStr, "^(%u+)")
    local color = base and STATUS_COLORS[base]
    local label = FriendlyStatus(statusStr)
    if color then
        return color .. label .. COLOR_RESET
    end
    return label
end

local function IsDisallowed(value)
    return value ~= nil and value ~= "ALLOWED" and value ~= "LOG_ONLY"
end

local function SetDisallowedRule(rules, key, checked)
    rules[key] = checked and "ALLOWED" or DISALLOWED_OUTCOME
end

local function IsCameraRuleEnforced(rules)
    return IsDisallowed(rules and rules.firstPersonOnly) or IsDisallowed(rules and rules.actionCam)
end

local function SetCameraRules(rules, mode)
    if mode == "FIRST_PERSON" then
        rules.firstPersonOnly = DISALLOWED_OUTCOME
        rules.actionCam = "ALLOWED"
    elseif mode == "CINEMATIC" then
        rules.firstPersonOnly = "ALLOWED"
        rules.actionCam = DISALLOWED_OUTCOME
    else
        rules.firstPersonOnly = "ALLOWED"
        rules.actionCam = "ALLOWED"
    end
end

local function GetSelectedCameraMode(start)
    if start.selectedCameraMode then return start.selectedCameraMode end
    if IsDisallowed(start.selectedRules.actionCam) then return "CINEMATIC" end
    if IsDisallowed(start.selectedRules.firstPersonOnly) then return "FIRST_PERSON" end
    return nil
end

local function SetFontStringRGB(fontString, color)
    fontString:SetTextColor(color.r, color.g, color.b)
end

local function ClearCheckboxPressVisual(checkbox)
    if not checkbox then return end
    if checkbox.SetButtonState then
        checkbox:SetButtonState("NORMAL", false)
    end
    if checkbox.UnlockHighlight then
        checkbox:UnlockHighlight()
    end
    if checkbox.GetHighlightTexture then
        local texture = checkbox:GetHighlightTexture()
        if texture then texture:Hide() end
    end
end

local function ClearCameraCheckboxVisuals(start)
    if not start then return end
    ClearCheckboxPressVisual(start.firstPersonCheck)
    ClearCheckboxPressVisual(start.actionCamCheck)
end

local function IsCheckedRuleValue(ruleName, value)
    if ruleName == "groupingMode" or ruleName == "gearQuality" or ruleName == "maxLevelGapValue" then
        return nil
    end
    if ruleName == "maxLevelGap" or ruleName == "firstPersonOnly" or ruleName == "actionCam" then
        return value ~= "ALLOWED"
    end
    return not IsDisallowed(value)
end

local function CreateAllowCheckbox(parent, rules, spec, x, y)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    checkbox.label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
    checkbox.label:SetWidth(230)
    checkbox.label:SetJustifyH("LEFT")
    checkbox.label:SetTextColor(BODY_TEXT.r, BODY_TEXT.g, BODY_TEXT.b)
    checkbox.label:SetText(spec.label)
    checkbox.ruleKey = spec.key
    checkbox:SetChecked(not IsDisallowed(rules[spec.key]))
    checkbox:SetScript("OnClick", function(self)
        SetDisallowedRule(rules, spec.key, self:GetChecked())
        if SC.MasterUI_Refresh then
            SC:MasterUI_Refresh()
        end
    end)
    return checkbox
end

local function ApplyStartPreset(frame, preset)
    local rules = frame.start.selectedRules
    frame.start.selectedPreset = preset

    local ironman = preset == "IRONMAN"
    local chef = preset == "CHEF_SPECIAL"

    rules.groupingMode = ironman and "SOLO_SELF_FOUND" or "SYNCED_GROUP_ALLOWED"
    rules.gearQuality = ironman and "WHITE_GRAY_ONLY" or (chef and "GREEN_OR_LOWER" or "ALLOWED")
    rules.maxLevelGap = ironman and DISALLOWED_OUTCOME or "ALLOWED"
    rules.maxLevelGapValue = 3
    rules.heirlooms = DISALLOWED_OUTCOME
    rules.dungeonRepeat = ironman and DISALLOWED_OUTCOME or "ALLOWED"
    rules.instanceWithUnsyncedPlayers = "ALLOWED"
    rules.unsyncedMembers = "ALLOWED"

    for _, spec in ipairs(ECONOMY_RULES) do
        SetDisallowedRule(rules, spec.key, not (ironman or spec.key == "auctionHouse" or spec.key == "mailbox" or spec.key == "trade" or spec.key == "bank" or spec.key == "warbandBank" or spec.key == "guildBank"))
    end

    for _, spec in ipairs(MOVEMENT_RULES) do
        SetDisallowedRule(rules, spec.key, not ironman)
    end

    SetDisallowedRule(rules, "consumables", not ironman)
    SetDisallowedRule(rules, "instancedPvP", false)
    rules.firstPersonOnly = "ALLOWED"
    rules.actionCam = "ALLOWED"
    frame.start.selectedCameraMode = nil

    if chef then
        rules.auctionHouse = DISALLOWED_OUTCOME
        rules.mailbox = DISALLOWED_OUTCOME
        rules.trade = DISALLOWED_OUTCOME
        rules.bank = DISALLOWED_OUTCOME
        rules.warbandBank = DISALLOWED_OUTCOME
        rules.guildBank = DISALLOWED_OUTCOME
        rules.mounts = "ALLOWED"
        rules.flying = DISALLOWED_OUTCOME
        rules.heirlooms = DISALLOWED_OUTCOME
        rules.consumables = "ALLOWED"
        rules.dungeonRepeat = "ALLOWED"
        rules.instancedPvP = DISALLOWED_OUTCOME
        frame.start.selectedCameraMode = "CINEMATIC"
        SetCameraRules(rules, frame.start.selectedCameraMode)
    end

    rules.maxDeaths = false
    rules.maxDeathsValue = rules.maxDeathsValue or 3
    rules.achievementPreset = preset

    if SC.ApplyGroupingMode then
        SC:ApplyGroupingMode(rules)
    end

    if frame.start.RefreshControls then
        frame.start:RefreshControls()
    end
end

local function CopyRulesInto(target, source)
    for key in pairs(target) do
        target[key] = nil
    end

    for key, value in pairs(source or {}) do
        target[key] = value
    end
end

local function BuildRuleChanges(previousRules, nextRules)
    local changes = {}

    for _, ruleName in ipairs(EDITABLE_RULE_ORDER) do
        local previousValue = previousRules and previousRules[ruleName]
        local nextValue = nextRules and nextRules[ruleName]

        if tostring(previousValue) ~= tostring(nextValue) then
            changes[ruleName] = nextValue
        end
    end

    return changes
end

local function CountRuleChanges(changes)
    local count = 0

    for _ in pairs(changes or {}) do
        count = count + 1
    end

    return count
end


local RULE_DISPLAY_NAMES = {
    groupingMode   = "Grouping Mode",
    auctionHouse   = "Auction House",
    mailbox        = "Mailbox",
    trade          = "Trade",
    bank           = "Bank",
    warbandBank    = "Warband Bank",
    guildBank      = "Guild Bank",
    mounts         = "Mounts",
    flying         = "Flying Mounts",
    flightPaths    = "Flight Paths",
    gearQuality    = "Gear Limit",
    heirlooms      = "Heirlooms",
    maxLevelGap    = "Level Gap Enforcement",
    maxLevelGapValue = "Max Level Gap",
    dungeonRepeat  = "Repeated Dungeons",
    consumables    = "Consumables",
    instancedPvP   = "Instanced PvP",
    firstPersonOnly = "First Person Camera",
    actionCam      = "Cinematic Camera",
}

local function FriendlyRuleValue(ruleName, value)
    if value == nil then return "|cff9ca3af?|r" end
    if ruleName == "groupingMode" then
        if value == "SYNCED_GROUP_ALLOWED" then return "grouping" end
        if value == "SOLO_SELF_FOUND" then return "solo only" end
    end
    if ruleName == "gearQuality" then
        return GetOptionText(GEAR_OPTIONS, value)
    end
    if ruleName == "maxLevelGapValue" or ruleName == "maxDeathsValue" then
        return tostring(value)
    end
    if ruleName == "maxDeaths" then
        return value and "enabled" or "disabled"
    end
    if value == "ALLOWED" or value == "LOG_ONLY" then return "allowed" end
    return "disallowed"
end

local function GetPendingAmendment()
    local db = SC.db or SoftcoreDB
    for _, amendment in ipairs(db and db.ruleAmendments or {}) do
        if amendment.status == "PENDING" then
            return amendment
        end
    end
    return nil
end

local function GetPendingRunProposal()
    if SC.GetPendingProposal then
        local proposal = SC:GetPendingProposal()
        if proposal and (proposal.status == "PENDING" or proposal.status == "ACCEPTED") then
            return proposal
        end
    end
    return nil
end

local function GetPendingRulesConflict()
    local db = SC.db or SoftcoreDB
    for _, conflict in pairs(db and db.run and db.run.conflicts or {}) do
        if conflict.active and conflict.type == "RULESET_MISMATCH" and conflict.remoteRuleset and not conflict.dismissed then
            return conflict
        end
    end
    return nil
end

local function GetSortedActiveViolations()
    local db = SC.db or SoftcoreDB
    local source = (db and db.violations) or {}
    local result = {}

    for _, violation in ipairs(source) do
        if violation.status ~= "CLEARED" then
            table.insert(result, violation)
        end
    end

    table.sort(result, function(left, right)
        return (left.createdAt or 0) > (right.createdAt or 0)
    end)

    return result
end

local function CountAllViolations(playerKey)
    local db = SC.db or SoftcoreDB
    local count = 0
    for _, v in ipairs(db and db.violations or {}) do
        if v.playerKey == playerKey then
            count = count + 1
        end
    end
    return count
end

local function CountActiveConflicts(run)
    local count = 0
    for _, conflict in pairs(run and run.conflicts or {}) do
        if conflict.active then
            count = count + 1
        end
    end
    return count
end

local function FormatSyncTime(timestamp)
    if not timestamp then
        return "none"
    end
    return FormatElapsed(timestamp) .. " ago"
end

local function BuildRunIntegritySummary(run, activeViolations)
    local db = SC.db or SoftcoreDB
    local rulesHash = SC.GetRulesetHash and SC:GetRulesetHash() or "unknown"
    local conflicts = CountActiveConflicts(run)
    local version = SC.version or "?"
    local sync = db and db.sync or {}
    local lastSync = sync.lastReceivedAt or sync.lastSentAt

    local summary = "Integrity: addon " .. tostring(version)
        .. "  /  rules " .. tostring(rulesHash)
        .. "  /  conflicts " .. tostring(conflicts)
        .. "  /  active violations " .. tostring(activeViolations or 0)

    if IsInGroup() then
        summary = summary .. "  /  sync " .. FormatSyncTime(lastSync)
    end

    return summary
end

local function GetPartyDisplayRows()
    local db = SC.db or SoftcoreDB
    local syncRows = SC.Sync_GetGroupRows and SC:Sync_GetGroupRows() or {}
    local participantOrder = db and db.run and db.run.participantOrder or {}
    local participants = db and db.run and db.run.participants or {}
    local localKey = SC:GetPlayerKey()
    local displayRows = {}
    local seen = {}

    local localStatus = SC:GetPlayerStatus()
    local localName = db and db.character and db.character.name or FormatPlayerLabel(localKey)
    local localParticipant = participants[localKey]
    table.insert(displayRows, {
        name = localName or "You",
        level = db and db.character and db.character.level,
        startLevel = localParticipant and localParticipant.levelAtJoin,
        status = localStatus.participantStatus or "NOT_IN_RUN",
        totalViolations = CountAllViolations(localKey),
    })
    seen[localKey] = true

    for _, peer in ipairs(syncRows) do
        local peerKey = peer.playerKey or peer.name
        local displayStatus = tostring(SC.Sync_GetDisplayStatus and SC:Sync_GetDisplayStatus(peer) or peer.participantStatus or "UNKNOWN")
        if (peer.activeViolations or 0) > 0 then
            local violationType = peer.latestViolation and peer.latestViolation.type
            if violationType and violationType ~= "" then
                displayStatus = "VIOLATION (" .. tostring(violationType) .. ")"
            else
                displayStatus = "VIOLATION"
            end
        end

        if peerKey and not seen[peerKey] and #displayRows < 5 then
            table.insert(displayRows, {
                name = peer.name or peer.playerKey or "Unknown",
                level = peer.level,
                startLevel = participants[peerKey] and participants[peerKey].levelAtJoin,
                status = displayStatus,
                totalViolations = CountAllViolations(peer.playerKey or ""),
            })
            seen[peerKey] = true
        end
    end

    for _, participantKey in ipairs(participantOrder) do
        if participantKey ~= localKey and not seen[participantKey] and #displayRows < 5 then
            local participant = participants[participantKey]
            if participant then
                table.insert(displayRows, {
                    name = participant.playerKey,
                    level = participant.currentLevel,
                    startLevel = participant.levelAtJoin,
                    status = tostring(participant.status or "UNKNOWN"),
                    totalViolations = CountAllViolations(participantKey),
                })
                seen[participantKey] = true
            end
        end
    end

    return displayRows
end

local function CreateOverviewPartyRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(690, 24)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -252 - ((index - 1) * 28))
    if index % 2 == 0 then
        local rowBg = row:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints(row)
        rowBg:SetColorTexture(0.82, 0.58, 0.22, 0.08)
    end
    row.name = CreateField(row, 0, 0, 190)
    row.level = CreateField(row, 204, 0, 90)
    row.status = CreateField(row, 314, 0, 180)
    row.total = CreateField(row, 520, 0, 120)
    return row
end

local function RefreshOverviewPanel(frame)
    local db = SC.db or SoftcoreDB
    local run = db and db.run or {}
    local active = run.active
    local status = SC:GetPlayerStatus()
    local partyRows = GetPartyDisplayRows()
    local activeViolations = #GetSortedActiveViolations()
    local localKey = SC:GetPlayerKey()
    local localParticipant = run.participants and run.participants[localKey]
    local startLevel = (localParticipant and localParticipant.levelAtJoin) or run.startLevel
    local grouped = IsInGroup()

    frame.overview.noRunText:SetShown(not active)
    frame.overview.goToRunBtn:SetShown(not active)
    frame.overview.resyncBtn:SetShown(grouped)

    frame.overview.run:SetShown(active)
    frame.overview.localStatus:SetShown(active)
    frame.overview.partyStatus:SetShown(active)
    frame.overview.elapsed:SetShown(active)
    frame.overview.deaths:SetShown(active)
    frame.overview.violations:SetShown(active)
    frame.overview.levels:SetShown(active)
    frame.overview.runId:SetShown(active)
    frame.overview.integrity:SetShown(active)

    if active then
        frame.overview.run:SetText("|cffffd100" .. tostring(run.runName or "Softcore Run") .. "|r")
        frame.overview.localStatus:SetText("Character: " .. ColorStatus(status.participantStatus or "NOT_IN_RUN"))
        frame.overview.partyStatus:SetText("Party: " .. ColorStatus(status.partyStatus or "INACTIVE"))
        frame.overview.elapsed:SetText("Elapsed: " .. FormatElapsed(run.startTime) .. "  |cffad8f61Started " .. FormatTime(run.startTime) .. "|r")
        SetLine(frame.overview.deaths, "Deaths", tostring(run.deathCount or 0) .. " (permanent)")
        if not tonumber(startLevel) or tonumber(startLevel) <= 0 then
            startLevel = "?"
        end
        frame.overview.levels:SetText("Level: " .. tostring(db and db.character and db.character.level or "?") .. "  |cffad8f61Started at " .. tostring(startLevel) .. "|r")

        local violationColor = activeViolations > 0 and "|cfffbbf24" or ""
        local violationReset = activeViolations > 0 and "|r" or ""
        frame.overview.violations:SetText("Active violations: " .. violationColor .. activeViolations .. violationReset)

        frame.overview.runId:SetText("|cffad8f61Run ID: " .. tostring(run.runId or "none") .. "|r")
        frame.overview.integrity:SetText("|cffad8f61" .. BuildRunIntegritySummary(run, activeViolations) .. "|r")
    end

    frame.overview.partyEmpty:SetShown(grouped and #partyRows == 0)

    for index = #frame.overview.partyRows + 1, math.min(#partyRows, 5) do
        frame.overview.partyRows[index] = CreateOverviewPartyRow(frame.overview.panel, index)
    end

    for index, row in ipairs(frame.overview.partyRows) do
        local display = partyRows[index]
        if display then
            row:Show()
            row.name:SetText(Trunc(display.name, 24))
            local levelText = display.level and tostring(display.level) or ""
            if tonumber(display.startLevel) and tonumber(display.startLevel) > 0 then
                levelText = levelText .. " |cffad8f61(" .. tostring(display.startLevel) .. ")|r"
            end
            row.level:SetText(levelText)
            row.status:SetText(ColorStatus(display.status))
            local total = display.totalViolations or 0
            row.total:SetText(total > 0 and "|cfffbbf24" .. total .. "|r" or "0")
        else
            row:Hide()
        end
    end
end

local function SetRunSetupEnabled(frame, enabled)
    local start = frame.start

    start.casualBtn:SetEnabled(enabled)
    start.ironmanBtn:SetEnabled(enabled)
    if start.chefBtn then start.chefBtn:SetEnabled(enabled) end

    for _, control in ipairs(start.controls) do
        if control.Enable and control.Disable then
            if enabled then control:Enable() else control:Disable() end
        end
    end

    if UIDropDownMenu_EnableDropDown and UIDropDownMenu_DisableDropDown then
        if enabled then
            UIDropDownMenu_EnableDropDown(start.groupingDropdown)
            UIDropDownMenu_EnableDropDown(start.gearDropdown)
        else
            UIDropDownMenu_DisableDropDown(start.groupingDropdown)
            UIDropDownMenu_DisableDropDown(start.gearDropdown)
        end
    end

    if enabled then
        start.maxGapBox:Enable()
    else
        start.maxGapBox:Disable()
    end
end

local function RefreshAmendmentPanel(frame, amendment, isProposer)
    local panel = frame.start.amendmentPanel
    local localShortName = string.match(tostring(amendment.proposedBy or "?"), "^([^-]+)")

    if isProposer then
        panel.title:SetText("|cfffbbf24Pending Rule Amendment|r - waiting for party")
        panel.proposer:SetText("You proposed this amendment.")
    else
        panel.title:SetText("|cfffbbf24Pending Rule Amendment|r")
        panel.proposer:SetText("Proposed by: " .. (localShortName or "?"))
    end
    panel.reason:SetText("Reason: " .. Trunc(amendment.reason or "", 90))

    local changeCount = 0
    for _, ruleName in ipairs(EDITABLE_RULE_ORDER) do
        if amendment.newRules[ruleName] ~= nil then
            changeCount = changeCount + 1
            if changeCount <= 8 then
                local oldVal = amendment.previousRules[ruleName]
                local newVal = amendment.newRules[ruleName]
                local label = RULE_DISPLAY_NAMES[ruleName] or ruleName
                panel.changeLines[changeCount]:SetText(
                    "- " .. label .. ": " .. FriendlyRuleValue(ruleName, oldVal) .. " -> " .. FriendlyRuleValue(ruleName, newVal)
                )
            end
        end
    end
    for i = changeCount + 1, 8 do
        panel.changeLines[i]:SetText("")
    end

    local contentH = 72 + (math.max(1, changeCount) * 16) + 42
    panel:SetHeight(contentH)

    panel.acceptBtn:SetShown(not isProposer)
    panel.declineBtn:SetShown(not isProposer)
    panel.cancelBtn:SetShown(isProposer)
    panel.waitText:SetShown(isProposer)

    if not isProposer then
        panel.acceptBtn:SetScript("OnClick", function()
            if SC.AcceptRuleAmendment then SC:AcceptRuleAmendment(amendment.id) end
            SC:MasterUI_Refresh()
        end)
        panel.declineBtn:SetScript("OnClick", function()
            if SC.DeclineRuleAmendment then SC:DeclineRuleAmendment(amendment.id) end
            SC:MasterUI_Refresh()
        end)
    else
        panel.cancelBtn:SetScript("OnClick", function()
            local db = SC.db or SoftcoreDB
            for _, a in ipairs(db and db.ruleAmendments or {}) do
                if a.id == amendment.id and a.status == "PENDING" then
                    a.status = "DECLINED"
                    a.declinedAt = time()
                    a.declinedBy = SC:GetPlayerKey()
                    if SC.Sync_SendAmendmentCancelled then SC:Sync_SendAmendmentCancelled(a) end
                    break
                end
            end
            frame.start.isModifyingRules = false
            frame.start.draftBaseRules = nil
            SC:MasterUI_Refresh()
        end)
    end
end


local function HideAllRunControls(frame)
    frame.start.inactiveText:Hide()
    frame.start.activeText:Hide()
    if frame.start.presetLabel then frame.start.presetLabel:Hide() end
    if frame.start.cancelRunHint then frame.start.cancelRunHint:Hide() end
    frame.start.casualBtn:Hide()
    frame.start.ironmanBtn:Hide()
    if frame.start.chefBtn then frame.start.chefBtn:Hide() end
    for _, control in ipairs(frame.start.controls) do control:Hide() end
    frame.start.groupingDropdown:Hide()
    frame.start.gearDropdown:Hide()
    frame.start.maxGapBox:Hide()
    frame.start.primaryBtn:Hide()
    frame.start.stopBtn:Hide()
    if frame.start.confirmStopBtn then frame.start.confirmStopBtn:Hide() end
    if frame.start.cancelStopBtn then frame.start.cancelStopBtn:Hide() end
    if frame.start.cancelRunBox then frame.start.cancelRunBox:Hide() end
    frame.start.modifyBtn:Hide()
    if frame.start.syncBtn then frame.start.syncBtn:Hide() end
    if frame.start.inviteBtn then frame.start.inviteBtn:Hide() end
    frame.start.applyChangesBtn:Hide()
    frame.start.cancelChangesBtn:Hide()
    if frame.start.proposalAcceptBtn then frame.start.proposalAcceptBtn:Hide() end
    if frame.start.proposalDeclineBtn then frame.start.proposalDeclineBtn:Hide() end
    if frame.start.proposalCancelBtn then frame.start.proposalCancelBtn:Hide() end
end

local function AnchorRunFooterButtons(frame)
    local start = frame.start
    local first

    if start.primaryBtn:IsShown() then
        first = start.primaryBtn
    elseif start.stopBtn:IsShown() then
        first = start.stopBtn
    elseif start.confirmStopBtn and start.confirmStopBtn:IsShown() then
        first = start.confirmStopBtn
    elseif start.applyChangesBtn:IsShown() then
        first = start.applyChangesBtn
    elseif start.proposalAcceptBtn and start.proposalAcceptBtn:IsShown() then
        first = start.proposalAcceptBtn
    elseif start.proposalCancelBtn and start.proposalCancelBtn:IsShown() then
        first = start.proposalCancelBtn
    end

    if not first then return end

    first:ClearAllPoints()
    first:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 32, 24)

    if start.stopBtn:IsShown() and start.stopBtn ~= first then
        start.stopBtn:ClearAllPoints()
        start.stopBtn:SetPoint("LEFT", first, "RIGHT", 8, 0)
    end
    if start.cancelRunBox and start.cancelRunBox:IsShown() then
        start.cancelRunBox:ClearAllPoints()
        start.cancelRunBox:SetPoint("LEFT", first, "RIGHT", 14, -1)
    end
    if start.confirmStopBtn and start.confirmStopBtn:IsShown() and start.confirmStopBtn ~= first then
        start.confirmStopBtn:ClearAllPoints()
        if start.cancelRunBox and start.cancelRunBox:IsShown() then
            start.confirmStopBtn:SetPoint("LEFT", start.cancelRunBox, "RIGHT", 8, 1)
        else
            start.confirmStopBtn:SetPoint("LEFT", first, "RIGHT", 8, 0)
        end
    end
    if start.cancelStopBtn and start.cancelStopBtn:IsShown() then
        start.cancelStopBtn:ClearAllPoints()
        if start.cancelRunBox and start.cancelRunBox:IsShown() then
            start.cancelStopBtn:SetPoint("LEFT", start.cancelRunBox, "RIGHT", 8, 1)
        else
            start.cancelStopBtn:SetPoint("LEFT", start.confirmStopBtn, "RIGHT", 8, 0)
        end
    end
    if start.cancelRunHint and start.cancelRunHint:IsShown() then
        start.cancelRunHint:ClearAllPoints()
        start.cancelRunHint:SetPoint("LEFT", start.cancelStopBtn, "RIGHT", 10, 0)
    end
    if start.modifyBtn:IsShown() then
        start.modifyBtn:ClearAllPoints()
        start.modifyBtn:SetPoint("LEFT", start.stopBtn, "RIGHT", 8, 0)
    end
    if start.syncBtn and start.syncBtn:IsShown() then
        start.syncBtn:ClearAllPoints()
        start.syncBtn:SetPoint("LEFT", start.modifyBtn, "RIGHT", 8, 0)
    end
    if start.inviteBtn and start.inviteBtn:IsShown() then
        start.inviteBtn:ClearAllPoints()
        start.inviteBtn:SetPoint("LEFT", start.syncBtn, "RIGHT", 8, 0)
    end
    if start.applyChangesBtn:IsShown() and start.applyChangesBtn ~= first then
        start.applyChangesBtn:ClearAllPoints()
        start.applyChangesBtn:SetPoint("LEFT", first, "RIGHT", 8, 0)
    end
    if start.cancelChangesBtn:IsShown() then
        start.cancelChangesBtn:ClearAllPoints()
        start.cancelChangesBtn:SetPoint("LEFT", start.applyChangesBtn, "RIGHT", 8, 0)
    end
    if start.proposalDeclineBtn and start.proposalDeclineBtn:IsShown() then
        start.proposalDeclineBtn:ClearAllPoints()
        start.proposalDeclineBtn:SetPoint("LEFT", first, "RIGHT", 8, 0)
    end
end

local function RefreshRunPanel(frame)
    local active = IsActiveRun()
    local db = SC.db or SoftcoreDB
    local modifying = active and frame.start.isModifyingRules
    local rulesConflict = GetPendingRulesConflict()

    -- Amendment panel takes over the whole tab when one is pending
    local pendingAmendment = GetPendingAmendment()
    if pendingAmendment and frame.start.amendmentPanel then
        HideAllRunControls(frame)
        local localKey = SC:GetPlayerKey()
        frame.start.amendmentPanel:Show()
        RefreshAmendmentPanel(frame, pendingAmendment, pendingAmendment.proposedBy == localKey)
        return
    end
    if frame.start.amendmentPanel then
        frame.start.amendmentPanel:Hide()
    end

    -- Pending run proposal: show normal controls (read-only) with Accept/Decline/Cancel buttons
    local pendingProposal = GetPendingRunProposal()
    if pendingProposal then
        local isProposer = pendingProposal.proposedBy == SC:GetPlayerKey()
        local acceptedLocally = pendingProposal.status == "ACCEPTED" and not isProposer
        local proposer = FormatPlayerLabel(pendingProposal.proposedBy)
        CopyRulesInto(frame.start.selectedRules, pendingProposal.ruleset)
        frame.start.groupingDropdown:SetShown(true)
        frame.start.gearDropdown:SetShown(true)
        frame.start.maxGapBox:SetShown(true)
        if frame.start.presetLabel then frame.start.presetLabel:SetShown(false) end
        frame.start.casualBtn:SetShown(false)
        frame.start.ironmanBtn:SetShown(false)
        if frame.start.chefBtn then frame.start.chefBtn:SetShown(false) end
        for _, control in ipairs(frame.start.controls) do control:SetShown(true) end
        SetRunSetupEnabled(frame, false)
        frame.start.inactiveText:SetShown(false)
        frame.start.activeText:SetShown(true)
        if isProposer then
            if pendingProposal.proposalType == "SYNC_RUN" then
                frame.start.activeText:SetText("|cfffbbf24Waiting for party to accept your run sync proposal...|r")
            elseif pendingProposal.proposalType == "ADD_PARTICIPANT" then
                frame.start.activeText:SetText("|cfffbbf24Waiting for party to accept your run invite...|r")
            else
                frame.start.activeText:SetText("|cfffbbf24Waiting for party to accept your run proposal...|r")
            end
        elseif acceptedLocally then
            if pendingProposal.proposalType == "SYNC_RUN" then
                frame.start.activeText:SetText("|cfffbbf24Accepted run sync from " .. proposer .. ".|r Waiting for party confirmation.")
            elseif pendingProposal.proposalType == "ADD_PARTICIPANT" then
                frame.start.activeText:SetText("|cfffbbf24Accepted party run invite from " .. proposer .. ".|r Waiting for party confirmation.")
            else
                frame.start.activeText:SetText("|cfffbbf24Accepted run proposal from " .. proposer .. ".|r Waiting for party confirmation.")
            end
        else
            if pendingProposal.proposalType == "SYNC_RUN" then
                frame.start.activeText:SetText("|cffffd100Run sync proposal from " .. proposer .. ".|r Review the matching rules below, then Accept or Decline.")
            elseif pendingProposal.proposalType == "ADD_PARTICIPANT" then
                frame.start.activeText:SetText("|cffffd100Party run invite from " .. proposer .. ".|r Review the rules below, then Accept or Decline.")
            else
                frame.start.activeText:SetText("|cffffd100Run proposal from " .. proposer .. ".|r Review the proposed rules below, then Accept or Decline.")
            end
        end
        frame.start.primaryBtn:Hide()
        frame.start.stopBtn:Hide()
        if frame.start.confirmStopBtn then frame.start.confirmStopBtn:Hide() end
        if frame.start.cancelStopBtn then frame.start.cancelStopBtn:Hide() end
        frame.start.modifyBtn:Hide()
        if frame.start.syncBtn then frame.start.syncBtn:Hide() end
        if frame.start.inviteBtn then frame.start.inviteBtn:Hide() end
        frame.start.applyChangesBtn:Hide()
        frame.start.cancelChangesBtn:Hide()
        frame.start.proposalAcceptBtn:SetShown((not isProposer) and not acceptedLocally)
        frame.start.proposalDeclineBtn:SetShown((not isProposer) and not acceptedLocally)
        frame.start.proposalCancelBtn:SetShown(isProposer)
        frame.start.proposalAcceptBtn:SetScript("OnClick", function()
            if SC.AcceptPendingProposal then SC:AcceptPendingProposal() end
            SC:MasterUI_Refresh()
        end)
        frame.start.proposalDeclineBtn:SetScript("OnClick", function()
            if SC.DeclinePendingProposal then SC:DeclinePendingProposal() end
            SC:MasterUI_Refresh()
        end)
        frame.start.proposalCancelBtn:SetScript("OnClick", function()
            if SC.CancelPendingProposal then SC:CancelPendingProposal() end
            SC:MasterUI_Refresh()
        end)
        if frame.start.RefreshControls then frame.start:RefreshControls() end
        AnchorRunFooterButtons(frame)
        return
    end

    frame.start.inactiveText:SetShown(not active)
    frame.start.activeText:SetShown(active)

    if active and db and db.run and db.run.ruleset and not modifying then
        CopyRulesInto(frame.start.selectedRules, db.run.ruleset)
        frame.start.selectedCameraMode = nil
    elseif not frame.start.selectedRules then
        frame.start.selectedRules = SC:GetDefaultRuleset()
    end

    frame.start.groupingDropdown:SetShown(true)
    frame.start.gearDropdown:SetShown(true)
    frame.start.maxGapBox:SetShown(true)
    if frame.start.presetLabel then frame.start.presetLabel:SetShown(true) end
    frame.start.casualBtn:SetShown(true)
    frame.start.ironmanBtn:SetShown(true)
    if frame.start.chefBtn then frame.start.chefBtn:SetShown(true) end
    for _, control in ipairs(frame.start.controls) do
        control:SetShown(true)
    end
    frame.start.primaryBtn:SetShown(not active)
    local confirmingStop = active and frame.start.stopConfirmPending
    local stopReady = confirmingStop and frame.start.cancelRunBox and string.lower(strtrim(frame.start.cancelRunBox:GetText() or "")) == "end run"
    if not active then
        frame.start.stopConfirmPending = false
        if frame.start.cancelRunBox then
            frame.start.cancelRunBox:SetText("")
            frame.start.cancelRunBox:Hide()
        end
    end
    frame.start.stopBtn:SetShown(active and not modifying and not confirmingStop)
    if frame.start.confirmStopBtn then
        frame.start.confirmStopBtn:SetShown(confirmingStop)
        frame.start.confirmStopBtn:SetEnabled(stopReady)
    end
    if frame.start.cancelStopBtn then
        frame.start.cancelStopBtn:SetShown(confirmingStop)
        frame.start.cancelStopBtn:SetEnabled(true)
    end
    if frame.start.cancelRunBox then
        frame.start.cancelRunBox:SetShown(confirmingStop)
        if confirmingStop then
            frame.start.cancelRunBox:Enable()
        else
            frame.start.cancelRunBox:Disable()
        end
    end
    if frame.start.cancelRunHint then
        frame.start.cancelRunHint:SetShown(confirmingStop)
    end
    frame.start.modifyBtn:SetShown(active and not modifying and not confirmingStop)
    if frame.start.syncBtn then
        frame.start.syncBtn:SetShown(active and not modifying and not confirmingStop and IsInGroup())
    end
    if frame.start.inviteBtn then
        frame.start.inviteBtn:SetShown(active and not modifying and not confirmingStop and IsInGroup())
    end
    frame.start.applyChangesBtn:SetShown(modifying)
    frame.start.cancelChangesBtn:SetShown(modifying)
    SetRunSetupEnabled(frame, (not active) or modifying)
    if active and not modifying then
        frame.start.casualBtn:SetEnabled(false)
        frame.start.ironmanBtn:SetEnabled(false)
        if frame.start.chefBtn then frame.start.chefBtn:SetEnabled(false) end
    end

    if active then
        if modifying then
            if IsInGroup() then
                frame.start.applyChangesBtn:SetText("Propose to Party")
                frame.start.activeText:SetText("Draft rule amendment. This will be sent to all party members for approval.")
            else
                frame.start.applyChangesBtn:SetText("Apply Changes")
                frame.start.activeText:SetText("Draft rule amendment. Changes apply going forward and will be logged.")
            end
        else
            if confirmingStop then
                frame.start.activeText:SetText("|cfffbbf24End run requested.|r This will reset local run progress.")
            elseif rulesConflict then
                frame.start.activeText:SetText("|cfffbbf24Rules conflict detected with " .. FormatPlayerLabel(rulesConflict.playerKey) .. ".|r Use Propose Sync only when everyone has intentionally aligned rules.")
            else
                frame.start.activeText:SetText("Active run rules are locked. Camera mode can be switched anytime without a rule amendment.")
            end
        end
    end

    if frame.start.RefreshControls then
        frame.start:RefreshControls()
    end
    AnchorRunFooterButtons(frame)
end

local function RefreshViolationsPanel(frame)
    local violations = GetSortedActiveViolations()

    frame.violations.empty:SetShown(#violations == 0)
    if frame.violations.scroll then
        FauxScrollFrame_Update(frame.violations.scroll, #violations, VIOLATION_ROWS, VIOLATION_ROW_HEIGHT)
    end

    local offset = frame.violations.scroll and FauxScrollFrame_GetOffset(frame.violations.scroll) or 0
    for rowIndex, row in ipairs(frame.violations.rows) do
        local violation = violations[offset + rowIndex]

        if violation then
            row:Show()
            row.time:SetText(Trunc(FormatTime(violation.createdAt), 19))
            row.owner:SetText(Trunc(FormatPlayerLabel(violation.playerKey), 16))
            row.type:SetText(Trunc(FormatViolationLogLabel(violation.type), 18))
            SetCompactText(row.detail, FormatViolationDetail(violation), 38)

            if SC:IsViolationClearable(violation) then
                local violationId = violation.id
                row.clearBtn:Show()
                row.clearBtn:SetScript("OnClick", function()
                    SC:ClearViolation(violationId, SC:GetPlayerKey())
                    Print("violation cleared.")
                    SC:MasterUI_Refresh()
                end)
            else
                row.clearBtn:Hide()
                row.clearBtn:SetScript("OnClick", nil)
            end
        else
            row:Hide()
            row.clearBtn:SetScript("OnClick", nil)
        end
    end
end

local function RefreshLogPanel(frame)
    local db = SC.db or SoftcoreDB
    local log = (db and db.eventLog) or {}
    local entries = GetVisibleLogEntries(log)

    if #entries == 0 then
        frame.log.empty:Show()
        for _, row in ipairs(frame.log.rows) do
            row:Hide()
        end
        if frame.log.scroll then
            FauxScrollFrame_Update(frame.log.scroll, 0, LOG_ROWS, LOG_ROW_HEIGHT)
        end
        return
    end

    frame.log.empty:Hide()
    if frame.log.scroll then
        FauxScrollFrame_Update(frame.log.scroll, #entries, LOG_ROWS, LOG_ROW_HEIGHT)
    end

    local offset = frame.log.scroll and FauxScrollFrame_GetOffset(frame.log.scroll) or 0
    for rowIndex, row in ipairs(frame.log.rows) do
        local entry = entries[offset + rowIndex]

        if entry then
            local eventLabel, eventColor = FormatLogEvent(entry)

            row:Show()
            row.time:SetText(FormatTime(entry.time))
            row.actor:SetText(Trunc(FormatPlayerLabel(entry.actorKey or entry.playerKey), 16))
            row.kind:SetText(Trunc(eventLabel, 18))
            row.kind:SetTextColor(eventColor.r, eventColor.g, eventColor.b)
            SetCompactText(row.message, FormatLogMessage(entry), 52)
        else
            row:Hide()
        end
    end
end

local function CreateAchievementRow(parent, index)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetSize(628, 74)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * 82))
    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    row:SetBackdropColor(0.11, 0.075, 0.035, 0.92)
    row:SetBackdropBorderColor(0.58, 0.42, 0.18, 0.72)

    row.medal = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.medal:SetSize(46, 46)
    row.medal:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -12)
    row.medal:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    row.medal:SetBackdropColor(0.25, 0.18, 0.08, 1)
    row.medal:SetBackdropBorderColor(0.76, 0.58, 0.18, 1)
    row.icon = row.medal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.icon:SetPoint("CENTER", row.medal, "CENTER", 0, 0)
    row.icon:SetWidth(42)
    row.icon:SetJustifyH("CENTER")
    row.icon:SetText("?")
    row.iconCheck = row.medal:CreateTexture(nil, "OVERLAY")
    row.iconCheck:SetSize(32, 32)
    row.iconCheck:SetPoint("CENTER", row.medal, "CENTER", 0, 0)
    row.iconCheck:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    row.iconCheck:Hide()

    row.name = CreateField(row, 70, -10, 340)
    row.name:SetFontObject(GameFontNormal)
    row.date = CreateField(row, 424, -12, 190)
    row.date:SetJustifyH("RIGHT")
    row.description = CreateField(row, 70, -32, 530)
    row.description:SetFontObject(GameFontHighlightSmall)
    row.progress = CreateFrame("StatusBar", nil, row)
    row.progress:SetSize(300, 10)
    row.progress:SetPoint("TOPLEFT", row, "TOPLEFT", 70, -56)
    row.progress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.progress:SetMinMaxValues(0, 1)
    row.progressBg = row.progress:CreateTexture(nil, "BACKGROUND")
    row.progressBg:SetAllPoints(row.progress)
    row.progressBg:SetColorTexture(0.05, 0.04, 0.025, 0.95)
    row.progressText = CreateField(row, 378, -52, 234)
    row.progressText:SetFontObject(GameFontHighlightSmall)

    return row
end

local function RefreshAchievementsPanel(frame)
    if not frame.achievements then return end

    local rows = SC.GetAchievementRows and SC:GetAchievementRows() or {}
    local earnedCount = 0

    for _, row in ipairs(rows) do
        if row.earned then
            earnedCount = earnedCount + 1
        end
    end

    frame.achievements.summary:SetText("Earned: " .. tostring(earnedCount) .. " / " .. tostring(#rows))

    if #rows == 0 then
        frame.achievements.empty:Show()
    else
        frame.achievements.empty:Hide()
    end

    for index = #frame.achievements.rows + 1, #rows do
        frame.achievements.rows[index] = CreateAchievementRow(frame.achievements.content, index)
    end

    local contentHeight = math.max(408, (#rows * 82) + 12)
    frame.achievements.content:SetSize(628, contentHeight)

    for index, rowFrame in ipairs(frame.achievements.rows) do
        local achievement = rows[index]
        if achievement then
            rowFrame:Show()
            local progressValue = tonumber(achievement.progressValue or 0) or 0
            if achievement.earned then
                rowFrame.icon:SetText("")
                rowFrame.iconCheck:Show()
            elseif progressValue > 0 then
                rowFrame.iconCheck:Hide()
                rowFrame.icon:SetText("|cffffffff" .. tostring(math.floor((progressValue * 100) + 0.5)) .. "%|r")
            else
                rowFrame.iconCheck:Hide()
                rowFrame.icon:SetText("|cff6b7280?|r")
            end
            rowFrame.name:SetText((achievement.earned and "|cffffd100" or "|cffad8f61") .. tostring(achievement.name or "?") .. "|r")
            rowFrame.description:SetText(Trunc(achievement.description or "", 100))
            if achievement.earnedAt then
                rowFrame.date:SetText("|cff4ade80" .. FormatTime(achievement.earnedAt) .. "|r")
                rowFrame.progress:SetValue(1)
                rowFrame.progress:SetStatusBarColor(0.86, 0.62, 0.16, 1)
                rowFrame.progressText:SetText("|cff4ade80Complete|r")
                rowFrame:SetBackdropColor(0.18, 0.12, 0.045, 0.96)
                rowFrame:SetBackdropBorderColor(0.86, 0.62, 0.16, 0.92)
                rowFrame.medal:SetBackdropColor(0.42, 0.30, 0.07, 1)
                rowFrame.medal:SetBackdropBorderColor(1.0, 0.82, 0.20, 1)
            else
                rowFrame.date:SetText("")
                rowFrame.progress:SetValue(progressValue)
                if progressValue > 0 then
                    rowFrame.progress:SetStatusBarColor(0.22, 0.56, 0.88, 1)
                else
                    rowFrame.progress:SetStatusBarColor(0.34, 0.28, 0.18, 1)
                end
                rowFrame.progressText:SetText("|cffd6c29a" .. tostring(achievement.progressText or "Not earned") .. "|r")
                rowFrame:SetBackdropColor(0.10, 0.075, 0.04, 0.9)
                rowFrame:SetBackdropBorderColor(0.46, 0.36, 0.18, 0.62)
                rowFrame.medal:SetBackdropColor(0.13, 0.12, 0.10, 1)
                rowFrame.medal:SetBackdropBorderColor(0.42, 0.36, 0.26, 0.9)
            end
        else
            rowFrame:Hide()
        end
    end
end

local function ConfirmStopRun()
    SC:ResetRun()
    if SC.masterFrame then
        if SC.masterFrame.start then
            SC.masterFrame.start.stopConfirmPending = false
            if SC.masterFrame.start.cancelRunBox then
                SC.masterFrame.start.cancelRunBox:SetText("")
                SC.masterFrame.start.cancelRunBox:ClearFocus()
            end
        end
        SC.masterFrame.activeTab = TAB_RUN
        SC:MasterUI_Refresh()
    end
end

local function ArmStopRunConfirmation(frame)
    local start = frame and frame.start
    if not start then return end

    start.stopConfirmPending = true
    if start.cancelRunBox then
        start.cancelRunBox:SetText("")
        start.cancelRunBox:SetFocus()
    end
    SC:MasterUI_Refresh()
end

local function CancelStopRunConfirmation(frame)
    local start = frame and frame.start
    if not start then return end

    start.stopConfirmPending = false
    if start.cancelRunBox then
        start.cancelRunBox:SetText("")
        start.cancelRunBox:ClearFocus()
    end
    SC:MasterUI_Refresh()
end

function SC:ConfirmStopRun()
    ConfirmStopRun()
end

function SC:MasterUI_Refresh()
    local frame = self.masterFrame
    if not frame or not frame:IsShown() then return end

    frame.activeTab = NormalizeTab(frame.activeTab)

    for tabName, panel in pairs(frame.panels) do
        panel:SetShown(tabName == frame.activeTab)
    end

    local function SetTabSelected(tab, selected)
        tab:SetEnabled(true)
        if selected then
            tab:LockHighlight()
        else
            tab:UnlockHighlight()
        end
    end

    SetTabSelected(frame.overviewTab, frame.activeTab == TAB_OVERVIEW)
    SetTabSelected(frame.runTab, frame.activeTab == TAB_RUN)
    SetTabSelected(frame.violationsTab, frame.activeTab == TAB_VIOLATIONS)
    SetTabSelected(frame.logTab, frame.activeTab == TAB_LOG)
    SetTabSelected(frame.achievementsTab, frame.activeTab == TAB_ACHIEVEMENTS)

    RefreshOverviewPanel(frame)
    RefreshRunPanel(frame)
    RefreshViolationsPanel(frame)
    RefreshLogPanel(frame)
    RefreshAchievementsPanel(frame)

    if SC.HUD_Refresh then
        SC:HUD_Refresh()
    end
end

function SC:ToggleMasterWindow()
    if self.masterFrame and self.masterFrame:IsShown() then
        self.masterFrame:Hide()
    else
        self:OpenMasterWindow()
    end
end

function SC:OpenMasterWindow(focusTab)
    if self.masterFrame then
        self.masterFrame:Show()
        self.masterFrame.activeTab = NormalizeTab(focusTab or self.masterFrame.activeTab)
        self:MasterUI_Refresh()
        return
    end

    local frame = CreateFrame("Frame", "SoftcoreMasterFrame", UIParent, "BackdropTemplate")
    frame:SetSize(760, 658)
    RestorePosition("master", frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        SavePosition("master", f)
    end)
    if UISpecialFrames then
        table.insert(UISpecialFrames, "SoftcoreMasterFrame")
    end
    ApplyParchmentBackdrop(frame)

    local headerSep = frame:CreateTexture(nil, "ARTWORK")
    headerSep:SetHeight(1)
    headerSep:SetPoint("TOPLEFT",  frame, "TOPLEFT",  22, -64)
    headerSep:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -64)
    headerSep:SetColorTexture(0.78, 0.55, 0.20, 0.75)

    frame.activeTab = NormalizeTab(focusTab)
    frame.panels = {}

    local logo = frame:CreateTexture(nil, "ARTWORK")
    logo:SetSize(40, 40)
    logo:SetPoint("TOPLEFT", frame, "TOPLEFT", 26, -15)
    logo:SetTexture(MENU_LOGO_TEXTURE)
    logo:SetTexCoord(0, 1, 0, 1)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -10)
    title:SetTextColor(GOLD_TEXT.r, GOLD_TEXT.g, GOLD_TEXT.b)
    title:SetText("|cffffd700Softcore|r")

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    subtitle:SetTextColor(MUTED_TEXT.r, MUTED_TEXT.g, MUTED_TEXT.b)
    subtitle:SetText("Hardcore-style run ledger for group accountability")

    local closeBtn = CreateFrame("Button", "SoftcoreMasterCloseButton", frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    local function AddTab(fieldName, label, tabName, relativeTo, width)
        local tab = CreateButton(frame, label, width or 92, 24)
        if relativeTo then
            tab:SetPoint("LEFT", relativeTo, "RIGHT", 6, 0)
        else
            tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -72)
        end
        tab:SetScript("OnClick", function()
            frame.activeTab = tabName
            SC:MasterUI_Refresh()
        end)
        frame[fieldName] = tab
        return tab
    end

    local overviewTab = AddTab("overviewTab", "Overview", TAB_OVERVIEW)
    local runTab = AddTab("runTab", "Run", TAB_RUN, overviewTab)
    local violationsTab = AddTab("violationsTab", "Violations", TAB_VIOLATIONS, runTab)
    local logTab = AddTab("logTab", "Log", TAB_LOG, violationsTab)
    AddTab("achievementsTab", "Achievements", TAB_ACHIEVEMENTS, logTab, 110)

    local startPanel = CreatePanel(frame)
    startPanel:SetHeight(490)
    frame.panels[TAB_RUN] = startPanel
    frame.start = { controls = {}, selectedRules = SC:GetDefaultRuleset(), selectedPreset = "CASUAL" }
    frame.start.selectedRules.dungeonRepeat = "ALLOWED"
    frame.start.selectedRules.instanceWithUnsyncedPlayers = "ALLOWED"
    frame.start.selectedRules.unsyncedMembers = "ALLOWED"
    frame.start.inactiveText = CreateField(startPanel, 0, 0, 620)
    frame.start.inactiveText:SetText("Choose a ruleset, review the rules, then start your run.")
    frame.start.activeText = CreateField(startPanel, 0, 0, 620)
    frame.start.activeText:SetText("Active run rules are locked. Future rule changes will use a visible amendment flow.")

    frame.start.presetLabel = CreateLabel(startPanel, "Presets", 0, -30, "GameFontNormalSmall", 60)
    frame.start.presetLabel:SetTextColor(BODY_TEXT.r, BODY_TEXT.g, BODY_TEXT.b)
    frame.start.casualBtn = CreateButton(startPanel, "Casual", 86, 22)
    frame.start.casualBtn:SetPoint("TOPLEFT", startPanel, "TOPLEFT", 58, -24)
    frame.start.casualBtn:SetScript("OnClick", function()
        ApplyStartPreset(frame, "CASUAL")
    end)

    frame.start.chefBtn = CreateButton(startPanel, "Chef's Special", 116, 22)
    frame.start.chefBtn:SetPoint("LEFT", frame.start.casualBtn, "RIGHT", 8, 0)
    frame.start.chefBtn:SetScript("OnClick", function()
        ApplyStartPreset(frame, "CHEF_SPECIAL")
    end)

    frame.start.ironmanBtn = CreateButton(startPanel, "Ironman", 86, 22)
    frame.start.ironmanBtn:SetPoint("LEFT", frame.start.chefBtn, "RIGHT", 8, 0)
    frame.start.ironmanBtn:SetScript("OnClick", function()
        ApplyStartPreset(frame, "IRONMAN")
    end)

    table.insert(frame.start.controls, CreateSectionHeader(startPanel, "Core Rules", 0, -62, 300))
    table.insert(frame.start.controls, CreateLabel(startPanel, "Death is permanent. A death fails this character only.", 0, -92, "GameFontHighlightSmall", 320))
    table.insert(frame.start.controls, CreateLabel(startPanel, "Mode", 0, -128, "GameFontNormalSmall", 70))
    frame.start.groupingDropdown = CreateDropdown(startPanel, "SoftcoreMasterGroupingDropdown", GROUPING_OPTIONS, frame.start.selectedRules.groupingMode, function(value)
        frame.start.selectedRules.groupingMode = value
        if SC.ApplyGroupingMode then
            SC:ApplyGroupingMode(frame.start.selectedRules)
        end
        SC:MasterUI_Refresh()
    end, 140)
    frame.start.groupingDropdown:SetPoint("TOPLEFT", startPanel, "TOPLEFT", 82, -120)

    table.insert(frame.start.controls, CreateSectionHeader(startPanel, "Economy and Storage", 0, -178, 300))
    local y = -208
    for _, spec in ipairs(ECONOMY_RULES) do
        local checkbox = CreateAllowCheckbox(startPanel, frame.start.selectedRules, spec, 0, y)
        table.insert(frame.start.controls, checkbox)
        y = y - 30
    end

    table.insert(frame.start.controls, CreateSectionHeader(startPanel, "Movement", 360, -62, 300))
    y = -92
    for _, spec in ipairs(MOVEMENT_RULES) do
        local checkbox = CreateAllowCheckbox(startPanel, frame.start.selectedRules, spec, 360, y)
        table.insert(frame.start.controls, checkbox)
        if spec.key == "flying" then
            local hint = startPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            hint:SetPoint("LEFT", checkbox.label, "LEFT", 124, 0)
            hint:SetTextColor(MUTED_TEXT.r * 0.7, MUTED_TEXT.g * 0.7, MUTED_TEXT.b * 0.7)
            hint:SetText("incl. druid flight form")
            table.insert(frame.start.controls, hint)
        end
        y = y - 30
    end

    table.insert(frame.start.controls, CreateSectionHeader(startPanel, "Gear and Items", 360, -188, 300))
    table.insert(frame.start.controls, CreateLabel(startPanel, "Gear limit", 360, -218, "GameFontNormalSmall", 82))
    frame.start.gearDropdown = CreateDropdown(startPanel, "SoftcoreMasterGearDropdown", GEAR_OPTIONS, frame.start.selectedRules.gearQuality, function(value)
        frame.start.selectedRules.gearQuality = value
        SC:MasterUI_Refresh()
    end, 145)
    frame.start.gearDropdown:SetPoint("TOPLEFT", startPanel, "TOPLEFT", 452, -210)
    frame.start.heirloomCheck = CreateAllowCheckbox(startPanel, frame.start.selectedRules, { label = "Allow Heirlooms", key = "heirlooms" }, 360, -252)
    table.insert(frame.start.controls, frame.start.heirloomCheck)
    frame.start.consumablesCheck = CreateAllowCheckbox(startPanel, frame.start.selectedRules, { label = "Allow Consumables", key = "consumables" }, 360, -282)
    table.insert(frame.start.controls, frame.start.consumablesCheck)

    table.insert(frame.start.controls, CreateSectionHeader(startPanel, "Group and Dungeon", 360, -322, 300))
    frame.start.maxGapCheck = CreateFrame("CheckButton", nil, startPanel, "UICheckButtonTemplate")
    frame.start.maxGapCheck:SetPoint("TOPLEFT", startPanel, "TOPLEFT", 360, -352)
    frame.start.maxGapCheck.label = frame.start.maxGapCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.start.maxGapCheck.label:SetPoint("LEFT", frame.start.maxGapCheck, "RIGHT", 2, 0)
    frame.start.maxGapCheck.label:SetTextColor(BODY_TEXT.r, BODY_TEXT.g, BODY_TEXT.b)
    frame.start.maxGapCheck.label:SetText("Enforce Level Gap")
    frame.start.maxGapCheck:SetScript("OnClick", function(self)
        frame.start.selectedRules.maxLevelGap = self:GetChecked() and DISALLOWED_OUTCOME or "ALLOWED"
        SC:MasterUI_Refresh()
    end)
    table.insert(frame.start.controls, frame.start.maxGapCheck)
    frame.start.maxGapLabel = CreateLabel(startPanel, "Max gap", 388, -388, "GameFontNormalSmall", 70)
    table.insert(frame.start.controls, frame.start.maxGapLabel)
    frame.start.maxGapBox = CreateFrame("EditBox", nil, startPanel, "InputBoxTemplate")
    frame.start.maxGapBox:SetSize(42, 22)
    frame.start.maxGapBox:SetPoint("TOPLEFT", startPanel, "TOPLEFT", 460, -382)
    frame.start.maxGapBox:SetAutoFocus(false)
    frame.start.maxGapBox:SetNumeric(true)
    frame.start.maxGapBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value then
            frame.start.selectedRules.maxLevelGapValue = value
        end
    end)
    frame.start.maxGapBox:SetScript("OnEditFocusLost", function()
        SC:MasterUI_Refresh()
    end)
    frame.start.dungeonRepeatCheck = CreateAllowCheckbox(startPanel, frame.start.selectedRules, { label = "Allow Repeated Dungeons", key = "dungeonRepeat" }, 360, -420)
    table.insert(frame.start.controls, frame.start.dungeonRepeatCheck)
    frame.start.instancedPvPCheck = CreateAllowCheckbox(startPanel, frame.start.selectedRules, { label = "Allow Instanced PvP", key = "instancedPvP" }, 360, -450)
    table.insert(frame.start.controls, frame.start.instancedPvPCheck)

    table.insert(frame.start.controls, CreateSectionHeader(startPanel, "Camera", 0, -398, 300))
    frame.start.cameraHint = startPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.start.cameraHint:SetPoint("TOPLEFT", startPanel, "TOPLEFT", 70, -398)
    frame.start.cameraHint:SetTextColor(MUTED_TEXT.r * 0.7, MUTED_TEXT.g * 0.7, MUTED_TEXT.b * 0.7)
    frame.start.cameraHint:SetText("Mode can be switched anytime during a run.")
    table.insert(frame.start.controls, frame.start.cameraHint)
    frame.start.firstPersonCheck = CreateFrame("CheckButton", nil, startPanel, "UICheckButtonTemplate")
    frame.start.firstPersonCheck:SetPoint("TOPLEFT", startPanel, "TOPLEFT", 0, -428)
    frame.start.firstPersonCheck.label = frame.start.firstPersonCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.start.firstPersonCheck.label:SetPoint("LEFT", frame.start.firstPersonCheck, "RIGHT", 2, 0)
    frame.start.firstPersonCheck.label:SetWidth(280)
    frame.start.firstPersonCheck.label:SetJustifyH("LEFT")
    frame.start.firstPersonCheck.label:SetTextColor(BODY_TEXT.r, BODY_TEXT.g, BODY_TEXT.b)
    frame.start.firstPersonCheck.label:SetText("Use First Person Camera")
    frame.start.firstPersonCheck.ruleKey = "firstPersonOnly"
    frame.start.firstPersonCheck:SetScript("OnClick", function(btn)
        if IsActiveRun() and not frame.start.isModifyingRules then
            if btn:GetChecked() and SC.SetCameraMode then
                SC:SetCameraMode("FIRST_PERSON")
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    ClearCameraCheckboxVisuals(frame.start)
                end)
            else
                ClearCameraCheckboxVisuals(frame.start)
            end
            SC:MasterUI_Refresh()
            return
        end
        frame.start.selectedCameraMode = btn:GetChecked() and "FIRST_PERSON" or nil
        SetCameraRules(frame.start.selectedRules, frame.start.selectedCameraMode)
        SC:MasterUI_Refresh()
    end)
    table.insert(frame.start.controls, frame.start.firstPersonCheck)

    frame.start.actionCamCheck = CreateFrame("CheckButton", nil, startPanel, "UICheckButtonTemplate")
    frame.start.actionCamCheck:SetPoint("TOPLEFT", startPanel, "TOPLEFT", 0, -458)
    frame.start.actionCamCheck.label = frame.start.actionCamCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.start.actionCamCheck.label:SetPoint("LEFT", frame.start.actionCamCheck, "RIGHT", 2, 0)
    frame.start.actionCamCheck.label:SetWidth(280)
    frame.start.actionCamCheck.label:SetJustifyH("LEFT")
    frame.start.actionCamCheck.label:SetTextColor(BODY_TEXT.r, BODY_TEXT.g, BODY_TEXT.b)
    frame.start.actionCamCheck.label:SetText("Use Cinematic Camera")
    frame.start.actionCamCheck.ruleKey = "actionCam"
    frame.start.actionCamCheck:SetScript("OnClick", function(btn)
        if IsActiveRun() and not frame.start.isModifyingRules then
            if btn:GetChecked() and SC.SetCameraMode then
                SC:SetCameraMode("CINEMATIC")
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    ClearCameraCheckboxVisuals(frame.start)
                end)
            else
                ClearCameraCheckboxVisuals(frame.start)
            end
            SC:MasterUI_Refresh()
            return
        end
        frame.start.selectedCameraMode = btn:GetChecked() and "CINEMATIC" or nil
        SetCameraRules(frame.start.selectedRules, frame.start.selectedCameraMode)
        SC:MasterUI_Refresh()
    end)
    table.insert(frame.start.controls, frame.start.actionCamCheck)

    function frame.start:RefreshControls()
        if SC.ApplyGroupingMode then
            SC:ApplyGroupingMode(self.selectedRules)
        end
        self.selectedRules.instanceWithUnsyncedPlayers = "ALLOWED"
        self.selectedRules.unsyncedMembers = "ALLOWED"

        UIDropDownMenu_SetText(self.groupingDropdown, GetOptionText(GROUPING_OPTIONS, self.selectedRules.groupingMode))
        UIDropDownMenu_SetText(self.gearDropdown, GetOptionText(GEAR_OPTIONS, self.selectedRules.gearQuality))
        local isSolo = self.selectedRules.groupingMode == "SOLO_SELF_FOUND"
        if isSolo then
            self.selectedRules.maxLevelGap = "ALLOWED"
        end
        local canEdit = not IsActiveRun() or self.isModifyingRules
        self.maxGapCheck:SetChecked(not isSolo and self.selectedRules.maxLevelGap ~= "ALLOWED")
        self.maxGapCheck:SetEnabled(canEdit and not isSolo)
        local locked = not canEdit or isSolo
        self.maxGapCheck.label:SetFontObject(GameFontNormalSmall)
        if locked then
            SetFontStringRGB(self.maxGapCheck.label, BODY_TEXT)
        elseif self.isModifyingRules and self.draftBaseRules then
            local baseVal = self.draftBaseRules.maxLevelGap
            local curVal = self.selectedRules.maxLevelGap
            if tostring(baseVal) ~= tostring(curVal) then
                local checked = IsCheckedRuleValue("maxLevelGap", curVal)
                SetFontStringRGB(self.maxGapCheck.label, checked == false and RED_TEXT or GREEN_TEXT)
            else
                SetFontStringRGB(self.maxGapCheck.label, BODY_TEXT)
            end
        else
            SetFontStringRGB(self.maxGapCheck.label, BODY_TEXT)
        end
        if not canEdit or isSolo then self.maxGapBox:Disable() end
        self.maxGapBox:SetText(tostring(self.selectedRules.maxLevelGapValue or 3))
        if self.maxGapLabel then
            if locked then
                SetFontStringRGB(self.maxGapLabel, BODY_TEXT)
            elseif self.isModifyingRules and self.draftBaseRules then
                local baseVal = self.draftBaseRules.maxLevelGapValue
                local curVal  = self.selectedRules.maxLevelGapValue
                if tostring(baseVal) ~= tostring(curVal) then
                    SetFontStringRGB(self.maxGapLabel, GREEN_TEXT)
                else
                    SetFontStringRGB(self.maxGapLabel, BODY_TEXT)
                end
            else
                SetFontStringRGB(self.maxGapLabel, BODY_TEXT)
            end
        end

        for _, checkbox in ipairs(self.controls) do
            if checkbox.label and checkbox.GetChecked and checkbox ~= self.maxGapCheck then
                local text = checkbox.label:GetText()
                for _, spec in ipairs(ECONOMY_RULES) do
                    if text == spec.label then checkbox:SetChecked(not IsDisallowed(self.selectedRules[spec.key])) end
                end
                for _, spec in ipairs(MOVEMENT_RULES) do
                    if text == spec.label then checkbox:SetChecked(not IsDisallowed(self.selectedRules[spec.key])) end
                end
                if self.isModifyingRules and self.draftBaseRules and checkbox.ruleKey then
                    local baseVal = self.draftBaseRules[checkbox.ruleKey]
                    local curVal = self.selectedRules[checkbox.ruleKey]
                    if tostring(baseVal) ~= tostring(curVal) then
                        local checked = IsCheckedRuleValue(checkbox.ruleKey, curVal)
                        SetFontStringRGB(checkbox.label, checked == false and RED_TEXT or GREEN_TEXT)
                    else
                        SetFontStringRGB(checkbox.label, BODY_TEXT)
                    end
                else
                    SetFontStringRGB(checkbox.label, BODY_TEXT)
                end
            end
        end
        self.heirloomCheck:SetChecked(not IsDisallowed(self.selectedRules.heirlooms))
        self.dungeonRepeatCheck:SetChecked(not IsDisallowed(self.selectedRules.dungeonRepeat))
        self.consumablesCheck:SetChecked(not IsDisallowed(self.selectedRules.consumables))
        self.instancedPvPCheck:SetChecked(not IsDisallowed(self.selectedRules.instancedPvP))
        local active = IsActiveRun()
        local editingCamera = (not active) or self.isModifyingRules
        local cameraRequired = active and (not self.isModifyingRules) and SC.IsCameraModeRequired and SC:IsCameraModeRequired()
        local cameraMode = editingCamera and GetSelectedCameraMode(self) or (SC.GetCameraMode and SC:GetCameraMode())
        local cameraAvailable = editingCamera or cameraRequired
        self.firstPersonCheck:SetChecked((cameraRequired or IsCameraRuleEnforced(self.selectedRules)) and cameraMode == "FIRST_PERSON")
        self.actionCamCheck:SetChecked((cameraRequired or IsCameraRuleEnforced(self.selectedRules)) and cameraMode == "CINEMATIC")
        ClearCameraCheckboxVisuals(self)
        self.firstPersonCheck:SetEnabled(cameraAvailable)
        self.actionCamCheck:SetEnabled(cameraAvailable)
        SetFontStringRGB(self.firstPersonCheck.label, BODY_TEXT)
        SetFontStringRGB(self.actionCamCheck.label, BODY_TEXT)
        self.selectedRules.maxDeaths = false
        self.selectedRules.maxDeathsValue = self.selectedRules.maxDeathsValue or 3
    end

    frame.start.primaryBtn = CreateButton(startPanel, "Start Run", 120, 24)
    frame.start.primaryBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 30, 18)
    frame.start.primaryBtn:SetScript("OnClick", function()
        local ruleset = SC:CopyTable(frame.start.selectedRules)
        if SC.ApplyGroupingMode then
            SC:ApplyGroupingMode(ruleset)
        end
        ruleset.instanceWithUnsyncedPlayers = "ALLOWED"
        ruleset.unsyncedMembers = "ALLOWED"
        ruleset.achievementPreset = frame.start.selectedPreset or ruleset.achievementPreset or "CUSTOM"
        if IsInGroup() then
            if SC.CreateRunProposal then
                SC:CreateRunProposal("Softcore Run", ruleset, "RUN")
            else
                Print("proposal handling is not loaded.")
            end
        else
            SC:StartRun({
                runName = "Softcore Run",
                ruleset = ruleset,
                preset = ruleset.achievementPreset,
                cameraMode = frame.start.selectedCameraMode,
            })
            frame.activeTab = TAB_OVERVIEW
        end
        SC:MasterUI_Refresh()
    end)
    ApplyStartPreset(frame, "CASUAL")
    frame.start.stopBtn = CreateButton(startPanel, "End Run", 100, 24)
    frame.start.stopBtn:SetPoint("LEFT", frame.start.primaryBtn, "RIGHT", 8, 0)
    frame.start.stopBtn:SetScript("OnClick", function()
        ArmStopRunConfirmation(frame)
    end)
    frame.start.confirmStopBtn = CreateButton(startPanel, "Confirm End", 110, 24)
    frame.start.confirmStopBtn:SetPoint("LEFT", frame.start.stopBtn, "RIGHT", 8, 0)
    frame.start.confirmStopBtn:SetScript("OnClick", ConfirmStopRun)
    frame.start.cancelRunHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.start.cancelRunHint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 32, 52)
    frame.start.cancelRunHint:SetTextColor(MUTED_TEXT.r * 0.7, MUTED_TEXT.g * 0.7, MUTED_TEXT.b * 0.7)
    frame.start.cancelRunHint:SetText("Type \"end run\" to enable Confirm End.")
    frame.start.cancelRunBox = CreateFrame("EditBox", nil, startPanel, "InputBoxTemplate")
    frame.start.cancelRunBox:SetSize(70, 22)
    frame.start.cancelRunBox:SetAutoFocus(false)
    frame.start.cancelRunBox:SetScript("OnTextChanged", function()
        SC:MasterUI_Refresh()
    end)
    frame.start.cancelRunBox:SetScript("OnEnterPressed", function(self)
        if string.lower(strtrim(self:GetText() or "")) == "end run" then
            ConfirmStopRun()
        end
    end)
    frame.start.cancelStopBtn = CreateButton(startPanel, "Cancel", 80, 24)
    frame.start.cancelStopBtn:SetPoint("LEFT", frame.start.confirmStopBtn, "RIGHT", 8, 0)
    frame.start.cancelStopBtn:SetScript("OnClick", function()
        CancelStopRunConfirmation(frame)
    end)
    frame.start.modifyBtn = CreateButton(startPanel, "Modify Rules", 110, 24)
    frame.start.modifyBtn:SetPoint("LEFT", frame.start.stopBtn, "RIGHT", 8, 0)
    frame.start.modifyBtn:SetScript("OnClick", function()
        local db = SC.db or SoftcoreDB
        if not db or not db.run or not db.run.ruleset then return end

        frame.start.stopConfirmPending = false
        frame.start.stopConfirmReadyAt = nil
        frame.start.isModifyingRules = true
        frame.start.draftBaseRules = SC:CopyTable(db.run.ruleset)
        CopyRulesInto(frame.start.selectedRules, db.run.ruleset)
        frame.start.selectedCameraMode = nil
        SC:MasterUI_Refresh()
    end)
    frame.start.syncBtn = CreateButton(startPanel, "Propose Sync", 110, 24)
    frame.start.syncBtn:SetPoint("LEFT", frame.start.modifyBtn, "RIGHT", 8, 0)
    frame.start.syncBtn:SetScript("OnClick", function()
        if SC.CreateRunSyncProposal then
            SC:CreateRunSyncProposal()
        else
            Print("run sync proposals are not loaded.")
        end
        SC:MasterUI_Refresh()
    end)
    frame.start.inviteBtn = CreateButton(startPanel, "Invite Party", 100, 24)
    frame.start.inviteBtn:SetPoint("LEFT", frame.start.syncBtn, "RIGHT", 8, 0)
    frame.start.inviteBtn:SetScript("OnClick", function()
        if SC.CreateRunInviteProposal then
            SC:CreateRunInviteProposal()
        else
            Print("party run invites are not loaded.")
        end
        SC:MasterUI_Refresh()
    end)
    frame.start.applyChangesBtn = CreateButton(startPanel, "Apply Changes", 120, 24)
    frame.start.applyChangesBtn:SetPoint("LEFT", frame.start.primaryBtn, "RIGHT", 8, 0)
    frame.start.applyChangesBtn:SetScript("OnClick", function()
        local changes = BuildRuleChanges(frame.start.draftBaseRules or {}, frame.start.selectedRules or {})
        if CountRuleChanges(changes) == 0 then
            Print("no rule changes selected.")
            return
        end

        if IsInGroup() then
            if SC.ProposeRuleAmendment then
                SC:ProposeRuleAmendment(changes, "Run rules modified from the Run tab.")
                frame.start.isModifyingRules = false
                frame.start.draftBaseRules = nil
                Print("rule amendment proposed to party.")
            else
                Print("rule amendment handling is not loaded.")
            end
        else
            if SC.ProposeRuleAmendment and SC.AcceptRuleAmendment and SC.ApplyRuleAmendment then
                local amendment = SC:ProposeRuleAmendment(changes, "Run rules modified from the Run tab.")
                SC:AcceptRuleAmendment(amendment.id)
                SC:ApplyRuleAmendment(amendment.id)
                frame.start.isModifyingRules = false
                frame.start.draftBaseRules = nil
                Print("rule changes applied.")
            else
                Print("rule amendment handling is not loaded.")
            end
        end

        SC:MasterUI_Refresh()
    end)
    frame.start.cancelChangesBtn = CreateButton(startPanel, "Cancel", 80, 24)
    frame.start.cancelChangesBtn:SetPoint("LEFT", frame.start.applyChangesBtn, "RIGHT", 8, 0)
    frame.start.cancelChangesBtn:SetScript("OnClick", function()
        frame.start.isModifyingRules = false
        frame.start.draftBaseRules = nil
        SC:MasterUI_Refresh()
    end)
    frame.start.proposalAcceptBtn = CreateButton(startPanel, "Accept", 90, 24)
    frame.start.proposalDeclineBtn = CreateButton(startPanel, "Decline", 90, 24)
    frame.start.proposalCancelBtn = CreateButton(startPanel, "Cancel Proposal", 120, 24)
    frame.start.proposalAcceptBtn:Hide()
    frame.start.proposalDeclineBtn:Hide()
    frame.start.proposalCancelBtn:Hide()

    -- Amendment proposal overlay (replaces rule controls when a pending amendment exists)
    local amendPanel = CreateFrame("Frame", nil, startPanel, "BackdropTemplate")
    amendPanel:SetSize(640, 200)
    amendPanel:SetPoint("TOPLEFT", startPanel, "TOPLEFT", 0, 0)
    amendPanel:EnableMouse(true)
    amendPanel:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    amendPanel:SetBackdropColor(0.05, 0.05, 0, 0.95)
    amendPanel:Hide()

    amendPanel.title   = CreateField(amendPanel, 10, -10, 620)
    amendPanel.title:SetFontObject(GameFontNormal)
    amendPanel.proposer = CreateField(amendPanel, 10, -30, 620)
    amendPanel.reason   = CreateField(amendPanel, 10, -48, 620)
    amendPanel.changeLines = {}
    for i = 1, 8 do
        amendPanel.changeLines[i] = CreateField(amendPanel, 10, -64 - (i - 1) * 16, 620)
    end
    amendPanel.acceptBtn  = CreateButton(amendPanel, "Accept",          90, 24)
    amendPanel.declineBtn = CreateButton(amendPanel, "Decline",         90, 24)
    amendPanel.cancelBtn  = CreateButton(amendPanel, "Cancel Proposal", 120, 24)
    amendPanel.acceptBtn:SetPoint("BOTTOMLEFT",  amendPanel, "BOTTOMLEFT", 10, 10)
    amendPanel.declineBtn:SetPoint("LEFT", amendPanel.acceptBtn, "RIGHT", 8, 0)
    amendPanel.cancelBtn:SetPoint("BOTTOMLEFT",  amendPanel, "BOTTOMLEFT", 10, 10)
    amendPanel.waitText = CreateField(amendPanel, 10, -999, 620)
    amendPanel.waitText:SetPoint("BOTTOMLEFT", amendPanel, "BOTTOMLEFT", 10, 42)
    amendPanel.waitText:SetText("|cfffbbf24Waiting for party members to accept...|r")

    frame.start.amendmentPanel = amendPanel



    local overviewPanel = CreatePanel(frame)
    frame.panels[TAB_OVERVIEW] = overviewPanel
    CreateSectionHeader(overviewPanel, "Character Record", 0, 0, 650)
    frame.overview = {
        panel = overviewPanel,
        noRunText = CreateField(overviewPanel, 0, -34, 500),
        run = CreateField(overviewPanel, 0, -34),
        localStatus = CreateField(overviewPanel, 0, -58),
        partyStatus = CreateField(overviewPanel, 0, -84),
        elapsed = CreateField(overviewPanel, 0, -110),
        levels = CreateField(overviewPanel, 380, -58, 260),
        deaths = CreateField(overviewPanel, 380, -84, 220),
        violations = CreateField(overviewPanel, 380, -110, 220),
        runId = CreateField(overviewPanel, 0, -140, 650),
        integrity = CreateField(overviewPanel, 0, -162, 690),
        partyRows = {},
    }
    frame.overview.noRunText:SetText("No active run. Start a Softcore run to begin tracking deaths, violations, and party status.")
    frame.overview.goToRunBtn = CreateButton(overviewPanel, "Start a Run", 110, 24)
    frame.overview.goToRunBtn:SetPoint("TOPLEFT", overviewPanel, "TOPLEFT", 0, -68)
    frame.overview.goToRunBtn:SetScript("OnClick", function()
        frame.activeTab = TAB_RUN
        SC:MasterUI_Refresh()
    end)
    CreateSectionHeader(overviewPanel, "Party Ledger", 0, -184, 650)
    frame.overview.resyncBtn = CreateButton(overviewPanel, "Resync", 72, 20)
    frame.overview.resyncBtn:SetPoint("TOPRIGHT", overviewPanel, "TOPRIGHT", -24, -181)
    frame.overview.resyncBtn:SetScript("OnClick", function()
        if SC.Sync_BroadcastStatus then
            SC:Sync_BroadcastStatus("RESYNC")
            Print("resync requested.")
        end
    end)
    CreateLabel(overviewPanel, "Name", 0, -222, "GameFontNormalSmall", 190)
    CreateLabel(overviewPanel, "Level |cffad8f61(Start)|r", 204, -222, "GameFontNormalSmall", 100)
    CreateLabel(overviewPanel, "Status", 314, -222, "GameFontNormalSmall", 180)
    CreateLabel(overviewPanel, "Total Violations", 520, -222, "GameFontNormalSmall", 140)

    local columnSep = overviewPanel:CreateTexture(nil, "ARTWORK")
    columnSep:SetHeight(1)
    columnSep:SetPoint("TOPLEFT",  overviewPanel, "TOPLEFT",  0, -237)
    columnSep:SetWidth(650)
    columnSep:SetColorTexture(0.72, 0.49, 0.18, 0.42)

    frame.overview.partyEmpty = CreateField(overviewPanel, 0, -252, 620)
    frame.overview.partyEmpty:SetText("No synced party members.")

    local violationsPanel = CreatePanel(frame)
    frame.panels[TAB_VIOLATIONS] = violationsPanel
    frame.violations = { rows = {} }
    CreateSectionHeader(violationsPanel, "Active Violations", 0, 0, 650)
    CreateLabel(violationsPanel, "Time", 0, -38, "GameFontNormalSmall", 130)
    CreateLabel(violationsPanel, "Character", 134, -38, "GameFontNormalSmall", 100)
    CreateLabel(violationsPanel, "Issue", 242, -38, "GameFontNormalSmall", 128)
    CreateLabel(violationsPanel, "Details", 378, -38, "GameFontNormalSmall", 230)
    local violColSep = violationsPanel:CreateTexture(nil, "ARTWORK")
    violColSep:SetHeight(1)
    violColSep:SetPoint("TOPLEFT",  violationsPanel, "TOPLEFT",  0, -53)
    violColSep:SetPoint("TOPRIGHT", violationsPanel, "TOPRIGHT", -20, -53)
    violColSep:SetColorTexture(0.72, 0.49, 0.18, 0.42)
    frame.violations.empty = CreateField(violationsPanel, 0, -66, 620)
    frame.violations.empty:SetText("No active violations.")
    frame.violations.scroll = CreateFrame("ScrollFrame", "SoftcoreViolationsScrollFrame", violationsPanel, "FauxScrollFrameTemplate")
    frame.violations.scroll:SetPoint("TOPLEFT", violationsPanel, "TOPLEFT", 0, VIOLATION_ROW_TOP)
    frame.violations.scroll:SetPoint("BOTTOMRIGHT", violationsPanel, "BOTTOMRIGHT", -24, 18)
    frame.violations.scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, VIOLATION_ROW_HEIGHT, function()
            SC:MasterUI_Refresh()
        end)
    end)
    for index = 1, VIOLATION_ROWS do
        local row = CreateFrame("Frame", nil, violationsPanel)
        row:SetSize(690, VIOLATION_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", violationsPanel, "TOPLEFT", 0, VIOLATION_ROW_TOP - ((index - 1) * VIOLATION_ROW_HEIGHT))
        if index % 2 == 0 then
            local rowBg = row:CreateTexture(nil, "BACKGROUND")
            rowBg:SetAllPoints(row)
            rowBg:SetColorTexture(0.82, 0.58, 0.22, 0.08)
        end
        row.time = CreateField(row, 0, 0, 130)
        row.owner = CreateField(row, 134, 0, 100)
        row.type = CreateField(row, 242, 0, 128)
        row.detail = CreateField(row, 378, 0, 230)
        row.time:ClearAllPoints()
        row.time:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.owner:ClearAllPoints()
        row.owner:SetPoint("LEFT", row, "LEFT", 134, 0)
        row.type:ClearAllPoints()
        row.type:SetPoint("LEFT", row, "LEFT", 242, 0)
        row.detail:ClearAllPoints()
        row.detail:SetPoint("LEFT", row, "LEFT", 378, 0)
        row.time:SetWordWrap(false)
        row.owner:SetWordWrap(false)
        row.type:SetWordWrap(false)
        row.detail:SetWordWrap(false)
        row.clearBtn = CreateButton(row, "Clear", 58, 17)
        row.clearBtn:SetPoint("RIGHT", row, "RIGHT", -18, 0)
        frame.violations.rows[index] = row
    end

    local logPanel = CreatePanel(frame)
    frame.panels[TAB_LOG] = logPanel
    frame.log = { rows = {} }
    CreateSectionHeader(logPanel, "Audit Log", 0, 0, 650)
    CreateLabel(logPanel, "Time", 0, -38, "GameFontNormalSmall", 130)
    CreateLabel(logPanel, "Character", 134, -38, "GameFontNormalSmall", 100)
    CreateLabel(logPanel, "Event", 242, -38, "GameFontNormalSmall", 128)
    CreateLabel(logPanel, "Message", 378, -38, "GameFontNormalSmall", 300)
    local logColSep = logPanel:CreateTexture(nil, "ARTWORK")
    logColSep:SetHeight(1)
    logColSep:SetPoint("TOPLEFT",  logPanel, "TOPLEFT",  0, -53)
    logColSep:SetPoint("TOPRIGHT", logPanel, "TOPRIGHT", -20, -53)
    logColSep:SetColorTexture(0.72, 0.49, 0.18, 0.42)
    frame.log.empty = CreateField(logPanel, 0, -66, 620)
    frame.log.empty:SetText("No events recorded.")
    frame.log.scroll = CreateFrame("ScrollFrame", "SoftcoreLogScrollFrame", logPanel, "FauxScrollFrameTemplate")
    frame.log.scroll:SetPoint("TOPLEFT", logPanel, "TOPLEFT", 0, LOG_ROW_TOP)
    frame.log.scroll:SetPoint("BOTTOMRIGHT", logPanel, "BOTTOMRIGHT", -24, 18)
    frame.log.scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, LOG_ROW_HEIGHT, function()
            SC:MasterUI_Refresh()
        end)
    end)
    for index = 1, LOG_ROWS do
        local row = CreateFrame("Frame", nil, logPanel)
        row:SetSize(690, LOG_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", logPanel, "TOPLEFT", 0, LOG_ROW_TOP - ((index - 1) * LOG_ROW_HEIGHT))
        if index % 2 == 0 then
            local rowBg = row:CreateTexture(nil, "BACKGROUND")
            rowBg:SetAllPoints(row)
            rowBg:SetColorTexture(0.82, 0.58, 0.22, 0.08)
        end
        row.time = CreateField(row, 0, 0, 130)
        row.actor = CreateField(row, 134, 0, 100)
        row.kind = CreateField(row, 242, 0, 128)
        row.message = CreateField(row, 378, 0, 300)
        row.time:ClearAllPoints()
        row.time:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.actor:ClearAllPoints()
        row.actor:SetPoint("LEFT", row, "LEFT", 134, 0)
        row.kind:ClearAllPoints()
        row.kind:SetPoint("LEFT", row, "LEFT", 242, 0)
        row.message:ClearAllPoints()
        row.message:SetPoint("LEFT", row, "LEFT", 378, 0)
        row.time:SetWordWrap(false)
        row.actor:SetWordWrap(false)
        row.kind:SetWordWrap(false)
        row.message:SetWordWrap(false)
        frame.log.rows[index] = row
    end

    local achievementsPanel = CreatePanel(frame)
    frame.panels[TAB_ACHIEVEMENTS] = achievementsPanel
    frame.achievements = { rows = {} }
    CreateSectionHeader(achievementsPanel, "Achievements", 0, 0, 650)
    frame.achievements.summary = CreateField(achievementsPanel, 0, -34, 250)
    frame.achievements.summary:SetText("Earned: 0 / 0")
    frame.achievements.empty = CreateField(achievementsPanel, 0, -72, 620)
    frame.achievements.empty:SetText("No achievements are loaded.")
    frame.achievements.scroll = CreateFrame("ScrollFrame", "SoftcoreAchievementsScrollFrame", achievementsPanel, "UIPanelScrollFrameTemplate")
    frame.achievements.scroll:SetPoint("TOPLEFT", achievementsPanel, "TOPLEFT", 0, -64)
    frame.achievements.scroll:SetSize(674, 408)
    frame.achievements.scroll:EnableMouseWheel(true)
    frame.achievements.scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local maxScroll = self:GetVerticalScrollRange() or 0
        local nextScroll = current - (delta * 48)
        if nextScroll < 0 then nextScroll = 0 end
        if nextScroll > maxScroll then nextScroll = maxScroll end
        self:SetVerticalScroll(nextScroll)
        local scrollBar = _G[self:GetName() .. "ScrollBar"]
        if scrollBar then
            scrollBar:SetValue(nextScroll)
        end
    end)
    frame.achievements.content = CreateFrame("Frame", nil, frame.achievements.scroll)
    frame.achievements.content:SetSize(628, 408)
    frame.achievements.scroll:SetScrollChild(frame.achievements.content)

    self.masterFrame = frame
    self:MasterUI_Refresh()
end
