-- Item and group integrity checks for the current local run.

local SC = Softcore

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r " .. tostring(message))
end

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

local tooltipScanner = nil
local function GetTooltipScanner()
    if not tooltipScanner then
        tooltipScanner = CreateFrame("GameTooltip", "SoftcoreGearScanner", nil, "GameTooltipTemplate")
        tooltipScanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return tooltipScanner
end

local function IsItemSelfCrafted(slotId)
    local playerName = UnitName("player")
    if not playerName then return false end
    local madeByPrefix = "Made by " .. playerName
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local data = C_TooltipInfo.GetInventoryItem("player", slotId)
        if data and data.lines then
            for _, line in ipairs(data.lines) do
                if line.leftText and string.find(line.leftText, madeByPrefix, 1, true) then
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
        if line and string.find(line:GetText() or "", madeByPrefix, 1, true) then
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

function SC:ResetGearScanTracking()
    lastGearScanAt = 0
    gearViolationTimes = {}
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
            elseif invalid.rule == "enchants" then
                self:ApplyRuleOutcome("enchants", {
                    playerKey = self:GetPlayerKey(),
                    detail = "Enchanted item equipped: " .. tostring(item.link),
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

function SC:CheckInstanceIntegrity()
    local db = GetDB()
    if not IsRunActive() then
        return
    end

    local inInstance, instanceType = IsInInstance()
    if not inInstance then
        currentInstanceName = nil
        return
    end

    local instanceName, _, difficultyID, difficultyName, _, _, _, _, instanceGroupSize, lfgDungeonID = GetInstanceInfo()
    if not instanceName or instanceName == "" or currentInstanceName == instanceName then
        return
    end

    local entrySource = GetInstanceEntrySource()
    local instanceKind = GetTrackedInstanceKind(instanceType, entrySource)
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
local ACTION_CAM_ENEMY_FOCUS_YAW = "0.5"
local ACTION_CAM_ENEMY_FOCUS_PITCH = "0.4"
local ACTION_CAM_INTERACT_FOCUS_YAW = "0"
local ACTION_CAM_INTERACT_FOCUS_PITCH = "0"

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
    return (IsMounted and IsMounted()) and 7 or 5
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

    local mounted = IsMounted and IsMounted()

    SetCVarIfChanged("CameraKeepCharacterCentered", "0")
    SetCVarIfChanged("CameraReduceUnexpectedMovement", "0")
    SetCVarIfChanged("test_cameraOverShoulder", mounted and ACTION_CAM_MOUNTED_SHOULDER_OFFSET or ACTION_CAM_SHOULDER_OFFSET)
    SetCVarIfChanged("test_cameraDynamicPitch", "1")
    SetCVarIfChanged("test_cameraTargetFocusEnemyEnable", "1")
    SetCVarIfChanged("test_cameraTargetFocusInteractEnable", "0")
    SetCVarIfChanged("test_cameraTargetFocusEnemyStrengthYaw", ACTION_CAM_ENEMY_FOCUS_YAW)
    SetCVarIfChanged("test_cameraTargetFocusEnemyStrengthPitch", ACTION_CAM_ENEMY_FOCUS_PITCH)
    SetCVarIfChanged("test_cameraTargetFocusInteractStrengthYaw", ACTION_CAM_INTERACT_FOCUS_YAW)
    SetCVarIfChanged("test_cameraTargetFocusInteractStrengthPitch", ACTION_CAM_INTERACT_FOCUS_PITCH)
    SetCVarIfChanged("test_cameraHeadMovementStrength", ACTION_CAM_HEAD_MOVEMENT_STRENGTH)

    if not IsNpcInteractionActive() and not HasHostileCameraTarget() then
        local current = GetCameraZoom and GetCameraZoom() or target
        if current - target > 0.5 then
            CameraZoomIn(current - target)
        end
    end
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
