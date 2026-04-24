-- Softcore
-- Local MVP state, slash commands, and shared helpers.

local ADDON_NAME = ...

Softcore = Softcore or {}
local SC = Softcore

SC.name = "Softcore"
SC.version = "0.2.9"
SC.maxLogEntries = 30

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r " .. tostring(message))
end

local function FormatTime(timestamp)
    if not timestamp then
        return "never"
    end

    return date("%Y-%m-%d %H:%M:%S", timestamp)
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

local function GetPlayerKey(character)
    character = character or GetPlayerSnapshot()
    return BuildPlayerKey(character.name, character.realm)
end

local function CreateDefaultRuleset()
    return {
        id = "default",
        name = "Default Softcore Rules",
        version = 1,
        warningsAreFatal = false,
        deathIsFatal = true,
        death = "CHARACTER_FAIL",
        deathFails = "CHARACTER_ONLY",
        failedMemberBlocksParty = true,
        allowLateJoin = true,
        allowReplacementCharacters = true,
        requireLeaderApprovalForJoin = true,
        auctionHouse = "WARNING",
        mailbox = "WARNING",
        trade = "WARNING",
        mounts = "ALLOWED",
        flying = "ALLOWED",
        flightPaths = "ALLOWED",
        outsiderGrouping = "WARNING",
        unsyncedMembers = "WARNING",
        maxLevelGap = "ALLOWED",
        dungeonRepeat = "ALLOWED",
        bank = "WARNING",
        warbandBank = "WARNING",
        guildBank = "WARNING",
        voidStorage = "LOG_ONLY",
        craftingOrders = "LOG_ONLY",
        vendor = "ALLOWED",
    }
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
        for index = 1, GetNumGroupMembers() do
            local name, realm = UnitFullName("raid" .. index)
            if name then
                keys[BuildPlayerKey(name, realm)] = true
            end
        end
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

local function EnsureRunDefaults(run)
    if run.active == nil then run.active = false end
    if run.valid == nil then run.valid = true end
    if run.failed == nil then run.failed = false end
    run.runId = run.runId or nil
    run.startTime = run.startTime or nil
    run.deathCount = run.deathCount or 0
    run.warningCount = run.warningCount or 0
    run.ruleset = run.ruleset or CreateDefaultRuleset()
    run.participants = run.participants or {}
    run.participantOrder = run.participantOrder or {}
    run.partyStatus = run.partyStatus or "INACTIVE"
    run.governance = run.governance or CreateDefaultGovernance()
    run.conflicts = run.conflicts or {}

    for key, value in pairs(CreateDefaultRuleset()) do
        if run.ruleset[key] == nil then
            run.ruleset[key] = value
        end
    end

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
    SoftcoreDB.ruleAmendments = SoftcoreDB.ruleAmendments or {}
    SoftcoreDB.sync = SoftcoreDB.sync or {}
    SoftcoreDB.sync.remoteSequences = SoftcoreDB.sync.remoteSequences or {}
    SoftcoreDB.sync.localSequence = SoftcoreDB.sync.localSequence or 0

    EnsureRunDefaults(SoftcoreDB.run)
    if SoftcoreDB.run.active and not SoftcoreDB.run.runId then
        SoftcoreDB.nextIds.run = SoftcoreDB.nextIds.run + 1
        SoftcoreDB.run.runId = "SC-RUN-" .. tostring(time()) .. "-" .. tostring(SoftcoreDB.nextIds.run)
    end

    SC.db = SoftcoreDB
    return SoftcoreDB
end

local function CreateStableId(kind)
    local db = EnsureDatabase()

    db.nextIds[kind] = (db.nextIds[kind] or 0) + 1
    return "SC-" .. string.upper(kind) .. "-" .. tostring(time()) .. "-" .. tostring(db.nextIds[kind])
end

function SC:RefreshCharacter()
    local db = EnsureDatabase()
    db.character = GetPlayerSnapshot()
    return db.character
end

function SC:GetPlayerKey()
    return GetPlayerKey(GetPlayerSnapshot())
end

function SC:CreateRunId()
    return CreateStableId("run")
end

