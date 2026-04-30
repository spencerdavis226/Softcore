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
local PANEL_HEIGHT = 560
local RUN_FOOTER_BOTTOM = 24
local RUN_FOOTER_LEFT_INSET = 32
local RUN_FOOTER_RIGHT_INSET = 32
local RUN_LAYOUT = {
    CONTENT_WIDTH = 690,
    SECTION_GAP = 14,
    COLUMN_GAP = 32,
    ROW_HEIGHT = 31,
    SECTION_CONTENT_TOP = 32,
    SECTION_ROW_CONTROL_HEIGHT = 28,
    DROPDOWN_X_OFFSET = -16,
    CHECKBOX_LABEL_GAP = 4,
    INLINE_FIELD_GAP = 10,
}
RUN_LAYOUT.COLUMN_WIDTH = math.floor((RUN_LAYOUT.CONTENT_WIDTH - RUN_LAYOUT.COLUMN_GAP) / 2)
RUN_LAYOUT.RIGHT_COLUMN_X = RUN_LAYOUT.COLUMN_WIDTH + RUN_LAYOUT.COLUMN_GAP
SC.MasterUIRunLayout = RUN_LAYOUT
local AUDIT_LIST_LAYOUT = {
    CONTENT_WIDTH = 690,
    SUMMARY_TOP = -34,
    COLUMN_TOP = -58,
    DIVIDER_TOP = -72,
    ROW_TOP = -86,
    ROW_HEIGHT = 34,
    FOOTER_HEIGHT = 36,
    ROW_TEXT_INSET = 10,
    SCROLL_RIGHT_INSET = 24,
}
AUDIT_LIST_LAYOUT.TYPE_X = 10
AUDIT_LIST_LAYOUT.TYPE_WIDTH = 108
AUDIT_LIST_LAYOUT.ACTOR_X = 136
AUDIT_LIST_LAYOUT.ACTOR_WIDTH = 92
AUDIT_LIST_LAYOUT.TIME_X = 246
AUDIT_LIST_LAYOUT.TIME_WIDTH = 134
AUDIT_LIST_LAYOUT.MESSAGE_X = 398
AUDIT_LIST_LAYOUT.MESSAGE_WIDTH = AUDIT_LIST_LAYOUT.CONTENT_WIDTH - AUDIT_LIST_LAYOUT.MESSAGE_X - 28
AUDIT_LIST_LAYOUT.ACTION_MESSAGE_WIDTH = AUDIT_LIST_LAYOUT.CONTENT_WIDTH - AUDIT_LIST_LAYOUT.MESSAGE_X - 96
AUDIT_LIST_LAYOUT.VISIBLE_ROWS = math.floor((PANEL_HEIGHT + AUDIT_LIST_LAYOUT.ROW_TOP - AUDIT_LIST_LAYOUT.FOOTER_HEIGHT - 8) / AUDIT_LIST_LAYOUT.ROW_HEIGHT)
local LOG_UI_MAX_ENTRIES = 1000
local LOG_ROWS = AUDIT_LIST_LAYOUT.VISIBLE_ROWS
local LOG_ROW_TOP = AUDIT_LIST_LAYOUT.ROW_TOP
local LOG_ROW_HEIGHT = AUDIT_LIST_LAYOUT.ROW_HEIGHT
local VIOLATION_ROWS = AUDIT_LIST_LAYOUT.VISIBLE_ROWS
local VIOLATION_ROW_TOP = AUDIT_LIST_LAYOUT.ROW_TOP
local VIOLATION_ROW_HEIGHT = AUDIT_LIST_LAYOUT.ROW_HEIGHT
local OVERVIEW_PARTY_ROWS = 5
local OVERVIEW_LAYOUT = {
    CONTENT_WIDTH = 690,
    HERO_HEIGHT = 78,
    HERO_GAP = 10,
    METRIC_HEIGHT = 74,
    METRIC_GAP = 10,
    LEDGER_TOP_GAP = 18,
    ACTIVITY_HEIGHT = 90,
    ACTIVITY_GAP = 14,
    ACTIVITY_ROWS = 3,
    SECTION_INSET = 12,
    SECTION_TITLE_TOP = -9,
    SECTION_DIVIDER_TOP = -30,
    SECTION_HEADER_HEIGHT = 36,
    LEDGER_INSET = 12,
    LEDGER_HEADER_HEIGHT = 36,
    LEDGER_ROW_HEIGHT = 44,
    LEDGER_ROW_GAP = 6,
    LEDGER_BADGE_WIDTH = 136,
    LEDGER_BADGE_HEIGHT = 24,
    LEDGER_BADGE_GAP = 12,
}
OVERVIEW_LAYOUT.LEDGER_MAX_ROWS_HEIGHT = (OVERVIEW_PARTY_ROWS * OVERVIEW_LAYOUT.LEDGER_ROW_HEIGHT)
    + ((OVERVIEW_PARTY_ROWS - 1) * OVERVIEW_LAYOUT.LEDGER_ROW_GAP)
local ACHIEVEMENT_LAYOUT = {
    CONTENT_WIDTH = 690,
    SUMMARY_TOP = -34,
    SUMMARY_HEIGHT = 62,
    SUMMARY_GAP = 10,
    SCROLL_TOP = -112,
    SCROLL_HEIGHT = PANEL_HEIGHT - 128,
    SCROLL_WIDTH = 714,
    SECTION_GAP = 8,
    SECTION_HEADER_HEIGHT = 38,
    SECTION_ROW_TOP_GAP = 6,
    SECTION_BOTTOM_INSET = 8,
    ROW_HEIGHT = 72,
    ROW_GAP = 6,
    ROW_INSET = 10,
    ICON_SIZE = 42,
    BADGE_WIDTH = 74,
    BADGE_HEIGHT = 20,
    PROGRESS_WIDTH = 170,
}
local BODY_TEXT = { r = 0.94, g = 0.86, b = 0.68 }
local MUTED_TEXT = { r = 0.68, g = 0.56, b = 0.38 }
local GOLD_TEXT = { r = 1.00, g = 0.82, b = 0.20 }
local GREEN_TEXT = { r = 0.42, g = 1.00, b = 0.54 }
local RED_TEXT = { r = 1.00, g = 0.30, b = 0.25 }
local BLUE_TEXT = { r = 0.38, g = 0.66, b = 1.00 }
local PURPLE_TEXT = { r = 0.78, g = 0.58, b = 1.00 }
local ORANGE_TEXT = { r = 1.00, g = 0.58, b = 0.22 }
local MENU_LOGO_TEXTURE = "Interface\\AddOns\\Softcore\\Assets\\SoftcoreLogoMenu"

local CLASS_COLORS = {
    DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },
    DEMONHUNTER = { r = 0.64, g = 0.19, b = 0.79 },
    DRUID = { r = 1.00, g = 0.49, b = 0.04 },
    EVOKER = { r = 0.20, g = 0.58, b = 0.50 },
    HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
    MAGE = { r = 0.25, g = 0.78, b = 0.92 },
    MONK = { r = 0.00, g = 1.00, b = 0.60 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    PRIEST = { r = 1.00, g = 1.00, b = 1.00 },
    ROGUE = { r = 1.00, g = 0.96, b = 0.41 },
    SHAMAN = { r = 0.00, g = 0.44, b = 0.87 },
    WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
}

local CLASS_LABELS = {
    DEATHKNIGHT = "Death Knight",
    DEMONHUNTER = "Demon Hunter",
}

local ACHIEVEMENT_CATEGORY_ORDER = {
    "Award",
    "Leveling",
    "Max Level",
    "Classes",
    "Rules",
}

local ACHIEVEMENT_CATEGORY_META = {
    Award = { label = "Completion Award", icon = "Interface\\Icons\\INV_Letter_18", color = GOLD_TEXT },
    Leveling = { label = "Leveling", icon = "Interface\\Icons\\Achievement_Level_10", color = GREEN_TEXT },
    ["Max Level"] = { label = "Max Level", icon = "Interface\\Icons\\INV_Misc_Trophy_Argent", color = GOLD_TEXT },
    Classes = { label = "Classes", icon = "Interface\\Icons\\Achievement_Character_Human_Male", color = PURPLE_TEXT },
    Rules = { label = "Rules", icon = "Interface\\Icons\\INV_Misc_Note_03", color = ORANGE_TEXT },
}

local ACHIEVEMENT_CLASS_ICONS = {
    DEATHKNIGHT = "Interface\\Icons\\Spell_Deathknight_ClassIcon",
    DEMONHUNTER = "Interface\\Icons\\Ability_DemonHunter_SpectralSight",
    DRUID = "Interface\\Icons\\Ability_Druid_Maul",
    EVOKER = "Interface\\Icons\\ClassIcon_Evoker",
    HUNTER = "Interface\\Icons\\INV_Weapon_Bow_07",
    MAGE = "Interface\\Icons\\Spell_Frost_FrostBolt02",
    MONK = "Interface\\Icons\\Class_Monk",
    PALADIN = "Interface\\Icons\\Ability_Paladin_BeaconofLight",
    PRIEST = "Interface\\Icons\\Spell_Holy_PowerWordShield",
    ROGUE = "Interface\\Icons\\Ability_Stealth",
    SHAMAN = "Interface\\Icons\\Spell_Nature_BloodLust",
    WARLOCK = "Interface\\Icons\\Spell_Shadow_CurseOfTounges",
    WARRIOR = "Interface\\Icons\\Ability_Warrior_InnerRage",
}

local ACHIEVEMENT_RULE_ICONS = {
    actionCam = "Interface\\Icons\\INV_Misc_Spyglass_02",
    auctionHouse = "Interface\\Icons\\INV_Misc_Coin_02",
    bank = "Interface\\Icons\\INV_Misc_Bag_08",
    consumables = "Interface\\Icons\\INV_Potion_54",
    dungeonRepeat = "Interface\\Icons\\Achievement_Dungeon_GloryoftheRaider",
    enchants = "Interface\\Icons\\Trade_Engraving",
    flightPaths = "Interface\\Icons\\Ability_Mount_Gryphon_01",
    flying = "Interface\\Icons\\Ability_Mount_Wyvern_01",
    gearQuality = "Interface\\Icons\\INV_Chest_Cloth_17",
    guildBank = "Interface\\Icons\\INV_Misc_Gem_Variety_01",
    heirlooms = "Interface\\Icons\\INV_Misc_Cape_18",
    instancedPvP = "Interface\\Icons\\Achievement_BG_winWSG",
    mailbox = "Interface\\Icons\\INV_Letter_15",
    maxLevelGap = "Interface\\Icons\\Achievement_GuildPerk_WorkingOvertime_Rank2",
    mounts = "Interface\\Icons\\Ability_Mount_RidingHorse",
    trade = "Interface\\Icons\\INV_Misc_Bag_10",
    warbandBank = "Interface\\Icons\\INV_Misc_EngGizmos_17",
    WHITE_GRAY_ONLY = "Interface\\Icons\\INV_Chest_Cloth_17",
}

local ACHIEVEMENT_KIND_ICONS = {
    BINARY = "Interface\\Icons\\Achievement_General",
    CAMERA_IRONMAN_NO_FLIGHT_PATHS_MAX = "Interface\\Icons\\Ability_Mount_Gryphon_01",
    CAMERA_MAX = "Interface\\Icons\\INV_Misc_Spyglass_02",
    CHEF_SPECIAL_MAX = "Interface\\Icons\\INV_Misc_Food_15",
    CLEAN_MAX = "Interface\\Icons\\INV_Misc_Rune_01",
    COMPLETION_AWARD = "Interface\\Icons\\INV_Letter_18",
    GEAR_QUALITY_CRAFTED_MAX = "Interface\\Icons\\Trade_BlackSmithing",
    GEAR_QUALITY_MAX = "Interface\\Icons\\INV_Chest_Cloth_17",
    GROUPED_MAX = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend",
    IRONMAN_MAX = "Interface\\Icons\\INV_Sword_27",
    MAX_LEVEL = "Interface\\Icons\\INV_Misc_Trophy_Argent",
    RULE_UNCHANGED_MAX = "Interface\\Icons\\INV_Misc_Note_05",
}

local PRESET_DISPLAY = {
    CASUAL = "Casual Run",
    CHEF_SPECIAL = "Chef's Special Run",
    IRONMAN = "Ironman Run",
    IRON_VIGIL = "Iron Vigil Run",
}
local PRESET_ORDER = { "CASUAL", "CHEF_SPECIAL", "IRONMAN", "IRON_VIGIL" }

local GROUPING_OPTIONS = {
    { text = "Group", value = "SYNCED_GROUP_ALLOWED" },
    { text = "Solo Only", value = "SOLO_SELF_FOUND" },
}

local GEAR_OPTIONS = {
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
    {
        label = "Allow Mounts",
        key = "mounts",
        tooltip = "Allows ground mount-style travel. Worgen Running Wild and Druid land Travel/Mount Form count as ground mounts.",
    },
    {
        label = "Allow Flying Mounts",
        key = "flying",
        tooltip = "Allows player-controlled flying. Druid Flight Form and Dracthyr Soar count as flying mounts.",
    },
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
    "selfCraftedGearAllowed",
    "heirlooms",
    "enchants",
    "maxLevelGap",
    "maxLevelGapValue",
    "dungeonRepeat",
    "consumables",
    "instancedPvP",
    "actionCam",
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r " .. tostring(message))
end

local function FormatTime(timestamp)
    if not timestamp then return "never" end
    return date("%Y-%m-%d %H:%M:%S", timestamp)
end

local function FormatClock(timestamp)
    if not timestamp then return "never" end
    return date("%H:%M", timestamp)
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

local function FormatDuration(seconds)
    if SC.FormatDuration then
        return SC:FormatDuration(seconds)
    end
    seconds = tonumber(seconds or 0) or 0
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
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
    FORCED_MOVEMENT = { label = "Forced Movement", group = "system" },
    FORCED_MOVEMENT_ENDED = { label = "Forced Movement ..", group = "system" },
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
    PVP_ADVISORY = { label = "PvP Advisory", group = "world" },
    RULE_AMENDMENT_ACCEPTED = { label = "Rule Accepted", group = "rules" },
    RULE_AMENDMENT_APPLIED = { label = "Rules Applied", group = "rules" },
    RULE_AMENDMENT_DECLINED = { label = "Rule Declined", group = "rules" },
    RULE_AMENDMENT_PROPOSED = { label = "Rule Proposal", group = "rules" },
    RULE_AMENDMENT_RECEIVED = { label = "Rule Proposal", group = "rules" },
    RULE_AMENDMENT_SUMMARY = { label = "Rules Amended", group = "rules" },
    RULE_CHANGED = { label = "Rule Changed", group = "rules" },
    RULE_LOG = { label = "Rule Notice", group = "rules" },
    RULE_UNKNOWN_OUTCOME = { label = "Rule Notice", group = "rules" },
    RUN_RESET = { label = "Run Reset", group = "run" },
    RUN_START = { label = "Run Started", group = "run" },
    RUN_COMPLETED = { label = "Run Completed", group = "run" },
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
    local kind = tostring(entry and entry.kind or "")
    if LOG_HIDDEN_EVENTS[kind] then
        return false
    end
    if SC.ShouldDisplayLogEntryInUI and not SC:ShouldDisplayLogEntryInUI(entry) then
        return false
    end
    return true
end

local function GetVisibleLogEntries(log, maxEntries)
    local entries = {}
    local totalVisible = 0

    for index = #log, 1, -1 do
        local entry = log[index]
        if ShouldShowLogEntry(entry) then
            totalVisible = totalVisible + 1
            if not maxEntries or #entries < maxEntries then
                table.insert(entries, entry)
            end
        end
    end

    return entries, totalVisible
end

local LOG_VIOLATION_LABELS = {
    auctionHouse = "Auction House",
    bank = "Bank",
    consumables = "Consumable",
    death = "Death",
    enchants = "Enchant",
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

local function CenteredOffset(containerWidth, childWidth)
    return math.floor(((containerWidth or 0) - (childWidth or 0)) / 2)
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

local function CreateAuditColumn(parent, text, x, width)
    local label = CreateLabel(parent, text, x, AUDIT_LIST_LAYOUT.COLUMN_TOP, "GameFontNormalSmall", width)
    label:SetTextColor(MUTED_TEXT.r, MUTED_TEXT.g, MUTED_TEXT.b)
    return label
end

local function CreateAuditListFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    footer:SetHeight(AUDIT_LIST_LAYOUT.FOOTER_HEIGHT)
    local divider = footer:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, 0)
    divider:SetPoint("TOPRIGHT", footer, "TOPRIGHT", -AUDIT_LIST_LAYOUT.SCROLL_RIGHT_INSET, 0)
    divider:SetColorTexture(0.72, 0.49, 0.18, 0.30)
    footer.text = CreateField(footer, 0, -11, 500)
    footer.text:SetTextColor(MUTED_TEXT.r, MUTED_TEXT.g, MUTED_TEXT.b)
    return footer
end

local function CreateAuditRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(AUDIT_LIST_LAYOUT.CONTENT_WIDTH, AUDIT_LIST_LAYOUT.ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, AUDIT_LIST_LAYOUT.ROW_TOP - ((index - 1) * AUDIT_LIST_LAYOUT.ROW_HEIGHT))
    row:EnableMouse(true)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetColorTexture(0.82, 0.58, 0.22, index % 2 == 0 and 0.08 or 0.035)

    row.accent = row:CreateTexture(nil, "ARTWORK")
    row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -3)
    row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 3)
    row.accent:SetWidth(3)
    row.accent:SetColorTexture(GOLD_TEXT.r, GOLD_TEXT.g, GOLD_TEXT.b, 0.85)

    return row
end

local function SetAuditRowAccent(row, color)
    if not row or not row.accent then return end
    color = color or BODY_TEXT
    row.accent:SetColorTexture(color.r, color.g, color.b, 0.85)
end

local function SetAuditRowTooltip(row, title, body)
    if not row then return end
    if (not title or title == "") and (not body or body == "") then
        row:SetScript("OnEnter", nil)
        row:SetScript("OnLeave", nil)
        return
    end

    row:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if title and title ~= "" then
            GameTooltip:AddLine(title, GOLD_TEXT.r, GOLD_TEXT.g, GOLD_TEXT.b)
        end
        if body and body ~= "" then
            GameTooltip:AddLine(body, BODY_TEXT.r, BODY_TEXT.g, BODY_TEXT.b, true)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

function RUN_LAYOUT:SectionHeight(rowCount, extraHeight)
    rowCount = math.max(tonumber(rowCount or 1) or 1, 1)
    return self.SECTION_CONTENT_TOP + ((rowCount - 1) * self.ROW_HEIGHT) + self.SECTION_ROW_CONTROL_HEIGHT + (extraHeight or 0)
end

function RUN_LAYOUT:CreateRow(parent, x, y, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, y or 0)
    row:SetSize(width or self.COLUMN_WIDTH, self.ROW_HEIGHT)
    return row
end

function RUN_LAYOUT:PlaceRowLabel(row, label, x, width)
    if not row or not label then return end
    label:ClearAllPoints()
    label:SetPoint("LEFT", row, "LEFT", x or 0, 0)
    label:SetWidth(width or 120)
    label:SetJustifyH("LEFT")
end

function RUN_LAYOUT:PlaceRowDropdown(row, dropdown, x)
    if not row or not dropdown then return end
    dropdown:ClearAllPoints()
    dropdown:SetPoint("LEFT", row, "LEFT", (x or 0) + self.DROPDOWN_X_OFFSET, 0)
end

function RUN_LAYOUT:PlaceRowCheckbox(row, checkbox, x)
    if not row or not checkbox then return end
    checkbox:ClearAllPoints()
    checkbox:SetPoint("LEFT", row, "LEFT", x or 0, 0)
end

function RUN_LAYOUT:PlaceCheckboxText(checkbox, width)
    if not checkbox or not checkbox.label then return end
    checkbox.label:ClearAllPoints()
    checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", self.CHECKBOX_LABEL_GAP, 0)
    checkbox.label:SetWidth(width or 0)
    checkbox.label:SetJustifyH("LEFT")
end

-- Place the label to the LEFT of the checkbox (right-justified into it). Use for inline checkbox groups
-- where the label must precede the checkbox so the association is unambiguous.
function RUN_LAYOUT:PlaceCheckboxTextLeft(checkbox, width)
    if not checkbox or not checkbox.label then return end
    checkbox.label:ClearAllPoints()
    checkbox.label:SetPoint("RIGHT", checkbox, "LEFT", -self.CHECKBOX_LABEL_GAP, 0)
    checkbox.label:SetWidth(width or 0)
    checkbox.label:SetJustifyH("RIGHT")
