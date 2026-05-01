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
    { id = "no_flight_paths", name = "No Flight Plan", rule = "flightPaths", label = "Flight Paths" },
    { id = "no_heirlooms", name = "No Hand-Me-Downs", rule = "heirlooms", label = "Heirlooms" },
    { id = "no_enchants", name = "Unenchanted", rule = "enchants", label = "Enchants" },
    { id = "no_consumables", name = "No Crutches", rule = "consumables", label = "Consumables" },
    { id = "level_gap_enforced", name = "Kept Together", rule = "maxLevelGap", description = "Reach max level after starting at level 10 or lower with Level Gap Enforcement enabled from run start through max level." },
    { id = "no_repeat_dungeons", name = "One Clear Only", rule = "dungeonRepeat", label = "Repeated Dungeons" },
    { id = "no_instanced_pvp", name = "No Battleground Detours", rule = "instancedPvP", label = "Instanced PvP" },
}

local CLEAN_LEVEL_NAMES = {
    [30] = "Rule Keeper",
    [40] = "Steady Hands",
    [50] = "Unshaken",
    [60] = "Untarnished",
    [70] = "Pure Resolve",
    [80] = "Flawless Path",
    [90] = "Crystal Ledger",
    [100] = "Spotless Century",
}

local CLASS_MAX_ACHIEVEMENTS = {
    { class = "WARRIOR", name = "Max-Level Warrior", label = "Warrior" },
    { class = "PALADIN", name = "Max-Level Paladin", label = "Paladin" },
    { class = "HUNTER", name = "Max-Level Hunter", label = "Hunter" },
    { class = "ROGUE", name = "Max-Level Rogue", label = "Rogue" },
    { class = "PRIEST", name = "Max-Level Priest", label = "Priest" },
    { class = "DEATHKNIGHT", name = "Max-Level Death Knight", label = "Death Knight" },
    { class = "SHAMAN", name = "Max-Level Shaman", label = "Shaman" },
    { class = "MAGE", name = "Max-Level Mage", label = "Mage" },
    { class = "WARLOCK", name = "Max-Level Warlock", label = "Warlock" },
    { class = "MONK", name = "Max-Level Monk", label = "Monk" },
    { class = "DRUID", name = "Max-Level Druid", label = "Druid" },
    { class = "DEMONHUNTER", name = "Max-Level Demon Hunter", label = "Demon Hunter" },
    { class = "EVOKER", name = "Max-Level Evoker", label = "Evoker" },
}

local CLASS_MAX_BY_FILE = {}
for _, spec in ipairs(CLASS_MAX_ACHIEVEMENTS) do
    CLASS_MAX_BY_FILE[spec.class] = spec
end

local PLAYER_RULE_CHANGE_KEYS = {
    groupingMode = true,
    auctionHouse = true,
    mailbox = true,
    trade = true,
    bank = true,
    warbandBank = true,
    guildBank = true,
    mounts = true,
    flying = true,
    flightPaths = true,
    maxLevelGap = true,
    maxLevelGapValue = true,
    dungeonRepeat = true,
    gearQuality = true,
    selfCraftedGearAllowed = true,
    heirlooms = true,
    enchants = true,
    consumables = true,
    instancedPvP = true,
    actionCam = true,
}

local ACHIEVEMENT_NAME_MAX_LEN = 34
local ACHIEVEMENT_DESC_MAX_LEN = 160
local lastAchievementSoundAt = 0

local function NotifyAchievementEarned(detail)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r achievement earned: |cffffd100" .. tostring(detail or "Achievement") .. "|r")
    end
    local now = time()
    if SC.PlayUISound and now ~= lastAchievementSoundAt then
        lastAchievementSoundAt = now
        SC:PlayUISound("ACHIEVEMENT_EARNED")
    end
end

local function ClampAchievementText(value, maxLen)
    local text = tostring(value or "")
    if maxLen and maxLen > 3 and #text > maxLen then
        return string.sub(text, 1, maxLen - 2) .. ".."
    end
    return text
end

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

local function EarnedStore()
    return GetAccountDB().earned
end

