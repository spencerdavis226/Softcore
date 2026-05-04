-- Item and group integrity checks for the current local run.

local SC = Softcore

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r " .. tostring(message))
end

local GEAR_SCAN_THROTTLE = 10
local GEAR_VIOLATION_THROTTLE = 60
local LEVEL_GAP_THROTTLE = 20
local GROUP_PROGRESS_VIOLATION_THROTTLE = 60

local lastGearScanAt = 0
local lastPendingGearRescanAt = 0
local lastLevelGapCheckAt = 0
local currentInstanceName
local gearViolationTimes = {}
local groupProgressViolationTimes = {}

local EQUIPMENT_SLOTS = {}

local function AddEquipmentSlot(slotId)
    slotId = tonumber(slotId)
    if not slotId or slotId <= 0 then return end
    for _, existing in ipairs(EQUIPMENT_SLOTS) do
        if existing == slotId then return end
    end
    table.insert(EQUIPMENT_SLOTS, slotId)
end

for _, slotId in ipairs({
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
    11, 12, 13, 14, 15, 16, 17, 19,
    20, 21, 22, 23, 24, 25,
}) do
    AddEquipmentSlot(slotId)
end

for _, globalName in ipairs({
    "INVSLOT_AMMO",
    "INVSLOT_HEAD",
    "INVSLOT_NECK",
    "INVSLOT_SHOULDER",
    "INVSLOT_BODY",
    "INVSLOT_CHEST",
    "INVSLOT_WAIST",
    "INVSLOT_LEGS",
    "INVSLOT_FEET",
    "INVSLOT_WRIST",
    "INVSLOT_HAND",
    "INVSLOT_FINGER1",
    "INVSLOT_FINGER2",
    "INVSLOT_TRINKET1",
    "INVSLOT_TRINKET2",
    "INVSLOT_BACK",
    "INVSLOT_MAINHAND",
    "INVSLOT_OFFHAND",
    "INVSLOT_RANGED",
    "INVSLOT_TABARD",
    "INVSLOT_PROFESSION_TOOL",
    "INVSLOT_PROFESSION_GEAR_1",
    "INVSLOT_PROFESSION_GEAR_2",
    "INVSLOT_PROFESSION_GEAR_3",
}) do
    AddEquipmentSlot(_G[globalName])
end

local tooltipScanner = nil
local function GetTooltipScanner()
    if not tooltipScanner then
        tooltipScanner = CreateFrame("GameTooltip", "SoftcoreGearScanner", nil, "GameTooltipTemplate")
        tooltipScanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return tooltipScanner
end

local function Trim(text)
    return string.gsub(tostring(text or ""), "^%s*(.-)%s*$", "%1")
end

local function NormalizeTooltipText(text)
    text = tostring(text or "")
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    return Trim(text)
end

local function AddCandidateName(names, value)
    value = Trim(value)
    if value ~= "" then
        names[value] = true
    end
end

local function GetPlayerCraftingNames()
    local names = {}
    local playerName = UnitName("player")
    local fullName, fullRealm = UnitFullName("player")
    local realm = fullRealm
    if not realm or realm == "" then
        realm = GetRealmName and GetRealmName() or nil
    end

    AddCandidateName(names, playerName)
    AddCandidateName(names, fullName)
    if fullName and realm and realm ~= "" then
        AddCandidateName(names, fullName .. "-" .. realm)
        AddCandidateName(names, fullName .. " - " .. realm)
    elseif playerName and realm and realm ~= "" then
        AddCandidateName(names, playerName .. "-" .. realm)
        AddCandidateName(names, playerName .. " - " .. realm)
    end

    return names
end

local function AddCraftedByMarker(markers, formatText, playerName)
    if not formatText or formatText == "" or not playerName or playerName == "" then
        return
    end

    local ok, marker = pcall(string.format, formatText, playerName)
    if ok and marker and marker ~= "" then
        markers[NormalizeTooltipText(marker)] = true
    end
end

local function GetSelfCraftedTooltipMarkers()
    local markers = {}
    local formats = {
        _G.ITEM_CREATED_BY,
        "Made by %s",
        "Crafted by %s",
        "Created by %s",
    }

    for playerName in pairs(GetPlayerCraftingNames()) do
        for _, formatText in ipairs(formats) do
            AddCraftedByMarker(markers, formatText, playerName)
        end
    end

    return markers
end

local function IsSelfCraftedTooltipLine(text)
    local normalized = NormalizeTooltipText(text)
    if normalized == "" then
        return false
    end

    return GetSelfCraftedTooltipMarkers()[normalized] == true
end

local function IsItemSelfCrafted(slotId)
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local data = C_TooltipInfo.GetInventoryItem("player", slotId)
        if data and data.lines then
            for _, line in ipairs(data.lines) do
                if line.leftText and IsSelfCraftedTooltipLine(line.leftText) then
                    return true
                end
            end
            return false
        end
    end
    local scanner = GetTooltipScanner()
    scanner:ClearLines()
    scanner:SetInventoryItem("player", slotId)
    for i = 1, scanner:NumLines() do
        local line = _G["SoftcoreGearScannerTextLeft" .. i]
        if line and IsSelfCraftedTooltipLine(line:GetText() or "") then
            return true
        end
    end
    return false
end

local QUALITY_NAMES = {
    [0] = "Poor",
    [1] = "Common",
    [2] = "Uncommon",
    [3] = "Rare",
    [4] = "Epic",
    [5] = "Legendary",
    [6] = "Artifact",
    [7] = "Heirloom",
}

