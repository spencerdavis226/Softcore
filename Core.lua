-- Softcore
-- Local MVP state, slash commands, and shared helpers.

local ADDON_NAME = ...

Softcore = Softcore or {}
local SC = Softcore

SC.name = "Softcore"
SC.version = "0.5.0"

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r " .. tostring(message))
end

local function NormalizeDeathAnnouncementMode(value)
    value = string.lower(tostring(value or ""))
    if value == "" or value == "off" or value == "none" or value == "disabled" then
        return "OFF"
    end
    if value == "chat" or value == "local" then
        return "CHAT"
    end
    if value == "party" or value == "group" then
        return "PARTY"
    end
    if value == "guild" then
        return "GUILD"
    end
    return nil
end

local DEATH_ANNOUNCEMENT_CHANNELS = {
    CHAT = true,
    PARTY = true,
    GUILD = true,
}

local DEATH_ANNOUNCEMENT_ORDER = { "CHAT", "PARTY", "GUILD" }

local function CopyDeathAnnouncementChannels(value)
    local channels = {}

    if type(value) == "table" then
        for channel, enabled in pairs(value) do
            local normalized = NormalizeDeathAnnouncementMode(channel)
            if normalized and normalized ~= "OFF" and enabled then
                channels[normalized] = true
            end
        end
        return channels
    end

    local normalized = NormalizeDeathAnnouncementMode(value)
    if normalized and normalized ~= "OFF" then
        channels[normalized] = true
    end
    return channels
end

local function FormatDeathAnnouncementChannels(channels)
    local labels = {}
    for _, channel in ipairs(DEATH_ANNOUNCEMENT_ORDER) do
        if channels[channel] then
            table.insert(labels, string.lower(channel))
        end
    end
    if #labels == 0 then
        return "off"
    end
    return table.concat(labels, ", ")
end

local function GetGroupAnnouncementChannel()
    if IsInRaid() then
        return nil
    end
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInGroup() then
        return "PARTY"
    end
    return nil
end

function SC:PlayUISound(event)
    if not PlaySound then return end
    local SK = _G["SOUNDKIT"] or {}
    local sounds = {
        RUN_STARTED       = SK.IG_QUEST_LOG_ACCEPT          or 878,
        VIOLATION         = SK.UI_ERROR_MESSAGE              or 882,
        DEATH             = SK.IG_QUEST_FAILED               or 851,
        VIOLATION_CLEARED = SK.IG_QUEST_OBJECTIVE_COMPLETE   or 879,
        PROPOSAL_RECEIVED = SK.READY_CHECK                   or 8960,
        ACHIEVEMENT_EARNED = SK.UI_EpicLoot_Toasts           or SK.UI_BonusLootRoll_Start or 31578,
        RUN_COMPLETED     = SK.UI_AzeriteEmpoweredItem       or SK.UI_EpicLoot_Toasts or 31578,
    }
    local id = sounds[event]
    if id then PlaySound(id, "Master") end
end

local function FormatTime(timestamp)
    if not timestamp then
        return "never"
    end

    return date("%Y-%m-%d %H:%M:%S", timestamp)
end

local function FormatDuration(seconds)
    seconds = tonumber(seconds or 0) or 0
    if seconds < 0 then seconds = 0 end

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if hours > 0 then
        return string.format("%dh %02dm", hours, minutes)
    end
    return string.format("%dm", minutes)
end

local function GetPlayerSnapshot()
    local name, realm = UnitFullName("player")

    if not realm or realm == "" then
        realm = GetRealmName()
    end

    local _, classFile = UnitClass("player")

    return {
        name = name or "Unknown",
        realm = realm or "Unknown",
        class = classFile or "UNKNOWN",
        level = UnitLevel("player") or 0,
        zone = GetRealZoneText() or "Unknown",
    }
end

local function BuildPlayerKey(name, realm)
    if not realm or realm == "" then
        realm = GetRealmName()
    end

    return (name or "Unknown") .. "-" .. (realm or "Unknown")
end

local function SplitPlayerKey(playerKey)
    local name, realm = string.match(playerKey or "", "^([^-]+)%-(.+)$")
    if name then
        return name, realm
    end

    return playerKey or "Unknown", GetRealmName()
end

local function FormatPlayerLabel(playerKey)
    local name = SplitPlayerKey(playerKey)
    return name or "Unknown"
end

local function GetPlayerKey(character)
    character = character or GetPlayerSnapshot()
    return BuildPlayerKey(character.name, character.realm)
end

local function ApplyGroupingModeRules(ruleset)
    ruleset = ruleset or {}
    ruleset.groupingMode = ruleset.groupingMode or "SYNCED_GROUP_ALLOWED"
    ruleset.death = "CHARACTER_FAIL"
    ruleset.deathFails = "CHARACTER_ONLY"

    if ruleset.groupingMode == "SOLO_SELF_FOUND" then
        ruleset.allowLateJoin = false
        ruleset.allowReplacementCharacters = false
        ruleset.failedMemberBlocksParty = true
        ruleset.requireLeaderApprovalForJoin = false
    else
        ruleset.groupingMode = "SYNCED_GROUP_ALLOWED"
        ruleset.allowLateJoin = true
        ruleset.allowReplacementCharacters = true
        ruleset.failedMemberBlocksParty = true
        ruleset.requireLeaderApprovalForJoin = false
    end

    return ruleset
end

local function CreateDefaultRuleset()
    local ruleset = {
        id = "default",
        name = "Default Softcore Rules",
        version = 1,
        warningsAreFatal = false,
        deathIsFatal = true,
        death = "CHARACTER_FAIL",
        deathFails = "CHARACTER_ONLY",
        groupingMode = "SYNCED_GROUP_ALLOWED",
        failedMemberBlocksParty = true,
        allowLateJoin = true,
        allowReplacementCharacters = true,
        requireLeaderApprovalForJoin = false,
        auctionHouse = "WARNING",
        mailbox = "WARNING",
        trade = "WARNING",
        mounts = "ALLOWED",
        flying = "ALLOWED",
        flightPaths = "ALLOWED",
        outsiderGrouping = "WARNING",
        unsyncedMembers = "ALLOWED",
        maxLevelGap = "ALLOWED",
        maxLevelGapValue = 3,
        dungeonRepeat = "LOG_ONLY",
        gearQuality = "ALLOWED",
        selfCraftedGearAllowed = false,
        heirlooms = "WARNING",
        enchants = "ALLOWED",
        instanceWithUnsyncedPlayers = "WARNING",
        bank = "WARNING",
        warbandBank = "WARNING",
        guildBank = "WARNING",
        voidStorage = "LOG_ONLY",
        craftingOrders = "LOG_ONLY",
        vendor = "ALLOWED",
        consumables = "ALLOWED",
        instancedPvP = "ALLOWED",
        actionCam = "ALLOWED",
        maxDeaths = false,
        maxDeathsValue = 3,
    }

    return ApplyGroupingModeRules(ruleset)
end

local function CreateDefaultGovernance()
    return {
        mode = "ACTIVE_PARTY_MAJORITY",
        allowAnyActiveParticipantToPropose = true,
        requireVoteForRuleChanges = true,
        requireVoteForViolationClears = false,
    }
end

local function GetCurrentPartyKeys()
    local keys = {}

    keys[GetPlayerKey()] = true

    if IsInRaid() then
        return keys
    elseif IsInGroup() then
        for index = 1, GetNumSubgroupMembers() do
            local name, realm = UnitFullName("party" .. index)
            if name then
                keys[BuildPlayerKey(name, realm)] = true
            end
        end
    end

    return keys
end

local function ShouldThrottleRunNotice(run, bucketName, playerKey, seconds)
    run[bucketName] = run[bucketName] or {}
    local now = time()
    local last = run[bucketName][playerKey]
    if last and now - last < (seconds or 60) then
        return true
    end

    run[bucketName][playerKey] = now
    return false
end

local function IsCameraRuleEnforcedValue(value)
    return value ~= nil and value ~= "ALLOWED" and value ~= "LOG_ONLY" and value ~= false
end

local function DefaultCameraModeForRules(ruleset)
    if not ruleset then return nil end
    if IsCameraRuleEnforcedValue(ruleset.actionCam) then return "CINEMATIC" end
    return nil
end

local function EnsureRunDefaults(run)
    if run.active == nil then run.active = false end
    if run.valid == nil then run.valid = true end
    if run.failed == nil then run.failed = false end
    if run.completed == nil then run.completed = false end
    if run.levelGapBlocked == nil then run.levelGapBlocked = false end
    run.runId = run.runId or nil
    run.runName = run.runName or nil
    run.startTime = run.startTime or nil
    run.completedAt = run.completedAt or nil
    run.activeTimeSeconds = tonumber(run.activeTimeSeconds or 0) or 0
    run.activeTimeUpdatedAt = run.activeTimeUpdatedAt or nil
    run.deathCount = run.deathCount or 0
    run.warningCount = run.warningCount or 0
    run.ruleset = run.ruleset or CreateDefaultRuleset()
    run.participants = run.participants or {}
    run.participantOrder = run.participantOrder or {}
    run.partyStatus = run.partyStatus or "INACTIVE"
    run.governance = run.governance or CreateDefaultGovernance()
    run.conflicts = run.conflicts or {}
    run.dungeons = run.dungeons or {}
    run.dungeonOrder = run.dungeonOrder or {}

    for key, value in pairs(CreateDefaultRuleset()) do
        if run.ruleset[key] == nil then
            run.ruleset[key] = value
        end
    end

    ApplyGroupingModeRules(run.ruleset)
    run.cameraMode = run.cameraMode or DefaultCameraModeForRules(run.ruleset)

    for key, value in pairs(CreateDefaultGovernance()) do
        if run.governance[key] == nil then
            run.governance[key] = value
        end
    end

    for _, participant in pairs(run.participants) do
        if participant.status == "LEFT" then
            participant.status = "OUT_OF_PARTY"
        end
    end
end

local function EnsureDatabase()
    SoftcoreDB = SoftcoreDB or {}

    SoftcoreDB.character = SoftcoreDB.character or GetPlayerSnapshot()
    SoftcoreDB.run = SoftcoreDB.run or {}
    SoftcoreDB.eventLog = SoftcoreDB.eventLog or {}
    SoftcoreDB.violations = SoftcoreDB.violations or {}
    SoftcoreDB.nextIds = SoftcoreDB.nextIds or {}
    SoftcoreDB.nextIds.run = SoftcoreDB.nextIds.run or 0
    SoftcoreDB.nextIds.log = SoftcoreDB.nextIds.log or 0
    SoftcoreDB.nextIds.violation = SoftcoreDB.nextIds.violation or 0
    SoftcoreDB.nextIds.amendment = SoftcoreDB.nextIds.amendment or 0
    SoftcoreDB.nextIds.proposal = SoftcoreDB.nextIds.proposal or 0
    SoftcoreDB.ruleAmendments = SoftcoreDB.ruleAmendments or {}
    SoftcoreDB.proposals = SoftcoreDB.proposals or {}
    SoftcoreDB.pendingProposalId = SoftcoreDB.pendingProposalId or nil
    SoftcoreDB.acceptedRunId = SoftcoreDB.acceptedRunId or nil
    SoftcoreDB.acceptedRulesetHash = SoftcoreDB.acceptedRulesetHash or nil
    SoftcoreDB.settings = SoftcoreDB.settings or {}
    SoftcoreDB.settings.deathAnnouncements = SoftcoreDB.settings.deathAnnouncements or {}
    SoftcoreDB.sync = SoftcoreDB.sync or {}
    SoftcoreDB.sync.remoteSequences = SoftcoreDB.sync.remoteSequences or {}
    SoftcoreDB.sync.localSequence = SoftcoreDB.sync.localSequence or 0
    SoftcoreDB.sync.seenAuditIds = SoftcoreDB.sync.seenAuditIds or {}
    SoftcoreDB.sync.seenViolationIds = SoftcoreDB.sync.seenViolationIds or {}
    SoftcoreDB.debugTrace = SoftcoreDB.debugTrace or {}
    SoftcoreDB.runHistory = SoftcoreDB.runHistory or {}

    EnsureRunDefaults(SoftcoreDB.run)
    local localPlayerKey = GetPlayerKey(SoftcoreDB.character)
    for _, violation in ipairs(SoftcoreDB.violations) do
        violation.playerKey = violation.playerKey or localPlayerKey
    end
    for _, entry in ipairs(SoftcoreDB.eventLog) do
        entry.playerKey = entry.playerKey or localPlayerKey
        entry.actorKey = entry.actorKey or entry.playerKey
    end

    if SoftcoreDB.run.active and not SoftcoreDB.run.runId then
        SoftcoreDB.nextIds.run = SoftcoreDB.nextIds.run + 1
        SoftcoreDB.run.runId = "SC-RUN-" .. tostring(time()) .. "-" .. tostring(SoftcoreDB.nextIds.run)
    end

    SC.db = SoftcoreDB
    return SoftcoreDB
end

function SC:TraceDebug(kind, fields)
    local db = EnsureDatabase()
    local trace = db.debugTrace
    local entry = {
        time = time(),
        kind = tostring(kind or "DEBUG"),
    }

    if type(fields) == "table" then
        for key, value in pairs(fields) do
            if type(value) ~= "table" and type(value) ~= "function" then
                entry[key] = value
            end
        end
    end

    table.insert(trace, entry)
    while #trace > 300 do
        table.remove(trace, 1)
    end

    return entry