end

-- Place a dropdown immediately after a label, accounting for the dropdown frame's internal x offset.
function RUN_LAYOUT:PlaceDropdownAfterLabel(label, dropdown, gap)
    if not label or not dropdown then return end
    dropdown:ClearAllPoints()
    dropdown:SetPoint("LEFT", label, "RIGHT", (gap or self.INLINE_FIELD_GAP) + self.DROPDOWN_X_OFFSET, 0)
end

function RUN_LAYOUT:PlaceInlineField(anchor, label, box)
    if not anchor or not label or not box then return end
    label:ClearAllPoints()
    label:SetPoint("LEFT", anchor, "RIGHT", self.INLINE_FIELD_GAP, 0)
    label:SetJustifyH("LEFT")
    box:ClearAllPoints()
    box:SetPoint("LEFT", label, "RIGHT", 4, 0)
end

local function CreateOverviewCard(parent, title, x, y, width, height, options)
    options = options or {}
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    card:SetSize(width or 160, height or 86)
    if card.SetBackdrop then
        card:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        card:SetBackdropColor(0.08, 0.045, 0.018, 0.82)
        card:SetBackdropBorderColor(0.68, 0.48, 0.18, 0.95)
    end

    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -9)
    card.title:SetTextColor(GOLD_TEXT.r, GOLD_TEXT.g, GOLD_TEXT.b)
    card.title:SetText(title)

    card.value = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.value:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -8)
    card.value:SetWidth((width or 160) - 24)
    card.value:SetJustifyH("LEFT")
    card.value:SetTextColor(BODY_TEXT.r, BODY_TEXT.g, BODY_TEXT.b)
    if options.valueFont and _G[options.valueFont] then
        card.value:SetFontObject(_G[options.valueFont])
    end
    if options.centerValue then
        card.value:ClearAllPoints()
        card.value:SetPoint("LEFT", card, "LEFT", 12, -8)
        card.value:SetPoint("RIGHT", card, "RIGHT", -12, -8)
        card.value:SetJustifyH("CENTER")
    end

    card.detail = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.detail:SetPoint("TOPLEFT", card.value, "BOTTOMLEFT", 0, -8)
    card.detail:SetWidth((width or 160) - 24)
    card.detail:SetJustifyH("LEFT")
    card.detail:SetTextColor(MUTED_TEXT.r, MUTED_TEXT.g, MUTED_TEXT.b)
    if options.hideDetail then
        card.detail:Hide()
    end

    return card
end

local function SetOverviewCardTone(card, color)
    if not card or not color then return end
    if card.SetBackdropColor then
        card:SetBackdropColor(color.r * 0.10, color.g * 0.075, color.b * 0.045, 0.86)
        card:SetBackdropBorderColor(color.r, color.g, color.b, 0.88)
    end
end

local function CreateOverviewMetricGrid(parent, specs, x, y, width, height, gap)
    local cards = {}
    local order = {}
    local count = #specs
    local cardWidth = math.floor(((width or OVERVIEW_LAYOUT.CONTENT_WIDTH) - ((count - 1) * (gap or 0))) / count)

    for index, spec in ipairs(specs) do
        local left = x + ((index - 1) * (cardWidth + (gap or 0)))
        local card = CreateOverviewCard(parent, spec.title, left, y, cardWidth, height, {
            centerValue = true,
            hideDetail = true,
            valueFont = "GameFontNormalLarge",
        })
        card.metricKey = spec.key
        cards[spec.key] = card
        table.insert(order, card)
    end

    return cards, order
end

local function CreateRunSection(parent, title, x, y, width, height)
    local section = CreateFrame("Frame", nil, parent)
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    section:SetSize(width, height)
    section.fixedHeight = height
    section.children = {}

    section.title = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    section.title:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    section.title:SetWidth(width)
    section.title:SetJustifyH("LEFT")
    section.title:SetTextColor(GOLD_TEXT.r, GOLD_TEXT.g, GOLD_TEXT.b)
    section.title:SetText(title)

    section.divider = section:CreateTexture(nil, "ARTWORK")
    section.divider:SetHeight(1)
    section.divider:SetPoint("TOPLEFT", section, "TOPLEFT", 0, -18)
    section.divider:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, -18)
    section.divider:SetColorTexture(0.72, 0.49, 0.18, 0.42)

    section.content = CreateFrame("Frame", nil, section)
    section.content:SetPoint("TOPLEFT", section, "TOPLEFT", 0, -RUN_LAYOUT.SECTION_CONTENT_TOP)
    section.content:SetPoint("BOTTOMRIGHT", section, "BOTTOMRIGHT", 0, 0)

    function section:Refresh()
        self:SetHeight(self.fixedHeight)
        self.content:Show()
        self.divider:Show()
        for _, child in ipairs(self.children) do
            child:SetShown(child.softcoreDesiredShown ~= false)
        end
    end

    section:Refresh()
    return section
end

local function RegisterRunControl(start, control, section)
    table.insert(start.controls, control)
    if section then
        table.insert(section.children, control)
        control.softcoreRunSection = section
    end
    return control
end

local function SetRunControlShown(control, shown)
    if not control then return end
    control.softcoreDesiredShown = shown
    control:SetShown(shown)
end

local function RefreshRunSections(start)
    if not start or not start.sections then return end
    for _, section in ipairs(start.sections) do
        section:Refresh()
    end
    if start.charterSection then
        local function place(section, x, y)
            if not section then return y end
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", start.panel, "TOPLEFT", x, y)
            return y - section:GetHeight() - RUN_LAYOUT.SECTION_GAP
        end

        start.charterSection:ClearAllPoints()
        start.charterSection:SetPoint("TOPLEFT", start.panel, "TOPLEFT", 0, 0)

        local bodyY = -start.charterSection:GetHeight() - RUN_LAYOUT.SECTION_GAP
        local leftY = bodyY
        leftY = place(start.accessSection, 0, leftY)
        place(start.travelSection, 0, leftY)

        local rightY = bodyY
        rightY = place(start.gearSection, RUN_LAYOUT.RIGHT_COLUMN_X, rightY)
        place(start.partyDungeonSection, RUN_LAYOUT.RIGHT_COLUMN_X, rightY)
    end
end

local function SetCardValue(card, value, detail, color)
    if not card then return end
    card.value:SetText(tostring(value or ""))
    if card.detail then
        card.detail:SetText(tostring(detail or ""))
        if detail and detail ~= "" then
            card.detail:Show()
        else
            card.detail:Hide()
        end
    end
    color = color or BODY_TEXT
    card.value:SetTextColor(color.r, color.g, color.b)
    SetOverviewCardTone(card, color)
end

local completionAwardFrame

local function CleanAwardText(fontString)
    if not fontString then return fontString end
    if fontString.SetShadowColor then
        fontString:SetShadowColor(0, 0, 0, 0)
    end
    if fontString.SetShadowOffset then
        fontString:SetShadowOffset(0, 0)
    end
    return fontString
end

local function CreateAwardFont(parent, template, width, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetWidth(width or 360)
    fs:SetJustifyH(justify or "CENTER")
    fs:SetTextColor(0.18, 0.105, 0.035)
    return CleanAwardText(fs)
end

local function FormatAwardCharacter(award)
    local name = tostring(award and award.characterName or "Unknown")
    local realm = tostring(award and award.realm or "")
    if realm ~= "" and realm ~= "Unknown" then
        return name .. "-" .. realm
    end
    return name
end

local function FormatAwardRules(award)
    local label = tostring(award and (award.presetLabel or award.preset) or "Custom")
    if award and award.rulesetModified then
        if award.rulesetModifiedAtLevel then
            return label .. ", amended at level " .. tostring(award.rulesetModifiedAtLevel)
        end
        return label .. ", amended"
    end
    return label .. ", original terms"
end

local AWARD_LAYOUT = {
    panelWidth        = 620,
    panelHeight       = 620,
    innerPad          = 30,
    contentWidth      = 520,
    labelWidth        = 116,
    labelValueGap     = 14,
    rowHeight         = 18,
    rowGap            = 6,
    sectionGap        = 12,
    headerTop         = -22,
    headerIconBox     = 56,
    headerIconInner   = 46,
    headerToKicker    = 10,
    kickerToTitle     = 4,
    titleToCharacter  = 8,
    characterToSub    = 4,
    subToDivider      = 14,
    afterDivider      = 12,
    beforeFooter      = 14,
    afterFooter       = 12,
    dividerWidth      = 500,
    dividerThickness  = 1,
    sectionRule       = 380,
    pageBorderSize    = 2,
    stampDiameter     = 90,
    stampRingPx       = 1,
    stampBorderInset  = 26,
}

local AWARD_COLORS = {
    label    = { 0.42, 0.20, 0.04 },
    value    = { 0.16, 0.08, 0.02 },
    title    = { 0.30, 0.12, 0.025 },
    kicker   = { 0.42, 0.22, 0.06 },
    muted    = { 0.50, 0.32, 0.10 },
    border   = { 0.28, 0.15, 0.045, 0.76 },
    divider  = { 0.50, 0.24, 0.06, 0.45 },
    rule     = { 0.45, 0.22, 0.05, 0.18 },
    stamp    = { 0.65, 0.10, 0.08, 0.95 },
    parchment = { 0.93, 0.78, 0.50, 1.0 },
}

local AWARD_CIRCLE_TEXTURE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function CreateAwardRow(parent, label, valueWidth)
    local L = AWARD_LAYOUT
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(L.contentWidth, L.rowHeight)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.label:SetWidth(L.labelWidth)
    row.label:SetJustifyH("LEFT")
    row.label:SetTextColor(unpack(AWARD_COLORS.label))
    row.label:SetText(string.upper(label))
    CleanAwardText(row.label)

    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.value:SetPoint("TOPLEFT", row.label, "TOPRIGHT", L.labelValueGap, 1)
    row.value:SetWidth(valueWidth or (L.contentWidth - L.labelWidth - L.labelValueGap))
    row.value:SetJustifyH("LEFT")
    row.value:SetTextColor(unpack(AWARD_COLORS.value))
    CleanAwardText(row.value)
    return row
end

local function CreateAwardPageBorder(parent)
    local L = AWARD_LAYOUT
    local C = AWARD_COLORS.border
    local size = L.pageBorderSize

    parent.borderTop = parent:CreateTexture(nil, "BACKGROUND")
    parent.borderTop:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    parent.borderTop:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    parent.borderTop:SetHeight(size)
    parent.borderTop:SetColorTexture(unpack(C))

    parent.borderBottom = parent:CreateTexture(nil, "BACKGROUND")
    parent.borderBottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    parent.borderBottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    parent.borderBottom:SetHeight(size)
    parent.borderBottom:SetColorTexture(unpack(C))

    parent.borderLeft = parent:CreateTexture(nil, "BACKGROUND")
    parent.borderLeft:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    parent.borderLeft:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    parent.borderLeft:SetWidth(size)
    parent.borderLeft:SetColorTexture(unpack(C))

    parent.borderRight = parent:CreateTexture(nil, "BACKGROUND")
    parent.borderRight:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    parent.borderRight:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    parent.borderRight:SetWidth(size)
    parent.borderRight:SetColorTexture(unpack(C))
end

local function AnchorRowBelow(row, prev, gap)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -(gap or AWARD_LAYOUT.rowGap))
end

local function CreateAwardSectionRule(parent, anchorBelow, gap)
    local rule = parent:CreateTexture(nil, "BACKGROUND")
    rule:SetSize(AWARD_LAYOUT.sectionRule, 1)
    rule:SetPoint("TOP", anchorBelow, "BOTTOM", 0, -(gap or AWARD_LAYOUT.sectionGap))
    rule:SetColorTexture(unpack(AWARD_COLORS.rule))
    return rule
end

local function CreateAwardCircle(parent, size, color, layer, sublevel)
    local tex = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
    tex:SetTexture(AWARD_CIRCLE_TEXTURE)
    tex:SetSize(size, size)
    tex:SetPoint("CENTER", parent, "CENTER", 0, 0)
    tex:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    return tex
end

local function FormatAwardDate(timestamp)
    if not timestamp then return "—" end
    return date("%Y-%m-%d", timestamp)
end

local function FormatAwardDateTime(timestamp)
    if not timestamp then return "—" end
    return date("%Y-%m-%d %H:%M", timestamp)
end

local function FormatAwardHash(hash)
    local s = tostring(hash or "")
    if s == "" then return "—" end
    if #s > 12 then return string.sub(s, 1, 12) end
    return s
end

local function FormatAwardRunId(award)
    return tostring(award and (award.runId or award.id) or "—")
end

local function FormatAwardAddonVersion()
    local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    local v = meta and meta("Softcore", "Version") or nil
    if not v or v == "" then return "Softcore" end
    return "Softcore v" .. tostring(v)
end

local function FormatAwardViolations(award)
    local total = tonumber(award and award.totalViolations or 0) or 0
    local cleared = tonumber(award and award.clearedViolations or 0) or 0
    local active = tonumber(award and award.activeViolations or (total - cleared)) or 0
    if total == 0 then
        return "none logged - clean ledger"
    end
    return string.format("%d logged - %d cleared - %d unresolved", total, cleared, active)
end

local function FormatAwardDungeons(award)
    local n = tonumber(award and award.dungeonCount or 0) or 0
    if n == 0 then return "none recorded" end
    if n == 1 then return "1 instance recorded" end
    return tostring(n) .. " instances recorded"
end

local function FormatAwardLevelDate(level, timestamp)
    return "Lv " .. tostring(level or "?") .. "   " .. FormatAwardDate(timestamp)
end

local function FormatAwardLevelDateTime(level, timestamp)
    return "Lv " .. tostring(level or "?") .. "   " .. FormatAwardDateTime(timestamp)
end

local function EnsureCompletionAwardFrame()
    if completionAwardFrame then
        return completionAwardFrame
    end

    local L = AWARD_LAYOUT
    local C = AWARD_COLORS

    local frame = CreateFrame("Frame", "SoftcoreCompletionAwardFrame", UIParent, "BackdropTemplate")
    frame:SetSize(L.panelWidth, L.panelHeight)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile = false,
        edgeSize = 32,
        insets = { left = 10, right = 10, top = 10, bottom = 10 },
    })
    frame:SetBackdropColor(0.78, 0.62, 0.36, 1.0)
    frame:SetBackdropBorderColor(0.72, 0.43, 0.12, 1)

    frame.inner = CreateFrame("Frame", nil, frame)
    frame.inner:SetPoint("TOPLEFT", frame, "TOPLEFT", L.innerPad, -L.innerPad - 2)
    frame.inner:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -L.innerPad, L.innerPad + 2)
    CreateAwardPageBorder(frame.inner)

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)

    -- Header: trophy icon, kicker, title, character, subtitle
    frame.headerIconFrame = CreateFrame("Frame", nil, frame.inner, "BackdropTemplate")
    frame.headerIconFrame:SetSize(L.headerIconBox, L.headerIconBox)
    frame.headerIconFrame:SetPoint("TOP", frame.inner, "TOP", 0, L.headerTop)
    frame.headerIconFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame.headerIconFrame:SetBackdropColor(0.30, 0.16, 0.04, 0.88)
    frame.headerIconFrame:SetBackdropBorderColor(0.78, 0.54, 0.18, 0.95)
    frame.headerIcon = frame.headerIconFrame:CreateTexture(nil, "ARTWORK")
    frame.headerIcon:SetSize(L.headerIconInner, L.headerIconInner)
    frame.headerIcon:SetPoint("CENTER", frame.headerIconFrame, "CENTER", 0, 0)
    frame.headerIcon:SetTexture("Interface\\Icons\\INV_Misc_Trophy_Argent")
    frame.headerIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    frame.kicker = CreateAwardFont(frame.inner, "GameFontNormalSmall", L.contentWidth)
    frame.kicker:SetPoint("TOP", frame.headerIconFrame, "BOTTOM", 0, -L.headerToKicker)
    frame.kicker:SetTextColor(unpack(C.kicker))
    frame.kicker:SetText("SOFTCORE CERTIFICATE OF COMPLETION")

    frame.title = CreateAwardFont(frame.inner, "GameFontNormalHuge", L.contentWidth)
    frame.title:SetPoint("TOP", frame.kicker, "BOTTOM", 0, -L.kickerToTitle)
    frame.title:SetTextColor(unpack(C.title))
    frame.title:SetText("Max Level Reached")

    frame.character = CreateAwardFont(frame.inner, "GameFontNormalLarge", L.contentWidth)
    frame.character:SetPoint("TOP", frame.title, "BOTTOM", 0, -L.titleToCharacter)
    frame.character:SetTextColor(unpack(C.value))

    frame.subtitle = CreateAwardFont(frame.inner, "GameFontHighlight", L.contentWidth)
    frame.subtitle:SetPoint("TOP", frame.character, "BOTTOM", 0, -L.characterToSub)
    frame.subtitle:SetTextColor(unpack(C.muted))

    frame.dividerTop = frame.inner:CreateTexture(nil, "ARTWORK")
    frame.dividerTop:SetPoint("TOP", frame.subtitle, "BOTTOM", 0, -L.subToDivider)
    frame.dividerTop:SetSize(L.dividerWidth, L.dividerThickness)
    frame.dividerTop:SetColorTexture(unpack(C.divider))

    frame.rows = {}
    frame.rows.run        = CreateAwardRow(frame.inner, "Run")
    frame.rows.ruleset    = CreateAwardRow(frame.inner, "Ruleset")
    frame.rows.started    = CreateAwardRow(frame.inner, "Started")
    frame.rows.completed  = CreateAwardRow(frame.inner, "Completed")
    frame.rows.activeTime = CreateAwardRow(frame.inner, "Active Time")
    frame.rows.violations = CreateAwardRow(frame.inner, "Violations")
    frame.rows.dungeons   = CreateAwardRow(frame.inner, "Dungeons")

    local function centerRow(row, anchorTo, anchorPoint, yOffset)
        row:ClearAllPoints()
        row:SetPoint("TOP", anchorTo, anchorPoint, 0, yOffset)
    end

    centerRow(frame.rows.run, frame.dividerTop, "BOTTOM", -L.afterDivider)
    AnchorRowBelow(frame.rows.ruleset, frame.rows.run)

    frame.rule1 = CreateAwardSectionRule(frame.inner, frame.rows.ruleset)
    centerRow(frame.rows.started, frame.rule1, "BOTTOM", -L.afterDivider)
    AnchorRowBelow(frame.rows.completed, frame.rows.started)
    AnchorRowBelow(frame.rows.activeTime, frame.rows.completed)

    frame.rule2 = CreateAwardSectionRule(frame.inner, frame.rows.activeTime)
    centerRow(frame.rows.violations, frame.rule2, "BOTTOM", -L.afterDivider)
    AnchorRowBelow(frame.rows.dungeons, frame.rows.violations)

    frame.dividerBottom = frame.inner:CreateTexture(nil, "ARTWORK")
    frame.dividerBottom:SetPoint("TOP", frame.rows.dungeons, "BOTTOM", 0, -L.beforeFooter)
    frame.dividerBottom:SetSize(L.dividerWidth, L.dividerThickness)
    frame.dividerBottom:SetColorTexture(unpack(C.divider))

    -- Verification footer rows (muted)
    frame.rows.runId = CreateAwardRow(frame.inner, "Run ID")
    frame.rows.hash  = CreateAwardRow(frame.inner, "Hash")
    frame.rows.addon = CreateAwardRow(frame.inner, "Addon")

    centerRow(frame.rows.runId, frame.dividerBottom, "BOTTOM", -L.afterFooter)
    AnchorRowBelow(frame.rows.hash, frame.rows.runId)
    AnchorRowBelow(frame.rows.addon, frame.rows.hash)

    for _, key in ipairs({ "runId", "hash", "addon" }) do
        local r = frame.rows[key]
        r.label:SetTextColor(unpack(C.muted))
        r.value:SetTextColor(unpack(C.muted))
    end

    -- Circular notary stamp centered on the page border, like a real seal
    -- pressed onto the certificate edge.
    frame.stamp = CreateFrame("Frame", nil, frame)
    frame.stamp:SetSize(L.stampDiameter, L.stampDiameter)
    frame.stamp:SetPoint("CENTER", frame.inner, "BOTTOMRIGHT",
        -L.stampBorderInset, L.stampBorderInset)
    frame.stamp:SetFrameLevel(frame.inner:GetFrameLevel() + 8)

    -- Two layered alpha-mask circles produce a restrained red ring with the
    -- parchment showing through the center.
    frame.stampRing = CreateAwardCircle(frame.stamp,
        L.stampDiameter, C.stamp, "ARTWORK", 1)
    frame.stampFill = CreateAwardCircle(frame.stamp,
        L.stampDiameter - L.stampRingPx * 2, C.parchment, "ARTWORK", 2)

    frame.stampTopText = frame.stamp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.stampTopText:SetPoint("CENTER", frame.stamp, "CENTER", 0, 12)
    frame.stampTopText:SetTextColor(unpack(C.stamp))
    frame.stampTopText:SetText("SOFTCORE")
    frame.stampTopText:SetJustifyH("CENTER")
    CleanAwardText(frame.stampTopText)
    if frame.stampTopText.SetRotation then
        frame.stampTopText:SetRotation(math.rad(-8))
    end

    frame.stampStar = frame.stamp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.stampStar:SetPoint("CENTER", frame.stamp, "CENTER", 0, -1)
    frame.stampStar:SetTextColor(unpack(C.stamp))
    frame.stampStar:SetText("* * *")
    frame.stampStar:SetJustifyH("CENTER")
    CleanAwardText(frame.stampStar)
    if frame.stampStar.SetRotation then
        frame.stampStar:SetRotation(math.rad(-8))
    end

    frame.stampBottomText = frame.stamp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.stampBottomText:SetPoint("CENTER", frame.stamp, "CENTER", 0, -14)
    frame.stampBottomText:SetTextColor(unpack(C.stamp))
    frame.stampBottomText:SetText("CERTIFIED")
    frame.stampBottomText:SetJustifyH("CENTER")
    CleanAwardText(frame.stampBottomText)
    if frame.stampBottomText.SetRotation then
        frame.stampBottomText:SetRotation(math.rad(-8))
    end

    frame:Hide()
    completionAwardFrame = frame
    return frame