function SC:AddLog(kind, message, extra)
    local db = EnsureDatabase()
    local logEntryId = CreateStableId("log")
    local entry = {
        id = logEntryId,
        logEntryId = logEntryId,
        runId = db.run.runId,
        time = time(),
        kind = kind,
        message = message,
    }

    if extra then
        for key, value in pairs(extra) do
            entry[key] = value
        end
    end

    table.insert(db.eventLog, entry)

    -- Keep the visible saved log useful but small for this early addon phase.
    while #db.eventLog > self.maxLogEntries do
        table.remove(db.eventLog, 1)
    end

    if self.UI_Update then
        self:UI_Update()
    end

    return entry
end

function SC:LogEvent(kind, message)
    return self:AddLog(kind, message)
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
    self:AddLog("VIOLATION_ADDED", detail, {
        violationId = violation.id,
        violationType = violation.type,
        severity = violation.severity,
    })

    return violation
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
    local participant = self:GetOrCreateParticipant(playerKey)

    if participant.status ~= "FAILED" and participant.status ~= "RETIRED" then
        participant.status = "PENDING"
        participant.joinedAt = participant.joinedAt or time()
        participant.leftAt = nil
        self:AddLog("PARTICIPANT_ADDED", "Participant added: " .. participant.playerKey, {
            playerKey = participant.playerKey,
        })
    end

    return participant
end

function SC:IsParticipantInCurrentParty(playerKey)
    return GetCurrentPartyKeys()[playerKey] == true
end

function SC:MarkParticipantFailed(playerKey, reason)
    local participant = self:GetOrCreateParticipant(playerKey)

    if participant.status ~= "FAILED" then
        participant.status = "FAILED"
        participant.failedAt = time()
        participant.failReason = reason or "Failed"
        self:AddLog("PARTICIPANT_FAILED", participant.playerKey .. " failed: " .. participant.failReason, {
            playerKey = participant.playerKey,
        })
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

function SC:RefreshParticipantsFromRoster()
    local db = EnsureDatabase()
    local partyKeys = GetCurrentPartyKeys()

    if not db.run.active then
        return
    end

    for playerKey, participant in pairs(db.run.participants) do
        if participant.status ~= "FAILED" and participant.status ~= "RETIRED" then
            if partyKeys[playerKey] then
                if participant.status == "OUT_OF_PARTY" or participant.status == "UNSYNCED" then
                    participant.status = "ACTIVE"
                    participant.leftAt = nil
                    participant.joinedAt = participant.joinedAt or time()
                end
            elseif playerKey ~= GetPlayerKey(db.character) and (participant.status == "ACTIVE" or participant.status == "WARNING" or participant.status == "UNSYNCED" or participant.status == "PENDING") then
                self:MarkParticipantLeft(playerKey)
            end
        end
    end

    if db.run.ruleset.allowLateJoin then
        for playerKey in pairs(partyKeys) do
            if not db.run.participants[playerKey] then
                local participant = self:GetOrCreateParticipant(playerKey)
                participant.status = db.run.ruleset.requireLeaderApprovalForJoin and "PENDING" or "ACTIVE"
                participant.joinedAt = participant.joinedAt or time()
                self:AddLog("PARTICIPANT_DISCOVERED", "Party member discovered: " .. playerKey, {
                    playerKey = playerKey,
                })
            end
        end
    end
end

function SC:GetPartyStatus()
    local db = EnsureDatabase()

    if not db.run.active then
        db.run.partyStatus = "INACTIVE"
        return db.run.partyStatus
    end

    local hasWarning = false
    local hasUnsynced = false
    local hasConflict = false

    for playerKey, participant in pairs(db.run.participants) do
        if self:IsParticipantInCurrentParty(playerKey) then
            if participant.status == "FAILED" and db.run.ruleset.failedMemberBlocksParty then
                db.run.partyStatus = "BLOCKED"
                return db.run.partyStatus
            elseif participant.status == "RUN_MISMATCH" then
                hasConflict = true
            elseif participant.status == "WARNING" then
                hasWarning = true
            elseif participant.status == "PENDING" or participant.status == "UNSYNCED" then
                hasUnsynced = true
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
        db.run.partyStatus = "WARNING"
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

