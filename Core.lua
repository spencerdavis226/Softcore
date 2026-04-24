-- Softcore
-- Local MVP state, slash commands, and shared helpers.

local ADDON_NAME = ...

Softcore = Softcore or {}
local SC = Softcore

SC.name = "Softcore"
SC.version = "0.1.0"
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

local function EnsureDatabase()
    SoftcoreDB = SoftcoreDB or {}

    SoftcoreDB.character = SoftcoreDB.character or GetPlayerSnapshot()
    SoftcoreDB.run = SoftcoreDB.run or {}
    SoftcoreDB.eventLog = SoftcoreDB.eventLog or {}

    local run = SoftcoreDB.run
    if run.active == nil then run.active = false end
    if run.valid == nil then run.valid = true end
    if run.failed == nil then run.failed = false end
    run.startTime = run.startTime or nil
    run.deathCount = run.deathCount or 0
    run.warningCount = run.warningCount or 0

    SC.db = SoftcoreDB
    return SoftcoreDB
end

function SC:RefreshCharacter()
    local db = EnsureDatabase()
    db.character = GetPlayerSnapshot()
    return db.character
end

function SC:LogEvent(kind, message)
    local db = EnsureDatabase()

    table.insert(db.eventLog, {
        time = time(),
        kind = kind,
        message = message,
    })

    -- Keep the saved log useful but small for this first local MVP.
    while #db.eventLog > self.maxLogEntries do
        table.remove(db.eventLog, 1)
    end

    if self.UI_Update then
        self:UI_Update()
    end
end

function SC:StartRun()
    local db = EnsureDatabase()

    db.character = GetPlayerSnapshot()
    db.run.active = true
    db.run.valid = true
    db.run.failed = false
    db.run.startTime = time()
    db.run.deathCount = 0
    db.run.warningCount = 0
    db.eventLog = {}

    self:LogEvent("RUN_START", "Run started for " .. db.character.name .. "-" .. db.character.realm .. ".")
    Print("run started.")

    if self.UI_Update then
        self:UI_Update()
    end
end

function SC:ResetRun()
    local db = EnsureDatabase()

    db.character = GetPlayerSnapshot()
    db.run.active = false
    db.run.valid = true
    db.run.failed = false
    db.run.startTime = nil
    db.run.deathCount = 0
    db.run.warningCount = 0
    db.eventLog = {}

    self:LogEvent("RUN_RESET", "Local run reset.")
    Print("local run reset.")

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