end

function SC:ShowCompletionAward(award)
    award = award or (self.GetCompletionAward and self:GetCompletionAward()) or nil
    if not award then
        Print("No completion award is available for this character.")
        return
    end

    local frame = EnsureCompletionAwardFrame()

    frame.character:SetText(FormatAwardCharacter(award))
    frame.subtitle:SetText(tostring(award.classLabel or award.class or "Adventurer") .. "   reached Level " .. tostring(award.completedLevel or "?"))

    frame.rows.run.value:SetText(tostring(award.runName or "Softcore Run"))
    frame.rows.ruleset.value:SetText(FormatAwardRules(award))
    frame.rows.started.value:SetText(FormatAwardLevelDate(award.startLevel, award.startedAt))
    frame.rows.completed.value:SetText(FormatAwardLevelDateTime(award.completedLevel, award.completedAt))
    frame.rows.activeTime.value:SetText(FormatDuration(award.activeTimeSeconds) .. "   addon-observed")
    frame.rows.violations.value:SetText(FormatAwardViolations(award))
    frame.rows.dungeons.value:SetText(FormatAwardDungeons(award))

    frame.rows.runId.value:SetText(FormatAwardRunId(award))
    frame.rows.hash.value:SetText(FormatAwardHash(award.rulesetHash))
    frame.rows.addon.value:SetText(FormatAwardAddonVersion())

    -- footer rows are smaller / muted
    for _, key in ipairs({ "runId", "hash", "addon" }) do
        local row = frame.rows[key]
        row.label:SetTextColor(unpack(AWARD_FOOTER_COLOR))
        row.value:SetTextColor(unpack(AWARD_FOOTER_COLOR))
    end

    frame:Show()
end

local function SetRegionShown(region, shown)
    if not region then return end
    if region.SetShown then
        region:SetShown(shown)
    elseif shown then
        region:Show()
    else
        region:Hide()
    end
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
    dropdown.softcoreSelectedValue = selectedValue
    UIDropDownMenu_SetWidth(dropdown, width or 145)
    UIDropDownMenu_SetText(dropdown, GetOptionText(options, selectedValue))
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        for _, option in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.checked = dropdown.softcoreSelectedValue == option.value
            info.isNotRadio = false
            info.keepShownOnClick = false
            info.func = function()
                dropdown.softcoreSelectedValue = option.value
                UIDropDownMenu_SetText(dropdown, option.text)
                onSelect(option.value)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    return dropdown
end

local function SetDropdownSelected(dropdown, options, value)
    if not dropdown then return end
    dropdown.softcoreSelectedValue = value
    UIDropDownMenu_SetText(dropdown, GetOptionText(options, value))
end

local STATUS_RGB = {
    VALID = GREEN_TEXT,
    ACTIVE = GREEN_TEXT,
    FAILED = RED_TEXT,
    BLOCKED = GOLD_TEXT,
    CONFLICT = GOLD_TEXT,
    VIOLATION = GOLD_TEXT,
    WARNING = GOLD_TEXT,
    UNSYNCED = MUTED_TEXT,
    INACTIVE = MUTED_TEXT,
    NOT_IN_RUN = MUTED_TEXT,
    OUT_OF_PARTY = MUTED_TEXT,
    RETIRED = ORANGE_TEXT,
    RUN_MISMATCH = GOLD_TEXT,
    RULESET_MISMATCH = GOLD_TEXT,
    ADDON_VERSION_MISMATCH = GOLD_TEXT,
    RAID_UNSUPPORTED = GOLD_TEXT,
}

local STATUS_LABELS = {
    VALID = "Valid",
    ACTIVE = "Valid",
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
    RAID_UNSUPPORTED = "Raid Local Only",
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

local function GetStatusBase(statusStr)
    return string.match(tostring(statusStr or ""), "^(%u+)") or tostring(statusStr or "")
end

local function CreateStatusPill(parent, x, y, width)
    local pill = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    pill:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    pill:SetSize(width or 132, 25)
    if pill.SetBackdrop then
        pill:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 12,
            edgeSize = 10,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
    end

    pill.text = pill:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pill.text:SetPoint("CENTER", pill, "CENTER", 0, 0)
    pill.text:SetWidth((width or 132) - 16)
    pill.text:SetJustifyH("CENTER")

    return pill
end

local function SetStatusPill(pill, status, prefix)
    if not pill then return end

    local base = GetStatusBase(status)
    local color = STATUS_RGB[base] or BODY_TEXT
    pill.text:SetText((prefix or "") .. FriendlyStatus(status))
    pill.text:SetTextColor(color.r, color.g, color.b)
    if pill.SetBackdropColor then
        pill:SetBackdropColor(color.r * 0.16, color.g * 0.12, color.b * 0.08, 0.9)
        pill:SetBackdropBorderColor(color.r, color.g, color.b, 0.85)
    end
end

local function IsDisallowed(value)
    return value ~= nil and value ~= "ALLOWED" and value ~= "LOG_ONLY"
end

local function SetDisallowedRule(rules, key, checked)
    rules[key] = checked and "ALLOWED" or DISALLOWED_OUTCOME
end

local function IsCameraRuleEnforced(rules)
    return IsDisallowed(rules and rules.actionCam)
end

local function SetCameraRules(rules, mode)
    if mode == "CINEMATIC" then
        rules.actionCam = DISALLOWED_OUTCOME
    else
        rules.actionCam = "ALLOWED"
    end
end

local function GetSelectedCameraMode(start)
    if start.selectedCameraMode then return start.selectedCameraMode end
    if IsDisallowed(start.selectedRules.actionCam) then return "CINEMATIC" end
    return nil
end

local function SetFontStringRGB(fontString, color)
    fontString:SetTextColor(color.r, color.g, color.b)
end

local function IsCheckedRuleValue(ruleName, value)
    if ruleName == "groupingMode" or ruleName == "gearQuality" or ruleName == "maxLevelGapValue" then
        return nil
    end
    if ruleName == "maxLevelGap" or ruleName == "actionCam" then
        return value ~= "ALLOWED"
    end
    return not IsDisallowed(value)
end

local function CreateAllowCheckbox(parent, rules, spec, x, y)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    checkbox:SetHitRectInsets(0, -250, 0, 0)
    checkbox.label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", RUN_LAYOUT.CHECKBOX_LABEL_GAP, 0)
    checkbox.label:SetWidth(0)
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
    if spec.tooltip then
        SetAuditRowTooltip(checkbox, spec.label, spec.tooltip)
    end
    return checkbox
end

local function CreateDeathAnnounceCheckbox(parent, channel, label, x, y)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    checkbox.channel = channel
    checkbox.label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
    checkbox.label:SetTextColor(BODY_TEXT.r, BODY_TEXT.g, BODY_TEXT.b)
    checkbox.label:SetText(label)
    checkbox:SetScript("OnClick", function(self)
        if SC.SetDeathAnnouncementChannel then
            SC:SetDeathAnnouncementChannel(self.channel, self:GetChecked())
        end
        if SC.MasterUI_Refresh then
            SC:MasterUI_Refresh()
        end
    end)
    return checkbox
end

local function ConfigureRulesForPreset(rules, preset)
    local ironman = preset == "IRONMAN" or preset == "IRON_VIGIL"
    local ironVigil = preset == "IRON_VIGIL"
    local chef = preset == "CHEF_SPECIAL"
    local selectedCameraMode = nil

    rules.groupingMode = ironman and "SOLO_SELF_FOUND" or "SYNCED_GROUP_ALLOWED"
    rules.gearQuality = (ironman or chef) and "WHITE_GRAY_ONLY" or "ALLOWED"
    rules.selfCraftedGearAllowed = ironman and false or true
    rules.maxLevelGap = ironman and DISALLOWED_OUTCOME or "ALLOWED"
    rules.maxLevelGapValue = 3
    rules.heirlooms = DISALLOWED_OUTCOME
    rules.enchants = ironman and DISALLOWED_OUTCOME or "ALLOWED"
    rules.dungeonRepeat = ironman and DISALLOWED_OUTCOME or "ALLOWED"
    rules.instanceWithUnsyncedPlayers = "ALLOWED"
    rules.unsyncedMembers = "ALLOWED"

    for _, spec in ipairs(ECONOMY_RULES) do
        SetDisallowedRule(rules, spec.key, not (ironman or spec.key == "auctionHouse" or spec.key == "mailbox" or spec.key == "trade" or spec.key == "bank" or spec.key == "warbandBank" or spec.key == "guildBank"))
    end

    for _, spec in ipairs(MOVEMENT_RULES) do
        SetDisallowedRule(rules, spec.key, not ironman)
    end
    if ironman then
        rules.flightPaths = "ALLOWED"
    end
    if ironVigil then
        rules.flightPaths = DISALLOWED_OUTCOME
    end

    SetDisallowedRule(rules, "consumables", not ironman)
    SetDisallowedRule(rules, "instancedPvP", false)
    rules.actionCam = "ALLOWED"

    if chef then
        rules.auctionHouse = DISALLOWED_OUTCOME
        rules.mailbox = "ALLOWED"
        rules.trade = "ALLOWED"
        rules.bank = "ALLOWED"
        rules.warbandBank = DISALLOWED_OUTCOME
        rules.guildBank = DISALLOWED_OUTCOME
        rules.mounts = "ALLOWED"
        rules.flying = DISALLOWED_OUTCOME
        rules.flightPaths = "ALLOWED"
        rules.heirlooms = DISALLOWED_OUTCOME
        rules.enchants = "ALLOWED"
        rules.consumables = "ALLOWED"
        rules.dungeonRepeat = "ALLOWED"
        rules.instancedPvP = DISALLOWED_OUTCOME
        selectedCameraMode = "CINEMATIC"
        SetCameraRules(rules, selectedCameraMode)
    elseif not ironman then
        -- Casual: minimal restrictions for a lightweight baseline run.
        rules.auctionHouse = "ALLOWED"
        rules.mailbox = "ALLOWED"
        rules.trade = "ALLOWED"
        rules.bank = "ALLOWED"
        rules.warbandBank = "ALLOWED"
        rules.guildBank = "ALLOWED"
        rules.heirlooms = "ALLOWED"
        rules.selfCraftedGearAllowed = false
    end

    if ironVigil then
        selectedCameraMode = "CINEMATIC"
        SetCameraRules(rules, selectedCameraMode)
    end

    rules.maxDeaths = false
    rules.maxDeathsValue = rules.maxDeathsValue or 3
    rules.achievementPreset = preset

    if SC.ApplyGroupingMode then
        SC:ApplyGroupingMode(rules)
    end

    return selectedCameraMode
end

local function ApplyStartPreset(frame, preset)
    local rules = frame.start.selectedRules
    frame.start.selectedPreset = preset
    frame.start.selectedCameraMode = ConfigureRulesForPreset(rules, preset)

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

local function BuildAmendmentReviewRules(baseRules, amendment)
    local rules = SC:CopyTable(baseRules or {})
    for ruleName, value in pairs(amendment and amendment.newRules or {}) do
        rules[ruleName] = value
    end
    return rules
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
    selfCraftedGearAllowed = "Self-crafted Gear Exemption",
    heirlooms      = "Heirlooms",
    enchants       = "Enchants",
    maxLevelGap    = "Level Gap Enforcement",
    maxLevelGapValue = "Max Level Gap",
    dungeonRepeat  = "Repeated Dungeons",
    consumables    = "Consumables",
    instancedPvP   = "Instanced PvP",
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
    if ruleName == "selfCraftedGearAllowed" then
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
        class = db and db.character and db.character.class,
        status = localStatus.participantStatus or "NOT_IN_RUN",
        totalViolations = CountAllViolations(localKey),
        isLocal = true,
    })
    seen[localKey] = true

    if IsInRaid() then
        return displayRows
    end

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

        if peerKey and not seen[peerKey] and #displayRows < OVERVIEW_PARTY_ROWS then
            local pRow = participants[peerKey]
            local pStart = pRow and pRow.levelAtJoin
            local startLevel = (tonumber(pStart) and tonumber(pStart) > 0) and pStart or peer.levelAtJoin
            table.insert(displayRows, {
                name = peer.name or peer.playerKey or "Unknown",
                level = peer.level,
                startLevel = startLevel,
                class = peer.class or (pRow and pRow.class),
                status = displayStatus,
                totalViolations = CountAllViolations(peer.playerKey or ""),
            })
            seen[peerKey] = true
        end
    end

    for _, participantKey in ipairs(participantOrder) do
        if participantKey ~= localKey and not seen[participantKey] and #displayRows < OVERVIEW_PARTY_ROWS then
            local participant = participants[participantKey]
            if participant then
                table.insert(displayRows, {
                    name = participant.playerKey,
                    level = participant.currentLevel,
                    startLevel = participant.levelAtJoin,
                    class = participant.class,
                    status = tostring(participant.status or "UNKNOWN"),
                    totalViolations = CountAllViolations(participantKey),
                })
                seen[participantKey] = true
            end
        end
    end

    return displayRows
end

local function GetOverviewStatusColor(status)
    local base = GetStatusBase(status)
    return STATUS_RGB[base] or BODY_TEXT
end

local function FormatTotalViolations(count)
    count = tonumber(count or 0) or 0
    return tostring(count) .. (count == 1 and " total violation" or " total violations")
end

local function BuildPresetRuleset(preset)
    local rules = SC.GetDefaultRuleset and SC:GetDefaultRuleset() or {}
    ConfigureRulesForPreset(rules, preset)
    return rules
end

local function RulesMatchPreset(rules, preset)
    if not rules then return false end

    local presetRules = BuildPresetRuleset(preset)
    if SC.DescribeRulesetDifferences then
        return #SC:DescribeRulesetDifferences(presetRules, rules) == 0
    end

    return rules.achievementPreset == preset
end

local function DetectRulesetPreset(rules)
    for _, preset in ipairs(PRESET_ORDER) do
        if RulesMatchPreset(rules, preset) then
            return preset
        end
    end
    return nil
end

local function FormatOverviewRunTitle(run)
    local preset = DetectRulesetPreset(run and run.ruleset)
    return PRESET_DISPLAY[preset] or "Custom Run"
end

local function FormatOverviewRunDetail(run)
    if run and run.rulesetModified == false then
        return "Unmodified"
    end

    local version = tonumber(run and run.ruleset and run.ruleset.version) or 1
    local level = tonumber(run and run.rulesetModifiedAtLevel)
    if run and run.rulesetModified ~= true and version <= 1 and not level then
        return "Unmodified"
    end
    if level and level > 0 then
        return "Modified at level " .. tostring(level)
    end
    return "Modified"
end

local function GetClassColor(classFile)
    classFile = tostring(classFile or "")
    local colors = (_G and _G.RAID_CLASS_COLORS) or RAID_CLASS_COLORS
    local color = colors and colors[classFile] or CLASS_COLORS[classFile]
    if color then
        return { r = color.r or 0.68, g = color.g or 0.56, b = color.b or 0.38 }
    end
    return MUTED_TEXT
end

local function FormatClassName(classFile)
    classFile = tostring(classFile or "")
    if classFile == "" or classFile == "UNKNOWN" then
        return "Class"
    end
    local localized = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile]
    if localized and localized ~= "" then
        return localized
    end
    if CLASS_LABELS[classFile] then
        return CLASS_LABELS[classFile]
    end
    local text = string.lower(classFile)
    text = string.gsub(text, "(%a)([%w']*)", function(first, rest)
        return string.upper(first) .. rest
    end)
    return text
end

local function SetOverviewBadgeTone(badge, text, color)
    if not badge then return end
    color = color or BODY_TEXT
    badge.text:SetText(tostring(text or ""))
    badge.text:SetTextColor(color.r, color.g, color.b)
    if badge.SetBackdropColor then
        badge:SetBackdropColor(color.r * 0.12, color.g * 0.09, color.b * 0.06, 0.9)
        badge:SetBackdropBorderColor(color.r, color.g, color.b, 0.82)
    end
end

local function CalculateOverviewLedgerHeight(rowCount)
    rowCount = math.min(math.max(tonumber(rowCount or 1) or 1, 1), OVERVIEW_PARTY_ROWS)
    return OVERVIEW_LAYOUT.LEDGER_INSET
        + OVERVIEW_LAYOUT.LEDGER_HEADER_HEIGHT
        + (rowCount * OVERVIEW_LAYOUT.LEDGER_ROW_HEIGHT)
        + ((rowCount - 1) * OVERVIEW_LAYOUT.LEDGER_ROW_GAP)
        + OVERVIEW_LAYOUT.LEDGER_INSET
end

local function ApplyOverviewSectionBackdrop(section, borderAlpha)
    if not section or not section.SetBackdrop then return end

    section:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    section:SetBackdropColor(0.07, 0.042, 0.018, 0.88)
    section:SetBackdropBorderColor(0.68, 0.50, 0.20, borderAlpha or 0.82)
end

local function CreateOverviewSectionHeader(section, titleText)
    local inset = OVERVIEW_LAYOUT.SECTION_INSET

    section.title = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    section.title:SetPoint("TOPLEFT", section, "TOPLEFT", inset, OVERVIEW_LAYOUT.SECTION_TITLE_TOP)
    section.title:SetWidth(240)
    section.title:SetJustifyH("LEFT")
    section.title:SetTextColor(GOLD_TEXT.r, GOLD_TEXT.g, GOLD_TEXT.b)
    section.title:SetText(titleText)

    section.divider = section:CreateTexture(nil, "ARTWORK")
    section.divider:SetHeight(1)
    section.divider:SetPoint("TOPLEFT", section, "TOPLEFT", inset, OVERVIEW_LAYOUT.SECTION_DIVIDER_TOP)
    section.divider:SetPoint("TOPRIGHT", section, "TOPRIGHT", -inset, OVERVIEW_LAYOUT.SECTION_DIVIDER_TOP)
    section.divider:SetColorTexture(0.72, 0.49, 0.18, 0.34)
end

local function CreateOverviewSmallBadge(parent, width, height)
    local badge = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    badge:SetSize(width or 72, height or 24)
    if badge.SetBackdrop then
        badge:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 12,
            edgeSize = 10,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        badge:SetBackdropColor(0.08, 0.045, 0.018, 0.88)
        badge:SetBackdropBorderColor(0.68, 0.48, 0.18, 0.75)
    end

    badge.text = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badge.text:SetPoint("CENTER", badge, "CENTER", 0, 0)
    badge.text:SetWidth((width or 72) - 12)
    badge.text:SetJustifyH("CENTER")
    return badge
