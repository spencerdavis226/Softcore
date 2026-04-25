-- Master menu for the main Softcore UI.

local SC = Softcore

local TAB_START = "START"
local TAB_STATUS = "STATUS"
local TAB_VIOLATIONS = "VIOLATIONS"
local TAB_LOG = "LOG"
local TAB_RULES = "RULES"
local TAB_PARTY = "PARTY"

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r " .. tostring(message))
end

local function FormatTime(timestamp)
    if not timestamp then return "never" end
    return date("%Y-%m-%d %H:%M:%S", timestamp)
end

local function Trunc(str, maxLen)
    str = tostring(str or "")
    if #str <= maxLen then return str end
    return string.sub(str, 1, maxLen - 2) .. ".."
end

local function SetLine(fontString, label, value)
    fontString:SetText(label .. ": " .. tostring(value))
end

local function IsActiveRun()
    local db = SC.db or SoftcoreDB
    return db and db.run and db.run.active
end

local function GetDefaultTab()
    return IsActiveRun() and TAB_STATUS or TAB_START
end

local function NormalizeTab(tab)
    if tab == TAB_LOG or tab == TAB_RULES or tab == TAB_PARTY or tab == TAB_VIOLATIONS then
        return tab
    end

    if tab == TAB_START and not IsActiveRun() then
        return TAB_START
    end

    if tab == TAB_STATUS and IsActiveRun() then
        return TAB_STATUS
    end

    return GetDefaultTab()
end

local function CreateButton(parent, label, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 90, height or 24)
    button:SetText(label)
    return button
end

local function CreatePanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetSize(672, 420)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, -92)
    return panel
end