end

function SC:ClearDebugTrace(reason)
    local db = EnsureDatabase()
    db.debugTrace = {}
    if db.sync then
        db.sync.staleSendDrops = 0
        db.sync.lastStaleSendDrop = nil
        db.sync.coalescedStatusDrops = 0
        db.sync.lastCoalescedStatusDrop = nil
        db.sync.sendFailureCount = 0
        db.sync.lastSendError = nil
        db.sync.expiredChunkBuffers = 0
        db.sync.lastExpiredChunk = nil
    end
    return self:TraceDebug("DEBUG_TRACE_CLEARED", {
        reason = reason or "manual",
        playerKey = GetPlayerKey(db.character),
        runId = db.run and db.run.runId,
    })
end

local function BindCharacterDatabase()
    local currentCharacter = GetPlayerSnapshot()
    local currentKey = GetPlayerKey(currentCharacter)
    local legacyKey = SoftcoreDB and SoftcoreDB.character and GetPlayerKey(SoftcoreDB.character) or nil

    if not SoftcoreCharDB then
        if legacyKey and legacyKey == currentKey then
            SoftcoreCharDB = SoftcoreDB
        else
            SoftcoreCharDB = {}
        end
    end

    SoftcoreDB = SoftcoreCharDB
    SoftcoreDB.character = SoftcoreDB.character or currentCharacter
end

local function CreateStableId(kind)
    local db = EnsureDatabase()

    db.nextIds[kind] = (db.nextIds[kind] or 0) + 1
    return "SC-" .. string.upper(kind) .. "-" .. tostring(time()) .. "-" .. tostring(db.nextIds[kind])
end

local function HasRunData(run, eventLog, violations)
    if not run then
        return false
    end

    return run.runId ~= nil or #(eventLog or {}) > 0 or #(violations or {}) > 0
end

