-- Compact always-visible HUD: run and party status at a glance.
-- Left-click opens the master menu (Violations tab if violations are active).
-- Drag to reposition.  /sc hud to toggle visibility.

local SC = Softcore

local function SavePosition(key, frame)
    SoftcoreDB = SoftcoreDB or {}
    SoftcoreDB.ui = SoftcoreDB.ui or {}
    SoftcoreDB.ui[key] = { x = frame:GetLeft(), y = frame:GetTop() }
end

local function RestorePosition(key, frame, defaultX, defaultY)
    local pos = SoftcoreDB and SoftcoreDB.ui and SoftcoreDB.ui[key]
    frame:ClearAllPoints()
    if pos and pos.x and pos.y then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", defaultX or 0, defaultY or 0)
    end
end

local HUD_WIDTH    = 160
local HUD_PAD      = 8
local HUD_MAX_MEMBERS = 5

-- Row geometry
local HERO_TOP     = -7
local HERO_H       = 20
local MEMBER_TOP   = -(HERO_TOP - HERO_TOP + 7 + HERO_H + 4)   -- = -31
local MEMBER_H     = 16
local MEMBER_STEP  = -(MEMBER_H + 2)                            -- = -18

-- Indicator sizes
local HERO_LIGHT   = 10
local MEMBER_LIGHT = 8

-- Status → RGB color
local STATUS_RGB = {
    VALID      = {0.29, 0.85, 0.50},
    ACTIVE     = {0.29, 0.85, 0.50},
    FAILED     = {1.00, 0.27, 0.27},
    BLOCKED    = {0.98, 0.75, 0.14},
    CONFLICT   = {0.98, 0.75, 0.14},
    VIOLATION  = {0.98, 0.75, 0.14},
    WARNING    = {0.98, 0.75, 0.14},
    UNSYNCED   = {0.61, 0.64, 0.69},
    INACTIVE   = {0.61, 0.64, 0.69},
    NOT_IN_RUN = {0.61, 0.64, 0.69},
}
local RGB_NEUTRAL = {0.61, 0.64, 0.69}

local function SetLight(texture, statusStr)
    local base = statusStr and string.match(statusStr, "^(%u+)")
    local c = (base and STATUS_RGB[base]) or RGB_NEUTRAL
    texture:SetColorTexture(c[1], c[2], c[3], 1)
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
        if v.playerKey == playerKey and v.status ~= "CLEARED" then n = n + 1 end
    end
    return n
end

local function MakeLight(parent, size)
    local t = parent:CreateTexture(nil, "OVERLAY")
    t:SetSize(size, size)
    t:SetColorTexture(RGB_NEUTRAL[1], RGB_NEUTRAL[2], RGB_NEUTRAL[3], 1)
    return t
end