local function GetDB()
    return SC.db or SoftcoreDB
end

local function IsRunActive()
    local db = GetDB()
    if not db or not db.run or not db.run.active then
        return false
    end

    return not (SC.IsLocalCharacterFailed and SC:IsLocalCharacterFailed())
end

local function GetItemInfoCompat(itemLink)
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(itemLink)
    end

    return GetItemInfo(itemLink)
end

local function GetPermanentEnchantId(itemLink)
    local itemString = string.match(tostring(itemLink or ""), "item:([^|]+)")
    if not itemString then return nil end

    local fields = {}
    for field in string.gmatch(itemString .. ":", "([^:]*):") do
        table.insert(fields, field)
    end

    local enchantId = tonumber(fields[2] or 0) or 0
    if enchantId == 0 then
        return nil
    end

    return enchantId
end

local function GetEquippedItems()
    local items = {}

    for _, slotId in ipairs(EQUIPMENT_SLOTS) do
        local itemLink = GetInventoryItemLink("player", slotId)
        if itemLink then
            local name, _, quality = GetItemInfoCompat(itemLink)
            quality = GetInventoryItemQuality("player", slotId) or quality
            table.insert(items, {
                slotId = slotId,
                link = itemLink,
                name = name or itemLink,
                quality = quality,
                qualityPending = quality == nil,
                enchantId = GetPermanentEnchantId(itemLink),
            })
        end
    end

    return items
end

local function IsGearQualityInvalid(ruleValue, quality)
    if not quality or ruleValue == "ALLOWED" then
        return false
    end

    if ruleValue == "WHITE_GRAY_ONLY" then
        return quality > 1
    end

    if ruleValue == "COMMON_OR_UNCOMMON" then
        return quality > 2
    end

    if ruleValue == "GREEN_OR_LOWER" then
        return quality > 2
    end

    if ruleValue == "BLUE_OR_LOWER" then
        return quality > 3
    end

    if ruleValue == "EPIC_OR_LOWER" then
        return quality > 4
    end

    if ruleValue == "NO_EPICS" then
        return quality >= 4
    end

    return false
end

local function ShouldThrottle(key, seconds)
    local now = time()

    if now - (gearViolationTimes[key] or 0) < seconds then
        return true
    end

    gearViolationTimes[key] = now
    return false
end

local function HasActiveLocalViolation(ruleName, detail)
    local db = GetDB()
    local playerKey = SC:GetPlayerKey()

    for _, violation in ipairs(db and db.violations or {}) do
        if violation.status ~= "CLEARED"
            and violation.shared ~= true
            and violation.playerKey == playerKey
            and violation.type == ruleName
            and violation.detail == detail then
            return true
        end
    end

    return false
end

local function BuildEquippedItemViolationDetail(invalid)
    local item = invalid and invalid.item
    local link = item and item.link

    if invalid.rule == "heirlooms" then
        return "Heirloom equipped: " .. tostring(link)
    end

    if invalid.rule == "enchants" then
        return "Enchanted item equipped: " .. tostring(link)
    end

    return "Invalid equipped item: " .. tostring(link)
end

function SC:ResetGearScanTracking()
    lastGearScanAt = 0
    lastPendingGearRescanAt = 0
    gearViolationTimes = {}
    groupProgressViolationTimes = {}
end

function SC:GetInvalidEquippedItems()
    local invalid = {}
    local gearRule = self:GetRule("gearQuality")

    for _, item in ipairs(GetEquippedItems()) do
        if item.quality == 7 then
            if self:GetRule("heirlooms") ~= "ALLOWED" then
                table.insert(invalid, {
                    rule = "heirlooms",
                    item = item,
                    reason = "Heirloom equipped",
                })
            end
        elseif IsGearQualityInvalid(gearRule, item.quality) then
            local selfCraftedAllowed = self:GetRule("selfCraftedGearAllowed") == true
            if not (selfCraftedAllowed and IsItemSelfCrafted(item.slotId)) then
                table.insert(invalid, {
                    rule = "gearQuality",
                    item = item,
                    reason = "Disallowed quality for " .. tostring(gearRule),
                })
            end
        end

        if item.enchantId and self:GetRule("enchants") ~= "ALLOWED" then
            table.insert(invalid, {
                rule = "enchants",
                item = item,
                reason = "Permanent enchant applied",
            })
        end
    end

    return invalid
end

function SC:ScanEquippedGear(force, options)
    if not IsRunActive() then
        return
    end
    options = options or {}

    local now = time()
    if not force and now - lastGearScanAt < GEAR_SCAN_THROTTLE then
        return
    end
    lastGearScanAt = now

    local pendingItemInfo = false
    for _, item in ipairs(GetEquippedItems()) do
        if item.qualityPending then
            pendingItemInfo = true
            break
        end
    end
    if pendingItemInfo and C_Timer and C_Timer.After and now - lastPendingGearRescanAt >= GEAR_SCAN_THROTTLE then
        lastPendingGearRescanAt = now
        C_Timer.After(2, function()
            if SC.ScanEquippedGear then
                SC:ScanEquippedGear(true)
            end
        end)
    end

    for _, invalid in ipairs(self:GetInvalidEquippedItems()) do
        local item = invalid.item
        local key = invalid.rule .. ":" .. tostring(item.link)
        local detail = BuildEquippedItemViolationDetail(invalid)

        if not HasActiveLocalViolation(invalid.rule, detail)
            and (options.ignoreViolationThrottle or not ShouldThrottle(key, GEAR_VIOLATION_THROTTLE)) then
            if invalid.rule == "heirlooms" then
                self:ApplyRuleOutcome("heirlooms", {
                    playerKey = self:GetPlayerKey(),
                    detail = detail,
                })
            elseif invalid.rule == "enchants" then
                self:ApplyRuleOutcome("enchants", {
                    playerKey = self:GetPlayerKey(),
                    detail = detail,
                })
            else
                local db = GetDB()
                if db and db.run then
                    db.run.warningCount = (db.run.warningCount or 0) + 1
                end
                local participant = self:GetOrCreateParticipant(self:GetPlayerKey())
                if participant.status == "ACTIVE" then
                    participant.status = "WARNING"
                end
                self:AddViolation("gearQuality", detail, "WARNING", self:GetPlayerKey())
            end
        end
    end
