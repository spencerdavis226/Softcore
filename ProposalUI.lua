-- Proposal state, popup, and slash fallbacks for group run governance.

local SC = Softcore

local SEPARATOR = "\031"
local PAIR_SEPARATOR = "\030"

local RULE_KEYS = {
    "death",
    "groupingMode",
    "failedMemberBlocksParty",
    "allowLateJoin",
    "allowReplacementCharacters",
    "requireLeaderApprovalForJoin",
    "auctionHouse",
    "mailbox",
    "trade",
    "bank",
    "warbandBank",
    "guildBank",
    "mounts",
    "flying",
    "gearQuality",
    "heirlooms",
    "outsiderGrouping",
    "unsyncedMembers",
    "maxLevelGap",
    "maxLevelGapValue",
    "dungeonRepeat",
    "instanceWithUnsyncedPlayers",
}

local function FriendlyGroupingMode(value)
    if value == "SOLO_SELF_FOUND" then
        return "Solo / self-found only"
    end

    return "Group allowed with synced Softcore players"
end

local function FriendlySeverity(value)
    if value == "ALLOWED" then return "Allowed" end
    if value == "LOG_ONLY" then return "Log only" end
    if value == "WARNING" then return "Warning" end
    if value == "FATAL" then return "Fatal" end
    return tostring(value)
end

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r " .. tostring(message))
end

local function GetDB()
    SoftcoreDB = SoftcoreDB or {}
    SoftcoreDB.proposals = SoftcoreDB.proposals or {}
    return SoftcoreDB
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

function SC:SerializeRuleset(ruleset)
    local parts = {}

    for _, key in ipairs(RULE_KEYS) do
        if ruleset[key] ~= nil then
            table.insert(parts, Escape(key) .. "=" .. Escape(ruleset[key]))
        end
    end

    return table.concat(parts, PAIR_SEPARATOR)
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
            elseif tonumber(value) and key == "maxLevelGapValue" then
                ruleset[key] = tonumber(value)
            else
                ruleset[key] = value
            end
        end
    end

    if self.ApplyGroupingMode then
        self:ApplyGroupingMode(ruleset)
    end

    return ruleset
end

function SC:ComputeRulesetHash(ruleset)
    local oldRuleset
    local db = self.db or SoftcoreDB

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
    return "Death: Permanent per character"
        .. "\nGrouping: " .. FriendlyGroupingMode(proposal.ruleset.groupingMode)
        .. "\nUnsynced group member: " .. FriendlySeverity(proposal.ruleset.unsyncedMembers)
        .. "\nAH: " .. FriendlySeverity(proposal.ruleset.auctionHouse)
        .. "  Mail: " .. FriendlySeverity(proposal.ruleset.mailbox)
        .. "  Trade: " .. FriendlySeverity(proposal.ruleset.trade)
        .. "\nGear: " .. tostring(proposal.ruleset.gearQuality)
        .. "  Heirlooms: " .. FriendlySeverity(proposal.ruleset.heirlooms)
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
        return db.proposals[db.pendingProposalId]
    end
    return nil
end

function SC:CanProposeRun()
    local db = self.db or SoftcoreDB
    local participant = db and db.run and db.run.participants and db.run.participants[self:GetPlayerKey()]

    if not IsInGroup() then
        return true
    end

    if UnitIsGroupLeader and UnitIsGroupLeader("player") then
        return true
    end

    return participant and (participant.status == "ACTIVE" or participant.status == "WARNING")
end

function SC:CreateRunProposal(runName, ruleset, proposalType, targetPlayerKey, runId)
    if not self:CanProposeRun() then
        Print("only the party leader or an active participant can propose a run.")
        return nil
    end

    local db = GetDB()
    local proposalRunId = runId or self:CreateRunId()
    local proposalRuleset = self:CopyTable(ruleset or self:GetDefaultRuleset())
    if self.ApplyGroupingMode then
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
        acceptedBy = {},
        declinedBy = {},
        status = "PENDING",
        proposalType = proposalType or "RUN",
        targetPlayerKey = targetPlayerKey,
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

function SC:ReceiveRunProposal(payload, proposerKey)
    local db = GetDB()
    local ruleset = self:DeserializeRuleset(payload.ruleset)
    local computedHash = self:ComputeRulesetHash(ruleset)

    if payload.addonVersion and payload.addonVersion ~= self.version then
        Print("proposal from " .. proposerKey .. " uses addon version " .. tostring(payload.addonVersion) .. "; you are on " .. tostring(self.version) .. ".")
    end

    if payload.proposalRulesetHash and payload.proposalRulesetHash ~= computedHash then
        Print("proposal ruleset hash mismatch detected. Use /sc conflicts if the proposal looks wrong.")
    end

    local proposal = {
        proposalId = payload.proposalId,
        runId = payload.proposalRunId,
        runName = payload.runName or "Softcore Run",
        proposedBy = proposerKey,
        proposedAt = tonumber(payload.proposedAt) or time(),
        ruleset = ruleset,
        rulesetHash = payload.proposalRulesetHash or computedHash,
        acceptedBy = {},
        declinedBy = {},
        status = "PENDING",
        proposalType = payload.proposalKind or "RUN",
        targetPlayerKey = payload.targetPlayerKey,
    }

    if proposal.targetPlayerKey and proposal.targetPlayerKey ~= self:GetPlayerKey() then
        db.proposals[proposal.proposalId] = proposal
        self:AddLog("PROPOSAL_OBSERVED", "Observed proposal for " .. proposal.targetPlayerKey, {
            proposalId = proposal.proposalId,
            targetPlayerKey = proposal.targetPlayerKey,
        })
        return
    end

    if db.run and db.run.active and proposal.proposalType == "RUN" then
        Print("received a run proposal, but you already have an active run. Use /sc proposal to review.")
    end

    self:StoreProposal(proposal)
    self:ShowProposalPopup(proposal)
