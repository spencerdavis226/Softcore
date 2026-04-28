-- Proposal state and slash fallbacks for group run governance.

local SC = Softcore

local SEPARATOR = "\031"
local PAIR_SEPARATOR = "\030"
local PROPOSAL_TIMEOUT_SECONDS = 30 * 60
local ACCEPT_RETRY_SECONDS = 5
local ACCEPT_RETRY_LIMIT = 6

local function FriendlyGroupingMode(value)
    if value == "SOLO_SELF_FOUND" then
        return "Solo"
    end

    return "Group"
end

local function GetRulesetSyncOrder(self)
    if self.GetRulesetSyncOrder then
        return self:GetRulesetSyncOrder()
    end

    return {
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
        "consumables",
        "instancedPvP",
        "maxDeaths",
        "maxDeathsValue",
    }
end

local function FriendlyAllowed(value)
    if value == "ALLOWED" or value == "LOG_ONLY" then
        return "Allowed"
    end

    return "Disallowed"
end

local function FriendlyGear(value)
    if value == "ALLOWED" then return "Any gear" end
    if value == "WHITE_GRAY_ONLY" then return "White/gray only" end
    if value == "GREEN_OR_LOWER" or value == "COMMON_OR_UNCOMMON" then return "Green or lower" end
    if value == "BLUE_OR_LOWER" then return "Blue or lower" end
    if value == "EPIC_OR_LOWER" then return "Epic or lower" end
    if value == "NO_EPICS" then return "Blue or lower" end
    return tostring(value)
end

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r " .. tostring(message))
end

local function GetDB()
    local db = SC.db or SoftcoreDB or {}
    SoftcoreDB = db
    db.proposals = db.proposals or {}
    return db
end

local function Escape(value)
    value = tostring(value or "")
    value = string.gsub(value, "%%", "%%%%")
    value = string.gsub(value, SEPARATOR, "%%u")
    value = string.gsub(value, PAIR_SEPARATOR, "%%p")
    value = string.gsub(value, "=", "%%e")
    return value
end

local function Unescape(value)
    value = tostring(value or "")
    value = string.gsub(value, "%%e", "=")
    value = string.gsub(value, "%%p", PAIR_SEPARATOR)
    value = string.gsub(value, "%%u", SEPARATOR)
    value = string.gsub(value, "%%%%", "%%")
    return value
end

-- Returns a table of all current party member keys including the local player.
local function GetCurrentPartyKeys()
    local keys = {}
    local name, realm = UnitFullName("player")
    if not realm or realm == "" then
        realm = GetRealmName()
    end
    keys[(name or "Unknown") .. "-" .. (realm or "Unknown")] = true

    if IsInRaid() then
        return keys
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local n, r = UnitFullName("party" .. i)
            if n then
                if not r or r == "" then r = GetRealmName() end
                keys[n .. "-" .. r] = true
            end
        end
    end

    return keys
end

local function IsGroupProposal(proposal)
    if not proposal then
        return false
    end

    return proposal.proposalType == "RUN"
        or proposal.proposalType == "SYNC_RUN"
        or proposal.proposalType == "ADD_PARTICIPANT"
end

local function ActivateAcceptedProposalParticipants(self, proposal)
    if not proposal or not proposal.acceptedBy then
        return
    end

    local db = GetDB()
    if not db.run or not db.run.active then
        return
    end

    local localKey = self:GetPlayerKey()
    local currentParty = GetCurrentPartyKeys()
    for playerKey, accepted in pairs(proposal.acceptedBy) do
        if accepted and playerKey ~= localKey and currentParty[playerKey] then
            local participant = self:GetOrCreateParticipant(playerKey)
            if participant.status ~= "FAILED" and participant.status ~= "RETIRED" then
                participant.status = "ACTIVE"
                participant.joinedAt = participant.joinedAt or time()
                participant.leftAt = nil
            end
        end
    end
end

function SC:SerializeRuleset(ruleset)
    local parts = {}
    local normalized = self.NormalizeRulesetForSync and self:NormalizeRulesetForSync(ruleset or {}) or (ruleset or {})

    for _, key in ipairs(GetRulesetSyncOrder(self)) do
        if normalized[key] ~= nil then
            table.insert(parts, Escape(key) .. "=" .. Escape(normalized[key]))
        end
    end

    return table.concat(parts, PAIR_SEPARATOR)
end

function SC:SerializePartialRules(rules)
    local parts = {}
    for key, value in pairs(rules or {}) do
        table.insert(parts, Escape(key) .. "=" .. Escape(value))
    end
    return table.concat(parts, PAIR_SEPARATOR)
end

function SC:DeserializePartialRules(serialized)
    local rules = {}
    for pair in string.gmatch(serialized or "", "([^" .. PAIR_SEPARATOR .. "]+)") do
        local key, value = string.match(pair, "^([^=]+)=(.*)$")
        if key then
            key = Unescape(key)
            value = Unescape(value)
            if value == "true" then
                rules[key] = true
            elseif value == "false" then
                rules[key] = false
            elseif (key == "maxLevelGapValue" or key == "maxDeathsValue") and tonumber(value) then
                rules[key] = tonumber(value)
            else
                rules[key] = value
            end
        end
    end
    return rules