end

function SC:RecheckClearedViolationState(violation)
    if not violation or violation.shared == true or violation.playerKey ~= self:GetPlayerKey() then
        return
    end

    if violation.type == "gearQuality" or violation.type == "heirlooms" or violation.type == "enchants" then
        self:ScanEquippedGear(true, { ignoreViolationThrottle = true })
    elseif violation.type == "mounts" or violation.type == "flying" then
        if self.CheckMovementRules then
            self:CheckMovementRules(true)
        end
    elseif self.RecheckAccessRuleState then
        self:RecheckAccessRuleState(violation.type)
    end
end

local function GetCurrentPartyLevels()
    local levels = {}

    local playerLevel = UnitLevel("player")
    if playerLevel and playerLevel > 0 then
        table.insert(levels, playerLevel)
    end

    if IsInRaid() then
        return levels
    elseif IsInGroup() then
        for index = 1, GetNumSubgroupMembers() do
            local level = UnitLevel("party" .. index)
            if level and level > 0 then
                table.insert(levels, level)
            end
        end
    end

    return levels
end

function SC:CheckMaxLevelGap(force)
    local db = GetDB()
    if not IsRunActive() then
        return
    end

    if self:GetRule("maxLevelGap") == "ALLOWED" then
        if db and db.run then
            db.run.levelGapBlocked = false
        end
        return
    end

    local now = time()
    if not force and now - lastLevelGapCheckAt < LEVEL_GAP_THROTTLE then
        return
    end
    lastLevelGapCheckAt = now

    local levels = GetCurrentPartyLevels()
    if #levels < 2 then
        if db and db.run then
            db.run.levelGapBlocked = false
        end
        return
    end

    local lowest = levels[1]
    local highest = levels[1]
    for _, level in ipairs(levels) do
        if level < lowest then lowest = level end
        if level > highest then highest = level end
    end

    local gap = highest - lowest
    local allowedGap = tonumber(self:GetRule("maxLevelGapValue")) or 3

    if gap > allowedGap then
        db.run.levelGapBlocked = true
        self:AddLog("LEVEL_GAP_EXCEEDED", "Party level gap is " .. tostring(gap) .. " (allowed " .. tostring(allowedGap) .. ").")
    else
        db.run.levelGapBlocked = false
    end
end

local function BuildPlayerKey(name, realm)
    if not realm or realm == "" then
        realm = GetRealmName and GetRealmName() or nil
    end
    return tostring(name or "Unknown") .. "-" .. tostring(realm or "Unknown")
end

local function GetCurrentPartyMemberKeys()
    local keys = {}

    if not IsInGroup() or IsInRaid() then
        return keys
    end

    for index = 1, GetNumSubgroupMembers() do
        local name, realm = UnitFullName("party" .. index)
        if name then
            table.insert(keys, BuildPlayerKey(name, realm))
        end
    end

    return keys
end

local function AddUniqueDetail(details, seen, playerKey, reason)
    local text = tostring(playerKey or "Unknown") .. " (" .. tostring(reason or "invalid") .. ")"
    if seen[text] then
        return
    end
    seen[text] = true
    table.insert(details, text)
end

local function ShouldThrottleGroupProgress(ruleName, detail)
    local key = tostring(ruleName or "?") .. ":" .. tostring(detail or "?")
    local now = time()

    if now - (groupProgressViolationTimes[key] or 0) < GROUP_PROGRESS_VIOLATION_THROTTLE then
        return true
    end

    groupProgressViolationTimes[key] = now
    return false
end

local function HasActiveProgressViolation(ruleName, detail)
    local db = GetDB()
    local playerKey = SC:GetPlayerKey()

    for _, violation in ipairs(db and db.violations or {}) do
        if violation.status ~= "CLEARED"
            and violation.playerKey == playerKey
            and violation.type == ruleName
            and violation.detail == detail then
            return true
        end
    end

    return false
end

local function ApplyProgressRule(ruleName, detail)
    if SC:GetRule(ruleName) == "ALLOWED" then
        return
    end
    if HasActiveProgressViolation(ruleName, detail) then
        return
    end
    if ShouldThrottleGroupProgress(ruleName, detail) then
        return
    end

    SC:ApplyRuleOutcome(ruleName, {
        playerKey = SC:GetPlayerKey(),
        detail = detail,
    })
end