local function Earn(id, scope, detail)
    local store = EarnedStore()
    if store[id] then return false end

    store[id] = {
        id = id,
        scope = "ACCOUNT",
        earnedAt = time(),
        playerKey = SC.GetPlayerKey and SC:GetPlayerKey() or nil,
        runId = SoftcoreDB and SoftcoreDB.run and SoftcoreDB.run.runId or nil,
        detail = detail,
    }

    if SC.AddLog then
        SC:AddLog("ACHIEVEMENT_EARNED", "Achievement earned: " .. tostring(detail or id), {
            achievementId = id,
            achievementScope = "ACCOUNT",
        })
    end

    NotifyAchievementEarned(detail or id)

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
    if rules.selfCraftedGearAllowed == true then return false end

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
        "enchants",
        "consumables",
        "dungeonRepeat",
        "instancedPvP",
    }

    for _, ruleName in ipairs(requiredDisallowed) do
        if not IsDisallowed(rules[ruleName]) then
            return false
        end
    end

    return true
end

local function IsIronmanPreset(preset)
    return preset == "IRONMAN" or preset == "IRON_VIGIL"
end

local function IsChefSpecialPreset(preset)
    return preset == "CHEF_SPECIAL"
end

local function InitialDetectedPreset(eligibility)
    if not eligibility then return nil end
    return (SC.DetectRulesetPreset and SC:DetectRulesetPreset(eligibility.initialRules)) or eligibility.initialPreset
end

local function IsCameraEnforcedRules(rules)
    if not rules then return false end
    return IsDisallowed(rules.actionCam)
end

local function RuleChanged(eligibility, ruleName)
    return eligibility and eligibility.ruleChanges and eligibility.ruleChanges[ruleName] == true
end

local function AnyRuleAmendmentApplied(eligibility)
    return eligibility and (eligibility.anyAmendmentApplied == true or eligibility.anyRuleChanged == true)
end

local function IsPlayerFacingRuleChange(ruleName, oldValue, newValue, eligibility)
    if not PLAYER_RULE_CHANGE_KEYS[ruleName] then
        return false
    end

    if ruleName == "maxLevelGapValue" then
        local initialGap = eligibility and eligibility.initialRules and eligibility.initialRules.maxLevelGap
        local currentGap = SC.db and SC.db.run and SC.db.run.ruleset and SC.db.run.ruleset.maxLevelGap
        if not IsDisallowed(initialGap) and not IsDisallowed(currentGap) then
            return false
        end
    end

    return tostring(oldValue) ~= tostring(newValue)
end

local function CanEarnMaxRunAchievement(eligibility)
    if not eligibility or not eligibility.createdAtRunStart then return false end
    if not eligibility.startedAtOrBelow10 then return false end
    if eligibility.failed then return false end
    return true
end

local function AddDefinition(result, id, scope, category, name, description, progressKind, target, ruleName)
    local sortOrder = #result + 1
    table.insert(result, {
        id = id,
        scope = scope,
        category = category,
        name = ClampAchievementText(name, ACHIEVEMENT_NAME_MAX_LEN),
        description = ClampAchievementText(description, ACHIEVEMENT_DESC_MAX_LEN),
        progressKind = progressKind,
        target = target,
        ruleName = ruleName,
        sortOrder = sortOrder,
    })
end