end

function SC:DeserializeRuleset(serialized)
    local ruleset = self:GetDefaultRuleset()

    for pair in string.gmatch(serialized or "", "([^" .. PAIR_SEPARATOR .. "]+)") do
        local key, value = string.match(pair, "^([^=]+)=(.*)$")
        if key then
            key = Unescape(key)
            value = Unescape(value)
            if value == "true" then
                ruleset[key] = true
            elseif value == "false" then
                ruleset[key] = false
            elseif tonumber(value) and (key == "maxLevelGapValue" or key == "maxDeathsValue") then
                ruleset[key] = tonumber(value)
            else
                ruleset[key] = value
            end
        end
    end

    if self.NormalizeRulesetForSync then
        ruleset = self:NormalizeRulesetForSync(ruleset)
    elseif self.ApplyGroupingMode then
        self:ApplyGroupingMode(ruleset)
    end

    return ruleset
end

function SC:ComputeRulesetHash(ruleset)
    local oldRuleset
    local db = self.db or SoftcoreDB

    if self.NormalizeRulesetForSync then
        ruleset = self:NormalizeRulesetForSync(ruleset or {})
    end

    if db and db.run then
        oldRuleset = db.run.ruleset
        db.run.ruleset = ruleset
    end

    local hash = self.GetRulesetHash and self:GetRulesetHash() or ""

    if db and db.run then
        db.run.ruleset = oldRuleset
    end

    return hash
end

local function ProposalSummary(proposal)
    return "Death: Permanent"
        .. "\nGrouping: " .. FriendlyGroupingMode(proposal.ruleset.groupingMode)
        .. "\nAH: " .. FriendlyAllowed(proposal.ruleset.auctionHouse)
        .. "  Mail: " .. FriendlyAllowed(proposal.ruleset.mailbox)
        .. "  Trade: " .. FriendlyAllowed(proposal.ruleset.trade)
        .. "\nGear: " .. FriendlyGear(proposal.ruleset.gearQuality)
        .. "  Heirlooms: " .. FriendlyAllowed(proposal.ruleset.heirlooms)
end

local function PrintRuleDifferences(self, localRuleset, remoteRuleset)
    if not self.DescribeRulesetDifferences then
        return
    end

    local differences = self:DescribeRulesetDifferences(localRuleset, remoteRuleset)
    if #differences == 0 then
        return
    end

    Print("rule differences:")
    for _, diff in ipairs(differences) do
        Print("  " .. diff.ruleName .. ": local " .. tostring(diff.localValue) .. " / proposal " .. tostring(diff.remoteValue))
    end
end

function SC:StoreProposal(proposal)
    local db = GetDB()
    db.proposals[proposal.proposalId] = proposal
    db.pendingProposalId = proposal.proposalId
    return proposal
end

function SC:GetPendingProposal()
    local db = GetDB()
    if db.pendingProposalId then
        local proposal = db.proposals[db.pendingProposalId]
        if not proposal then
            db.pendingProposalId = nil
            return nil
        end

        if proposal.status ~= "PENDING" and proposal.status ~= "ACCEPTED" then
            db.pendingProposalId = nil
            return nil
        end

        if IsInRaid() and IsGroupProposal(proposal) then
            proposal.status = "EXPIRED"
            db.pendingProposalId = nil
            self:AddLog("PROPOSAL_EXPIRED", "Expired group proposal because raid groups are local-only.", {
                proposalId = proposal.proposalId,
                runId = proposal.runId,
            })
            return nil
        end

        local createdAt = tonumber(proposal.proposedAt) or time()
        if time() - createdAt > PROPOSAL_TIMEOUT_SECONDS then
            proposal.status = "EXPIRED"
            db.pendingProposalId = nil
            self:AddLog("PROPOSAL_EXPIRED", "Expired stale proposal: " .. tostring(proposal.runName), {
                proposalId = proposal.proposalId,
                runId = proposal.runId,
            })
            return nil
        end
        return proposal
    end
    return nil
end

function SC:ClearStalePendingProposal()
    self:GetPendingProposal()
end

function SC:CanProposeRun()
    local db = self.db or SoftcoreDB
    local participant = db and db.run and db.run.participants and db.run.participants[self:GetPlayerKey()]

    if not IsInGroup() or IsInRaid() then
        return true
    end

    if UnitIsGroupLeader and UnitIsGroupLeader("player") then
        return true
    end

    return participant and (participant.status == "ACTIVE" or participant.status == "WARNING")
end

-- Returns true if all members still in the party (from partyAtProposalTime) have accepted.
-- Members who have left the party since the proposal was created are ignored — they can't
-- accept anyway and shouldn't block the run from starting.
function SC:CheckAllProposalMembersAccepted(proposal)
    if proposal.targetPlayerKey then
        local currentParty = GetCurrentPartyKeys()
        return not currentParty[proposal.targetPlayerKey] or proposal.acceptedBy[proposal.targetPlayerKey] == true
    end

    local party = proposal.partyAtProposalTime
    if not party or not next(party) then
        return true
    end

    local currentParty = GetCurrentPartyKeys()
    for key in pairs(party) do
        if currentParty[key] and not proposal.acceptedBy[key] then
            return false
        end
    end

    return true
