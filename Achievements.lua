-- Account and character achievements for Softcore runs.

local SC = Softcore

local DISALLOWED_VALUES = {
    WARNING = true,
    FATAL = true,
    CHARACTER_FAIL = true,
}

local RESTRICTION_RULES = {
    { id = "no_auction_house", name = "Trade Chat Only", rule = "auctionHouse", label = "Auction House" },
    { id = "no_mailbox", name = "No Mail Call", rule = "mailbox", label = "Mailbox" },
    { id = "no_trade", name = "Self Supplied", rule = "trade", label = "Trade" },
    { id = "no_bank", name = "Pockets Only", rule = "bank", label = "Bank" },
    { id = "no_warband_bank", name = "No Warband Help", rule = "warbandBank", label = "Warband Bank" },
    { id = "no_guild_bank", name = "No Guild Vault", rule = "guildBank", label = "Guild Bank" },
    { id = "no_mounts", name = "Walked the World", rule = "mounts", label = "Mounts" },
    { id = "no_flying", name = "Grounded Champion", rule = "flying", label = "Flying Mounts" },
    { id = "no_heirlooms", name = "No Hand-Me-Downs", rule = "heirlooms", label = "Heirlooms" },
    { id = "no_consumables", name = "No Crutches", rule = "consumables", label = "Consumables" },
    { id = "level_gap_enforced", name = "Kept Together", rule = "maxLevelGap", description = "Reach max level with Level Gap Enforcement enabled from run start through max level." },
    { id = "no_repeat_dungeons", name = "One Clear Only", rule = "dungeonRepeat", label = "Repeated Dungeons" },
    { id = "no_instanced_pvp", name = "No Battleground Detours", rule = "instancedPvP", label = "Instanced PvP" },
}

local function GetAccountDB()
    SoftcoreAchievementsDB = SoftcoreAchievementsDB or {}
    SoftcoreAchievementsDB.earned = SoftcoreAchievementsDB.earned or {}
    SoftcoreAchievementsDB.nextIds = SoftcoreAchievementsDB.nextIds or {}
    return SoftcoreAchievementsDB
end

local function GetCharDB()
    SoftcoreDB = SoftcoreDB or {}
    SoftcoreDB.achievements = SoftcoreDB.achievements or {}
    SoftcoreDB.achievements.earned = SoftcoreDB.achievements.earned or {}
    SoftcoreDB.achievements.runEligibility = SoftcoreDB.achievements.runEligibility or nil
    return SoftcoreDB.achievements
end

local function IsDisallowed(value)
    if value == nil then return false end
    if value == "ALLOWED" or value == "LOG_ONLY" or value == false then return false end
    return DISALLOWED_VALUES[value] or true
end

local function GetMaxLevel()
    if GetMaxLevelForPlayerExpansion then
        local ok, level = pcall(GetMaxLevelForPlayerExpansion)
        if ok and tonumber(level) then return tonumber(level) end
    end

    if MAX_PLAYER_LEVEL and tonumber(MAX_PLAYER_LEVEL) then
        return tonumber(MAX_PLAYER_LEVEL)
    end

    return 80
end

local function IsLocalActiveAndValid(db)
    if not db or not db.run or not db.run.active then return false end
    local playerKey = SC.GetPlayerKey and SC:GetPlayerKey()
    local participant = playerKey and db.run.participants and db.run.participants[playerKey]
    if participant and participant.status == "FAILED" then return false end
    return true
end

local function EarnedStore(scope)
    if scope == "ACCOUNT" then
        return GetAccountDB().earned
    end

    return GetCharDB().earned
end

local function Earn(id, scope, detail)
    local store = EarnedStore(scope)
    if store[id] then return false end

    store[id] = {
        id = id,
        scope = scope,
        earnedAt = time(),
        playerKey = SC.GetPlayerKey and SC:GetPlayerKey() or nil,
        runId = SoftcoreDB and SoftcoreDB.run and SoftcoreDB.run.runId or nil,
        detail = detail,
    }

    if SC.AddLog then
        SC:AddLog("ACHIEVEMENT_EARNED", "Achievement earned: " .. tostring(detail or id), {
            achievementId = id,
            achievementScope = scope,
        })
    end

    return true