function SC:ClearViolation(violationId, clearedBy, clearReason)
    local db = EnsureDatabase()

    for _, violation in ipairs(db.violations) do
        if violation.id == violationId then
            if violation.status ~= "CLEARED" then
                violation.status = "CLEARED"
                violation.clearedAt = time()
                violation.clearedBy = clearedBy or GetPlayerKey(db.character)
                violation.clearReason = clearReason or "Cleared"
                self:AddLog("VIOLATION_CLEARED", "Violation cleared: " .. tostring(violation.type), {
                    violationId = violation.id,
                    clearedBy = violation.clearedBy,
                    clearReason = violation.clearReason,
                })
                if self.Sync_SendProposal then
                    self:Sync_SendProposal("VIOLATION_CLEAR", violation.id)
                end
            end

            return violation
        end
    end

    return nil
end

function SC:GetPlayerStatus()
    local db = EnsureDatabase()

    self:RefreshCharacter()
    local playerKey = GetPlayerKey(db.character)
    local participant = db.run.participants[playerKey]

    if db.run.active then
        participant = self:GetOrCreateParticipant(playerKey)
        participant.currentLevel = db.character.level
        participant.class = db.character.class
    end

    return {
        runId = db.run.runId,
        playerKey = playerKey,
        name = db.character.name,
        realm = db.character.realm,
        class = db.character.class,
        level = db.character.level,
        zone = db.character.zone,
        active = db.run.active,
        valid = db.run.valid,
        failed = participant and participant.status == "FAILED",
        participantStatus = participant and participant.status or "NOT_IN_RUN",
        partyStatus = self:GetPartyStatus(),
        rulesetVersion = db.run.ruleset.version,
        rulesetHash = self.GetRulesetHash and self:GetRulesetHash() or "",
        deaths = db.run.deathCount,
        warnings = db.run.warningCount,
        version = self.version,
        timestamp = time(),
    }
end

function SC:StartRun()
    local db = EnsureDatabase()

    db.character = GetPlayerSnapshot()
    db.run.runId = self:CreateRunId()
    db.run.active = true
    db.run.valid = true
    db.run.failed = false
    db.run.startTime = time()
    db.run.deathCount = 0
    db.run.warningCount = 0
    db.run.ruleset = CreateDefaultRuleset()
    db.run.governance = CreateDefaultGovernance()
    db.run.participants = {}
    db.run.participantOrder = {}
    db.run.partyStatus = "VALID"
    db.run.conflicts = {}
    db.eventLog = {}
    db.violations = {}
    local participant = self:GetOrCreateParticipant(GetPlayerKey(db.character))
    participant.status = "ACTIVE"
    participant.joinedAt = db.run.startTime
    participant.levelAtJoin = db.character.level
    participant.currentLevel = db.character.level
    participant.class = db.character.class

    self:AddLog("RUN_START", "Run started for " .. db.character.name .. "-" .. db.character.realm .. ".")
    self:RefreshParticipantsFromRoster()
    Print("run started.")

    if self.Sync_BroadcastStatus then
        self:Sync_BroadcastStatus("RUN_START")
    end

    if self.UI_Update then
        self:UI_Update()
    end
end

function SC:ResetRun()
    local db = EnsureDatabase()

    db.character = GetPlayerSnapshot()
    db.run.runId = nil
    db.run.active = false
    db.run.valid = true
    db.run.failed = false
    db.run.startTime = nil
    db.run.deathCount = 0
    db.run.warningCount = 0
    db.run.ruleset = CreateDefaultRuleset()
    db.run.governance = CreateDefaultGovernance()
    db.run.participants = {}
    db.run.participantOrder = {}
    db.run.partyStatus = "INACTIVE"
    db.run.conflicts = {}
    db.eventLog = {}
    db.violations = {}

    self:AddLog("RUN_RESET", "Local run reset.")
    Print("local run reset.")

    if self.Sync_BroadcastStatus then
        self:Sync_BroadcastStatus("RUN_RESET")
    end

    if self.UI_Update then
        self:UI_Update()
    end
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
    Print("party: " .. self:GetPartyStatus())
    local participant = run.participants[GetPlayerKey(character)]
    Print("participant: " .. tostring(participant and participant.status or "INACTIVE"))
    Print("valid: " .. tostring(run.valid) .. ", failed: " .. tostring(run.failed))
    Print("deaths: " .. tostring(run.deathCount) .. ", warnings: " .. tostring(run.warningCount))
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
    Print("runId: " .. tostring(db.run.runId or "none"))
    Print("active: " .. tostring(db.run.active) .. ", party: " .. self:GetPartyStatus())
    Print("rulesetVersion: " .. tostring(db.run.ruleset.version) .. ", rulesetHash: " .. tostring(self.GetRulesetHash and self:GetRulesetHash() or "unknown"))
    Print("governance: " .. tostring(db.run.governance.mode))
