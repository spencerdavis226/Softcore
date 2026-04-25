-- Master menu for the main Softcore UI.

local SC = Softcore

local TAB_START = "START"
local TAB_STATUS = "STATUS"
local TAB_VIOLATIONS = "VIOLATIONS"
local TAB_LOG = "LOG"
local TAB_RULES = "RULES"
local TAB_PARTY = "PARTY"

local DISALLOWED_OUTCOME = "WARNING"

local GROUPING_OPTIONS = {
    { text = "Grouping Allowed", value = "SYNCED_GROUP_ALLOWED" },
    { text = "Solo Only", value = "SOLO_SELF_FOUND" },
}

local GEAR_OPTIONS = {
    { text = "Any gear", value = "ALLOWED" },
    { text = "White/gray only", value = "WHITE_GRAY_ONLY" },
    { text = "Green or lower", value = "GREEN_OR_LOWER" },
    { text = "Blue or lower", value = "BLUE_OR_LOWER" },
}

local ECONOMY_RULES = {
    { label = "Allow Auction House", key = "auctionHouse" },
    { label = "Allow Mailbox", key = "mailbox" },
    { label = "Allow Trade", key = "trade" },
    { label = "Allow Bank", key = "bank" },
    { label = "Allow Warband Bank", key = "warbandBank" },
    { label = "Allow Guild Bank", key = "guildBank" },
}

local MOVEMENT_RULES = {
    { label = "Allow mounts", key = "mounts" },
    { label = "Allow flying", key = "flying" },
}

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

local function CreateLabel(parent, text, x, y, template, width)
    local fs = CreateField(parent, x, y, width or 220)
    fs:SetFontObject(_G[template or "GameFontNormalSmall"])
    fs:SetText(text)
    return fs
end

local function GetOptionText(options, value)
    for _, option in ipairs(options) do
        if option.value == value then
            return option.text
        end
    end

    return tostring(value or "")
end

local function CreateDropdown(parent, name, options, selectedValue, onSelect, width)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, width or 145)
    UIDropDownMenu_SetText(dropdown, GetOptionText(options, selectedValue))
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        for _, option in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.func = function()
                UIDropDownMenu_SetText(dropdown, option.text)
                onSelect(option.value)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    return dropdown
end

local function IsDisallowed(value)
    return value ~= nil and value ~= "ALLOWED" and value ~= "LOG_ONLY"
end

local function SetDisallowedRule(rules, key, checked)
    rules[key] = checked and "ALLOWED" or DISALLOWED_OUTCOME
end

local function CreateAllowCheckbox(parent, rules, spec, x, y)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    checkbox.label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
    checkbox.label:SetWidth(230)
    checkbox.label:SetJustifyH("LEFT")
    checkbox.label:SetText(spec.label)
    checkbox:SetChecked(not IsDisallowed(rules[spec.key]))
    checkbox:SetScript("OnClick", function(self)
        SetDisallowedRule(rules, spec.key, self:GetChecked())
    end)
    return checkbox
end

