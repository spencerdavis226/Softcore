-- Log and violation review GUI.
-- Events tab: scrollable event log (read-only).
-- Violations tab: paginated violation list with reason-gated clearing.
-- Gear violations are clearable with a reason; the player is expected to unequip the
-- offending item first. No live gear re-scan is performed at clear time (simpler and safe).

local SC = Softcore

local TAB_EVENTS    = "EVENTS"
local TAB_VIOLATIONS = "VIOLATIONS"
local ROWS_PER_PAGE = 13
local ROW_HEIGHT    = 24

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r " .. tostring(message))
end

local function FormatTime(timestamp)
    if not timestamp then return "--:--" end
    return date("%H:%M:%S", timestamp)
end

local function Trunc(str, maxLen)
    str = tostring(str or "")
    if #str <= maxLen then return str end
    return string.sub(str, 1, maxLen - 2) .. ".."
end

local function StyleSilentButton(button, width, height, label)
    button:SetSize(width, height)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    button:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    button:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER")
    text:SetText(label or "")
    button:SetFontString(text)
    button:SetText(label or "")

    button:SetScript("OnEnter", function(self)
        if self:IsEnabled() then
            self:SetBackdropColor(0.16, 0.16, 0.16, 0.95)
        end
    end)
    button:SetScript("OnLeave", function(self)
        if self:IsEnabled() then
            self:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
        end
    end)
    button:SetScript("OnEnable", function(self)
        self:SetAlpha(1)
        self:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    end)
    button:SetScript("OnDisable", function(self)
        self:SetAlpha(0.55)
        self:SetBackdropColor(0.04, 0.04, 0.04, 0.95)
    end)

    return button
end

local function CreateSilentButton(parent, width, height, label)
    return StyleSilentButton(CreateFrame("Button", nil, parent, "BackdropTemplate"), width, height, label)
end

-- ── Events tab ────────────────────────────────────────────────────────────────

local function RefreshEvents(frame)
    local db = Softcore.db or SoftcoreDB
    local log = (db and db.eventLog) or {}

    frame.eventsMsgFrame:Clear()

    if #log == 0 then
        frame.eventsMsgFrame:AddMessage("|cffaaaaaa(no events recorded)|r")
        return
    end

    for _, entry in ipairs(log) do
        local line = string.format(
            "|cffaaaaaa%s|r |cffffcc00[%s]|r %s",
            FormatTime(entry.time),
            tostring(entry.kind or "?"),
            tostring(entry.message or "")
        )
        frame.eventsMsgFrame:AddMessage(line)
    end

    frame.eventsMsgFrame:ScrollToBottom()
end

-- ── Violations tab ────────────────────────────────────────────────────────────

local function RefreshViolations(frame)
    local db = Softcore.db or SoftcoreDB
    local source = (db and db.violations) or {}
    local violations = {}
    for _, violation in ipairs(source) do
        table.insert(violations, violation)
    end
    table.sort(violations, function(left, right)
        local leftActive = left.status ~= "CLEARED"
        local rightActive = right.status ~= "CLEARED"
        if leftActive ~= rightActive then
            return leftActive
        end
        return (left.createdAt or 0) > (right.createdAt or 0)
    end)
    local total = #violations
    local totalPages = math.max(1, math.ceil(total / ROWS_PER_PAGE))

    frame.vPage = math.min(frame.vPage or 1, totalPages)
    local page = frame.vPage
    local startIdx = (page - 1) * ROWS_PER_PAGE + 1

    frame.vPageText:SetText("Page " .. page .. " of " .. totalPages)

    if page > 1 then frame.vPrevBtn:Enable() else frame.vPrevBtn:Disable() end
    if page < totalPages then frame.vNextBtn:Enable() else frame.vNextBtn:Disable() end
    frame.noViolationsText:SetShown(total == 0)

    for i, row in ipairs(frame.vRows) do
        local v = violations[startIdx + i - 1]
        if v then
            row:Show()
            row.timeText:SetText(FormatTime(v.createdAt))
            row.typeText:SetText(Trunc(v.type or "?", 20))

            if v.status == "CLEARED" then
                row.statusText:SetText("|cff888888CLEARED|r")
            else
                row.statusText:SetText("|cffff8888ACTIVE|r")
            end

            row.detailText:SetText(Trunc(v.detail or "", 44))

            if Softcore:IsViolationClearable(v) then
                row.clearBtn:Show()
                local vid  = v.id
                local vtyp = v.type
                row.clearBtn:SetScript("OnClick", function()
                    frame.pendingClearId = vid
                    frame.pendingClearLabel:SetText(
                        "Clear \"" .. tostring(vtyp) .. "\" violation — enter a reason:"
                    )
                    frame.reasonBox:SetText("")
                    frame.reasonError:SetText("")
                    frame.reasonPanel:Show()
                    frame.reasonBox:SetFocus()
                end)
            else
                row.clearBtn:Hide()
            end
        else
            row:Hide()
        end
    end
