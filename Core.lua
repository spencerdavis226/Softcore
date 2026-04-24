-- Softcore
-- Local MVP state, slash commands, and shared helpers.

local ADDON_NAME = ...

Softcore = Softcore or {}
local SC = Softcore

SC.name = "Softcore"
SC.version = "0.2.5"
SC.maxLogEntries = 30

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r " .. tostring(message))
end

local function FormatTime(timestamp)
    if not timestamp then
        return "never"
    end

    return date("%Y-%m-%d %H:%M:%S", timestamp)
end

local function GetPlayerSnapshot()
    local name, realm = UnitFullName("player")

    if not realm or realm == "" then
        realm = GetRealmName()
    end

    local _, classFile = UnitClass("player")

    return {
        name = name or "Unknown",
        realm = realm or "Unknown",
        class = classFile or "UNKNOWN",
        level = UnitLevel("player") or 0,
        zone = GetRealZoneText() or "Unknown",
    }
end

local function GetPlayerKey(character)
    character = character or GetPlayerSnapshot()
    return (character.name or "Unknown") .. "-" .. (character.realm or "Unknown")
end

local function CreateDefaultRuleset()
    return {
        id = "default",
        name = "Default Softcore Rules",
        version = 1,
        warningsAreFatal = false,
        deathIsFatal = true,
    }
end

local function EnsureRunDefaults(run)
    if run.active == nil then run.active = false end
    if run.valid == nil then run.valid = true end
    if run.failed == nil then run.failed = false end
    run.runId = run.runId or nil
    run.startTime = run.startTime or nil
    run.deathCount = run.deathCount or 0
    run.warningCount = run.warningCount or 0
    run.ruleset = run.ruleset or CreateDefaultRuleset()
end

local function EnsureDatabase()
    SoftcoreDB = SoftcoreDB or {}

    SoftcoreDB.character = SoftcoreDB.character or GetPlayerSnapshot()
    SoftcoreDB.run = SoftcoreDB.run or {}
    SoftcoreDB.eventLog = SoftcoreDB.eventLog or {}
    SoftcoreDB.violations = SoftcoreDB.violations or {}
    SoftcoreDB.nextIds = SoftcoreDB.nextIds or {}
    SoftcoreDB.nextIds.run = SoftcoreDB.nextIds.run or 0
    SoftcoreDB.nextIds.log = SoftcoreDB.nextIds.log or 0
    SoftcoreDB.nextIds.violation = SoftcoreDB.nextIds.violation or 0

    EnsureRunDefaults(SoftcoreDB.run)
    if SoftcoreDB.run.active and not SoftcoreDB.run.runId then
        SoftcoreDB.nextIds.run = SoftcoreDB.nextIds.run + 1
        SoftcoreDB.run.runId = "SC-RUN-" .. tostring(time()) .. "-" .. tostring(SoftcoreDB.nextIds.run)
    end

    SC.db = SoftcoreDB
    return SoftcoreDB
end

local function CreateStableId(kind)
    local db = EnsureDatabase()

    db.nextIds[kind] = (db.nextIds[kind] or 0) + 1
    return "SC-" .. string.upper(kind) .. "-" .. tostring(time()) .. "-" .. tostring(db.nextIds[kind])
end

function SC:RefreshCharacter()
    local db = EnsureDatabase()
    db.character = GetPlayerSnapshot()
    return db.character
end

function SC:CreateRunId()
    return CreateStableId("run")
end

function SC:AddLog(kind, message, extra)
    local db = EnsureDatabase()
    local logEntryId = CreateStableId("log")
    local entry = {
        id = logEntryId,
        logEntryId = logEntryId,
        runId = db.run.runId,
        time = time(),
        kind = kind,
        message = message,
    }

    if extra then
        for key, value in pairs(extra) do
            entry[key] = value
        end
    end

    table.insert(db.eventLog, entry)

    -- Keep the visible saved log useful but small for this early addon phase.
    while #db.eventLog > self.maxLogEntries do
        table.remove(db.eventLog, 1)
    end

    if self.UI_Update then
        self:UI_Update()
    end

    return entry
end

function SC:LogEvent(kind, message)
    return self:AddLog(kind, message)
end

function SC:AddViolation(violationType, detail, severity, playerKey)
    local db = EnsureDatabase()
    local now = time()
    local violationId = CreateStableId("violation")
    local violation = {
        id = violationId,
        violationId = violationId,
        runId = db.run.runId,
        playerKey = playerKey or GetPlayerKey(db.character),
        type = violationType,
        detail = detail,
        severity = severity or "WARNING",
        status = "ACTIVE",
        createdAt = now,
        clearedAt = nil,
        clearedBy = nil,
        clearReason = nil,
    }

    table.insert(db.violations, violation)
    self:AddLog("VIOLATION_ADDED", detail, {
        violationId = violation.id,
        violationType = violation.type,
        severity = violation.severity,
    })

    return violation
end