local function GetInvalidProgressPartyDetails()
    local db = GetDB()
    local ruleset = db and db.run and db.run.ruleset or {}
    local details = {}
    local seen = {}

    if not IsInGroup() or IsInRaid() then
        return details
    end

    for _, playerKey in ipairs(GetCurrentPartyMemberKeys()) do
        local participant = db and db.run and db.run.participants and db.run.participants[playerKey]
        if ruleset.groupingMode == "SOLO_SELF_FOUND" then
            AddUniqueDetail(details, seen, playerKey, "outside solo run")
        elseif not participant then
            AddUniqueDetail(details, seen, playerKey, "not in this run")
        elseif participant.status == "FAILED" and ruleset.failedMemberBlocksParty then
            AddUniqueDetail(details, seen, playerKey, "failed run member")
        elseif participant.status == "PENDING" or participant.status == "UNSYNCED" or participant.status == "NOT_IN_RUN" then
            AddUniqueDetail(details, seen, playerKey, string.lower(tostring(participant.status)))
        elseif participant.status == "RUN_MISMATCH" or participant.status == "RULESET_MISMATCH" or participant.status == "ADDON_VERSION_MISMATCH" then
            AddUniqueDetail(details, seen, playerKey, string.lower(tostring(participant.status)))
        end
    end

    if SC.Sync_GetGroupRows then
        for _, peer in ipairs(SC:Sync_GetGroupRows()) do
            local peerKey = peer and peer.playerKey
            if peerKey then
                local compatible, reason = SC.IsRemoteStateCompatible and SC:IsRemoteStateCompatible(peer)
                if peer.unsynced then
                    AddUniqueDetail(details, seen, peerKey, "no addon response")
                elseif not compatible then
                    AddUniqueDetail(details, seen, peerKey, string.lower(tostring(reason or "sync blocker")))
                elseif (peer.participantStatus == "FAILED" or peer.failed) and ruleset.failedMemberBlocksParty then
                    AddUniqueDetail(details, seen, peerKey, "failed run member")
                end
            end
        end
    end

    for _, conflict in pairs(db and db.run and db.run.conflicts or {}) do
        if conflict.active and SC.IsParticipantInCurrentParty and SC:IsParticipantInCurrentParty(conflict.playerKey) then
            AddUniqueDetail(details, seen, conflict.playerKey, string.lower(tostring(conflict.type or "conflict")))
        end
    end

    return details
end

function SC:CheckPartyProgressIntegrity(progressLabel)
    local db = GetDB()
    if not IsRunActive() or not db or not db.run then
        return
    end

    if not IsInGroup() or IsInRaid() then
        return
    end

    progressLabel = progressLabel or "Gained XP"

    if self.CheckMaxLevelGap then
        self:CheckMaxLevelGap(false)
    end
    if db.run.levelGapBlocked and self:GetRule("maxLevelGap") ~= "ALLOWED" then
        ApplyProgressRule("maxLevelGap", tostring(progressLabel) .. " while party level gap was blocked.")
    end

    local invalidDetails = GetInvalidProgressPartyDetails()
    if #invalidDetails == 0 then
        return
    end

    local ruleName = (db.run.ruleset and db.run.ruleset.groupingMode) == "SOLO_SELF_FOUND" and "outsiderGrouping" or "unsyncedMembers"
    ApplyProgressRule(ruleName, tostring(progressLabel) .. " while grouped with invalid party member(s): " .. table.concat(invalidDetails, ", ") .. ".")
end

local function HasUnsyncedPartyMembers()
    if not IsInGroup() or IsInRaid() then
        return false
    end

    local rows = SC.Sync_GetGroupRows and SC:Sync_GetGroupRows() or {}
    for _, status in ipairs(rows) do
        if status.unsynced or status.participantStatus == "UNSYNCED" or status.participantStatus == "NOT_IN_RUN" or status.participantStatus == "PENDING" or status.participantStatus == "RUN_MISMATCH" then
            return true
        end
    end

    return false
end

local function SafeCallBoolean(owner, methodName)
    local method = owner and owner[methodName]
    if not method then return false end

    local ok, result = pcall(method)
    return ok and result == true
end

local function IsFollowerDungeon()
    return SafeCallBoolean(C_LFGInfo, "IsInLFGFollowerDungeon")
end

local function IsLFGInstance()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return true
    end

    if IsInLFGDungeon then
        local ok, result = pcall(IsInLFGDungeon)
        return ok and result == true
    end

    return false
end

local function GetInstanceEntrySource()
    if IsFollowerDungeon() then
        return "FOLLOWER"
    end

    if IsLFGInstance() then
        return "GROUP_FINDER"
    end

    return "MANUAL"
end

local function FormatInstanceSource(source)
    if source == "FOLLOWER" then return "Follower" end
    if source == "GROUP_FINDER" then return "Group Finder" end
    return "Manual"
end

local function GetTrackedInstanceKind(instanceType, entrySource)
    if entrySource == "FOLLOWER" then
        return "DUNGEON"
    end

    if instanceType == "party" then
        return "DUNGEON"
    end

    if instanceType == "raid" then
        return "RAID"
    end

    if instanceType == "scenario" then
        return "SCENARIO"
    end

    if instanceType == "pvp" or instanceType == "arena" then
        return "PVP"
    end

    return "INSTANCE"
end

local function FormatInstanceKind(kind)
    if kind == "DUNGEON" then return "Dungeon" end
    if kind == "RAID" then return "Raid" end
    if kind == "SCENARIO" then return "Scenario" end
    if kind == "PVP" then return "Instanced PvP" end
    return "Instance"
end