end

local function SetOverviewSmallBadge(badge, text, color)
    SetOverviewBadgeTone(badge, text, color)
end

local function CreateOverviewPartyRow(parent, index, width)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetSize(width, OVERVIEW_LAYOUT.LEDGER_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * (OVERVIEW_LAYOUT.LEDGER_ROW_HEIGHT + OVERVIEW_LAYOUT.LEDGER_ROW_GAP)))
    if row.SetBackdrop then
        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 12,
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        row:SetBackdropColor(0.07, 0.045, 0.022, 0.82)
        row:SetBackdropBorderColor(0.45, 0.34, 0.16, 0.7)
    end

    row.accent = row:CreateTexture(nil, "ARTWORK")
    row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -3)
    row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 3, 3)
    row.accent:SetWidth(3)
    row.accent:SetColorTexture(GREEN_TEXT.r, GREEN_TEXT.g, GREEN_TEXT.b, 0.9)
    row.accentWarning = row:CreateTexture(nil, "ARTWORK")
    row.accentWarning:SetWidth(3)
    row.accentWarning:SetColorTexture(GOLD_TEXT.r, GOLD_TEXT.g, GOLD_TEXT.b, 0.95)
    row.accentWarning:Hide()

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -7)
    row.name:SetWidth(220)
    row.name:SetJustifyH("LEFT")
    row.name:SetTextColor(BODY_TEXT.r, BODY_TEXT.g, BODY_TEXT.b)
    row.name:SetWordWrap(false)

    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.meta:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -26)
    row.meta:SetWidth(220)
    row.meta:SetJustifyH("LEFT")
    row.meta:SetTextColor(MUTED_TEXT.r, MUTED_TEXT.g, MUTED_TEXT.b)
    row.meta:SetWordWrap(false)

    local badgeWidth = OVERVIEW_LAYOUT.LEDGER_BADGE_WIDTH
    local badgeHeight = OVERVIEW_LAYOUT.LEDGER_BADGE_HEIGHT
    local badgeGap = OVERVIEW_LAYOUT.LEDGER_BADGE_GAP
    local badgeLeft = width - 14 - (badgeWidth * 3) - (badgeGap * 2)
    row.classBadge = CreateOverviewSmallBadge(row, badgeWidth, badgeHeight)
    row.classBadge:SetPoint("TOPLEFT", row, "TOPLEFT", badgeLeft, -10)
    row.statusPill = CreateStatusPill(row, badgeLeft + badgeWidth + badgeGap, -9, badgeWidth)
    row.statusPill:SetHeight(badgeHeight)
    row.totalBadge = CreateOverviewSmallBadge(row, badgeWidth, badgeHeight)
    row.totalBadge:SetPoint("TOPLEFT", row, "TOPLEFT", badgeLeft + ((badgeWidth + badgeGap) * 2), -10)
    row:Hide()
    return row
end

local function CreateOverviewPartyLedger(parent, x, y, width, maxRows)
    local ledger = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    ledger:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    ledger:SetSize(width, CalculateOverviewLedgerHeight(maxRows))
    ApplyOverviewSectionBackdrop(ledger, 0.86)
    CreateOverviewSectionHeader(ledger, "Party Ledger")

    ledger.count = CreateOverviewSmallBadge(ledger, 54, 20)
    ledger.count:SetPoint("TOPRIGHT", ledger, "TOPRIGHT", -OVERVIEW_LAYOUT.SECTION_INSET, -7)

    ledger.rowsFrame = CreateFrame("Frame", nil, ledger)
    ledger.rowsFrame:SetPoint("TOPLEFT", ledger, "TOPLEFT", OVERVIEW_LAYOUT.LEDGER_INSET, -(OVERVIEW_LAYOUT.LEDGER_HEADER_HEIGHT + OVERVIEW_LAYOUT.LEDGER_INSET))
    ledger.rowsFrame:SetSize(width - (OVERVIEW_LAYOUT.LEDGER_INSET * 2), OVERVIEW_LAYOUT.LEDGER_MAX_ROWS_HEIGHT)

    ledger.empty = ledger:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ledger.empty:SetPoint("TOPLEFT", ledger.rowsFrame, "TOPLEFT", 4, -2)
    ledger.empty:SetWidth(width - (OVERVIEW_LAYOUT.LEDGER_INSET * 2) - 8)
    ledger.empty:SetJustifyH("LEFT")
    ledger.empty:SetTextColor(MUTED_TEXT.r, MUTED_TEXT.g, MUTED_TEXT.b)
    ledger.empty:SetText("Waiting for party members to sync.")
    ledger.empty:Hide()

    ledger.rows = {}
    for index = 1, maxRows do
        ledger.rows[index] = CreateOverviewPartyRow(ledger.rowsFrame, index, width - (OVERVIEW_LAYOUT.LEDGER_INSET * 2))
    end

    return ledger
end

local function FormatOverviewLevelText(level, startLevel)
    local current = level and tostring(level) or "?"
    local text = "Level " .. current
    if tonumber(startLevel) and tonumber(startLevel) > 0 then
        text = text .. "  |cffad8f61Started " .. tostring(startLevel) .. "|r"
    end
    return text
end

local function RefreshOverviewLedger(ledger, rows, grouped, inRaid)
    if not ledger then return end

    local visibleRows = math.min(#rows, OVERVIEW_PARTY_ROWS)
    SetOverviewSmallBadge(ledger.count, tostring(visibleRows) .. "/" .. tostring(OVERVIEW_PARTY_ROWS), GOLD_TEXT)
    SetRegionShown(ledger.empty, visibleRows == 0)
    ledger:SetHeight(CalculateOverviewLedgerHeight(OVERVIEW_PARTY_ROWS))

    for index, row in ipairs(ledger.rows) do
        local display = rows[index]
        if display then
            local statusColor = GetOverviewStatusColor(display.status)
            local statusBase = GetStatusBase(display.status)
            local total = tonumber(display.totalViolations or 0) or 0
            local splitAccent = total > 0 and (statusBase == "VALID" or statusBase == "ACTIVE")

            row:Show()
            row.name:SetText((display.isLocal and "|cffffd100" or "") .. Trunc(display.name, 30) .. (display.isLocal and "|r" or ""))
            row.meta:SetText(FormatOverviewLevelText(display.level, display.startLevel))
            SetOverviewBadgeTone(row.classBadge, Trunc(FormatClassName(display.class), 14), GetClassColor(display.class))
            SetStatusPill(row.statusPill, display.status)
            SetOverviewSmallBadge(row.totalBadge, FormatTotalViolations(total), total > 0 and GOLD_TEXT or MUTED_TEXT)
            row.accent:ClearAllPoints()
            if splitAccent then
                row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -3)
                row.accent:SetPoint("BOTTOMLEFT", row, "LEFT", 3, 0)
                row.accentWarning:ClearAllPoints()
                row.accentWarning:SetPoint("TOPLEFT", row, "LEFT", 3, 0)
                row.accentWarning:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 3, 3)
                row.accentWarning:Show()
            else
                row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -3)
                row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 3, 3)
                row.accentWarning:Hide()
            end
            row.accent:SetColorTexture(statusColor.r, statusColor.g, statusColor.b, 0.95)
            if row.SetBackdropColor then
                row:SetBackdropColor(statusColor.r * 0.055, statusColor.g * 0.04, statusColor.b * 0.028, 0.86)
                row:SetBackdropBorderColor(statusColor.r, statusColor.g, statusColor.b, 0.46)
            end
        else
            row:Hide()
        end
    end
end

local function CreateOverviewActivityPanel(parent, x, y, width, height)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    panel:SetSize(width, height)
    ApplyOverviewSectionBackdrop(panel, 0.76)
    CreateOverviewSectionHeader(panel, "Recent Activity")

    panel.rows = {}
    local rowTop = OVERVIEW_LAYOUT.SECTION_DIVIDER_TOP - 4
    local rowLeft = OVERVIEW_LAYOUT.SECTION_INSET
    local rowWidth = width - 24
    local showActorColumn = rowWidth >= 620
    local timeLeft = 12
    local timeWidth = 38
    local kindLeft = 60
    local kindWidth = 96
    local actorLeft = 168
    local actorWidth = 84
    local messageLeft = showActorColumn and 266 or 168
    local messageWidth = rowWidth - messageLeft - 8
    local rowHeight = math.floor((height - math.abs(rowTop) - 8) / OVERVIEW_LAYOUT.ACTIVITY_ROWS)
    for index = 1, OVERVIEW_LAYOUT.ACTIVITY_ROWS do
        local row = CreateFrame("Frame", nil, panel)
        row:SetSize(rowWidth, rowHeight)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", rowLeft, rowTop - ((index - 1) * rowHeight))
        row:EnableMouse(true)
        row.showActorColumn = showActorColumn
        row.tooltipTitle = ""
        row.tooltipBody = ""

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints(row)
        row.bg:SetColorTexture(0.82, 0.58, 0.22, index % 2 == 0 and 0.06 or 0.025)

        row.accent = row:CreateTexture(nil, "ARTWORK")
        row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
        row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 2)
        row.accent:SetWidth(3)
        row.accent:SetColorTexture(GOLD_TEXT.r, GOLD_TEXT.g, GOLD_TEXT.b, 0.9)

        row.time = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.time:SetPoint("LEFT", row, "LEFT", timeLeft, 0)
        row.time:SetWidth(timeWidth)
        row.time:SetJustifyH("LEFT")
        row.time:SetTextColor(MUTED_TEXT.r, MUTED_TEXT.g, MUTED_TEXT.b)

        row.kind = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.kind:SetPoint("LEFT", row, "LEFT", kindLeft, 0)
        row.kind:SetWidth(kindWidth)
        row.kind:SetJustifyH("LEFT")
        row.kind:SetWordWrap(false)

        row.actor = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.actor:SetPoint("LEFT", row, "LEFT", actorLeft, 0)
        row.actor:SetWidth(actorWidth)
        row.actor:SetJustifyH("LEFT")
        row.actor:SetWordWrap(false)
        row.actor:SetTextColor(BODY_TEXT.r, BODY_TEXT.g, BODY_TEXT.b)
        SetRegionShown(row.actor, showActorColumn)

        row.message = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.message:SetPoint("LEFT", row, "LEFT", messageLeft, 0)
        row.message:SetWidth(messageWidth)
        row.message:SetJustifyH("LEFT")
        row.message:SetWordWrap(false)
        row.message:SetTextColor(BODY_TEXT.r, BODY_TEXT.g, BODY_TEXT.b)

        panel.rows[index] = row
    end

    panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.empty:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -35)
    panel.empty:SetWidth(width - 40)
    panel.empty:SetJustifyH("LEFT")
    panel.empty:SetTextColor(MUTED_TEXT.r, MUTED_TEXT.g, MUTED_TEXT.b)
    panel.empty:SetText("No recent activity.")
    panel.empty:Hide()

    return panel
end

local function RefreshOverviewActivity(panel)
    if not panel then return end

    local db = SC.db or SoftcoreDB
    local entries = GetVisibleLogEntries((db and db.eventLog) or {})
    local shown = 0

    for _, entry in ipairs(entries) do
        if shown >= OVERVIEW_LAYOUT.ACTIVITY_ROWS then
            break
        end

        local label, color = FormatLogEvent(entry)
        local message = FormatLogMessage(entry)
        if message and message ~= "" then
            shown = shown + 1
            local row = panel.rows[shown]
            row:Show()
            SetAuditRowAccent(row, color)
            row.time:SetText(FormatClock(entry.time))
            row.kind:SetText(Trunc(label, 16))
            row.kind:SetTextColor(color.r, color.g, color.b)
            if row.actor then
                row.actor:SetText(Trunc(FormatPlayerLabel(entry.actorKey or entry.playerKey), 14))
                SetRegionShown(row.actor, row.showActorColumn)
            end
            SetCompactText(row.message, message, row.showActorColumn and 62 or 78)
            SetAuditRowTooltip(row, label, message)
        end
    end

    for index = shown + 1, #panel.rows do
        local row = panel.rows[index]
        row:Hide()
        SetAuditRowTooltip(row, nil, nil)
    end
    SetRegionShown(panel.empty, shown == 0)
end

local function RefreshOverviewPanel(frame)
    local db = SC.db or SoftcoreDB
    local run = db and db.run or {}
    local active = run.active
    local status = SC:GetPlayerStatus() or {}
    local partyRows = GetPartyDisplayRows()
    local activeViolationRows = GetSortedActiveViolations()
    local activeViolations = #activeViolationRows
    local localKey = SC:GetPlayerKey()
    local localParticipant = run.participants and run.participants[localKey]
    local startLevel = (localParticipant and localParticipant.levelAtJoin) or run.startLevel
    local inRaid = IsInRaid()
    local grouped = IsInGroup() and not inRaid

    for _, element in ipairs(frame.overview.inactiveElements or {}) do
        SetRegionShown(element, not active)
    end
    for _, element in ipairs(frame.overview.activeElements or {}) do
        SetRegionShown(element, active)
    end

    if not active then
        local award = SC.GetCompletionAward and SC:GetCompletionAward() or nil
        if run.completed or award then
            frame.overview.inactiveTitle:SetText("Run Completed")
            frame.overview.inactiveBody:SetText("Max level reached. Your completion award is available from the Achievements tab.")
            frame.overview.goToRunBtn:SetText("View Award")
            frame.overview.goToRunBtn.softcoreShowsAward = true
        else
            frame.overview.inactiveTitle:SetText("No Active Run")
            frame.overview.inactiveBody:SetText("Start a Softcore run to begin tracking deaths, violations, and party status.")
            frame.overview.goToRunBtn:SetText("Start a Run")
            frame.overview.goToRunBtn.softcoreShowsAward = false
        end
    end

    if active then
        frame.overview.run:SetText("|cffffd100" .. FormatOverviewRunTitle(run) .. "|r")
        SetStatusPill(frame.overview.localStatusPill, status.participantStatus or "NOT_IN_RUN", "Player: ")
        SetStatusPill(frame.overview.partyStatusPill, status.partyStatus or "INACTIVE", "Party: ")
        SetRegionShown(frame.overview.partyStatusPill, grouped)

        if not tonumber(startLevel) or tonumber(startLevel) <= 0 then
            startLevel = "?"
        end
        local currentLevel = db and db.character and db.character.level or "?"
        frame.overview.runId:SetText("|cffad8f61" .. FormatOverviewRunDetail(run) .. "|r")
        frame.overview.identity:SetText("Level " .. tostring(currentLevel) .. "  |cffad8f61Started " .. tostring(startLevel) .. "|r")

        SetCardValue(frame.overview.deathCard, tostring(run.deathCount or 0), "", (run.deathCount or 0) > 0 and RED_TEXT or GREEN_TEXT)
        SetCardValue(frame.overview.violationCard, tostring(activeViolations), "", activeViolations > 0 and GOLD_TEXT or GREEN_TEXT)

        local activeTime = SC.GetActiveRunTimeSeconds and SC:GetActiveRunTimeSeconds() or run.activeTimeSeconds
        SetCardValue(frame.overview.timeCard, FormatDuration(activeTime), "", BLUE_TEXT)

        local conflicts = CountActiveConflicts(run)
        local integrityColor = (conflicts > 0 or activeViolations > 0) and GOLD_TEXT or GREEN_TEXT
        local integrityValue = "Clean"
        if conflicts > 0 then
            integrityValue = tostring(conflicts) .. (conflicts == 1 and " conflict" or " conflicts")
        elseif activeViolations > 0 then
            integrityValue = tostring(activeViolations) .. (activeViolations == 1 and " issue" or " issues")
        end
        SetCardValue(frame.overview.integrityCard, integrityValue, "", integrityColor)
    end

    SetRegionShown(frame.overview.raidNote, active and inRaid)

    RefreshOverviewActivity(frame.overview.activityPanel)
    RefreshOverviewLedger(frame.overview.partyLedger, active and partyRows or {}, grouped, inRaid)
end

local function SetRunSetupEnabled(frame, enabled)
    local start = frame.start
    start.setupEnabled = enabled

    start.casualBtn:SetEnabled(enabled)
    start.ironmanBtn:SetEnabled(enabled)
    if start.chefBtn then start.chefBtn:SetEnabled(enabled) end
    if start.ironVigilBtn then start.ironVigilBtn:SetEnabled(enabled) end

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

local function AnchorRunFooterButtons(frame)
    local start = frame.start
    local leftPrev

    local function anchorLeft(control, xGap, yOffset)
        if not control or not control:IsShown() then
            return
        end
        control:ClearAllPoints()
        if leftPrev then
            control:SetPoint("LEFT", leftPrev, "RIGHT", xGap or 8, yOffset or 0)
        else
            control:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", RUN_FOOTER_LEFT_INSET, RUN_FOOTER_BOTTOM)
        end
        leftPrev = control
    end

    local rightPrev

    local function anchorRight(control, xGap, yOffset)
        if not control or not control:IsShown() then
            return
        end
        control:ClearAllPoints()
        if rightPrev then
            control:SetPoint("RIGHT", rightPrev, "LEFT", -(xGap or 8), yOffset or 0)
        else
            control:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -RUN_FOOTER_RIGHT_INSET, RUN_FOOTER_BOTTOM)
        end
        rightPrev = control
    end

    -- Danger zone: Start / End Run and confirmation controls grow from the left toward center.
    anchorLeft(start.primaryBtn)
    anchorLeft(start.stopBtn)
    anchorLeft(start.cancelRunBox, 14, -1)
    anchorLeft(start.confirmStopBtn, 8, 1)
    anchorLeft(start.cancelStopBtn, 8, 1)

    if start.cancelRunHint and start.cancelRunHint:IsShown() then
        start.cancelRunHint:ClearAllPoints()
        if start.cancelRunBox and start.cancelRunBox:IsShown() then
            start.cancelRunHint:SetPoint("BOTTOMLEFT", start.cancelRunBox, "TOPLEFT", 0, 4)
        elseif start.stopBtn and start.stopBtn:IsShown() then
            start.cancelRunHint:SetPoint("BOTTOMLEFT", start.stopBtn, "TOPLEFT", 0, 4)
        else
            start.cancelRunHint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", RUN_FOOTER_LEFT_INSET, RUN_FOOTER_BOTTOM + 28)
        end
    end

    -- Run governance: Modify Rules and Party Sync share this action slot.
    anchorRight(start.modifyBtn)
    anchorRight(start.partySyncBtn)
    anchorRight(start.cancelChangesBtn)
    anchorRight(start.applyChangesBtn)
    anchorRight(start.proposalCancelBtn)
    anchorRight(start.proposalDeclineBtn)
    anchorRight(start.proposalAcceptBtn)
end

