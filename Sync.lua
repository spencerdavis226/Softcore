-- Lightweight Blizzard addon-message sync for group run status.

local SC = Softcore

local PREFIX = "SOFTCORE"
local UNSYNCED_AFTER = 30
local HEARTBEAT_SECONDS = 10
local MAX_AUDIT_TEXT = 120
local MAX_MESSAGE_BYTES = 230
local MAX_CHUNK_DATA_BYTES = 180
local CHUNK_TIMEOUT_SECONDS = 30

SC.syncEnabled = true
SC.groupStatuses = SC.groupStatuses or {}

local syncFrame
local pendingChunks = {}

local function CleanupPendingChunks(now)
    now = now or time()
    for key, buffer in pairs(pendingChunks) do
        if now - (buffer.createdAt or now) > CHUNK_TIMEOUT_SECONDS then
            pendingChunks[key] = nil
        end
    end
end

local function PlayerKey(name, realm)
    if not realm or realm == "" then
        realm = GetRealmName()
    end

    return (name or "Unknown") .. "-" .. (realm or "Unknown")
end

local function SplitFullName(fullName)
    local name, realm = string.match(fullName or "", "^([^-]+)%-(.+)$")
    if name then
        return name, realm
    end

    return fullName, GetRealmName()
end

local function Escape(value)
    value = tostring(value or "")
    return string.gsub(value, "([^%w _%.%-])", function(character)
        return string.format("%%%02X", string.byte(character))
    end)
end