local function ShouldApplyDungeonRepeatRule(instanceKind)
    return instanceKind == "DUNGEON"
end

local function BuildInstanceEntryMessage(instanceName, entrySource)
    if entrySource == "FOLLOWER" then
        return "Entered follower dungeon: " .. instanceName
    end

    if entrySource == "GROUP_FINDER" then
        return "Entered group finder instance: " .. instanceName
    end

    return "Entered instance: " .. instanceName
end

local function BuildInstanceVisitKey(instanceName, instanceType, difficultyID, lfgDungeonID)
    return table.concat({
        tostring(instanceName or ""),
        tostring(instanceType or ""),
        tostring(difficultyID or ""),
        tostring(lfgDungeonID or ""),
    }, "|")
end

function SC:CheckInstanceIntegrity()
    local db = GetDB()
    if not IsRunActive() then
        return
    end

    local inInstance, instanceType = IsInInstance()
    if not inInstance then
        currentInstanceName = nil
        if db.run then
            db.run.currentInstanceVisit = nil
        end
        return
    end

    local instanceName, _, difficultyID, difficultyName, _, _, _, _, instanceGroupSize, lfgDungeonID = GetInstanceInfo()
    if not instanceName or instanceName == "" then
        return
    end

    local entrySource = GetInstanceEntrySource()
    local instanceKind = GetTrackedInstanceKind(instanceType, entrySource)
    local visitKey = BuildInstanceVisitKey(instanceName, instanceType, difficultyID, lfgDungeonID)
    local currentVisit = db.run and db.run.currentInstanceVisit
    if currentVisit and currentVisit.visitKey == visitKey and currentVisit.active then
        currentInstanceName = instanceName
        return
    end

    currentInstanceName = instanceName
    db.run.dungeons = db.run.dungeons or {}
    db.run.dungeonOrder = db.run.dungeonOrder or {}
    db.run.currentInstanceVisit = {
        visitKey = visitKey,
        instanceName = instanceName,
        instanceType = instanceType,
        difficultyID = difficultyID,
        lfgDungeonID = lfgDungeonID,
        active = true,
        enteredAt = time(),
    }

    local entry = db.run.dungeons[instanceName]
    if not entry then
        entry = {
            name = instanceName,
            instanceType = instanceType,
            count = 0,
            firstEnteredAt = time(),
            lastEnteredAt = nil,
            firstEntrySource = entrySource,
            instanceKind = instanceKind,
        }
        db.run.dungeons[instanceName] = entry
        table.insert(db.run.dungeonOrder, instanceName)
    end

    entry.count = entry.count + 1
    entry.lastEnteredAt = time()
    entry.lastEntrySource = entrySource
    entry.instanceKind = instanceKind
    entry.instanceType = instanceType
    entry.difficultyID = difficultyID
    entry.difficultyName = difficultyName
    entry.instanceGroupSize = instanceGroupSize
    entry.lfgDungeonID = lfgDungeonID
    entry.isFollowerDungeon = entrySource == "FOLLOWER" or nil
    entry.isGroupFinder = entrySource == "GROUP_FINDER" or nil

    self:AddLog("INSTANCE_ENTERED", BuildInstanceEntryMessage(instanceName, entrySource), {
        instanceName = instanceName,
        instanceType = instanceType,
        instanceKind = instanceKind,
        entrySource = entrySource,
        difficultyID = difficultyID,
        difficultyName = difficultyName,
        instanceGroupSize = instanceGroupSize,
        lfgDungeonID = lfgDungeonID,
        isFollowerDungeon = entrySource == "FOLLOWER",
        isGroupFinder = entrySource == "GROUP_FINDER",
        count = entry.count,
    })

    if entry.count > 1 and ShouldApplyDungeonRepeatRule(instanceKind) then
        self:ApplyRuleOutcome("dungeonRepeat", {
            playerKey = self:GetPlayerKey(),
            detail = "Repeated dungeon during this run: " .. instanceName,
        })
    end

    if HasUnsyncedPartyMembers() then
        self:ApplyRuleOutcome("instanceWithUnsyncedPlayers", {
            playerKey = self:GetPlayerKey(),
            detail = "Entered instance with unsynced or unconfirmed party members: " .. instanceName,
        })
    end
end

function SC:PrintGearStatus()
    local rules = (GetDB() and GetDB().run and GetDB().run.ruleset) or {}
    Print("gearQuality = " .. tostring(rules.gearQuality))
    Print("heirlooms = " .. tostring(rules.heirlooms))
    Print("enchants = " .. tostring(rules.enchants))

    local invalid = self:GetInvalidEquippedItems()
    if #invalid == 0 then
        Print("no invalid equipped items detected.")
        return
    end

    Print("invalid equipped items:")
    for _, itemInfo in ipairs(invalid) do
        local item = itemInfo.item
        local suffix = "quality " .. tostring(QUALITY_NAMES[item.quality] or item.quality or "unknown")
        if item.enchantId then
            suffix = suffix .. ", enchant " .. tostring(item.enchantId)
        end
        Print(tostring(item.link) .. " - " .. itemInfo.reason .. " (" .. suffix .. ")")
    end
end

local SetCVarCompat = (C_CVar and C_CVar.SetCVar) and function(k, v) C_CVar.SetCVar(k, v) end or SetCVar
local GetCVarCompat = (C_CVar and C_CVar.GetCVar) and function(k) return C_CVar.GetCVar(k) end or GetCVar