end

-- Called on GROUP_ROSTER_UPDATE. If the local player is the proposer and a member who
-- hadn't accepted has now left, re-evaluate whether the proposal can be confirmed.
function SC:CheckPendingProposalOnRosterUpdate()
    local db = GetDB()
    local proposal = self:GetPendingProposal()
    if not proposal or proposal.status ~= "PENDING" then return end
    if proposal.proposedBy ~= self:GetPlayerKey() then return end
    if proposal.proposalType ~= "RUN" and proposal.proposalType ~= "SYNC_RUN" and proposal.proposalType ~= "ADD_PARTICIPANT" then return end

    if self:CheckAllProposalMembersAccepted(proposal) then
        proposal.status = "CONFIRMED"
        db.pendingProposalId = nil

        if proposal.proposalType == "RUN" and (not db.run or not db.run.active) then
            self:StartRun({
                runId = proposal.runId,
                runName = proposal.runName,
                ruleset = proposal.ruleset,
                preset = proposal.preset,
            })
        end

        if self.Sync_SendRunProposalConfirmed then
            self:Sync_SendRunProposalConfirmed(proposal)
        end

        if proposal.proposalType == "SYNC_RUN" then
            Print("all present members accepted. Run sync confirmed.")
        elseif proposal.proposalType == "ADD_PARTICIPANT" then
            Print("all present members accepted. Party invite confirmed.")
        else
            Print("all present members accepted. Run started.")
        end
    end
end

function SC:ConfirmPendingProposalPeerActive(playerKey, runId, rulesetHash)
    local db = GetDB()
    local proposal = self:GetPendingProposal()
    if not proposal or proposal.status ~= "PENDING" then return false end
    if proposal.proposedBy ~= self:GetPlayerKey() then return false end
    if proposal.proposalType ~= "RUN" and proposal.proposalType ~= "SYNC_RUN" and proposal.proposalType ~= "ADD_PARTICIPANT" then return false end
    if not playerKey or not runId or proposal.runId ~= runId then return false end
    if rulesetHash and rulesetHash ~= "" and proposal.rulesetHash and proposal.rulesetHash ~= rulesetHash then return false end

    proposal.acceptedBy[playerKey] = true

    if not self:CheckAllProposalMembersAccepted(proposal) then
        return false
    end

    proposal.status = "CONFIRMED"
    db.pendingProposalId = nil

    if proposal.proposalType == "RUN" and not db.run.active then
        self:StartRun({
            runId = proposal.runId,
            runName = proposal.runName,
            ruleset = proposal.ruleset,
            preset = proposal.preset,
        })
    end

    if proposal.proposalType == "RUN" or proposal.proposalType == "ADD_PARTICIPANT" then
        ActivateAcceptedProposalParticipants(self, proposal)
    end

    if self.Sync_SendRunProposalConfirmed then
        self:Sync_SendRunProposalConfirmed(proposal)
    end

    self:AddLog("PROPOSAL_CONFIRMED", "Proposal confirmed from active peer status: " .. tostring(playerKey), {
        proposalId = proposal.proposalId,
        playerKey = playerKey,
        runId = proposal.runId,
    })

    if proposal.proposalType == "SYNC_RUN" then
        Print("run sync confirmed from party status.")
    elseif proposal.proposalType == "ADD_PARTICIPANT" then
        Print("party invite confirmed from party status.")
    else
        Print("run started from party acceptance.")
    end

    if self.MasterUI_Refresh then self:MasterUI_Refresh() end
    if self.HUD_Refresh then self:HUD_Refresh() end
    return true
end

function SC:CreateRunProposal(runName, ruleset, proposalType, targetPlayerKey, runId)
    if IsInRaid() then
        Print("raid groups are not supported for run proposals.")
        return nil
    end

    if not self:CanProposeRun() then
        Print("only the party leader or an active participant can propose a run.")
        return nil
    end

    local db = GetDB()
    local existing = self:GetPendingProposal()
    if existing and (existing.status == "PENDING" or existing.status == "ACCEPTED") then
        Print("finish or cancel the current proposal before creating another.")
        return nil
    end

    if (proposalType == "RUN" or not proposalType) and db.run and db.run.active then
        Print("cannot propose a new run while an active run is in progress. Use /sc reset to stop it first.")
        return nil
    end
    local proposalRunId = runId or self:CreateRunId()
    local proposalRuleset = self:CopyTable(ruleset or self:GetDefaultRuleset())
    if self.NormalizeRulesetForSync then
        proposalRuleset = self:NormalizeRulesetForSync(proposalRuleset)
    elseif self.ApplyGroupingMode then
        self:ApplyGroupingMode(proposalRuleset)
    end
    local proposal = {
        proposalId = self:CreateProposalId(),
        runId = proposalRunId,
        runName = runName or "Softcore Run",
        proposedBy = self:GetPlayerKey(),
        proposedAt = time(),
        ruleset = proposalRuleset,
        rulesetHash = self:ComputeRulesetHash(proposalRuleset),
        preset = proposalRuleset.achievementPreset or proposalRuleset.preset or "CUSTOM",
        acceptedBy = {},
        declinedBy = {},
        status = "PENDING",
        proposalType = proposalType or "RUN",
        targetPlayerKey = targetPlayerKey,
        partyAtProposalTime = GetCurrentPartyKeys(),
    }

    proposal.acceptedBy[proposal.proposedBy] = true
    db.proposals[proposal.proposalId] = proposal
    db.pendingProposalId = proposal.proposalId
    self:AddLog("PROPOSAL_CREATED", "Run proposal created: " .. proposal.runName, {
        proposalId = proposal.proposalId,
        runId = proposal.runId,
    })

    if self.Sync_SendRunProposal then
        self:Sync_SendRunProposal(proposal)
    end

    return proposal