local function RefreshRunPanel(frame)
    local active = IsActiveRun()
    local db = SC.db or SoftcoreDB
    local modifying = active and frame.start.isModifyingRules
    local rulesConflict = GetPendingRulesConflict()

    local pendingAmendment = GetPendingAmendment()
    if pendingAmendment then
        local localKey = SC:GetPlayerKey()
        local isProposer = pendingAmendment.proposedBy == localKey
        local proposer = FormatPlayerLabel(pendingAmendment.proposedBy)
        local baseRules = db and db.run and db.run.ruleset
        local proposedRules = BuildAmendmentReviewRules(baseRules, pendingAmendment)

        CopyRulesInto(frame.start.selectedRules, proposedRules)
        frame.start.draftBaseRules = SC:CopyTable(baseRules or {})
        frame.start.selectedCameraMode = nil
        frame.start.isModifyingRules = false
        frame.start.isReviewingRuleAmendment = true
        frame.start.groupingDropdown:SetShown(true)
        frame.start.gearDropdown:SetShown(true)
        frame.start.maxGapBox:SetShown(true)
        for _, control in ipairs(frame.start.controls) do SetRunControlShown(control, true) end
        if frame.start.presetLabel then SetRunControlShown(frame.start.presetLabel, false) end
        SetRunControlShown(frame.start.casualBtn, false)
        SetRunControlShown(frame.start.ironmanBtn, false)
        if frame.start.chefBtn then SetRunControlShown(frame.start.chefBtn, false) end
        if frame.start.ironVigilBtn then SetRunControlShown(frame.start.ironVigilBtn, false) end
        SetRunSetupEnabled(frame, false)
        frame.start.inactiveText:SetShown(false)
        frame.start.activeText:SetShown(false)
        if pendingAmendment.detailsPending then
            frame.start.activeText:SetText("|cffffd100Rule change from " .. proposer .. " received.|r Loading changed rules...")
        elseif isProposer then
            frame.start.activeText:SetText("|cfffbbf24Waiting for party to accept your rule change.|r Changed rules are highlighted below.")
        else
            frame.start.activeText:SetText("|cffffd100Rule change from " .. proposer .. ".|r Review the highlighted rules below, then Accept or Decline.")
        end
        frame.start.primaryBtn:Hide()
        frame.start.stopBtn:Hide()
        if frame.start.confirmStopBtn then frame.start.confirmStopBtn:Hide() end
        if frame.start.cancelStopBtn then frame.start.cancelStopBtn:Hide() end
        if frame.start.cancelRunBox then
            frame.start.cancelRunBox:SetText("")
            frame.start.cancelRunBox:Hide()
        end
        if frame.start.cancelRunHint then frame.start.cancelRunHint:Hide() end
        frame.start.stopConfirmPending = false
        frame.start.modifyBtn:Hide()
        if frame.start.partySyncBtn then frame.start.partySyncBtn:Hide() end
        frame.start.applyChangesBtn:Hide()
        frame.start.cancelChangesBtn:Hide()
        frame.start.proposalAcceptBtn:SetShown(not isProposer)
        frame.start.proposalAcceptBtn:SetText(pendingAmendment.detailsPending and "Retry Details" or "Accept")
        frame.start.proposalAcceptBtn:SetEnabled(true)
        frame.start.proposalDeclineBtn:SetShown(not isProposer)
        frame.start.proposalDeclineBtn:SetEnabled(true)
        frame.start.proposalCancelBtn:SetShown(isProposer)
        frame.start.proposalCancelBtn:SetEnabled(true)
        frame.start.proposalCancelBtn:SetText("Cancel Proposal")
        frame.start.proposalAcceptBtn:SetScript("OnClick", function()
            if SC.AcceptRuleAmendment then SC:AcceptRuleAmendment(pendingAmendment.id) end
            SC:MasterUI_Refresh()
        end)
        frame.start.proposalDeclineBtn:SetScript("OnClick", function()
            if SC.DeclineRuleAmendment then SC:DeclineRuleAmendment(pendingAmendment.id) end
            SC:MasterUI_Refresh()
        end)
        frame.start.proposalCancelBtn:SetScript("OnClick", function()
            local ruleDb = SC.db or SoftcoreDB
            for _, amendment in ipairs(ruleDb and ruleDb.ruleAmendments or {}) do
                if amendment.id == pendingAmendment.id and amendment.status == "PENDING" then
                    amendment.status = "DECLINED"
                    amendment.declinedAt = time()
                    amendment.declinedBy = SC:GetPlayerKey()
                    if SC.Sync_SendAmendmentCancelled then SC:Sync_SendAmendmentCancelled(amendment) end
                    break
                end
            end
            frame.start.draftBaseRules = nil
            frame.start.isReviewingRuleAmendment = false
            SC:MasterUI_Refresh()
        end)
        if frame.start.RefreshControls then frame.start:RefreshControls() end
        RefreshRunSections(frame.start)
        AnchorRunFooterButtons(frame)
        return
    end
    frame.start.isReviewingRuleAmendment = false

    -- Pending run proposal: show normal controls (read-only) with Accept/Decline/Cancel buttons
    local pendingProposal = GetPendingRunProposal()
    if pendingProposal then
        local isProposer = pendingProposal.proposedBy == SC:GetPlayerKey()
        local acceptedLocally = pendingProposal.status == "ACCEPTED" and not isProposer
        local proposer = FormatPlayerLabel(pendingProposal.proposedBy)
        local acceptBlocked = false
        local blockText = nil
        if pendingProposal.detailsPending then
            acceptBlocked = true
            blockText = "Proposal details are still loading."
        end
        if (not isProposer) and (not acceptedLocally) and active and db and db.run and db.run.ruleset then
            local localHash = SC.GetRulesetHash and SC:GetRulesetHash() or ""
            if (not pendingProposal.detailsPending) and pendingProposal.rulesetHash and pendingProposal.rulesetHash ~= "" and localHash ~= "" and localHash ~= pendingProposal.rulesetHash then
                acceptBlocked = true
                blockText = "Rules do not match."
                if SC.DescribeRulesetDifferences then
                    local diffs = SC:DescribeRulesetDifferences(db.run.ruleset, pendingProposal.ruleset)
                    if diffs and diffs[1] then
                        blockText = blockText .. " " .. tostring(diffs[1].ruleName) .. ": local " .. tostring(diffs[1].localValue) .. " / proposal " .. tostring(diffs[1].remoteValue)
                    end
                end
            end
        end
        CopyRulesInto(frame.start.selectedRules, pendingProposal.ruleset)
        frame.start.groupingDropdown:SetShown(true)
        frame.start.gearDropdown:SetShown(true)
        frame.start.maxGapBox:SetShown(true)
        for _, control in ipairs(frame.start.controls) do SetRunControlShown(control, true) end
        if frame.start.presetLabel then SetRunControlShown(frame.start.presetLabel, false) end
        SetRunControlShown(frame.start.casualBtn, false)
        SetRunControlShown(frame.start.ironmanBtn, false)
        if frame.start.chefBtn then SetRunControlShown(frame.start.chefBtn, false) end
        if frame.start.ironVigilBtn then SetRunControlShown(frame.start.ironVigilBtn, false) end
        SetRunSetupEnabled(frame, false)
        frame.start.inactiveText:SetShown(false)
        frame.start.activeText:SetShown(false)
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
            if acceptBlocked then
                if pendingProposal.detailsPending then
                    frame.start.activeText:SetText("|cffffd100Proposal from " .. proposer .. " received.|r Loading details...")
                else
                    frame.start.activeText:SetText("|cfff87171Sync blocked: " .. blockText .. "|r Use /sc conflicts or /sc syncdebug for full details.")
                end
            elseif pendingProposal.proposalType == "SYNC_RUN" then
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
        if frame.start.cancelRunBox then
            frame.start.cancelRunBox:SetText("")
            frame.start.cancelRunBox:Hide()
        end
        if frame.start.cancelRunHint then frame.start.cancelRunHint:Hide() end
        frame.start.stopConfirmPending = false
        frame.start.modifyBtn:Hide()
        if frame.start.partySyncBtn then frame.start.partySyncBtn:Hide() end
        frame.start.applyChangesBtn:Hide()
        frame.start.cancelChangesBtn:Hide()
        frame.start.proposalAcceptBtn:SetShown((not isProposer) and not acceptedLocally)
        frame.start.proposalAcceptBtn:SetText(pendingProposal.detailsPending and "Retry Details" or "Accept")
        frame.start.proposalAcceptBtn:SetEnabled((not acceptBlocked) or pendingProposal.detailsPending)
        frame.start.proposalDeclineBtn:SetShown((not isProposer) and not acceptedLocally)
        frame.start.proposalDeclineBtn:SetEnabled(true)
        frame.start.proposalCancelBtn:SetShown(isProposer or acceptedLocally)
        frame.start.proposalCancelBtn:SetEnabled(true)
        frame.start.proposalCancelBtn:SetText(isProposer and "Cancel Proposal" or "Cancel Wait")
        frame.start.proposalAcceptBtn:SetScript("OnClick", function()
            if SC.AcceptPendingProposal then SC:AcceptPendingProposal() end
            SC:MasterUI_Refresh()
        end)
        frame.start.proposalDeclineBtn:SetScript("OnClick", function()
            if SC.DeclinePendingProposal then SC:DeclinePendingProposal() end
            SC:MasterUI_Refresh()
        end)
        frame.start.proposalCancelBtn:SetScript("OnClick", function()
            if isProposer then
                if SC.CancelPendingProposal then SC:CancelPendingProposal() end
            else
                if SC.DeclinePendingProposal then SC:DeclinePendingProposal() end
            end
            SC:MasterUI_Refresh()
        end)
        if frame.start.RefreshControls then frame.start:RefreshControls() end
        RefreshRunSections(frame.start)
        AnchorRunFooterButtons(frame)
        return
    end

    frame.start.inactiveText:SetShown(false)
    frame.start.activeText:SetShown(false)

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
    if frame.start.ironVigilBtn then frame.start.ironVigilBtn:SetShown(true) end
    for _, control in ipairs(frame.start.controls) do
        SetRunControlShown(control, true)
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
    local partySyncRoute = nil
    local showPartySync = false
    if frame.start.partySyncBtn then
        local canShowPartySync = active and not modifying and not confirmingStop and IsInGroup() and not IsInRaid()
        if canShowPartySync and SC.GetPartySyncAction then
            partySyncRoute = SC:GetPartySyncAction()
            showPartySync = partySyncRoute and partySyncRoute.action ~= "NONE" and partySyncRoute.action ~= "HIDDEN"
            frame.start.partySyncBtn:SetEnabled(partySyncRoute and partySyncRoute.enabled == true)
        else
            frame.start.partySyncBtn:SetEnabled(false)
        end
        frame.start.partySyncBtn:SetShown(showPartySync)
    end
    frame.start.modifyBtn:SetShown(active and not modifying and not confirmingStop and not showPartySync)
    frame.start.applyChangesBtn:SetShown(modifying)
    frame.start.cancelChangesBtn:SetShown(modifying)
    if frame.start.proposalAcceptBtn then frame.start.proposalAcceptBtn:Hide() end
    if frame.start.proposalDeclineBtn then frame.start.proposalDeclineBtn:Hide() end
    if frame.start.proposalCancelBtn then
        frame.start.proposalCancelBtn:Hide()
        frame.start.proposalCancelBtn:SetText("Cancel Proposal")
    end
    if frame.start.proposalAcceptBtn then frame.start.proposalAcceptBtn:SetScript("OnClick", nil) end
    if frame.start.proposalDeclineBtn then frame.start.proposalDeclineBtn:SetScript("OnClick", nil) end
    if frame.start.proposalCancelBtn then frame.start.proposalCancelBtn:SetScript("OnClick", nil) end
    if frame.start.proposalAcceptBtn then frame.start.proposalAcceptBtn:SetEnabled(true) end
    if frame.start.proposalAcceptBtn then frame.start.proposalAcceptBtn:SetText("Accept") end
    if frame.start.proposalDeclineBtn then frame.start.proposalDeclineBtn:SetEnabled(true) end
    if frame.start.proposalCancelBtn then frame.start.proposalCancelBtn:SetEnabled(true) end
    SetRunSetupEnabled(frame, (not active) or modifying)
    if active and not modifying then
        frame.start.casualBtn:SetEnabled(false)
        frame.start.ironmanBtn:SetEnabled(false)
        if frame.start.chefBtn then frame.start.chefBtn:SetEnabled(false) end
        if frame.start.ironVigilBtn then frame.start.ironVigilBtn:SetEnabled(false) end
    end

    if active then
        if modifying then
            if IsInGroup() and not IsInRaid() then
                frame.start.applyChangesBtn:SetText("Propose to Party")
                frame.start.activeText:SetText("Draft rule amendment. This will be sent to all party members for approval.")
            elseif IsInRaid() then
                frame.start.applyChangesBtn:SetText("Apply Changes")
                frame.start.activeText:SetText("Raid groups are not supported. Rule changes apply locally and will be logged.")
            else
                frame.start.applyChangesBtn:SetText("Apply Changes")
                frame.start.activeText:SetText("Draft rule amendment. Changes apply going forward and will be logged.")
            end
        else
            if confirmingStop then
                frame.start.activeText:SetText("|cfffbbf24End run requested.|r This will reset local run progress.")
            elseif partySyncRoute and partySyncRoute.message and IsInGroup() and not IsInRaid() then
                if partySyncRoute.action == "NONE" then
                    frame.start.activeText:SetText("|cff4ade80" .. partySyncRoute.message .. "|r Active run rules are locked.")
                elseif partySyncRoute.action == "BLOCKED" then
                    frame.start.activeText:SetText("|cfffbbf24" .. partySyncRoute.message .. "|r")
                else
                    frame.start.activeText:SetText("|cffffd100" .. partySyncRoute.message .. "|r")
                end
            elseif rulesConflict then
                frame.start.activeText:SetText("|cfffbbf24Rules conflict detected with " .. FormatPlayerLabel(rulesConflict.playerKey) .. ".|r Use Party Sync to propose your local rule differences.")
            else
                frame.start.activeText:SetText("Active run rules are locked. Camera mode can be switched anytime without a rule amendment.")
            end
        end
    end

    if frame.start.RefreshControls then
        frame.start:RefreshControls()
    end
    RefreshRunSections(frame.start)
    AnchorRunFooterButtons(frame)
end