local function GetCVarDefaultCompat(key)
    if C_CVar and C_CVar.GetCVarDefault then
        local v = C_CVar.GetCVarDefault(key)
        if v ~= nil then return tostring(v) end
    end
    if GetCVarDefault then
        local v = GetCVarDefault(key)
        if v ~= nil then return tostring(v) end
    end
    return nil
end

local ACTIONCAM_CVARS = {
    "CameraKeepCharacterCentered",
    "CameraReduceUnexpectedMovement",
    "test_cameraOverShoulder",
    "test_cameraDynamicPitch",
    "test_cameraTargetFocusEnemyEnable",
    "test_cameraTargetFocusInteractEnable",
    "test_cameraTargetFocusEnemyStrengthPitch",
    "test_cameraTargetFocusEnemyStrengthYaw",
    "test_cameraTargetFocusInteractStrengthPitch",
    "test_cameraTargetFocusInteractStrengthYaw",
    "test_cameraHeadMovementStrength",
}

local ACTIONCAM_CVAR_FALLBACK_DEFAULTS = {
    CameraKeepCharacterCentered = "1",
    CameraReduceUnexpectedMovement = "0",
    test_cameraOverShoulder = "0",
    test_cameraDynamicPitch = "0",
    test_cameraTargetFocusEnemyEnable = "0",
    test_cameraTargetFocusInteractEnable = "0",
    test_cameraTargetFocusEnemyStrengthPitch = "0.4",
    test_cameraTargetFocusEnemyStrengthYaw = "0.5",
    test_cameraTargetFocusInteractStrengthPitch = "0.75",
    test_cameraTargetFocusInteractStrengthYaw = "1.0",
    test_cameraHeadMovementStrength = "0",
}

local actionCamOriginals = nil

local ACTION_CAM_SHOULDER_OFFSET = "0.7"
local ACTION_CAM_MOUNTED_SHOULDER_OFFSET = "0"
local ACTION_CAM_HEAD_MOVEMENT_STRENGTH = "1"
local ACTION_CAM_HEAD_MOVEMENT_STRENGTH_FIRST_PERSON = "0.4"
local ACTION_CAM_FIRST_PERSON_ZOOM_THRESHOLD = 0.5
local ACTION_CAM_ENEMY_FOCUS_YAW = "0.5"
local ACTION_CAM_ENEMY_FOCUS_PITCH = "0.4"
local ACTION_CAM_INTERACT_FOCUS_YAW = "0"
local ACTION_CAM_INTERACT_FOCUS_PITCH = "0"

local ACTION_CAM_PROFILE_ORDER = { "SOFT", "CINEMATIC", "DRAMATIC" }
local ACTION_CAM_PROFILES = {
    SOFT = {
        label = "Soft",
        note = "gentle shoulder camera, low motion",
        zoom = 6,
        mountedZoom = 7,
        keepCentered = "0",
        reduceUnexpected = "1",
        shoulder = "0.45",
        mountedShoulder = "0",
        dynamicPitch = "0",
        enemyFocusEnable = "0",
        interactFocusEnable = "0",
        enemyFocusYaw = "0.25",
        enemyFocusPitch = "0.2",
        interactFocusYaw = "0",
        interactFocusPitch = "0",
        headMovement = "0.15",
        headMovementFirstPerson = "0",
    },
    CINEMATIC = {
        label = "Cinematic",
        note = "current Softcore enforced profile",
        zoom = 5,
        mountedZoom = 7,
        keepCentered = "0",
        reduceUnexpected = "0",
        shoulder = ACTION_CAM_SHOULDER_OFFSET,
        mountedShoulder = ACTION_CAM_MOUNTED_SHOULDER_OFFSET,
        dynamicPitch = "1",
        enemyFocusEnable = "1",
        interactFocusEnable = "0",
        enemyFocusYaw = ACTION_CAM_ENEMY_FOCUS_YAW,
        enemyFocusPitch = ACTION_CAM_ENEMY_FOCUS_PITCH,
        interactFocusYaw = ACTION_CAM_INTERACT_FOCUS_YAW,
        interactFocusPitch = ACTION_CAM_INTERACT_FOCUS_PITCH,
        headMovement = ACTION_CAM_HEAD_MOVEMENT_STRENGTH,
        headMovementFirstPerson = ACTION_CAM_HEAD_MOVEMENT_STRENGTH_FIRST_PERSON,
    },
    DRAMATIC = {
        label = "Dramatic",
        note = "stronger offset, target focus, and camera motion",
        zoom = 4.5,
        mountedZoom = 6.5,
        keepCentered = "0",
        reduceUnexpected = "0",
        shoulder = "0.85",
        mountedShoulder = "0.25",
        dynamicPitch = "1",
        enemyFocusEnable = "1",
        interactFocusEnable = "1",
        enemyFocusYaw = "0.7",
        enemyFocusPitch = "0.55",
        interactFocusYaw = "0.35",
        interactFocusPitch = "0.25",
        headMovement = "1",
        headMovementFirstPerson = "0.5",
    },
}

local actionCamTestProfile = nil

local function SetCVarIfChanged(key, value)
    local str = tostring(value)
    if GetCVarCompat(key) ~= str then
        SetCVarCompat(key, str)
    end
end