end

-- ── Main refresh dispatcher ───────────────────────────────────────────────────

function SC:LogUI_Refresh()
    local frame = self.logFrame
    if not frame or not frame:IsShown() then return end

    -- Dim the active tab button so it reads as selected
    frame.eventsTab:SetEnabled(frame.activeTab ~= TAB_EVENTS)
    frame.violationsTab:SetEnabled(frame.activeTab ~= TAB_VIOLATIONS)

    if frame.activeTab == TAB_EVENTS then
        frame.eventsPanel:Show()
        frame.violationsPanel:Hide()
        frame.vPrevBtn:Hide()
        frame.vNextBtn:Hide()
        frame.vPageText:SetText("")
        frame.reasonPanel:Hide()
        RefreshEvents(frame)
    else
        frame.eventsPanel:Hide()
        frame.violationsPanel:Show()
        frame.vPrevBtn:Show()
        frame.vNextBtn:Show()
        RefreshViolations(frame)
    end
end

-- ── Window builder ────────────────────────────────────────────────────────────

function SC:OpenLogWindow(focusTab)
    if self.logFrame then
        self.logFrame:Show()
        if focusTab then
            self.logFrame.activeTab = focusTab
            self.logFrame.vPage = 1
            self.logFrame.pendingClearId = nil
            self.logFrame.reasonPanel:Hide()
        end
        self:LogUI_Refresh()
        return
    end

    -- Frame: 720 × 560
    local frame = CreateFrame("Frame", "SoftcoreLogFrame", UIParent, "BackdropTemplate")
    frame:SetSize(720, 560)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:EnableKeyboard(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)
    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.92)

    frame.activeTab      = focusTab or TAB_EVENTS
    frame.vPage          = 1
    frame.pendingClearId = nil

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -14)
    title:SetText("Softcore: Log")

    local topCloseBtn = CreateSilentButton(frame, 24, 24, "X")
    topCloseBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -12)
    topCloseBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Tab buttons
    local eventsTab = CreateSilentButton(frame, 90, 24, "Events")
    eventsTab:SetPoint("TOPLEFT", 18, -44)
    eventsTab:SetScript("OnClick", function()
        frame.activeTab = TAB_EVENTS
        frame.pendingClearId = nil
        frame.reasonPanel:Hide()
        self:LogUI_Refresh()
    end)
    frame.eventsTab = eventsTab

    local violationsTab = CreateSilentButton(frame, 90, 24, "Violations")
    violationsTab:SetPoint("LEFT", eventsTab, "RIGHT", 6, 0)
    violationsTab:SetScript("OnClick", function()
        frame.activeTab = TAB_VIOLATIONS
        frame.vPage = 1
        frame.pendingClearId = nil
        frame.reasonPanel:Hide()
        self:LogUI_Refresh()
    end)
    frame.violationsTab = violationsTab

    -- ── Events panel (ScrollingMessageFrame) ─────────────────────────────────
    -- y=-76 → height 336 → bottom edge at y=-412
    local eventsPanel = CreateFrame("Frame", nil, frame)
    eventsPanel:SetSize(682, 336)
    eventsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -76)

    local evHdr = eventsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    evHdr:SetPoint("TOPLEFT", 0, 0)
    evHdr:SetText("Time          [Type]  Message")
    evHdr:SetJustifyH("LEFT")

    local evMsgFrame = CreateFrame("ScrollingMessageFrame", nil, eventsPanel)
    evMsgFrame:SetSize(682, 310)
    evMsgFrame:SetPoint("TOPLEFT", eventsPanel, "TOPLEFT", 0, -22)
    evMsgFrame:SetFont("Fonts\\FRIZQT__.TTF", 11)
    evMsgFrame:SetMaxLines(500)
    evMsgFrame:SetFading(false)
    evMsgFrame:SetJustifyH("LEFT")
    evMsgFrame:EnableMouseWheel(true)
    evMsgFrame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)
    frame.eventsMsgFrame = evMsgFrame
    frame.eventsPanel    = eventsPanel

    -- ── Violations panel (paginated rows) ────────────────────────────────────
    -- Same position/size as events panel
    local vPanel = CreateFrame("Frame", nil, frame)
    vPanel:SetSize(682, 336)
    vPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -76)

    -- Column headers
    local function VHdr(label, x, w)
        local fs = vPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", x, 0)
        fs:SetWidth(w)
        fs:SetJustifyH("LEFT")
        fs:SetText(label)
    end
    VHdr("Time",   0,   82)
    VHdr("Type",   84,  130)
    VHdr("Status", 216, 72)
    VHdr("Detail", 290, 340)

    local noViolationsText = vPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noViolationsText:SetPoint("TOPLEFT", vPanel, "TOPLEFT", 0, -28)
    noViolationsText:SetWidth(682)
    noViolationsText:SetJustifyH("LEFT")
    noViolationsText:SetText("(no violations recorded)")
    frame.noViolationsText = noViolationsText

    -- Violation rows (ROWS_PER_PAGE = 13)
    local vRows = {}
    for i = 1, ROWS_PER_PAGE do
        local row = CreateFrame("Frame", nil, vPanel)
        row:SetSize(682, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", vPanel, "TOPLEFT", 0, -22 - (i - 1) * ROW_HEIGHT)

        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.04)
        end

        local function Fld(x, w)
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("TOPLEFT", x, -3)
            fs:SetWidth(w)
            fs:SetJustifyH("LEFT")
            return fs
        end

        row.timeText   = Fld(0,   82)
        row.typeText   = Fld(84,  130)
        row.statusText = Fld(216, 72)
        row.detailText = Fld(290, 310)

        row.clearBtn = CreateSilentButton(row, 56, 18, "Clear")
        row.clearBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -3)
        row.clearBtn:Hide()

        vRows[i] = row
    end
    frame.vRows         = vRows
    frame.violationsPanel = vPanel

    -- ── Pagination (below the panels, always child of frame) ─────────────────
    -- Panels end at y=-(76+336)=y=-412; pagination row at y=-418
    local vPrevBtn = CreateSilentButton(frame, 70, 22, "< Prev")
    vPrevBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -418)
    vPrevBtn:SetScript("OnClick", function()
        frame.vPage = math.max(1, (frame.vPage or 1) - 1)
        self:LogUI_Refresh()
    end)
    frame.vPrevBtn = vPrevBtn

    local vPageText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    vPageText:SetPoint("TOP", frame, "TOPLEFT", 360, -422)
    frame.vPageText = vPageText

    local vNextBtn = CreateSilentButton(frame, 70, 22, "Next >")
    vNextBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -418)
    vNextBtn:SetScript("OnClick", function()
        frame.vPage = (frame.vPage or 1) + 1
        self:LogUI_Refresh()
    end)
    frame.vNextBtn = vNextBtn

    -- ── Reason panel (shown when Clear is clicked on a violation) ─────────────
    -- Anchored below pagination, at y=-448; height 52
    local reasonPanel = CreateFrame("Frame", nil, frame)
    reasonPanel:SetSize(682, 52)
    reasonPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -448)

    local pendingClearLabel = reasonPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pendingClearLabel:SetPoint("TOPLEFT", 0, 0)
    pendingClearLabel:SetWidth(682)
    pendingClearLabel:SetJustifyH("LEFT")
    frame.pendingClearLabel = pendingClearLabel

    local reasonBox = CreateFrame("EditBox", nil, reasonPanel, "InputBoxTemplate")
    reasonBox:SetSize(430, 22)
    reasonBox:SetPoint("TOPLEFT", reasonPanel, "TOPLEFT", 0, -20)
    reasonBox:SetAutoFocus(false)
    reasonBox:SetMaxLetters(200)
    frame.reasonBox = reasonBox

    local confirmBtn = CreateSilentButton(reasonPanel, 80, 22, "Confirm")
    confirmBtn:SetPoint("LEFT", reasonBox, "RIGHT", 8, 0)
    confirmBtn:SetScript("OnClick", function()
        local reason = strtrim(reasonBox:GetText() or "")
        if reason == "" then
            frame.reasonError:SetText("|cffff4444Enter a reason to clear this violation.|r")
            return
        end
        if frame.pendingClearId then
            self:ClearViolation(frame.pendingClearId, self:GetPlayerKey(), reason)
            Print("violation cleared.")
        end
        frame.pendingClearId = nil
        reasonPanel:Hide()
        self:LogUI_Refresh()
    end)

    local cancelClearBtn = CreateSilentButton(reasonPanel, 70, 22, "Cancel")
    cancelClearBtn:SetPoint("LEFT", confirmBtn, "RIGHT", 6, 0)
    cancelClearBtn:SetScript("OnClick", function()
        frame.pendingClearId = nil
        frame.reasonError:SetText("")
        reasonPanel:Hide()
    end)

    local reasonError = reasonPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reasonError:SetPoint("TOPLEFT", reasonPanel, "TOPLEFT", 0, -46)
    reasonError:SetWidth(682)
    reasonError:SetJustifyH("LEFT")
    frame.reasonError = reasonError

    reasonPanel:Hide()
    frame.reasonPanel = reasonPanel

    -- ── Close button ──────────────────────────────────────────────────────────
    local closeBtn = CreateSilentButton(frame, 80, 24, "Close")
    closeBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    self.logFrame = frame
    self:LogUI_Refresh()
end