local function CopyTable(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = CopyTable(value)
    end
    return copy
end

function SC:CopyTable(source)
    return CopyTable(source)
end

function SC:GetDefaultRuleset()
    return CopyTable(CreateDefaultRuleset())
end

function SC:ApplyGroupingMode(ruleset)
    return ApplyGroupingModeRules(ruleset)
end

local PRESET_AWARD_LABELS = {
    CASUAL = "Casual",
    CHEF_SPECIAL = "Chef's Special",
    IRONMAN = "Ironman",
    IRON_VIGIL = "Iron Vigil",
    CUSTOM = "Custom",
}

local RUN_NAME_ECONOMY_RULES = { "auctionHouse", "mailbox", "trade", "bank", "warbandBank", "guildBank" }
local RUN_NAME_BANK_RULES = { "bank", "warbandBank", "guildBank" }
local RUN_NAME_TRAVEL_RULES = { "mounts", "flying", "flightPaths" }
local RUN_NAME_BOOST_RULES = { "heirlooms", "enchants", "consumables" }

local function RunNameRuleAllowed(value)
    return value == "ALLOWED" or value == "LOG_ONLY"
end

local function RunNameRuleRestricted(value)
    return value ~= nil and value ~= false and not RunNameRuleAllowed(value)
end

local function RunNameRulesAllAllowed(ruleset, keys)
    for _, key in ipairs(keys) do
        if not RunNameRuleAllowed(ruleset and ruleset[key]) then
            return false
        end
    end
    return true
end

local function RunNameRulesAllRestricted(ruleset, keys)
    for _, key in ipairs(keys) do
        if not RunNameRuleRestricted(ruleset and ruleset[key]) then
            return false
        end
    end
    return true
end

local function RunNameGrouped(ruleset)
    return (ruleset and ruleset.groupingMode) ~= "SOLO_SELF_FOUND"
end

local function RunNameSolo(ruleset)
    return ruleset and ruleset.groupingMode == "SOLO_SELF_FOUND"
end

local function RunNameGearAllowed(ruleset)
    return ruleset and (ruleset.gearQuality == nil or ruleset.gearQuality == "ALLOWED")
end

local function RunNameGearRestricted(ruleset)
    return ruleset and ruleset.gearQuality ~= nil and ruleset.gearQuality ~= "ALLOWED"
end

local function RunNameLevelGapOff(ruleset)
    return not RunNameRuleRestricted(ruleset and ruleset.maxLevelGap)
end

local function RunNameCameraOff(ruleset)
    return not RunNameRuleRestricted(ruleset and ruleset.actionCam)
end

local function RunNameCommonEasyRules(ruleset)
    return RunNameRulesAllAllowed(ruleset, RUN_NAME_ECONOMY_RULES)
        and RunNameRulesAllAllowed(ruleset, RUN_NAME_TRAVEL_RULES)
        and RunNameGearAllowed(ruleset)
        and RunNameRulesAllAllowed(ruleset, RUN_NAME_BOOST_RULES)
        and RunNameRuleAllowed(ruleset and ruleset.dungeonRepeat)
        and RunNameLevelGapOff(ruleset)
        and RunNameCameraOff(ruleset)
end

local function RunNameIronmanBase(ruleset)
    return RunNameSolo(ruleset)
        and ruleset.gearQuality == "WHITE_GRAY_ONLY"
        and ruleset.selfCraftedGearAllowed ~= true
        and RunNameRulesAllRestricted(ruleset, RUN_NAME_ECONOMY_RULES)
        and RunNameRuleRestricted(ruleset.mounts)
        and RunNameRuleRestricted(ruleset.flying)
        and RunNameRulesAllRestricted(ruleset, RUN_NAME_BOOST_RULES)
        and RunNameRuleRestricted(ruleset.dungeonRepeat)
        and RunNameRuleRestricted(ruleset.instancedPvP)
end

local HIDDEN_RUN_NAMES = {
    {
        name = "Oops! All Restrictions",
        matches = function(ruleset)
            return RunNameGrouped(ruleset)
                and RunNameRulesAllRestricted(ruleset, RUN_NAME_ECONOMY_RULES)
                and RunNameRulesAllRestricted(ruleset, RUN_NAME_TRAVEL_RULES)
                and ruleset.gearQuality == "WHITE_GRAY_ONLY"
                and ruleset.selfCraftedGearAllowed ~= true
                and RunNameRulesAllRestricted(ruleset, RUN_NAME_BOOST_RULES)
                and RunNameRuleRestricted(ruleset.maxLevelGap)
                and RunNameRuleRestricted(ruleset.dungeonRepeat)
                and RunNameRuleRestricted(ruleset.instancedPvP)
                and RunNameRuleRestricted(ruleset.actionCam)
        end,
    },
    {
        name = "Iron Vigilante",
        matches = function(ruleset)
            return RunNameIronmanBase(ruleset)
                and RunNameRuleRestricted(ruleset.flightPaths)
                and RunNameRuleRestricted(ruleset.actionCam)
        end,
    },
    {
        name = "Irony Maiden",
        matches = function(ruleset)
            return RunNameIronmanBase(ruleset)
                and RunNameRuleAllowed(ruleset.flightPaths)
                and RunNameCameraOff(ruleset)
        end,
    },
    {
        name = "Gordon Ramps",
        matches = function(ruleset)
            return RunNameGrouped(ruleset)
                and ruleset.gearQuality == "WHITE_GRAY_ONLY"
                and ruleset.selfCraftedGearAllowed == true
                and RunNameRuleRestricted(ruleset.auctionHouse)
                and RunNameRuleAllowed(ruleset.mailbox)
                and RunNameRuleAllowed(ruleset.trade)
                and RunNameRuleAllowed(ruleset.bank)
                and RunNameRuleRestricted(ruleset.warbandBank)
                and RunNameRuleRestricted(ruleset.guildBank)
                and RunNameRuleAllowed(ruleset.mounts)
                and RunNameRuleRestricted(ruleset.flying)
                and RunNameRuleAllowed(ruleset.flightPaths)
                and RunNameRuleRestricted(ruleset.heirlooms)
                and RunNameRuleAllowed(ruleset.enchants)
                and RunNameRuleAllowed(ruleset.consumables)
                and RunNameRuleAllowed(ruleset.dungeonRepeat)
                and RunNameRuleRestricted(ruleset.instancedPvP)
                and RunNameRuleRestricted(ruleset.actionCam)
        end,
    },
    {
        name = "Chicken Run",
        matches = function(ruleset)
            return RunNameGrouped(ruleset)
                and RunNameCommonEasyRules(ruleset)
                and RunNameRuleAllowed(ruleset.instancedPvP)
        end,
    },
    {
        name = "Casual Friday Night Wipes",
        matches = function(ruleset)
            return RunNameGrouped(ruleset)
                and RunNameCommonEasyRules(ruleset)
                and RunNameRuleRestricted(ruleset.instancedPvP)
        end,
    },
    {
        name = "Solo Yolo",
        matches = function(ruleset)
            return RunNameSolo(ruleset)
                and RunNameCommonEasyRules(ruleset)
                and RunNameRuleAllowed(ruleset.instancedPvP)
        end,
    },
    {
        name = "Alone Ranger",
        matches = function(ruleset)
            return RunNameSolo(ruleset)
                and RunNameGearAllowed(ruleset)
                and RunNameRulesAllAllowed(ruleset, RUN_NAME_TRAVEL_RULES)
                and RunNameRulesAllAllowed(ruleset, RUN_NAME_BOOST_RULES)
        end,
    },
    {
        name = "Mind the Gap",
        matches = function(ruleset)
            return RunNameGrouped(ruleset)
                and RunNameRuleRestricted(ruleset.maxLevelGap)
                and RunNameGearAllowed(ruleset)
                and RunNameRulesAllAllowed(ruleset, RUN_NAME_TRAVEL_RULES)
        end,
    },
    {
        name = "Fifty Grades of Gray",
        matches = function(ruleset)
            return ruleset.gearQuality == "WHITE_GRAY_ONLY"
                and ruleset.selfCraftedGearAllowed ~= true
        end,
    },
    {
        name = "Made You Loot",
        matches = function(ruleset)
            return RunNameGearRestricted(ruleset)
                and ruleset.selfCraftedGearAllowed == true
        end,
    },
    {
        name = "Green With Envy",
        matches = function(ruleset)
            return ruleset.gearQuality == "GREEN_OR_LOWER"
        end,
    },
    {
        name = "Blue Yourself",
        matches = function(ruleset)
            return ruleset.gearQuality == "BLUE_OR_LOWER"
        end,
    },
    {
        name = "No Heir Today",
        matches = function(ruleset)
            return RunNameRuleRestricted(ruleset.heirlooms)
                and RunNameRuleAllowed(ruleset.enchants)
                and RunNameRuleAllowed(ruleset.consumables)
        end,
    },
    {
        name = "No Enchant Intended",
        matches = function(ruleset)
            return RunNameRuleRestricted(ruleset.enchants)
                and RunNameRuleAllowed(ruleset.heirlooms)
        end,
    },
    {
        name = "Flaskless Gordon",
        matches = function(ruleset)
            return RunNameRuleRestricted(ruleset.consumables)
                and RunNameRuleAllowed(ruleset.heirlooms)
                and RunNameRuleAllowed(ruleset.enchants)
        end,
    },
    {
        name = "Deadminesweeper",
        matches = function(ruleset)
            return RunNameRuleRestricted(ruleset.dungeonRepeat)
                and not RunNameIronmanBase(ruleset)
        end,
    },
    {
        name = "Camera Shy",
        matches = function(ruleset)
            return RunNameRuleRestricted(ruleset.actionCam)
                and RunNameRulesAllAllowed(ruleset, RUN_NAME_TRAVEL_RULES)
                and RunNameGearAllowed(ruleset)
        end,
    },
    {
        name = "Walk Hard",
        matches = function(ruleset)
            return RunNameRulesAllRestricted(ruleset, RUN_NAME_TRAVEL_RULES)
        end,
    },
    {
        name = "No Fly Zone",
        matches = function(ruleset)
            return RunNameRuleAllowed(ruleset.mounts)
                and RunNameRuleRestricted(ruleset.flying)
                and RunNameRuleAllowed(ruleset.flightPaths)
        end,
    },
    {
        name = "Flight Pathological",
        matches = function(ruleset)
            return RunNameRuleAllowed(ruleset.mounts)
                and RunNameRuleAllowed(ruleset.flying)
                and RunNameRuleRestricted(ruleset.flightPaths)
        end,
    },
    {
        name = "Mount Rushless",
        matches = function(ruleset)
            return RunNameRuleRestricted(ruleset.mounts)
                and (RunNameRuleAllowed(ruleset.flying) or RunNameRuleAllowed(ruleset.flightPaths))
        end,
    },
    {
        name = "Wallet of Warcraft",
        matches = function(ruleset)
            return RunNameRulesAllAllowed(ruleset, RUN_NAME_ECONOMY_RULES)
                and (RunNameGearRestricted(ruleset) or not RunNameRulesAllAllowed(ruleset, RUN_NAME_TRAVEL_RULES))
        end,
    },
    {
        name = "Auction House Arrest",
        matches = function(ruleset)
            return RunNameRuleRestricted(ruleset.auctionHouse)
                and RunNameRuleAllowed(ruleset.mailbox)
                and RunNameRuleAllowed(ruleset.trade)
                and RunNameRuleAllowed(ruleset.bank)
        end,
    },
    {
        name = "Bank Error in Your Favor",
        matches = function(ruleset)
            return RunNameRulesAllRestricted(ruleset, RUN_NAME_BANK_RULES)
                and (RunNameRuleAllowed(ruleset.auctionHouse) or RunNameRuleAllowed(ruleset.mailbox) or RunNameRuleAllowed(ruleset.trade))
        end,
    },
}

function SC:GetHiddenRunName(ruleset)
    if type(ruleset) ~= "table" then
        return nil
    end

    for _, spec in ipairs(HIDDEN_RUN_NAMES) do
        if spec.matches(ruleset) then
            return spec.name
        end
    end
    return nil
end

local CLASS_AWARD_LABELS = {
    DEATHKNIGHT = "Death Knight",
    DEMONHUNTER = "Demon Hunter",
}

local function FormatAwardClass(classFile)
    classFile = tostring(classFile or "")
    if classFile == "" then return "Unknown" end
    return CLASS_AWARD_LABELS[classFile] or (string.sub(classFile, 1, 1) .. string.lower(string.sub(classFile, 2)))
end

local function CountAwardViolations(violations)
    local total, active, cleared = 0, 0, 0
    for _, violation in ipairs(violations or {}) do
        total = total + 1
        if violation.status == "CLEARED" then
            cleared = cleared + 1
        else
            active = active + 1
        end
    end
    return total, active, cleared
end

local function CountAwardDungeons(run)
    local order = run and run.dungeonOrder
    if order and #order > 0 then
        return #order
    end

    local count = 0
    for _ in pairs((run and run.dungeons) or {}) do
        count = count + 1
    end
    return count
end

local function CountAwardPartyMembers(run)
    local count = 0
    for _ in pairs((run and run.participants) or {}) do
        count = count + 1
    end
    return count
end

function SC:GetCompletionAward()
    local db = EnsureDatabase()
    return db.completionAward
end

function SC:BuildCompletionAwardSnapshot(maxLevel)
    local db = EnsureDatabase()
    local run = db.run or {}
    local character = db.character or GetPlayerSnapshot()
    local totalViolations, activeViolations, clearedViolations = CountAwardViolations(db.violations)
    local preset = run.ruleset and run.ruleset.achievementPreset or "CUSTOM"
    local runName = (self.GetHiddenRunName and self:GetHiddenRunName(run.ruleset)) or run.runName or "Softcore Run"

    return {
        id = run.runId or ("SC-COMPLETION-" .. tostring(time())),
        runId = run.runId,
        runName = runName,
        characterName = character.name,
        realm = character.realm,
        class = character.class,
        classLabel = FormatAwardClass(character.class),
        startLevel = run.startLevel or character.level,
        completedLevel = maxLevel or character.level,
        startedAt = run.startTime,
        completedAt = time(),
        activeTimeSeconds = self.GetActiveRunTimeSeconds and self:GetActiveRunTimeSeconds() or run.activeTimeSeconds or 0,
        deaths = run.deathCount or 0,
        totalViolations = totalViolations,
        activeViolations = activeViolations,
        clearedViolations = clearedViolations,
        dungeonCount = CountAwardDungeons(run),
        partyMembers = CountAwardPartyMembers(run),
        rulesetHash = self.GetRulesetHash and self:GetRulesetHash() or "",
        preset = preset,
        presetLabel = PRESET_AWARD_LABELS[preset] or "Custom",
        rulesetModified = run.rulesetModified == true,
        rulesetModifiedAtLevel = run.rulesetModifiedAtLevel,
    }
end

function SC:CompleteRunAtMaxLevel(maxLevel)
    local db = EnsureDatabase()
    if not db.run or not db.run.active or db.run.completed then
        return db.completionAward
    end
    if self:IsLocalCharacterFailed() then
        return nil
    end

    if self.UpdateActiveRunTime then
        self:UpdateActiveRunTime()
    end

    local award = self:BuildCompletionAwardSnapshot(maxLevel)
    db.completionAward = award
    db.run.completed = true
    db.run.completedAt = award.completedAt
    db.run.completionAward = award

    local participant = db.run.participants and db.run.participants[GetPlayerKey(db.character)]
    if participant and participant.status ~= "FAILED" and participant.status ~= "RETIRED" then
        participant.status = "COMPLETED"
    end

    self:AddLog("RUN_COMPLETED", "Reached max level. Softcore run completed.", {
        runId = db.run.runId,
        completedLevel = award.completedLevel,
    })

    db.run.active = false
    db.run.activeTimeUpdatedAt = nil
    db.run.partyStatus = "COMPLETED"

    Print("max level reached. Run completed.")
    self:PlayUISound("RUN_COMPLETED")

    if self.Sync_BroadcastStatus then
        self:Sync_BroadcastStatus("RUN_COMPLETED", { fast = true })
    end
    if self.HUD_Refresh then
        self:HUD_Refresh()
    end
    if self.MasterUI_Refresh then
        self:MasterUI_Refresh()
    end
    if self.ShowCompletionAward then
        self:ShowCompletionAward(award)
    end

    return award
end

local function ArchiveCurrentRun(db, reason)
    if not HasRunData(db.run, db.eventLog, db.violations) then
        return
    end

    if SC.UpdateActiveRunTime then
        SC:UpdateActiveRunTime()
    end

    table.insert(db.runHistory, {
        archivedAt = time(),
        reason = reason or "Archived",
        runId = db.run.runId,
        runName = db.run.runName,
        run = CopyTable(db.run),
        eventLog = CopyTable(db.eventLog),
        violations = CopyTable(db.violations),
    })
end

function SC:RefreshCharacter()
    local db = EnsureDatabase()
    db.character = GetPlayerSnapshot()
    return db.character
end

function SC:ResumeActiveRunTimer()
    local db = EnsureDatabase()
    if db.run and db.run.active then
        db.run.activeTimeSeconds = tonumber(db.run.activeTimeSeconds or 0) or 0
        db.run.activeTimeUpdatedAt = time()
    end
end

function SC:UpdateActiveRunTime()
    local db = EnsureDatabase()
    local run = db.run
    if not run or not run.active then
        return tonumber(run and run.activeTimeSeconds or 0) or 0
    end

    local now = time()
    local last = tonumber(run.activeTimeUpdatedAt)
    run.activeTimeSeconds = tonumber(run.activeTimeSeconds or 0) or 0
    if last and now >= last then
        run.activeTimeSeconds = run.activeTimeSeconds + (now - last)
    end
    run.activeTimeUpdatedAt = now
    return run.activeTimeSeconds
end

function SC:GetActiveRunTimeSeconds()
    local db = EnsureDatabase()
    local run = db.run
    if not run then return 0 end

    local seconds = tonumber(run.activeTimeSeconds or 0) or 0
    if run.active then
        local last = tonumber(run.activeTimeUpdatedAt)
        local now = time()
        if last and now >= last then
            seconds = seconds + (now - last)
        end
    end
    return seconds
end

function SC:FormatDuration(seconds)
    return FormatDuration(seconds)
end

function SC:GetPlayerKey()
    return GetPlayerKey(GetPlayerSnapshot())
end

function SC:FormatPlayerLabel(playerKey)
    return FormatPlayerLabel(playerKey)
end

function SC:CreateRunId()
    return CreateStableId("run")
end

function SC:CreateProposalId()
    return CreateStableId("proposal")
end

local function IsRuleTrackedInRunRuleset(ruleset, ruleKey)
    if not ruleset or not ruleKey then
        return false
    end
    local v = ruleset[ruleKey]
    return v ~= nil and v ~= "ALLOWED" and v ~= false
end

local function GetForcedMovementLogReason(entry)
    local r = entry and entry.reason
    if r == "taxi" or r == "vehicle" or r == "override" then
        return r
    end
    local msg = tostring(entry and entry.message or "")
    if string.find(msg, "taxi or forced", 1, true) then
        return "taxi"
    end
    if string.find(msg, "override action bar", 1, true) then
        return "override"
    end
    if string.find(msg, "Vehicle or forced movement active:", 1, true) then
        return "vehicle"
    end
    return nil
end

--- Whether a stored log entry should appear in the master menu Log tab and /sc log chat output.
--- Full history remains in SavedVariables and CSV/debug exports.
function SC:ShouldDisplayLogEntryInUI(entry)
    local kind = tostring(entry and entry.kind or "")
    local db = EnsureDatabase()
    local ruleset = db.run and db.run.ruleset

    if kind == "PET_BATTLE_STARTED" or kind == "PET_BATTLE_ENDED" then
        return false
    end

    if kind == "FORCED_MOVEMENT" or kind == "FORCED_MOVEMENT_ENDED" then
        local reason = GetForcedMovementLogReason(entry)
        if reason == "taxi" then
            return IsRuleTrackedInRunRuleset(ruleset, "flightPaths")
        end
        if reason == "vehicle" or reason == "override" then
            return IsRuleTrackedInRunRuleset(ruleset, "mounts")
                or IsRuleTrackedInRunRuleset(ruleset, "flying")
        end
        return IsRuleTrackedInRunRuleset(ruleset, "flightPaths")
            or IsRuleTrackedInRunRuleset(ruleset, "mounts")
            or IsRuleTrackedInRunRuleset(ruleset, "flying")
    end

    if kind == "LEVEL_GAP_EXCEEDED" then
        return IsRuleTrackedInRunRuleset(ruleset, "maxLevelGap")
    end

    if kind == "INSTANCE_ENTERED" then
        return IsRuleTrackedInRunRuleset(ruleset, "dungeonRepeat")
            or IsRuleTrackedInRunRuleset(ruleset, "instanceWithUnsyncedPlayers")
    end

    return true
end

function SC:AddLog(kind, message, extra)
    local db = EnsureDatabase()
    local logEntryId = CreateStableId("log")
    local suppressAuditSync = extra and extra.suppressAuditSync
    local entry = {
        id = logEntryId,
        logEntryId = logEntryId,
        runId = db.run.runId,
        time = time(),
        kind = kind,
        message = message,
        playerKey = GetPlayerKey(db.character),
        actorKey = GetPlayerKey(db.character),
    }

    if extra then
        for key, value in pairs(extra) do
            if key ~= "suppressAuditSync" then
                entry[key] = value
            end
        end
    end

    table.insert(db.eventLog, entry)
    db.sync.seenAuditIds[entry.id] = true

    if self.TraceDebug then
        self:TraceDebug("AUDIT_LOG", {
            logEntryId = entry.id,
            runId = entry.runId,
            eventKind = entry.kind,
            playerKey = entry.playerKey,
            actorKey = entry.actorKey,
            message = entry.message,
        })
    end

    if self.HUD_Refresh then
        self:HUD_Refresh()
    end

    if self.MasterUI_Refresh then
        self:MasterUI_Refresh()
    end

    if self.Sync_BroadcastLog and not suppressAuditSync and not string.match(tostring(kind or ""), "^SYNC_") then
        self:Sync_BroadcastLog(entry)
    end

    return entry
end

function SC:LogEvent(kind, message)
    return self:AddLog(kind, message)
end

local function BuildViolationAddedMessage(violation)
    local violationType = tostring(violation and violation.type or "unknown")
    local detail = violation and violation.detail

    if detail and detail ~= "" then
        return "Violation added: " .. violationType .. " - " .. tostring(detail)
    end

    return "Violation added: " .. violationType
end

function SC:AddViolation(violationType, detail, severity, playerKey)
    local db = EnsureDatabase()
    local now = time()
    local violationId = CreateStableId("violation")
    local violation = {
        id = violationId,
        violationId = violationId,
        runId = db.run.runId,
        playerKey = playerKey or GetPlayerKey(db.character),
        type = violationType,
        detail = detail,
        severity = severity or "WARNING",
        status = "ACTIVE",
        createdAt = now,
        clearedAt = nil,
        clearedBy = nil,
        clearReason = nil,
    }

    table.insert(db.violations, violation)
    db.sync.seenViolationIds[violation.id] = true
    if self.TraceDebug then
        self:TraceDebug("VIOLATION_LOCAL_ADDED", {
            violationId = violation.id,
            runId = violation.runId,
            playerKey = violation.playerKey,
            violationType = violation.type,
            severity = violation.severity,
            detail = violation.detail,
        })
    end
    self:AddLog("VIOLATION_ADDED", BuildViolationAddedMessage(violation), {
        violationId = violation.id,
        violationType = violation.type,
        violationDetail = violation.detail,
        violationPlayerKey = violation.playerKey,
        severity = violation.severity,
        playerKey = violation.playerKey,
        actorKey = violation.playerKey,
        suppressAuditSync = true,
    })

    if self.Achievements_OnViolationAdded then
        self:Achievements_OnViolationAdded(violation)
    end

    if self.Sync_BroadcastViolation then
        self:Sync_BroadcastViolation(violation)
    end

    local sev = violation.severity
    if sev == "FATAL" or sev == "CHARACTER_FAIL" then
        self:PlayUISound("DEATH")
    else
        self:PlayUISound("VIOLATION")
    end

    if self.MasterUI_Refresh then
        self:MasterUI_Refresh()
    end

    return violation
end

function SC:GetActiveViolationSnapshot(playerKey)
    local db = EnsureDatabase()
    local count = 0
    local latest = nil

    for _, violation in ipairs(db.violations or {}) do
        if violation.status ~= "CLEARED" and (not playerKey or violation.playerKey == playerKey) then
            count = count + 1
            if not latest or (violation.createdAt or 0) > (latest.createdAt or 0) then
                latest = violation
            end
        end
    end

    return {
        count = count,
        latest = latest,
    }
end

function SC:GetOrCreateParticipant(playerKey)
    local db = EnsureDatabase()
    local key = playerKey or GetPlayerKey(db.character)
    local participant = db.run.participants[key]

    if not participant then
        local name, realm = SplitPlayerKey(key)
        participant = {
            playerKey = key,
            name = name,
            realm = realm,
            class = nil,
            levelAtJoin = 0,
            currentLevel = 0,
            status = "PENDING",
            joinedAt = nil,
            leftAt = nil,
            failedAt = nil,
            failReason = nil,
        }

        if key == GetPlayerKey(db.character) then
            participant.name = db.character.name
            participant.realm = db.character.realm
            participant.class = db.character.class
            participant.levelAtJoin = db.character.level
            participant.currentLevel = db.character.level
        end

        db.run.participants[key] = participant
        table.insert(db.run.participantOrder, key)
    end

    return participant
end

function SC:AddParticipant(playerKey)
    local db = EnsureDatabase()
    if db.run.participants[playerKey] then
        return db.run.participants[playerKey], false
    end

    local participant = self:GetOrCreateParticipant(playerKey)

    if participant.status ~= "FAILED" and participant.status ~= "RETIRED" then
        participant.status = "PENDING"
        participant.joinedAt = participant.joinedAt or time()
        participant.leftAt = nil
        self:AddLog("PARTICIPANT_ADDED", "Participant added: " .. participant.playerKey, {
            playerKey = participant.playerKey,
        })
    end

    return participant, true
end

function SC:IsParticipantInCurrentParty(playerKey)
    return GetCurrentPartyKeys()[playerKey] == true
end

-- Individual-state boundary:
-- The local character's participant row is authoritative only for this client.
-- Remote sync rows are advisory/display-only and feed derived party status.
function SC:GetLocalPlayerStatus()
    local db = EnsureDatabase()
    self:RefreshCharacter()

    local playerKey = GetPlayerKey(db.character)
    local participant = db.run.participants[playerKey]

    local levelAtJoin = 0
    if db.run.active then
        participant = self:GetOrCreateParticipant(playerKey)
        participant.currentLevel = db.character.level
        participant.class = db.character.class
        levelAtJoin = tonumber(participant.levelAtJoin) or 0
        if levelAtJoin <= 0 then
            levelAtJoin = tonumber(db.run.startLevel) or 0
        end
    end

    return {
        runId = db.run.runId,
        runName = (self.GetHiddenRunName and self:GetHiddenRunName(db.run.ruleset)) or db.run.runName,
        playerKey = playerKey,
        name = db.character.name,
        realm = db.character.realm,
        class = db.character.class,
        level = db.character.level,
        levelAtJoin = levelAtJoin,
        zone = db.character.zone,
        active = db.run.active,
        valid = db.run.valid,
        completed = db.run.completed == true,
        failed = participant and participant.status == "FAILED",
        participantStatus = participant and participant.status or "NOT_IN_RUN",
        rulesetVersion = db.run.ruleset.version,
        rulesetHash = self.GetRulesetHash and self:GetRulesetHash() or "",
        deaths = db.run.deathCount,
        warnings = db.run.warningCount,
        version = self.version,
        timestamp = time(),
    }
end

function SC:GetRemotePeerStatus(playerKey)
    if not playerKey or not self.groupStatuses then
        return nil
    end

    return self.groupStatuses[playerKey]
end

function SC:IsLocalCharacterFailed()
    local db = EnsureDatabase()
    local playerKey = GetPlayerKey(db.character)
    local participant = db.run.participants and db.run.participants[playerKey]

    return db.run.failed == true
        or db.run.valid == false
        or (participant and participant.status == "FAILED")
end

function SC:CanRecordLocalRunEvent()
    local db = EnsureDatabase()
    return db.run.active == true and not self:IsLocalCharacterFailed()
end

function SC:IsRemoteStateCompatible(peer)
    local db = EnsureDatabase()

    if not peer or peer.unsynced then
        return false, "UNSYNCED"
    end

    if peer.participantStatus == "PENDING" or peer.participantStatus == "UNSYNCED" or peer.participantStatus == "NOT_IN_RUN" then
        return false, peer.participantStatus
    end

    if not peer.active then
        return false, "NOT_IN_RUN"
    end

    if db.run.runId and peer.runId and db.run.runId ~= peer.runId then
        return false, "RUN_MISMATCH"
    end

    local localHash = self.GetRulesetHash and self:GetRulesetHash() or ""
    if localHash ~= "" and peer.rulesetHash and peer.rulesetHash ~= "" and localHash ~= peer.rulesetHash then
        return false, "RULESET_MISMATCH"
    end

    if peer.addonVersion and peer.addonVersion ~= self.version then
        return false, "ADDON_VERSION_MISMATCH"
    end

    return true, nil
end

function SC:ShouldApplyGroupViolationLocally(reason)
    local db = EnsureDatabase()
    local ruleset = db.run.ruleset or {}
    local ruleName = reason == "SOLO_SELF_FOUND" and "outsiderGrouping" or "unsyncedMembers"
    local outcome = ruleset[ruleName]

    if reason == "SOLO_SELF_FOUND" then
        return outcome ~= nil and outcome ~= "ALLOWED", ruleName
    end

    if reason == "UNSYNCED" or reason == "RULESET_MISMATCH" or reason == "RUN_MISMATCH" or reason == "ADDON_VERSION_MISMATCH" then
        return outcome ~= nil and outcome ~= "ALLOWED", ruleName
    end

    return false, ruleName
end

function SC:MarkParticipantFailed(playerKey, reason)
    local db = EnsureDatabase()
    local participant = self:GetOrCreateParticipant(playerKey)

    if participant.status ~= "FAILED" then
        participant.status = "FAILED"
        participant.failedAt = time()
        participant.failReason = reason or "Failed"
        self:AddLog("PARTICIPANT_FAILED", participant.playerKey .. " failed: " .. participant.failReason, {
            playerKey = participant.playerKey,
        })
        if self.Achievements_OnParticipantFailed then
            self:Achievements_OnParticipantFailed(playerKey)
        end
    end

    if playerKey == GetPlayerKey(db.character) then
        db.run.failed = true
        db.run.valid = false
    end

    return participant
end

function SC:MarkParticipantLeft(playerKey)
    local participant = self:GetOrCreateParticipant(playerKey)

    if participant.status ~= "FAILED" and participant.status ~= "RETIRED" and participant.status ~= "OUT_OF_PARTY" then
        participant.status = "OUT_OF_PARTY"
        participant.leftAt = time()
        self:AddLog("PARTICIPANT_OUT_OF_PARTY", participant.playerKey .. " left the party.", {
            playerKey = participant.playerKey,
        })
    end

    return participant
end

function SC:CanAutoDiscoverParticipant(playerKey, remoteStatus)
    local db = EnsureDatabase()
    if not db.run.active or not playerKey or not remoteStatus then
        return false
    end

    local ruleset = db.run.ruleset or {}
    if not ruleset.allowLateJoin or ruleset.requireLeaderApprovalForJoin then
        return false
    end

    local localHash = self.GetRulesetHash and self:GetRulesetHash() or ""
    if remoteStatus.runId ~= db.run.runId then
        return false
    end
    if not remoteStatus.rulesetHash or remoteStatus.rulesetHash ~= localHash then
        return false
    end
    if remoteStatus.participantStatus == "FAILED"
        or remoteStatus.participantStatus == "RUN_MISMATCH"
        or remoteStatus.participantStatus == "RULESET_MISMATCH"
        or remoteStatus.participantStatus == "ADDON_VERSION_MISMATCH"
        or remoteStatus.participantStatus == "NOT_IN_RUN" then
        return false
    end

    return true
end

function SC:RefreshParticipantsFromRoster()
    local db = EnsureDatabase()
    local partyKeys = GetCurrentPartyKeys()
    local localPlayerKey = GetPlayerKey(db.character)
    local ruleset = db.run.ruleset or {}
    local groupingMode = ruleset.groupingMode or "SYNCED_GROUP_ALLOWED"

    if not db.run.active then
        return
    end

    for playerKey, participant in pairs(db.run.participants or {}) do
        if participant.status ~= "FAILED" and participant.status ~= "RETIRED" then
            if partyKeys[playerKey] then
                if participant.status == "OUT_OF_PARTY" or participant.status == "UNSYNCED" then
                    if groupingMode == "SOLO_SELF_FOUND" and playerKey ~= localPlayerKey then
                        participant.status = "NOT_IN_RUN"
                    else
                        participant.status = "ACTIVE"
                    end
                    participant.leftAt = nil
                    participant.joinedAt = participant.joinedAt or time()
                end
            elseif playerKey ~= localPlayerKey and (participant.status == "ACTIVE" or participant.status == "WARNING" or participant.status == "UNSYNCED" or participant.status == "PENDING") then
                self:MarkParticipantLeft(playerKey)
            end
        end
    end

    for playerKey in pairs(partyKeys) do
        if playerKey ~= localPlayerKey and not db.run.participants[playerKey] then
            if groupingMode == "SOLO_SELF_FOUND" then
                local shouldApply, ruleName = self:ShouldApplyGroupViolationLocally("SOLO_SELF_FOUND")
                if shouldApply and not ShouldThrottleRunNotice(db.run, "outsiderGroupingNotices", playerKey, 60) and self.ApplyRuleOutcome then
                    self:ApplyRuleOutcome(ruleName, {
                        playerKey = localPlayerKey,
                        detail = "Grouped with outside character during solo/self-found run: " .. playerKey,
                    })
                end
            elseif ruleset.allowLateJoin then
                local remoteStatus = self.groupStatuses and self.groupStatuses[playerKey]
                if self:CanAutoDiscoverParticipant(playerKey, remoteStatus) then
                    local participant = self:GetOrCreateParticipant(playerKey)
                    participant.status = "ACTIVE"
                    participant.joinedAt = participant.joinedAt or time()
                    self:AddLog("PARTICIPANT_DISCOVERED", "Synced party member joined the run: " .. playerKey, {
                        playerKey = playerKey,
                    })
                end
            end
        end
    end
end

function SC:GetPartyStatus()
    return self:GetDerivedPartyStatus()
end

function SC:GetDerivedPartyStatus()
    local db = EnsureDatabase()

    if not db.run.active then
        db.run.partyStatus = "INACTIVE"
        return db.run.partyStatus
    end

    if IsInRaid() then
        db.run.levelGapBlocked = false
        db.run.partyStatus = "RAID_UNSUPPORTED"
        return db.run.partyStatus
    end

    if db.run.levelGapBlocked then
        db.run.partyStatus = "BLOCKED"
        return db.run.partyStatus
    end

    local hasWarning = false
    local hasUnsynced = false
    local hasConflict = false
    local localStatus = self:GetLocalPlayerStatus()

    if localStatus.participantStatus == "FAILED" and db.run.ruleset.failedMemberBlocksParty then
        db.run.partyStatus = "BLOCKED"
        return db.run.partyStatus
    elseif localStatus.participantStatus == "WARNING" then
        hasWarning = true
    elseif localStatus.participantStatus == "PENDING" or localStatus.participantStatus == "UNSYNCED" then
        hasUnsynced = true
    end

    for playerKey, participant in pairs(db.run.participants or {}) do
        if playerKey ~= localStatus.playerKey and self:IsParticipantInCurrentParty(playerKey) then
            if participant.status == "FAILED" and db.run.ruleset.failedMemberBlocksParty then
                db.run.partyStatus = "BLOCKED"
                return db.run.partyStatus
            elseif participant.status == "RUN_MISMATCH" or participant.status == "RULESET_MISMATCH" or participant.status == "ADDON_VERSION_MISMATCH" then
                hasConflict = true
            elseif participant.status == "WARNING" then
                hasWarning = true
            elseif participant.status == "PENDING" or participant.status == "UNSYNCED" or participant.status == "NOT_IN_RUN" then
                db.run.partyStatus = "BLOCKED"
                return db.run.partyStatus
            end
        end
    end

    -- Remote peer statuses are advisory. They can make the party display BLOCKED,
    -- VIOLATION, UNSYNCED, or CONFLICT, but they never mutate local run validity.
    if self.Sync_GetGroupRows then
        for _, peer in ipairs(self:Sync_GetGroupRows()) do
            local compatible, reason = self:IsRemoteStateCompatible(peer)
            if not compatible then
                if reason == "RUN_MISMATCH" or reason == "RULESET_MISMATCH" or reason == "ADDON_VERSION_MISMATCH" then
                    hasConflict = true
                else
                    db.run.partyStatus = "BLOCKED"
                    return db.run.partyStatus
                end
            elseif peer.participantStatus == "FAILED" or peer.failed then
                if db.run.ruleset.failedMemberBlocksParty then
                    db.run.partyStatus = "BLOCKED"
                    return db.run.partyStatus
                end
            elseif peer.participantStatus == "WARNING" then
                hasWarning = true
            elseif (tonumber(peer.activeViolations) or 0) > 0 then
                hasWarning = true
            elseif peer.participantStatus == "PENDING" or peer.participantStatus == "UNSYNCED" or peer.participantStatus == "NOT_IN_RUN" then
                db.run.partyStatus = "BLOCKED"
                return db.run.partyStatus
            end
        end
    end

    for _, conflict in pairs(db.run.conflicts) do
        if conflict.active and self:IsParticipantInCurrentParty(conflict.playerKey) then
            hasConflict = true
        end
    end

    if hasConflict then
        db.run.partyStatus = "CONFLICT"
    elseif hasWarning then
        db.run.partyStatus = "VIOLATION"
    elseif hasUnsynced then
        db.run.partyStatus = "UNSYNCED"
    else
        db.run.partyStatus = "VALID"
    end

    return db.run.partyStatus
end

function SC:CanPartyContinue()
    return self:GetPartyStatus() ~= "BLOCKED"
end

local function BuildViolationClearMessage(violation)
    local violationType = tostring(violation and violation.type or "unknown")
    local detail = violation and violation.detail
    local playerLabel = FormatPlayerLabel(violation and violation.playerKey)

    if detail and detail ~= "" then
        return "Cleared " .. playerLabel .. "'s violation: " .. violationType .. " - " .. tostring(detail)
    end

    return "Cleared " .. playerLabel .. "'s violation: " .. violationType
end

function SC:ClearViolation(violationId, clearedBy, clearReason)
    local db = EnsureDatabase()

    for _, violation in ipairs(db.violations) do
        if violation.id == violationId then
            if violation.status ~= "CLEARED" then
                violation.status = "CLEARED"
                violation.clearedAt = time()
                violation.clearedBy = clearedBy or GetPlayerKey(db.character)
                violation.clearReason = clearReason or "Cleared"
                if self.TraceDebug then
                    self:TraceDebug("VIOLATION_CLEARED", {
                        violationId = violation.id,
                        runId = violation.runId,
                        playerKey = violation.playerKey,
                        violationType = violation.type,
                        shared = violation.shared == true,
                        clearedBy = violation.clearedBy,
                        clearReason = violation.clearReason,
                    })
                end
                self:AddLog("VIOLATION_CLEARED", BuildViolationClearMessage(violation), {
                    violationId = violation.id,
                    violationType = violation.type,
                    violationDetail = violation.detail,
                    violationPlayerKey = violation.playerKey,
                    severity = violation.severity,
                    playerKey = violation.clearedBy,
                    actorKey = violation.clearedBy,
                    clearedBy = violation.clearedBy,
                    clearReason = violation.clearReason,
                    suppressAuditSync = true,
                })
                if self.Sync_BroadcastViolationClear then
                    self:Sync_BroadcastViolationClear(violation)
                end
                self:PlayUISound("VIOLATION_CLEARED")
                if self.MasterUI_Refresh then
                    self:MasterUI_Refresh()
                end

                local ownerKey = violation.playerKey
                local ownerParticipant = ownerKey and db.run.participants and db.run.participants[ownerKey]
                if ownerParticipant and ownerParticipant.status == "WARNING" then
                    local hasActiveViolation = false
                    for _, v in ipairs(db.violations) do
                        if v.playerKey == ownerKey and v.status ~= "CLEARED" and v.severity ~= "FATAL" then
                            hasActiveViolation = true
                            break
                        end
                    end
                    if not hasActiveViolation then
                        ownerParticipant.status = "ACTIVE"
                    end
                end
            end

            return violation
        end
    end

    return nil
end

function SC:ImportSharedLog(entry)
    if type(entry) ~= "table" or not entry.id then
        return nil
    end

    local db = EnsureDatabase()
    if db.sync.seenAuditIds[entry.id] then
        return nil
    end

    db.sync.seenAuditIds[entry.id] = true
    table.insert(db.eventLog, entry)

    if self.TraceDebug then
        self:TraceDebug("AUDIT_LOG_IMPORTED", {
            logEntryId = entry.id,
            runId = entry.runId,
            eventKind = entry.kind,
            playerKey = entry.playerKey,
            actorKey = entry.actorKey,
            violationId = entry.violationId,
            message = entry.message,
        })
    end

    if self.MasterUI_Refresh then
        self:MasterUI_Refresh()
    end

    return entry
end

function SC:ImportSharedViolation(violation)
    if type(violation) ~= "table" or not violation.id then
        return nil
    end

    local db = EnsureDatabase()
    if db.sync.seenViolationIds[violation.id] then
        return nil
    end

    db.sync.seenViolationIds[violation.id] = true
    table.insert(db.violations, violation)

    if self.TraceDebug then
        self:TraceDebug("VIOLATION_SHARED_IMPORTED", {
            violationId = violation.id,
            runId = violation.runId,
            playerKey = violation.playerKey,
            violationType = violation.type,
            severity = violation.severity,
            status = violation.status,
            detail = violation.detail,
        })
    end

    self:ImportSharedLog({
        id = violation.logEntryId or (violation.id .. ":added"),
        logEntryId = violation.logEntryId or (violation.id .. ":added"),
        runId = violation.runId,
        time = violation.createdAt,
        kind = "VIOLATION_ADDED",
        message = BuildViolationAddedMessage(violation),
        playerKey = violation.playerKey,
        actorKey = violation.playerKey,
        violationId = violation.id,
        violationType = violation.type,
        violationDetail = violation.detail,
        violationPlayerKey = violation.playerKey,
        severity = violation.severity,
        shared = true,
    })

    if self.MasterUI_Refresh then
        self:MasterUI_Refresh()
    end

    return violation
end

function SC:ImportSharedViolationClear(violationId, clearedBy, clearedAt, clearReason, ownerKey)
    local db = EnsureDatabase()

    for _, violation in ipairs(db.violations) do
        if violation.id == violationId then
            if not violation.shared then
                return nil
            end
            if ownerKey and violation.playerKey ~= ownerKey then
                return nil
            end

            if violation.status ~= "CLEARED" then
                violation.status = "CLEARED"
                violation.clearedBy = clearedBy
                violation.clearedAt = clearedAt or time()
                violation.clearReason = clearReason or "Cleared"
                if self.TraceDebug then
                    self:TraceDebug("VIOLATION_SHARED_CLEARED", {
                        violationId = violation.id,
                        runId = violation.runId,
                        playerKey = violation.playerKey,
                        violationType = violation.type,
                        clearedBy = violation.clearedBy,
                        clearReason = violation.clearReason,
                    })
                end

                self:ImportSharedLog({
                    id = violation.id .. ":cleared:" .. tostring(violation.clearedAt),
                    logEntryId = violation.id .. ":cleared:" .. tostring(violation.clearedAt),
                    runId = violation.runId,
                    time = violation.clearedAt,
                    kind = "VIOLATION_CLEARED",
                    message = BuildViolationClearMessage(violation),
                    playerKey = violation.clearedBy,
                    actorKey = violation.clearedBy,
                    violationId = violation.id,
                    violationType = violation.type,
                    violationDetail = violation.detail,
                    violationPlayerKey = violation.playerKey,
                    severity = violation.severity,
                    clearedBy = violation.clearedBy,
                    clearReason = violation.clearReason,
                    shared = true,
                })
            end

            return violation
        end
    end

    return nil
end

function SC:ImportSharedViolationSnapshot(snapshot)
    if type(snapshot) ~= "table" or not snapshot.id or snapshot.id == "" then
        return nil
    end

    local db = EnsureDatabase()
    if not db.run or not db.run.active or not db.run.runId or snapshot.runId ~= db.run.runId then
        return nil
    end

    local existing
    for _, violation in ipairs(db.violations) do
        if violation.id == snapshot.id then
            existing = violation
            break
        end
    end

    if existing then
        if existing.shared then
            local wasCleared = existing.status == "CLEARED"
            if wasCleared then
                if self.TraceDebug then
                    self:TraceDebug("VIOLATION_SHARED_SNAPSHOT_IGNORED_CLEARED", {
                        violationId = existing.id,
                        runId = existing.runId,
                        playerKey = existing.playerKey,
                        violationType = existing.type,
                    })
                end
                return existing
            end

            existing.status = "ACTIVE"
            existing.clearedAt = nil
            existing.clearedBy = nil
            existing.clearReason = nil
            existing.type = snapshot.type or existing.type
            existing.detail = snapshot.detail or existing.detail
            existing.severity = snapshot.severity or existing.severity or "WARNING"
            existing.playerKey = snapshot.playerKey or existing.playerKey
            existing.runId = snapshot.runId or existing.runId
            existing.createdAt = snapshot.createdAt or existing.createdAt or time()

        end

        return existing
    end

    local violation = {
        id = snapshot.id,
        violationId = snapshot.id,
        runId = snapshot.runId,
        playerKey = snapshot.playerKey,
        type = snapshot.type or "unknown",
        detail = snapshot.detail,
        severity = snapshot.severity or "WARNING",
        status = "ACTIVE",
        createdAt = snapshot.createdAt or time(),
        clearedAt = nil,
        clearedBy = nil,
        clearReason = nil,
        shared = true,
        snapshotOnly = true,
    }

    db.sync.seenViolationIds[violation.id] = true
    table.insert(db.violations, violation)

    if self.TraceDebug then
        self:TraceDebug("VIOLATION_SHARED_SNAPSHOT", {
            violationId = violation.id,
            runId = violation.runId,
            playerKey = violation.playerKey,
            violationType = violation.type,
            detail = violation.detail,
        })
    end

    if self.MasterUI_Refresh then
        self:MasterUI_Refresh()
    end

    return violation
end

-- Violation types that represent party compatibility blockers, not clearable run events.
local BLOCKER_VIOLATION_TYPES = {
    unsyncedMembers = true,
    maxLevelGap = true,
    instanceWithUnsyncedPlayers = true,
    outsiderGrouping = true,
}

function SC:IsViolationClearable(violation)
    if not violation or violation.status == "CLEARED" then return false end
    if violation.shared and violation.playerKey ~= self:GetPlayerKey() then return false end
    if violation.type == "death" then return false end
    if violation.severity == "FATAL" or violation.severity == "CHARACTER_FAIL" then return false end
    if BLOCKER_VIOLATION_TYPES[violation.type] then return false end
    return true
end

function SC:GetActiveViolations()
    local db = self.db or SoftcoreDB
    local result = {}
    for _, v in ipairs((db and db.violations) or {}) do
        if v.status ~= "CLEARED" then
            table.insert(result, v)
        end
    end
    return result
end

function SC:GetClearedViolations()
    local db = self.db or SoftcoreDB
    local result = {}
    for _, v in ipairs((db and db.violations) or {}) do
        if v.status == "CLEARED" then
            table.insert(result, v)
        end
    end
    return result
end

function SC:GetPlayerStatus()
    local status = self:GetLocalPlayerStatus()
    status.partyStatus = self:GetDerivedPartyStatus()
    return status
end

function SC:StartRun(runOptions)
    local db = EnsureDatabase()
    local existingParticipant = db.run.participants[GetPlayerKey(db.character)]
    runOptions = runOptions or {}

    if db.run.active then
        if existingParticipant and existingParticipant.status == "FAILED" then
            Print("this character failed the active run and must not continue.")
            self:PrintStatus()
            return false
        end

        if existingParticipant and existingParticipant.status == "RETIRED" then
            Print("this character is retired from the active run and was not reactivated.")
            self:PrintStatus()
            return false
        end

        Print("run is already active.")
        self:PrintStatus()
        return false
    end

    local startingRuleset = runOptions.ruleset and CopyTable(runOptions.ruleset) or CopyTable(db.run.ruleset or CreateDefaultRuleset())
    if self.NormalizeRulesetForSync then
        startingRuleset = self:NormalizeRulesetForSync(startingRuleset)
    end

    local preservedProposals = {}
    if runOptions.runId then
        for proposalId, proposal in pairs(db.proposals or {}) do
            if proposal and proposal.runId == runOptions.runId and (proposal.status == "PENDING" or proposal.status == "ACCEPTED" or proposal.status == "CONFIRMED") then
                proposal.status = "CONFIRMED"
                proposal.confirmedAt = proposal.confirmedAt or time()
                preservedProposals[proposalId] = proposal
            end
        end
    end

    ArchiveCurrentRun(db, "Starting new run")

    db.character = GetPlayerSnapshot()
    db.run.runId = runOptions.runId or self:CreateRunId()
    db.run.runName = runOptions.runName or "Softcore Run"
    db.run.active = true
    db.run.valid = true
    db.run.failed = false
    db.run.completed = false
    db.run.completedAt = nil
    db.run.startTime = time()
    db.run.activeTimeSeconds = 0
    db.run.activeTimeUpdatedAt = db.run.startTime
    db.run.startLevel = db.character.level
    db.run.deathCount = 0
    db.run.warningCount = 0
    db.run.rulesetModified = false
    db.run.rulesetModifiedAtLevel = nil
    db.run.ruleset = startingRuleset
    db.run.ruleset.achievementPreset = runOptions.preset or db.run.ruleset.achievementPreset or "CUSTOM"
    ApplyGroupingModeRules(db.run.ruleset)
    if (not runOptions.runName or runOptions.runName == "Softcore Run") and self.GetHiddenRunName then
        db.run.runName = self:GetHiddenRunName(db.run.ruleset) or db.run.runName
    end
    db.run.cameraMode = runOptions.cameraMode or DefaultCameraModeForRules(db.run.ruleset)
    db.run.governance = CreateDefaultGovernance()
    db.run.participants = {}
    db.run.participantOrder = {}
    db.run.partyStatus = "VALID"
    db.run.conflicts = {}
    db.run.dungeons = {}
    db.run.dungeonOrder = {}
    db.run.levelGapBlocked = false
    db.eventLog = {}
    db.violations = {}
    db.proposals = preservedProposals
    db.pendingProposalId = nil
    db.acceptedRunId = nil
    db.acceptedRulesetHash = nil
    db.ruleAmendments = {}
    local participant = self:GetOrCreateParticipant(GetPlayerKey(db.character))
    participant.status = "ACTIVE"
    participant.joinedAt = db.run.startTime
    participant.levelAtJoin = db.character.level
    participant.currentLevel = db.character.level
    participant.class = db.character.class

    self:AddLog("RUN_START", "Run started for " .. db.character.name .. "-" .. db.character.realm .. " at level " .. tostring(db.character.level or "?") .. ".")
    if self.Achievements_OnRunStart then
        self:Achievements_OnRunStart(runOptions)
    end
    if self.ResetGearScanTracking then
        self:ResetGearScanTracking()
    end
    if self.ResetEventTracking then
        self:ResetEventTracking()
    end
    if self.ScanEquippedGear then
        self:ScanEquippedGear(true)
    end
    if self.CheckMovementRules then
        self:CheckMovementRules()
    end
    if self.EnforceActionCamSettings then
        self:EnforceActionCamSettings()
    end
    self:RefreshParticipantsFromRoster()
    self:PlayUISound("RUN_STARTED")
    Print("run started.")

    if self.Sync_BroadcastStatus then
        self:Sync_BroadcastStatus("RUN_START", { fast = true })
    end

    SoftcoreDB = SoftcoreDB or {}
    SoftcoreDB.ui = SoftcoreDB.ui or {}
    SoftcoreDB.ui.hudHidden = false

    if self.HUD_Refresh then
        self:HUD_Refresh()
    end

    return true
end

function SC:ResetRun()
    local db = EnsureDatabase()
    if not HasRunData(db.run, db.eventLog, db.violations) then
        Print("no run data to reset.")
        return false
    end

    ArchiveCurrentRun(db, "Reset confirmed")

    db.character = GetPlayerSnapshot()
    db.run.runId = nil
    db.run.runName = nil
    db.run.active = false
    db.run.valid = true
    db.run.failed = false
    db.run.completed = false
    db.run.completedAt = nil
    db.run.startTime = nil
    db.run.activeTimeSeconds = 0
    db.run.activeTimeUpdatedAt = nil
    db.run.deathCount = 0
    db.run.warningCount = 0
    db.run.ruleset = CreateDefaultRuleset()
    db.run.cameraMode = nil
    db.run.governance = CreateDefaultGovernance()
    db.run.participants = {}
    db.run.participantOrder = {}
    db.run.partyStatus = "INACTIVE"
    db.run.conflicts = {}
    db.run.dungeons = {}
    db.run.dungeonOrder = {}
    db.run.levelGapBlocked = false
    db.eventLog = {}
    db.violations = {}
    db.pendingProposalId = nil
    db.acceptedRunId = nil
    db.acceptedRulesetHash = nil
    db.proposals = {}
    db.ruleAmendments = {}

    if self.RestoreActionCamSettings then
        self:RestoreActionCamSettings()
    end

    self:AddLog("RUN_RESET", "Local run reset.")
    Print("local run reset.")

    if self.Sync_BroadcastStatus then
        self:Sync_BroadcastStatus("RUN_RESET", { fast = true })
    end

    if self.HUD_Refresh then
        self:HUD_Refresh()
    end

    return true
end

function SC:GetStatusText()
    local db = EnsureDatabase()
    local run = db.run

    local participant = db.run.participants[GetPlayerKey(db.character)]

    if participant and participant.status == "FAILED" then
        return "Failed"
    end

    if run.active then
        return "Active"
    end

    if run.completed then
        return "Completed"
    end

    return "Inactive"
end

function SC:PrintStatus()
    local db = EnsureDatabase()
    local character = db.character
    local run = db.run

    Print("status: " .. self:GetStatusText())
    Print("character: " .. character.name .. "-" .. character.realm .. " " .. character.class .. " level " .. tostring(character.level))
    Print("zone: " .. tostring(character.zone))
    Print("started: " .. FormatTime(run.startTime))
    Print("active time: " .. FormatDuration(self:GetActiveRunTimeSeconds()))
    Print("party: " .. self:GetPartyStatus())
    local participant = run.participants[GetPlayerKey(character)]
    Print("participant: " .. tostring(participant and participant.status or "INACTIVE"))
    Print("valid: " .. tostring(run.valid) .. ", failed: " .. tostring(run.failed))
    Print("deaths: " .. tostring(run.deathCount) .. ", violations: " .. tostring(run.warningCount))
end

function SC:PrintRoster()
    local db = EnsureDatabase()

    if #db.run.participantOrder == 0 then
        Print("roster is empty.")
        return
    end

    Print("run roster:")
    for _, playerKey in ipairs(db.run.participantOrder) do
        local participant = db.run.participants[playerKey]
        if participant then
            Print(participant.playerKey .. " - " .. participant.status .. " - level " .. tostring(participant.currentLevel or "?"))
        end
    end
end

function SC:PrintRun()
    local db = EnsureDatabase()
    local violationSnapshot = self.GetActiveViolationSnapshot and self:GetActiveViolationSnapshot(self:GetPlayerKey()) or nil
    local activeViolations = violationSnapshot and violationSnapshot.count or 0
    local activeConflicts = 0
    for _, conflict in pairs(db.run.conflicts or {}) do
        if conflict.active then
            activeConflicts = activeConflicts + 1
        end
    end

    local runName = (self.GetHiddenRunName and self:GetHiddenRunName(db.run.ruleset)) or db.run.runName or "none"
    Print("run: " .. tostring(runName))
    Print("runId: " .. tostring(db.run.runId or "none"))
    Print("active: " .. tostring(db.run.active) .. ", party: " .. self:GetPartyStatus())
    Print("activeTime: " .. FormatDuration(self:GetActiveRunTimeSeconds()) .. " (addon-observed)")
    Print("rulesetVersion: " .. tostring(db.run.ruleset.version) .. ", rulesetHash: " .. tostring(self.GetRulesetHash and self:GetRulesetHash() or "unknown"))
    Print("integrity: addon " .. tostring(self.version or "?") .. ", active violations " .. tostring(activeViolations) .. ", active conflicts " .. tostring(activeConflicts))
    if IsInGroup() then
        local lastSync = db.sync and (db.sync.lastReceivedAt or db.sync.lastSentAt)
        Print("sync: " .. (lastSync and (tostring(time() - lastSync) .. "s ago") or "none"))
    end
    Print("governance: " .. tostring(db.run.governance.mode))
end

function SC:GetDeathAnnouncementChannels()
    local db = EnsureDatabase()
    local channels = CopyDeathAnnouncementChannels(db.settings and db.settings.deathAnnouncements)
    db.settings.deathAnnouncements = channels
    return channels
end

function SC:IsDeathAnnouncementChannelEnabled(channel)
    local normalized = NormalizeDeathAnnouncementMode(channel)
    if not normalized or normalized == "OFF" then
        return false
    end
    return self:GetDeathAnnouncementChannels()[normalized] == true
end

function SC:SetDeathAnnouncementChannel(channel, enabled)
    local normalized = NormalizeDeathAnnouncementMode(channel)
    if not normalized or normalized == "OFF" then
        return false, "unknown announcement target: " .. tostring(channel)
    end

    local db = EnsureDatabase()
    local channels = self:GetDeathAnnouncementChannels()
    channels[normalized] = enabled and true or nil
    db.settings.deathAnnouncements = channels
    return true, "death announcements: " .. FormatDeathAnnouncementChannels(channels)
end

function SC:SetDeathAnnouncementMode(mode)
    local normalized = NormalizeDeathAnnouncementMode(mode)
    if not normalized then
        return false, "usage: /sc announce off|chat|party|guild"
    end

    local db = EnsureDatabase()
    local channels = {}
    if normalized ~= "OFF" then
        channels[normalized] = true
    end
    db.settings.deathAnnouncements = channels
    return true, "death announcements: " .. FormatDeathAnnouncementChannels(channels)
end

function SC:SetDeathAnnouncementChannelsFromText(text)
    local channels = {}
    local sawValue = false

    for token in string.gmatch(tostring(text or ""), "[^,%s/|]+") do
        local normalized = NormalizeDeathAnnouncementMode(token)
        if not normalized then
            return false, "usage: /sc announce off|chat|party|guild"
        end
        sawValue = true
        if normalized == "OFF" then
            channels = {}
        else
            channels[normalized] = true
        end
    end

    if not sawValue then
        return false, "usage: /sc announce off|chat|party|guild"
    end

    local db = EnsureDatabase()
    db.settings.deathAnnouncements = channels
    return true, "death announcements: " .. FormatDeathAnnouncementChannels(channels)
end

function SC:PrintDeathAnnouncementSettings()
    Print("death announcements: " .. FormatDeathAnnouncementChannels(self:GetDeathAnnouncementChannels()))
    Print("usage: /sc announce off|chat|party|guild")
end

function SC:AnnounceLocalDeath(detail)
    local db = EnsureDatabase()
    local channels = self:GetDeathAnnouncementChannels()
    local announced = false
    local anyChannel = false
    for _, channel in ipairs(DEATH_ANNOUNCEMENT_ORDER) do
        if channels[channel] then
            anyChannel = true
            break
        end
    end
    if not anyChannel then
        return false
    end

    local character = db.character or GetPlayerSnapshot()
    local run = db.run or {}
    local message = "Softcore death: " .. tostring(character.name or "Unknown")
        .. " level " .. tostring(character.level or UnitLevel("player") or "?")
        .. " in " .. tostring(character.zone or GetRealZoneText() or "Unknown")
        .. " - " .. tostring(detail or "character died.")
    local runName = (self.GetHiddenRunName and self:GetHiddenRunName(run.ruleset)) or run.runName
    if runName then
        message = message .. " (" .. tostring(runName) .. ")"
    end

    if channels.CHAT then
        Print(message)
        announced = true
    end

    if channels.PARTY then
        local channel = GetGroupAnnouncementChannel()
        if not channel then
            Print(IsInRaid() and "death announcement skipped: raid groups are not supported." or "death announcement skipped: not in a group.")
        else
            SendChatMessage(message, channel)
            announced = true
        end
    end

    if channels.GUILD then
        if not IsInGuild() then
            Print("death announcement skipped: not in a guild.")
        else
            SendChatMessage(message, "GUILD")
            announced = true
        end
    end

    return announced
end

function SC:PrintConflicts()
    local db = EnsureDatabase()
    local found = false

    for _, conflict in pairs(db.run.conflicts) do
        if conflict.active then
            found = true
            Print(conflict.playerKey .. " - " .. conflict.type .. " - local " .. tostring(conflict.localValue) .. " / remote " .. tostring(conflict.remoteValue))
            if conflict.type == "RULESET_MISMATCH" and conflict.remoteRuleset and db.run.ruleset then
                if self.DescribeRulesetDifferences then
                    for _, diff in ipairs(self:DescribeRulesetDifferences(db.run.ruleset, conflict.remoteRuleset)) do
                        Print("  " .. diff.ruleName .. ": local " .. tostring(diff.localValue) .. " / remote " .. tostring(diff.remoteValue))
                    end
                else
                    Print("  full rule diff unavailable.")
                end
            elseif conflict.type == "RULESET_MISMATCH" then
                Print("  full remote rules unavailable. Use /sc resync, then /sc conflicts.")
            end
        end
    end

    if not found then
        Print("no active conflicts.")
    end
end

function SC:PrintRules()
    local db = EnsureDatabase()
    local rules = db.run.ruleset
    local order = {
        "death",
        "groupingMode",
        "failedMemberBlocksParty",
        "allowLateJoin",
        "allowReplacementCharacters",
        "requireLeaderApprovalForJoin",
        "auctionHouse",
        "mailbox",
        "trade",
        "mounts",
        "flying",
        "flightPaths",
        "outsiderGrouping",
        "unsyncedMembers",
        "maxLevelGap",
        "maxLevelGapValue",
        "dungeonRepeat",
        "gearQuality",
        "heirlooms",
        "enchants",
        "instanceWithUnsyncedPlayers",
        "bank",
        "warbandBank",
        "guildBank",
        "voidStorage",
        "craftingOrders",
        "vendor",
        "consumables",
        "instancedPvP",
        "actionCam",
    }

    Print("current rules:")
    for _, ruleName in ipairs(order) do
        Print(ruleName .. " = " .. tostring(rules[ruleName]))
    end
end

function SC:PrintAccessRules()
    local db = EnsureDatabase()
    local rules = db.run.ruleset
    local order = {
        "bank",
        "warbandBank",
        "guildBank",
        "voidStorage",
        "craftingOrders",
        "vendor",
        "auctionHouse",
        "mailbox",
        "trade",
    }

    Print("access rules:")
    for _, ruleName in ipairs(order) do
        Print(ruleName .. " = " .. tostring(rules[ruleName]))
    end
end

function SC:PrintLog()
    local db = EnsureDatabase()

    if #db.eventLog == 0 then
        Print("event log is empty.")
        return
    end

    Print("recent event log:")
    local printed = 0
    for index = math.max(1, #db.eventLog - 9), #db.eventLog do
        local entry = db.eventLog[index]
        if self:ShouldDisplayLogEntryInUI(entry) then
            Print(FormatTime(entry.time) .. " [" .. entry.kind .. "] " .. FormatPlayerLabel(entry.actorKey or entry.playerKey) .. ": " .. entry.message)
            printed = printed + 1
        end
    end
    if printed == 0 then
        Print("(no entries in this window match the current run rules display filter.)")
    end
end

local function CountActiveViolations(violations)
    local count = 0
    for _, violation in ipairs(violations or {}) do
        if violation.status ~= "CLEARED" then
            count = count + 1
        end
    end
    return count
end

local function CountActiveConflicts(conflicts)
    local count = 0
    for _, conflict in pairs(conflicts or {}) do
        if conflict.active then
            count = count + 1
        end
    end
    return count
end

local function CsvValue(value)
    local text = tostring(value == nil and "" or value)
    text = string.gsub(text, "[\t\r\n]+", " ")
    text = string.gsub(text, "\"", "\"\"")
    if string.find(text, "[,\"]") then
        text = "\"" .. text .. "\""
    end
    return text
end

local function AddCsvLine(lines, section, field, value, timeValue, actor, kind, message)
    table.insert(lines, table.concat({
        CsvValue(section),
        CsvValue(field),
        CsvValue(value),
        CsvValue(timeValue),
        CsvValue(actor),
        CsvValue(kind),
        CsvValue(message),
    }, ","))
end

local function BuildRunExportText()
    local db = EnsureDatabase()
    local run = db.run or {}
    local character = db.character or GetPlayerSnapshot()
    local lines = {}

    table.insert(lines, "Section,Field,Value,Time,Actor,Kind,Message")
    AddCsvLine(lines, "Info", "Format", "Softcore CSV export - comma-delimited for spreadsheets")
    AddCsvLine(lines, "Info", "Exported", FormatTime(time()))
    AddCsvLine(lines, "Character", "Name", tostring(character.name or "Unknown") .. "-" .. tostring(character.realm or "Unknown"))
    AddCsvLine(lines, "Character", "Class", character.class or "?")
    AddCsvLine(lines, "Character", "Level", character.level or "?")
    AddCsvLine(lines, "Character", "Zone", character.zone or "?")
    AddCsvLine(lines, "Run", "Name", (SC.GetHiddenRunName and SC:GetHiddenRunName(run.ruleset)) or run.runName or "none")
    AddCsvLine(lines, "Run", "Run ID", run.runId or "none")
    AddCsvLine(lines, "Run", "Status", SC:GetStatusText())
    AddCsvLine(lines, "Run", "Active", run.active == true)
    AddCsvLine(lines, "Run", "Valid", run.valid ~= false)
    AddCsvLine(lines, "Run", "Failed", run.failed == true)
    AddCsvLine(lines, "Run", "Completed", run.completed == true)
    AddCsvLine(lines, "Run", "Completed At", FormatTime(run.completedAt))
    AddCsvLine(lines, "Run", "Started", FormatTime(run.startTime))
    AddCsvLine(lines, "Run", "Observed Time", FormatDuration(SC:GetActiveRunTimeSeconds()))
    AddCsvLine(lines, "Run", "Deaths", run.deathCount or 0)
    AddCsvLine(lines, "Run", "Active Violations", CountActiveViolations(db.violations))
    AddCsvLine(lines, "Run", "Active Conflicts", CountActiveConflicts(run.conflicts))
    AddCsvLine(lines, "Run", "Ruleset Version", run.ruleset and run.ruleset.version or "?")
    AddCsvLine(lines, "Run", "Ruleset Hash", SC.GetRulesetHash and SC:GetRulesetHash() or "unknown")
    AddCsvLine(lines, "Run", "Party Status", SC:GetPartyStatus())

    if db.completionAward then
        local award = db.completionAward
        AddCsvLine(lines, "Completion Award", "Run ID", award.runId or "")
        AddCsvLine(lines, "Completion Award", "Preset", award.presetLabel or award.preset or "")
        AddCsvLine(lines, "Completion Award", "Completed At", FormatTime(award.completedAt))
        AddCsvLine(lines, "Completion Award", "Observed Time", FormatDuration(award.activeTimeSeconds))
        AddCsvLine(lines, "Completion Award", "Deaths", award.deaths or 0)
        AddCsvLine(lines, "Completion Award", "Total Violations", award.totalViolations or 0)
        AddCsvLine(lines, "Completion Award", "Dungeons", award.dungeonCount or 0)
        AddCsvLine(lines, "Completion Award", "Party Members", award.partyMembers or 0)
    end

    if #(run.participantOrder or {}) > 0 then
        for _, playerKey in ipairs(run.participantOrder) do
            local participant = run.participants and run.participants[playerKey]
            if participant then
                AddCsvLine(lines, "Participant", participant.playerKey or playerKey, participant.status or "?", nil, nil, "Level", participant.currentLevel or participant.levelAtJoin or "?")
            end
        end
    end

    if #(db.eventLog or {}) > 0 then
        for index = 1, #db.eventLog do
            local entry = db.eventLog[index]
            AddCsvLine(lines, "Log", tostring(index), "", FormatTime(entry.time), entry.actorKey or entry.playerKey or "", entry.kind or "?", entry.message or "")
        end
    end

    return table.concat(lines, "\n")
end

function SC:GetRunExportText()
    return BuildRunExportText()
end

local function AddKeyValueCsv(lines, section, field, source)
    if type(source) ~= "table" then
        return
    end

    local parts = {}
    for key, value in pairs(source) do
        if type(value) ~= "table" and type(value) ~= "function" then
            table.insert(parts, tostring(key) .. "=" .. tostring(value))
        end
    end
    table.sort(parts)
    AddCsvLine(lines, section, field, table.concat(parts, " | "))
end

local function BuildDebugExportText()
    local db = EnsureDatabase()
    local run = db.run or {}
    local character = db.character or GetPlayerSnapshot()
    local lines = {}
    local localKey = GetPlayerKey(character)

    table.insert(lines, "Section,Field,Value,Time,Actor,Kind,Message")
    AddCsvLine(lines, "Info", "Format", "Softcore debug export - paste both clients into chat")
    AddCsvLine(lines, "Info", "Exported", FormatTime(time()))
    AddCsvLine(lines, "Character", "Player", localKey)
    AddCsvLine(lines, "Character", "Level", character.level or "?")
    AddCsvLine(lines, "Character", "Zone", character.zone or "?")
    AddCsvLine(lines, "Run", "Run ID", run.runId or "none")
    AddCsvLine(lines, "Run", "Active", run.active == true)
    AddCsvLine(lines, "Run", "Status", SC:GetStatusText())
    AddCsvLine(lines, "Run", "Party Status", SC:GetPartyStatus())
    AddCsvLine(lines, "Run", "Ruleset Hash", SC.GetRulesetHash and SC:GetRulesetHash() or "unknown")
    AddCsvLine(lines, "Rule", "enchants", run.ruleset and run.ruleset.enchants or "")
    AddCsvLine(lines, "Rule", "actionCam", run.ruleset and run.ruleset.actionCam or "")
    AddCsvLine(lines, "Rule", "cameraMode", run.cameraMode or "")
    AddCsvLine(lines, "Sync", "Last Sent", db.sync and db.sync.lastSentAt and FormatTime(db.sync.lastSentAt) or "never")
    AddCsvLine(lines, "Sync", "Last Received", db.sync and db.sync.lastReceivedAt and FormatTime(db.sync.lastReceivedAt) or "never")
    AddKeyValueCsv(lines, "Sync", "Last Send Result", db.sync and db.sync.lastSendResult)
    AddKeyValueCsv(lines, "Sync", "Last Chunked Send", db.sync and db.sync.lastChunkedSend)
    AddKeyValueCsv(lines, "Sync", "Last Reassembled Chunk", db.sync and db.sync.lastReassembledChunk)
    AddCsvLine(lines, "Sync", "Stale Send Drops", db.sync and db.sync.staleSendDrops or 0)
    AddKeyValueCsv(lines, "Sync", "Last Stale Send Drop", db.sync and db.sync.lastStaleSendDrop)
    AddCsvLine(lines, "Sync", "Coalesced Status Drops", db.sync and db.sync.coalescedStatusDrops or 0)
    AddKeyValueCsv(lines, "Sync", "Last Coalesced Status Drop", db.sync and db.sync.lastCoalescedStatusDrop)

    local proposal = SC.GetPendingProposal and SC:GetPendingProposal() or nil
    if proposal then
        AddCsvLine(lines, "Proposal", proposal.proposalId or "?", proposal.status or "?", FormatTime(proposal.proposedAt), proposal.proposedBy, proposal.proposalType, proposal.runId)
    else
        AddCsvLine(lines, "Proposal", "Pending", "none")
    end

    for _, violation in ipairs(db.violations or {}) do
        AddCsvLine(
            lines,
            "Violation",
            violation.id or "?",
            tostring(violation.status or "?") .. " shared=" .. tostring(violation.shared == true),
            FormatTime(violation.createdAt),
            violation.playerKey or "",
            violation.type or "?",
            tostring(violation.detail or "") .. " clearedBy=" .. tostring(violation.clearedBy or "")
        )
    end

    for _, entry in ipairs(db.eventLog or {}) do
        AddCsvLine(lines, "Audit", entry.id or "?", "", FormatTime(entry.time), entry.actorKey or entry.playerKey or "", entry.kind or "?", entry.message or "")
    end

    for playerKey, participant in pairs(run.participants or {}) do
        AddCsvLine(lines, "Participant", playerKey, participant.status or "?", FormatTime(participant.joinedAt), participant.playerKey or "", "Level", participant.currentLevel or participant.levelAtJoin or "?")
    end

    if SC.groupStatuses then
        for playerKey, peer in pairs(SC.groupStatuses) do
            AddCsvLine(
                lines,
                "Peer",
                playerKey,
                tostring(peer.participantStatus or "?") .. " active=" .. tostring(peer.active == true),
                peer.lastSeen and FormatTime(peer.lastSeen) or "never",
                peer.playerKey or playerKey,
                "violations=" .. tostring(peer.activeViolations or 0),
                "run=" .. tostring(peer.runId or "") .. " rules=" .. tostring(peer.rulesetHash or "") .. " latest=" .. tostring(peer.latestViolation and peer.latestViolation.id or "")
            )
        end
    end

    for _, conflict in pairs(run.conflicts or {}) do
        AddCsvLine(lines, "Conflict", conflict.playerKey or "?", conflict.type or "?", FormatTime(conflict.detectedAt), "", conflict.active and "ACTIVE" or "CLEARED", "local=" .. tostring(conflict.localValue) .. " remote=" .. tostring(conflict.remoteValue))
    end

    for index, entry in ipairs(db.debugTrace or {}) do
        AddKeyValueCsv(lines, "Trace", tostring(index) .. " " .. tostring(entry.kind or "?"), entry)
    end

    return table.concat(lines, "\n")
end

function SC:GetDebugExportText()
    return BuildDebugExportText()
end

local exportFrame

local function EnsureRunExportFrame()
    if exportFrame then
        return exportFrame
    end

    local frame = CreateFrame("Frame", "SoftcoreRunExportFrame", UIParent, "BackdropTemplate")
    frame:SetSize(760, 520)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
        frame:SetBackdropColor(0, 0, 0, 0.96)
    end

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -18)
    frame.title:SetText("Softcore CSV Export")

    frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.hint:SetPoint("TOP", frame.title, "BOTTOM", 0, -8)
    frame.hint:SetText("Comma-delimited for spreadsheets. Highlighted text is ready to copy.")

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", -6, -6)

    frame.scroll = CreateFrame("ScrollFrame", "SoftcoreRunExportScrollFrame", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 22, -64)
    frame.scroll:SetPoint("BOTTOMRIGHT", -34, 24)

    frame.editBox = CreateFrame("EditBox", nil, frame.scroll)
    frame.editBox:SetMultiLine(true)
    frame.editBox:SetAutoFocus(false)
    frame.editBox:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    frame.editBox:SetMaxLetters(0)
    frame.editBox:SetWidth(690)
    frame.editBox:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
    end)
    frame.editBox:SetScript("OnTextChanged", function(editBox)
        local height = editBox:GetStringHeight() + 20
        if height < frame.scroll:GetHeight() then
            height = frame.scroll:GetHeight()
        end
        editBox:SetHeight(height)
    end)
    frame.scroll:SetScrollChild(frame.editBox)

    frame:Hide()
    exportFrame = frame
    return exportFrame