function SC:GetAchievementDefinitions()
    local result = {}
    local maxLevel = GetMaxLevel()

    for level = 10, maxLevel, 10 do
        AddDefinition(result, "char_level_" .. tostring(level), "ACCOUNT", "Leveling", "Still Breathing: " .. tostring(level), "Reach level " .. tostring(level) .. " in an active run started at level 10 or below.", "LEVEL", level)
    end

    for level = 30, maxLevel, 10 do
        local name = CLEAN_LEVEL_NAMES[level] or ("Clean Climb: " .. tostring(level))
        AddDefinition(result, "char_clean_level_" .. tostring(level), "ACCOUNT", "Leveling", name, "Reach level " .. tostring(level) .. " with no violations in a run started at level 10 or below.", "LEVEL_CLEAN", level)
    end

    AddDefinition(result, "char_max_level", "ACCOUNT", "Max Level", "Softcore Champion", "Reach max level after starting the run at level 10 or below.", "MAX_LEVEL")
    AddDefinition(result, "char_clean_max_level", "ACCOUNT", "Max Level", "Clean Finish", "Reach max level after starting at level 10 or lower without any local violations.", "CLEAN_MAX")
    AddDefinition(result, "char_chef_special_max_level", "ACCOUNT", "Max Level", "Chef's Table", "Reach max level after starting at level 10 or lower using the Chef's Special preset with no rule amendments.", "CHEF_SPECIAL_MAX")
    AddDefinition(result, "char_ironman_max_level", "ACCOUNT", "Max Level", "Iron Will", "Reach max level after starting at level 10 or lower using an Ironman preset with no rule amendments.", "IRONMAN_MAX")
    AddDefinition(result, "char_camera_max_level", "ACCOUNT", "Max Level", "Locked Perspective", "Reach max level after starting at level 10 or lower with Cinematic Camera enforced from run start.", "CAMERA_MAX")
    AddDefinition(result, "char_camera_ironman_no_flight_paths_max_level", "ACCOUNT", "Max Level", "Iron Vigil", "Reach max level after starting at level 10 or lower using the Iron Vigil preset with no rule amendments.", "CAMERA_IRONMAN_NO_FLIGHT_PATHS_MAX")
    AddDefinition(result, "char_original_terms", "ACCOUNT", "Max Level", "Original Terms", "Reach max level after starting at level 10 or lower with no rule amendments applied.", "RULE_UNCHANGED_MAX")
    AddDefinition(result, "char_party_survivor", "ACCOUNT", "Max Level", "Party Survivor", "Reach max level after starting at level 10 or lower in group mode.", "GROUPED_MAX")

    for _, spec in ipairs(CLASS_MAX_ACHIEVEMENTS) do
        AddDefinition(result, "char_max_class_" .. string.lower(spec.class), "ACCOUNT", "Classes", spec.name, "Reach max level as a " .. spec.label .. " after starting the run at level 10 or below.", "CLASS_MAX", nil, spec.class)
    end

    for _, spec in ipairs(RESTRICTION_RULES) do
        AddDefinition(result, "char_max_" .. spec.id, "ACCOUNT", "Rules", spec.name, spec.description or ("Reach max level after starting at level 10 or lower with " .. spec.label .. " disallowed from run start through max level."), "RULE_MAX", nil, spec.rule)
    end

    AddDefinition(result, "char_white_knuckles", "ACCOUNT", "Rules", "White Knuckles", "Reach max level after starting at level 10 or lower with white/gray gear quality enforced from run start.", "GEAR_QUALITY_MAX", nil, "WHITE_GRAY_ONLY")
    AddDefinition(result, "char_self_forged", "ACCOUNT", "Rules", "Self-Forged", "Reach max level after starting at level 10 or lower with white/gray gear quality and self-crafted gear exemption from run start.", "GEAR_QUALITY_CRAFTED_MAX", nil, "WHITE_GRAY_ONLY")

    return result
end

