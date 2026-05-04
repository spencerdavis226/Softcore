-- Exact run-label profiles. Labels are derived from current rules only.

local SC = Softcore

local DISALLOWED_OUTCOME = "WARNING"
local RUN_SUFFIX = " Run"

local ECONOMY_RULE_KEYS = { "auctionHouse", "mailbox", "trade", "bank", "warbandBank", "guildBank" }
local MOVEMENT_RULE_KEYS = { "mounts", "flying", "flightPaths" }
local BOOST_RULE_KEYS = { "heirlooms", "enchants", "consumables" }

local SEVERITY_RULE_KEYS = {
    auctionHouse = true,
    mailbox = true,
    trade = true,
    mounts = true,
    flying = true,
    flightPaths = true,
    maxLevelGap = true,
    dungeonRepeat = true,
    heirlooms = true,
    enchants = true,
    bank = true,
    warbandBank = true,
    guildBank = true,
    consumables = true,
    instancedPvP = true,
    actionCam = true,
}

local RUN_LABEL_RULE_KEYS = {
    "groupingMode",
    "auctionHouse",
    "mailbox",
    "trade",
    "bank",
    "warbandBank",
    "guildBank",
    "mounts",
    "flying",
    "flightPaths",
    "maxLevelGap",
    "dungeonRepeat",
    "gearQuality",
    "selfCraftedGearAllowed",
    "heirlooms",
    "enchants",
    "consumables",
    "instancedPvP",
    "actionCam",
}

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

local function ApplyGroupingRules(rules)
    if SC.ApplyGroupingMode then
        return SC:ApplyGroupingMode(rules)
    end
    return rules
end

local function GetBaseRuleset()
    if SC.GetDefaultRuleset then
        return SC:GetDefaultRuleset()
    end
    return {}
end

local function SetRules(rules, keys, value)
    for _, key in ipairs(keys) do
        rules[key] = value
    end
end

local function ApplyPresetProfile(rules, preset)
    local ironman = preset == "IRONMAN" or preset == "IRON_VIGIL"
    local ironVigil = preset == "IRON_VIGIL"
    local chef = preset == "CHEF_SPECIAL"
    local selectedCameraMode = nil

    rules.groupingMode = ironman and "SOLO_SELF_FOUND" or "SYNCED_GROUP_ALLOWED"
    rules.gearQuality = (ironman or chef) and "WHITE_GRAY_ONLY" or "ALLOWED"
    if ironman then
        rules.selfCraftedGearAllowed = false
    elseif chef then
        rules.selfCraftedGearAllowed = true
    else
        rules.selfCraftedGearAllowed = false
    end
    rules.maxLevelGap = "ALLOWED"
    rules.maxLevelGapValue = 3
    rules.heirlooms = DISALLOWED_OUTCOME
    rules.enchants = ironman and DISALLOWED_OUTCOME or "ALLOWED"
    rules.dungeonRepeat = ironman and DISALLOWED_OUTCOME or "ALLOWED"
    rules.instanceWithUnsyncedPlayers = "ALLOWED"
    rules.unsyncedMembers = "ALLOWED"

    SetRules(rules, ECONOMY_RULE_KEYS, DISALLOWED_OUTCOME)
    SetRules(rules, MOVEMENT_RULE_KEYS, ironman and DISALLOWED_OUTCOME or "ALLOWED")
    if ironman then
        rules.flightPaths = "ALLOWED"
    end
    if ironVigil then
        rules.flightPaths = DISALLOWED_OUTCOME
    end

    rules.consumables = ironman and DISALLOWED_OUTCOME or "ALLOWED"
    rules.instancedPvP = DISALLOWED_OUTCOME
    rules.actionCam = "ALLOWED"

    if chef then
        rules.auctionHouse = DISALLOWED_OUTCOME
        rules.mailbox = DISALLOWED_OUTCOME
        rules.trade = "ALLOWED"
        rules.bank = "ALLOWED"
        rules.warbandBank = DISALLOWED_OUTCOME
        rules.guildBank = DISALLOWED_OUTCOME
        rules.mounts = "ALLOWED"
        rules.flying = DISALLOWED_OUTCOME
        rules.flightPaths = "ALLOWED"
        rules.heirlooms = DISALLOWED_OUTCOME
        rules.enchants = "ALLOWED"
        rules.consumables = "ALLOWED"
        rules.dungeonRepeat = "ALLOWED"
        rules.instancedPvP = DISALLOWED_OUTCOME
        rules.actionCam = DISALLOWED_OUTCOME
        selectedCameraMode = "CINEMATIC"
    elseif not ironman then
        SetRules(rules, ECONOMY_RULE_KEYS, "ALLOWED")
        rules.heirlooms = "ALLOWED"
        rules.selfCraftedGearAllowed = false
    end

    if ironVigil then
        rules.actionCam = DISALLOWED_OUTCOME
        selectedCameraMode = "CINEMATIC"
    end

    rules.maxDeaths = false
    rules.maxDeathsValue = 3
    rules.achievementPreset = preset

    ApplyGroupingRules(rules)
    return selectedCameraMode