end

local function ShowRunExportWindow(text, title, hint)
    if not CreateFrame or not UIParent then
        return false
    end

    local frame = EnsureRunExportFrame()
    frame.title:SetText(title or "Softcore CSV Export")
    frame.hint:SetText(hint or "Comma-delimited for spreadsheets. Highlighted text is ready to copy.")
    frame.editBox:SetText(text or "")
    frame.editBox:SetCursorPosition(0)
    frame.editBox:HighlightText()
    frame.editBox:SetFocus()
    frame.scroll:SetVerticalScroll(0)
    frame:Show()
    return true
end

function SC:PrintRunExport()
    local text = BuildRunExportText()
    for line in string.gmatch(text, "([^\n]+)") do
        Print(line)
    end
end

function SC:ShowRunExport()
    local text = BuildRunExportText()
    if ShowRunExportWindow(text) then
        Print("CSV export opened for copy.")
    else
        self:PrintRunExport()
    end
end

function SC:PrintDebugExport()
    local text = BuildDebugExportText()
    for line in string.gmatch(text, "([^\n]+)") do
        Print(line)
    end
end

function SC:ShowDebugExport()
    local text = BuildDebugExportText()
    if ShowRunExportWindow(text, "Softcore Debug Export", "Paste this from both clients when tracing sync or violation lifecycles.") then
        Print("debug export opened for copy.")
    else
        self:PrintDebugExport()
    end