local function IsNpcInteractionActive()
    return (GossipFrame and GossipFrame:IsShown())
        or (MerchantFrame and MerchantFrame:IsShown())
        or (QuestFrame and QuestFrame:IsShown())
        or (ItemTextFrame and ItemTextFrame:IsShown())
        or (ClassTrainerFrame and ClassTrainerFrame:IsShown())
        or (TaxiFrame and TaxiFrame:IsShown())
        or (GuildRegistrarFrame and GuildRegistrarFrame:IsShown())
end

local function HasHostileCameraTarget()
    return UnitExists("target") and UnitCanAttack("player", "target")
end

local function IsFirstPersonZoomedIn()
    if not GetCameraZoom then
        return false
    end
    local zoom = tonumber(GetCameraZoom())
    return zoom ~= nil and zoom <= ACTION_CAM_FIRST_PERSON_ZOOM_THRESHOLD
end

local function IsCameraRuleEnforcedValue(value)
    return value ~= nil and value ~= "ALLOWED" and value ~= "LOG_ONLY" and value ~= false
end

local function IsCameraModeRequired(ruleset)
    return IsCameraRuleEnforcedValue(ruleset and ruleset.actionCam)
end

local function DefaultCameraModeForRules(ruleset)
    if IsCameraRuleEnforcedValue(ruleset and ruleset.actionCam) then return "CINEMATIC" end
    return nil
end

local function GetRunCameraMode()
    if not IsRunActive() then return nil end
    local db = GetDB()
    local run = db and db.run
    local ruleset = run and run.ruleset
    if not IsCameraModeRequired(ruleset) then return nil end
    run.cameraMode = run.cameraMode or DefaultCameraModeForRules(ruleset) or "CINEMATIC"
    return run.cameraMode
end

local function CaptureActionCamOriginals()
    if actionCamOriginals then return end
    local db = GetDB()
    if db and db.actionCamCvarBackup then
        actionCamOriginals = {}
        for _, key in ipairs(ACTIONCAM_CVARS) do
            actionCamOriginals[key] = db.actionCamCvarBackup[key]
        end
        return
    end
    actionCamOriginals = {}
    for _, key in ipairs(ACTIONCAM_CVARS) do
        actionCamOriginals[key] = GetCVarCompat(key)
    end
    if db then
        db.actionCamCvarBackup = {}
        for _, key in ipairs(ACTIONCAM_CVARS) do
            db.actionCamCvarBackup[key] = actionCamOriginals[key]
        end
    end
end

local function GetActionCamZoomTarget()
    if GetRunCameraMode() ~= "CINEMATIC" then return nil end
    local profile = ACTION_CAM_PROFILES[actionCamTestProfile] or ACTION_CAM_PROFILES.CINEMATIC
    return (IsMounted and IsMounted()) and profile.mountedZoom or profile.zoom
end

local function ApplyActionCamProfileSettings(profile)
    local mounted = IsMounted and IsMounted()

    SetCVarIfChanged("CameraKeepCharacterCentered", profile.keepCentered)
    SetCVarIfChanged("CameraReduceUnexpectedMovement", profile.reduceUnexpected)
    SetCVarIfChanged("test_cameraOverShoulder", mounted and profile.mountedShoulder or profile.shoulder)
    SetCVarIfChanged("test_cameraDynamicPitch", profile.dynamicPitch)
    SetCVarIfChanged("test_cameraTargetFocusEnemyEnable", profile.enemyFocusEnable)
    SetCVarIfChanged("test_cameraTargetFocusInteractEnable", profile.interactFocusEnable)
    SetCVarIfChanged("test_cameraTargetFocusEnemyStrengthYaw", profile.enemyFocusYaw)
    SetCVarIfChanged("test_cameraTargetFocusEnemyStrengthPitch", profile.enemyFocusPitch)
    SetCVarIfChanged("test_cameraTargetFocusInteractStrengthYaw", profile.interactFocusYaw)
    SetCVarIfChanged("test_cameraTargetFocusInteractStrengthPitch", profile.interactFocusPitch)
    SetCVarIfChanged("test_cameraHeadMovementStrength", IsFirstPersonZoomedIn()
        and profile.headMovementFirstPerson
        or profile.headMovement)

    if not IsNpcInteractionActive() and not HasHostileCameraTarget() then
        local target = (mounted and profile.mountedZoom) or profile.zoom
        local current = GetCameraZoom and GetCameraZoom() or target
        if current - target > 0.5 then
            CameraZoomIn(current - target)
        end
    end
end

function SC:IsActionCamEnforced()
    return GetActionCamZoomTarget() ~= nil
end

function SC:IsCameraModeRequired()
    local db = GetDB()
    return IsRunActive() and IsCameraModeRequired(db and db.run and db.run.ruleset)
end

function SC:GetCameraMode()
    return GetRunCameraMode()
end

function SC:SetCameraMode(mode)
    if mode ~= "CINEMATIC" then return false end
    local db = GetDB()
    if not db or not db.run or not db.run.active or not IsCameraModeRequired(db.run.ruleset) then
        return false
    end

    db.run.cameraMode = mode
    if self.EnforceActionCamSettings then
        self:EnforceActionCamSettings()
    end

    if self.MasterUI_Refresh then self:MasterUI_Refresh() end
    if self.HUD_Refresh then self:HUD_Refresh() end
    return true
end

