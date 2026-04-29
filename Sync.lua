-- Lightweight Blizzard addon-message sync for group run status.

local SC = Softcore

local PREFIX = "SOFTCORE"
local UNSYNCED_AFTER = 30
local HEARTBEAT_SECONDS = 10
local MAX_AUDIT_TEXT = 120
local MAX_MESSAGE_BYTES = 230
local MAX_CHUNK_DATA_BYTES = 150
local CHUNK_TIMEOUT_SECONDS = 30
local CONTROL_RETRY_SECONDS = 1
local CONTROL_RETRY_LIMIT = 3
local PROPOSAL_RESEND_SECONDS = 8
local PROPOSAL_RESEND_ATTEMPTS = 1
local CONTROL_REPEAT_ATTEMPTS = 1
local SEND_QUEUE_TICK_SECONDS = 0.25
local SEND_TOKEN_REFILL_SECONDS = 1.05
local SEND_TOKEN_MAX = 8

SC.syncEnabled = true
SC.groupStatuses = SC.groupStatuses or {}

local syncFrame
local pendingChunks = {}
local sendQueue = {}
local sendQueueActive = false
local sendTokens = SEND_TOKEN_MAX
local sendLastRefillAt
local syncSessionId = tostring(time()) .. "-" .. tostring(math.random(100000, 999999))
local GetDB

local SEND_RESULT_NAMES = {
    [0] = "Success",
    [1] = "InvalidPrefix",
    [2] = "InvalidMessage",
    [3] = "AddonMessageThrottle",
    [4] = "InvalidChatType",
    [5] = "NotInGroup",
    [6] = "TargetRequired",
    [7] = "InvalidChannel",
    [8] = "ChannelThrottle",
    [9] = "GeneralError",
    [10] = "NotInGuild",
    [11] = "AddOnMessageLockdown",
    [12] = "TargetOffline",
}

local function CleanupPendingChunks(now)
    now = now or time()
    local db = SoftcoreDB
    for key, buffer in pairs(pendingChunks) do
        if now - (buffer.createdAt or now) > CHUNK_TIMEOUT_SECONDS then
            pendingChunks[key] = nil
            if db and db.sync then
                db.sync.expiredChunkBuffers = (db.sync.expiredChunkBuffers or 0) + 1
                db.sync.lastExpiredChunk = {
                    bufferKey = key,
                    messageType = buffer.messageType,
                    received = buffer.received or 0,
                    total = buffer.total or 0,
                    expiredAt = now,
                }
            end
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

local function ResolvePayloadPlayerKey(payload, sender)
    local senderName, senderRealm = SplitFullName(sender)
    local senderKey = PlayerKey(senderName, senderRealm)
    local payloadKey = payload and payload.playerKey

    if payloadKey and payloadKey ~= "" then
        local payloadName = string.match(payloadKey, "^([^-]+)")
        if not payloadName or payloadName == senderName then
            return payloadKey, senderName, senderRealm
        end
    end

    return senderKey, senderName, senderRealm
end

local function Escape(value)
    if value == nil then
        value = ""
    else
        value = tostring(value)
    end
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

local function SerializeKeySet(keys)
    local parts = {}
    for key in pairs(keys or {}) do
        table.insert(parts, tostring(key))
    end
    table.sort(parts)
    return table.concat(parts, ";")
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

local function SendResultCode(result)
    if result == nil or result == true then
        return 0
    end

    if result == false then
        return 9
    end

    return tonumber(result) or 9
end

local function IsSuccessfulSend(resultCode)
    return resultCode == 0
end

local function GetMonotonicTime()
    if GetTime then
        return GetTime()
    end

    return time()
end

local function RefillSendTokens()
    local now = GetMonotonicTime()
    sendLastRefillAt = sendLastRefillAt or now

    local elapsed = now - sendLastRefillAt
    if elapsed < SEND_TOKEN_REFILL_SECONDS then
        return
    end

    local gained = math.floor(elapsed / SEND_TOKEN_REFILL_SECONDS)
    if gained > 0 then
        sendTokens = math.min(SEND_TOKEN_MAX, sendTokens + gained)
        sendLastRefillAt = sendLastRefillAt + (gained * SEND_TOKEN_REFILL_SECONDS)
    end
end