end

function SC:CreateRunSyncProposal()
    local db = GetDB()
    if not IsInGroup() or IsInRaid() then
        Print(IsInRaid() and "raid groups are not supported for run sync proposals." or "run sync proposals require a party.")
        return nil
    end
    if not db.run or not db.run.active then
        Print("start a run before proposing party sync.")
        return nil
    end

    return self:CreateRunProposal(db.run.runName or "Softcore Run", db.run.ruleset, "SYNC_RUN", nil, db.run.runId)
end

function SC:CreateRunInviteProposal()
    local db = GetDB()
    if not IsInGroup() or IsInRaid() then
        Print(IsInRaid() and "raid groups are not supported for party invites." or "party invites require a party.")
        return nil
    end
    if not db.run or not db.run.active then
        Print("start a run before inviting party members.")
        return nil
    end

    return self:CreateRunProposal(db.run.runName or "Softcore Run", db.run.ruleset, "ADD_PARTICIPANT", nil, db.run.runId)
end

function SC:ApplyRunSyncProposal(proposal, sourceKey)
    local db = GetDB()
    if not proposal or proposal.proposalType ~= "SYNC_RUN" then
        return false
    end
    if not db.run or not db.run.active then
        Print("cannot sync: no active local run.")
        return false
    end

    local localHash = self.GetRulesetHash and self:GetRulesetHash() or ""
    if localHash ~= "" and proposal.rulesetHash and localHash ~= proposal.rulesetHash then
        Print("cannot sync: local rules do not match the proposal.")
        PrintRuleDifferences(self, db.run.ruleset, proposal.ruleset)
        return false
    end

    local oldRunId = db.run.runId
    db.run.runId = proposal.runId
    db.run.runName = proposal.runName or db.run.runName
    if self.Achievements_OnRunSynced then
        self:Achievements_OnRunSynced(oldRunId, db.run.runId)
    end

    local participant = self:GetOrCreateParticipant(self:GetPlayerKey())
    participant.status = "ACTIVE"
    participant.joinedAt = participant.joinedAt or time()

    for _, conflict in pairs(db.run.conflicts or {}) do
        if conflict.type == "RUN_MISMATCH" then
            conflict.active = false
            conflict.clearedAt = time()
        end
    end

    self:AddLog("RUN_SYNCED", "Run synced with party proposal from " .. tostring(sourceKey or proposal.proposedBy or "?") .. ".", {
        proposalId = proposal.proposalId,
        oldRunId = oldRunId,
        runId = proposal.runId,
    })

    if self.Sync_BroadcastStatus then
        self:Sync_BroadcastStatus("RUN_SYNCED")
    end
    if self.HUD_Refresh then self:HUD_Refresh() end
    if self.MasterUI_Refresh then self:MasterUI_Refresh() end

    return true
end

function SC:ReceiveRunProposal(payload, proposerKey)
    local db = GetDB()
    local ruleset = self:DeserializeRuleset(payload.ruleset)
    local computedHash = self:ComputeRulesetHash(ruleset)

    if payload.addonVersion and payload.addonVersion ~= self.version then
        self:AddLog("PROPOSAL_VERSION_MISMATCH", "Proposal from " .. proposerKey .. " uses addon version " .. tostring(payload.addonVersion) .. "; local version is " .. tostring(self.version) .. ".")
    end

    if payload.proposalRulesetHash and payload.proposalRulesetHash ~= computedHash then
        self:AddLog("PROPOSAL_HASH_MISMATCH", "Proposal ruleset hash mismatch detected for " .. tostring(proposerKey) .. ".")
    end

    local proposal = {
        proposalId = payload.proposalId,
        runId = payload.proposalRunId,
        runName = payload.runName or "Softcore Run",
        proposedBy = proposerKey,
        proposedAt = tonumber(payload.proposedAt) or time(),
        ruleset = ruleset,
        rulesetHash = payload.proposalRulesetHash or computedHash,
        preset = payload.preset or "CUSTOM",
        acceptedBy = {},
        declinedBy = {},
        status = "PENDING",
        proposalType = payload.proposalKind or "RUN",
        targetPlayerKey = payload.targetPlayerKey,
        partyAtProposalTime = GetCurrentPartyKeys(),
    }
    proposal.acceptedBy[proposerKey] = true

    if proposal.targetPlayerKey and proposal.targetPlayerKey ~= self:GetPlayerKey() then
        db.proposals[proposal.proposalId] = proposal
        self:AddLog("PROPOSAL_OBSERVED", "Observed proposal for " .. proposal.targetPlayerKey, {
            proposalId = proposal.proposalId,
            targetPlayerKey = proposal.targetPlayerKey,
        })
        return
    end

    local existing = self:GetPendingProposal()
    if existing and existing.proposalId ~= proposal.proposalId then
        db.proposals[proposal.proposalId] = proposal
        proposal.status = "DECLINED"
        self:AddLog("PROPOSAL_BUSY_DECLINED", "Ignored proposal from " .. proposerKey .. " because another proposal is pending.", {
            oldProposalId = existing.proposalId,
            newProposalId = proposal.proposalId,
        })
        if self.Sync_SendProposalResponse then
            self:Sync_SendProposalResponse("PROPOSAL_DECLINE", proposal)
        end
        Print("proposal from " .. tostring(proposerKey) .. " ignored: another proposal is pending.")
        return
    end

    local sameExisting = db.proposals[proposal.proposalId]
    if sameExisting then
        sameExisting.runName = proposal.runName
        sameExisting.ruleset = proposal.ruleset
        sameExisting.rulesetHash = proposal.rulesetHash
        sameExisting.preset = proposal.preset
        sameExisting.partyAtProposalTime = sameExisting.partyAtProposalTime or proposal.partyAtProposalTime
        sameExisting.acceptedBy = sameExisting.acceptedBy or {}
        sameExisting.acceptedBy[proposerKey] = true
        if (sameExisting.status == "PENDING" or sameExisting.status == "ACCEPTED") and db.pendingProposalId ~= sameExisting.proposalId then
            db.pendingProposalId = sameExisting.proposalId
        end
        if self.MasterUI_Refresh then self:MasterUI_Refresh() end
        return
    end

    self:StoreProposal(proposal)
    if self.PlayUISound then self:PlayUISound("PROPOSAL_RECEIVED") end
    if self.OpenMasterWindow then
        self:OpenMasterWindow("RUN")
    else
        Print("proposal received: " .. proposal.runName .. ". Use /sc proposal to review.")
    end