local function RefreshViolationsPanel(frame)
    local violations = GetSortedActiveViolations()
    local clearable = 0
    local shared = 0

    for _, violation in ipairs(violations) do
        if SC:IsViolationClearable(violation) then
            clearable = clearable + 1
        end
        if violation.shared then
            shared = shared + 1
        end
    end

    if frame.violations.summary then
        local summary
        if #violations == 0 then
            summary = "No active issues."
        else
            summary = tostring(#violations) .. " active"
            if clearable > 0 then
                summary = summary .. " / " .. tostring(clearable) .. " clearable"
            end
            if shared > 0 then
                summary = summary .. " / " .. tostring(shared) .. " shared"
            end
        end
        frame.violations.summary:SetText(summary)
    end

    frame.violations.empty:SetShown(#violations == 0)
    if frame.violations.footer and frame.violations.footer.text then
        frame.violations.footer.text:SetText(#violations == 0 and "Cleared issues remain in the audit log." or "Only active issues are listed here.")
    end
    if frame.violations.scroll then
        FauxScrollFrame_Update(frame.violations.scroll, #violations, VIOLATION_ROWS, VIOLATION_ROW_HEIGHT)
    end

    local offset = frame.violations.scroll and FauxScrollFrame_GetOffset(frame.violations.scroll) or 0
    for rowIndex, row in ipairs(frame.violations.rows) do
        local violation = violations[offset + rowIndex]

        if violation then
            local severity = tostring(violation.severity or "")
            local tone = (violation.type == "death" or severity == "FATAL" or severity == "CHARACTER_FAIL") and RED_TEXT or GOLD_TEXT

            row:Show()
            SetAuditRowAccent(row, tone)
            row.time:SetText(FormatTime(violation.createdAt))
            row.owner:SetText(Trunc(FormatPlayerLabel(violation.playerKey), 14))
            row.type:SetText(Trunc(FormatViolationLogLabel(violation.type), 18))
            row.type:SetTextColor(tone.r, tone.g, tone.b)
            SetCompactText(row.detail, FormatViolationDetail(violation), 70)
            SetAuditRowTooltip(row, FormatViolationLogLabel(violation.type), FormatViolationDetail(violation))

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
            SetAuditRowTooltip(row, nil, nil)
            row.clearBtn:SetScript("OnClick", nil)
        end
    end
end

local function RefreshLogPanel(frame)
    local db = SC.db or SoftcoreDB
    local log = (db and db.eventLog) or {}
    local entries, totalVisible = GetVisibleLogEntries(log, LOG_UI_MAX_ENTRIES)
    local totalStored = #log
    local capped = totalVisible > #entries

    if frame.log.summary then
        if totalVisible == 0 then
            frame.log.summary:SetText("No visible audit rows.")
        elseif capped then
            frame.log.summary:SetText("Showing newest " .. tostring(#entries) .. " of " .. tostring(totalVisible) .. " visible rows.")
        else
            frame.log.summary:SetText("Showing " .. tostring(totalVisible) .. " visible audit rows.")
        end
    end

    if frame.log.footer and frame.log.footer.text then
        local footerText = "CSV export includes all " .. tostring(totalStored) .. " stored rows."
        if capped then
            footerText = footerText .. " Menu list is capped for responsiveness."
        end
        frame.log.footer.text:SetText(footerText)
    end

    if #entries == 0 then
        frame.log.empty:Show()
        for _, row in ipairs(frame.log.rows) do
            row:Hide()
            SetAuditRowTooltip(row, nil, nil)
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
            local message = FormatLogMessage(entry)

            row:Show()
            SetAuditRowAccent(row, eventColor)
            row.time:SetText(FormatTime(entry.time))
            row.actor:SetText(Trunc(FormatPlayerLabel(entry.actorKey or entry.playerKey), 14))
            row.kind:SetText(Trunc(eventLabel, 18))
            row.kind:SetTextColor(eventColor.r, eventColor.g, eventColor.b)
            SetCompactText(row.message, message, 76)
            SetAuditRowTooltip(row, eventLabel, message)
        else
            row:Hide()
            SetAuditRowTooltip(row, nil, nil)
        end
    end
end

local function CreateViolationsTab(frame)
    local violationsPanel = CreatePanel(frame)
    frame.panels[TAB_VIOLATIONS] = violationsPanel
    frame.violations = { rows = {} }

    CreateSectionHeader(violationsPanel, "Active Violations", 0, 0, AUDIT_LIST_LAYOUT.CONTENT_WIDTH)
    frame.violations.summary = CreateField(violationsPanel, 0, AUDIT_LIST_LAYOUT.SUMMARY_TOP, 420)
    frame.violations.summary:SetTextColor(MUTED_TEXT.r, MUTED_TEXT.g, MUTED_TEXT.b)
    CreateAuditColumn(violationsPanel, "Issue", AUDIT_LIST_LAYOUT.TYPE_X, AUDIT_LIST_LAYOUT.TYPE_WIDTH)
    CreateAuditColumn(violationsPanel, "Character", AUDIT_LIST_LAYOUT.ACTOR_X, AUDIT_LIST_LAYOUT.ACTOR_WIDTH)
    CreateAuditColumn(violationsPanel, "Time", AUDIT_LIST_LAYOUT.TIME_X, AUDIT_LIST_LAYOUT.TIME_WIDTH)
    CreateAuditColumn(violationsPanel, "Details", AUDIT_LIST_LAYOUT.MESSAGE_X, AUDIT_LIST_LAYOUT.ACTION_MESSAGE_WIDTH)
    local violColSep = CreateDivider(violationsPanel, 0, AUDIT_LIST_LAYOUT.DIVIDER_TOP, AUDIT_LIST_LAYOUT.CONTENT_WIDTH - AUDIT_LIST_LAYOUT.SCROLL_RIGHT_INSET)
    violColSep:SetColorTexture(0.72, 0.49, 0.18, 0.42)

    frame.violations.empty = CreateField(violationsPanel, 0, AUDIT_LIST_LAYOUT.ROW_TOP, 620)
    frame.violations.empty:SetText("No active violations.")
    frame.violations.scroll = CreateFrame("ScrollFrame", "SoftcoreViolationsScrollFrame", violationsPanel, "FauxScrollFrameTemplate")
    frame.violations.scroll:SetPoint("TOPLEFT", violationsPanel, "TOPLEFT", 0, VIOLATION_ROW_TOP)
    frame.violations.scroll:SetPoint("BOTTOMRIGHT", violationsPanel, "BOTTOMRIGHT", -AUDIT_LIST_LAYOUT.SCROLL_RIGHT_INSET, AUDIT_LIST_LAYOUT.FOOTER_HEIGHT + 4)
    frame.violations.scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, VIOLATION_ROW_HEIGHT, function()
            SC:MasterUI_Refresh()
        end)
    end)

    for index = 1, VIOLATION_ROWS do
        local row = CreateAuditRow(violationsPanel, index)
        row.type = CreateField(row, AUDIT_LIST_LAYOUT.TYPE_X, -10, AUDIT_LIST_LAYOUT.TYPE_WIDTH)
        row.owner = CreateField(row, AUDIT_LIST_LAYOUT.ACTOR_X, -10, AUDIT_LIST_LAYOUT.ACTOR_WIDTH)
        row.time = CreateField(row, AUDIT_LIST_LAYOUT.TIME_X, -10, AUDIT_LIST_LAYOUT.TIME_WIDTH)
        row.detail = CreateField(row, AUDIT_LIST_LAYOUT.MESSAGE_X, -10, AUDIT_LIST_LAYOUT.ACTION_MESSAGE_WIDTH)
        row.time:SetWordWrap(false)
        row.owner:SetWordWrap(false)
        row.type:SetWordWrap(false)
        row.detail:SetWordWrap(false)
        row.clearBtn = CreateButton(row, "Clear", 58, 17)
        row.clearBtn:SetPoint("RIGHT", row, "RIGHT", -18, 1)
        frame.violations.rows[index] = row
    end

    frame.violations.footer = CreateAuditListFooter(violationsPanel)
end

local function CreateLogTab(frame)
    local logPanel = CreatePanel(frame)
    frame.panels[TAB_LOG] = logPanel
    frame.log = { rows = {} }

    CreateSectionHeader(logPanel, "Audit Log", 0, 0, AUDIT_LIST_LAYOUT.CONTENT_WIDTH)
    frame.log.summary = CreateField(logPanel, 0, AUDIT_LIST_LAYOUT.SUMMARY_TOP, 440)
    frame.log.summary:SetTextColor(MUTED_TEXT.r, MUTED_TEXT.g, MUTED_TEXT.b)
    CreateAuditColumn(logPanel, "Event", AUDIT_LIST_LAYOUT.TYPE_X, AUDIT_LIST_LAYOUT.TYPE_WIDTH)
    CreateAuditColumn(logPanel, "Character", AUDIT_LIST_LAYOUT.ACTOR_X, AUDIT_LIST_LAYOUT.ACTOR_WIDTH)
    CreateAuditColumn(logPanel, "Time", AUDIT_LIST_LAYOUT.TIME_X, AUDIT_LIST_LAYOUT.TIME_WIDTH)
    CreateAuditColumn(logPanel, "Message", AUDIT_LIST_LAYOUT.MESSAGE_X, AUDIT_LIST_LAYOUT.MESSAGE_WIDTH)
    local logColSep = CreateDivider(logPanel, 0, AUDIT_LIST_LAYOUT.DIVIDER_TOP, AUDIT_LIST_LAYOUT.CONTENT_WIDTH - AUDIT_LIST_LAYOUT.SCROLL_RIGHT_INSET)
    logColSep:SetColorTexture(0.72, 0.49, 0.18, 0.42)

    frame.log.empty = CreateField(logPanel, 0, AUDIT_LIST_LAYOUT.ROW_TOP, 620)
    frame.log.empty:SetText("No events recorded.")
    frame.log.scroll = CreateFrame("ScrollFrame", "SoftcoreLogScrollFrame", logPanel, "FauxScrollFrameTemplate")
    frame.log.scroll:SetPoint("TOPLEFT", logPanel, "TOPLEFT", 0, LOG_ROW_TOP)
    frame.log.scroll:SetPoint("BOTTOMRIGHT", logPanel, "BOTTOMRIGHT", -AUDIT_LIST_LAYOUT.SCROLL_RIGHT_INSET, AUDIT_LIST_LAYOUT.FOOTER_HEIGHT + 4)
    frame.log.scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, LOG_ROW_HEIGHT, function()
            SC:MasterUI_Refresh()
        end)
    end)

    for index = 1, LOG_ROWS do
        local row = CreateAuditRow(logPanel, index)
        row.kind = CreateField(row, AUDIT_LIST_LAYOUT.TYPE_X, -10, AUDIT_LIST_LAYOUT.TYPE_WIDTH)
        row.actor = CreateField(row, AUDIT_LIST_LAYOUT.ACTOR_X, -10, AUDIT_LIST_LAYOUT.ACTOR_WIDTH)
        row.time = CreateField(row, AUDIT_LIST_LAYOUT.TIME_X, -10, AUDIT_LIST_LAYOUT.TIME_WIDTH)
        row.message = CreateField(row, AUDIT_LIST_LAYOUT.MESSAGE_X, -10, AUDIT_LIST_LAYOUT.MESSAGE_WIDTH)
        row.time:SetWordWrap(false)
        row.actor:SetWordWrap(false)
        row.kind:SetWordWrap(false)
        row.message:SetWordWrap(false)
        frame.log.rows[index] = row
    end

    frame.log.footer = CreateAuditListFooter(logPanel)
    frame.log.exportBtn = CreateButton(logPanel, "Export CSV", 96, 24)
    frame.log.exportBtn:SetPoint("BOTTOMRIGHT", logPanel, "BOTTOMRIGHT", -AUDIT_LIST_LAYOUT.SCROLL_RIGHT_INSET, 3)
    frame.log.exportBtn:SetScript("OnClick", function()
        if SC.ShowRunExport then
            SC:ShowRunExport()
        elseif SC.PrintRunExport then
            SC:PrintRunExport()
        else
            Print("CSV export is not loaded.")
        end
    end)
end

local function GetAchievementCategoryRank(category)
    for index, knownCategory in ipairs(ACHIEVEMENT_CATEGORY_ORDER) do
        if knownCategory == category then
            return index
        end
    end
    return #ACHIEVEMENT_CATEGORY_ORDER + 1
end

local function GetAchievementCategoryMeta(category)
    return ACHIEVEMENT_CATEGORY_META[category] or {
        label = tostring(category or "Other"),
        icon = "Interface\\Icons\\Achievement_General",
        color = BODY_TEXT,
    }
end

local function FormatAchievementDate(timestamp)
    if not timestamp then return "" end
    return date("%b %d, %Y", timestamp)
end

local function GetAchievementIcon(achievement)
    if not achievement then
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    local progressKind = tostring(achievement.progressKind or "")
    local ruleName = achievement.ruleName

    if progressKind == "CLASS_MAX" and ACHIEVEMENT_CLASS_ICONS[ruleName] then
        return ACHIEVEMENT_CLASS_ICONS[ruleName]
    end

    if progressKind == "RULE_MAX" and ACHIEVEMENT_RULE_ICONS[ruleName] then
        return ACHIEVEMENT_RULE_ICONS[ruleName]
    end

    if (progressKind == "GEAR_QUALITY_MAX" or progressKind == "GEAR_QUALITY_CRAFTED_MAX") and ACHIEVEMENT_RULE_ICONS[ruleName] then
        return ACHIEVEMENT_RULE_ICONS[ruleName]
    end

    if progressKind == "LEVEL" or progressKind == "LEVEL_CLEAN" then
        local target = tonumber(achievement.target or 0) or 0
        if target > 0 then
            return "Interface\\Icons\\Achievement_Level_" .. tostring(target)
        end
    end

    return ACHIEVEMENT_KIND_ICONS[progressKind]
        or (ACHIEVEMENT_CATEGORY_META[achievement.category] and ACHIEVEMENT_CATEGORY_META[achievement.category].icon)
        or "Interface\\Icons\\Achievement_General"
end

local function CreateAchievementSummaryCard(parent, title, x, y, width)
    local card = CreateOverviewCard(parent, title, x, y, width, ACHIEVEMENT_LAYOUT.SUMMARY_HEIGHT, {
        centerValue = true,
        hideDetail = true,
        valueFont = "GameFontNormalLarge",
    })
    card.value:ClearAllPoints()
    card.value:SetPoint("CENTER", card, "CENTER", 0, -6)
    return card
end

local function CreateAchievementRow(parent)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetSize(ACHIEVEMENT_LAYOUT.CONTENT_WIDTH - (ACHIEVEMENT_LAYOUT.ROW_INSET * 2), ACHIEVEMENT_LAYOUT.ROW_HEIGHT)
    row:EnableMouse(true)
    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })

    row.accent = row:CreateTexture(nil, "ARTWORK")
    row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -5)
    row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 3, 5)
    row.accent:SetWidth(3)

    row.iconFrame = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.iconFrame:SetSize(ACHIEVEMENT_LAYOUT.ICON_SIZE + 6, ACHIEVEMENT_LAYOUT.ICON_SIZE + 6)
    row.iconFrame:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -11)
    row.iconFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    row.icon = row.iconFrame:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ACHIEVEMENT_LAYOUT.ICON_SIZE, ACHIEVEMENT_LAYOUT.ICON_SIZE)
    row.icon:SetPoint("CENTER", row.iconFrame, "CENTER", 0, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.iconShade = row.iconFrame:CreateTexture(nil, "OVERLAY")
    row.iconShade:SetAllPoints(row.icon)
    row.iconShade:SetColorTexture(0, 0, 0, 0.42)
    row.iconCheck = row.iconFrame:CreateTexture(nil, "OVERLAY")
    row.iconCheck:SetSize(24, 24)
    row.iconCheck:SetPoint("BOTTOMRIGHT", row.iconFrame, "BOTTOMRIGHT", 3, -3)
    row.iconCheck:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")

    row.name = CreateField(row, 70, -9, 346)
    row.name:SetFontObject(GameFontNormal)
    row.name:SetWordWrap(false)
    row.date = CreateField(row, 454, -10, 188)
    row.date:SetJustifyH("RIGHT")
    row.date:SetWordWrap(false)

    row.description = CreateField(row, 70, -31, 560)
    row.description:SetFontObject(GameFontHighlightSmall)
    row.description:SetWordWrap(false)

    row.progress = CreateFrame("StatusBar", nil, row)
    row.progress:SetSize(ACHIEVEMENT_LAYOUT.PROGRESS_WIDTH, 9)
    row.progress:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 70, 12)
    row.progress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.progress:SetMinMaxValues(0, 1)
    row.progressBg = row.progress:CreateTexture(nil, "BACKGROUND")
    row.progressBg:SetAllPoints(row.progress)
    row.progressBg:SetColorTexture(0.05, 0.04, 0.025, 0.95)

    row.progressText = CreateField(row, 254, -53, 276)
    row.progressText:SetFontObject(GameFontHighlightSmall)
    row.progressText:SetWordWrap(false)

    row.statusBadge = CreateOverviewSmallBadge(row, ACHIEVEMENT_LAYOUT.BADGE_WIDTH, ACHIEVEMENT_LAYOUT.BADGE_HEIGHT)
    row.statusBadge:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -12, 8)

    return row
end

local function CreateAchievementSection(parent)
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetSize(ACHIEVEMENT_LAYOUT.CONTENT_WIDTH, ACHIEVEMENT_LAYOUT.SECTION_HEADER_HEIGHT)
    section.rows = {}
    section:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })

    section.headerButton = CreateFrame("Button", nil, section)
    section.headerButton:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    section.headerButton:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, 0)
    section.headerButton:SetHeight(ACHIEVEMENT_LAYOUT.SECTION_HEADER_HEIGHT)

    section.icon = section.headerButton:CreateTexture(nil, "ARTWORK")
    section.icon:SetSize(22, 22)
    section.icon:SetPoint("LEFT", section.headerButton, "LEFT", 12, 0)
    section.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    section.title = section.headerButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    section.title:SetPoint("LEFT", section.icon, "RIGHT", 9, 0)
    section.title:SetWidth(240)
    section.title:SetJustifyH("LEFT")

    section.count = CreateOverviewSmallBadge(section.headerButton, 74, 20)
    section.count:SetPoint("RIGHT", section.headerButton, "RIGHT", -44, 0)

    section.toggleGlyph = section.headerButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    section.toggleGlyph:SetPoint("RIGHT", section.headerButton, "RIGHT", -14, 0)
    section.toggleGlyph:SetWidth(18)
    section.toggleGlyph:SetJustifyH("CENTER")

    section.divider = section:CreateTexture(nil, "ARTWORK")
    section.divider:SetHeight(1)
    section.divider:SetPoint("TOPLEFT", section, "TOPLEFT", 10, -ACHIEVEMENT_LAYOUT.SECTION_HEADER_HEIGHT)
    section.divider:SetPoint("TOPRIGHT", section, "TOPRIGHT", -10, -ACHIEVEMENT_LAYOUT.SECTION_HEADER_HEIGHT)
    section.divider:SetColorTexture(0.72, 0.49, 0.18, 0.30)

    section.headerButton:SetScript("OnClick", function(button)
        local owner = button:GetParent()
        local master = SC.masterFrame
        if not owner or not master or not master.achievements then return end
        local category = owner.category or "Other"
        master.achievements.collapsed = master.achievements.collapsed or {}
        master.achievements.collapsed[category] = not master.achievements.collapsed[category]
        SC:MasterUI_Refresh()
    end)

    return section
end

local function SetAchievementRowTone(row, achievement, categoryColor)
    local progressValue = tonumber(achievement and achievement.progressValue or 0) or 0
    local tone = categoryColor or BODY_TEXT

    if achievement and achievement.earned then
        row:SetBackdropColor(0.18, 0.12, 0.045, 0.96)
        row:SetBackdropBorderColor(GOLD_TEXT.r, GOLD_TEXT.g, GOLD_TEXT.b, 0.88)
        row.iconFrame:SetBackdropColor(0.32, 0.22, 0.06, 1)
        row.iconFrame:SetBackdropBorderColor(1.0, 0.82, 0.20, 1)
        row.accent:SetColorTexture(GOLD_TEXT.r, GOLD_TEXT.g, GOLD_TEXT.b, 0.95)
        row.icon:SetDesaturated(false)
        row.icon:SetVertexColor(1, 1, 1, 1)
        row.iconShade:Hide()
        row.iconCheck:Show()
        SetOverviewSmallBadge(row.statusBadge, "Done", GREEN_TEXT)
    elseif progressValue > 0 then
        row:SetBackdropColor(0.095, 0.072, 0.04, 0.92)
        row:SetBackdropBorderColor(tone.r, tone.g, tone.b, 0.66)
        row.iconFrame:SetBackdropColor(0.12, 0.11, 0.09, 1)
        row.iconFrame:SetBackdropBorderColor(tone.r, tone.g, tone.b, 0.86)
        row.accent:SetColorTexture(BLUE_TEXT.r, BLUE_TEXT.g, BLUE_TEXT.b, 0.90)
        row.icon:SetDesaturated(false)
        row.icon:SetVertexColor(0.95, 0.95, 0.95, 1)
        row.iconShade:Hide()
        row.iconCheck:Hide()
        SetOverviewSmallBadge(row.statusBadge, tostring(math.floor((progressValue * 100) + 0.5)) .. "%", BLUE_TEXT)
    else
        row:SetBackdropColor(0.07, 0.055, 0.035, 0.88)
        row:SetBackdropBorderColor(0.36, 0.30, 0.20, 0.65)
        row.iconFrame:SetBackdropColor(0.08, 0.075, 0.065, 1)
        row.iconFrame:SetBackdropBorderColor(0.36, 0.31, 0.22, 0.78)
        row.accent:SetColorTexture(MUTED_TEXT.r, MUTED_TEXT.g, MUTED_TEXT.b, 0.55)
        row.icon:SetDesaturated(true)
        row.icon:SetVertexColor(0.72, 0.66, 0.55, 1)
        row.iconShade:Show()
        row.iconCheck:Hide()
        SetOverviewSmallBadge(row.statusBadge, "Open", MUTED_TEXT)
    end
end

local function RefreshAchievementRow(row, achievement, categoryColor)
    local progressValue = tonumber(achievement.progressValue or 0) or 0
    if progressValue < 0 then progressValue = 0 end
    if progressValue > 1 then progressValue = 1 end

    row.icon:SetTexture(GetAchievementIcon(achievement))
    row.name:SetText((achievement.earned and "|cffffd100" or "|cffd6c29a") .. Trunc(achievement.name or "Achievement", 42) .. "|r")
    SetCompactText(row.description, achievement.description or "", 92)

    if achievement.earnedAt then
        row.date:SetText("|cff4ade80" .. FormatAchievementDate(achievement.earnedAt) .. "|r")
    else
        row.date:SetText("")
    end

    row.progress:SetValue(achievement.earned and 1 or progressValue)
    if achievement.earned then
        row.progress:SetStatusBarColor(0.86, 0.62, 0.16, 1)
        row.progressText:SetText(achievement.isCompletionAward and "|cff4ade80Click to view award|r" or "|cff4ade80Complete|r")
    elseif progressValue > 0 then
        row.progress:SetStatusBarColor(BLUE_TEXT.r, BLUE_TEXT.g, BLUE_TEXT.b, 1)
        row.progressText:SetText("|cffd6c29a" .. Trunc(achievement.progressText or "In progress", 42) .. "|r")
    else
        row.progress:SetStatusBarColor(0.34, 0.28, 0.18, 1)
        row.progressText:SetText("|cffad8f61" .. Trunc(achievement.progressText or "Not earned", 42) .. "|r")
    end

    SetAchievementRowTone(row, achievement, categoryColor)
    if achievement.isCompletionAward then
        SetOverviewSmallBadge(row.statusBadge, "View", GOLD_TEXT)
        row:SetScript("OnMouseUp", function()
            if SC.ShowCompletionAward then
                SC:ShowCompletionAward()
            end
        end)
    else
        row:SetScript("OnMouseUp", nil)
    end

    local tooltipBody = tostring(achievement.description or "")
    local progressText = tostring(achievement.progressText or "")
    if achievement.earnedAt then
        tooltipBody = tooltipBody .. "\nEarned " .. FormatAchievementDate(achievement.earnedAt)
    elseif progressText ~= "" then
        tooltipBody = tooltipBody .. "\n" .. progressText
    end
    SetAuditRowTooltip(row, achievement.name or "Achievement", tooltipBody)
end

local function BuildAchievementGroups(rows)
    local groups = {}
    local byCategory = {}

    for _, achievement in ipairs(rows) do
        local category = tostring(achievement.category or "Other")
        local group = byCategory[category]
        if not group then
            group = {
                category = category,
                rows = {},
                earned = 0,
                inProgress = 0,
                total = 0,
                rank = GetAchievementCategoryRank(category),
            }
            byCategory[category] = group
            table.insert(groups, group)
        end

        table.insert(group.rows, achievement)
        group.total = group.total + 1
        if achievement.earned then
            group.earned = group.earned + 1
        elseif (tonumber(achievement.progressValue or 0) or 0) > 0 then
            group.inProgress = group.inProgress + 1
        end
    end

    table.sort(groups, function(left, right)
        if left.rank ~= right.rank then
            return left.rank < right.rank
        end
        return tostring(left.category or "") < tostring(right.category or "")
    end)

    return groups
end

local function RefreshAchievementSection(section, group, collapsed, topOffset)
    local meta = GetAchievementCategoryMeta(group.category)
    local categoryColor = meta.color or BODY_TEXT
    local rowCount = #group.rows
    local height = ACHIEVEMENT_LAYOUT.SECTION_HEADER_HEIGHT

    if not collapsed then
        height = height + ACHIEVEMENT_LAYOUT.SECTION_ROW_TOP_GAP
            + (rowCount * ACHIEVEMENT_LAYOUT.ROW_HEIGHT)
            + (math.max(rowCount - 1, 0) * ACHIEVEMENT_LAYOUT.ROW_GAP)
            + ACHIEVEMENT_LAYOUT.SECTION_BOTTOM_INSET
    end

    section:ClearAllPoints()
    section:SetPoint("TOPLEFT", section:GetParent(), "TOPLEFT", 0, -topOffset)
    section:SetSize(ACHIEVEMENT_LAYOUT.CONTENT_WIDTH, height)
    section.category = group.category
    section:SetBackdropColor(0.08, 0.045, 0.018, 0.82)
    section:SetBackdropBorderColor(categoryColor.r, categoryColor.g, categoryColor.b, collapsed and 0.42 or 0.74)
    section.icon:SetTexture(meta.icon)
    section.title:SetText("|cffffd100" .. tostring(meta.label or group.category) .. "|r")
    SetOverviewSmallBadge(section.count, tostring(group.earned) .. "/" .. tostring(group.total), group.earned == group.total and GREEN_TEXT or GOLD_TEXT)
    section.toggleGlyph:SetText(collapsed and "+" or "-")
    SetRegionShown(section.divider, not collapsed and rowCount > 0)

    for index = #section.rows + 1, rowCount do
        section.rows[index] = CreateAchievementRow(section)
    end

    for index, row in ipairs(section.rows) do
        local achievement = group.rows[index]
        if achievement and not collapsed then
            row:Show()
            row:ClearAllPoints()
            row:SetPoint(
                "TOPLEFT",
                section,
                "TOPLEFT",
                ACHIEVEMENT_LAYOUT.ROW_INSET,
                -(ACHIEVEMENT_LAYOUT.SECTION_HEADER_HEIGHT + ACHIEVEMENT_LAYOUT.SECTION_ROW_TOP_GAP
                    + ((index - 1) * (ACHIEVEMENT_LAYOUT.ROW_HEIGHT + ACHIEVEMENT_LAYOUT.ROW_GAP)))
            )
            RefreshAchievementRow(row, achievement, categoryColor)
        else
            row:Hide()
        end
    end

    return height
end