local function BuildProgress(definition, earned)
    if earned then
        return 1, "Complete"
    end

    local db = SC.db or SoftcoreDB
    local currentLevel = tonumber(db and db.character and db.character.level or 0) or 0
    local maxLevel = GetMaxLevel()
    local eligibility = CurrentEligibility()

    if definition.progressKind == "BINARY" then
        return 0, "Not earned"
    end

    if definition.progressKind == "LEVEL" then
        local target = tonumber(definition.target or 0) or 0
        if target <= 0 then return 0, "Not earned" end
        if not eligibility or not eligibility.createdAtRunStart then
            return 0, "Start an active run"
        end
        if not eligibility.startedAtOrBelow10 then
            return 0, "Started above level 10"
        end
        if eligibility.failed then
            return 0, "Failed this run"
        end
        if target < (tonumber(eligibility.startLevel or 0) or 0) then
            return 0, "Started above target"
        end
        return math.min(currentLevel / target, 1), "Level " .. tostring(currentLevel) .. " / " .. tostring(target)
    end

    if definition.progressKind == "LEVEL_CLEAN" then
        local target = tonumber(definition.target or 0) or 0
        if target <= 0 then return 0, "Not earned" end
        if not eligibility or not eligibility.createdAtRunStart then
            return 0, "Start an active run"
        end
        if not eligibility.startedAtOrBelow10 then
            return 0, "Started above level 10"
        end
        if eligibility.failed then
            return 0, "Failed this run"
        end
        if eligibility.hadViolation then
            return 0, "Violation recorded"
        end
        if target < (tonumber(eligibility.startLevel or 0) or 0) then
            return 0, "Started above target"
        end
        return math.min(currentLevel / target, 1), "Clean: " .. tostring(currentLevel) .. " / " .. tostring(target)
    end

    if not eligibility or not eligibility.createdAtRunStart then
        return 0, "Start an eligible run"
    end

    if eligibility.failed then
        return 0, "Failed this run"
    end

    if definition.progressKind == "MAX_LEVEL" then
        if not eligibility.startedAtOrBelow10 then
            return 0, "Started above level 10"
        end
        return math.min(currentLevel / maxLevel, 1), "Level " .. tostring(currentLevel) .. " / " .. tostring(maxLevel)
    end

    if definition.progressKind == "CLEAN_MAX" then
        if not eligibility.startedAtOrBelow10 then
            return 0, "Started above level 10"
        end
        if eligibility.hadViolation then
            return 0, "Violation recorded"
        end
        return math.min(currentLevel / maxLevel, 1), "Clean run: " .. tostring(currentLevel) .. " / " .. tostring(maxLevel)
    end

    if definition.progressKind == "CHEF_SPECIAL_MAX" then
        if not eligibility.startedAtOrBelow10 then
            return 0, "Started above level 10"
        end
        if not IsChefSpecialPreset(InitialDetectedPreset(eligibility)) then
            return 0, "Not a Chef's Special start"
        end
        if AnyRuleAmendmentApplied(eligibility) then
            return 0, "Rules amended"
        end
        return math.min(currentLevel / maxLevel, 1), "Chef's Special: " .. tostring(currentLevel) .. " / " .. tostring(maxLevel)
    end

    if definition.progressKind == "IRONMAN_MAX" then
        if not eligibility.startedAtOrBelow10 then
            return 0, "Started above level 10"
        end
        if not IsIronmanPreset(InitialDetectedPreset(eligibility)) or not IsIronmanRules(eligibility.initialRules) then
            return 0, "Not an Ironman start"
        end
        if AnyRuleAmendmentApplied(eligibility) then
            return 0, "Rules amended"
        end
        return math.min(currentLevel / maxLevel, 1), "Ironman: " .. tostring(currentLevel) .. " / " .. tostring(maxLevel)
    end

    if definition.progressKind == "CAMERA_MAX" then
        if not eligibility.startedAtOrBelow10 then
            return 0, "Started above level 10"
        end
        if RuleChanged(eligibility, "actionCam") then
            return 0, "Camera rule changed"
        end
        if not IsCameraEnforcedRules(eligibility.initialRules) then
            return 0, "No camera mode enforced at start"
        end
        if not IsCameraEnforcedRules(db and db.run and db.run.ruleset) then
            return 0, "Camera enforcement removed"
        end
        return math.min(currentLevel / maxLevel, 1), "Camera run: " .. tostring(currentLevel) .. " / " .. tostring(maxLevel)
    end

    if definition.progressKind == "CAMERA_IRONMAN_NO_FLIGHT_PATHS_MAX" then
        if not eligibility.startedAtOrBelow10 then
            return 0, "Started above level 10"
        end
        if InitialDetectedPreset(eligibility) ~= "IRON_VIGIL" or not IsIronmanRules(eligibility.initialRules) then
            return 0, "Not an Iron Vigil start"
        end
        if not IsCameraEnforcedRules(eligibility.initialRules) then
            return 0, "No camera mode enforced at start"
        end
        if not RequirementStayedLocked(eligibility, db and db.run and db.run.ruleset, "flightPaths") then
            return 0, "Flight Paths not disallowed"
        end
        if AnyRuleAmendmentApplied(eligibility) then
            return 0, "Rules amended"
        end
        if not IsCameraEnforcedRules(db and db.run and db.run.ruleset) then
            return 0, "Camera enforcement removed"
        end
        return math.min(currentLevel / maxLevel, 1), "Iron Vigil: " .. tostring(currentLevel) .. " / " .. tostring(maxLevel)
    end

    if definition.progressKind == "RULE_UNCHANGED_MAX" then
        if not eligibility.startedAtOrBelow10 then
            return 0, "Started above level 10"
        end
        if AnyRuleAmendmentApplied(eligibility) then
            return 0, "Rules amended"
        end
        return math.min(currentLevel / maxLevel, 1), "No amendments: " .. tostring(currentLevel) .. " / " .. tostring(maxLevel)
    end

    if definition.progressKind == "GROUPED_MAX" then
        if not eligibility.startedAtOrBelow10 then
            return 0, "Started above level 10"
        end
        if not eligibility.initialRules or eligibility.initialRules.groupingMode ~= "SYNCED_GROUP_ALLOWED" then
            return 0, "Not started in group mode"
        end
        return math.min(currentLevel / maxLevel, 1), "Group run: " .. tostring(currentLevel) .. " / " .. tostring(maxLevel)
    end

    if definition.progressKind == "CLASS_MAX" then
        if not eligibility.startedAtOrBelow10 then
            return 0, "Started above level 10"
        end

        local currentClass = tostring(db and db.character and db.character.class or "")
        if currentClass ~= tostring(definition.ruleName or "") then
            local spec = CLASS_MAX_BY_FILE[definition.ruleName]
            return 0, spec and ("Play a " .. spec.label) or "Different class active"
        end

        local spec = CLASS_MAX_BY_FILE[currentClass]
        return math.min(currentLevel / maxLevel, 1), tostring(spec and spec.label or "Class") .. ": " .. tostring(currentLevel) .. " / " .. tostring(maxLevel)
    end

    if definition.progressKind == "GEAR_QUALITY_MAX" then
        if not eligibility.startedAtOrBelow10 then
            return 0, "Started above level 10"
        end
        if not eligibility.initialRules or eligibility.initialRules.gearQuality ~= definition.ruleName then
            return 0, "Wrong gear quality at start"
        end
        if eligibility.ruleChanges and eligibility.ruleChanges.gearQuality then
            return 0, "Gear quality changed"
        end
        if RuleChanged(eligibility, "selfCraftedGearAllowed") then
            return 0, "Self-crafted exemption changed"
        end
        if eligibility.initialRules and eligibility.initialRules.selfCraftedGearAllowed == true then
            return 0, "Self-crafted exemption enabled"
        end
        if db and db.run and db.run.ruleset and db.run.ruleset.selfCraftedGearAllowed == true then
            return 0, "Self-crafted exemption enabled"
        end
        return math.min(currentLevel / maxLevel, 1), "Eligible: " .. tostring(currentLevel) .. " / " .. tostring(maxLevel)
    end

    if definition.progressKind == "GEAR_QUALITY_CRAFTED_MAX" then
        if not eligibility.startedAtOrBelow10 then
            return 0, "Started above level 10"
        end
        if not eligibility.initialRules or eligibility.initialRules.gearQuality ~= definition.ruleName then
            return 0, "Wrong gear quality at start"
        end
        if eligibility.ruleChanges and eligibility.ruleChanges.gearQuality then
            return 0, "Gear quality changed"
        end
        if RuleChanged(eligibility, "selfCraftedGearAllowed") then
            return 0, "Self-crafted exemption changed"
        end
        if not (eligibility.initialRules and eligibility.initialRules.selfCraftedGearAllowed == true) then
            return 0, "Self-crafted exemption not enabled at start"
        end
        if not (db and db.run and db.run.ruleset and db.run.ruleset.selfCraftedGearAllowed == true) then
            return 0, "Self-crafted exemption disabled"
        end
        return math.min(currentLevel / maxLevel, 1), "Self-forged: " .. tostring(currentLevel) .. " / " .. tostring(maxLevel)
    end

    if definition.progressKind == "RULE_MAX" then
        if not eligibility.startedAtOrBelow10 then
            return 0, "Started above level 10"
        end
        if eligibility.ruleChanges and eligibility.ruleChanges[definition.ruleName] then
            return 0, "Rule changed"
        end
        if eligibility.ruleViolations and eligibility.ruleViolations[definition.ruleName] then
            return 0, "Rule violated"
        end
        if not eligibility.initialRules or not IsDisallowed(eligibility.initialRules[definition.ruleName]) then
            return 0, "Not restricted at start"
        end
        if not IsDisallowed(db and db.run and db.run.ruleset and db.run.ruleset[definition.ruleName]) then
            return 0, "Restriction removed"
        end
        return math.min(currentLevel / maxLevel, 1), "Eligible: " .. tostring(currentLevel) .. " / " .. tostring(maxLevel)
    end

    return 0, "Not earned"