end

function SC:ConfigureRulesetForPreset(rules, preset)
    if type(rules) ~= "table" then
        return nil
    end

    for key in pairs(rules) do
        rules[key] = nil
    end
    for key, value in pairs(GetBaseRuleset()) do
        rules[key] = CopyTable(value)
    end

    return ApplyPresetProfile(rules, preset)
end

local function BuildPresetRuleset(preset)
    local rules = GetBaseRuleset()
    ApplyPresetProfile(rules, preset)
    return rules
end

local function BuildCasualVariant(overrides)
    local rules = BuildPresetRuleset("CASUAL")
    for key, value in pairs(overrides or {}) do
        rules[key] = value
    end
    ApplyGroupingRules(rules)
    rules.achievementPreset = nil
    return rules
end

local function BuildAllRestrictionsRuleset()
    local rules = BuildCasualVariant({
        gearQuality = "WHITE_GRAY_ONLY",
        selfCraftedGearAllowed = false,
        maxLevelGap = DISALLOWED_OUTCOME,
        dungeonRepeat = DISALLOWED_OUTCOME,
        instanceWithUnsyncedPlayers = DISALLOWED_OUTCOME,
        unsyncedMembers = DISALLOWED_OUTCOME,
        instancedPvP = DISALLOWED_OUTCOME,
        actionCam = DISALLOWED_OUTCOME,
    })
    SetRules(rules, ECONOMY_RULE_KEYS, DISALLOWED_OUTCOME)
    SetRules(rules, MOVEMENT_RULE_KEYS, DISALLOWED_OUTCOME)
    SetRules(rules, BOOST_RULE_KEYS, DISALLOWED_OUTCOME)
    ApplyGroupingRules(rules)
    return rules
end