end

function SC:AcceptPendingProposal()
    local db = GetDB()
    local proposal = self:GetPendingProposal()
    local playerKey = self:GetPlayerKey()

    if not proposal then
        Print("no pending proposal.")
        return
    end

    if proposal.proposedBy == playerKey then
        Print("you already proposed this. Waiting for party responses.")
        return
    end

    if proposal.status == "ACCEPTED" and proposal.acceptedBy and proposal.acceptedBy[playerKey] then
        if self.Sync_SendProposalResponse then
            self:Sync_SendProposalResponse("PROPOSAL_ACCEPT", proposal)
        end
        if self.Sync_BroadcastStatus then
            self:Sync_BroadcastStatus("PROPOSAL_ACCEPT_RETRY")
        end
        Print("already accepted. Waiting for confirmation.")
        return
    end

    if db.run and db.run.active and proposal.proposalType == "RUN" and db.run.runId ~= proposal.runId then
        Print("cannot accept: you already have an active run with a different runId. Use /sc reset only if you intend to leave it.")
        Print("Use Propose Sync if both active runs should align.")
        return
    end

    local localHash = self.GetRulesetHash and self:GetRulesetHash() or ""
    if db.run and db.run.active and db.run.runId == proposal.runId and localHash ~= "" and localHash ~= proposal.rulesetHash then
        Print("cannot accept: ruleset mismatch detected.")
        PrintRuleDifferences(self, db.run.ruleset, proposal.ruleset)
        return
    end
    if proposal.proposalType == "SYNC_RUN" then
        if not db.run or not db.run.active then
            Print("cannot accept sync: no active local run.")
            return
        end
        if localHash ~= "" and proposal.rulesetHash and localHash ~= proposal.rulesetHash then
            Print("cannot accept sync: ruleset mismatch detected.")
            PrintRuleDifferences(self, db.run.ruleset, proposal.ruleset)
            return
        end
    end
    if proposal.proposalType == "ADD_PARTICIPANT" then
        if db.run and db.run.active and db.run.runId ~= proposal.runId then
            Print("cannot accept invite: you already have an active run with a different runId. Use Propose Sync if both runs should align.")
            return
        end
        if db.run and db.run.active and localHash ~= "" and proposal.rulesetHash and localHash ~= proposal.rulesetHash then
            Print("cannot accept invite: ruleset mismatch detected.")
            PrintRuleDifferences(self, db.run.ruleset, proposal.ruleset)
            return
        end
    end

    proposal.acceptedBy[playerKey] = true
    proposal.status = "ACCEPTED"
    proposal.acceptRetryCount = 0
    db.acceptedRunId = proposal.runId
    db.acceptedRulesetHash = proposal.rulesetHash
    db.pendingProposalId = proposal.proposalId

    if proposal.proposalType == "SYNC_RUN" then
        self:ApplyRunSyncProposal(proposal, proposal.proposedBy)
    elseif proposal.proposalType == "ADD_PARTICIPANT" then
        if not db.run.active then
            self:StartRun({
                runId = proposal.runId,
                runName = proposal.runName,
                ruleset = proposal.ruleset,
                preset = proposal.preset,
            })
        else
            local participant = self:GetOrCreateParticipant(playerKey)
            participant.status = "ACTIVE"
            participant.joinedAt = participant.joinedAt or time()
        end
    elseif not db.run.active then
        self:StartRun({
            runId = proposal.runId,
            runName = proposal.runName,
            ruleset = proposal.ruleset,
            preset = proposal.preset,
        })
    else
        local participant = self:GetOrCreateParticipant(playerKey)
        participant.status = "ACTIVE"
        participant.joinedAt = participant.joinedAt or time()
    end

    db.proposals = db.proposals or {}
    db.proposals[proposal.proposalId] = proposal
    db.pendingProposalId = proposal.proposalId
    db.acceptedRunId = proposal.runId
    db.acceptedRulesetHash = proposal.rulesetHash

    self:AddLog("PROPOSAL_ACCEPTED", "Accepted proposal: " .. proposal.runName, {
        proposalId = proposal.proposalId,
        runId = proposal.runId,
    })

    if self.Sync_SendProposalResponse then
        self:Sync_SendProposalResponse("PROPOSAL_ACCEPT", proposal)
    end

    if self.Sync_BroadcastStatus then
        self:Sync_BroadcastStatus("PROPOSAL_ACCEPTED")
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(ACCEPT_RETRY_SECONDS, function()
            if SC.RetryAcceptedProposal then
                SC:RetryAcceptedProposal(proposal.proposalId)
            end
        end)
    end

    Print("accepted proposal: " .. proposal.runName .. ". Waiting for confirmation.")
    if self.MasterUI_Refresh then self:MasterUI_Refresh() end
    if self.HUD_Refresh then self:HUD_Refresh() end