end

local SAMPLE_AWARD_NAMES = {
    "Aelyra",
    "Brenic",
    "Cindra",
    "Darian",
    "Elowen",
    "Kaelis",
    "Maris",
    "Seren",
}

local SAMPLE_AWARD_CLASSES = {
    { class = "WARRIOR", label = "Warrior" },
    { class = "PALADIN", label = "Paladin" },
    { class = "HUNTER", label = "Hunter" },
    { class = "ROGUE", label = "Rogue" },
    { class = "PRIEST", label = "Priest" },
    { class = "SHAMAN", label = "Shaman" },
    { class = "MAGE", label = "Mage" },
    { class = "WARLOCK", label = "Warlock" },
    { class = "MONK", label = "Monk" },
    { class = "DRUID", label = "Druid" },
    { class = "DEMONHUNTER", label = "Demon Hunter" },
    { class = "EVOKER", label = "Evoker" },
}

local SAMPLE_AWARD_PRESETS = {
    { preset = "CASUAL", label = "Casual" },
    { preset = "CHEF_SPECIAL", label = "Chef's Special" },
    { preset = "IRONMAN", label = "Ironman" },
    { preset = "IRON_VIGIL", label = "Iron Vigil" },
    { preset = "CUSTOM", label = "Custom" },
}