local RUN_LABEL_SPECS = {
    { label = "Casual", preset = "CASUAL", rules = BuildPresetRuleset("CASUAL") },
    { label = "Chef's Special", preset = "CHEF_SPECIAL", rules = BuildPresetRuleset("CHEF_SPECIAL") },
    { label = "Ironman", preset = "IRONMAN", rules = BuildPresetRuleset("IRONMAN") },
    { label = "Iron Vigil", preset = "IRON_VIGIL", rules = BuildPresetRuleset("IRON_VIGIL") },

    { label = "Party Animal", rules = BuildCasualVariant({ instancedPvP = "ALLOWED" }) },
    { label = "Mind the Gap", rules = BuildCasualVariant({ maxLevelGap = DISALLOWED_OUTCOME }) },
    { label = "Green Machine", rules = BuildCasualVariant({ gearQuality = "GREEN_OR_LOWER" }) },
    { label = "Blue Period", rules = BuildCasualVariant({ gearQuality = "BLUE_OR_LOWER" }) },
    { label = "White Knuckles", rules = BuildCasualVariant({ gearQuality = "WHITE_GRAY_ONLY", selfCraftedGearAllowed = false }) },
    { label = "Self-Forged", rules = BuildCasualVariant({ gearQuality = "WHITE_GRAY_ONLY", selfCraftedGearAllowed = true }) },
    { label = "No Heir Today", rules = BuildCasualVariant({ heirlooms = DISALLOWED_OUTCOME }) },
    { label = "No Enchant Intended", rules = BuildCasualVariant({ enchants = DISALLOWED_OUTCOME }) },
    { label = "Flaskless Gordon", rules = BuildCasualVariant({ consumables = DISALLOWED_OUTCOME }) },
    { label = "Dungeon Monogamist", rules = BuildCasualVariant({ dungeonRepeat = DISALLOWED_OUTCOME }) },
    { label = "Camera Shy", rules = BuildCasualVariant({ actionCam = DISALLOWED_OUTCOME }) },
    { label = "No Fly Zone", rules = BuildCasualVariant({ flying = DISALLOWED_OUTCOME }) },
    { label = "Flight Pathological", rules = BuildCasualVariant({ flightPaths = DISALLOWED_OUTCOME }) },
    { label = "Mount Rushless", rules = BuildCasualVariant({ mounts = DISALLOWED_OUTCOME }) },
    { label = "Walking Simulator", rules = BuildCasualVariant({ mounts = DISALLOWED_OUTCOME, flying = DISALLOWED_OUTCOME, flightPaths = DISALLOWED_OUTCOME }) },
    { label = "Auction House Arrest", rules = BuildCasualVariant({ auctionHouse = DISALLOWED_OUTCOME }) },
    { label = "Mailbox Hermit", rules = BuildCasualVariant({ mailbox = DISALLOWED_OUTCOME }) },
    { label = "Trade Chat Survivor", rules = BuildCasualVariant({ trade = DISALLOWED_OUTCOME }) },
    { label = "Bank Vault", rules = BuildCasualVariant({ bank = DISALLOWED_OUTCOME, warbandBank = DISALLOWED_OUTCOME, guildBank = DISALLOWED_OUTCOME }) },
    { label = "Warband Lockbox", rules = BuildCasualVariant({ warbandBank = DISALLOWED_OUTCOME }) },
    { label = "Guildless Wanderer", rules = BuildCasualVariant({ guildBank = DISALLOWED_OUTCOME }) },
    { label = "Market Goblin", rules = BuildCasualVariant({ gearQuality = "GREEN_OR_LOWER", selfCraftedGearAllowed = true }) },
    { label = "Solo Yolo", rules = BuildCasualVariant({ groupingMode = "SOLO_SELF_FOUND" }) },
    {
        label = "Alone Ranger",
        rules = BuildCasualVariant({
            groupingMode = "SOLO_SELF_FOUND",
            auctionHouse = DISALLOWED_OUTCOME,
            mailbox = DISALLOWED_OUTCOME,
            trade = DISALLOWED_OUTCOME,
            bank = DISALLOWED_OUTCOME,
            warbandBank = DISALLOWED_OUTCOME,
            guildBank = DISALLOWED_OUTCOME,
        }),
    },
    { label = "Oops All Restrictions", rules = BuildAllRestrictionsRuleset() },
}

local function NormalizeRulesetForRunLabel(ruleset)
    if type(ruleset) ~= "table" then
        return nil
    end

    local normalized = GetBaseRuleset()
    for key, value in pairs(ruleset) do
        normalized[key] = CopyTable(value)
    end
    ApplyGroupingRules(normalized)
    return normalized
end

local function CanonicalSeverityValue(value)
    if value == "ALLOWED" or value == "LOG_ONLY" then
        return "ALLOWED"
    end
    if value == nil or value == false then
        return "ALLOWED"
    end
    return "RESTRICTED"
end