end

function SC:RetryAcceptedProposal(proposalId)
    local db = GetDB()
    local proposal = db.proposals and db.proposals[proposalId]
    if not proposal or proposal.status ~= "ACCEPTED" then
        return
    end
    if time() - (tonumber(proposal.proposedAt) or time()) > PROPOSAL_TIMEOUT_SECONDS then
        proposal.status = "EXPIRED"
        if db.pendingProposalId == proposal.proposalId then
            db.pendingProposalId = nil
        end
        if self.MasterUI_Refresh then self:MasterUI_Refresh() end
        return
    end

    proposal.acceptRetryCount = (proposal.acceptRetryCount or 0) + 1
    if proposal.acceptRetryCount > ACCEPT_RETRY_LIMIT then
        return
    end

    if self.Sync_SendProposalResponse then
        self:Sync_SendProposalResponse("PROPOSAL_ACCEPT", proposal)
    end
    if self.Sync_BroadcastStatus then
        self:Sync_BroadcastStatus("PROPOSAL_ACCEPT_RETRY")
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(ACCEPT_RETRY_SECONDS, function()
            if SC.RetryAcceptedProposal then
                SC:RetryAcceptedProposal(proposalId)
            end
        end)
    end
end

function SC:CancelPendingProposal()
    local db = GetDB()
    local proposal = self:GetPendingProposal()

    if not proposal then
        Print("no pending proposal.")
        return
    end

    if proposal.proposedBy ~= self:GetPlayerKey() then
        Print("only the proposer can cancel this proposal.")
        return
    end

    proposal.status = "CANCELLED"
    db.pendingProposalId = nil

    self:AddLog("PROPOSAL_CANCELLED", "Cancelled proposal: " .. tostring(proposal.runName), {
        proposalId = proposal.proposalId,
        runId = proposal.runId,
    })

    if self.Sync_SendProposalCancelled then
        self:Sync_SendProposalCancelled(proposal)
    end

    Print("proposal cancelled: " .. tostring(proposal.runName) .. ".")
    if self.MasterUI_Refresh then self:MasterUI_Refresh() end
    if self.HUD_Refresh then self:HUD_Refresh() end
end

function SC:DeclinePendingProposal()
    local db = GetDB()
    local proposal = self:GetPendingProposal()
    local playerKey = self:GetPlayerKey()

    if not proposal then
        Print("no pending proposal.")
        return
    end

    proposal.declinedBy[playerKey] = true
    proposal.status = "DECLINED"
    db.pendingProposalId = nil

    self:AddLog("PROPOSAL_DECLINED", "Declined proposal: " .. proposal.runName, {
        proposalId = proposal.proposalId,
        runId = proposal.runId,
    })

    if self.Sync_SendProposalResponse then
        self:Sync_SendProposalResponse("PROPOSAL_DECLINE", proposal)
    end

    Print("declined proposal: " .. proposal.runName)
    if self.MasterUI_Refresh then self:MasterUI_Refresh() end
    if self.HUD_Refresh then self:HUD_Refresh() end
end