end

function SC:PrintConflicts()
    local db = EnsureDatabase()
    local found = false

    for _, conflict in pairs(db.run.conflicts) do
        if conflict.active then
            found = true
            Print(conflict.playerKey .. " - " .. conflict.type .. " - local " .. tostring(conflict.localValue) .. " / remote " .. tostring(conflict.remoteValue))
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
        "dungeonRepeat",
        "bank",
        "warbandBank",
        "guildBank",
        "voidStorage",
        "craftingOrders",
        "vendor",
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
    for index = math.max(1, #db.eventLog - 9), #db.eventLog do
        local entry = db.eventLog[index]
        Print(FormatTime(entry.time) .. " [" .. entry.kind .. "] " .. entry.message)
    end
end

function SC:PrintHelp()
    Print("/sc start - start a local run")
    Print("/sc status - print current run status")
    Print("/sc reset - reset the local run")
    Print("/sc log - print recent event logs")
    Print("/sc roster - print run participants")
    Print("/sc participants - print run participants")
    Print("/sc add Player-Realm - add a pending participant")
    Print("/sc retire - retire this character without failing")
    Print("/sc rules - print current ruleset")
    Print("/sc rule ruleName value - change a rule locally")
    Print("/sc run - print run metadata")
    Print("/sc conflicts - print sync conflicts")
    Print("/sc resync - request full state from party")
    Print("/sc access - print storage and economy access rules")
end

function SC:HandleSlash(input)
    local text = strtrim(input or "")
    local command, rest = string.match(text, "^(%S*)%s*(.-)$")
    command = string.lower(command or "")

    if command == "start" then
        self:StartRun()
    elseif command == "status" or command == "" then
        self:PrintStatus()
    elseif command == "reset" then
        self:ResetRun()
    elseif command == "log" then
        self:PrintLog()
    elseif command == "roster" or command == "participants" then
        self:PrintRoster()
    elseif command == "run" then
        self:PrintRun()
    elseif command == "conflicts" then
        self:PrintConflicts()
    elseif command == "resync" then
        if self.Sync_RequestFullState then
            self:Sync_RequestFullState()
            Print("requested full state from party.")
        else
            Print("sync is not ready yet.")
        end
    elseif command == "rules" then
        self:PrintRules()
    elseif command == "access" then
        self:PrintAccessRules()
    elseif command == "rule" then
        local ruleName, value = string.match(rest or "", "^(%S+)%s+(%S+)$")
        if ruleName and value then
            local ok, message = self:SetRule(ruleName, string.upper(value))
            Print(message)
        else
            Print("usage: /sc rule ruleName value")
        end
    elseif command == "add" then
        if rest and rest ~= "" then
            local participant = self:AddParticipant(rest)
            Print("added participant: " .. participant.playerKey .. " (" .. participant.status .. ")")
            if self.Sync_BroadcastStatus then
                self:Sync_BroadcastStatus("PARTICIPANT_ADDED")
            end
        else
            Print("usage: /sc add Player-Realm")
        end
    elseif command == "retire" then
        local db = EnsureDatabase()
        local participant = self:GetOrCreateParticipant(GetPlayerKey(db.character))
        if participant.status == "FAILED" then
            Print("failed characters cannot be retired.")
        else
            participant.status = "RETIRED"
            participant.leftAt = time()
            self:AddLog("PARTICIPANT_RETIRED", participant.playerKey .. " retired from the run.", {
                playerKey = participant.playerKey,
            })
            Print("retired " .. participant.playerKey .. ".")
            if self.Sync_BroadcastStatus then
                self:Sync_BroadcastStatus("PARTICIPANT_RETIRED")
            end
        end
    else
        self:PrintHelp()
    end
end

function SC:Initialize()
    EnsureDatabase()
    self:RefreshCharacter()

    SLASH_SOFTCORE1 = "/softcore"
    SLASH_SOFTCORE2 = "/sc"
    SlashCmdList.SOFTCORE = function(input)
        SC:HandleSlash(input)
    end

    if self.UI_Create then
        self:UI_Create()
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
SC.frame:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName == ADDON_NAME then
        SC:Initialize()
    end
end)
