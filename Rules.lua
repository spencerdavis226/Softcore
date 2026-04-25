-- Structured rules engine and local amendment foundation.

local SC = Softcore

local SUPPORTED_SEVERITIES = {
    ALLOWED = true,
    LOG_ONLY = true,
    WARNING = true,
    FATAL = true,
    CHARACTER_FAIL = true,
}

local RULE_ORDER = {
    "death",
    "groupingMode",
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

local HASH_RULE_ORDER = {
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

local BOOLEAN_RULES = {
    failedMemberBlocksParty = true,
    allowLateJoin = true,
    allowReplacementCharacters = true,
    requireLeaderApprovalForJoin = true,
    maxDeaths = true,
}

local ACCESS_RULES = {
    bank = true,
    warbandBank = true,
    guildBank = true,
    voidStorage = true,
    craftingOrders = true,
    vendor = true,
}

local SEVERITY_ONLY_RULES = {
    auctionHouse = true,
    mailbox = true,
    trade = true,
    mounts = true,
    flying = true,
    outsiderGrouping = true,
    unsyncedMembers = true,
    heirlooms = true,
    maxLevelGap = true,
    dungeonRepeat = true,
    instanceWithUnsyncedPlayers = true,
    consumables = true,
    instancedPvP = true,
}

local GEAR_QUALITY_VALUES = {
    ALLOWED = true,
    WHITE_GRAY_ONLY = true,
    COMMON_OR_UNCOMMON = true,
    NO_EPICS = true,
    GREEN_OR_LOWER = true,
    BLUE_OR_LOWER = true,
    EPIC_OR_LOWER = true,
}

local GROUPING_MODE_VALUES = {
    SYNCED_GROUP_ALLOWED = true,
    SOLO_SELF_FOUND = true,
}

local function GetDB()
    SoftcoreDB = SoftcoreDB or {}
    SoftcoreDB.run = SoftcoreDB.run or {}
    SoftcoreDB.run.ruleset = SoftcoreDB.run.ruleset or {}
    SoftcoreDB.ruleAmendments = SoftcoreDB.ruleAmendments or {}
    SoftcoreDB.nextIds = SoftcoreDB.nextIds or {}
    SoftcoreDB.nextIds.amendment = SoftcoreDB.nextIds.amendment or 0
    return SoftcoreDB
end

local function CreateAmendmentId()
    local db = GetDB()
    db.nextIds.amendment = (db.nextIds.amendment or 0) + 1
    return "SC-AMENDMENT-" .. tostring(time()) .. "-" .. tostring(db.nextIds.amendment)
end

local function CopyRules(rules)
    local copy = {}
    for key, value in pairs(rules or {}) do
        copy[key] = value
    end
    return copy
end

local function IsValidRuleValue(ruleName, value)
    if ruleName == "maxLevelGapValue" or ruleName == "maxDeathsValue" then
        return tonumber(value) ~= nil
    end

    if BOOLEAN_RULES[ruleName] then
        return type(value) == "boolean"
    end

    if ruleName == "death" then
        return value == "CHARACTER_FAIL"
    end

    if ruleName == "gearQuality" then
        return GEAR_QUALITY_VALUES[value] == true
    end

    if ruleName == "groupingMode" then
        return GROUPING_MODE_VALUES[value] == true
    end

    if (ACCESS_RULES[ruleName] or SEVERITY_ONLY_RULES[ruleName]) and value == "CHARACTER_FAIL" then
        return false
    end

    return SUPPORTED_SEVERITIES[value] == true
end

local function NormalizeRuleValue(ruleName, value)
    if ruleName == "maxLevelGapValue" or ruleName == "maxDeathsValue" then
        return tonumber(value)
    end

    if BOOLEAN_RULES[ruleName] then
        if value == true or value == "true" or value == "TRUE" then
            return true
        end

        if value == false or value == "false" or value == "FALSE" then
            return false
        end
    end

    return string.upper(tostring(value or ""))
end

local function ContextDetail(ruleName, context)
    context = context or {}
    return context.detail or ("Rule triggered: " .. ruleName)
end

function SC:IsRunFailed()
    local db = self.db or SoftcoreDB
    return db and db.run and db.run.failed == true
end

function SC:IsRunActive()
    local db = self.db or SoftcoreDB
    return db and db.run and db.run.active == true
end

function SC:GetRule(ruleName)
    local db = GetDB()
    return db.run.ruleset[ruleName]
end

function SC:SetRule(ruleName, value)
    local normalized = NormalizeRuleValue(ruleName, value)

    if self:GetRule(ruleName) == nil then
        return false, "unknown rule: " .. tostring(ruleName)
    end

    if not IsValidRuleValue(ruleName, normalized) then
        return false, "invalid value for " .. tostring(ruleName) .. ": " .. tostring(value)
    end

    if self:GetRule(ruleName) == normalized then
        return true, "rule unchanged: " .. ruleName .. " is already " .. tostring(normalized)
    end

    local amendment = self:ProposeRuleAmendment({
        [ruleName] = normalized,
    }, "Local slash command rule change.")

    self:AcceptRuleAmendment(amendment.id)
    self:ApplyRuleAmendment(amendment.id)

    return true, "rule updated: " .. ruleName .. " = " .. tostring(normalized)
end

function SC:EvaluateRule(ruleName, context)
    local outcome = self:GetRule(ruleName)

    return {
        ruleName = ruleName,
        outcome = outcome or "ALLOWED",
        context = context or {},
    }
end

function SC:ApplyRuleOutcome(ruleName, context)
    local evaluation = self:EvaluateRule(ruleName, context)
    local outcome = evaluation.outcome
    local detail = ContextDetail(ruleName, context)

    if outcome == "ALLOWED" or outcome == true then
        return evaluation
    end

    if outcome == "LOG_ONLY" then
        self:AddLog("RULE_LOG", detail, {
            ruleName = ruleName,
            outcome = outcome,
        })
        return evaluation
    end

    local playerKey = context and context.playerKey or self:GetPlayerKey()

    if outcome == "WARNING" then
        local db = self.db or SoftcoreDB
        if db and db.run then
            db.run.warningCount = (db.run.warningCount or 0) + 1
        end

        local participant = self:GetOrCreateParticipant(playerKey)
        if participant.status == "ACTIVE" then
            participant.status = "WARNING"
        end

        self:AddViolation(ruleName, detail, "WARNING", playerKey)
        return evaluation
    end

    if outcome == "FATAL" or outcome == "CHARACTER_FAIL" then
        self:MarkParticipantFailed(playerKey, detail)
        self:AddViolation(ruleName, detail, "FATAL", playerKey)
        return evaluation
    end

    self:AddLog("RULE_UNKNOWN_OUTCOME", detail, {
        ruleName = ruleName,
        outcome = tostring(outcome),
    })

    return evaluation
end

function SC:ProposeRuleAmendment(newRules, reason)
    local db = GetDB()
    local amendment = {
        id = CreateAmendmentId(),
        runId = db.run.runId,
        newRules = CopyRules(newRules),
        previousRules = {},
        reason = reason or "Rule amendment proposed.",
        status = "PENDING",
        proposedAt = time(),
        proposedBy = self:GetPlayerKey(),
        acceptedAt = nil,
        acceptedBy = nil,
        declinedAt = nil,
        declinedBy = nil,
        appliedAt = nil,
    }

    for ruleName in pairs(newRules or {}) do
        amendment.previousRules[ruleName] = db.run.ruleset[ruleName]
    end

    table.insert(db.ruleAmendments, amendment)
    self:AddLog("RULE_AMENDMENT_PROPOSED", amendment.reason, {
        amendmentId = amendment.id,
    })

    if self.Sync_SendAmendmentProposal then
        self:Sync_SendAmendmentProposal(amendment)
    elseif self.Sync_SendProposal then
        self:Sync_SendProposal("AMENDMENT_PROPOSE", amendment.id)
    end

    return amendment
end

function SC:AcceptRuleAmendment(amendmentId)
    local db = GetDB()

    for _, amendment in ipairs(db.ruleAmendments) do
        if amendment.id == amendmentId then
            if amendment.status == "PENDING" then
                amendment.status = "ACCEPTED"
                amendment.acceptedAt = time()
                amendment.acceptedBy = self:GetPlayerKey()
                self:AddLog("RULE_AMENDMENT_ACCEPTED", "Rule amendment accepted.", {
                    amendmentId = amendment.id,
                })
                if self.Sync_SendProposal then
                    self:Sync_SendProposal("AMENDMENT_ACCEPT", amendment.id)
                end
            end

            return amendment
        end
    end

    return nil
end

function SC:DeclineRuleAmendment(amendmentId)
    local db = GetDB()

    for _, amendment in ipairs(db.ruleAmendments) do
        if amendment.id == amendmentId then
            if amendment.status == "PENDING" then
                amendment.status = "DECLINED"
                amendment.declinedAt = time()
                amendment.declinedBy = self:GetPlayerKey()
                self:AddLog("RULE_AMENDMENT_DECLINED", "Rule amendment declined.", {
                    amendmentId = amendment.id,
                })
                if self.Sync_SendProposal then
                    self:Sync_SendProposal("AMENDMENT_DECLINE", amendment.id)
                end
            end

            return amendment
        end
    end

    return nil
end

function SC:ApplyRuleAmendment(amendmentId)
    local db = GetDB()

    for _, amendment in ipairs(db.ruleAmendments) do
        if amendment.id == amendmentId then
            if amendment.status ~= "ACCEPTED" and amendment.status ~= "APPLIED" then
                return nil
            end

            if amendment.status ~= "APPLIED" then
                for ruleName, value in pairs(amendment.newRules) do
                    db.run.ruleset[ruleName] = value
                    self:AddLog("RULE_CHANGED", ruleName .. " changed to " .. tostring(value), {
                        amendmentId = amendment.id,
                        ruleName = ruleName,
                        newValue = value,
                        oldValue = amendment.previousRules[ruleName],
                    })
                end

                if self.ApplyGroupingMode then
                    self:ApplyGroupingMode(db.run.ruleset)
                end

                db.run.ruleset.version = (tonumber(db.run.ruleset.version) or 1) + 1

                amendment.status = "APPLIED"
                amendment.appliedAt = time()
                self:AddLog("RULE_AMENDMENT_APPLIED", "Rule amendment applied prospectively.", {
                    amendmentId = amendment.id,
                })
            end

            return amendment
        end
    end

    return nil
end

function SC:ReceiveRuleAmendmentProposal(payload, senderKey)
    local db = GetDB()
    if not db.run or not db.run.active then return end
    if payload.runId and db.run.runId and payload.runId ~= db.run.runId then return end

    local amendmentId = payload.amendmentId or payload.proposalId
    if not amendmentId then return end

    for _, existing in ipairs(db.ruleAmendments) do
        if existing.id == amendmentId then return end
    end

    local newRules = self.DeserializePartialRules and self:DeserializePartialRules(payload.newRules) or {}
    local previousRules = self.DeserializePartialRules and self:DeserializePartialRules(payload.previousRules) or {}

    local amendment = {
        id = amendmentId,
        runId = payload.runId or db.run.runId,
        newRules = newRules,
        previousRules = previousRules,
        reason = payload.reason or "Rule amendment proposed.",
        status = "PENDING",
        proposedAt = tonumber(payload.proposedAt) or time(),
        proposedBy = payload.proposedBy or senderKey,
        remote = true,
    }

    table.insert(db.ruleAmendments, amendment)
    self:AddLog("RULE_AMENDMENT_RECEIVED", "Rule amendment proposed by " .. tostring(senderKey or "?"), {
        amendmentId = amendmentId,
    })

    if self.PlayUISound then self:PlayUISound("PROPOSAL_RECEIVED") end
    if self.MasterUI_Refresh then self:MasterUI_Refresh() end
    if self.HUD_Refresh then self:HUD_Refresh() end
end

function SC:ReceiveRuleAmendmentResponse(payload, senderKey)
    local db = GetDB()
    local amendmentId = payload.amendmentId or payload.proposalId
    if not amendmentId then return end

    local localKey = self:GetPlayerKey()

    for _, amendment in ipairs(db.ruleAmendments) do
        if amendment.id == amendmentId and amendment.status == "PENDING" then
            if amendment.proposedBy ~= localKey then return end

            if payload.type == "AMENDMENT_ACCEPT" then
                amendment.acceptances = amendment.acceptances or {}
                amendment.acceptances[senderKey] = true

                local syncRows = self.Sync_GetGroupRows and self:Sync_GetGroupRows() or {}
                local allAccepted = true
                for _, peer in ipairs(syncRows) do
                    if peer.playerKey and not amendment.acceptances[peer.playerKey] then
                        allAccepted = false
                        break
                    end
                end

                if allAccepted then
                    amendment.status = "ACCEPTED"
                    amendment.acceptedAt = time()
                    self:ApplyRuleAmendment(amendmentId)
                    if self.Sync_SendAmendmentApplied then
                        self:Sync_SendAmendmentApplied(amendment)
                    end
                    DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r Rule amendment accepted by all — applied.")
                end

            elseif payload.type == "AMENDMENT_DECLINE" then
                amendment.status = "DECLINED"
                amendment.declinedAt = time()
                amendment.declinedBy = senderKey
                if self.Sync_SendAmendmentCancelled then
                    self:Sync_SendAmendmentCancelled(amendment)
                end
                DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r |cfffbbf24Rule amendment declined by " .. tostring(senderKey or "?") .. ".|r")
            end

            if self.MasterUI_Refresh then self:MasterUI_Refresh() end
            return
        end
    end
end

function SC:ReceiveRuleAmendmentApplied(payload)
    local db = GetDB()
    local amendmentId = payload.amendmentId
    if not amendmentId then return end

    for _, amendment in ipairs(db.ruleAmendments) do
        if amendment.id == amendmentId and amendment.status == "PENDING" then
            amendment.status = "ACCEPTED"
            amendment.acceptedAt = time()
            self:ApplyRuleAmendment(amendmentId)
            DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r Rule amendment applied.")
            break
        end
    end

    if self.MasterUI_Refresh then self:MasterUI_Refresh() end
end

function SC:ReceiveRuleAmendmentCancelled(payload)
    local db = GetDB()
    local amendmentId = payload.amendmentId
    if not amendmentId then return end

    for _, amendment in ipairs(db.ruleAmendments) do
        if amendment.id == amendmentId and amendment.status == "PENDING" then
            amendment.status = "DECLINED"
            amendment.declinedAt = time()
            break
        end
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r |cfffbbf24Rule amendment was cancelled.|r")
    if self.MasterUI_Refresh then self:MasterUI_Refresh() end
end

function SC:GetRuleOrder()
    return RULE_ORDER
end

function SC:GetRulesetHash()
    local db = GetDB()
    local text = ""
    local checksum = 0

    for _, ruleName in ipairs(HASH_RULE_ORDER) do
        text = text .. ruleName .. "=" .. tostring(db.run.ruleset[ruleName]) .. ";"
    end

    for index = 1, string.len(text) do
        checksum = (checksum + (string.byte(text, index) * index)) % 1000000007
    end

    return tostring(checksum)
end
