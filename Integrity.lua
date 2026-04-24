-- Item and group integrity checks for the current local run.

local SC = Softcore

local GEAR_SCAN_THROTTLE = 10
local GEAR_VIOLATION_THROTTLE = 60
local LEVEL_GAP_THROTTLE = 20

local lastGearScanAt = 0
local lastLevelGapCheckAt = 0
local currentInstanceName
local gearViolationTimes = {}

local EQUIPMENT_SLOTS = {
    1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17,
}

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
    return db and db.run and db.run.active
end

local function GetItemInfoCompat(itemLink)
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(itemLink)
    end

    return GetItemInfo(itemLink)
end

local function GetEquippedItems()
    local items = {}

    for _, slotId in ipairs(EQUIPMENT_SLOTS) do
        local itemLink = GetInventoryItemLink("player", slotId)
        if itemLink then
            local name, _, quality = GetItemInfoCompat(itemLink)
            table.insert(items, {
                slotId = slotId,
                link = itemLink,
                name = name or itemLink,
                quality = quality,
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
            table.insert(invalid, {
                rule = "gearQuality",
                item = item,
                reason = "Disallowed quality for " .. tostring(gearRule),
            })
        end
    end

    return invalid
end

function SC:ScanEquippedGear(force)
    if not IsRunActive() then
        return
    end

    local now = time()
    if not force and now - lastGearScanAt < GEAR_SCAN_THROTTLE then
        return
    end
    lastGearScanAt = now

    for _, invalid in ipairs(self:GetInvalidEquippedItems()) do
        local item = invalid.item
        local key = invalid.rule .. ":" .. tostring(item.link)

        if not ShouldThrottle(key, GEAR_VIOLATION_THROTTLE) then
            if invalid.rule == "heirlooms" then
                self:ApplyRuleOutcome("heirlooms", {
                    playerKey = self:GetPlayerKey(),
                    detail = "Heirloom equipped: " .. tostring(item.link),
                })
            else
                self:AddLog("GEAR_QUALITY", "Invalid equipped item: " .. tostring(item.link), {
                    ruleName = "gearQuality",
                    gearQuality = item.quality,
                })
                self:AddViolation("gearQuality", "Invalid equipped item: " .. tostring(item.link), "WARNING", self:GetPlayerKey())
            end
        end
    end
end

local function GetCurrentPartyLevels()
    local levels = {}

    local playerLevel = UnitLevel("player")
    if playerLevel and playerLevel > 0 then
        table.insert(levels, playerLevel)
    end

    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            local level = UnitLevel("raid" .. index)
            if level and level > 0 then
                table.insert(levels, level)
            end
        end
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
    if not IsRunActive() or self:GetRule("maxLevelGap") == "ALLOWED" then
        return
    end

    local now = time()
    if not force and now - lastLevelGapCheckAt < LEVEL_GAP_THROTTLE then
        return
    end
    lastLevelGapCheckAt = now

    local levels = GetCurrentPartyLevels()
    if #levels < 2 then
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
    local db = GetDB()

    if gap > allowedGap then
        db.run.levelGapBlocked = true
        self:AddLog("LEVEL_GAP_EXCEEDED", "Party level gap is " .. tostring(gap) .. " (allowed " .. tostring(allowedGap) .. ").")
    else
        db.run.levelGapBlocked = false
    end
end

local function HasUnsyncedPartyMembers()
    if not IsInGroup() then
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

function SC:CheckInstanceIntegrity()
    local db = GetDB()
    if not db or not db.run or not db.run.active then
        return
    end

    local inInstance, instanceType = IsInInstance()
    if not inInstance then
        currentInstanceName = nil
        return
    end

    local instanceName = GetInstanceInfo()
    if not instanceName or instanceName == "" or currentInstanceName == instanceName then
        return
    end

    currentInstanceName = instanceName
    db.run.dungeons = db.run.dungeons or {}
    db.run.dungeonOrder = db.run.dungeonOrder or {}

    local entry = db.run.dungeons[instanceName]
    if not entry then
        entry = {
            name = instanceName,
            instanceType = instanceType,
            count = 0,
            firstEnteredAt = time(),
            lastEnteredAt = nil,
        }
        db.run.dungeons[instanceName] = entry
        table.insert(db.run.dungeonOrder, instanceName)
    end

    entry.count = entry.count + 1
    entry.lastEnteredAt = time()

    self:AddLog("INSTANCE_ENTERED", "Entered instance: " .. instanceName, {
        instanceName = instanceName,
        instanceType = instanceType,
        count = entry.count,
    })

    if entry.count > 1 then
        self:ApplyRuleOutcome("dungeonRepeat", {
            playerKey = self:GetPlayerKey(),
            detail = "Repeated instance during this run: " .. instanceName,
        })
    end

    if HasUnsyncedPartyMembers() then
        self:AddLog("INSTANCE_BLOCKER", "Entered instance with unsynced or unconfirmed party members: " .. instanceName)
    end
end

function SC:PrintGearStatus()
    local rules = (GetDB() and GetDB().run and GetDB().run.ruleset) or {}
    Print("gearQuality = " .. tostring(rules.gearQuality))
    Print("heirlooms = " .. tostring(rules.heirlooms))

    local invalid = self:GetInvalidEquippedItems()
    if #invalid == 0 then
        Print("no invalid equipped items detected.")
        return
    end

    Print("invalid equipped items:")
    for _, itemInfo in ipairs(invalid) do
        local item = itemInfo.item
        Print(tostring(item.link) .. " - " .. itemInfo.reason .. " (quality " .. tostring(QUALITY_NAMES[item.quality] or item.quality or "unknown") .. ")")
    end
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
            Print(entry.name .. " - entries: " .. tostring(entry.count))
        end
    end
end