local function RefreshAchievementsPanel(frame)
    if not frame.achievements then return end

    local rows = SC.GetAchievementRows and SC:GetAchievementRows() or {}
    local groups = BuildAchievementGroups(rows)
    local earnedCount = 0
    local inProgressCount = 0
    local achievementTotal = 0

    for _, achievement in ipairs(rows) do
        if not achievement.isCompletionAward then
            achievementTotal = achievementTotal + 1
        end
        if achievement.isCompletionAward then
            -- Award rows are a revisitable character record, not an account achievement.
        elseif achievement.earned then
            earnedCount = earnedCount + 1
        elseif (tonumber(achievement.progressValue or 0) or 0) > 0 then
            inProgressCount = inProgressCount + 1
        end
    end

    SetCardValue(frame.achievements.earnedCard, tostring(earnedCount), "", earnedCount > 0 and GOLD_TEXT or MUTED_TEXT)
    SetCardValue(frame.achievements.progressCard, tostring(inProgressCount), "", inProgressCount > 0 and BLUE_TEXT or MUTED_TEXT)
    SetCardValue(frame.achievements.remainingCard, tostring(math.max(achievementTotal - earnedCount, 0)), "", earnedCount == achievementTotal and GREEN_TEXT or BODY_TEXT)

    SetRegionShown(frame.achievements.empty, #rows == 0)

    for index = #frame.achievements.sections + 1, #groups do
        frame.achievements.sections[index] = CreateAchievementSection(frame.achievements.content)
    end

    local topOffset = 0
    for index, section in ipairs(frame.achievements.sections) do
        local group = groups[index]
        if group then
            section:Show()
            local collapsed = frame.achievements.collapsed and frame.achievements.collapsed[group.category]
            local height = RefreshAchievementSection(section, group, collapsed, topOffset)
            topOffset = topOffset + height + ACHIEVEMENT_LAYOUT.SECTION_GAP
        else
            section:Hide()
        end
    end

    local contentHeight = math.max(ACHIEVEMENT_LAYOUT.SCROLL_HEIGHT, topOffset + 8)
    frame.achievements.content:SetSize(ACHIEVEMENT_LAYOUT.CONTENT_WIDTH, contentHeight)
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

function SC:ToggleMasterWindow(focusTab)
    if self.masterFrame and self.masterFrame:IsShown() then
        self.masterFrame:Hide()
    else
        self:OpenMasterWindow(focusTab)
    end
end

local function CreateOverviewTab(frame)
    local overviewPanel = CreatePanel(frame)
    frame.panels[TAB_OVERVIEW] = overviewPanel
    local contentX = CenteredOffset(PANEL_WIDTH, OVERVIEW_LAYOUT.CONTENT_WIDTH)

    local inactiveWidth = 490
    local inactiveCard = CreateOverviewCard(overviewPanel, "Character Record", CenteredOffset(PANEL_WIDTH, inactiveWidth), -86, inactiveWidth, 170)
    inactiveCard.value:SetFontObject(GameFontNormalLarge)
    inactiveCard.detail:SetWidth(450)
    inactiveCard.detail:SetTextColor(BODY_TEXT.r, BODY_TEXT.g, BODY_TEXT.b)

    local hero = CreateFrame("Frame", nil, overviewPanel, "BackdropTemplate")
    hero:SetPoint("TOPLEFT", overviewPanel, "TOPLEFT", contentX, 0)
    hero:SetSize(OVERVIEW_LAYOUT.CONTENT_WIDTH, OVERVIEW_LAYOUT.HERO_HEIGHT)
    if hero.SetBackdrop then
        hero:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        hero:SetBackdropColor(0.08, 0.045, 0.018, 0.86)
        hero:SetBackdropBorderColor(0.72, 0.56, 0.22, 0.95)
    end

    frame.overview = {
        panel = overviewPanel,
        inactiveElements = { inactiveCard },
        activeElements = { hero },
        inactiveCard = inactiveCard,
        hero = hero,
    }

    frame.overview.inactiveTitle = inactiveCard.value
    frame.overview.inactiveBody = inactiveCard.detail
    frame.overview.inactiveTitle:SetText("No Active Run")
    frame.overview.inactiveBody:SetText("Start a Softcore run to begin tracking deaths, violations, and party status.")
    frame.overview.goToRunBtn = CreateButton(overviewPanel, "Start a Run", 110, 24)
    frame.overview.goToRunBtn:SetPoint("TOP", inactiveCard, "BOTTOM", 0, -18)
    table.insert(frame.overview.inactiveElements, frame.overview.goToRunBtn)
    frame.overview.goToRunBtn:SetScript("OnClick", function()
        if frame.overview.goToRunBtn.softcoreShowsAward and SC.ShowCompletionAward then
            SC:ShowCompletionAward()
            return
        end
        frame.activeTab = TAB_RUN
        SC:MasterUI_Refresh()
    end)

    frame.overview.run = hero:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.overview.run:SetPoint("TOPLEFT", hero, "TOPLEFT", 18, -14)
    frame.overview.run:SetWidth(330)
    frame.overview.run:SetJustifyH("LEFT")
    frame.overview.run:SetTextColor(GOLD_TEXT.r, GOLD_TEXT.g, GOLD_TEXT.b)
    frame.overview.runId = CreateField(hero, 18, -48, 330)
    frame.overview.identity = CreateField(hero, 504, -48, 172)
    frame.overview.identity:SetJustifyH("CENTER")
    frame.overview.partyStatusPill = CreateStatusPill(hero, 344, -14, 156)
    frame.overview.localStatusPill = CreateStatusPill(hero, 504, -14, 172)

    local metricTop = -(OVERVIEW_LAYOUT.HERO_HEIGHT + OVERVIEW_LAYOUT.HERO_GAP)
    local metricCards, metricOrder = CreateOverviewMetricGrid(overviewPanel, {
        { key = "deathCard", title = "Deaths" },
        { key = "violationCard", title = "Violations" },
        { key = "timeCard", title = "Time" },
        { key = "integrityCard", title = "Integrity" },
    }, contentX, metricTop, OVERVIEW_LAYOUT.CONTENT_WIDTH, OVERVIEW_LAYOUT.METRIC_HEIGHT, OVERVIEW_LAYOUT.METRIC_GAP)
    frame.overview.deathCard = metricCards.deathCard
    frame.overview.violationCard = metricCards.violationCard
    frame.overview.timeCard = metricCards.timeCard
    frame.overview.integrityCard = metricCards.integrityCard
    for _, card in ipairs(metricOrder) do
        table.insert(frame.overview.activeElements, card)
    end

    local activityTop = metricTop - OVERVIEW_LAYOUT.METRIC_HEIGHT - OVERVIEW_LAYOUT.LEDGER_TOP_GAP
    frame.overview.activityPanel = CreateOverviewActivityPanel(overviewPanel, contentX, activityTop, OVERVIEW_LAYOUT.CONTENT_WIDTH, OVERVIEW_LAYOUT.ACTIVITY_HEIGHT)
    table.insert(frame.overview.activeElements, frame.overview.activityPanel)

    local ledgerTop = activityTop - OVERVIEW_LAYOUT.ACTIVITY_HEIGHT - OVERVIEW_LAYOUT.ACTIVITY_GAP
    frame.overview.partyLedger = CreateOverviewPartyLedger(overviewPanel, contentX, ledgerTop, OVERVIEW_LAYOUT.CONTENT_WIDTH, OVERVIEW_PARTY_ROWS)
    table.insert(frame.overview.activeElements, frame.overview.partyLedger)

    frame.overview.raidNote = CreateField(frame.overview.partyLedger, OVERVIEW_LAYOUT.LEDGER_INSET, -CalculateOverviewLedgerHeight(1) - 8, 660)
    frame.overview.raidNote:SetText("|cfffbbf24Raid groups are not supported. Softcore will show and track only your character.|r")
    frame.overview.raidNote:Hide()
    table.insert(frame.overview.activeElements, frame.overview.raidNote)
end

function SC:OpenMasterWindow(focusTab)
    if self.masterFrame then
        self.masterFrame:Show()
        self.masterFrame.activeTab = NormalizeTab(focusTab or self.masterFrame.activeTab)
        self:MasterUI_Refresh()
        return
    end

    local frame = CreateFrame("Frame", "SoftcoreMasterFrame", UIParent, "BackdropTemplate")
    frame:SetSize(760, 718)
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
    subtitle:SetText("Group hardcore, synced and accountable.")

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
    local runTab = AddTab("runTab", "Charter", TAB_RUN, overviewTab)
    local violationsTab = AddTab("violationsTab", "Violations", TAB_VIOLATIONS, runTab)
    local logTab = AddTab("logTab", "Log", TAB_LOG, violationsTab)
    AddTab("achievementsTab", "Achievements", TAB_ACHIEVEMENTS, logTab, 110)

    local startPanel = CreatePanel(frame)
    startPanel:SetHeight(552)
    frame.panels[TAB_RUN] = startPanel
    frame.start = { panel = startPanel, controls = {}, selectedRules = SC:GetDefaultRuleset(), selectedPreset = "CASUAL" }
    frame.start.selectedRules.dungeonRepeat = "ALLOWED"
    frame.start.selectedRules.instanceWithUnsyncedPlayers = "ALLOWED"
    frame.start.selectedRules.unsyncedMembers = "ALLOWED"
    frame.start.inactiveText = CreateField(startPanel, 0, 0, 620)
    frame.start.inactiveText:SetText("Choose a ruleset, review the rules, then start your run.")
    frame.start.inactiveText:Hide()
    frame.start.activeText = CreateField(startPanel, 0, 0, 620)
    frame.start.activeText:SetText("Active run rules are locked. Future rule changes will use a visible amendment flow.")
    frame.start.activeText:Hide()

    frame.start.sections = {}
    local runLayout = SC.MasterUIRunLayout
    frame.start.charterSection = CreateRunSection(startPanel, "Run Charter", 0, 0, runLayout.CONTENT_WIDTH, runLayout:SectionHeight(2, 4))
    frame.start.accessSection = CreateRunSection(startPanel, "Access and Economy", 0, 0, runLayout.COLUMN_WIDTH, runLayout:SectionHeight(#ECONOMY_RULES))
    frame.start.travelSection = CreateRunSection(startPanel, "Travel and Camera", 0, 0, runLayout.COLUMN_WIDTH, runLayout:SectionHeight(#MOVEMENT_RULES + 1))
    frame.start.gearSection = CreateRunSection(startPanel, "Gear and Items", runLayout.RIGHT_COLUMN_X, 0, runLayout.COLUMN_WIDTH, runLayout:SectionHeight(5))
    frame.start.partyDungeonSection = CreateRunSection(startPanel, "Party and Dungeons", runLayout.RIGHT_COLUMN_X, 0, runLayout.COLUMN_WIDTH, runLayout:SectionHeight(3, 8))
    table.insert(frame.start.sections, frame.start.charterSection)
    table.insert(frame.start.sections, frame.start.accessSection)
    table.insert(frame.start.sections, frame.start.travelSection)
    table.insert(frame.start.sections, frame.start.gearSection)
    table.insert(frame.start.sections, frame.start.partyDungeonSection)

    local charterLeftX = 0
    local charterRightX = runLayout.RIGHT_COLUMN_X
    local charterLabelWidth = 56
    local charterControlX = charterLeftX + 58
    local charterRightControlX = 156
    -- Announce row is in the right column. "Announce Death" label sits at x=0 and the
    -- checkboxes start just after it. Group step: checkbox(26) + label_gap(4) +
    -- auto_label(~27 max) + inter_group(15) = 72px. First checkbox follows the label
    -- (width 120) + gap (4) = x 124.
    local charterDeathControlX = 124
    local charterDeathGroupWidth = 72
    local rowOneY = 0
    local rowTwoY = -runLayout.ROW_HEIGHT
    local charterModeRow = runLayout:CreateRow(frame.start.charterSection.content, charterRightX, rowOneY, runLayout.COLUMN_WIDTH)
    local charterAnnounceRow = runLayout:CreateRow(frame.start.charterSection.content, charterRightX, rowTwoY, runLayout.COLUMN_WIDTH)

    frame.start.presetLabel = CreateLabel(frame.start.charterSection.content, "Presets", charterLeftX, rowOneY - 4, "GameFontNormalSmall", charterLabelWidth)
    frame.start.presetLabel:SetTextColor(BODY_TEXT.r, BODY_TEXT.g, BODY_TEXT.b)
    RegisterRunControl(frame.start, frame.start.presetLabel, frame.start.charterSection)
    local presetButtonWidth = 116
    local presetButtonHeight = 22
    frame.start.casualBtn = CreateButton(frame.start.charterSection.content, "Casual", presetButtonWidth, presetButtonHeight)
    frame.start.casualBtn:SetPoint("TOPLEFT", frame.start.charterSection.content, "TOPLEFT", charterControlX, rowOneY - 1)
    frame.start.casualBtn:SetScript("OnClick", function()
        ApplyStartPreset(frame, "CASUAL")
    end)

    frame.start.chefBtn = CreateButton(frame.start.charterSection.content, "Chef's Special", presetButtonWidth, presetButtonHeight)
    frame.start.chefBtn:SetPoint("LEFT", frame.start.casualBtn, "RIGHT", 6, 0)
    frame.start.chefBtn:SetScript("OnClick", function()
        ApplyStartPreset(frame, "CHEF_SPECIAL")
    end)

    frame.start.ironmanBtn = CreateButton(frame.start.charterSection.content, "Ironman", presetButtonWidth, presetButtonHeight)
    frame.start.ironmanBtn:SetPoint("TOPLEFT", frame.start.charterSection.content, "TOPLEFT", charterControlX, rowTwoY - 1)
    frame.start.ironmanBtn:SetScript("OnClick", function()
        ApplyStartPreset(frame, "IRONMAN")
    end)
    frame.start.ironVigilBtn = CreateButton(frame.start.charterSection.content, "Iron Vigil", presetButtonWidth, presetButtonHeight)
    frame.start.ironVigilBtn:SetPoint("LEFT", frame.start.ironmanBtn, "RIGHT", 6, 0)
    frame.start.ironVigilBtn:SetScript("OnClick", function()
        ApplyStartPreset(frame, "IRON_VIGIL")
    end)

    RegisterRunControl(frame.start, frame.start.casualBtn, frame.start.charterSection)
    RegisterRunControl(frame.start, frame.start.chefBtn, frame.start.charterSection)
    RegisterRunControl(frame.start, frame.start.ironmanBtn, frame.start.charterSection)
    RegisterRunControl(frame.start, frame.start.ironVigilBtn, frame.start.charterSection)
    frame.start.groupingLabel = CreateLabel(frame.start.charterSection.content, "Mode", 0, 0, "GameFontNormalSmall", 90)
    runLayout:PlaceRowLabel(charterModeRow, frame.start.groupingLabel, 0, 120)
    RegisterRunControl(frame.start, frame.start.groupingLabel, frame.start.charterSection)
    frame.start.groupingDropdown = CreateDropdown(frame.start.charterSection.content, "SoftcoreMasterGroupingDropdown", GROUPING_OPTIONS, frame.start.selectedRules.groupingMode, function(value)
        frame.start.selectedRules.groupingMode = value
        if SC.ApplyGroupingMode then
            SC:ApplyGroupingMode(frame.start.selectedRules)
        end
        SC:MasterUI_Refresh()
    end, 140)
    runLayout:PlaceRowDropdown(charterModeRow, frame.start.groupingDropdown, charterRightControlX)
    RegisterRunControl(frame.start, frame.start.groupingDropdown, frame.start.charterSection)

    frame.start.deathAnnounceLabel = CreateLabel(frame.start.charterSection.content, "Announce Death", 0, 0, "GameFontNormalSmall", 120)
    runLayout:PlaceRowLabel(charterAnnounceRow, frame.start.deathAnnounceLabel, 0, 120)
    RegisterRunControl(frame.start, frame.start.deathAnnounceLabel, frame.start.charterSection)
    frame.start.deathAnnounceChatCheck = CreateDeathAnnounceCheckbox(frame.start.charterSection.content, "CHAT", "Chat", 0, 0)
    runLayout:PlaceRowCheckbox(charterAnnounceRow, frame.start.deathAnnounceChatCheck, charterDeathControlX)
    runLayout:PlaceCheckboxText(frame.start.deathAnnounceChatCheck)
    RegisterRunControl(frame.start, frame.start.deathAnnounceChatCheck, frame.start.charterSection)
    frame.start.deathAnnouncePartyCheck = CreateDeathAnnounceCheckbox(frame.start.charterSection.content, "PARTY", "Party", 0, 0)
    runLayout:PlaceRowCheckbox(charterAnnounceRow, frame.start.deathAnnouncePartyCheck, charterDeathControlX + charterDeathGroupWidth)
    runLayout:PlaceCheckboxText(frame.start.deathAnnouncePartyCheck)
    RegisterRunControl(frame.start, frame.start.deathAnnouncePartyCheck, frame.start.charterSection)
    frame.start.deathAnnounceGuildCheck = CreateDeathAnnounceCheckbox(frame.start.charterSection.content, "GUILD", "Guild", 0, 0)
    runLayout:PlaceRowCheckbox(charterAnnounceRow, frame.start.deathAnnounceGuildCheck, charterDeathControlX + charterDeathGroupWidth * 2)
    runLayout:PlaceCheckboxText(frame.start.deathAnnounceGuildCheck)
    RegisterRunControl(frame.start, frame.start.deathAnnounceGuildCheck, frame.start.charterSection)

    local y = 0
    for _, spec in ipairs(ECONOMY_RULES) do
        local checkbox = CreateAllowCheckbox(frame.start.accessSection.content, frame.start.selectedRules, spec, 0, y)
        RegisterRunControl(frame.start, checkbox, frame.start.accessSection)
        y = y - runLayout.ROW_HEIGHT
    end

    y = 0
    for _, spec in ipairs(MOVEMENT_RULES) do
        local checkbox = CreateAllowCheckbox(frame.start.travelSection.content, frame.start.selectedRules, spec, 0, y)
        RegisterRunControl(frame.start, checkbox, frame.start.travelSection)
        y = y - runLayout.ROW_HEIGHT
    end

    local cameraRow = runLayout:CreateRow(frame.start.travelSection.content, 0, -(#MOVEMENT_RULES * runLayout.ROW_HEIGHT), runLayout.COLUMN_WIDTH)
    frame.start.cameraRuleCheck = CreateFrame("CheckButton", nil, frame.start.travelSection.content, "UICheckButtonTemplate")
    runLayout:PlaceRowCheckbox(cameraRow, frame.start.cameraRuleCheck, 0)
    frame.start.cameraRuleCheck.label = frame.start.cameraRuleCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    runLayout:PlaceCheckboxText(frame.start.cameraRuleCheck)
    frame.start.cameraRuleCheck.label:SetTextColor(BODY_TEXT.r, BODY_TEXT.g, BODY_TEXT.b)
    frame.start.cameraRuleCheck.label:SetText("Cinematic Camera")
    frame.start.cameraRuleCheck.ruleKey = "actionCam"
    frame.start.cameraRuleCheck:SetScript("OnClick", function(btn)
        if IsActiveRun() and not frame.start.isModifyingRules then
            local mode = btn:GetChecked() and (GetSelectedCameraMode(frame.start) or "CINEMATIC") or nil
            if mode and SC.SetCameraMode then
                SC:SetCameraMode(mode)
            end
            SC:MasterUI_Refresh()
            return
        end
        frame.start.selectedCameraMode = btn:GetChecked() and (GetSelectedCameraMode(frame.start) or "CINEMATIC") or nil
        SetCameraRules(frame.start.selectedRules, frame.start.selectedCameraMode)
        SC:MasterUI_Refresh()
    end)
    RegisterRunControl(frame.start, frame.start.cameraRuleCheck, frame.start.travelSection)

    local gearLimitRow = runLayout:CreateRow(frame.start.gearSection.content, 0, 0, runLayout.COLUMN_WIDTH)
    frame.start.gearLimitCheck = CreateFrame("CheckButton", nil, frame.start.gearSection.content, "UICheckButtonTemplate")
    runLayout:PlaceRowCheckbox(gearLimitRow, frame.start.gearLimitCheck, 0)
    frame.start.gearLimitCheck.label = frame.start.gearLimitCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    runLayout:PlaceCheckboxText(frame.start.gearLimitCheck)
    frame.start.gearLimitCheck.label:SetTextColor(BODY_TEXT.r, BODY_TEXT.g, BODY_TEXT.b)
    frame.start.gearLimitCheck.label:SetText("Restrict Gear")
    frame.start.gearLimitCheck.ruleKey = "gearQuality"
    frame.start.gearLimitCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            if frame.start.selectedRules.gearQuality == "ALLOWED" then
                frame.start.selectedRules.gearQuality = "GREEN_OR_LOWER"
            end
        else
            frame.start.selectedRules.gearQuality = "ALLOWED"
        end
        SC:MasterUI_Refresh()
    end)
    RegisterRunControl(frame.start, frame.start.gearLimitCheck, frame.start.gearSection)
    frame.start.gearDropdown = CreateDropdown(frame.start.gearSection.content, "SoftcoreMasterGearDropdown", GEAR_OPTIONS, frame.start.selectedRules.gearQuality ~= "ALLOWED" and frame.start.selectedRules.gearQuality or "GREEN_OR_LOWER", function(value)
        frame.start.selectedRules.gearQuality = value
        SC:MasterUI_Refresh()
    end, 145)
    runLayout:PlaceDropdownAfterLabel(frame.start.gearLimitCheck.label, frame.start.gearDropdown)
    RegisterRunControl(frame.start, frame.start.gearDropdown, frame.start.gearSection)
    frame.start.selfCraftedCheck = CreateFrame("CheckButton", nil, frame.start.gearSection.content, "UICheckButtonTemplate")
    frame.start.selfCraftedCheck:SetPoint("TOPLEFT", frame.start.gearSection.content, "TOPLEFT", 16, -runLayout.ROW_HEIGHT)
    frame.start.selfCraftedCheck.label = frame.start.selfCraftedCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.start.selfCraftedCheck.label:SetPoint("LEFT", frame.start.selfCraftedCheck, "RIGHT", RUN_LAYOUT.CHECKBOX_LABEL_GAP, 0)
    frame.start.selfCraftedCheck.label:SetWidth(0)
    frame.start.selfCraftedCheck.label:SetJustifyH("LEFT")
    frame.start.selfCraftedCheck.label:SetTextColor(BODY_TEXT.r, BODY_TEXT.g, BODY_TEXT.b)
    frame.start.selfCraftedCheck.label:SetText("Allow any self-crafted gear")
    frame.start.selfCraftedCheck:SetScript("OnClick", function(btn)
        local ironmanSelected = frame.start.selectedPreset == "IRONMAN" or frame.start.selectedPreset == "IRON_VIGIL"
        if ironmanSelected then
            frame.start.selectedRules.selfCraftedGearAllowed = false
            btn:SetChecked(false)
            SC:MasterUI_Refresh()
            return
        end
        frame.start.selectedRules.selfCraftedGearAllowed = btn:GetChecked() == true
        SC:MasterUI_Refresh()
    end)
    RegisterRunControl(frame.start, frame.start.selfCraftedCheck, frame.start.gearSection)
    frame.start.heirloomCheck = CreateAllowCheckbox(frame.start.gearSection.content, frame.start.selectedRules, { label = "Allow Heirlooms", key = "heirlooms" }, 0, -runLayout.ROW_HEIGHT * 2)
    RegisterRunControl(frame.start, frame.start.heirloomCheck, frame.start.gearSection)
    frame.start.enchantsCheck = CreateAllowCheckbox(frame.start.gearSection.content, frame.start.selectedRules, { label = "Allow Enchants", key = "enchants" }, 0, -runLayout.ROW_HEIGHT * 3)
    RegisterRunControl(frame.start, frame.start.enchantsCheck, frame.start.gearSection)
    frame.start.consumablesCheck = CreateAllowCheckbox(frame.start.gearSection.content, frame.start.selectedRules, { label = "Allow Consumables", key = "consumables" }, 0, -runLayout.ROW_HEIGHT * 4)
    RegisterRunControl(frame.start, frame.start.consumablesCheck, frame.start.gearSection)

    local maxGapRow = runLayout:CreateRow(frame.start.partyDungeonSection.content, 0, 0, runLayout.COLUMN_WIDTH)
    frame.start.maxGapCheck = CreateFrame("CheckButton", nil, frame.start.partyDungeonSection.content, "UICheckButtonTemplate")
    runLayout:PlaceRowCheckbox(maxGapRow, frame.start.maxGapCheck, 0)
    frame.start.maxGapCheck.label = frame.start.maxGapCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    runLayout:PlaceCheckboxText(frame.start.maxGapCheck)
    frame.start.maxGapCheck.label:SetTextColor(BODY_TEXT.r, BODY_TEXT.g, BODY_TEXT.b)
    frame.start.maxGapCheck.label:SetText("Enforce Level Gap")
    frame.start.maxGapCheck:SetScript("OnClick", function(self)
        frame.start.selectedRules.maxLevelGap = self:GetChecked() and DISALLOWED_OUTCOME or "ALLOWED"
        SC:MasterUI_Refresh()
    end)
    RegisterRunControl(frame.start, frame.start.maxGapCheck, frame.start.partyDungeonSection)
    frame.start.maxGapLabel = CreateLabel(frame.start.partyDungeonSection.content, "Levels", 0, 0, "GameFontHighlightSmall", 44)
    frame.start.maxGapLabel:SetTextColor(MUTED_TEXT.r, MUTED_TEXT.g, MUTED_TEXT.b)
    RegisterRunControl(frame.start, frame.start.maxGapLabel, frame.start.partyDungeonSection)
    frame.start.maxGapBox = CreateFrame("EditBox", nil, frame.start.partyDungeonSection.content, "InputBoxTemplate")
    frame.start.maxGapBox:SetSize(42, 22)
    frame.start.maxGapBox:ClearAllPoints()
    frame.start.maxGapBox:SetPoint("LEFT", frame.start.maxGapCheck.label, "RIGHT", runLayout.INLINE_FIELD_GAP * 2, 0)
    frame.start.maxGapLabel:ClearAllPoints()
    frame.start.maxGapLabel:SetPoint("LEFT", frame.start.maxGapBox, "RIGHT", 4, 0)
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
    RegisterRunControl(frame.start, frame.start.maxGapBox, frame.start.partyDungeonSection)
    frame.start.dungeonRepeatCheck = CreateAllowCheckbox(frame.start.partyDungeonSection.content, frame.start.selectedRules, { label = "Allow Repeated Dungeons", key = "dungeonRepeat" }, 0, -runLayout.ROW_HEIGHT)
    RegisterRunControl(frame.start, frame.start.dungeonRepeatCheck, frame.start.partyDungeonSection)
    frame.start.instancedPvPCheck = CreateAllowCheckbox(frame.start.partyDungeonSection.content, frame.start.selectedRules, { label = "Allow Instanced PvP", key = "instancedPvP" }, 0, -(runLayout.ROW_HEIGHT * 2))
    RegisterRunControl(frame.start, frame.start.instancedPvPCheck, frame.start.partyDungeonSection)

    function frame.start:RefreshControls()
        if SC.ApplyGroupingMode then
            SC:ApplyGroupingMode(self.selectedRules)
        end
        self.selectedRules.instanceWithUnsyncedPlayers = "ALLOWED"
        self.selectedRules.unsyncedMembers = "ALLOWED"

        SetDropdownSelected(self.groupingDropdown, GROUPING_OPTIONS, self.selectedRules.groupingMode)
        if SC.IsDeathAnnouncementChannelEnabled then
            self.deathAnnounceChatCheck:SetChecked(SC:IsDeathAnnouncementChannelEnabled("CHAT"))
            self.deathAnnouncePartyCheck:SetChecked(SC:IsDeathAnnouncementChannelEnabled("PARTY"))
            self.deathAnnounceGuildCheck:SetChecked(SC:IsDeathAnnouncementChannelEnabled("GUILD"))
            self.deathAnnounceChatCheck:SetEnabled(true)
            self.deathAnnouncePartyCheck:SetEnabled(true)
            self.deathAnnounceGuildCheck:SetEnabled(true)
            SetFontStringRGB(self.deathAnnounceChatCheck.label, BODY_TEXT)
            SetFontStringRGB(self.deathAnnouncePartyCheck.label, BODY_TEXT)
            SetFontStringRGB(self.deathAnnounceGuildCheck.label, BODY_TEXT)
        end
        local gearRestricted = self.selectedRules.gearQuality ~= "ALLOWED"
        local gearDropdownValue = gearRestricted and self.selectedRules.gearQuality or "GREEN_OR_LOWER"
        SetDropdownSelected(self.gearDropdown, GEAR_OPTIONS, gearDropdownValue)
        local isSolo = self.selectedRules.groupingMode == "SOLO_SELF_FOUND"
        if isSolo then
            self.selectedRules.maxLevelGap = "ALLOWED"
        end
        local canEdit = not IsActiveRun() or self.isModifyingRules
        local highlightingRuleChanges = (self.isModifyingRules or self.isReviewingRuleAmendment) and self.draftBaseRules
        self.maxGapCheck:SetChecked(not isSolo and self.selectedRules.maxLevelGap ~= "ALLOWED")
        self.maxGapCheck:SetEnabled(canEdit and not isSolo)
        local locked = not canEdit or isSolo
        self.maxGapCheck.label:SetFontObject(GameFontNormalSmall)
        if locked then
            if highlightingRuleChanges and tostring(self.draftBaseRules.maxLevelGap) ~= tostring(self.selectedRules.maxLevelGap) then
                local checked = IsCheckedRuleValue("maxLevelGap", self.selectedRules.maxLevelGap)
                SetFontStringRGB(self.maxGapCheck.label, checked == false and RED_TEXT or GREEN_TEXT)
            else
                SetFontStringRGB(self.maxGapCheck.label, BODY_TEXT)
            end
        elseif highlightingRuleChanges then
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
                if highlightingRuleChanges and tostring(self.draftBaseRules.maxLevelGapValue) ~= tostring(self.selectedRules.maxLevelGapValue) then
                    SetFontStringRGB(self.maxGapLabel, GREEN_TEXT)
                else
                    SetFontStringRGB(self.maxGapLabel, MUTED_TEXT)
                end
            elseif highlightingRuleChanges then
                local baseVal = self.draftBaseRules.maxLevelGapValue
                local curVal  = self.selectedRules.maxLevelGapValue
                if tostring(baseVal) ~= tostring(curVal) then
                    SetFontStringRGB(self.maxGapLabel, GREEN_TEXT)
                else
                    SetFontStringRGB(self.maxGapLabel, MUTED_TEXT)
                end
            else
                SetFontStringRGB(self.maxGapLabel, MUTED_TEXT)
            end
        end
        if self.groupingLabel then
            if highlightingRuleChanges and tostring(self.draftBaseRules.groupingMode) ~= tostring(self.selectedRules.groupingMode) then
                SetFontStringRGB(self.groupingLabel, GREEN_TEXT)
            else
                SetFontStringRGB(self.groupingLabel, BODY_TEXT)
            end
        end
        self.gearLimitCheck:SetChecked(gearRestricted)
        self.gearLimitCheck:SetEnabled(canEdit)
        if UIDropDownMenu_EnableDropDown and UIDropDownMenu_DisableDropDown then
            if canEdit and gearRestricted then
                UIDropDownMenu_EnableDropDown(self.gearDropdown)
            else
                UIDropDownMenu_DisableDropDown(self.gearDropdown)
            end
        end
        if self.gearLimitCheck and self.gearLimitCheck.label then
            if highlightingRuleChanges and tostring(self.draftBaseRules.gearQuality) ~= tostring(self.selectedRules.gearQuality) then
                SetFontStringRGB(self.gearLimitCheck.label, gearRestricted and GREEN_TEXT or RED_TEXT)
            else
                SetFontStringRGB(self.gearLimitCheck.label, BODY_TEXT)
            end
        end

        for _, checkbox in ipairs(self.controls) do
            if checkbox.label and checkbox.GetChecked
                and checkbox ~= self.maxGapCheck
                and checkbox ~= self.gearLimitCheck
                and checkbox ~= self.cameraRuleCheck
                and checkbox ~= self.selfCraftedCheck then
                local text = checkbox.label:GetText()
                for _, spec in ipairs(ECONOMY_RULES) do
                    if text == spec.label then checkbox:SetChecked(not IsDisallowed(self.selectedRules[spec.key])) end
                end
                for _, spec in ipairs(MOVEMENT_RULES) do
                    if text == spec.label then checkbox:SetChecked(not IsDisallowed(self.selectedRules[spec.key])) end
                end
                if highlightingRuleChanges and checkbox.ruleKey then
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
        self.enchantsCheck:SetChecked(not IsDisallowed(self.selectedRules.enchants))
        self.dungeonRepeatCheck:SetChecked(not IsDisallowed(self.selectedRules.dungeonRepeat))
        self.consumablesCheck:SetChecked(not IsDisallowed(self.selectedRules.consumables))
        self.instancedPvPCheck:SetChecked(not IsDisallowed(self.selectedRules.instancedPvP))
        local ironmanSelected = self.selectedPreset == "IRONMAN" or self.selectedPreset == "IRON_VIGIL"
        if ironmanSelected then
            self.selectedRules.selfCraftedGearAllowed = false
        end
        local selfCraftedActive = self.selectedRules.selfCraftedGearAllowed == true
        self.selfCraftedCheck:SetChecked(selfCraftedActive)
        self.selfCraftedCheck:SetEnabled(canEdit and gearRestricted and not ironmanSelected)
        if self.selfCraftedCheck.label then
            if highlightingRuleChanges and tostring(self.draftBaseRules.selfCraftedGearAllowed) ~= tostring(self.selectedRules.selfCraftedGearAllowed) then
                SetFontStringRGB(self.selfCraftedCheck.label, selfCraftedActive and GREEN_TEXT or RED_TEXT)
            elseif gearRestricted and not ironmanSelected then
                SetFontStringRGB(self.selfCraftedCheck.label, BODY_TEXT)
            else
                SetFontStringRGB(self.selfCraftedCheck.label, MUTED_TEXT)
            end
        end
        local active = IsActiveRun()
        local editingCamera = (not active) or self.isModifyingRules or self.isReviewingRuleAmendment
        local cameraRequired = active and (not self.isModifyingRules) and SC.IsCameraModeRequired and SC:IsCameraModeRequired()
        local cameraRuleOn = IsCameraRuleEnforced(self.selectedRules) or cameraRequired
        self.cameraRuleCheck:SetChecked(cameraRuleOn)
        self.cameraRuleCheck:SetEnabled(((self.setupEnabled ~= false) and editingCamera) and not self.isReviewingRuleAmendment)
        if highlightingRuleChanges and tostring(self.draftBaseRules.actionCam) ~= tostring(self.selectedRules.actionCam) then
            SetFontStringRGB(self.cameraRuleCheck.label, cameraRuleOn and GREEN_TEXT or RED_TEXT)
        else
            SetFontStringRGB(self.cameraRuleCheck.label, BODY_TEXT)
        end
        self.selectedRules.maxDeaths = false
        self.selectedRules.maxDeathsValue = self.selectedRules.maxDeathsValue or 3
    end

    frame.start.primaryBtn = CreateButton(startPanel, "Start Run", 120, 24)
    frame.start.primaryBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", RUN_FOOTER_LEFT_INSET, RUN_FOOTER_BOTTOM)
    frame.start.primaryBtn:SetScript("OnClick", function()
        local ruleset = SC:CopyTable(frame.start.selectedRules)
        if SC.ApplyGroupingMode then
            SC:ApplyGroupingMode(ruleset)
        end
        ruleset.instanceWithUnsyncedPlayers = "ALLOWED"
        ruleset.unsyncedMembers = "ALLOWED"
        ruleset.achievementPreset = frame.start.selectedPreset or ruleset.achievementPreset or "CUSTOM"
        if IsInGroup() and not IsInRaid() then
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
    frame.start.partySyncBtn = CreateButton(startPanel, "Party Sync", 100, 24)
    frame.start.partySyncBtn:SetPoint("LEFT", frame.start.modifyBtn, "RIGHT", 8, 0)
    frame.start.partySyncBtn:SetScript("OnClick", function()
        if SC.RunPartySyncAction then
            SC:RunPartySyncAction()
        else
            Print("party sync is not loaded.")
        end
        SC:MasterUI_Refresh()
    end)
    frame.start.partySyncBtn:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Party Sync", 1, 0.82, 0.2)
        local route = SC.GetPartySyncAction and SC:GetPartySyncAction()
        if route and route.message then
            GameTooltip:AddLine(route.message, 0.94, 0.86, 0.68, true)
        end
        GameTooltip:AddLine("One click starts a staged sync plan. Required member approvals still use the Run tab.", 0.68, 0.56, 0.38, true)
        GameTooltip:AddLine("After each accepted stage, Softcore waits briefly for addon messages to settle, then continues automatically.", 0.68, 0.56, 0.38, true)
        GameTooltip:AddLine("If state is stale, Softcore requests fresh state before proposing another change.", 0.68, 0.56, 0.38, true)
        GameTooltip:Show()
    end)
    frame.start.partySyncBtn:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    frame.start.applyChangesBtn = CreateButton(startPanel, "Apply Changes", 120, 24)
    frame.start.applyChangesBtn:SetPoint("LEFT", frame.start.primaryBtn, "RIGHT", 8, 0)
    frame.start.applyChangesBtn:SetScript("OnClick", function()
        local changes = BuildRuleChanges(frame.start.draftBaseRules or {}, frame.start.selectedRules or {})
        if CountRuleChanges(changes) == 0 then
            Print("no rule changes selected.")
            return
        end

        if IsInGroup() and not IsInRaid() then
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
                local amendment = SC:ProposeRuleAmendment(changes, "Run rules modified from the Run tab.", {
                    suppressProposalAcceptLogs = true,
                })
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

    CreateOverviewTab(frame)

    CreateViolationsTab(frame)
    CreateLogTab(frame)

    local achievementsPanel = CreatePanel(frame)
    frame.panels[TAB_ACHIEVEMENTS] = achievementsPanel
    frame.achievements = { sections = {}, collapsed = {} }
    CreateSectionHeader(achievementsPanel, "Achievements", 0, 0, ACHIEVEMENT_LAYOUT.CONTENT_WIDTH)

    local cardWidth = math.floor((ACHIEVEMENT_LAYOUT.CONTENT_WIDTH - (ACHIEVEMENT_LAYOUT.SUMMARY_GAP * 2)) / 3)
    frame.achievements.earnedCard = CreateAchievementSummaryCard(achievementsPanel, "Earned", 0, ACHIEVEMENT_LAYOUT.SUMMARY_TOP, cardWidth)
    frame.achievements.progressCard = CreateAchievementSummaryCard(achievementsPanel, "In Progress", cardWidth + ACHIEVEMENT_LAYOUT.SUMMARY_GAP, ACHIEVEMENT_LAYOUT.SUMMARY_TOP, cardWidth)
    frame.achievements.remainingCard = CreateAchievementSummaryCard(achievementsPanel, "Open", (cardWidth + ACHIEVEMENT_LAYOUT.SUMMARY_GAP) * 2, ACHIEVEMENT_LAYOUT.SUMMARY_TOP, cardWidth)

    frame.achievements.empty = CreateField(achievementsPanel, 0, ACHIEVEMENT_LAYOUT.SCROLL_TOP, 620)
    frame.achievements.empty:SetText("No achievements are loaded.")
    frame.achievements.scroll = CreateFrame("ScrollFrame", "SoftcoreAchievementsScrollFrame", achievementsPanel, "UIPanelScrollFrameTemplate")
    frame.achievements.scroll:SetPoint("TOPLEFT", achievementsPanel, "TOPLEFT", 0, ACHIEVEMENT_LAYOUT.SCROLL_TOP)
    frame.achievements.scroll:SetSize(ACHIEVEMENT_LAYOUT.SCROLL_WIDTH, ACHIEVEMENT_LAYOUT.SCROLL_HEIGHT)
    frame.achievements.scroll:EnableMouseWheel(true)
    frame.achievements.scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local maxScroll = self:GetVerticalScrollRange() or 0
        local nextScroll = current - (delta * 46)
        if nextScroll < 0 then nextScroll = 0 end
        if nextScroll > maxScroll then nextScroll = maxScroll end
        self:SetVerticalScroll(nextScroll)
        local scrollBar = _G[self:GetName() .. "ScrollBar"]
        if scrollBar then
            scrollBar:SetValue(nextScroll)
        end
    end)
    frame.achievements.content = CreateFrame("Frame", nil, frame.achievements.scroll)
    frame.achievements.content:SetSize(ACHIEVEMENT_LAYOUT.CONTENT_WIDTH, ACHIEVEMENT_LAYOUT.SCROLL_HEIGHT)
    frame.achievements.scroll:SetScrollChild(frame.achievements.content)

    self.masterFrame = frame
    self:MasterUI_Refresh()
end