local function ApplyStartPreset(frame, preset)
    local rules = frame.start.selectedRules

    rules.groupingMode = preset == "IRONMAN" and "SOLO_SELF_FOUND" or "SYNCED_GROUP_ALLOWED"
    rules.gearQuality = preset == "IRONMAN" and "WHITE_GRAY_ONLY" or "ALLOWED"
    rules.maxLevelGap = preset == "IRONMAN" and DISALLOWED_OUTCOME or "ALLOWED"
    rules.maxLevelGapValue = 3
    rules.heirlooms = DISALLOWED_OUTCOME
    rules.dungeonRepeat = preset == "IRONMAN" and DISALLOWED_OUTCOME or "ALLOWED"
    rules.instanceWithUnsyncedPlayers = "ALLOWED"
    rules.unsyncedMembers = "ALLOWED"

    for _, spec in ipairs(ECONOMY_RULES) do
        SetDisallowedRule(rules, spec.key, not (preset == "IRONMAN" or spec.key == "auctionHouse" or spec.key == "mailbox" or spec.key == "trade" or spec.key == "bank" or spec.key == "warbandBank" or spec.key == "guildBank"))
    end

    for _, spec in ipairs(MOVEMENT_RULES) do
        SetDisallowedRule(rules, spec.key, preset ~= "IRONMAN")
    end

    if SC.ApplyGroupingMode then
        SC:ApplyGroupingMode(rules)
    end

    if frame.start.RefreshControls then
        frame.start:RefreshControls()
    end
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
    frame.start.casualBtn:SetShown(not active)
    frame.start.ironmanBtn:SetShown(not active)
    frame.start.primaryBtn:SetShown(not active)
    frame.start.groupingDropdown:SetShown(not active)
    frame.start.gearDropdown:SetShown(not active)
    frame.start.maxGapBox:SetShown(not active)

    for _, control in ipairs(frame.start.controls) do
        control:SetShown(not active)
    end

    if frame.start.RefreshControls then
        frame.start:RefreshControls()
    end
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

    for index = #log, 1, -1 do
        local entry = log[index]
        frame.log.events:AddMessage(string.format(
            "|cffaaaaaa%s|r |cffffcc00[%s]|r %s",
            FormatTime(entry.time),
            tostring(entry.kind or "?"),
            tostring(entry.message or "")
        ))
    end

    frame.log.events:ScrollToTop()
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
    local syncRows = SC.Sync_GetGroupRows and SC:Sync_GetGroupRows() or {}
    local participantOrder = db and db.run and db.run.participantOrder or {}
    local participants = db and db.run and db.run.participants or {}
    local localKey = SC:GetPlayerKey()
    local displayRows = {}

    for _, peer in ipairs(syncRows) do
        table.insert(displayRows, {
            name = peer.name or peer.playerKey or "Unknown",
            status = tostring(SC.Sync_GetDisplayStatus and SC:Sync_GetDisplayStatus(peer) or peer.participantStatus or "UNKNOWN"),
        })
    end

    for _, participantKey in ipairs(participantOrder) do
        if participantKey ~= localKey then
            local participant = participants[participantKey]
            if participant then
                table.insert(displayRows, {
                    name = participant.playerKey,
                    status = tostring(participant.status or "UNKNOWN"),
                })
            end
        end
    end

    frame.party.empty:SetShown(#displayRows == 0)

    for index, row in ipairs(frame.party.rows) do
        local display = displayRows[index]

        if display then
            row:Show()
            row.name:SetText(Trunc(display.name, 38))
            row.status:SetText(display.status)
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
    frame.start = { controls = {}, selectedRules = SC:GetDefaultRuleset() }
    frame.start.selectedRules.dungeonRepeat = "ALLOWED"
    frame.start.selectedRules.instanceWithUnsyncedPlayers = "ALLOWED"
    frame.start.selectedRules.unsyncedMembers = "ALLOWED"
    frame.start.inactiveText = CreateField(startPanel, 0, 0, 620)
    frame.start.inactiveText:SetText("No active Softcore run.")
    frame.start.activeText = CreateField(startPanel, 0, 0, 620)
    frame.start.activeText:SetText("A run is already active. Use the Status tab to review or stop it.")

    frame.start.casualBtn = CreateButton(startPanel, "Casual", 86, 22)
    frame.start.casualBtn:SetPoint("TOPLEFT", startPanel, "TOPLEFT", 0, -32)
    frame.start.casualBtn:SetScript("OnClick", function()
        ApplyStartPreset(frame, "CASUAL")
    end)

    frame.start.ironmanBtn = CreateButton(startPanel, "Ironman", 86, 22)
    frame.start.ironmanBtn:SetPoint("LEFT", frame.start.casualBtn, "RIGHT", 8, 0)
    frame.start.ironmanBtn:SetScript("OnClick", function()
        ApplyStartPreset(frame, "IRONMAN")
    end)

    table.insert(frame.start.controls, CreateLabel(startPanel, "Core", 0, -72, "GameFontNormal"))
    table.insert(frame.start.controls, CreateLabel(startPanel, "Death is permanent for each character.", 0, -98, "GameFontHighlightSmall", 300))
    table.insert(frame.start.controls, CreateLabel(startPanel, "Grouping", 0, -128, "GameFontNormalSmall", 80))
    frame.start.groupingDropdown = CreateDropdown(startPanel, "SoftcoreMasterGroupingDropdown", GROUPING_OPTIONS, frame.start.selectedRules.groupingMode, function(value)
        frame.start.selectedRules.groupingMode = value
        if SC.ApplyGroupingMode then
            SC:ApplyGroupingMode(frame.start.selectedRules)
        end
    end, 140)
    frame.start.groupingDropdown:SetPoint("TOPLEFT", startPanel, "TOPLEFT", 92, -120)

    table.insert(frame.start.controls, CreateLabel(startPanel, "Economy / Storage", 0, -168, "GameFontNormal"))
    local y = -194
    for _, spec in ipairs(ECONOMY_RULES) do
        local checkbox = CreateAllowCheckbox(startPanel, frame.start.selectedRules, spec, 0, y)
        table.insert(frame.start.controls, checkbox)
        y = y - 30
    end

    table.insert(frame.start.controls, CreateLabel(startPanel, "Movement", 350, -72, "GameFontNormal"))
    y = -98
    for _, spec in ipairs(MOVEMENT_RULES) do
        local checkbox = CreateAllowCheckbox(startPanel, frame.start.selectedRules, spec, 350, y)
        table.insert(frame.start.controls, checkbox)
        y = y - 30
    end

    table.insert(frame.start.controls, CreateLabel(startPanel, "Gear / Items", 350, -168, "GameFontNormal"))
    table.insert(frame.start.controls, CreateLabel(startPanel, "Gear limit", 350, -196, "GameFontNormalSmall", 80))
    frame.start.gearDropdown = CreateDropdown(startPanel, "SoftcoreMasterGearDropdown", GEAR_OPTIONS, frame.start.selectedRules.gearQuality, function(value)
        frame.start.selectedRules.gearQuality = value
    end, 145)
    frame.start.gearDropdown:SetPoint("TOPLEFT", startPanel, "TOPLEFT", 452, -188)
    frame.start.heirloomCheck = CreateAllowCheckbox(startPanel, frame.start.selectedRules, { label = "Allow heirlooms", key = "heirlooms" }, 350, -232)
    table.insert(frame.start.controls, frame.start.heirloomCheck)

    table.insert(frame.start.controls, CreateLabel(startPanel, "Group / Dungeon", 350, -278, "GameFontNormal"))
    frame.start.maxGapCheck = CreateFrame("CheckButton", nil, startPanel, "UICheckButtonTemplate")
    frame.start.maxGapCheck:SetPoint("TOPLEFT", startPanel, "TOPLEFT", 350, -304)
    frame.start.maxGapCheck.label = frame.start.maxGapCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.start.maxGapCheck.label:SetPoint("LEFT", frame.start.maxGapCheck, "RIGHT", 2, 0)
    frame.start.maxGapCheck.label:SetText("Enforce max level gap")
    frame.start.maxGapCheck:SetScript("OnClick", function(self)
        frame.start.selectedRules.maxLevelGap = self:GetChecked() and DISALLOWED_OUTCOME or "ALLOWED"
    end)
    table.insert(frame.start.controls, frame.start.maxGapCheck)
    table.insert(frame.start.controls, CreateLabel(startPanel, "Max gap", 378, -340, "GameFontNormalSmall", 70))
    frame.start.maxGapBox = CreateFrame("EditBox", nil, startPanel, "InputBoxTemplate")
    frame.start.maxGapBox:SetSize(42, 22)
    frame.start.maxGapBox:SetPoint("TOPLEFT", startPanel, "TOPLEFT", 450, -334)
    frame.start.maxGapBox:SetAutoFocus(false)
    frame.start.maxGapBox:SetNumeric(true)
    frame.start.maxGapBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value then
            frame.start.selectedRules.maxLevelGapValue = value
        end
    end)
    frame.start.dungeonRepeatCheck = CreateAllowCheckbox(startPanel, frame.start.selectedRules, { label = "Allow repeated dungeons", key = "dungeonRepeat" }, 350, -370)
    table.insert(frame.start.controls, frame.start.dungeonRepeatCheck)

    function frame.start:RefreshControls()
        if SC.ApplyGroupingMode then
            SC:ApplyGroupingMode(self.selectedRules)
        end
        self.selectedRules.instanceWithUnsyncedPlayers = "ALLOWED"
        self.selectedRules.unsyncedMembers = "ALLOWED"

        UIDropDownMenu_SetText(self.groupingDropdown, GetOptionText(GROUPING_OPTIONS, self.selectedRules.groupingMode))
        UIDropDownMenu_SetText(self.gearDropdown, GetOptionText(GEAR_OPTIONS, self.selectedRules.gearQuality))
        self.maxGapCheck:SetChecked(self.selectedRules.maxLevelGap ~= "ALLOWED")
        self.maxGapBox:SetText(tostring(self.selectedRules.maxLevelGapValue or 3))

        for _, checkbox in ipairs(self.controls) do
            if checkbox.label and checkbox.GetChecked and checkbox ~= self.maxGapCheck then
                local text = checkbox.label:GetText()
                for _, spec in ipairs(ECONOMY_RULES) do
                    if text == spec.label then checkbox:SetChecked(not IsDisallowed(self.selectedRules[spec.key])) end
                end
                for _, spec in ipairs(MOVEMENT_RULES) do
                    if text == spec.label then checkbox:SetChecked(not IsDisallowed(self.selectedRules[spec.key])) end
                end
            end
        end
        self.heirloomCheck:SetChecked(not IsDisallowed(self.selectedRules.heirlooms))
        self.dungeonRepeatCheck:SetChecked(not IsDisallowed(self.selectedRules.dungeonRepeat))
    end

    frame.start.primaryBtn = CreateButton(startPanel, "Start Run", 120, 24)
    frame.start.primaryBtn:SetPoint("BOTTOMLEFT", startPanel, "BOTTOMLEFT", 0, 0)
    frame.start.primaryBtn:SetScript("OnClick", function()
        local ruleset = SC:CopyTable(frame.start.selectedRules)
        if SC.ApplyGroupingMode then
            SC:ApplyGroupingMode(ruleset)
        end
        ruleset.instanceWithUnsyncedPlayers = "ALLOWED"
        ruleset.unsyncedMembers = "ALLOWED"
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
    ApplyStartPreset(frame, "CASUAL")

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
        local row = CreateFrame("Frame", nil, partyPanel)
        row:SetSize(620, 22)
        row:SetPoint("TOPLEFT", partyPanel, "TOPLEFT", 0, -24 - ((index - 1) * 24))
        row.name = CreateField(row, 0, 0, 360)
        row.status = CreateField(row, 380, 0, 180)
        frame.party.rows[index] = row
    end

    local bottomClose = CreateButton(frame, "Close", 80, 24)
    bottomClose:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18)
    bottomClose:SetScript("OnClick", function() frame:Hide() end)

    self.masterFrame = frame
    self:MasterUI_Refresh()
end