function SC:ReceiveProposalResponse(payload, playerKey)
    local db = GetDB()
    local proposal = db.proposals[payload.proposalId]

    if not proposal then
        self:AddLog("PROPOSAL_RESPONSE_UNKNOWN", "Received response for unknown proposal.", {
            proposalId = payload.proposalId,
            playerKey = playerKey,
        })
        return
    end
    if time() - (tonumber(proposal.proposedAt) or time()) > PROPOSAL_TIMEOUT_SECONDS then
        proposal.status = "EXPIRED"
        if db.pendingProposalId == proposal.proposalId then
            db.pendingProposalId = nil
        end
        return
    end

    if payload.type == "PROPOSAL_ACCEPT" then
        if proposal.status == "CANCELLED" or proposal.status == "DECLINED" or proposal.status == "EXPIRED" then
            return
        end

        proposal.acceptedBy[playerKey] = true
        if not proposal.acceptLoggedBy then proposal.acceptLoggedBy = {} end
        if not proposal.acceptLoggedBy[playerKey] then
            proposal.acceptLoggedBy[playerKey] = true
            self:AddLog("PROPOSAL_ACCEPT_SYNC", playerKey .. " accepted proposal " .. proposal.runName, {
                proposalId = proposal.proposalId,
                playerKey = playerKey,
            })
        end

        if proposal.proposedBy == self:GetPlayerKey() and proposal.status == "CONFIRMED" then
            if self.Sync_SendRunProposalConfirmed then
                self:Sync_SendRunProposalConfirmed(proposal)
            end
            return
        end

        -- Only the proposer drives the "all accepted" check and starts the run.
        -- Guard against DECLINED/CANCELLED → CONFIRMED: only act from PENDING state.
        if proposal.proposedBy == self:GetPlayerKey() and (proposal.proposalType == "RUN" or proposal.proposalType == "SYNC_RUN" or proposal.proposalType == "ADD_PARTICIPANT") and proposal.status == "PENDING" then
            if self:CheckAllProposalMembersAccepted(proposal) then
                proposal.status = "CONFIRMED"
                db.pendingProposalId = nil

                if proposal.proposalType == "RUN" and not db.run.active then
                    self:StartRun({
                        runId = proposal.runId,
                        runName = proposal.runName,
                        ruleset = proposal.ruleset,
                        preset = proposal.preset,
                    })
                end

                if proposal.proposalType == "RUN" or proposal.proposalType == "ADD_PARTICIPANT" then
                    ActivateAcceptedProposalParticipants(self, proposal)
                end

                if self.Sync_SendRunProposalConfirmed then
                    self:Sync_SendRunProposalConfirmed(proposal)
                end

                if proposal.proposalType == "SYNC_RUN" then
                    Print("all members accepted. Run sync confirmed.")
                elseif proposal.proposalType == "ADD_PARTICIPANT" then
                    Print("all members accepted. Party invite confirmed.")
                else
                    Print("all members accepted. Run started.")
                end
            end
        end

        if self.MasterUI_Refresh then
            self:MasterUI_Refresh()
        end

    elseif payload.type == "PROPOSAL_DECLINE" then
        if proposal.status == "CANCELLED" or proposal.status == "DECLINED" or proposal.status == "EXPIRED" then
            return
        end

        proposal.declinedBy[playerKey] = true
        self:AddLog("PROPOSAL_DECLINE_SYNC", playerKey .. " declined proposal " .. proposal.runName, {
            proposalId = proposal.proposalId,
            playerKey = playerKey,
        })

        -- Proposer cancels the proposal when any member declines.
        if proposal.proposedBy == self:GetPlayerKey() and (proposal.proposalType == "RUN" or proposal.proposalType == "SYNC_RUN" or proposal.proposalType == "ADD_PARTICIPANT") and proposal.status == "PENDING" then
            proposal.status = "DECLINED"
            db.pendingProposalId = nil

            Print(playerKey .. " declined. Proposal cancelled.")

            if self.Sync_SendProposalCancelled then
                self:Sync_SendProposalCancelled(proposal)
            end

            if self.HUD_Refresh then
                self:HUD_Refresh()
            end
            if self.MasterUI_Refresh then
                self:MasterUI_Refresh()
            end
        end
    end
end

-- Called when a non-proposer receives PROPOSAL_CONFIRMED from the proposer.
function SC:ReceiveRunConfirmed(payload, confirmerKey)
    local db = GetDB()
    local proposal = db.proposals[payload.proposalId]
    if not proposal then return end
    if confirmerKey ~= proposal.proposedBy then return end
    if payload.runId and proposal.runId and payload.runId ~= proposal.runId then return end
    if proposal.status ~= "PENDING" and proposal.status ~= "ACCEPTED" then return end
    if time() - (tonumber(proposal.proposedAt) or time()) > PROPOSAL_TIMEOUT_SECONDS then
        proposal.status = "EXPIRED"
        if db.pendingProposalId == proposal.proposalId then
            db.pendingProposalId = nil
        end
        return
    end

    local playerKey = self:GetPlayerKey()

    -- Only act if we already accepted this proposal and are not the proposer.
    if not proposal.acceptedBy[playerKey] then return end
    if proposal.proposedBy == playerKey then return end

    proposal.status = "CONFIRMED"
    if db.pendingProposalId == proposal.proposalId then
        db.pendingProposalId = nil
    end

    if proposal.proposalType == "SYNC_RUN" then
        self:ApplyRunSyncProposal(proposal, confirmerKey)
    elseif proposal.proposalType == "ADD_PARTICIPANT" then
        if not db.run.active then
            self:StartRun({
                runId = proposal.runId,
                runName = proposal.runName,
                ruleset = proposal.ruleset,
                preset = proposal.preset,
            })
        else
            local participant = self:GetOrCreateParticipant(playerKey)
            participant.status = "ACTIVE"
            participant.joinedAt = participant.joinedAt or time()
        end
    elseif not db.run.active then
        self:StartRun({
            runId = proposal.runId,
            runName = proposal.runName,
            ruleset = proposal.ruleset,
            preset = proposal.preset,
        })
    end

    self:AddLog("PROPOSAL_CONFIRMED", "Run confirmed by " .. confirmerKey .. ": " .. proposal.runName, {
        proposalId = proposal.proposalId,
    })

    if proposal.proposalType == "SYNC_RUN" then
        Print("run synced: all members accepted.")
    elseif proposal.proposalType == "ADD_PARTICIPANT" then
        Print("joined party run: all members accepted.")
    else
        Print("run started: all members accepted.")
    end

    if self.HUD_Refresh then
        self:HUD_Refresh()
    end
    if self.MasterUI_Refresh then
        self:MasterUI_Refresh()
    end