function SC:ClearViolation(violationId, clearedBy, clearReason)
    local db = EnsureDatabase()

    for _, violation in ipairs(db.violations) do
        if violation.id == violationId then
            if violation.status ~= "CLEARED" then
                violation.status = "CLEARED"
                violation.clearedAt = time()
                violation.clearedBy = clearedBy or GetPlayerKey(db.character)
                violation.clearReason = clearReason or "Cleared"
                self:AddLog("VIOLATION_CLEARED", "Violation cleared: " .. tostring(violation.type), {
                    violationId = violation.id,
                    clearedBy = violation.clearedBy,
                    clearReason = violation.clearReason,
                })
            end

            return violation
        end
    end

    return nil
end

function SC:GetPlayerStatus()
    local db = EnsureDatabase()

    self:RefreshCharacter()

    return {
        runId = db.run.runId,
        playerKey = GetPlayerKey(db.character),
        name = db.character.name,
        realm = db.character.realm,
        class = db.character.class,
        level = db.character.level,
        zone = db.character.zone,
        active = db.run.active,
        valid = db.run.valid,
        failed = db.run.failed,
        deaths = db.run.deathCount,
        warnings = db.run.warningCount,
        version = self.version,
        timestamp = time(),
    }
end

function SC:GetPartyStatus()
    local statuses = {}
    statuses[GetPlayerKey((self.db or SoftcoreDB or {}).character)] = self:GetPlayerStatus()

    if self.groupStatuses then
        for key, status in pairs(self.groupStatuses) do
            statuses[key] = status
        end
    end

    return statuses
end

function SC:StartRun()
    local db = EnsureDatabase()

    db.character = GetPlayerSnapshot()
    db.run.runId = self:CreateRunId()
    db.run.active = true
    db.run.valid = true
    db.run.failed = false
    db.run.startTime = time()
    db.run.deathCount = 0
    db.run.warningCount = 0
    db.run.ruleset = CreateDefaultRuleset()
    db.eventLog = {}
    db.violations = {}

    self:AddLog("RUN_START", "Run started for " .. db.character.name .. "-" .. db.character.realm .. ".")
    Print("run started.")

    if self.Sync_BroadcastStatus then
        self:Sync_BroadcastStatus("RUN_START")
    end

    if self.UI_Update then
        self:UI_Update()
    end
end

function SC:ResetRun()
    local db = EnsureDatabase()

    db.character = GetPlayerSnapshot()
    db.run.runId = nil
    db.run.active = false
    db.run.valid = true
    db.run.failed = false
    db.run.startTime = nil
    db.run.deathCount = 0
    db.run.warningCount = 0
    db.run.ruleset = CreateDefaultRuleset()
    db.eventLog = {}
    db.violations = {}

    self:AddLog("RUN_RESET", "Local run reset.")
    Print("local run reset.")

    if self.Sync_BroadcastStatus then
        self:Sync_BroadcastStatus("RUN_RESET")
    end

    if self.UI_Update then
        self:UI_Update()
    end
end

function SC:GetStatusText()
    local db = EnsureDatabase()
    local run = db.run

    if run.failed then
        return "Failed"
    end

    if run.active then
        return "Active"
    end

    return "Inactive"
end

function SC:PrintStatus()
    local db = EnsureDatabase()
    local character = db.character
    local run = db.run

    Print("status: " .. self:GetStatusText())
    Print("character: " .. character.name .. "-" .. character.realm .. " " .. character.class .. " level " .. tostring(character.level))
    Print("zone: " .. tostring(character.zone))
    Print("started: " .. FormatTime(run.startTime))
    Print("valid: " .. tostring(run.valid) .. ", failed: " .. tostring(run.failed))
    Print("deaths: " .. tostring(run.deathCount) .. ", warnings: " .. tostring(run.warningCount))
end

function SC:PrintLog()
    local db = EnsureDatabase()

    if #db.eventLog == 0 then
        Print("event log is empty.")
        return
    end

    Print("recent event log:")
    for index = math.max(1, #db.eventLog - 9), #db.eventLog do
        local entry = db.eventLog[index]
        Print(FormatTime(entry.time) .. " [" .. entry.kind .. "] " .. entry.message)
    end
end

function SC:PrintHelp()
    Print("/sc start - start a local run")
    Print("/sc status - print current run status")
    Print("/sc reset - reset the local run")
    Print("/sc log - print recent event logs")
end

function SC:HandleSlash(input)
    local command = string.lower(strtrim(input or ""))

    if command == "start" then
        self:StartRun()
    elseif command == "status" or command == "" then
        self:PrintStatus()
    elseif command == "reset" then
        self:ResetRun()
    elseif command == "log" then
        self:PrintLog()
    else
        self:PrintHelp()
    end
end

function SC:Initialize()
    EnsureDatabase()
    self:RefreshCharacter()

    SLASH_SOFTCORE1 = "/softcore"
    SLASH_SOFTCORE2 = "/sc"
    SlashCmdList.SOFTCORE = function(input)
        SC:HandleSlash(input)
    end

    if self.UI_Create then
        self:UI_Create()
    end

    if self.Events_Register then
        self:Events_Register()
    end

    if self.Sync_Initialize then
        self:Sync_Initialize()
    end

    Print("loaded. Type /sc status.")
end

SC.frame = CreateFrame("Frame")
SC.frame:RegisterEvent("ADDON_LOADED")
SC.frame:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName == ADDON_NAME then
        SC:Initialize()
    end
end)