local function CanonicalRunLabelValue(ruleset, key)
    if key == "selfCraftedGearAllowed" then
        if not ruleset or ruleset.gearQuality == nil or ruleset.gearQuality == "ALLOWED" then
            return "IGNORED"
        end
        return ruleset.selfCraftedGearAllowed == true
    end

    if key == "maxLevelGapValue" then
        if CanonicalSeverityValue(ruleset and ruleset.maxLevelGap) == "ALLOWED" then
            return "IGNORED"
        end
        local value = tonumber(ruleset and ruleset.maxLevelGapValue)
        return value or tostring(ruleset and ruleset.maxLevelGapValue)
    end

    if SEVERITY_RULE_KEYS[key] then
        return CanonicalSeverityValue(ruleset and ruleset[key])
    end

    return ruleset and ruleset[key]
end

local function RulesetsMatch(a, b)
    if not a or not b then
        return false
    end

    for _, key in ipairs(RUN_LABEL_RULE_KEYS) do
        if CanonicalRunLabelValue(a, key) ~= CanonicalRunLabelValue(b, key) then
            return false
        end
    end
    return true
end

local function FormatRunLabel(label)
    label = tostring(label or "Custom")
    if string.sub(label, -#RUN_SUFFIX) == RUN_SUFFIX then
        return label
    end
    return label .. RUN_SUFFIX
end

local function FormatDebugValue(value)
    if value == nil then
        return "nil"
    end
    return tostring(value)
end

function SC:GetRunLabelDebugLines(ruleset)
    local lines = {}
    local label, preset = self:GetRunLabelForRuleset(ruleset)
    table.insert(lines, "run label: " .. tostring(label or "Custom Run") .. " preset=" .. tostring(preset or "CUSTOM") .. " source=RunLabels.lua")

    local normalized = NormalizeRulesetForRunLabel(ruleset)
    if not normalized then
        table.insert(lines, "no ruleset table available")
        return lines
    end

    for index = 1, 4 do
        local spec = RUN_LABEL_SPECS[index]
        if spec then
            local mismatches = {}
            for _, key in ipairs(RUN_LABEL_RULE_KEYS) do
                local actual = CanonicalRunLabelValue(normalized, key)
                local expected = CanonicalRunLabelValue(spec.rules, key)
                if actual ~= expected then
                    table.insert(mismatches, key .. "=" .. FormatDebugValue(actual) .. " expected " .. FormatDebugValue(expected))
                end
            end

            if #mismatches == 0 then
                table.insert(lines, FormatRunLabel(spec.label) .. ": match")
            elseif not preset then
                local preview = {}
                for i = 1, math.min(#mismatches, 6) do
                    preview[i] = mismatches[i]
                end
                table.insert(lines, FormatRunLabel(spec.label) .. ": " .. tostring(#mismatches) .. " mismatch(es): " .. table.concat(preview, "; "))
            end
        end
    end

    return lines
end

function SC:GetRunLabelForRuleset(ruleset)
    local normalized = NormalizeRulesetForRunLabel(ruleset)
    if not normalized then
        return nil
    end

    for _, spec in ipairs(RUN_LABEL_SPECS) do
        if RulesetsMatch(normalized, spec.rules) then
            return FormatRunLabel(spec.label), spec.preset
        end
    end
    return nil
end

function SC:DetectRulesetPreset(ruleset)
    local _, preset = self:GetRunLabelForRuleset(ruleset)
    return preset
end

function SC:GetPresetRunLabel(preset)
    for _, spec in ipairs(RUN_LABEL_SPECS) do
        if spec.preset == preset then
            return FormatRunLabel(spec.label)
        end
    end
    return nil
end

function SC:GetRunDisplayName(run, fallback)
    local ruleset = run and run.ruleset
    local label = self:GetRunLabelForRuleset(ruleset)
    if label then
        return label
    end
    if type(ruleset) == "table" then
        return "Custom Run"
    end
    return fallback or "Custom Run"
end
