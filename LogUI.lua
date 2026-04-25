-- Log and violation review GUI.
-- Events tab: scrollable event log (read-only).
-- Violations tab: paginated violation list with one-click clearing.

local SC = Softcore

local TAB_EVENTS = "EVENTS"
local TAB_VIOLATIONS = "VIOLATIONS"
local ROWS_PER_PAGE = 13
local ROW_HEIGHT = 24

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

local function RefreshEvents(frame)
    local db = Softcore.db or SoftcoreDB
    local log = (db and db.eventLog) or {}

    frame.eventsMsgFrame:Clear()

    if #log == 0 then
        frame.eventsMsgFrame:AddMessage("|cffaaaaaa(no events recorded)|r")
        return
    end

    for index = #log, 1, -1 do
        local entry = log[index]
        local line = string.format(
            "|cffaaaaaa%s|r |cffffcc00[%s]|r %s",
            FormatTime(entry.time),
            tostring(entry.kind or "?"),
            tostring(entry.message or "")
        )
        frame.eventsMsgFrame:AddMessage(line)
    end

    frame.eventsMsgFrame:ScrollToTop()
end

local function GetSortedViolations()
    local db = Softcore.db or SoftcoreDB
    local source = (db and db.violations) or {}
    local violations = {}

    for _, violation in ipairs(source) do
        if violation.status ~= "CLEARED" then
            table.insert(violations, violation)
        end
    end

    table.sort(violations, function(left, right)
        return (left.createdAt or 0) > (right.createdAt or 0)
    end)

    return violations
end

local function RefreshViolations(frame)
    local violations = GetSortedViolations()
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
        local violation = violations[startIdx + i - 1]

        if violation then
            row:Show()
            row.timeText:SetText(FormatTime(violation.createdAt))
            row.typeText:SetText(Trunc(violation.type or "?", 20))

            row.statusText:SetText("|cffff8888ACTIVE|r")

            row.detailText:SetText(Trunc(violation.detail or "", 44))

            if Softcore:IsViolationClearable(violation) then
                local violationId = violation.id
                row.clearBtn:Show()
                row.clearBtn:SetScript("OnClick", function()
                    SC:ClearViolation(violationId, SC:GetPlayerKey())
                    Print("violation cleared.")
                    SC:LogUI_Refresh()
                end)
            else
                row.clearBtn:Hide()
                row.clearBtn:SetScript("OnClick", nil)
            end
        else
            row:Hide()
            row.clearBtn:SetScript("OnClick", nil)
        end
    end
end

function SC:LogUI_Refresh()
    local frame = self.logFrame
    if not frame or not frame:IsShown() then return end

    frame.eventsTab:SetEnabled(frame.activeTab ~= TAB_EVENTS)
    frame.violationsTab:SetEnabled(frame.activeTab ~= TAB_VIOLATIONS)

    if frame.activeTab == TAB_EVENTS then
        frame.eventsPanel:Show()
        frame.violationsPanel:Hide()
        frame.vPrevBtn:Hide()
        frame.vNextBtn:Hide()
        frame.vPageText:SetText("")
        RefreshEvents(frame)
    else
        frame.eventsPanel:Hide()
        frame.violationsPanel:Show()
        frame.vPrevBtn:Show()
        frame.vNextBtn:Show()
        RefreshViolations(frame)
    end
end

function SC:OpenLogWindow(focusTab)
    if self.logFrame then
        self.logFrame:Show()
        if focusTab then
            self.logFrame.activeTab = focusTab
            self.logFrame.vPage = 1
        end
        self:LogUI_Refresh()
        return
    end

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
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.92)

    frame.activeTab = focusTab or TAB_EVENTS
    frame.vPage = 1

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -14)
    title:SetText("Softcore: Log")

    local topCloseBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    topCloseBtn:SetSize(24, 24)
    topCloseBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -12)
    topCloseBtn:SetText("X")
    topCloseBtn:SetScript("OnClick", function() frame:Hide() end)

    local eventsTab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    eventsTab:SetSize(90, 24)
    eventsTab:SetPoint("TOPLEFT", 18, -44)
    eventsTab:SetText("Events")
    eventsTab:SetScript("OnClick", function()
        frame.activeTab = TAB_EVENTS
        self:LogUI_Refresh()
    end)
    frame.eventsTab = eventsTab

    local violationsTab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    violationsTab:SetSize(90, 24)
    violationsTab:SetPoint("LEFT", eventsTab, "RIGHT", 6, 0)
    violationsTab:SetText("Violations")
    violationsTab:SetScript("OnClick", function()
        frame.activeTab = TAB_VIOLATIONS
        frame.vPage = 1
        self:LogUI_Refresh()
    end)
    frame.violationsTab = violationsTab

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
    evMsgFrame:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    evMsgFrame:SetMaxLines(500)
    evMsgFrame:SetFading(false)
    evMsgFrame:SetJustifyH("LEFT")
    evMsgFrame:EnableMouseWheel(true)
    evMsgFrame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)
    frame.eventsMsgFrame = evMsgFrame
    frame.eventsPanel = eventsPanel

    local vPanel = CreateFrame("Frame", nil, frame)
    vPanel:SetSize(682, 336)
    vPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -76)

    local function VHdr(label, x, w)
        local fs = vPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", x, 0)
        fs:SetWidth(w)
        fs:SetJustifyH("LEFT")
        fs:SetText(label)
    end

    VHdr("Time", 0, 82)
    VHdr("Type", 84, 130)
    VHdr("Status", 216, 72)
    VHdr("Detail", 290, 340)

    local noViolationsText = vPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noViolationsText:SetPoint("TOPLEFT", vPanel, "TOPLEFT", 0, -28)
    noViolationsText:SetWidth(682)
    noViolationsText:SetJustifyH("LEFT")
    noViolationsText:SetText("(no violations recorded)")
    frame.noViolationsText = noViolationsText

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

        row.timeText = Fld(0, 82)
        row.typeText = Fld(84, 130)
        row.statusText = Fld(216, 72)
        row.detailText = Fld(290, 310)

        row.clearBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.clearBtn:SetSize(56, 18)
        row.clearBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -3)
        row.clearBtn:SetText("Clear")
        row.clearBtn:Hide()

        vRows[i] = row
    end
    frame.vRows = vRows
    frame.violationsPanel = vPanel

    local vPrevBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    vPrevBtn:SetSize(70, 22)
    vPrevBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -418)
    vPrevBtn:SetText("< Prev")
    vPrevBtn:SetScript("OnClick", function()
        frame.vPage = math.max(1, (frame.vPage or 1) - 1)
        self:LogUI_Refresh()
    end)
    frame.vPrevBtn = vPrevBtn

    local vPageText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    vPageText:SetPoint("TOP", frame, "TOPLEFT", 360, -422)
    frame.vPageText = vPageText

    local vNextBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    vNextBtn:SetSize(70, 22)
    vNextBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -418)
    vNextBtn:SetText("Next >")
    vNextBtn:SetScript("OnClick", function()
        frame.vPage = (frame.vPage or 1) + 1
        self:LogUI_Refresh()
    end)
    frame.vNextBtn = vNextBtn

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    self.logFrame = frame
    self:LogUI_Refresh()
end