end

local function CurrentEligibility()
    local achievements = GetCharDB()
    local db = SC.db or SoftcoreDB
    local eligibility = achievements.runEligibility

    if not eligibility or not db or not db.run or not db.run.active then
        return nil
    end

    if eligibility.runId ~= db.run.runId then
        return nil
    end

    return eligibility
end

local function RequirementStayedLocked(eligibility, ruleset, ruleName)
    if not eligibility or not eligibility.createdAtRunStart then return false end
    if eligibility.ruleChanges and eligibility.ruleChanges[ruleName] then return false end
    if eligibility.ruleViolations and eligibility.ruleViolations[ruleName] then return false end
    if not eligibility.initialRules or not IsDisallowed(eligibility.initialRules[ruleName]) then return false end
    return IsDisallowed(ruleset and ruleset[ruleName])
end

local function IsIronmanRules(rules)
    if not rules then return false end
    if rules.groupingMode ~= "SOLO_SELF_FOUND" then return false end
    if rules.gearQuality ~= "WHITE_GRAY_ONLY" then return false end

    local requiredDisallowed = {
        "auctionHouse",
        "mailbox",
        "trade",
        "bank",
        "warbandBank",
        "guildBank",
        "mounts",
        "flying",
        "heirlooms",
        "consumables",
        "dungeonRepeat",
    }

    for _, ruleName in ipairs(requiredDisallowed) do
        if not IsDisallowed(rules[ruleName]) then
            return false
        end
    end

    return true
end

local function CanEarnMaxRunAchievement(eligibility)
    if not eligibility or not eligibility.createdAtRunStart then return false end
    if not eligibility.startedAtOrBelow10 then return false end
    if eligibility.failed then return false end
    return true
end

local function AddDefinition(result, id, scope, category, name, description)
    table.insert(result, {
        id = id,
        scope = scope,
        category = category,
        name = name,
        description = description,
    })
end

function SC:GetAchievementDefinitions()
    local result = {}
    local maxLevel = GetMaxLevel()

    AddDefinition(result, "acct_first_run", "ACCOUNT", "Account", "First Steps", "Start your first Softcore run on this account.")
    AddDefinition(result, "acct_first_max_level", "ACCOUNT", "Account", "First Survivor", "Reach max level on an eligible Softcore character.")
    AddDefinition(result, "char_first_run", "CHARACTER", "Character", "Into the Ledger", "Start a Softcore run on this character.")

    for level = 10, maxLevel, 10 do
        AddDefinition(result, "char_level_" .. tostring(level), "CHARACTER", "Leveling", "Still Breathing: " .. tostring(level), "Reach level " .. tostring(level) .. " during an active Softcore run.")
    end

    AddDefinition(result, "char_max_level", "CHARACTER", "Max Level", "Softcore Champion", "Reach max level after starting the run at level 10 or below.")
    AddDefinition(result, "char_clean_max_level", "CHARACTER", "Max Level", "Clean Finish", "Reach max level on an eligible run without any local violations.")
    AddDefinition(result, "char_ironman_max_level", "CHARACTER", "Max Level", "Iron Will", "Reach max level on an eligible run that started with the Ironman preset.")

    for _, spec in ipairs(RESTRICTION_RULES) do
        AddDefinition(result, "char_max_" .. spec.id, "CHARACTER", "Rules", spec.name, spec.description or ("Reach max level with " .. spec.label .. " disallowed from run start through max level."))
    end

    return result
end

function SC:GetAchievementRows()
    local rows = {}
    local charEarned = GetCharDB().earned
    local accountEarned = GetAccountDB().earned

    for _, definition in ipairs(self:GetAchievementDefinitions()) do
        local earned = definition.scope == "ACCOUNT" and accountEarned[definition.id] or charEarned[definition.id]
        table.insert(rows, {
            id = definition.id,
            scope = definition.scope,
            category = definition.category,
            name = definition.name,
            description = definition.description,
            earned = earned ~= nil,
            earnedAt = earned and earned.earnedAt or nil,
        })
    end

    return rows
end

