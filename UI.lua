-- Compact run-status HUD. Auto-shows when a run is active, hides when not.
-- Click to toggle the Softcore menu. Drag to reposition. /sc hud to show/hide.

local SC = Softcore
local MINIMAP_LOGO_TEXTURE = "Interface\\AddOns\\Softcore\\Assets\\SoftcoreLogoMinimap"

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

-- ── HUD ──────────────────────────────────────────────────────────────────────

local HUD_W        = 130
local HUD_PAD      = 8
local ROW_H        = 22
local DOT_SIZE     = 8
local HUD_MAX_ROWS = 6

-- Maps status prefix → RGB color (green=ok, yellow=warning, red=failed, grey=inactive)
local STATUS_COLOR = {
    ACTIVE     = {0.29, 0.85, 0.50},
    VALID      = {0.29, 0.85, 0.50},
    FAILED     = {1.00, 0.27, 0.27},
    BLOCKED    = {0.98, 0.75, 0.14},
    CONFLICT   = {0.98, 0.75, 0.14},
    VIOLATION  = {0.98, 0.75, 0.14},
    WARNING    = {0.98, 0.75, 0.14},
    UNSYNCED   = {0.61, 0.64, 0.69},
    INACTIVE   = {0.61, 0.64, 0.69},
    NOT_IN_RUN = {0.61, 0.64, 0.69},
}

local function SetStatusDot(texture, statusStr)
    local base = statusStr and string.match(statusStr, "^(%u+)")
    local c = (base and STATUS_COLOR[base]) or STATUS_COLOR.INACTIVE
    texture:SetColorTexture(c[1], c[2], c[3], 1)
    texture:SetSize(DOT_SIZE, DOT_SIZE)
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

function SC:HUD_Create()
    if self.hudFrame then
        self:HUD_Refresh()
        return
    end

    local frame = CreateFrame("Button", "SoftcoreHUDFrame", UIParent, "BackdropTemplate")
    frame:SetSize(HUD_W, HUD_PAD * 2 + ROW_H)
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
        if SC.OpenMasterWindow and LocalActiveViolations() > 0 then
            SC:OpenMasterWindow("VIOLATIONS")
        elseif SC.ToggleMasterWindow then
            SC:ToggleMasterWindow()
        end
    end)
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.08, 0.045, 0.02, 0.96)
    frame:SetBackdropBorderColor(0.72, 0.49, 0.18, 0.85)
    frame:Hide()

    frame.rows = {}
    for i = 1, HUD_MAX_ROWS do
        local dot = frame:CreateTexture(nil, "OVERLAY")
        dot:SetPoint("CENTER", frame, "TOPLEFT",
            HUD_PAD + DOT_SIZE / 2,
            -HUD_PAD - (i - 1) * ROW_H - ROW_H / 2)
        local mask = frame:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMaskSmall",
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(dot)
        dot:AddMaskTexture(mask)

        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", frame, "TOPLEFT",
            HUD_PAD + DOT_SIZE + 6,
            -HUD_PAD - (i - 1) * ROW_H)
        label:SetSize(HUD_W - HUD_PAD * 2 - DOT_SIZE - 6, ROW_H)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("MIDDLE")

        dot:Hide()
        label:Hide()
        frame.rows[i] = { dot = dot, label = label }
    end

    frame.violLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.violLabel:SetSize(HUD_W - HUD_PAD * 2, ROW_H)
    frame.violLabel:SetJustifyH("LEFT")
    frame.violLabel:SetJustifyV("MIDDLE")
    frame.violLabel:Hide()

    self.hudFrame = frame
    self:HUD_Refresh()
end

function SC:HUD_Refresh()
    local frame = self.hudFrame
    if not frame then return end

    local db     = self.db or SoftcoreDB
    local run    = db and db.run or {}
    local active = run.active
    local ui     = SoftcoreDB and SoftcoreDB.ui or {}

    if not active or ui.hudHidden then
        frame:Hide()
        return
    end

    local status     = self:GetPlayerStatus()
    local pStatus    = status.participantStatus or "NOT_IN_RUN"
    local syncRows   = self.Sync_GetGroupRows and self:Sync_GetGroupRows() or {}
    local inParty    = IsInGroup() and #syncRows > 0
    local violations = LocalActiveViolations()

    local entries = {}
    table.insert(entries, {
        name    = inParty and "Party Status" or "Run Status",
        status  = inParty and (status.partyStatus or pStatus) or pStatus,
        isLocal = true,
    })
    if inParty then
        for _, peer in ipairs(syncRows) do
            if #entries >= HUD_MAX_ROWS then break end
            local raw = self.Sync_GetDisplayStatus and self:Sync_GetDisplayStatus(peer)
                     or peer.participantStatus or "UNSYNCED"
            table.insert(entries, { name = ShortName(peer.name), status = raw })
        end
    end

    for i, entry in ipairs(entries) do
        local row = frame.rows[i]
        SetStatusDot(row.dot, entry.status)
        row.label:SetText(entry.name)
        if entry.isLocal then
            row.label:SetTextColor(1, 0.82, 0.20)
        else
            row.label:SetTextColor(0.94, 0.86, 0.68)
        end
        row.dot:Show()
        row.label:Show()
    end
    for i = #entries + 1, HUD_MAX_ROWS do
        frame.rows[i].dot:Hide()
        frame.rows[i].label:Hide()
    end

    local totalRows = #entries
    if violations > 0 then
        frame.violLabel:ClearAllPoints()
        frame.violLabel:SetPoint("TOPLEFT", frame, "TOPLEFT",
            HUD_PAD, -HUD_PAD - totalRows * ROW_H)
        local word = violations == 1 and "violation" or "violations"
        frame.violLabel:SetText("|cfffbbf24" .. violations .. " active " .. word .. "|r")
        frame.violLabel:Show()
        totalRows = totalRows + 1
    else
        frame.violLabel:Hide()
    end

    frame:SetHeight(HUD_PAD * 2 + totalRows * ROW_H)
    frame:Show()
end

function SC:HUD_Toggle()
    if not self.hudFrame then
        self:HUD_Create()
        return
    end
    SoftcoreDB = SoftcoreDB or {}
    SoftcoreDB.ui = SoftcoreDB.ui or {}
    SoftcoreDB.ui.hudHidden = not SoftcoreDB.ui.hudHidden
    self:HUD_Refresh()
    if SoftcoreDB.ui.hudHidden then
        DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r Status HUD hidden. Type /sc hud to restore.")
    end
end

-- ── Minimap button ───────────────────────────────────────────────────────────

local MINIMAP_RADIUS = 98

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
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
    icon:SetTexture(MINIMAP_LOGO_TEXTURE)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:RegisterForClicks("LeftButtonUp")
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

    button:SetScript("OnClick", function()
        if dragging then return end
        if SC.ToggleMasterWindow then SC:ToggleMasterWindow() end
    end)

    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("Softcore", 1, 1, 1)
        GameTooltip:AddLine("/sc minimap to hide this button", 0.6, 0.6, 0.6)
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