end

function SC:GetAchievementRows()
    local rows = {}
    local charEarned = GetCharDB().earned
    local accountEarned = GetAccountDB().earned

    for _, definition in ipairs(self:GetAchievementDefinitions()) do
        if charEarned[definition.id] and not accountEarned[definition.id] then
            accountEarned[definition.id] = charEarned[definition.id]
            accountEarned[definition.id].scope = "ACCOUNT"
        end

        local earned = accountEarned[definition.id]
        local progressValue, progressText = BuildProgress(definition, earned)
        table.insert(rows, {
            id = definition.id,
            scope = "ACCOUNT",
            category = definition.category,
            name = definition.name,
            description = definition.description,
            progressKind = definition.progressKind,
            target = definition.target,
            ruleName = definition.ruleName,
            earned = earned ~= nil,
            earnedAt = earned and earned.earnedAt or nil,
            progressValue = progressValue,
            progressText = progressText,
            sortOrder = definition.sortOrder,
        })
    end

    local award = self.GetCompletionAward and self:GetCompletionAward() or nil
    if award then
        table.insert(rows, {
            id = "completion_award_" .. tostring(award.id or award.runId or "latest"),
            scope = "CHARACTER",
            category = "Award",
            name = "Max-Level Award",
            description = "Reopen the parchment award for " .. tostring(award.characterName or "this character") .. ".",
            progressKind = "COMPLETION_AWARD",
            earned = true,
            earnedAt = award.completedAt,
            progressValue = 1,
            progressText = "Click to view award",
            sortOrder = -1000,
            isCompletionAward = true,
        })
    end

    table.sort(rows, function(left, right)
        if left.earned ~= right.earned then
            return not left.earned
        end

        if left.earned and right.earned then
            return (left.earnedAt or 0) > (right.earnedAt or 0)
        end

        local leftProgress = tonumber(left.progressValue or 0) or 0
        local rightProgress = tonumber(right.progressValue or 0) or 0
        local leftStarted = leftProgress > 0
        local rightStarted = rightProgress > 0

        if leftStarted ~= rightStarted then
            return leftStarted
        end

        if leftStarted and leftProgress ~= rightProgress then
            return leftProgress > rightProgress
        end

        local leftOrder = tonumber(left.sortOrder or 0) or 0
        local rightOrder = tonumber(right.sortOrder or 0) or 0
        if leftOrder ~= rightOrder then
            return leftOrder < rightOrder
        end

        return tostring(left.name or "") < tostring(right.name or "")
    end)

    return rows
