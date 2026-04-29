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

local HUD_W    = 118
local HUD_H    = 26
local HUD_PAD  = 8
local DOT_SIZE = 10

local LAMP_COLOR = {
    GREEN  = {0.22, 0.95, 0.42},
    BLUE   = {0.26, 0.58, 1.00},
    YELLOW = {1.00, 0.78, 0.16},
    ORANGE = {1.00, 0.42, 0.12},
    RED    = {1.00, 0.18, 0.14},
    GRAY   = {0.48, 0.50, 0.54},
}

local TEXT_COLOR = {
    GREEN  = {0.62, 1.00, 0.68},
    BLUE   = {0.58, 0.78, 1.00},
    YELLOW = {1.00, 0.86, 0.32},
    ORANGE = {1.00, 0.62, 0.28},
    RED    = {1.00, 0.38, 0.32},
    GRAY   = {0.66, 0.68, 0.72},
}

local function SetLamp(frame, state)
    local c = LAMP_COLOR[state] or LAMP_COLOR.GRAY
    frame.lamp:SetColorTexture(c[1], c[2], c[3], 1)
    frame.lampGlow:SetVertexColor(c[1], c[2], c[3], 0.55)
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

local function HasRemoteFailure(syncRows)
    local db = SC.db or SoftcoreDB
    local localKey = SC:GetPlayerKey()

    for playerKey, participant in pairs(db and db.run and db.run.participants or {}) do
        if playerKey ~= localKey and participant.status == "FAILED" then
            if not SC.IsParticipantInCurrentParty or SC:IsParticipantInCurrentParty(playerKey) then
                return true
            end
        end
    end

    for _, peer in ipairs(syncRows or {}) do
        if peer.participantStatus == "FAILED" or peer.failed or peer.valid == false then
            return true
        end
    end
    return false
end

local function GetPendingRuleAmendment(db)
    for _, amendment in ipairs(db and db.ruleAmendments or {}) do
        if amendment.status == "PENDING" or amendment.status == "ACCEPTED" then
            return amendment
        end
    end
    return nil
end

local function HasRecentRuleGovernance(db)
    local now = time()
    for _, amendment in ipairs(db and db.ruleAmendments or {}) do
        local settledAt = amendment.appliedAt or amendment.declinedAt or amendment.expiredAt or amendment.noChangesAt
        if settledAt and now - tonumber(settledAt) <= 12 then
            return true
        end
    end
    return false
end

local function GetGovernanceHUDState(db)
    local proposal = SC.GetPendingProposal and SC:GetPendingProposal() or nil
    if proposal then
        local localKey = SC:GetPlayerKey()
        local isProposer = proposal.proposedBy == localKey

        if proposal.detailsPending then
            return "YELLOW", "Details", "RUN"
        elseif proposal.status == "ACCEPTED" then
            return "YELLOW", "Waiting", "RUN"
        elseif isProposer then
            return "YELLOW", "Waiting", "RUN"
        elseif proposal.proposalType == "ADD_PARTICIPANT" then
            return "YELLOW", "Invite", "RUN"
        elseif proposal.proposalType == "SYNC_RUN" then
            return "YELLOW", "Run Sync", "RUN"
        end

        return "YELLOW", "Review", "RUN"
    end

    local amendment = GetPendingRuleAmendment(db)
    if amendment then
        if amendment.detailsPending then
            return "YELLOW", "Details", "RUN"
        elseif amendment.status == "ACCEPTED" then
            return "BLUE", "Settling", "RUN"
        elseif amendment.proposedBy == SC:GetPlayerKey() then
            return "YELLOW", "Waiting", "RUN"
        end

        return "YELLOW", "Rule Review", "RUN"
    end

    if HasRecentRuleGovernance(db) then
        return "BLUE", "Settling", "RUN"
    end

    local plan = db and db.partySyncPlan
    if plan and plan.active and plan.owner == SC:GetPlayerKey() then
        local route = SC.GetPartySyncAction and SC:GetPartySyncAction(true) or nil
        if route then
            if route.action == "RESYNC" then
                return "BLUE", "Syncing", "RUN"
            elseif route.action == "AMEND_RULES" then
                return "YELLOW", "Rules", "RUN"
            elseif route.action == "SYNC_RUN" then
                return "YELLOW", "Run Sync", "RUN"
            elseif route.action == "INVITE" then
                return "YELLOW", "Invite", "RUN"
            elseif route.action == "BLOCKED" then
                return "YELLOW", "Blocked", "RUN"
            elseif route.action == "NONE" then
                return "GREEN", "Synced", "OVERVIEW"
            end
        end

        return "BLUE", "Syncing", "RUN"
    end

    return nil
