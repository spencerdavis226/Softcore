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

function SC:PlayUISound(event)
    if not PlaySound then return end
    local SK = _G["SOUNDKIT"] or {}
    local sounds = {
        RUN_STARTED       = SK.IG_QUEST_LOG_ACCEPT          or 878,
        VIOLATION         = SK.UI_ERROR_MESSAGE              or 882,
        DEATH             = SK.IG_QUEST_FAILED               or 851,
        VIOLATION_CLEARED = SK.IG_QUEST_OBJECTIVE_COMPLETE   or 879,
        PROPOSAL_RECEIVED = SK.READY_CHECK                   or 8960,
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
        heirlooms = "WARNING",
        instanceWithUnsyncedPlayers = "WARNING",
        bank = "WARNING",
        warbandBank = "WARNING",
        guildBank = "WARNING",
        voidStorage = "LOG_ONLY",
        craftingOrders = "LOG_ONLY",
        vendor = "ALLOWED",
        consumables = "ALLOWED",
        instancedPvP = "ALLOWED",
        firstPersonOnly = "ALLOWED",
        actionCam = "ALLOWED",
        actionCamShoulderOffset = 1.5,
        actionCamDynamicPitch = true,
        actionCamEnemyFocus = true,
        actionCamInteractFocus = true,
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

local function EnsureRunDefaults(run)
    if run.active == nil then run.active = false end
    if run.valid == nil then run.valid = true end
    if run.failed == nil then run.failed = false end
    if run.levelGapBlocked == nil then run.levelGapBlocked = false end
    run.runId = run.runId or nil
    run.runName = run.runName or nil
    run.startTime = run.startTime or nil
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
    SoftcoreDB.sync = SoftcoreDB.sync or {}
    SoftcoreDB.sync.remoteSequences = SoftcoreDB.sync.remoteSequences or {}
    SoftcoreDB.sync.localSequence = SoftcoreDB.sync.localSequence or 0
    SoftcoreDB.sync.seenAuditIds = SoftcoreDB.sync.seenAuditIds or {}
    SoftcoreDB.sync.seenViolationIds = SoftcoreDB.sync.seenViolationIds or {}
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

local function ArchiveCurrentRun(db, reason)
    if not HasRunData(db.run, db.eventLog, db.violations) then
        return
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

    if db.run.active then
        participant = self:GetOrCreateParticipant(playerKey)
        participant.currentLevel = db.character.level
        participant.class = db.character.class
    end

    return {
        runId = db.run.runId,
        runName = db.run.runName,
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

function SC:IsRemoteStateCompatible(peer)
    local db = EnsureDatabase()

    if not peer or peer.unsynced then
        return false, "UNSYNCED"
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
                local localHash = self.GetRulesetHash and self:GetRulesetHash() or ""
                local matchingRun = remoteStatus and remoteStatus.runId == db.run.runId
                local matchingRules = remoteStatus and remoteStatus.rulesetHash and remoteStatus.rulesetHash == localHash

                if matchingRun and matchingRules and remoteStatus.participantStatus ~= "FAILED" and remoteStatus.participantStatus ~= "RUN_MISMATCH" then
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

function SC:ImportSharedViolationClear(violationId, clearedBy, clearedAt, clearReason)
    local db = EnsureDatabase()

    for _, violation in ipairs(db.violations) do
        if violation.id == violationId then
            if not violation.shared then
                return nil
            end

            if violation.status ~= "CLEARED" then
                violation.status = "CLEARED"
                violation.clearedBy = clearedBy
                violation.clearedAt = clearedAt or time()
                violation.clearReason = clearReason or "Cleared"

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

-- Violation types that represent party compatibility blockers, not clearable run events.
local BLOCKER_VIOLATION_TYPES = {
    unsyncedMembers = true,
    maxLevelGap = true,
    instanceWithUnsyncedPlayers = true,
    outsiderGrouping = true,
}

function SC:IsViolationClearable(violation)
    if not violation or violation.status == "CLEARED" then return false end
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

    ArchiveCurrentRun(db, "Starting new run")

    db.character = GetPlayerSnapshot()
    db.run.runId = runOptions.runId or self:CreateRunId()
    db.run.runName = runOptions.runName or "Softcore Run"
    db.run.active = true
    db.run.valid = true
    db.run.failed = false
    db.run.startTime = time()
    db.run.startLevel = db.character.level
    db.run.deathCount = 0
    db.run.warningCount = 0
    db.run.ruleset = runOptions.ruleset and CopyTable(runOptions.ruleset) or CreateDefaultRuleset()
    db.run.ruleset.achievementPreset = runOptions.preset or db.run.ruleset.achievementPreset or "CUSTOM"
    ApplyGroupingModeRules(db.run.ruleset)
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
    if self.ScanEquippedGear then
        self:ScanEquippedGear(true)
    end
    if db.run.ruleset and db.run.ruleset.firstPersonOnly ~= "ALLOWED" and db.run.ruleset.firstPersonOnly ~= nil and db.run.ruleset.firstPersonOnly ~= false then
        if self.SnapCameraToFirstPerson then
            self:SnapCameraToFirstPerson()
        end
    end
    if self.EnforceActionCamSettings then
        self:EnforceActionCamSettings()
    end
    self:RefreshParticipantsFromRoster()
    self:PlayUISound("RUN_STARTED")
    Print("run started.")

    if self.Sync_BroadcastStatus then
        self:Sync_BroadcastStatus("RUN_START")
    end

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
    db.run.startTime = nil
    db.run.deathCount = 0
    db.run.warningCount = 0
    db.run.ruleset = CreateDefaultRuleset()
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

    if self.RestoreActionCamSettings then
        self:RestoreActionCamSettings()
    end

    self:AddLog("RUN_RESET", "Local run reset.")
    Print("local run reset.")

    if self.Sync_BroadcastStatus then
        self:Sync_BroadcastStatus("RUN_RESET")
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
    Print("run: " .. tostring(db.run.runName or "none"))
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
        "instanceWithUnsyncedPlayers",
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
        Print(FormatTime(entry.time) .. " [" .. entry.kind .. "] " .. FormatPlayerLabel(entry.actorKey or entry.playerKey) .. ": " .. entry.message)
    end
end

function SC:PrintHelp()
    Print("Softcore commands:")
    Print("  /sc menu          open the menu")
    Print("  /sc minimap       toggle minimap button")
    Print("  /sc hud           toggle status HUD")
    Print("  /sc resync        re-sync state with party")
    Print("  /sc reset         stop the current run")
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
                self:Sync_BroadcastStatus("PARTICIPANT_ADDED")
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
                self:Sync_BroadcastStatus("PARTICIPANT_RETIRED")
            end
        end
    else
        self:PrintHelp()
    end
end

function SC:Initialize()
    BindCharacterDatabase()
    EnsureDatabase()
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
SC.frame:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName == ADDON_NAME then
        SC:Initialize()
    end
end)
