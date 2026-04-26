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
    "consumables",
    "instancedPvP",
    "maxDeaths",
    "maxDeathsValue",
}

local function FriendlyGroupingMode(value)
    if value == "SOLO_SELF_FOUND" then
        return "Solo"
    end

    return "Group"
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

-- Returns a table of all current party member keys including the local player.
local function GetCurrentPartyKeys()
    local keys = {}
    local name, realm = UnitFullName("player")
    if not realm or realm == "" then
        realm = GetRealmName()
    end
    keys[(name or "Unknown") .. "-" .. (realm or "Unknown")] = true

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local n, r = UnitFullName("raid" .. i)
            if n then
                if not r or r == "" then r = GetRealmName() end
                keys[n .. "-" .. r] = true
            end
        end
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

function SC:SerializeRuleset(ruleset)
    local parts = {}

    for _, key in ipairs(RULE_KEYS) do
        if ruleset[key] ~= nil then
            table.insert(parts, Escape(key) .. "=" .. Escape(ruleset[key]))
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
    return "Death: Permanent"
        .. "\nGrouping: " .. FriendlyGroupingMode(proposal.ruleset.groupingMode)
        .. "\nAH: " .. FriendlyAllowed(proposal.ruleset.auctionHouse)
        .. "  Mail: " .. FriendlyAllowed(proposal.ruleset.mailbox)
        .. "  Trade: " .. FriendlyAllowed(proposal.ruleset.trade)
        .. "\nGear: " .. FriendlyGear(proposal.ruleset.gearQuality)
        .. "  Heirlooms: " .. FriendlyAllowed(proposal.ruleset.heirlooms)
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

-- Returns true if all members still in the party (from partyAtProposalTime) have accepted.
-- Members who have left the party since the proposal was created are ignored — they can't
-- accept anyway and shouldn't block the run from starting.
function SC:CheckAllProposalMembersAccepted(proposal)
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
    if proposal.proposalType ~= "RUN" then return end

    if self:CheckAllProposalMembersAccepted(proposal) then
        proposal.status = "CONFIRMED"
        db.pendingProposalId = nil

        if not db.run or not db.run.active then
            self:StartRun({
                runId = proposal.runId,
                runName = proposal.runName,
                ruleset = proposal.ruleset,
            })
        end

        if self.Sync_SendRunProposalConfirmed then
            self:Sync_SendRunProposalConfirmed(proposal)
        end

        Print("all present members accepted. Run started.")
    end
end

function SC:CreateRunProposal(runName, ruleset, proposalType, targetPlayerKey, runId)
    if not self:CanProposeRun() then
        Print("only the party leader or an active participant can propose a run.")
        return nil
    end

    local db = GetDB()
    if (proposalType == "RUN" or not proposalType) and db.run and db.run.active then
        Print("cannot propose a new run while an active run is in progress. Use /sc reset to stop it first.")
        return nil
    end
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

    -- Cancel any existing pending proposal before storing the new one so the old
    -- proposalId isn't left dangling and the UI doesn't show a stale proposal.
    local existing = self:GetPendingProposal()
    if existing and existing.proposalId ~= proposal.proposalId then
        existing.status = "CANCELLED"
        db.pendingProposalId = nil
        self:AddLog("PROPOSAL_SUPERSEDED", "Pending proposal superseded by new proposal from " .. proposerKey, {
            oldProposalId = existing.proposalId,
            newProposalId = proposal.proposalId,
        })
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

    if db.run and db.run.active and proposal.proposalType == "RUN" and db.run.runId ~= proposal.runId then
        Print("cannot accept: you already have an active run with a different runId. Use /sc reset only if you intend to leave it.")
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
        -- When in a group, wait for PROPOSAL_CONFIRMED from the proposer.
        -- When not in a group (edge case), start immediately.
        if not IsInGroup() then
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
        -- else: run will start when ReceiveRunConfirmed fires
    end

    self:AddLog("PROPOSAL_ACCEPTED", "Accepted proposal: " .. proposal.runName, {
        proposalId = proposal.proposalId,
        runId = proposal.runId,
    })

    if self.Sync_SendProposalResponse then
        self:Sync_SendProposalResponse("PROPOSAL_ACCEPT", proposal)
    end

    Print("accepted proposal: " .. proposal.runName .. ". Waiting for all members to accept.")
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

        -- Only the proposer drives the "all accepted" check and starts the run.
        -- Guard against DECLINED/CANCELLED → CONFIRMED: only act from PENDING state.
        if proposal.proposedBy == self:GetPlayerKey() and proposal.proposalType == "RUN" and proposal.status == "PENDING" then
            if self:CheckAllProposalMembersAccepted(proposal) then
                proposal.status = "CONFIRMED"
                db.pendingProposalId = nil

                if not db.run.active then
                    self:StartRun({
                        runId = proposal.runId,
                        runName = proposal.runName,
                        ruleset = proposal.ruleset,
                    })
                end

                if self.Sync_SendRunProposalConfirmed then
                    self:Sync_SendRunProposalConfirmed(proposal)
                end

                Print("all members accepted. Run started.")
            end
        end

    elseif payload.type == "PROPOSAL_DECLINE" then
        proposal.declinedBy[playerKey] = true
        self:AddLog("PROPOSAL_DECLINE_SYNC", playerKey .. " declined proposal " .. proposal.runName, {
            proposalId = proposal.proposalId,
            playerKey = playerKey,
        })

        -- Proposer cancels the proposal when any member declines.
        if proposal.proposedBy == self:GetPlayerKey() and proposal.proposalType == "RUN" and proposal.status == "PENDING" then
            proposal.status = "DECLINED"
            db.pendingProposalId = nil

            Print(playerKey .. " declined. Proposal cancelled.")

            if self.Sync_SendProposalCancelled then
                self:Sync_SendProposalCancelled(proposal)
            end

            if self.HUD_Refresh then
                self:HUD_Refresh()
            end
        end
    end
end

-- Called when a non-proposer receives PROPOSAL_CONFIRMED from the proposer.
function SC:ReceiveRunConfirmed(payload, confirmerKey)
    local db = GetDB()
    local proposal = db.proposals[payload.proposalId]
    if not proposal then return end

    local playerKey = self:GetPlayerKey()

    -- Only act if we already accepted this proposal and are not the proposer.
    if not proposal.acceptedBy[playerKey] then return end
    if proposal.proposedBy == playerKey then return end

    proposal.status = "CONFIRMED"
    if db.pendingProposalId == proposal.proposalId then
        db.pendingProposalId = nil
    end

    if not db.run.active then
        self:StartRun({
            runId = proposal.runId,
            runName = proposal.runName,
            ruleset = proposal.ruleset,
        })
    end

    self:AddLog("PROPOSAL_CONFIRMED", "Run confirmed by " .. confirmerKey .. ": " .. proposal.runName, {
        proposalId = proposal.proposalId,
    })

    Print("run started: all members accepted.")

    if self.HUD_Refresh then
        self:HUD_Refresh()
    end
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