local function MakeLabel(parent, fontObj, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", fontObj)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    return fs
end

function SC:HUD_Create()
    if self.hudFrame then
        self:HUD_Refresh()
        return
    end

    local frame = CreateFrame("Button", "SoftcoreHUDFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(HUD_WIDTH)
    frame:SetHeight(34)
    RestorePosition("hud", frame, 0, 150)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        SavePosition("hud", f)
    end)
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

    -- Hero row: light left-centered in row, label to its right
    local textW = HUD_WIDTH - HUD_PAD * 2 - HERO_LIGHT - 5
    frame.heroLight = MakeLight(frame, HERO_LIGHT)
    frame.heroLight:SetPoint("LEFT", frame, "TOPLEFT", HUD_PAD, HERO_TOP - HERO_H / 2)
    frame.heroLabel = MakeLabel(frame, "GameFontNormal", textW)
    frame.heroLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", HUD_PAD + HERO_LIGHT + 5, HERO_TOP)

    -- Member rows: indented, smaller light + label
    local memberTextW = HUD_WIDTH - HUD_PAD * 2 - 4 - MEMBER_LIGHT - 4
    frame.memberRows = {}
    for i = 1, HUD_MAX_MEMBERS do
        local topY = MEMBER_TOP + (i - 1) * MEMBER_STEP
        local row = {
            light = MakeLight(frame, MEMBER_LIGHT),
            label = MakeLabel(frame, "GameFontNormalSmall", memberTextW),
        }
        row.light:SetPoint("LEFT", frame, "TOPLEFT", HUD_PAD + 4, topY - MEMBER_H / 2)
        row.label:SetPoint("TOPLEFT", frame, "TOPLEFT", HUD_PAD + 4 + MEMBER_LIGHT + 4, topY)
        row.light:Hide()
        frame.memberRows[i] = row
    end

    -- Violation hint row (no light — yellow text only)
    frame.violHint = MakeLabel(frame, "GameFontNormalSmall", HUD_WIDTH - HUD_PAD * 2 - 4)

    self.hudFrame = frame
    self:HUD_Refresh()
end

function SC:HUD_Refresh()
    local frame = self.hudFrame
    if not frame then return end

    local db       = self.db or SoftcoreDB
    local run      = db and db.run or {}
    local char     = db and db.character or {}
    local active   = run.active
    local localKey = self:GetPlayerKey()
    local status   = self:GetPlayerStatus()
    local pStatus  = status.participantStatus or "NOT_IN_RUN"
    local syncRows = self.Sync_GetGroupRows and self:Sync_GetGroupRows() or {}
    local inParty  = IsInGroup() and #syncRows > 0
    local violations = LocalActiveViolations()

    -- Hero row
    if not active then
        SetLight(frame.heroLight, "INACTIVE")
        frame.heroLabel:SetText("No Run")
    elseif inParty then
        SetLight(frame.heroLight, status.partyStatus or "INACTIVE")
        frame.heroLabel:SetText("Party")
    else
        SetLight(frame.heroLight, pStatus)
        frame.heroLabel:SetText("Run Status")
    end

    -- Member rows (party only: local player first, then peers)
    local usedRows = 0

    if active and inParty then
        usedRows = 1
        SetLight(frame.memberRows[1].light, pStatus)
        frame.memberRows[1].label:SetText((char.name or ShortName(localKey)) .. " *")
        frame.memberRows[1].light:Show()

        for _, peer in ipairs(syncRows) do
            if usedRows >= HUD_MAX_MEMBERS then break end
            usedRows = usedRows + 1
            local raw = self.Sync_GetDisplayStatus and self:Sync_GetDisplayStatus(peer) or peer.participantStatus or "UNSYNCED"
            SetLight(frame.memberRows[usedRows].light, raw)
            frame.memberRows[usedRows].label:SetText(ShortName(peer.name))
            frame.memberRows[usedRows].light:Show()
        end
    end

    for i = usedRows + 1, HUD_MAX_MEMBERS do
        frame.memberRows[i].light:Hide()
        frame.memberRows[i].label:SetText("")
    end

    -- Violation hint (text only, no light needed — yellow is the signal)
    if active and violations > 0 then
        local violY = MEMBER_TOP + usedRows * MEMBER_STEP
        frame.violHint:ClearAllPoints()
        frame.violHint:SetPoint("TOPLEFT", frame, "TOPLEFT", HUD_PAD + 4, violY)
        local word = violations == 1 and "violation" or "violations"
        frame.violHint:SetText("|cfffbbf24" .. violations .. " active " .. word .. "|r")
    else
        frame.violHint:SetText("")
    end

    -- Resize: hero (34px base) + member rows + viol hint row
    local extraRows = usedRows + (active and violations > 0 and 1 or 0)
    frame:SetHeight(extraRows == 0 and 34 or (36 + extraRows * 18))
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

-- ── Minimap button ───────────────────────────────────────────────────────────

local MINIMAP_RADIUS = 80

local function GetMinimapUI()
    SoftcoreDB = SoftcoreDB or {}
    SoftcoreDB.ui = SoftcoreDB.ui or {}
    return SoftcoreDB.ui
end

local function PlaceMinimapButton(button, angle)
    local rad = math.rad(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(rad) * MINIMAP_RADIUS,
        math.sin(rad) * MINIMAP_RADIUS)
end

function SC:MinimapButton_Create()
    if self.minimapButton then return end

    local ui    = GetMinimapUI()
    local angle = ui.minimapAngle or 225

    local button = CreateFrame("Button", "SoftcoreMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\Spell_Shadow_SoulGem")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("CENTER")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local dragging = false

    button:SetScript("OnDragStart", function()
        dragging = true
        button:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local scale  = UIParent:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / scale, cy / scale
            local a = math.deg(math.atan2(cy - my, cx - mx))
            PlaceMinimapButton(button, a)
            GetMinimapUI().minimapAngle = a
        end)
    end)

    button:SetScript("OnDragStop", function()
        button:SetScript("OnUpdate", nil)
        C_Timer.After(0.05, function() dragging = false end)
    end)

    button:SetScript("OnClick", function(_, btn)
        if dragging then return end
        if btn == "RightButton" then
            button:Hide()
            GetMinimapUI().minimapHidden = true
            DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r Minimap button hidden. Type /sc minimap to restore it.")
        else
            if SC.OpenMasterWindow then SC:OpenMasterWindow() end
        end
    end)

    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("Softcore", 1, 1, 1)
        GameTooltip:AddLine("Left-click: open menu", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: hide button", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: reposition", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    PlaceMinimapButton(button, angle)
    if ui.minimapHidden then button:Hide() end

    self.minimapButton = button
end

function SC:MinimapButton_Toggle()
    if not self.minimapButton then
        self:MinimapButton_Create()
        return
    end
    local ui = GetMinimapUI()
    if self.minimapButton:IsShown() then
        self.minimapButton:Hide()
        ui.minimapHidden = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r Minimap button hidden. Type /sc minimap to restore it.")
    else
        self.minimapButton:Show()
        ui.minimapHidden = false
    end
end