function SC:Achievements_OnRunStart(runOptions)
    local db = self.db or SoftcoreDB
    if not db or not db.run or not db.run.active then return end

    local achievements = GetCharDB()
    local startLevel = tonumber(db.run.startLevel or db.character.level or 0) or 0
    local preset = (runOptions and runOptions.preset) or (db.run.ruleset and db.run.ruleset.achievementPreset) or "CUSTOM"

    achievements.runEligibility = {
        runId = db.run.runId,
        createdAtRunStart = true,
        startedAt = db.run.startTime or time(),
        startLevel = startLevel,
        startedAtOrBelow10 = startLevel <= 10,
        initialRules = self.CopyTable and self:CopyTable(db.run.ruleset or {}) or {},
        initialRulesetHash = self.GetRulesetHash and self:GetRulesetHash() or nil,
        initialPreset = preset,
        hadViolation = false,
        failed = false,
        ruleChanges = {},
        ruleViolations = {},
    }

    Earn("char_first_run", "CHARACTER", "Into the Ledger")
    Earn("acct_first_run", "ACCOUNT", "First Steps")
    self:Achievements_OnLevelChanged(db.character.level)
end

function SC:Achievements_OnLevelChanged(level)
    local db = self.db or SoftcoreDB
    if not IsLocalActiveAndValid(db) then return end

    local eligibility = CurrentEligibility()
    if not eligibility or eligibility.failed then return end

    level = tonumber(level or db.character.level or 0) or 0
    local maxLevel = GetMaxLevel()
    local startLevel = tonumber(eligibility.startLevel or db.run.startLevel or 0) or 0

    for milestone = 10, maxLevel, 10 do
        if level >= milestone and milestone >= startLevel then
            Earn("char_level_" .. tostring(milestone), "CHARACTER", "Still Breathing: " .. tostring(milestone))
        end
    end

    if level < maxLevel or not CanEarnMaxRunAchievement(eligibility) then
        return
    end

    Earn("char_max_level", "CHARACTER", "Softcore Champion")
    Earn("acct_first_max_level", "ACCOUNT", "First Survivor")

    if not eligibility.hadViolation then
        Earn("char_clean_max_level", "CHARACTER", "Clean Finish")
    end

    if eligibility.initialPreset == "IRONMAN" and IsIronmanRules(eligibility.initialRules) and not eligibility.anyRuleChanged then
        Earn("char_ironman_max_level", "CHARACTER", "Iron Will")
    end

    for _, spec in ipairs(RESTRICTION_RULES) do
        if RequirementStayedLocked(eligibility, db.run.ruleset, spec.rule) then
            Earn("char_max_" .. spec.id, "CHARACTER", spec.name)
        end
    end
end

function SC:Achievements_OnViolationAdded(violation)
    if not violation or violation.playerKey ~= (self.GetPlayerKey and self:GetPlayerKey()) then return end

    local eligibility = CurrentEligibility()
    if eligibility then
        eligibility.hadViolation = true
        eligibility.ruleViolations = eligibility.ruleViolations or {}
        if violation.type then
            eligibility.ruleViolations[violation.type] = true
        end
        if violation.severity == "FATAL" or violation.severity == "CHARACTER_FAIL" or violation.type == "death" then
            eligibility.failed = true
        end
    end
end

function SC:Achievements_OnParticipantFailed(playerKey)
    if playerKey ~= (self.GetPlayerKey and self:GetPlayerKey()) then return end

    local eligibility = CurrentEligibility()
    if eligibility then
        eligibility.failed = true
    end
end

function SC:Achievements_OnRuleChanged(ruleName, oldValue, newValue)
    if tostring(oldValue) == tostring(newValue) then return end

    local eligibility = CurrentEligibility()
    if not eligibility then return end

    eligibility.ruleChanges = eligibility.ruleChanges or {}
    eligibility.ruleChanges[ruleName] = true
    eligibility.anyRuleChanged = true
end

function SC:Achievements_OnRunSynced(oldRunId, newRunId)
    local achievements = GetCharDB()
    local eligibility = achievements.runEligibility
    if eligibility and eligibility.runId == oldRunId then
        eligibility.runId = newRunId
        eligibility.syncedRunIdFrom = oldRunId
        eligibility.syncedAt = time()
    end
end