local function PickRandom(list)
    return list[math.random(1, #list)]
end

function SC:ShowSampleCompletionAward()
    local class = PickRandom(SAMPLE_AWARD_CLASSES)
    local preset = PickRandom(SAMPLE_AWARD_PRESETS)
    local totalViolations = math.random(0, 7)
    local clearedViolations = totalViolations > 0 and math.random(0, totalViolations) or 0
    local award = {
        id = "SC-SAMPLE-AWARD-" .. tostring(time()),
        runId = "SC-SAMPLE-" .. tostring(math.random(1000, 9999)),
        runName = "Sample Softcore Run",
        characterName = PickRandom(SAMPLE_AWARD_NAMES),
        realm = "Thrall",
        class = class.class,
        classLabel = class.label,
        startLevel = math.random(1, 10),
        completedLevel = 80,
        startedAt = time() - math.random(3600 * 48, 3600 * 24 * 21),
        completedAt = time() - math.random(60, 3600 * 24),
        activeTimeSeconds = math.random(3600 * 18, 3600 * 9 * 24),
        deaths = math.random(0, 2),
        totalViolations = totalViolations,
        activeViolations = totalViolations - clearedViolations,
        clearedViolations = clearedViolations,
        dungeonCount = math.random(0, 24),
        partyMembers = math.random(1, 5),
        rulesetHash = "sample",
        preset = preset.preset,
        presetLabel = preset.label,
        rulesetModified = math.random(1, 4) == 1,
        rulesetModifiedAtLevel = math.random(18, 72),
    }
    if not award.rulesetModified then
        award.rulesetModifiedAtLevel = nil
    end

    Print("opening sample completion award.")
    self:PlayUISound("ACHIEVEMENT_EARNED")
    self:PlayUISound("RUN_COMPLETED")
    if self.ShowCompletionAward then
        self:ShowCompletionAward(award)
    else
        Print("completion award UI is not loaded.")
    end
end

function SC:PrintHelp()
    Print("Softcore commands:")
    Print("  /sc menu | status | rules | violations | log")
    Print("  /sc status chat | rules chat | log chat")
    Print("  /sc run chat      print run integrity summary")
    Print("  /sc export        copy CSV run summary")
    Print("  /sc participants  show current participants")
    Print("  /sc conflicts     print active party conflicts")
    Print("  /sc syncdebug | sd  print sync diagnostics")
    Print("  /sc debuglog | dl   copy sync/audit debug export")
    Print("  /sc debugclear | dc clear debug trace for a fresh test")
    Print("  /sc gear          print equipped gear rule status")
    Print("  /sc dungeons      print dungeon tracking state")
    Print("  /sc proposal      show pending proposal")
    Print("  /sc accept | decline")
    Print("  /sc propose       propose a grouped run")
    Print("  /sc propose-add Player-Realm")
    Print("  /sc announce off|chat|party|guild")
    Print("  /sc resync        re-sync state with party")
    Print("  /sc hud          toggle the HUD")
    Print("  /sc minimap      toggle the minimap button")
    Print("  /sc reset | retire")
    Print("  /sc access        print access rules")
    Print("  /sc rule name value")
end

function SC:HandleSlash(input)
    local text = strtrim(input or "")
    local command, rest = string.match(text, "^(%S*)%s*(.-)$")
    command = string.lower(command or "")

    if command == "" or command == "help" then
        self:PrintHelp()
    elseif command == "menu" then
        if self.OpenMasterWindow then
            self:OpenMasterWindow()
        else
            self:PrintStatus()
        end
    elseif command == "start" then
        self:StartRun()
    elseif command == "new" then
        if self.OpenMasterWindow then
            self:OpenMasterWindow("RUN")
        else
            Print("master UI is not loaded.")
        end
    elseif command == "status" then
        local sub = string.lower(strtrim(rest or ""))
        if sub == "chat" or sub == "print" then
            self:PrintStatus()
        elseif self.OpenMasterWindow then
            self:OpenMasterWindow("OVERVIEW")
        else
            self:PrintStatus()
        end
    elseif command == "reset" then
        if self.ConfirmStopRun then
            self:ConfirmStopRun()
        else
            self:ResetRun()
        end
    elseif command == "log" then
        local sub = string.lower(strtrim(rest or ""))
        if sub == "chat" or sub == "print" then
            self:PrintLog()
        elseif self.OpenMasterWindow then
            self:OpenMasterWindow("LOG")
        else
            self:PrintLog()
        end
    elseif command == "violations" then
        if self.OpenMasterWindow then
            self:OpenMasterWindow("VIOLATIONS")
        else
            Print("master UI is not loaded.")
        end
    elseif command == "gear" then
        if self.PrintGearStatus then
            self:PrintGearStatus()
        else
            Print("gear checks are not loaded.")
        end
    elseif command == "dungeons" then
        if self.PrintDungeons then
            self:PrintDungeons()
        else
            Print("dungeon tracking is not loaded.")
        end
    elseif command == "roster" or command == "participants" then
        local sub = string.lower(strtrim(rest or ""))
        if sub == "chat" or sub == "print" then
            self:PrintRoster()
        elseif self.OpenMasterWindow then
            self:OpenMasterWindow("OVERVIEW")
        else
            self:PrintRoster()
        end
    elseif command == "run" then
        local sub = string.lower(strtrim(rest or ""))
        if sub == "chat" or sub == "print" then
            self:PrintRun()
        elseif self.OpenMasterWindow then
            self:OpenMasterWindow("OVERVIEW")
        else
            self:PrintRun()
        end
    elseif command == "export" or command == "summary" then
        local sub = string.lower(strtrim(rest or ""))
        if sub == "chat" or sub == "print" then
            self:PrintRunExport()
        else
            self:ShowRunExport()
        end
    elseif command == "conflicts" then
        self:PrintConflicts()
    elseif command == "syncdebug" or command == "sd" then
        if self.PrintSyncDebug then
            self:PrintSyncDebug()
        else
            Print("sync debug is not loaded.")
        end
    elseif command == "debuglog" or command == "debug" or command == "dl" then
        local sub = string.lower(strtrim(rest or ""))
        if sub == "chat" or sub == "print" then
            self:PrintDebugExport()
        else
            self:ShowDebugExport()
        end
    elseif command == "debugclear" or command == "dc" then
        if self.ClearDebugTrace then
            self:ClearDebugTrace(strtrim(rest or ""))
            Print("debug trace cleared.")
        else
            Print("debug trace is not available.")
        end
    elseif command == "awardtest" or command == "sampleaward" then
        self:ShowSampleCompletionAward()
    elseif command == "announce" or command == "deathannounce" then
        local mode = string.lower(strtrim(rest or ""))
        if mode == "" then
            self:PrintDeathAnnouncementSettings()
        else
            local _, message = self:SetDeathAnnouncementChannelsFromText(mode)
            Print(message)
        end
    elseif command == "resync" then
        if self.Sync_RequestFullState then
            self:Sync_RequestFullState()
            Print("requested full state from party.")
        else
            Print("sync is not ready yet.")
        end
    elseif command == "rules" then
        local sub = string.lower(strtrim(rest or ""))
        if sub == "chat" or sub == "print" then
            self:PrintRules()
        elseif self.OpenMasterWindow then
            self:OpenMasterWindow("RUN")
        else
            self:PrintRules()
        end
    elseif command == "access" then
        self:PrintAccessRules()
    elseif command == "proposal" then
        if self.ShowPendingProposal then
            self:ShowPendingProposal()
        else
            Print("proposal UI is not loaded.")
        end
    elseif command == "accept" then
        if self.AcceptPendingProposal then
            self:AcceptPendingProposal()
        else
            Print("proposal handling is not loaded.")
        end
    elseif command == "decline" then
        if self.DeclinePendingProposal then
            self:DeclinePendingProposal()
        else
            Print("proposal handling is not loaded.")
        end
    elseif command == "propose" then
        if self.ProposeRunFromSlash then
            self:ProposeRunFromSlash(rest)
        else
            Print("proposal handling is not loaded.")
        end
    elseif command == "propose-add" then
        if self.ProposeAddParticipant then
            self:ProposeAddParticipant(rest)
        else
            Print("proposal handling is not loaded.")
        end
    elseif command == "hud" then
        if self.HUD_Toggle then
            self:HUD_Toggle()
        else
            Print("HUD is not loaded.")
        end
    elseif command == "minimap" then
        if self.MinimapButton_Toggle then
            self:MinimapButton_Toggle()
        else
            Print("minimap button is not loaded.")
        end
    elseif command == "rule" then
        local ruleName, value = string.match(rest or "", "^(%S+)%s+(%S+)$")
        if ruleName and value then
            local _, message = self:SetRule(ruleName, string.upper(value))
            Print(message)
        else
            Print("usage: /sc rule ruleName value")
        end
    elseif command == "add" then
        if rest and rest ~= "" then
            local participant, added = self:AddParticipant(rest)
            if added then
                Print("added participant: " .. participant.playerKey .. " (" .. participant.status .. ")")
            else
                Print(participant.playerKey .. " is already a participant (" .. participant.status .. ").")
            end
            if added and self.Sync_BroadcastStatus then
                self:Sync_BroadcastStatus("PARTICIPANT_ADDED", { fast = true })
            end
        else
            Print("usage: /sc add Player-Realm")
        end
    elseif command == "retire" then
        local db = EnsureDatabase()
        if not db.run.active then
            Print("no active run to retire from.")
            return
        end

        local participant = self:GetOrCreateParticipant(GetPlayerKey(db.character))
        if participant.status == "FAILED" then
            Print("failed characters cannot be retired.")
        elseif participant.status == "RETIRED" then
            Print(participant.playerKey .. " is already retired.")
        else
            participant.status = "RETIRED"
            participant.leftAt = time()
            self:AddLog("PARTICIPANT_RETIRED", participant.playerKey .. " retired from the run.", {
                playerKey = participant.playerKey,
            })
            Print("retired " .. participant.playerKey .. ".")
            if self.Sync_BroadcastStatus then
                self:Sync_BroadcastStatus("PARTICIPANT_RETIRED", { fast = true })
            end
        end
    else
        self:PrintHelp()
    end
end

function SC:Initialize()
    BindCharacterDatabase()
    EnsureDatabase()
    self:ResumeActiveRunTimer()
    self:RefreshCharacter()
    if self.ClearStalePendingProposal then
        self:ClearStalePendingProposal()
    end
    if self.ClearStaleRuleAmendments then
        self:ClearStaleRuleAmendments()
    end

    SLASH_SOFTCORE1 = "/softcore"
    SLASH_SOFTCORE2 = "/sc"
    SlashCmdList.SOFTCORE = function(input)
        SC:HandleSlash(input)
    end

    if self.HUD_Create then
        self:HUD_Create()
    end

    if self.MinimapButton_Create then
        self:MinimapButton_Create()
    end

    if self.Events_Register then
        self:Events_Register()
    end

    if self.Sync_Initialize then
        self:Sync_Initialize()
    end

    Print("loaded. Type /sc status.")
end

SC.frame = CreateFrame("Frame")
SC.frame:RegisterEvent("ADDON_LOADED")
SC.frame:RegisterEvent("PLAYER_LOGOUT")
SC.frame:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName == ADDON_NAME then
        SC:Initialize()
    elseif event == "PLAYER_LOGOUT" then
        if SC.UpdateActiveRunTime then
            SC:UpdateActiveRunTime()
        end
    end
end)