end

function SC:ConfirmAcceptedProposalFromStatus(proposerKey, runId, rulesetHash)
    local db = GetDB()
    local proposal = self:GetPendingProposal()
    if not proposal or proposal.status ~= "ACCEPTED" then return false end
    if proposal.proposedBy ~= proposerKey then return false end
    if not runId or proposal.runId ~= runId then return false end
    if rulesetHash and rulesetHash ~= "" and proposal.rulesetHash and proposal.rulesetHash ~= rulesetHash then return false end
    if time() - (tonumber(proposal.proposedAt) or time()) > PROPOSAL_TIMEOUT_SECONDS then
        proposal.status = "EXPIRED"
        if db.pendingProposalId == proposal.proposalId then
            db.pendingProposalId = nil
        end
        return false
    end

    local playerKey = self:GetPlayerKey()
    if not proposal.acceptedBy[playerKey] then return false end

    proposal.status = "CONFIRMED"
    if db.pendingProposalId == proposal.proposalId then
        db.pendingProposalId = nil
    end

    if proposal.proposalType == "SYNC_RUN" then
        self:ApplyRunSyncProposal(proposal, proposerKey)
    elseif proposal.proposalType == "ADD_PARTICIPANT" then
        if not db.run.active then
            self:StartRun({
                runId = proposal.runId,
                runName = proposal.runName,
                ruleset = proposal.ruleset,
                preset = proposal.preset,
            })
        else
            local participant = self:GetOrCreateParticipant(playerKey)
            participant.status = "ACTIVE"
            participant.joinedAt = participant.joinedAt or time()
        end
    elseif not db.run.active then
        self:StartRun({
            runId = proposal.runId,
            runName = proposal.runName,
            ruleset = proposal.ruleset,
            preset = proposal.preset,
        })
    end

    self:AddLog("PROPOSAL_CONFIRMED", "Run confirmed from proposer status: " .. tostring(proposal.runName), {
        proposalId = proposal.proposalId,
        runId = proposal.runId,
    })

    Print("run started: proposer status confirmed accepted run.")
    if self.HUD_Refresh then self:HUD_Refresh() end
    if self.MasterUI_Refresh then self:MasterUI_Refresh() end
    return true
end

-- Called when a player receives PROPOSAL_CANCELLED from the proposer.
function SC:ReceiveProposalCancelled(payload, cancellerKey)
    local db = GetDB()
    local proposal = db.proposals[payload.proposalId]
    if not proposal then return end

    proposal.status = "CANCELLED"
    if db.pendingProposalId == proposal.proposalId then
        db.pendingProposalId = nil
    end

    self:AddLog("PROPOSAL_CANCELLED", "Proposal cancelled by " .. cancellerKey .. ": " .. tostring(proposal.runName), {
        proposalId = proposal.proposalId,
    })

    Print("proposal cancelled: " .. tostring(proposal.runName) .. ".")

    if self.HUD_Refresh then
        self:HUD_Refresh()
    end
    if self.MasterUI_Refresh then
        self:MasterUI_Refresh()
    end
end

function SC:ShowPendingProposal()
    local proposal = self:GetPendingProposal()

    if not proposal then
        Print("no pending proposal.")
        return
    end

    if self.OpenMasterWindow then
        self:OpenMasterWindow("RUN")
    else
        Print("proposal: " .. proposal.runName .. " from " .. tostring(proposal.proposedBy))
        Print(ProposalSummary(proposal))
    end
end

function SC:ProposeRunFromSlash()
    if self.OpenMasterWindow then
        self:OpenMasterWindow("RUN")
    else
        self:CreateRunProposal("Softcore Run", self:GetDefaultRuleset(), "RUN")
        Print("proposed run.")
    end
end

function SC:ProposeAddParticipant(playerKey)
    if not playerKey or playerKey == "" then
        Print("usage: /sc propose-add Player-Realm")
        return
    end

    local db = GetDB()
    if not db.run or not db.run.active then
        Print("no active run to add a participant to.")
        return
    end

    if not db.run.ruleset.allowReplacementCharacters and db.run.participants[playerKey] and db.run.participants[playerKey].status == "FAILED" then
        Print("replacement characters are not allowed by the current rules.")
        return
    end

    local proposal = self:CreateRunProposal(db.run.runName or "Softcore Run", db.run.ruleset, "ADD_PARTICIPANT", playerKey, db.run.runId)
    if proposal then
        Print("proposed adding participant: " .. playerKey)
    end
end