function SC:PrintActionCamTestStatus()
    local activeProfile = ACTION_CAM_PROFILES[actionCamTestProfile]
    Print("camera test profile: " .. (activeProfile and activeProfile.label or "off"))
    if activeProfile then
        Print(activeProfile.note)
    end
    Print("macro: /sc camera next")
    Print("profiles: soft, cinematic, dramatic, off")
    Print("current CVars: shoulder=" .. tostring(GetCVarCompat("test_cameraOverShoulder"))
        .. ", dynamicPitch=" .. tostring(GetCVarCompat("test_cameraDynamicPitch"))
        .. ", enemyFocus=" .. tostring(GetCVarCompat("test_cameraTargetFocusEnemyEnable"))
        .. ", interactFocus=" .. tostring(GetCVarCompat("test_cameraTargetFocusInteractEnable"))
        .. ", headMovement=" .. tostring(GetCVarCompat("test_cameraHeadMovementStrength")))
end

function SC:SetActionCamTestProfile(profileKey)
    profileKey = string.upper(tostring(profileKey or ""))
    if profileKey == "" or profileKey == "STATUS" then
        self:PrintActionCamTestStatus()
        return true
    end

    if profileKey == "OFF" or profileKey == "DEFAULT" or profileKey == "RESTORE" then
        actionCamTestProfile = nil
        self:RestoreActionCamSettings()
        Print("camera test profile: off")
        return true
    end

    if profileKey == "NEXT" or profileKey == "TOGGLE" or profileKey == "CYCLE" then
        local nextIndex = 1
        for i, key in ipairs(ACTION_CAM_PROFILE_ORDER) do
            if key == actionCamTestProfile then
                nextIndex = i + 1
                break
            end
        end
        if nextIndex > #ACTION_CAM_PROFILE_ORDER then
            actionCamTestProfile = nil
            self:RestoreActionCamSettings()
            Print("camera test profile: off")
            return true
        end
        profileKey = ACTION_CAM_PROFILE_ORDER[nextIndex]
    end

    local profile = ACTION_CAM_PROFILES[profileKey]
    if not profile then
        Print("usage: /sc camera status|next|soft|cinematic|dramatic|off")
        return false
    end

    CaptureActionCamOriginals()
    actionCamTestProfile = profileKey
    ApplyActionCamProfileSettings(profile)
    Print("camera test profile: " .. profile.label .. " - " .. profile.note)
    return true
end

function SC:HandleActionCamSlash(input)
    local profileKey = string.lower(strtrim(input or ""))
    if profileKey == "" then profileKey = "status" end
    return self:SetActionCamTestProfile(profileKey)
end

function SC:RestoreActionCamSettings()
    local db = GetDB()
    if not actionCamOriginals and db and db.actionCamCvarBackup then
        actionCamOriginals = {}
        for _, key in ipairs(ACTIONCAM_CVARS) do
            actionCamOriginals[key] = db.actionCamCvarBackup[key]
        end
    end
    if not actionCamOriginals then return end
    for _, key in ipairs(ACTIONCAM_CVARS) do
        local v = actionCamOriginals[key]
        if v ~= nil then SetCVarCompat(key, v) end
    end
    actionCamOriginals = nil
    if db then
        db.actionCamCvarBackup = nil
    end
end

local function RevertActionCamToEngineDefaults()
    for _, key in ipairs(ACTIONCAM_CVARS) do
        local def = GetCVarDefaultCompat(key) or ACTIONCAM_CVAR_FALLBACK_DEFAULTS[key]
        if def and GetCVarCompat(key) ~= def then
            SetCVarCompat(key, def)
        end
    end
end

function SC:CleanupActionCamIfNeeded()
    local db = GetDB()
    local enforcingZoom = GetActionCamZoomTarget()
    if enforcingZoom then
        return
    end
    if db and db.actionCamCvarBackup then
        actionCamOriginals = {}
        for _, key in ipairs(ACTIONCAM_CVARS) do
            actionCamOriginals[key] = db.actionCamCvarBackup[key]
        end
        self:RestoreActionCamSettings()
        return
    end
    RevertActionCamToEngineDefaults()
end

function SC:EnforceActionCamSettings()
    local target = GetActionCamZoomTarget()
    if not target then return end

    CaptureActionCamOriginals()

    ApplyActionCamProfileSettings(ACTION_CAM_PROFILES[actionCamTestProfile] or ACTION_CAM_PROFILES.CINEMATIC)
end

do
    local elapsed = 0
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:SetScript("OnEvent", function()
        if SC.CleanupActionCamIfNeeded then
            SC:CleanupActionCamIfNeeded()
        end
    end)
    frame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.2 then return end
        elapsed = 0

        if GetActionCamZoomTarget() then
            SC:EnforceActionCamSettings()
        elseif actionCamOriginals then
            SC:RestoreActionCamSettings()
        end
    end)
end

function SC:PrintDungeons()
    local db = GetDB()
    if not db or not db.run or not db.run.dungeonOrder or #db.run.dungeonOrder == 0 then
        Print("no dungeons recorded for this run.")
        return
    end

    Print("dungeons entered:")
    for _, name in ipairs(db.run.dungeonOrder) do
        local entry = db.run.dungeons[name]
        if entry then
            local source = FormatInstanceSource(entry.lastEntrySource or entry.firstEntrySource)
            local kind = FormatInstanceKind(entry.instanceKind or GetTrackedInstanceKind(entry.instanceType, entry.lastEntrySource or entry.firstEntrySource))
            local difficulty = entry.difficultyName and entry.difficultyName ~= "" and (" - " .. entry.difficultyName) or ""
            Print(entry.name .. " - entries: " .. tostring(entry.count) .. " - " .. kind .. " - " .. source .. difficulty)
        end
    end
end
