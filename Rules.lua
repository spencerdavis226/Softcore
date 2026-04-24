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
}

local BOOLEAN_RULES = {
    failedMemberBlocksParty = true,
    allowLateJoin = true,
    allowReplacementCharacters = true,
    requireLeaderApprovalForJoin = true,
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
}

local GEAR_QUALITY_VALUES = {
    ALLOWED = true,
    WHITE_GRAY_ONLY = true,
    COMMON_OR_UNCOMMON = true,
    NO_EPICS = true,
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
    if ruleName == "maxLevelGapValue" then
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
    if ruleName == "maxLevelGapValue" then
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

        self:AddLog("WARNING", detail, {
            ruleName = ruleName,
            outcome = outcome,
        })
        self:AddViolation(ruleName, detail, "WARNING", playerKey)
        return evaluation
    end

    if outcome == "FATAL" or outcome == "CHARACTER_FAIL" then
        self:MarkParticipantFailed(playerKey, detail)
        self:AddLog("RULE_FATAL", detail, {
            ruleName = ruleName,
            outcome = outcome,
        })
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

    if self.Sync_SendProposal then
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