local function CreateField(parent, x, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(width or 620)
    fs:SetJustifyH("LEFT")
    fs:SetText("")
    return fs
end

local function GetSortedActiveViolations()
    local db = SC.db or SoftcoreDB
    local source = (db and db.violations) or {}
    local result = {}

    for _, violation in ipairs(source) do
        if violation.status ~= "CLEARED" then
            table.insert(result, violation)
        end
    end

    table.sort(result, function(left, right)
        return (left.createdAt or 0) > (right.createdAt or 0)
    end)

    return result
end

local function RefreshStatusPanel(frame)
    local db = SC.db or SoftcoreDB
    local run = db and db.run or {}
    local status = SC:GetPlayerStatus()

    SetLine(frame.status.run, "Run", run.runName or "Softcore Run")
    SetLine(frame.status.localStatus, "You", status.participantStatus or "NOT_IN_RUN")
    SetLine(frame.status.partyStatus, "Party", status.partyStatus or "INACTIVE")
    SetLine(frame.status.started, "Started", FormatTime(run.startTime))
    SetLine(frame.status.deaths, "Deaths", run.deathCount or 0)
    SetLine(frame.status.violations, "Active violations", #GetSortedActiveViolations())
    SetLine(frame.status.runId, "Run ID", run.runId or "none")
end

local function RefreshStartPanel(frame)
    local active = IsActiveRun()

    frame.start.inactiveText:SetShown(not active)
    frame.start.activeText:SetShown(active)
    frame.start.startDefaultBtn:SetShown(not active)
    frame.start.configureBtn:SetShown(not active)
end

local function RefreshViolationsPanel(frame)
    local violations = GetSortedActiveViolations()

    frame.violations.empty:SetShown(#violations == 0)

    for index, row in ipairs(frame.violations.rows) do
        local violation = violations[index]

        if violation then
            row:Show()
            row.type:SetText(Trunc(violation.type or "?", 18))
            row.detail:SetText(Trunc(violation.detail or "", 58))
            row.time:SetText(FormatTime(violation.createdAt))

            if SC:IsViolationClearable(violation) then
                local violationId = violation.id
                row.clearBtn:Show()
                row.clearBtn:SetScript("OnClick", function()
                    SC:ClearViolation(violationId, SC:GetPlayerKey())
                    Print("violation cleared.")
                    SC:MasterUI_Refresh()
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

local function RefreshLogPanel(frame)
    local db = SC.db or SoftcoreDB
    local log = (db and db.eventLog) or {}

    frame.log.events:Clear()

    if #log == 0 then
        frame.log.events:AddMessage("|cffaaaaaa(no events recorded)|r")
        return
    end

    for _, entry in ipairs(log) do
        frame.log.events:AddMessage(string.format(
            "|cffaaaaaa%s|r |cffffcc00[%s]|r %s",
            FormatTime(entry.time),
            tostring(entry.kind or "?"),
            tostring(entry.message or "")
        ))
    end

    frame.log.events:ScrollToBottom()
end

local function RefreshRulesPanel(frame)
    local db = SC.db or SoftcoreDB
    local rules = db and db.run and db.run.ruleset or SC:GetDefaultRuleset()
    local order = SC.GetRuleOrder and SC:GetRuleOrder() or {}

    for index, row in ipairs(frame.rules.rows) do
        local ruleName = order[index]
        if ruleName then
            row:Show()
            row:SetText(ruleName .. " = " .. tostring(rules[ruleName]))
        else
            row:Hide()
        end
    end
end

local function RefreshPartyPanel(frame)
    local db = SC.db or SoftcoreDB
    local rows = SC.Sync_GetGroupRows and SC:Sync_GetGroupRows() or {}
    local participantOrder = db and db.run and db.run.participantOrder or {}
    local participants = db and db.run and db.run.participants or {}

    frame.party.empty:SetShown(#rows == 0 and #participantOrder <= 1)

    for index, row in ipairs(frame.party.rows) do
        local peer = rows[index]
        local participantKey = participantOrder[index]
        local participant = participantKey and participants[participantKey]

        if peer then
            row:Show()
            row:SetText((peer.name or peer.playerKey or "Unknown") .. " - " .. tostring(SC.Sync_GetDisplayStatus and SC:Sync_GetDisplayStatus(peer) or peer.participantStatus or "UNKNOWN"))
        elseif participant then
            row:Show()
            row:SetText(tostring(participant.playerKey) .. " - " .. tostring(participant.status or "UNKNOWN"))
        else
            row:Hide()
        end
    end
end

local function ConfirmStopRun()
    if not StaticPopupDialogs or not StaticPopup_Show then
        SC:ResetRun()
        if SC.masterFrame then
            SC.masterFrame.activeTab = TAB_START
            SC:MasterUI_Refresh()
        end
        return
    end

    StaticPopupDialogs["SOFTCORE_STOP_RUN"] = StaticPopupDialogs["SOFTCORE_STOP_RUN"] or {
        text = "Stop this Softcore run?\n\nThis archives the current local run data and returns this character to inactive state.",
        button1 = "Stop Run",
        button2 = "Cancel",
        OnAccept = function()
            SC:ResetRun()
            if SC.masterFrame then
                SC.masterFrame.activeTab = TAB_START
                SC:MasterUI_Refresh()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopup_Show("SOFTCORE_STOP_RUN")
end

function SC:MasterUI_Refresh()
    local frame = self.masterFrame
    if not frame or not frame:IsShown() then return end

    frame.activeTab = NormalizeTab(frame.activeTab)

    frame.startTab:SetShown(not IsActiveRun())
    frame.statusTab:SetShown(IsActiveRun())

    for tabName, panel in pairs(frame.panels) do
        panel:SetShown(tabName == frame.activeTab)
    end

    frame.startTab:SetEnabled(frame.activeTab ~= TAB_START)
    frame.statusTab:SetEnabled(frame.activeTab ~= TAB_STATUS)
    frame.violationsTab:SetEnabled(frame.activeTab ~= TAB_VIOLATIONS)
    frame.logTab:SetEnabled(frame.activeTab ~= TAB_LOG)
    frame.rulesTab:SetEnabled(frame.activeTab ~= TAB_RULES)
    frame.partyTab:SetEnabled(frame.activeTab ~= TAB_PARTY)

    RefreshStartPanel(frame)
    RefreshStatusPanel(frame)
    RefreshViolationsPanel(frame)
    RefreshLogPanel(frame)
    RefreshRulesPanel(frame)
    RefreshPartyPanel(frame)
end

function SC:OpenMasterWindow(focusTab)
    if self.masterFrame then
        self.masterFrame:Show()
        self.masterFrame.activeTab = NormalizeTab(focusTab or self.masterFrame.activeTab)
        self:MasterUI_Refresh()
        return
    end

    local frame = CreateFrame("Frame", "SoftcoreMasterFrame", UIParent, "BackdropTemplate")
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
    frame.activeTab = NormalizeTab(focusTab)
    frame.panels = {}

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -14)
    title:SetText("Softcore")

    local closeBtn = CreateButton(frame, "X", 24, 24)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -12)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    local function AddTab(fieldName, label, tabName, relativeTo)
        local tab = CreateButton(frame, label, 92, 24)
        if relativeTo then
            tab:SetPoint("LEFT", relativeTo, "RIGHT", 6, 0)
        else
            tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -52)
        end
        tab:SetScript("OnClick", function()
            frame.activeTab = tabName
            SC:MasterUI_Refresh()
        end)
        frame[fieldName] = tab
        return tab
    end

    local firstTab = AddTab("startTab", "Start", TAB_START)
    AddTab("statusTab", "Status", TAB_STATUS)
    local violationsTab = AddTab("violationsTab", "Violations", TAB_VIOLATIONS, firstTab)
    local logTab = AddTab("logTab", "Log", TAB_LOG, violationsTab)
    local rulesTab = AddTab("rulesTab", "Rules", TAB_RULES, logTab)
    AddTab("partyTab", "Party", TAB_PARTY, rulesTab)

    local startPanel = CreatePanel(frame)
    frame.panels[TAB_START] = startPanel
    frame.start = {}
    frame.start.inactiveText = CreateField(startPanel, 0, 0, 620)
    frame.start.inactiveText:SetText("No active Softcore run.")
    frame.start.activeText = CreateField(startPanel, 0, 0, 620)
    frame.start.activeText:SetText("A run is already active. Use the Status tab to review or stop it.")
    frame.start.startDefaultBtn = CreateButton(startPanel, "Start Run", 120, 24)
    frame.start.startDefaultBtn:SetPoint("TOPLEFT", startPanel, "TOPLEFT", 0, -36)
    frame.start.startDefaultBtn:SetScript("OnClick", function()
        local ruleset = SC:GetDefaultRuleset()
        if IsInGroup() then
            if SC.CreateRunProposal then
                SC:CreateRunProposal("Softcore Run", ruleset, "RUN")
            else
                Print("proposal handling is not loaded.")
            end
        else
            SC:StartRun({
                runName = "Softcore Run",
                ruleset = ruleset,
            })
            frame.activeTab = TAB_STATUS
        end
        SC:MasterUI_Refresh()
    end)
    frame.start.configureBtn = CreateButton(startPanel, "Configure Rules", 130, 24)
    frame.start.configureBtn:SetPoint("LEFT", frame.start.startDefaultBtn, "RIGHT", 8, 0)
    frame.start.configureBtn:SetScript("OnClick", function()
        if SC.OpenStartRunWindow then
            SC:OpenStartRunWindow()
        end
    end)

    local statusPanel = CreatePanel(frame)
    frame.panels[TAB_STATUS] = statusPanel
    frame.status = {
        run = CreateField(statusPanel, 0, 0),
        localStatus = CreateField(statusPanel, 0, -24),
        partyStatus = CreateField(statusPanel, 0, -48),
        started = CreateField(statusPanel, 0, -72),
        deaths = CreateField(statusPanel, 0, -96),
        violations = CreateField(statusPanel, 0, -120),
        runId = CreateField(statusPanel, 0, -144),
    }
    local stopBtn = CreateButton(statusPanel, "Stop Run", 100, 24)
    stopBtn:SetPoint("TOPLEFT", statusPanel, "TOPLEFT", 0, -184)
    stopBtn:SetScript("OnClick", ConfirmStopRun)

    local violationsPanel = CreatePanel(frame)
    frame.panels[TAB_VIOLATIONS] = violationsPanel
    frame.violations = { rows = {} }
    frame.violations.empty = CreateField(violationsPanel, 0, 0, 620)
    frame.violations.empty:SetText("(no active violations)")
    for index = 1, 12 do
        local row = CreateFrame("Frame", nil, violationsPanel)
        row:SetSize(672, 28)
        row:SetPoint("TOPLEFT", violationsPanel, "TOPLEFT", 0, -((index - 1) * 30))
        row.time = CreateField(row, 0, 0, 128)
        row.type = CreateField(row, 132, 0, 110)
        row.detail = CreateField(row, 246, 0, 340)
        row.clearBtn = CreateButton(row, "Clear", 62, 20)
        row.clearBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 2)
        frame.violations.rows[index] = row
    end

    local logPanel = CreatePanel(frame)
    frame.panels[TAB_LOG] = logPanel
    frame.log = {}
    frame.log.events = CreateFrame("ScrollingMessageFrame", nil, logPanel)
    frame.log.events:SetSize(672, 390)
    frame.log.events:SetPoint("TOPLEFT", logPanel, "TOPLEFT", 0, 0)
    frame.log.events:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    frame.log.events:SetMaxLines(500)
    frame.log.events:SetFading(false)
    frame.log.events:SetJustifyH("LEFT")
    frame.log.events:EnableMouseWheel(true)
    frame.log.events:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)

    local rulesPanel = CreatePanel(frame)
    frame.panels[TAB_RULES] = rulesPanel
    frame.rules = { rows = {} }
    for index = 1, 24 do
        frame.rules.rows[index] = CreateField(rulesPanel, 0, -((index - 1) * 17), 620)
    end

    local partyPanel = CreatePanel(frame)
    frame.panels[TAB_PARTY] = partyPanel
    frame.party = { rows = {} }
    frame.party.empty = CreateField(partyPanel, 0, 0, 620)
    frame.party.empty:SetText("(no synced party members)")
    for index = 1, 12 do
        frame.party.rows[index] = CreateField(partyPanel, 0, -((index - 1) * 24), 620)
    end

    local bottomClose = CreateButton(frame, "Close", 80, 24)
    bottomClose:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18)
    bottomClose:SetScript("OnClick", function() frame:Hide() end)

    self.masterFrame = frame
    self:MasterUI_Refresh()
end
