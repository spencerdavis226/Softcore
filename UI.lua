-- Compact always-visible HUD: run and party status at a glance.
-- Left-click to open the master menu (Violations tab if violations are active).
-- Drag to reposition.  /sc hud to toggle visibility.

local SC = Softcore

local HUD_WIDTH       = 224
local HUD_PAD         = 8
local HUD_HERO_H      = 20   -- GameFontNormal row height
local HUD_MEMBER_H    = 16   -- GameFontNormalSmall row height
local HUD_MAX_MEMBERS = 5

-- Pixel positions (top-anchored, negative Y from top-left)
local HERO_Y         = -7
local MEMBERS_TOP_Y  = -(7 + HUD_HERO_H + 4)   -- below hero + gap
local MEMBER_STEP    = -(HUD_MEMBER_H + 2)
local HUD_PAD_BOT    = 7

local STATUS_DOTS = {
    VALID      = "|cff4ade80●|r",
    ACTIVE     = "|cff4ade80●|r",
    FAILED     = "|cffff4444●|r",
    BLOCKED    = "|cfffbbf24●|r",
    CONFLICT   = "|cfffbbf24●|r",
    VIOLATION  = "|cfffbbf24●|r",
    WARNING    = "|cfffbbf24●|r",
    UNSYNCED   = "|cff9ca3af●|r",
    INACTIVE   = "|cff9ca3af●|r",
    NOT_IN_RUN = "|cff9ca3af●|r",
}
local DOT_NEUTRAL = "|cff9ca3af●|r"

local function Dot(statusStr)
    local base = statusStr and string.match(statusStr, "^(%u+)")
    return (base and STATUS_DOTS[base]) or DOT_NEUTRAL
end

local function DisplayStatus(s)
    if s == "WARNING" then return "VIOLATION" end
    return s or "UNKNOWN"
end

local function ShortName(name)
    return name and (string.match(name, "^[^-]+") or name) or "?"
end

local function LocalActiveViolations()
    local db = SC.db or SoftcoreDB
    if not db or not db.violations then return 0 end
    local playerKey = SC:GetPlayerKey()
    local n = 0
    for _, v in ipairs(db.violations) do
        if v.playerKey == playerKey and v.status ~= "CLEARED" then
            n = n + 1
        end
    end
    return n
end

function SC:HUD_Create()
    if self.hudFrame then
        self:HUD_Refresh()
        return
    end

    local frame = CreateFrame("Button", "SoftcoreHUDFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(HUD_WIDTH)
    frame:SetHeight(34)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:RegisterForClicks("LeftButtonUp")
    frame:SetScript("OnClick", function()
        if SC.OpenMasterWindow then
            SC:OpenMasterWindow(LocalActiveViolations() > 0 and "VIOLATIONS" or "OVERVIEW")
        end
    end)
    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.80)

    frame.hero = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.hero:SetPoint("TOPLEFT", frame, "TOPLEFT", HUD_PAD, HERO_Y)
    frame.hero:SetWidth(HUD_WIDTH - HUD_PAD * 2)
    frame.hero:SetJustifyH("LEFT")

    frame.memberRows = {}
    for i = 1, HUD_MAX_MEMBERS do
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", HUD_PAD + 4, MEMBERS_TOP_Y + (i - 1) * MEMBER_STEP)
        fs:SetWidth(HUD_WIDTH - HUD_PAD * 2 - 4)
        fs:SetJustifyH("LEFT")
        frame.memberRows[i] = fs
    end

    frame.violHint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.violHint:SetWidth(HUD_WIDTH - HUD_PAD * 2 - 4)
    frame.violHint:SetJustifyH("LEFT")

    self.hudFrame = frame
    self:HUD_Refresh()
end

function SC:HUD_Refresh()
    local frame = self.hudFrame
    if not frame then return end

    local db        = self.db or SoftcoreDB
    local run       = db and db.run or {}
    local char      = db and db.character or {}
    local active    = run.active
    local localKey  = self:GetPlayerKey()
    local status    = self:GetPlayerStatus()
    local pStatus   = status.participantStatus or "NOT_IN_RUN"
    local syncRows  = self.Sync_GetGroupRows and self:Sync_GetGroupRows() or {}
    local inParty   = IsInGroup() and #syncRows > 0
    local violations = LocalActiveViolations()

    -- Hero row
    if not active then
        frame.hero:SetText(DOT_NEUTRAL .. "  No active run — click to start")
    elseif inParty then
        local partyStatus = status.partyStatus or "INACTIVE"
        frame.hero:SetText(Dot(partyStatus) .. "  Party: " .. DisplayStatus(partyStatus))
    else
        local name  = char.name or ShortName(localKey)
        local level = char.level and ("  " .. char.level) or ""
        frame.hero:SetText(Dot(pStatus) .. "  " .. name .. level .. "  " .. DisplayStatus(pStatus))
    end

    -- Member rows (party mode only)
    local usedRows = 0

    if active and inParty then
        usedRows = usedRows + 1
        local name  = char.name or ShortName(localKey)
        local level = char.level and ("  " .. char.level) or ""
        frame.memberRows[usedRows]:SetText(Dot(pStatus) .. "  " .. name .. " *" .. level .. "  " .. DisplayStatus(pStatus))

        for _, peer in ipairs(syncRows) do
            if usedRows >= HUD_MAX_MEMBERS then break end
            usedRows = usedRows + 1
            local raw  = self.Sync_GetDisplayStatus and self:Sync_GetDisplayStatus(peer) or peer.participantStatus or "UNSYNCED"
            local disp = DisplayStatus(raw)
            local lv   = peer.level and ("  " .. peer.level) or ""
            frame.memberRows[usedRows]:SetText(Dot(raw) .. "  " .. ShortName(peer.name) .. lv .. "  " .. disp)
        end
    end

    for i = usedRows + 1, HUD_MAX_MEMBERS do
        frame.memberRows[i]:SetText("")
    end

    -- Violation hint row, anchored after last used member (or hero if none)
    local violY = MEMBERS_TOP_Y + usedRows * MEMBER_STEP
    if usedRows == 0 then
        violY = MEMBERS_TOP_Y
    end

    if active and violations > 0 then
        frame.violHint:ClearAllPoints()
        frame.violHint:SetPoint("TOPLEFT", frame, "TOPLEFT", HUD_PAD + 4, violY)
        local plural = violations == 1 and "violation" or "violations"
        frame.violHint:SetText("|cfffbbf24⚠  " .. violations .. " active " .. plural .. " — click to review|r")
    else
        frame.violHint:SetText("")
    end

    -- Resize frame to snugly fit content
    local extraRows = usedRows + (active and violations > 0 and 1 or 0)
    local height = -MEMBERS_TOP_Y + (extraRows > 0 and (extraRows * (HUD_MEMBER_H + 2)) or 0) + HUD_PAD_BOT
    frame:SetHeight(height)
end

function SC:HUD_Toggle()
    if not self.hudFrame then
        self:HUD_Create()
        return
    end
    if self.hudFrame:IsShown() then
        self.hudFrame:Hide()
    else
        self.hudFrame:Show()
        self:HUD_Refresh()
    end
end