end

function SC:AcceptPendingProposal()
    local db = GetDB()
    local proposal = self:GetPendingProposal()
    local playerKey = self:GetPlayerKey()

    if not proposal then
        Print("no pending proposal.")
        return
    end

    if db.run and db.run.active and proposal.proposalType == "RUN" and db.run.runId ~= proposal.runId then
        Print("cannot accept: you already have an active run with a different runId. Use /sc reset confirm only if you intend to leave it.")
        return
    end

    local localHash = self.GetRulesetHash and self:GetRulesetHash() or ""
    if db.run and db.run.active and db.run.runId == proposal.runId and localHash ~= "" and localHash ~= proposal.rulesetHash then
        Print("cannot accept: ruleset mismatch detected.")
        return
    end

    proposal.acceptedBy[playerKey] = true
    proposal.status = "ACCEPTED"
    db.acceptedRunId = proposal.runId
    db.acceptedRulesetHash = proposal.rulesetHash

    if proposal.proposalType == "ADD_PARTICIPANT" then
        local participant = self:GetOrCreateParticipant(playerKey)
        participant.status = "ACTIVE"
        participant.joinedAt = participant.joinedAt or time()
    else
        if not db.run.active then
            self:StartRun({
                runId = proposal.runId,
                runName = proposal.runName,
                ruleset = proposal.ruleset,
            })
        else
            local participant = self:GetOrCreateParticipant(playerKey)
            participant.status = "ACTIVE"
        end
    end

    self:AddLog("PROPOSAL_ACCEPTED", "Accepted proposal: " .. proposal.runName, {
        proposalId = proposal.proposalId,
        runId = proposal.runId,
    })

    if self.Sync_SendProposalResponse then
        self:Sync_SendProposalResponse("PROPOSAL_ACCEPT", proposal)
    end

    Print("accepted proposal: " .. proposal.runName)
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
    self:AddLog("PROPOSAL_DECLINED", "Declined proposal: " .. proposal.runName, {
        proposalId = proposal.proposalId,
        runId = proposal.runId,
    })

    if self.Sync_SendProposalResponse then
        self:Sync_SendProposalResponse("PROPOSAL_DECLINE", proposal)
    end

    Print("declined proposal: " .. proposal.runName)
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

    if payload.type == "PROPOSAL_ACCEPT" then
        proposal.acceptedBy[playerKey] = true
        self:AddLog("PROPOSAL_ACCEPT_SYNC", playerKey .. " accepted proposal " .. proposal.runName, {
            proposalId = proposal.proposalId,
            playerKey = playerKey,
        })
    elseif payload.type == "PROPOSAL_DECLINE" then
        proposal.declinedBy[playerKey] = true
        self:AddLog("PROPOSAL_DECLINE_SYNC", playerKey .. " declined proposal " .. proposal.runName, {
            proposalId = proposal.proposalId,
            playerKey = playerKey,
        })
    end
end

function SC:ShowPendingProposal()
    local proposal = self:GetPendingProposal()

    if not proposal then
        Print("no pending proposal.")
        return
    end

    Print("proposal: " .. proposal.runName .. " from " .. tostring(proposal.proposedBy))
    Print(ProposalSummary(proposal))
    self:ShowProposalPopup(proposal)
end

function SC:ShowProposalPopup(proposal)
    if not StaticPopupDialogs then
        Print("proposal received: " .. proposal.runName .. ". Use /sc accept or /sc decline.")
        return
    end

    StaticPopupDialogs["SOFTCORE_RUN_PROPOSAL"] = {
        text = "Softcore proposal:\n%s\n\n%s",
        button1 = "Accept",
        button2 = "Decline",
        OnAccept = function()
            SC:AcceptPendingProposal()
        end,
        OnCancel = function()
            SC:DeclinePendingProposal()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopup_Show("SOFTCORE_RUN_PROPOSAL", proposal.runName, "From: " .. tostring(proposal.proposedBy) .. "\n\n" .. ProposalSummary(proposal))
end

function SC:ProposeRunFromSlash(rest)
    local runName = rest and rest ~= "" and rest or "Softcore Run"
    if self.OpenStartRunWindow then
        self:OpenStartRunWindow(runName)
    else
        self:CreateRunProposal(runName, self:GetDefaultRuleset(), "RUN")
        Print("proposed run: " .. runName)
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