end

function SC:Achievements_OnRunStart(runOptions)
    local db = self.db or SoftcoreDB
    if not db or not db.run or not db.run.active then return end

    local achievements = GetCharDB()
    local startLevel = tonumber(db.run.startLevel or db.character.level or 0) or 0
    local preset = (self.DetectRulesetPreset and self:DetectRulesetPreset(db.run.ruleset)) or "CUSTOM"

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

    self:Achievements_OnLevelChanged(db.character.level)
end

function SC:Achievements_OnLevelChanged(level)
    local db = self.db or SoftcoreDB
    if not IsLocalActiveAndValid(db) then return end

    local eligibility = CurrentEligibility()
    level = tonumber(level or db.character.level or 0) or 0
    local maxLevel = GetMaxLevel()
    if not eligibility then
        local fallbackStartLevel = tonumber(db.run and db.run.startLevel or 0) or 0
        if level >= maxLevel and fallbackStartLevel < maxLevel and self.CompleteRunAtMaxLevel then
            self:CompleteRunAtMaxLevel(maxLevel)
        end
        return
    end
    if eligibility.failed then return end

    local startLevel = tonumber(eligibility.startLevel or db.run.startLevel or 0) or 0

    for milestone = 10, maxLevel, 10 do
        if eligibility.startedAtOrBelow10 and level >= milestone and milestone >= startLevel then
            Earn("char_level_" .. tostring(milestone), "CHARACTER", "Still Breathing: " .. tostring(milestone))
        end
    end

    for milestone = 30, maxLevel, 10 do
        if eligibility.startedAtOrBelow10 and level >= milestone and milestone >= startLevel and not eligibility.hadViolation then
            Earn("char_clean_level_" .. tostring(milestone), "CHARACTER", CLEAN_LEVEL_NAMES[milestone] or ("Clean Climb: " .. tostring(milestone)))
        end
    end

    local reachedMaxFromLeveling = level >= maxLevel and startLevel < maxLevel
    if level < maxLevel or not CanEarnMaxRunAchievement(eligibility) then
        if reachedMaxFromLeveling and self.CompleteRunAtMaxLevel then
            self:CompleteRunAtMaxLevel(maxLevel)
        end
        return
    end

    Earn("char_max_level", "CHARACTER", "Softcore Champion")

    local currentClass = tostring(db.character and db.character.class or "")
    local classSpec = CLASS_MAX_BY_FILE[currentClass]
    if classSpec then
        Earn("char_max_class_" .. string.lower(currentClass), "CHARACTER", classSpec.name)
    end

    if not eligibility.hadViolation then
        Earn("char_clean_max_level", "CHARACTER", "Clean Finish")
    end

    if IsChefSpecialPreset(InitialDetectedPreset(eligibility)) and not AnyRuleAmendmentApplied(eligibility) then
        Earn("char_chef_special_max_level", "CHARACTER", "Chef's Table")
    end

    if IsIronmanPreset(InitialDetectedPreset(eligibility)) and IsIronmanRules(eligibility.initialRules) and not AnyRuleAmendmentApplied(eligibility) then
        Earn("char_ironman_max_level", "CHARACTER", "Iron Will")
    end

    if IsCameraEnforcedRules(eligibility.initialRules) and IsCameraEnforcedRules(db.run.ruleset) then
        if not RuleChanged(eligibility, "actionCam") then
            Earn("char_camera_max_level", "CHARACTER", "Locked Perspective")
        end
    end

    if InitialDetectedPreset(eligibility) == "IRON_VIGIL"
       and IsIronmanRules(eligibility.initialRules)
       and IsCameraEnforcedRules(eligibility.initialRules)
       and IsCameraEnforcedRules(db.run.ruleset)
       and RequirementStayedLocked(eligibility, db.run.ruleset, "flightPaths")
       and not RuleChanged(eligibility, "actionCam")
       and not AnyRuleAmendmentApplied(eligibility) then
        Earn("char_camera_ironman_no_flight_paths_max_level", "CHARACTER", "Iron Vigil")
    end

    if not AnyRuleAmendmentApplied(eligibility) then
        Earn("char_original_terms", "CHARACTER", "Original Terms")
    end

    if eligibility.initialRules and eligibility.initialRules.groupingMode == "SYNCED_GROUP_ALLOWED" then
        Earn("char_party_survivor", "CHARACTER", "Party Survivor")
    end

    if eligibility.initialRules and eligibility.initialRules.gearQuality == "WHITE_GRAY_ONLY"
       and not (eligibility.ruleChanges and eligibility.ruleChanges.gearQuality)
       and not RuleChanged(eligibility, "selfCraftedGearAllowed")
       and eligibility.initialRules.selfCraftedGearAllowed ~= true
       and db.run.ruleset.selfCraftedGearAllowed ~= true then
        Earn("char_white_knuckles", "CHARACTER", "White Knuckles")
    end

    if eligibility.initialRules and eligibility.initialRules.gearQuality == "WHITE_GRAY_ONLY"
       and not (eligibility.ruleChanges and eligibility.ruleChanges.gearQuality)
       and not RuleChanged(eligibility, "selfCraftedGearAllowed")
       and eligibility.initialRules.selfCraftedGearAllowed == true
       and db.run.ruleset.selfCraftedGearAllowed == true then
        Earn("char_self_forged", "CHARACTER", "Self-Forged")
    end

    for _, spec in ipairs(RESTRICTION_RULES) do
        if RequirementStayedLocked(eligibility, db.run.ruleset, spec.rule) then
            Earn("char_max_" .. spec.id, "CHARACTER", spec.name)
        end
    end

    if self.CompleteRunAtMaxLevel then
        self:CompleteRunAtMaxLevel(maxLevel)
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
    eligibility.anyAmendmentApplied = true
    if not IsPlayerFacingRuleChange(ruleName, oldValue, newValue, eligibility) then return end

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