local function Unescape(value)
    value = tostring(value or "")
    return string.gsub(value, "%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
end

local function Encode(payload)
    local parts = {}

    for key, value in pairs(payload) do
        table.insert(parts, Escape(key) .. "=" .. Escape(value))
    end

    return table.concat(parts, ";")
end

local function Decode(message)
    local payload = {}

    for pair in string.gmatch(message or "", "([^;]+)") do
        local key, value = string.match(pair, "^([^=]+)=(.*)$")
        if key then
            payload[Unescape(key)] = Unescape(value)
        end
    end

    return payload
end

local function GetSyncChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end

    if IsInRaid() then
        return "RAID"
    end

    if IsInGroup() then
        return "PARTY"
    end

    return nil
end

local function DispatchAddonMessage(message, channel)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(PREFIX, message, channel)
    else
        _G.SendAddonMessage(PREFIX, message, channel)
    end
end

local function GetDB()
    SoftcoreDB = SoftcoreDB or {}
    SoftcoreDB.sync = SoftcoreDB.sync or {}
    SoftcoreDB.sync.remoteSequences = SoftcoreDB.sync.remoteSequences or {}
    SoftcoreDB.sync.localSequence = SoftcoreDB.sync.localSequence or 0
    SoftcoreDB.run = SoftcoreDB.run or {}
    SoftcoreDB.run.conflicts = SoftcoreDB.run.conflicts or {}
    return SoftcoreDB
end

local function NextSequence()
    local db = GetDB()
    db.sync.localSequence = (db.sync.localSequence or 0) + 1
    return db.sync.localSequence
end

local function AddMetadata(payload)
    local db = GetDB()
    local status = SC:GetPlayerStatus()

    payload.runId = payload.runId or status.runId
    payload.rulesetVersion = payload.rulesetVersion or status.rulesetVersion
    payload.rulesetHash = payload.rulesetHash or status.rulesetHash
    payload.addonVersion = SC.version
    payload.playerKey = status.playerKey
    payload.sequence = NextSequence()
    payload.sentAt = time()
    payload.partyStatus = status.partyStatus

    return payload
end

local function SendPayload(payload)
    local channel = GetSyncChannel()
    if not channel then
        -- Not in a group; message silently dropped. Callers that need delivery
        -- confirmation (e.g. proposals) should check IsInGroup() beforehand.
        return false
    end

    local message = Encode(AddMetadata(payload))
    if #message <= MAX_MESSAGE_BYTES then
        DispatchAddonMessage(message, channel)
        return true
    end

    local chunkId = tostring(time()) .. "-" .. tostring(math.random(100000, 999999))
    local total = math.ceil(#message / MAX_CHUNK_DATA_BYTES)
    for index = 1, total do
        local first = ((index - 1) * MAX_CHUNK_DATA_BYTES) + 1
        DispatchAddonMessage(
            "CHUNK|" .. chunkId .. "|" .. tostring(index) .. "|" .. tostring(total) .. "|" .. string.sub(message, first, first + MAX_CHUNK_DATA_BYTES - 1),
            channel
        )
    end

    return true
end

local function RegisterPrefix()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    else
        RegisterAddonMessagePrefix(PREFIX)
    end
end

local function GetUnitFullName(unit)
    local name, realm = UnitFullName(unit)

    if not name then
        return nil
    end

    return PlayerKey(name, realm)
end

local function GetRosterKeys()
    local keys = {}

    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            local key = GetUnitFullName("raid" .. index)
            if key then
                table.insert(keys, key)
            end
        end
    elseif IsInGroup() then
        table.insert(keys, PlayerKey(UnitFullName("player")))

        for index = 1, GetNumSubgroupMembers() do
            local key = GetUnitFullName("party" .. index)
            if key then
                table.insert(keys, key)
            end
        end
    end

    return keys
end

local function LocalPlayerKey()
    local name, realm = UnitFullName("player")
    return PlayerKey(name, realm)
end

local function Trunc(value, maxLen)
    value = tostring(value or "")
    if #value <= maxLen then
        return value
    end

    return string.sub(value, 1, maxLen - 2) .. ".."
end

local function CanShareAudit()
    local db = GetDB()
    return IsInGroup() and db.run and db.run.active and db.run.runId
end

local function CanImportSharedAudit(payload)
    local db = GetDB()
    if not db.run or not db.run.active or not db.run.runId then
        return false
    end

    return payload.runId and payload.runId == db.run.runId
end

local function RecordConflict(playerKey, conflictType, localValue, remoteValue, extra)
    local db = GetDB()
    local key = playerKey .. ":" .. conflictType

    db.run.conflicts[key] = {
        playerKey = playerKey,
        type = conflictType,
        localValue = localValue,
        remoteValue = remoteValue,
        active = true,
        detectedAt = time(),
    }

    if extra then
        for k, v in pairs(extra) do
            db.run.conflicts[key][k] = v
        end
    end
end

local function ClearConflict(playerKey, conflictType)
    local db = GetDB()
    local key = playerKey .. ":" .. conflictType

    if db.run.conflicts[key] then
        db.run.conflicts[key].active = false
        db.run.conflicts[key].clearedAt = time()
    end
end

local function ShouldIgnoreStale(payload, playerKey)
    local sequence = tonumber(payload.sequence)
    if not sequence then
        return false
    end

    local db = GetDB()
    local lastSequence = tonumber(db.sync.remoteSequences[playerKey] or 0)

    if sequence <= lastSequence then
        return true
    end

    db.sync.remoteSequences[playerKey] = sequence
    return false
end

local function GetDisplayStatus(status)
    if not status or status.unsynced then
        return "UNSYNCED"
    end

    if status.participantStatus == "FAILED" or status.failed or not status.valid then
        return "FAILED"
    end

    if status.participantStatus == "WARNING" or status.participantStatus == "VIOLATION" then
        return "VIOLATION"
    end

    if (tonumber(status.activeViolations) or 0) > 0 then
        return "VIOLATION"
    end

    if status.participantStatus == "PENDING" or status.participantStatus == "UNSYNCED" then
        return "UNSYNCED"
    end

    if status.participantStatus == "NOT_IN_RUN" then
        return "NOT_IN_RUN"
    end

    if status.participantStatus == "OUT_OF_PARTY" or status.participantStatus == "RETIRED" or status.participantStatus == "DECLINED" then
        return "INACTIVE"
    end

    if status.participantStatus == "RUN_MISMATCH" or status.participantStatus == "RULESET_MISMATCH" or status.participantStatus == "ADDON_VERSION_MISMATCH" then
        return status.participantStatus
    end

    if status.active and status.participantStatus ~= "INACTIVE" then
        return "VALID"
    end

    return "INACTIVE"
end

local function AddViolationSnapshot(payload)
    if not SC.GetActiveViolationSnapshot then
        return payload
    end

    local snapshot = SC:GetActiveViolationSnapshot(LocalPlayerKey())
    local latest = snapshot and snapshot.latest

    payload.activeViolations = snapshot and snapshot.count or 0

    if latest then
        payload.latestViolationId = latest.id
        payload.latestViolationType = latest.type
        payload.latestViolationDetail = latest.detail
        payload.latestViolationAt = latest.createdAt
    else
        payload.latestViolationId = ""
        payload.latestViolationType = ""
        payload.latestViolationDetail = ""
        payload.latestViolationAt = ""
    end

    return payload
end

function SC:Sync_GetDisplayStatus(status)
    return GetDisplayStatus(status)
end

function SC:Sync_MarkRoster()
    local now = time()
    local roster = GetRosterKeys()
    local seen = {}

    for _, key in ipairs(roster) do
        seen[key] = true

        if key ~= LocalPlayerKey() and not self.groupStatuses[key] then
            local name, realm = SplitFullName(key)
            self.groupStatuses[key] = {
                name = name,
                realm = realm,
                level = "?",
                warnings = 0,
                unsynced = true,
                lastSeen = 0,
                rosterSeen = now,
            }
        end
    end

    for key in pairs(self.groupStatuses) do
        if not seen[key] then
            self.groupStatuses[key] = nil
        end
    end

end

function SC:Sync_GetGroupRows()
    self:Sync_MarkRoster()

    local rows = {}
    local now = time()
    local playerKey = LocalPlayerKey()

    for _, key in ipairs(GetRosterKeys()) do
        if key ~= playerKey then
            local status = self.groupStatuses[key]

            if status and status.lastSeen and status.lastSeen > 0 and now - status.lastSeen <= UNSYNCED_AFTER then
                status.unsynced = false
            elseif status then
                status.unsynced = true
            end

            if status then
                table.insert(rows, status)
            end
        end
    end

    return rows
end

function SC:Sync_BuildPayload(reason)
    if not (self.db or SoftcoreDB) then
        return nil
    end

    local status = self:GetPlayerStatus()

    local payload = AddViolationSnapshot({
        type = "STATUS",
        reason = reason or "UPDATE",
        runName = status.runName,
        name = status.name,
        realm = status.realm,
        class = status.class,
        level = status.level,
        zone = status.zone,
        active = status.active and 1 or 0,
        valid = status.valid and 1 or 0,
        failed = status.failed and 1 or 0,
        deaths = status.deaths or 0,
        warnings = status.warnings or 0,
        participantStatus = status.participantStatus,
        version = status.version,
        addonVersion = status.version,
        rulesetVersion = status.rulesetVersion,
        rulesetHash = status.rulesetHash,
        timestamp = status.timestamp,
    })

    if reason == "RESYNC" and self.SerializeRuleset then
        local db = self.db or SoftcoreDB
        if db and db.run and db.run.ruleset then
            payload.ruleset = self:SerializeRuleset(db.run.ruleset)
        end
    end

    return payload
end

function SC:Sync_BroadcastStatus(reason)
    local payload = self:Sync_BuildPayload(reason)
    if not payload then
        return
    end

    SendPayload(payload)
end

function SC:Sync_SendHello()
    SendPayload({
        type = "HELLO",
    })
end

function SC:Sync_RequestFullState()
    SendPayload({
        type = "FULL_STATE_REQUEST",
    })
    self:Sync_BroadcastStatus("RESYNC")
end

function SC:Sync_SendFullState()
    local db = GetDB()
    local status = self:GetPlayerStatus()

    local payload = AddViolationSnapshot({
        type = "FULL_STATE_RESPONSE",
        name = status.name,
        realm = status.realm,
        class = status.class,
        level = status.level,
        zone = status.zone,
        active = db.run.active and 1 or 0,
        valid = db.run.valid and 1 or 0,
        failed = db.run.failed and 1 or 0,
        deaths = db.run.deathCount or 0,
        warnings = db.run.warningCount or 0,
        participantStatus = status.participantStatus,
        participantCount = #(db.run.participantOrder or {}),
        rulesetVersion = status.rulesetVersion,
        rulesetHash = status.rulesetHash,
    })
    if self.SerializeRuleset and db.run and db.run.ruleset then
        payload.ruleset = self:SerializeRuleset(db.run.ruleset)
    end
    SendPayload(payload)
end

function SC:Sync_SendProposal(proposalType, proposalId)
    SendPayload({
        type = proposalType,
        amendmentId = proposalId,
        proposalId = proposalId,
    })
end

function SC:Sync_SendAmendmentProposal(amendment)
    SendPayload({
        type = "AMENDMENT_PROPOSE",
        amendmentId = amendment.id,
        runId = amendment.runId,
        newRules = self.SerializePartialRules and self:SerializePartialRules(amendment.newRules) or "",
        previousRules = self.SerializePartialRules and self:SerializePartialRules(amendment.previousRules) or "",
        reason = amendment.reason or "",
        proposedBy = amendment.proposedBy or "",
        proposedAt = tostring(amendment.proposedAt or time()),
    })
end

function SC:Sync_SendAmendmentApplied(amendment)
    SendPayload({
        type = "AMENDMENT_APPLIED",
        amendmentId = amendment.id,
        runId = amendment.runId,
    })
end

function SC:Sync_SendAmendmentCancelled(amendment)
    SendPayload({
        type = "AMENDMENT_CANCELLED",
        amendmentId = amendment.id,
        runId = amendment.runId,
    })
end

function SC:Sync_BroadcastLog(entry)
    if not CanShareAudit() or not entry or not entry.id then
        return
    end

    SendPayload({
        type = "PARTY_LOG",
        auditId = entry.id,
        auditKind = entry.kind,
        auditMessage = Trunc(entry.message, MAX_AUDIT_TEXT),
        auditTime = entry.time,
        actorKey = entry.actorKey or entry.playerKey,
        auditPlayerKey = entry.playerKey,
        violationId = entry.violationId,
        violationType = entry.violationType,
        violationDetail = Trunc(entry.violationDetail, MAX_AUDIT_TEXT),
        violationPlayerKey = entry.violationPlayerKey,
        clearedBy = entry.clearedBy,
    })
end

function SC:Sync_BroadcastViolation(violation)
    if not CanShareAudit() or not violation or not violation.id then
        return
    end

    SendPayload({
        type = "PARTY_VIOLATION",
        violationId = violation.id,
        violationType = violation.type,
        violationDetail = Trunc(violation.detail, MAX_AUDIT_TEXT),
        violationSeverity = violation.severity,
        violationStatus = violation.status,
        violationPlayerKey = violation.playerKey,
        violationCreatedAt = violation.createdAt,
    })
end

function SC:Sync_BroadcastViolationClear(violation)
    if not CanShareAudit() or not violation or not violation.id then
        return
    end

    SendPayload({
        type = "PARTY_VIOLATION_CLEAR",
        violationId = violation.id,
        clearedBy = violation.clearedBy,
        clearedAt = violation.clearedAt,
        clearReason = Trunc(violation.clearReason, MAX_AUDIT_TEXT),
    })
end

function SC:Sync_SendRunProposal(proposal)
    local sent = SendPayload({
        type = "PROPOSAL",
        proposalId = proposal.proposalId,
        runId = proposal.runId,
        proposalRunId = proposal.runId,
        runName = proposal.runName,
        proposedAt = proposal.proposedAt,
        proposalKind = proposal.proposalType or "RUN",
        targetPlayerKey = proposal.targetPlayerKey,
        ruleset = self:SerializeRuleset(proposal.ruleset),
        rulesetHash = proposal.rulesetHash,
        proposalRulesetHash = proposal.rulesetHash,
    })
    if not sent then
        DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r Proposal created but not sent — you are not in a group.")
    end
end

function SC:Sync_SendProposalResponse(messageType, proposal)
    SendPayload({
        type = messageType,
        proposalId = proposal.proposalId,
        runId = proposal.runId,
        proposalRunId = proposal.runId,
        runName = proposal.runName,
        proposalRulesetHash = proposal.rulesetHash,
    })
end

function SC:Sync_SendRunProposalConfirmed(proposal)
    SendPayload({
        type = "PROPOSAL_CONFIRMED",
        proposalId = proposal.proposalId,
        runId = proposal.runId,
        runName = proposal.runName,
    })
end

function SC:Sync_SendProposalCancelled(proposal)
    SendPayload({
        type = "PROPOSAL_CANCELLED",
        proposalId = proposal.proposalId,
    })
end

function SC:Sync_HandleMessage(message, sender, isReassembled)
    if not isReassembled and string.sub(message or "", 1, 6) == "CHUNK|" then
        CleanupPendingChunks()

        local chunkId, chunkIndexText, chunkTotalText, chunkData = string.match(message, "^CHUNK|([^|]+)|([^|]+)|([^|]+)|(.*)$")
        local chunkIndex = tonumber(chunkIndexText)
        local chunkTotal = tonumber(chunkTotalText)
        if not chunkId or not chunkIndex or not chunkTotal or chunkTotal < 1 then
            return
        end

        local senderName, senderRealm = SplitFullName(sender)
        local key = PlayerKey(senderName, senderRealm)
        if key == LocalPlayerKey() then
            return
        end

        local bufferKey = key .. ":" .. chunkId
        local buffer = pendingChunks[bufferKey]
        if not buffer then
            buffer = {
                total = chunkTotal,
                chunks = {},
                received = 0,
                createdAt = time(),
            }
            pendingChunks[bufferKey] = buffer
        end

        if not buffer.chunks[chunkIndex] then
            buffer.chunks[chunkIndex] = chunkData or ""
            buffer.received = buffer.received + 1
        end

        if buffer.received >= buffer.total then
            local parts = {}
            for index = 1, buffer.total do
                if not buffer.chunks[index] then
                    return
                end
                parts[index] = buffer.chunks[index]
            end
            pendingChunks[bufferKey] = nil
            self:Sync_HandleMessage(table.concat(parts), sender, true)
        end

        return
    end

    local payload = Decode(message)

    local name = payload.name
    local realm = payload.realm

    if not name or name == "" then
        name, realm = SplitFullName(sender)
    end

    local key = PlayerKey(name, realm)
    if key == LocalPlayerKey() then
        return
    end

    if ShouldIgnoreStale(payload, key) then
        return
    end

    if payload.type == "FULL_STATE_REQUEST" then
        self:Sync_SendFullState()
        return
    end

    if payload.type == "HELLO" then
        self:Sync_BroadcastStatus("HELLO")
        return
    end

    if payload.type == "PROPOSAL" then
        if self.ReceiveRunProposal then
            self:ReceiveRunProposal(payload, key)
        end
        return
    end

    if payload.type == "PROPOSAL_ACCEPT" or payload.type == "PROPOSAL_DECLINE" then
        if self.ReceiveProposalResponse then
            self:ReceiveProposalResponse(payload, key)
        end
        return
    end

    if payload.type == "PROPOSAL_CONFIRMED" then
        if self.ReceiveRunConfirmed then
            self:ReceiveRunConfirmed(payload, key)
        end
        return
    end

    if payload.type == "PROPOSAL_CANCELLED" then
        if self.ReceiveProposalCancelled then
            self:ReceiveProposalCancelled(payload, key)
        end
        return
    end

    if payload.type == "PARTY_LOG" then
        if CanImportSharedAudit(payload) and self.ImportSharedLog then
            self:ImportSharedLog({
                id = payload.auditId,
                logEntryId = payload.auditId,
                runId = payload.runId,
                time = tonumber(payload.auditTime) or time(),
                kind = payload.auditKind,
                message = payload.auditMessage,
                playerKey = payload.auditPlayerKey or payload.playerKey or key,
                actorKey = payload.actorKey or payload.playerKey or key,
                violationId = payload.violationId,
                violationType = payload.violationType,
                violationDetail = payload.violationDetail,
                violationPlayerKey = payload.violationPlayerKey,
                clearedBy = payload.clearedBy,
                shared = true,
            })
        end
        return
    end

    if payload.type == "PARTY_VIOLATION" then
        if CanImportSharedAudit(payload) and self.ImportSharedViolation then
            self:ImportSharedViolation({
                id = payload.violationId,
                violationId = payload.violationId,
                runId = payload.runId,
                playerKey = payload.violationPlayerKey or payload.playerKey or key,
                type = payload.violationType,
                detail = payload.violationDetail,
                severity = payload.violationSeverity or "WARNING",
                status = payload.violationStatus or "ACTIVE",
                createdAt = tonumber(payload.violationCreatedAt) or time(),
                clearedAt = nil,
                clearedBy = nil,
                clearReason = nil,
                shared = true,
            })
        end
        return
    end

    if payload.type == "PARTY_VIOLATION_CLEAR" then
        if CanImportSharedAudit(payload) and self.ImportSharedViolationClear then
            self:ImportSharedViolationClear(
                payload.violationId,
                payload.clearedBy or payload.playerKey or key,
                tonumber(payload.clearedAt) or time(),
                payload.clearReason
            )
        end
        return
    end

    if payload.type == "AMENDMENT_PROPOSE" then
        if self.ReceiveRuleAmendmentProposal then
            self:ReceiveRuleAmendmentProposal(payload, key)
        end
        return
    end

    if payload.type == "AMENDMENT_ACCEPT" or payload.type == "AMENDMENT_DECLINE" then
        if self.ReceiveRuleAmendmentResponse then
            self:ReceiveRuleAmendmentResponse(payload, key)
        end
        return
    end

    if payload.type == "AMENDMENT_APPLIED" then
        if self.ReceiveRuleAmendmentApplied then
            self:ReceiveRuleAmendmentApplied(payload, key)
        end
        return
    end

    if payload.type == "AMENDMENT_CANCELLED" then
        if self.ReceiveRuleAmendmentCancelled then
            self:ReceiveRuleAmendmentCancelled(payload, key)
        end
        return
    end

    if payload.type ~= "STATUS" and payload.type ~= "FULL_STATE_RESPONSE" then
        return
    end

    local localRunId = (self.db and self.db.run and self.db.run.runId) or nil
    local remoteRunId = payload.runId
    local localRulesetHash = self.GetRulesetHash and self:GetRulesetHash() or ""
    local remoteRulesetHash = payload.rulesetHash
    local remoteRuleset = payload.ruleset and self.DeserializeRuleset and self:DeserializeRuleset(payload.ruleset) or nil

    local participantStatus = payload.participantStatus
    if localRunId and remoteRunId and localRunId ~= remoteRunId then
        participantStatus = "RUN_MISMATCH"
        RecordConflict(key, "RUN_MISMATCH", localRunId, remoteRunId)
    else
        ClearConflict(key, "RUN_MISMATCH")
    end

    if remoteRulesetHash and remoteRulesetHash ~= "" and localRulesetHash ~= "" and remoteRulesetHash ~= localRulesetHash then
        if participantStatus ~= "RUN_MISMATCH" then
            participantStatus = "RULESET_MISMATCH"
        end
        RecordConflict(key, "RULESET_MISMATCH", localRulesetHash, remoteRulesetHash, {
            remoteRuleset = remoteRuleset,
            remoteRulesetSerialized = payload.ruleset,
        })
    else
        ClearConflict(key, "RULESET_MISMATCH")
    end

    if payload.addonVersion and payload.addonVersion ~= SC.version then
        if participantStatus ~= "RUN_MISMATCH" and participantStatus ~= "RULESET_MISMATCH" then
            participantStatus = "ADDON_VERSION_MISMATCH"
        end
        RecordConflict(key, "ADDON_VERSION_MISMATCH", SC.version, payload.addonVersion)
    else
        ClearConflict(key, "ADDON_VERSION_MISMATCH")
    end

    self.groupStatuses[key] = {
        name = name,
        realm = realm,
        runId = payload.runId,
        playerKey = payload.playerKey or key,
        class = payload.class,
        level = tonumber(payload.level) or payload.level or "?",
        zone = payload.zone,
        active = payload.active == "1",
        valid = payload.valid == "1",
        failed = payload.failed == "1",
        deaths = tonumber(payload.deaths) or 0,
        warnings = tonumber(payload.warnings) or 0,
        activeViolations = tonumber(payload.activeViolations) or 0,
        latestViolation = {
            id = payload.latestViolationId,
            type = payload.latestViolationType,
            detail = payload.latestViolationDetail,
            createdAt = tonumber(payload.latestViolationAt) or nil,
            playerKey = payload.playerKey or key,
        },
        participantStatus = participantStatus,
        partyStatus = payload.partyStatus,
        version = payload.addonVersion or payload.version,
        addonVersion = payload.addonVersion or payload.version,
        rulesetVersion = tonumber(payload.rulesetVersion) or 0,
        rulesetHash = payload.rulesetHash,
        sequence = tonumber(payload.sequence) or 0,
        timestamp = tonumber(payload.timestamp) or 0,
        lastSeen = time(),
        unsynced = false,
    }

    -- Remote sync is advisory/display-only. A peer payload may update that peer's
    -- display record, but it must never fail, reset, or otherwise invalidate the
    -- local character's individual run state.
    if self.db and self.db.run and self.db.run.active and self.GetOrCreateParticipant then
        local run = self.db.run
        local ruleset = run.ruleset or {}

        if not (ruleset.groupingMode == "SOLO_SELF_FOUND" and not run.participants[key]) then
            local participant = self:GetOrCreateParticipant(key)
            participant.name = name
            participant.realm = realm
            participant.class = payload.class
            participant.currentLevel = tonumber(payload.level) or participant.currentLevel
            participant.joinedAt = participant.joinedAt or time()

            if participantStatus == "RUN_MISMATCH" or participantStatus == "RULESET_MISMATCH" or participantStatus == "ADDON_VERSION_MISMATCH" then
                participant.status = participantStatus
            elseif participantStatus == "FAILED" then
                participant.status = "FAILED"
                participant.failedAt = participant.failedAt or time()
                participant.failReason = participant.failReason or "Synced failure"
            elseif participant.status ~= "FAILED" and participant.status ~= "RETIRED" and participantStatus then
                participant.status = participantStatus
            end
        end
    end

    if self.HUD_Refresh then
        self:HUD_Refresh()
    end
end

function SC:Sync_Initialize()
    if syncFrame then
        return
    end

    RegisterPrefix()

    syncFrame = CreateFrame("Frame")
    syncFrame:RegisterEvent("CHAT_MSG_ADDON")
    syncFrame:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)
        if prefix == PREFIX and (channel == "PARTY" or channel == "RAID" or channel == "INSTANCE_CHAT") then
            SC:Sync_HandleMessage(message, sender)
        end
    end)

    self:Sync_MarkRoster()

    -- Give other clients a moment to register their prefix after reload/login.
    if C_Timer and C_Timer.After then
        C_Timer.After(2, function()
            SC:Sync_SendHello()
            SC:Sync_BroadcastStatus("LOGIN")
        end)
        C_Timer.After(UNSYNCED_AFTER, function()
            if SC.HUD_Refresh then
                SC:HUD_Refresh()
            end
        end)
        if C_Timer.NewTicker then
            self.syncTicker = C_Timer.NewTicker(5, function()
                CleanupPendingChunks()
                if SC.HUD_Refresh then
                    SC:HUD_Refresh()
                end
            end)
            self.syncBroadcastTicker = C_Timer.NewTicker(HEARTBEAT_SECONDS, function()
                SC:Sync_BroadcastStatus("HEARTBEAT")
            end)
        end
    else
        self:Sync_BroadcastStatus("LOGIN")
    end
end