local function RecordSendResult(messageType, channel, byteCount, resultCode, chunkText)
    local db = GetDB()
    db.sync.lastSendResult = {
        type = messageType,
        channel = channel,
        bytes = byteCount,
        result = resultCode,
        resultName = SEND_RESULT_NAMES[resultCode] or tostring(resultCode),
        chunk = chunkText,
        time = time(),
    }

    if not IsSuccessfulSend(resultCode) then
        db.sync.sendFailureCount = (db.sync.sendFailureCount or 0) + 1
        db.sync.lastSendError = db.sync.lastSendResult
    end

    if SC.TraceDebug and (messageType ~= "STATUS" or not IsSuccessfulSend(resultCode)) then
        SC:TraceDebug("SYNC_SEND_RESULT", {
            messageType = messageType,
            channel = channel,
            bytes = byteCount,
            result = resultCode,
            resultName = SEND_RESULT_NAMES[resultCode] or tostring(resultCode),
            chunk = chunkText,
        })
    end
end

local function DispatchAddonMessageNow(message, channel, messageType, chunkText)
    local result

    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        local r1, r2 = C_ChatInfo.SendAddonMessage(PREFIX, message, channel)
        result = r2 ~= nil and r2 or r1
    else
        if _G.SendAddonMessage then
            result = _G.SendAddonMessage(PREFIX, message, channel)
        end
    end

    local resultCode = SendResultCode(result)
    RecordSendResult(messageType or "UNKNOWN", channel, #(message or ""), resultCode, chunkText)

    return IsSuccessfulSend(resultCode), resultCode
end

local function ShouldRetrySend(resultCode, messageType)
    return resultCode == 3 or resultCode == 8 or messageType ~= "STATUS"
end

local function GetMessagePriority(messageType)
    if messageType == "PARTY_VIOLATION_CLEAR" then return 1 end
    if messageType == "PARTY_VIOLATION" then return 2 end
    if messageType == "PROPOSAL_CONFIRMED" or messageType == "PROPOSAL_CANCELLED" then return 2 end
    if messageType == "PROPOSAL_ACCEPT" or messageType == "PROPOSAL_DECLINE" then return 3 end
    if messageType == "PARTY_LOG" then return 4 end
    if messageType == "PROPOSAL" then return 5 end
    if messageType == "STATUS" then return 6 end
    return 4
end

local function IsQueuedMessageStale(item)
    if not item then
        return true
    end

    local db = SoftcoreDB
    local proposalId = item.proposalId
    local proposal = proposalId and db and db.proposals and db.proposals[proposalId] or nil

    if item.messageType == "PROPOSAL" then
        return proposal and proposal.status ~= "PENDING"
    end

    if item.messageType == "PROPOSAL_ACCEPT" then
        return proposal and (proposal.status == "CANCELLED" or proposal.status == "DECLINED" or proposal.status == "EXPIRED")
    end

    return false
end

local function QueueSendItem(item)
    item.priority = item.priority or GetMessagePriority(item.messageType)

    local insertAt = #sendQueue + 1
    for index, queued in ipairs(sendQueue) do
        if (queued.priority or GetMessagePriority(queued.messageType)) > item.priority then
            insertAt = index
            break
        end
    end

    table.insert(sendQueue, insertAt, item)
end

local function ProcessSendQueue()
    RefillSendTokens()

    if #sendQueue > 0 and sendTokens > 0 then
        local item = table.remove(sendQueue, 1)
        if IsQueuedMessageStale(item) then
            local db = SoftcoreDB
            if db and db.sync then
                db.sync.sendQueueDepth = #sendQueue
                db.sync.staleSendDrops = (db.sync.staleSendDrops or 0) + 1
                db.sync.lastStaleSendDrop = {
                    type = item.messageType,
                    proposalId = item.proposalId,
                    runId = item.runId,
                    chunk = item.chunkText,
                    time = time(),
                }
            end
            if SC.TraceDebug and (not item.chunkText or string.match(item.chunkText, "^1/")) then
                SC:TraceDebug("SYNC_DROP_STALE_SEND", {
                    messageType = item.messageType,
                    proposalId = item.proposalId,
                    runId = item.runId,
                    chunk = item.chunkText,
                })
            end
        else
            sendTokens = sendTokens - 1

            local success, resultCode = DispatchAddonMessageNow(item.message, item.channel, item.messageType, item.chunkText)
            if not success then
                if resultCode == 3 or resultCode == 8 then
                    sendTokens = 0
                    sendLastRefillAt = GetMonotonicTime()
                end

                item.retryAttempt = (item.retryAttempt or 0) + 1
                if item.retryAttempt <= CONTROL_RETRY_LIMIT and ShouldRetrySend(resultCode, item.messageType) then
                    QueueSendItem(item)
                end
            end

            local db = SoftcoreDB
            if db and db.sync then
                db.sync.sendQueueDepth = #sendQueue
            end
        end
    end

    if #sendQueue == 0 then
        sendQueueActive = false
        return
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(SEND_QUEUE_TICK_SECONDS, ProcessSendQueue)
    else
        while #sendQueue > 0 do
            local item = table.remove(sendQueue, 1)
            DispatchAddonMessageNow(item.message, item.channel, item.messageType, item.chunkText)
        end
        sendQueueActive = false
    end
end

local function DispatchAddonMessage(message, channel, messageType, chunkText, meta)
    if not C_Timer or not C_Timer.After then
        return DispatchAddonMessageNow(message, channel, messageType, chunkText)
    end

    meta = meta or {}
    QueueSendItem({
        message = message,
        channel = channel,
        messageType = messageType or "UNKNOWN",
        chunkText = chunkText,
        proposalId = meta.proposalId,
        runId = meta.runId,
        violationId = meta.violationId,
        retryAttempt = 0,
    })

    local db = SoftcoreDB
    if db and db.sync then
        db.sync.sendQueueDepth = #sendQueue
        db.sync.lastQueuedSend = {
            type = messageType or "UNKNOWN",
            channel = channel,
            bytes = #(message or ""),
            chunk = chunkText,
            time = time(),
        }
    end

    if not sendQueueActive then
        sendQueueActive = true
        ProcessSendQueue()
    end

    return true, 0
end

function GetDB()
    SoftcoreDB = SoftcoreDB or {}
    SoftcoreDB.sync = SoftcoreDB.sync or {}
    SoftcoreDB.sync.remoteSequences = SoftcoreDB.sync.remoteSequences or {}
    SoftcoreDB.sync.localSequence = SoftcoreDB.sync.localSequence or 0
    SoftcoreDB.sync.lastSentAt = SoftcoreDB.sync.lastSentAt or nil
    SoftcoreDB.sync.lastReceivedAt = SoftcoreDB.sync.lastReceivedAt or nil
    SoftcoreDB.sync.rulesetRequests = SoftcoreDB.sync.rulesetRequests or {}
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
    payload.syncSessionId = syncSessionId
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

    local db = GetDB()
    local messageType = payload.type or "UNKNOWN"
    db.sync.lastSentAt = time()

    if SC.TraceDebug and messageType ~= "STATUS" then
        SC:TraceDebug("SYNC_QUEUE_PAYLOAD", {
            messageType = messageType,
            channel = channel,
            runId = payload.runId,
            violationId = payload.violationId,
            proposalId = payload.proposalId,
        })
    end

    local message = Encode(AddMetadata(payload))
    local meta = {
        proposalId = payload.proposalId,
        runId = payload.runId,
        violationId = payload.violationId,
    }
    if #message <= MAX_MESSAGE_BYTES then
        DispatchAddonMessage(message, channel, messageType, nil, meta)
        return true
    end

    local chunkId = tostring(time()) .. "-" .. tostring(math.random(100000, 999999))
    local total = math.ceil(#message / MAX_CHUNK_DATA_BYTES)
    db.sync.lastChunkedSend = {
        type = messageType,
        chunkId = chunkId,
        total = total,
        bytes = #message,
        time = time(),
    }
    for index = 1, total do
        local first = ((index - 1) * MAX_CHUNK_DATA_BYTES) + 1
        local chunkData = string.sub(message, first, first + MAX_CHUNK_DATA_BYTES - 1)
        local chunkText = tostring(index) .. "/" .. tostring(total)
        DispatchAddonMessage(
            "CHUNK|2|" .. syncSessionId .. "|" .. chunkId .. "|" .. tostring(messageType) .. "|" .. tostring(index) .. "|" .. tostring(total) .. "|" .. chunkData,
            channel,
            messageType,
            chunkText,
            meta
        )
    end

    return true
end

local function SendPayloadWithRepeats(payload, repeats)
    SendPayload(payload)

    if not C_Timer or not C_Timer.After then
        return
    end

    for attempt = 1, (repeats or 0) do
        C_Timer.After(CONTROL_RETRY_SECONDS * attempt, function()
            SendPayload(payload)
        end)
    end
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
        table.insert(keys, PlayerKey(UnitFullName("player")))
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
        return true
    end

    local db = GetDB()
    local remoteSessionId = payload.syncSessionId or ""
    local previous = db.sync.remoteSequences[playerKey]
    local lastSequence = 0
    local lastSessionId

    if type(previous) == "table" then
        lastSequence = tonumber(previous.sequence or 0) or 0
        lastSessionId = previous.sessionId
    else
        lastSequence = tonumber(previous or 0) or 0
    end

    if remoteSessionId ~= "" then
        if lastSessionId == remoteSessionId and sequence <= lastSequence then
            return true
        end

        db.sync.remoteSequences[playerKey] = {
            sequence = sequence,
            sessionId = remoteSessionId,
        }
        return false
    end

    if sequence <= lastSequence then
        return true
    end

    db.sync.remoteSequences[playerKey] = sequence
    return false
end

local function IsProposalControlMessage(messageType)
    return messageType == "PROPOSAL"
        or messageType == "PROPOSAL_ACCEPT"
        or messageType == "PROPOSAL_DECLINE"
        or messageType == "PROPOSAL_CONFIRMED"
        or messageType == "PROPOSAL_CANCELLED"
        or messageType == "FULL_STATE_REQUEST"
        or messageType == "FULL_STATE_RESPONSE"
        or messageType == "AMENDMENT_PROPOSE"
        or messageType == "AMENDMENT_ACCEPT"
        or messageType == "AMENDMENT_DECLINE"
        or messageType == "AMENDMENT_APPLIED"
        or messageType == "AMENDMENT_CANCELLED"
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
                playerKey = key,
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
        return false
    end

    return SendPayload(payload)
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
    SendPayloadWithRepeats({
        type = proposalType,
        amendmentId = proposalId,
        proposalId = proposalId,
    }, 2)
end

function SC:Sync_SendAmendmentProposal(amendment)
    SendPayloadWithRepeats({
        type = "AMENDMENT_PROPOSE",
        amendmentId = amendment.id,
        runId = amendment.runId,
        newRules = self.SerializePartialRules and self:SerializePartialRules(amendment.newRules) or "",
        previousRules = self.SerializePartialRules and self:SerializePartialRules(amendment.previousRules) or "",
        reason = amendment.reason or "",
        fullRulesProposal = amendment.fullRulesProposal and "1" or "0",
        proposedBy = amendment.proposedBy or "",
        proposedAt = tostring(amendment.proposedAt or time()),
    }, 2)
end

function SC:Sync_SendAmendmentApplied(amendment)
    SendPayloadWithRepeats({
        type = "AMENDMENT_APPLIED",
        amendmentId = amendment.id,
        runId = amendment.runId,
    }, 2)
end

function SC:Sync_SendAmendmentCancelled(amendment)
    SendPayloadWithRepeats({
        type = "AMENDMENT_CANCELLED",
        amendmentId = amendment.id,
        runId = amendment.runId,
    }, 2)
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
    local payload = {
        type = "PROPOSAL",
        proposalId = proposal.proposalId,
        runId = proposal.runId,
        proposalRunId = proposal.runId,
        runName = proposal.runName,
        proposedAt = proposal.proposedAt,
        proposalKind = proposal.proposalType or "RUN",
        targetPlayerKey = proposal.targetPlayerKey,
        preset = proposal.preset or "CUSTOM",
        ruleset = self:SerializeRuleset(proposal.ruleset),
        rulesetHash = proposal.rulesetHash,
        proposalRulesetHash = proposal.rulesetHash,
        voterKeys = SerializeKeySet(proposal.partyAtProposalTime),
    }
    local sent = SendPayload(payload)
    if C_Timer and C_Timer.After then
        for attempt = 1, PROPOSAL_RESEND_ATTEMPTS do
            C_Timer.After(PROPOSAL_RESEND_SECONDS * attempt, function()
                if proposal.status == "PENDING" then
                    SendPayload(payload)
                end
            end)
        end
    end
    if not sent then
        DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r Proposal created but not sent — you are not in a group.")
    end
end

function SC:Sync_SendProposalResponse(messageType, proposal)
    local payload = {
        type = messageType,
        proposalId = proposal.proposalId,
        runId = proposal.runId,
        proposalRunId = proposal.runId,
        runName = proposal.runName,
        proposalRulesetHash = proposal.rulesetHash,
    }

    SendPayload(payload)

    if not C_Timer or not C_Timer.After then
        return
    end

    for attempt = 1, CONTROL_REPEAT_ATTEMPTS do
        C_Timer.After(CONTROL_RETRY_SECONDS * attempt, function()
            if messageType == "PROPOSAL_ACCEPT" and proposal.status ~= "ACCEPTED" then
                return
            end
            if messageType == "PROPOSAL_DECLINE" and proposal.status ~= "DECLINED" then
                return
            end
            SendPayload(payload)
        end)
    end
end

function SC:Sync_SendRunProposalConfirmed(proposal)
    if not proposal then
        return false
    end

    local now = time()
    if proposal.confirmBroadcastedAt and now - proposal.confirmBroadcastedAt < 20 then
        return false
    end

    proposal.confirmBroadcastedAt = now
    SendPayloadWithRepeats({
        type = "PROPOSAL_CONFIRMED",
        proposalId = proposal.proposalId,
        runId = proposal.runId,
        runName = proposal.runName,
        preset = proposal.preset or "CUSTOM",
    }, CONTROL_REPEAT_ATTEMPTS)
    return true
end

function SC:Sync_SendProposalCancelled(proposal)
    SendPayloadWithRepeats({
        type = "PROPOSAL_CANCELLED",
        proposalId = proposal.proposalId,
    }, 2)
end

function SC:Sync_HandleMessage(message, sender, isReassembled)
    if not isReassembled and string.sub(message or "", 1, 6) == "CHUNK|" then
        CleanupPendingChunks()

        local chunkSessionId, chunkId, chunkMessageType, chunkIndexText, chunkTotalText, chunkData
        if string.sub(message or "", 1, 8) == "CHUNK|2|" then
            chunkSessionId, chunkId, chunkMessageType, chunkIndexText, chunkTotalText, chunkData = string.match(message, "^CHUNK|2|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|(.*)$")
        else
            chunkId, chunkIndexText, chunkTotalText, chunkData = string.match(message, "^CHUNK|([^|]+)|([^|]+)|([^|]+)|(.*)$")
            chunkSessionId = ""
            chunkMessageType = "UNKNOWN"
        end
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
                sessionId = chunkSessionId,
                messageType = chunkMessageType,
                chunks = {},
                received = 0,
                createdAt = time(),
            }
            pendingChunks[bufferKey] = buffer
        end

        if buffer.total ~= chunkTotal then
            pendingChunks[bufferKey] = nil
            return
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
            local db = GetDB()
            db.sync.lastReassembledChunk = {
                bufferKey = bufferKey,
                messageType = buffer.messageType,
                total = buffer.total,
                time = time(),
            }
            if self.TraceDebug then
                self:TraceDebug("SYNC_CHUNK_REASSEMBLED", {
                    sender = key,
                    messageType = buffer.messageType,
                    total = buffer.total,
                })
            end
            self:Sync_HandleMessage(table.concat(parts), sender, true)
        end

        return
    end

    local payload = Decode(message)

    local key, name, realm = ResolvePayloadPlayerKey(payload, sender)
    if key == LocalPlayerKey() then
        return
    end

    if not IsProposalControlMessage(payload.type) and ShouldIgnoreStale(payload, key) then
        return
    end

    local db = GetDB()
    db.sync.lastReceivedAt = time()

    if self.TraceDebug and (payload.type ~= "STATUS" or (tonumber(payload.activeViolations) or 0) > 0 or payload.participantStatus ~= "ACTIVE") then
        self:TraceDebug("SYNC_RECEIVED", {
            messageType = payload.type,
            sender = key,
            runId = payload.runId,
            participantStatus = payload.participantStatus,
            active = payload.active,
            activeViolations = payload.activeViolations,
            latestViolationId = payload.latestViolationId,
            proposalId = payload.proposalId,
            violationId = payload.violationId,
        })
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
            local ownerKey = payload.violationPlayerKey or payload.playerKey or key
            if ownerKey ~= key then
                return
            end
            self:ImportSharedViolation({
                id = payload.violationId,
                violationId = payload.violationId,
                runId = payload.runId,
                playerKey = ownerKey,
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
    local localActive = self.db and self.db.run and self.db.run.active
    local remoteRunId = payload.runId
    local localRulesetHash = self.GetRulesetHash and self:GetRulesetHash() or ""
    local remoteRulesetHash = payload.rulesetHash
    local remoteRuleset = payload.ruleset and self.DeserializeRuleset and self:DeserializeRuleset(payload.ruleset) or nil
    local remoteActive = payload.active == "1"

    local participantStatus = payload.participantStatus
    local compareRunState = localActive and remoteActive and participantStatus ~= "NOT_IN_RUN" and participantStatus ~= "PENDING" and participantStatus ~= "UNSYNCED"

    if compareRunState and localRunId and remoteRunId and localRunId ~= remoteRunId then
        participantStatus = "RUN_MISMATCH"
        RecordConflict(key, "RUN_MISMATCH", localRunId, remoteRunId)
    else
        ClearConflict(key, "RUN_MISMATCH")
    end

    if compareRunState and remoteRulesetHash and remoteRulesetHash ~= "" and localRulesetHash ~= "" and remoteRulesetHash ~= localRulesetHash then
        if participantStatus ~= "RUN_MISMATCH" then
            participantStatus = "RULESET_MISMATCH"
        end
        RecordConflict(key, "RULESET_MISMATCH", localRulesetHash, remoteRulesetHash, {
            remoteRuleset = remoteRuleset,
            remoteRulesetSerialized = payload.ruleset,
        })
        if not remoteRuleset then
            db.sync.rulesetRequests = db.sync.rulesetRequests or {}
            local lastRequest = tonumber(db.sync.rulesetRequests[key] or 0) or 0
            if time() - lastRequest > 20 then
                db.sync.rulesetRequests[key] = time()
                if self.Sync_RequestFullState then
                    self:Sync_RequestFullState()
                end
            end
        end
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
        playerKey = key,
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
            playerKey = key,
        },
        participantStatus = participantStatus,
        partyStatus = payload.partyStatus,
        version = payload.addonVersion or payload.version,
        addonVersion = payload.addonVersion or payload.version,
        rulesetVersion = tonumber(payload.rulesetVersion) or 0,
        rulesetHash = payload.rulesetHash,
        remoteRuleset = remoteRuleset,
        sequence = tonumber(payload.sequence) or 0,
        timestamp = tonumber(payload.timestamp) or 0,
        lastSeen = time(),
        unsynced = false,
    }

    if remoteActive and (tonumber(payload.activeViolations) or 0) > 0 and self.ImportSharedViolationSnapshot then
        self:ImportSharedViolationSnapshot({
            id = payload.latestViolationId,
            runId = payload.runId,
            playerKey = key,
            type = payload.latestViolationType,
            detail = payload.latestViolationDetail,
            severity = "WARNING",
            createdAt = tonumber(payload.latestViolationAt) or time(),
        })
    end

    if payload.active == "1" and payload.runId and self.ConfirmAcceptedProposalFromStatus then
        self:ConfirmAcceptedProposalFromStatus(key, payload.runId, payload.rulesetHash)
    end
    if payload.active == "1" and payload.runId and self.ConfirmPendingProposalPeerActive then
        self:ConfirmPendingProposalPeerActive(key, payload.runId, payload.rulesetHash)
    end

    if self.RefreshParticipantsFromRoster then
        self:RefreshParticipantsFromRoster()
    end

    -- Remote sync is advisory/display-only. A peer payload may update that peer's
    -- display record, but it must never fail, reset, or otherwise invalidate the
    -- local character's individual run state or bypass run join rules.
    if self.db and self.db.run and self.db.run.active then
        local run = self.db.run
        local participant = run.participants and run.participants[key]

        if participant then
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
    if self.MasterUI_Refresh then
        self:MasterUI_Refresh()
    end
end

function SC:PrintSyncDebug()
    local db = GetDB()
    local localKey = LocalPlayerKey()
    local hash = self.GetRulesetHash and self:GetRulesetHash() or "unknown"

    local function Print(message)
        DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r " .. tostring(message))
    end

    Print("sync debug:")
    Print("  local: " .. tostring(localKey))
    Print("  run: " .. tostring(db.run and db.run.runId or "none") .. " / rules " .. tostring(hash) .. " / active " .. tostring(db.run and db.run.active == true))

    local roster = GetRosterKeys()
    if #roster == 0 then
        Print("  roster: not grouped")
    else
        Print("  roster:")
        for _, key in ipairs(roster) do
            Print("    " .. tostring(key))
        end
    end

    local proposal = self.GetPendingProposal and self:GetPendingProposal() or nil
    if proposal then
        local accepted = {}
        for playerKey, value in pairs(proposal.acceptedBy or {}) do
            if value then table.insert(accepted, playerKey) end
        end
        Print("  pending proposal: " .. tostring(proposal.proposalId) .. " / " .. tostring(proposal.status) .. " / " .. tostring(proposal.proposalType) .. " / by " .. tostring(proposal.proposedBy))
        Print("    run: " .. tostring(proposal.runId) .. " / rules " .. tostring(proposal.rulesetHash))
        Print("    accepted: " .. (#accepted > 0 and table.concat(accepted, ", ") or "none"))
    else
        Print("  pending proposal: none")
    end

    Print("  last sent: " .. (db.sync.lastSentAt and (tostring(time() - db.sync.lastSentAt) .. "s ago") or "never"))
    Print("  last received: " .. (db.sync.lastReceivedAt and (tostring(time() - db.sync.lastReceivedAt) .. "s ago") or "never"))
    if db.sync.lastSendResult then
        Print("  last send result: " .. tostring(db.sync.lastSendResult.type) .. " " .. tostring(db.sync.lastSendResult.resultName) .. " " .. tostring(db.sync.lastSendResult.bytes) .. "b")
    end
    Print("  send queue: " .. tostring(db.sync.sendQueueDepth or #sendQueue))
    Print("  stale send drops: " .. tostring(db.sync.staleSendDrops or 0))

    local pendingCount = 0
    for _, buffer in pairs(pendingChunks) do
        pendingCount = pendingCount + 1
        Print("  chunk pending: " .. tostring(buffer.messageType or "?") .. " " .. tostring(buffer.received or 0) .. "/" .. tostring(buffer.total or 0))
    end
    if pendingCount == 0 then
        Print("  chunk pending: none")
    end
    Print("  chunk expired: " .. tostring(db.sync.expiredChunkBuffers or 0))

    if self.groupStatuses then
        local anyPeer = false
        for peerKey, peer in pairs(self.groupStatuses) do
            anyPeer = true
            Print("  peer: " .. tostring(peerKey) .. " run " .. tostring(peer.runId or "none") .. " / rules " .. tostring(peer.rulesetHash or "?") .. " / " .. tostring(peer.participantStatus or "?") .. " / seen " .. tostring(peer.lastSeen and (time() - peer.lastSeen) or "never") .. "s")
        end
        if not anyPeer then
            Print("  peers: none")
        end
    end

    local foundConflict = false
    for _, conflict in pairs(db.run and db.run.conflicts or {}) do
        if conflict.active then
            foundConflict = true
            Print("  conflict: " .. tostring(conflict.playerKey) .. " " .. tostring(conflict.type) .. " local " .. tostring(conflict.localValue) .. " / remote " .. tostring(conflict.remoteValue))
            if conflict.type == "RULESET_MISMATCH" and conflict.remoteRuleset and self.DescribeRulesetDifferences then
                for _, diff in ipairs(self:DescribeRulesetDifferences(db.run.ruleset, conflict.remoteRuleset)) do
                    Print("    " .. diff.ruleName .. ": local " .. tostring(diff.localValue) .. " / remote " .. tostring(diff.remoteValue))
                end
            end
        end
    end
    if not foundConflict then
        Print("  conflicts: none")
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
        if prefix == PREFIX and (channel == "PARTY" or channel == "INSTANCE_CHAT") then
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