end

local function GetHUDState(status, violations, syncRows)
    local db = SC.db or SoftcoreDB
    local localStatus = status.participantStatus or "NOT_IN_RUN"
    local partyStatus = status.partyStatus or localStatus

    if localStatus == "FAILED" or status.failed or status.valid == false then
        return "RED", "Failed", "OVERVIEW"
    end

    local governanceState, governanceText, governanceTab = GetGovernanceHUDState(db)
    if governanceState then
        return governanceState, governanceText, governanceTab
    end

    if violations > 0 or localStatus == "WARNING" or localStatus == "VIOLATION" then
        local text = violations == 1 and "1 Violation" or tostring(violations) .. " Violations"
        if violations <= 0 then text = "Violation" end
        return "YELLOW", text, "VIOLATIONS"
    end

    if HasRemoteFailure(syncRows) then
        return "ORANGE", "Party Fail", "OVERVIEW"
    end

    if partyStatus == "BLOCKED" then
        return "YELLOW", "Blocked", "OVERVIEW"
    elseif partyStatus == "CONFLICT" then
        return "YELLOW", "Conflict", "OVERVIEW"
    elseif partyStatus == "UNSYNCED" then
        return "YELLOW", "Unsynced", "OVERVIEW"
    elseif partyStatus == "VIOLATION" or partyStatus == "WARNING" then
        return "YELLOW", "Warning", "OVERVIEW"
    elseif localStatus == "PENDING" then
        return "YELLOW", "Pending", "RUN"
    elseif localStatus == "NOT_IN_RUN" then
        return "GRAY", "No Run", "RUN"
    end

    return "GREEN", "Valid", "OVERVIEW"
end

function SC:HUD_Create()
    if self.hudFrame then
        self:HUD_Refresh()
        return
    end

    local frame = CreateFrame("Button", "SoftcoreHUDFrame", UIParent, "BackdropTemplate")
    frame:SetSize(HUD_W, HUD_H)
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
        if SC.ToggleMasterWindow then
            SC:ToggleMasterWindow(frame.focusTab or "OVERVIEW")
        elseif SC.OpenMasterWindow then
            SC:OpenMasterWindow(frame.focusTab or "OVERVIEW")
        end
    end)
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.055, 0.032, 0.014, 0.94)
    frame:SetBackdropBorderColor(0.78, 0.56, 0.24, 0.92)
    frame:Hide()

    local shine = frame:CreateTexture(nil, "BACKGROUND")
    shine:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    shine:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    shine:SetColorTexture(0.85, 0.58, 0.18, 0.08)

    frame.lampGlow = frame:CreateTexture(nil, "ARTWORK")
    frame.lampGlow:SetTexture("Interface\\GLUES\\Models\\UI_Draenei\\GenericGlow64")
    frame.lampGlow:SetBlendMode("ADD")
    frame.lampGlow:SetSize(22, 22)
    frame.lampGlow:SetPoint("LEFT", frame, "LEFT", 2, 0)

    frame.lamp = frame:CreateTexture(nil, "OVERLAY")
    frame.lamp:SetSize(DOT_SIZE, DOT_SIZE)
    frame.lamp:SetPoint("LEFT", frame, "LEFT", HUD_PAD, 0)
    local mask = frame:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMaskSmall",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(frame.lamp)
    frame.lamp:AddMaskTexture(mask)

    frame.statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.statusText:SetPoint("LEFT", frame.lamp, "RIGHT", 8, 0)
    frame.statusText:SetSize(HUD_W - 34, 18)
    frame.statusText:SetJustifyH("LEFT")
    frame.statusText:SetJustifyV("MIDDLE")
    frame.statusText:SetMaxLines(1)

    frame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:SetText("Softcore HUD", 1, 1, 1)
        GameTooltip:AddLine("Click to open or close details. Drag to move.", 0.74, 0.66, 0.50)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

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

    local status     = self:GetPlayerStatus()
    local syncRows   = self.Sync_GetGroupRows and self:Sync_GetGroupRows() or {}
    local violations = LocalActiveViolations()
    local state, text, focusTab = GetHUDState(status, violations, syncRows)
    local textColor = TEXT_COLOR[state] or TEXT_COLOR.GRAY
    local showForGovernance = (focusTab == "RUN" and text ~= "No Run")

    if ui.hudHidden or (not active and not showForGovernance) then
        frame:Hide()
        return
    end

    frame.focusTab = focusTab
    SetLamp(frame, state)
    frame.statusText:SetText(text)
    frame.statusText:SetTextColor(textColor[1], textColor[2], textColor[3])
    frame:SetSize(HUD_W, HUD_H)
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
