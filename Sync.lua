-- Lightweight Blizzard addon-message sync for group run status.

local SC = Softcore

local PREFIX = "SOFTCORE"
local UNSYNCED_AFTER = 30
local HEARTBEAT_SECONDS = 10

SC.syncEnabled = true
SC.groupStatuses = SC.groupStatuses or {}

local syncFrame

local function PlayerKey(name, realm)
    if not realm or realm == "" then
        realm = GetRealmName()
    end

    return (name or "Unknown") .. "-" .. (realm or "Unknown")
end

local function SplitFullName(fullName)
    local name, realm = string.match(fullName or "", "^([^-]+)%-(.+)$")
    if name then
        return name, realm
    end

    return fullName, GetRealmName()
end

local function Escape(value)
    value = tostring(value or "")
    return string.gsub(value, "([^%w _%.%-])", function(character)
        return string.format("%%%02X", string.byte(character))
    end)
end

local function Unescape(value)
    value = tostring(value or "")
    return string.gsub(value, "%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
end

local function Encode(payload)
    local parts = {}

    for key, value in pairs(payload) do
        table.insert(parts, Escape(key) .. "=" .. Escape(value))
    end

    return table.concat(parts, ";")
end

local function Decode(message)
    local payload = {}

    for pair in string.gmatch(message or "", "([^;]+)") do
        local key, value = string.match(pair, "^([^=]+)=(.*)$")
        if key then
            payload[Unescape(key)] = Unescape(value)
        end
    end

    return payload
end

local function GetSyncChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end

    if IsInRaid() then
        return "RAID"
    end

    if IsInGroup() then
        return "PARTY"
    end

    return nil
end

local function DispatchAddonMessage(message, channel)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(PREFIX, message, channel)
    else
        _G.SendAddonMessage(PREFIX, message, channel)
    end
end

local function RegisterPrefix()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    else
        RegisterAddonMessagePrefix(PREFIX)
    end
end

local function GetUnitFullName(unit)
    local name, realm = UnitFullName(unit)

    if not name then
        return nil
    end

    return PlayerKey(name, realm)
end

local function GetRosterKeys()
    local keys = {}

    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            local key = GetUnitFullName("raid" .. index)
            if key then
                table.insert(keys, key)
            end
        end
    elseif IsInGroup() then
        table.insert(keys, PlayerKey(UnitFullName("player")))

        for index = 1, GetNumSubgroupMembers() do
            local key = GetUnitFullName("party" .. index)
            if key then
                table.insert(keys, key)
            end
        end
    end

    return keys
end

local function LocalPlayerKey()
    local name, realm = UnitFullName("player")
    return PlayerKey(name, realm)
end

local function GetDisplayStatus(status)
    if not status or status.unsynced then
        return "UNSYNCED"
    end

    if status.failed or not status.valid then
        return "FAILED"
    end

    if status.active then
        return "VALID"
    end

    return "INACTIVE"
end

function SC:Sync_GetDisplayStatus(status)
    return GetDisplayStatus(status)
end

function SC:Sync_MarkRoster()
    local now = time()
    local roster = GetRosterKeys()
    local seen = {}

    for _, key in ipairs(roster) do
        seen[key] = true

        if key ~= LocalPlayerKey() and not self.groupStatuses[key] then
            local name, realm = SplitFullName(key)
            self.groupStatuses[key] = {
                name = name,
                realm = realm,
                level = "?",
                warnings = 0,
                unsynced = true,
                lastSeen = 0,
                rosterSeen = now,
            }
        end
    end

    for key in pairs(self.groupStatuses) do
        if not seen[key] then
            self.groupStatuses[key] = nil
        end
    end

end

function SC:Sync_GetGroupRows()
    self:Sync_MarkRoster()

    local rows = {}
    local now = time()
    local playerKey = LocalPlayerKey()

    for _, key in ipairs(GetRosterKeys()) do
        if key ~= playerKey then
            local status = self.groupStatuses[key]

            if status and status.lastSeen and status.lastSeen > 0 and now - status.lastSeen <= UNSYNCED_AFTER then
                status.unsynced = false
            elseif status then
                status.unsynced = true
            end

            if status then
                table.insert(rows, status)
            end
        end
    end

    return rows
end

function SC:Sync_BuildPayload(reason)
    local db = self.db or SoftcoreDB
    if not db or not db.character or not db.run then
        return nil
    end

    self:RefreshCharacter()

    return {
        type = "STATUS",
        reason = reason or "UPDATE",
        name = db.character.name,
        realm = db.character.realm,
        class = db.character.class,
        level = db.character.level,
        zone = db.character.zone,
        active = db.run.active and 1 or 0,
        valid = db.run.valid and 1 or 0,
        failed = db.run.failed and 1 or 0,
        deaths = db.run.deathCount or 0,
        warnings = db.run.warningCount or 0,
        version = self.version,
        timestamp = time(),
    }
end

function SC:Sync_BroadcastStatus(reason)
    local channel = GetSyncChannel()
    if not channel then
        return
    end

    local payload = self:Sync_BuildPayload(reason)
    if not payload then
        return
    end

    DispatchAddonMessage(Encode(payload), channel)
end

function SC:Sync_HandleMessage(message, sender)
    local payload = Decode(message)
    if payload.type ~= "STATUS" then
        return
    end

    local name = payload.name
    local realm = payload.realm

    if not name or name == "" then
        name, realm = SplitFullName(sender)
    end

    local key = PlayerKey(name, realm)
    if key == LocalPlayerKey() then
        return
    end

    self.groupStatuses[key] = {
        name = name,
        realm = realm,
        class = payload.class,
        level = tonumber(payload.level) or payload.level or "?",
        zone = payload.zone,
        active = payload.active == "1",
        valid = payload.valid == "1",
        failed = payload.failed == "1",
        deaths = tonumber(payload.deaths) or 0,
        warnings = tonumber(payload.warnings) or 0,
        version = payload.version,
        timestamp = tonumber(payload.timestamp) or 0,
        lastSeen = time(),
        unsynced = false,
    }

    if self.UI_Update then
        self:UI_Update()
    end
end

function SC:Sync_Initialize()
    if syncFrame then
        return
    end

    RegisterPrefix()

    syncFrame = CreateFrame("Frame")
    syncFrame:RegisterEvent("CHAT_MSG_ADDON")
    syncFrame:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)
        if prefix == PREFIX and (channel == "PARTY" or channel == "RAID" or channel == "INSTANCE_CHAT") then
            SC:Sync_HandleMessage(message, sender)
        end
    end)

    self:Sync_MarkRoster()

    -- Give other clients a moment to register their prefix after reload/login.
    if C_Timer and C_Timer.After then
        C_Timer.After(2, function()
            SC:Sync_BroadcastStatus("LOGIN")
        end)
        C_Timer.After(UNSYNCED_AFTER, function()
            if SC.UI_Update then
                SC:UI_Update()
            end
        end)
        if C_Timer.NewTicker then
            self.syncTicker = C_Timer.NewTicker(5, function()
                if SC.UI_Update then
                    SC:UI_Update()
                end
            end)
            self.syncBroadcastTicker = C_Timer.NewTicker(HEARTBEAT_SECONDS, function()
                SC:Sync_BroadcastStatus("HEARTBEAT")
            end)
        end
    else
        self:Sync_BroadcastStatus("LOGIN")
    end
end
