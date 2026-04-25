-- Master menu for the main Softcore UI.

local SC = Softcore

local TAB_RUN = "RUN"
local TAB_OVERVIEW = "OVERVIEW"
local TAB_VIOLATIONS = "VIOLATIONS"
local TAB_LOG = "LOG"

local DISALLOWED_OUTCOME = "WARNING"
local LOG_ROWS = 22

local GROUPING_OPTIONS = {
    { text = "Grouping Allowed", value = "SYNCED_GROUP_ALLOWED" },
    { text = "Solo Only", value = "SOLO_SELF_FOUND" },
}

local GEAR_OPTIONS = {
    { text = "Any gear", value = "ALLOWED" },
    { text = "White/grey only", value = "WHITE_GRAY_ONLY" },
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
    { label = "Allow flying (not flight paths)", key = "flying" },
}

local EDITABLE_RULE_ORDER = {
    "groupingMode",
    "auctionHouse",
    "mailbox",
    "trade",
    "bank",
    "warbandBank",
    "guildBank",
    "mounts",
    "flying",
    "gearQuality",
    "heirlooms",
    "maxLevelGap",
    "maxLevelGapValue",
    "dungeonRepeat",
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r " .. tostring(message))
end

local function FormatTime(timestamp)
    if not timestamp then return "never" end
    return date("%Y-%m-%d %H:%M:%S", timestamp)
end

local function FormatElapsed(startTime)
    if not startTime then return "" end
    local elapsed = time() - startTime
    if elapsed < 0 then elapsed = 0 end
    local h = math.floor(elapsed / 3600)
    local m = math.floor((elapsed % 3600) / 60)
    if h > 0 then
        return string.format("%dh %02dm", h, m)
    end
    return string.format("%dm", m)
end

local function Trunc(str, maxLen)
    str = tostring(str or "")
    if #str <= maxLen then return str end
    return string.sub(str, 1, maxLen - 2) .. ".."
end

local function FormatPlayerLabel(playerKey)
    if SC.FormatPlayerLabel then
        return SC:FormatPlayerLabel(playerKey)
    end

    local name = string.match(tostring(playerKey or "Unknown"), "^([^-]+)")
    return name or tostring(playerKey or "Unknown")
end

local function SetLine(fontString, label, value)
    fontString:SetText(label .. ": " .. tostring(value))
end

local function IsActiveRun()
    local db = SC.db or SoftcoreDB
    return db and db.run and db.run.active
end

local function GetDefaultTab()
    return IsActiveRun() and TAB_OVERVIEW or TAB_RUN
end

local function NormalizeTab(tab)
    if tab == "START" or tab == "RULES" then
        return TAB_RUN
    end

    if tab == "STATUS" or tab == "PARTY" then
        return TAB_OVERVIEW
    end

    if tab == TAB_LOG or tab == TAB_RUN or tab == TAB_OVERVIEW or tab == TAB_VIOLATIONS then
        return tab
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

local STATUS_COLORS = {
    VALID   = "|cff4ade80",
    ACTIVE  = "|cff4ade80",
    FAILED  = "|cffff4444",
    BLOCKED = "|cfffbbf24",
    CONFLICT = "|cfffbbf24",
    VIOLATION = "|cfffbbf24",
    UNSYNCED = "|cff9ca3af",
    INACTIVE = "|cff9ca3af",
    NOT_IN_RUN = "|cff9ca3af",
}
local COLOR_RESET = "|r"

local function ColorStatus(statusStr)
    if not statusStr then return "" end
    local base = string.match(statusStr, "^(%u+)")
    local color = base and STATUS_COLORS[base]
    if color then
        return color .. statusStr .. COLOR_RESET
    end
    return statusStr
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
        if SC.MasterUI_Refresh then
            SC:MasterUI_Refresh()
        end
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

local function CopyRulesInto(target, source)
    for key in pairs(target) do
        target[key] = nil
    end

    for key, value in pairs(source or {}) do
        target[key] = value
    end
end

local function BuildRuleChanges(previousRules, nextRules)
    local changes = {}

    for _, ruleName in ipairs(EDITABLE_RULE_ORDER) do
        local previousValue = previousRules and previousRules[ruleName]
        local nextValue = nextRules and nextRules[ruleName]

        if tostring(previousValue) ~= tostring(nextValue) then
            changes[ruleName] = nextValue
        end
    end

    return changes
end

local function CountRuleChanges(changes)
    local count = 0

    for _ in pairs(changes or {}) do
        count = count + 1
    end

    return count
end

local function FormatRuleChangeSummary(previousRules, changes)
    if CountRuleChanges(changes) == 0 then
        return "No rule changes selected."
    end

    local parts = {}
    for _, ruleName in ipairs(EDITABLE_RULE_ORDER) do
        if changes[ruleName] ~= nil then
            table.insert(parts, ruleName .. ": " .. tostring(previousRules[ruleName]) .. " -> " .. tostring(changes[ruleName]))
        end
    end

    return Trunc(table.concat(parts, "  |  "), 118)
end

local RULE_DISPLAY_NAMES = {
    groupingMode   = "Grouping Mode",
    auctionHouse   = "Auction House",
    mailbox        = "Mailbox",
    trade          = "Trade",
    bank           = "Bank",
    warbandBank    = "Warband Bank",
    guildBank      = "Guild Bank",
    mounts         = "Mounts",
    flying         = "Flying (not flight paths)",
    gearQuality    = "Gear Limit",
    heirlooms      = "Heirlooms",
    maxLevelGap    = "Level Gap Enforcement",
    maxLevelGapValue = "Max Level Gap",
    dungeonRepeat  = "Repeated Dungeons",
}

local function FriendlyRuleValue(ruleName, value)
    if value == nil then return "|cff9ca3af?|r" end
    if ruleName == "groupingMode" then
        if value == "SYNCED_GROUP_ALLOWED" then return "grouping" end
        if value == "SOLO_SELF_FOUND" then return "solo only" end
    end
    if ruleName == "gearQuality" then
        return GetOptionText(GEAR_OPTIONS, value)
    end
    if ruleName == "maxLevelGapValue" then
        return tostring(value)
    end
    if value == "ALLOWED" or value == "LOG_ONLY" then return "allowed" end
    return "disallowed"
end

local function GetPendingAmendment()
    local db = SC.db or SoftcoreDB
    for _, amendment in ipairs(db and db.ruleAmendments or {}) do
        if amendment.status == "PENDING" then
            return amendment
        end
    end
    return nil
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

local function GetPartyDisplayRows()
    local db = SC.db or SoftcoreDB
    local syncRows = SC.Sync_GetGroupRows and SC:Sync_GetGroupRows() or {}
    local participantOrder = db and db.run and db.run.participantOrder or {}
    local participants = db and db.run and db.run.participants or {}
    local localKey = SC:GetPlayerKey()
    local displayRows = {}

    local localStatus = SC:GetPlayerStatus()
    local localName = db and db.character and db.character.name or FormatPlayerLabel(localKey)
    table.insert(displayRows, {
        name = (localName or "You") .. " *",
        level = db and db.character and db.character.level,
        status = localStatus.participantStatus or "NOT_IN_RUN",
    })

    for _, peer in ipairs(syncRows) do
        local displayStatus = tostring(SC.Sync_GetDisplayStatus and SC:Sync_GetDisplayStatus(peer) or peer.participantStatus or "UNKNOWN")
        if (peer.activeViolations or 0) > 0 then
            local violationType = peer.latestViolation and peer.latestViolation.type
            if violationType and violationType ~= "" then
                displayStatus = "VIOLATION (" .. tostring(violationType) .. ")"
            else
                displayStatus = "VIOLATION"
            end
        end

        table.insert(displayRows, {
            name = peer.name or peer.playerKey or "Unknown",
            level = peer.level,
            status = displayStatus,
        })
    end

    for _, participantKey in ipairs(participantOrder) do
        if participantKey ~= localKey then
            local participant = participants[participantKey]
            if participant then
                table.insert(displayRows, {
                    name = participant.playerKey,
                    level = participant.currentLevel,
                    status = tostring(participant.status or "UNKNOWN"),
                })
            end
        end
    end

    return displayRows
end

local function RefreshOverviewPanel(frame)
    local db = SC.db or SoftcoreDB
    local run = db and db.run or {}
    local active = run.active
    local status = SC:GetPlayerStatus()
    local partyRows = GetPartyDisplayRows()
    local activeViolations = #GetSortedActiveViolations()

    frame.overview.noRunText:SetShown(not active)
    frame.overview.goToRunBtn:SetShown(not active)

    frame.overview.run:SetShown(active)
    frame.overview.localStatus:SetShown(active)
    frame.overview.partyStatus:SetShown(active)
    frame.overview.elapsed:SetShown(active)
    frame.overview.deaths:SetShown(active)
    frame.overview.violations:SetShown(active)
    frame.overview.runId:SetShown(active)

    if active then
        SetLine(frame.overview.run, "Run", run.runName or "Softcore Run")
        frame.overview.localStatus:SetText("You: " .. ColorStatus(status.participantStatus or "NOT_IN_RUN"))
        frame.overview.partyStatus:SetText("Party: " .. ColorStatus(status.partyStatus or "INACTIVE"))
        frame.overview.elapsed:SetText("Time: " .. FormatElapsed(run.startTime) .. "  |cff6b7280(since " .. FormatTime(run.startTime) .. ")|r")
        SetLine(frame.overview.deaths, "Deaths", run.deathCount or 0)

        local violationColor = activeViolations > 0 and "|cfffbbf24" or ""
        local violationReset = activeViolations > 0 and "|r" or ""
        frame.overview.violations:SetText("Active violations: " .. violationColor .. activeViolations .. violationReset)

        SetLine(frame.overview.runId, "Run ID", run.runId or "none")
    end

    frame.overview.partyEmpty:SetShown(false)

    for index, row in ipairs(frame.overview.partyRows) do
        local display = partyRows[index]
        if display then
            row:Show()
            row.name:SetText(Trunc(display.name, 24))
            row.level:SetText(display.level and tostring(display.level) or "")
            row.status:SetText(ColorStatus(display.status))
        else
            row:Hide()
        end
    end
end

local function SetRunSetupEnabled(frame, enabled)
    local start = frame.start

    start.casualBtn:SetEnabled(enabled)
    start.ironmanBtn:SetEnabled(enabled)

    for _, control in ipairs(start.controls) do
        if control.Enable and control.Disable then
            if enabled then control:Enable() else control:Disable() end
        end
    end

    if UIDropDownMenu_EnableDropDown and UIDropDownMenu_DisableDropDown then
        if enabled then
            UIDropDownMenu_EnableDropDown(start.groupingDropdown)
            UIDropDownMenu_EnableDropDown(start.gearDropdown)
        else
            UIDropDownMenu_DisableDropDown(start.groupingDropdown)
            UIDropDownMenu_DisableDropDown(start.gearDropdown)
        end
    end

    if enabled then
        start.maxGapBox:Enable()
    else
        start.maxGapBox:Disable()
    end
end

local function RefreshAmendmentPanel(frame, amendment, isProposer)
    local panel = frame.start.amendmentPanel
    local localShortName = string.match(tostring(amendment.proposedBy or "?"), "^([^-]+)")

    if isProposer then
        panel.title:SetText("|cfffbbf24Pending rule amendment|r — waiting for party")
        panel.proposer:SetText("You proposed this amendment.")
    else
        panel.title:SetText("|cfffbbf24Pending rule amendment|r")
        panel.proposer:SetText("Proposed by: " .. (localShortName or "?"))
    end
    panel.reason:SetText("Reason: " .. Trunc(amendment.reason or "", 90))

    local changeCount = 0
    for _, ruleName in ipairs(EDITABLE_RULE_ORDER) do
        if amendment.newRules[ruleName] ~= nil then
            changeCount = changeCount + 1
            if changeCount <= 8 then
                local oldVal = amendment.previousRules[ruleName]
                local newVal = amendment.newRules[ruleName]
                local label = RULE_DISPLAY_NAMES[ruleName] or ruleName
                panel.changeLines[changeCount]:SetText(
                    "• " .. label .. ": " .. FriendlyRuleValue(ruleName, oldVal) .. " → " .. FriendlyRuleValue(ruleName, newVal)
                )
            end
        end
    end
    for i = changeCount + 1, 8 do
        panel.changeLines[i]:SetText("")
    end

    local contentH = 72 + (math.max(1, changeCount) * 16) + 42
    panel:SetHeight(contentH)

    panel.acceptBtn:SetShown(not isProposer)
    panel.declineBtn:SetShown(not isProposer)
    panel.cancelBtn:SetShown(isProposer)
    panel.waitText:SetShown(isProposer)

    if not isProposer then
        panel.acceptBtn:SetScript("OnClick", function()
            if SC.AcceptRuleAmendment then SC:AcceptRuleAmendment(amendment.id) end
            SC:MasterUI_Refresh()
        end)
        panel.declineBtn:SetScript("OnClick", function()
            if SC.DeclineRuleAmendment then SC:DeclineRuleAmendment(amendment.id) end
            SC:MasterUI_Refresh()
        end)
    else
        panel.cancelBtn:SetScript("OnClick", function()
            local db = SC.db or SoftcoreDB
            for _, a in ipairs(db and db.ruleAmendments or {}) do
                if a.id == amendment.id and a.status == "PENDING" then
                    a.status = "DECLINED"
                    a.declinedAt = time()
                    a.declinedBy = SC:GetPlayerKey()
                    if SC.Sync_SendAmendmentCancelled then SC:Sync_SendAmendmentCancelled(a) end
                    break
                end
            end
            frame.start.isModifyingRules = false
            frame.start.draftBaseRules = nil
            SC:MasterUI_Refresh()
        end)
    end
end

local function HideAllRunControls(frame)
    frame.start.inactiveText:Hide()
    frame.start.activeText:Hide()
    frame.start.casualBtn:Hide()
    frame.start.ironmanBtn:Hide()
    for _, control in ipairs(frame.start.controls) do control:Hide() end
    frame.start.groupingDropdown:Hide()
    frame.start.gearDropdown:Hide()
    frame.start.maxGapBox:Hide()
    frame.start.primaryBtn:Hide()
    frame.start.stopBtn:Hide()
    frame.start.modifyBtn:Hide()
    frame.start.applyChangesBtn:Hide()
    frame.start.cancelChangesBtn:Hide()
    frame.start.changeSummary:Hide()
end

local function RefreshRunPanel(frame)
    local active = IsActiveRun()
    local db = SC.db or SoftcoreDB
    local modifying = active and frame.start.isModifyingRules

    -- Amendment panel takes over the whole tab when one is pending
    local pendingAmendment = GetPendingAmendment()
    if pendingAmendment and frame.start.amendmentPanel then
        HideAllRunControls(frame)
        local localKey = SC:GetPlayerKey()
        frame.start.amendmentPanel:Show()
        RefreshAmendmentPanel(frame, pendingAmendment, pendingAmendment.proposedBy == localKey)
        return
    end
    if frame.start.amendmentPanel then
        frame.start.amendmentPanel:Hide()
    end

    frame.start.inactiveText:SetShown(not active)
    frame.start.activeText:SetShown(active)

    if active and db and db.run and db.run.ruleset and not modifying then
        CopyRulesInto(frame.start.selectedRules, db.run.ruleset)
    elseif not frame.start.selectedRules then
        frame.start.selectedRules = SC:GetDefaultRuleset()
    end

    frame.start.groupingDropdown:SetShown(true)
    frame.start.gearDropdown:SetShown(true)
    frame.start.maxGapBox:SetShown(true)
    frame.start.casualBtn:SetShown(not active)
    frame.start.ironmanBtn:SetShown(not active)
    for _, control in ipairs(frame.start.controls) do
        control:SetShown(true)
    end
    frame.start.primaryBtn:SetShown(not active)
    frame.start.stopBtn:SetShown(active and not modifying)
    frame.start.modifyBtn:SetShown(active and not modifying)
    frame.start.applyChangesBtn:SetShown(modifying)
    frame.start.cancelChangesBtn:SetShown(modifying)
    frame.start.changeSummary:SetShown(modifying)
    SetRunSetupEnabled(frame, (not active) or modifying)

    if active then
        if modifying then
            if IsInGroup() then
                frame.start.applyChangesBtn:SetText("Propose to Party")
                frame.start.activeText:SetText("Draft rule amendment — will be sent to all party members for approval.")
            else
                frame.start.applyChangesBtn:SetText("Apply Changes")
                frame.start.activeText:SetText("Draft rule amendment. Changes apply going forward and will be logged.")
            end
        else
            frame.start.activeText:SetText("Active run rules are locked. Use Modify Rules to draft a logged amendment.")
        end
    end

    if frame.start.RefreshControls then
        frame.start:RefreshControls()
    end

    if modifying then
        local changes = BuildRuleChanges(frame.start.draftBaseRules or {}, frame.start.selectedRules or {})
        frame.start.changeSummary:SetText(FormatRuleChangeSummary(frame.start.draftBaseRules or {}, changes))
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
            row.owner:SetText(Trunc(FormatPlayerLabel(violation.playerKey), 14))
            row.detail:SetText(Trunc(violation.detail or "", 44))
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

    if #log == 0 then
        frame.log.empty:Show()
        for _, row in ipairs(frame.log.rows) do
            row:Hide()
        end
        return
    end

    frame.log.empty:Hide()

    for rowIndex, row in ipairs(frame.log.rows) do
        local entry = log[#log - rowIndex + 1]

        if entry then
            row:Show()
            row.time:SetText(FormatTime(entry.time))
            row.actor:SetText(Trunc(FormatPlayerLabel(entry.actorKey or entry.playerKey), 14))
            row.kind:SetText("[" .. tostring(entry.kind or "?") .. "]")
            row.message:SetText(Trunc(entry.message or "", 58))
        else
            row:Hide()
        end
    end
end

local function ConfirmStopRun()
    if not StaticPopupDialogs or not StaticPopup_Show then
        SC:ResetRun()
        if SC.masterFrame then
            SC.masterFrame.activeTab = TAB_RUN
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
                SC.masterFrame.activeTab = TAB_RUN
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

    for tabName, panel in pairs(frame.panels) do
        panel:SetShown(tabName == frame.activeTab)
    end

    frame.overviewTab:SetEnabled(frame.activeTab ~= TAB_OVERVIEW)
    frame.runTab:SetEnabled(frame.activeTab ~= TAB_RUN)
    frame.violationsTab:SetEnabled(frame.activeTab ~= TAB_VIOLATIONS)
    frame.logTab:SetEnabled(frame.activeTab ~= TAB_LOG)

    RefreshOverviewPanel(frame)
    RefreshRunPanel(frame)
    RefreshViolationsPanel(frame)
    RefreshLogPanel(frame)

    if SC.HUD_Refresh then
        SC:HUD_Refresh()
    end
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

    local overviewTab = AddTab("overviewTab", "Overview", TAB_OVERVIEW)
    local runTab = AddTab("runTab", "Run", TAB_RUN, overviewTab)
    local violationsTab = AddTab("violationsTab", "Violations", TAB_VIOLATIONS, runTab)
    local logTab = AddTab("logTab", "Log", TAB_LOG, violationsTab)

    local startPanel = CreatePanel(frame)
    frame.panels[TAB_RUN] = startPanel
    frame.start = { controls = {}, selectedRules = SC:GetDefaultRuleset() }
    frame.start.selectedRules.dungeonRepeat = "ALLOWED"
    frame.start.selectedRules.instanceWithUnsyncedPlayers = "ALLOWED"
    frame.start.selectedRules.unsyncedMembers = "ALLOWED"
    frame.start.inactiveText = CreateField(startPanel, 0, 0, 620)
    frame.start.inactiveText:SetText("No active Softcore run.")
    frame.start.activeText = CreateField(startPanel, 0, 0, 620)
    frame.start.activeText:SetText("Active run rules are locked. Future rule changes will use a visible amendment flow.")

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
        SC:MasterUI_Refresh()
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
        SC:MasterUI_Refresh()
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
        SC:MasterUI_Refresh()
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
    frame.start.maxGapBox:SetScript("OnEditFocusLost", function()
        SC:MasterUI_Refresh()
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
        local isSolo = self.selectedRules.groupingMode == "SOLO_SELF_FOUND"
        if isSolo then
            self.selectedRules.maxLevelGap = "ALLOWED"
        end
        self.maxGapCheck:SetChecked(not isSolo and self.selectedRules.maxLevelGap ~= "ALLOWED")
        self.maxGapCheck:SetEnabled(not isSolo)
        self.maxGapCheck.label:SetFontObject(isSolo and GameFontDisableSmall or GameFontNormalSmall)
        if isSolo then self.maxGapBox:Disable() end
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
            frame.activeTab = TAB_OVERVIEW
        end
        SC:MasterUI_Refresh()
    end)
    ApplyStartPreset(frame, "CASUAL")
    frame.start.stopBtn = CreateButton(startPanel, "Stop Run", 100, 24)
    frame.start.stopBtn:SetPoint("LEFT", frame.start.primaryBtn, "RIGHT", 8, 0)
    frame.start.stopBtn:SetScript("OnClick", ConfirmStopRun)
    frame.start.modifyBtn = CreateButton(startPanel, "Modify Rules", 110, 24)
    frame.start.modifyBtn:SetPoint("LEFT", frame.start.stopBtn, "RIGHT", 8, 0)
    frame.start.modifyBtn:SetScript("OnClick", function()
        local db = SC.db or SoftcoreDB
        if not db or not db.run or not db.run.ruleset then return end

        frame.start.isModifyingRules = true
        frame.start.draftBaseRules = SC:CopyTable(db.run.ruleset)
        CopyRulesInto(frame.start.selectedRules, db.run.ruleset)
        SC:MasterUI_Refresh()
    end)
    frame.start.applyChangesBtn = CreateButton(startPanel, "Apply Changes", 120, 24)
    frame.start.applyChangesBtn:SetPoint("LEFT", frame.start.primaryBtn, "RIGHT", 8, 0)
    frame.start.applyChangesBtn:SetScript("OnClick", function()
        local changes = BuildRuleChanges(frame.start.draftBaseRules or {}, frame.start.selectedRules or {})
        if CountRuleChanges(changes) == 0 then
            Print("no rule changes selected.")
            return
        end

        if IsInGroup() then
            if SC.ProposeRuleAmendment then
                SC:ProposeRuleAmendment(changes, "Run rules modified from the Run tab.")
                frame.start.isModifyingRules = false
                frame.start.draftBaseRules = nil
                Print("rule amendment proposed to party.")
            else
                Print("rule amendment handling is not loaded.")
            end
        else
            if SC.ProposeRuleAmendment and SC.AcceptRuleAmendment and SC.ApplyRuleAmendment then
                local amendment = SC:ProposeRuleAmendment(changes, "Run rules modified from the Run tab.")
                SC:AcceptRuleAmendment(amendment.id)
                SC:ApplyRuleAmendment(amendment.id)
                frame.start.isModifyingRules = false
                frame.start.draftBaseRules = nil
                Print("rule changes applied.")
            else
                Print("rule amendment handling is not loaded.")
            end
        end

        SC:MasterUI_Refresh()
    end)
    frame.start.cancelChangesBtn = CreateButton(startPanel, "Cancel", 80, 24)
    frame.start.cancelChangesBtn:SetPoint("LEFT", frame.start.applyChangesBtn, "RIGHT", 8, 0)
    frame.start.cancelChangesBtn:SetScript("OnClick", function()
        frame.start.isModifyingRules = false
        frame.start.draftBaseRules = nil
        SC:MasterUI_Refresh()
    end)
    frame.start.changeSummary = CreateField(startPanel, 0, -404, 640)

    -- Amendment proposal overlay (replaces rule controls when a pending amendment exists)
    local amendPanel = CreateFrame("Frame", nil, startPanel, "BackdropTemplate")
    amendPanel:SetSize(640, 200)
    amendPanel:SetPoint("TOPLEFT", startPanel, "TOPLEFT", 0, 0)
    amendPanel:EnableMouse(true)
    amendPanel:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    amendPanel:SetBackdropColor(0.05, 0.05, 0, 0.95)
    amendPanel:Hide()

    amendPanel.title   = CreateField(amendPanel, 10, -10, 620)
    amendPanel.title:SetFontObject(GameFontNormal)
    amendPanel.proposer = CreateField(amendPanel, 10, -30, 620)
    amendPanel.reason   = CreateField(amendPanel, 10, -48, 620)
    amendPanel.changeLines = {}
    for i = 1, 8 do
        amendPanel.changeLines[i] = CreateField(amendPanel, 10, -64 - (i - 1) * 16, 620)
    end
    amendPanel.acceptBtn  = CreateButton(amendPanel, "Accept",          90, 24)
    amendPanel.declineBtn = CreateButton(amendPanel, "Decline",         90, 24)
    amendPanel.cancelBtn  = CreateButton(amendPanel, "Cancel Proposal", 120, 24)
    amendPanel.acceptBtn:SetPoint("BOTTOMLEFT",  amendPanel, "BOTTOMLEFT", 10, 10)
    amendPanel.declineBtn:SetPoint("LEFT", amendPanel.acceptBtn, "RIGHT", 8, 0)
    amendPanel.cancelBtn:SetPoint("BOTTOMLEFT",  amendPanel, "BOTTOMLEFT", 10, 10)
    amendPanel.waitText = CreateField(amendPanel, 10, -999, 620)
    amendPanel.waitText:SetPoint("BOTTOMLEFT", amendPanel, "BOTTOMLEFT", 10, 42)
    amendPanel.waitText:SetText("|cfffbbf24Waiting for party members to accept...|r")

    frame.start.amendmentPanel = amendPanel

    local overviewPanel = CreatePanel(frame)
    frame.panels[TAB_OVERVIEW] = overviewPanel
    frame.overview = {
        noRunText = CreateField(overviewPanel, 0, 0, 500),
        run = CreateField(overviewPanel, 0, 0),
        localStatus = CreateField(overviewPanel, 0, -24),
        partyStatus = CreateField(overviewPanel, 0, -48),
        elapsed = CreateField(overviewPanel, 0, -72),
        deaths = CreateField(overviewPanel, 0, -96),
        violations = CreateField(overviewPanel, 0, -120),
        runId = CreateField(overviewPanel, 0, -144),
        partyRows = {},
    }
    frame.overview.noRunText:SetText("No active Softcore run.")
    frame.overview.goToRunBtn = CreateButton(overviewPanel, "Start a Run", 110, 24)
    frame.overview.goToRunBtn:SetPoint("TOPLEFT", overviewPanel, "TOPLEFT", 0, -28)
    frame.overview.goToRunBtn:SetScript("OnClick", function()
        frame.activeTab = TAB_RUN
        SC:MasterUI_Refresh()
    end)
    CreateLabel(overviewPanel, "Party", 0, -188, "GameFontNormal", 200)
    frame.overview.resyncBtn = CreateButton(overviewPanel, "Resync", 72, 20)
    frame.overview.resyncBtn:SetPoint("TOPLEFT", overviewPanel, "TOPLEFT", 210, -185)
    frame.overview.resyncBtn:SetScript("OnClick", function()
        if SC.Sync_BroadcastStatus then
            SC:Sync_BroadcastStatus("RESYNC")
            Print("resync requested.")
        end
    end)
    CreateLabel(overviewPanel, "Name", 0, -210, "GameFontNormalSmall", 200)
    CreateLabel(overviewPanel, "Lvl", 260, -210, "GameFontNormalSmall", 40)
    CreateLabel(overviewPanel, "Status", 310, -210, "GameFontNormalSmall", 280)
    frame.overview.partyEmpty = CreateField(overviewPanel, 0, -232, 620)
    frame.overview.partyEmpty:SetText("(no synced party members)")
    for index = 1, 8 do
        local row = CreateFrame("Frame", nil, overviewPanel)
        row:SetSize(620, 22)
        row:SetPoint("TOPLEFT", overviewPanel, "TOPLEFT", 0, -256 - ((index - 1) * 24))
        row.name = CreateField(row, 0, 0, 256)
        row.level = CreateField(row, 260, 0, 40)
        row.status = CreateField(row, 310, 0, 280)
        frame.overview.partyRows[index] = row
    end

    local violationsPanel = CreatePanel(frame)
    frame.panels[TAB_VIOLATIONS] = violationsPanel
    frame.violations = { rows = {} }
    CreateLabel(violationsPanel, "Time", 0, 0, "GameFontNormalSmall", 118)
    CreateLabel(violationsPanel, "Owner", 122, 0, "GameFontNormalSmall", 90)
    CreateLabel(violationsPanel, "Type", 216, 0, "GameFontNormalSmall", 108)
    CreateLabel(violationsPanel, "Detail", 328, 0, "GameFontNormalSmall", 260)
    frame.violations.empty = CreateField(violationsPanel, 0, -26, 620)
    frame.violations.empty:SetText("(no active violations)")
    for index = 1, 12 do
        local row = CreateFrame("Frame", nil, violationsPanel)
        row:SetSize(672, 28)
        row:SetPoint("TOPLEFT", violationsPanel, "TOPLEFT", 0, -26 - ((index - 1) * 30))
        row.time = CreateField(row, 0, 0, 118)
        row.owner = CreateField(row, 122, 0, 90)
        row.type = CreateField(row, 216, 0, 108)
        row.detail = CreateField(row, 328, 0, 260)
        row.clearBtn = CreateButton(row, "Clear", 62, 20)
        row.clearBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 2)
        frame.violations.rows[index] = row
    end

    local logPanel = CreatePanel(frame)
    frame.panels[TAB_LOG] = logPanel
    frame.log = { rows = {} }
    CreateLabel(logPanel, "Time", 0, 0, "GameFontNormalSmall", 130)
    CreateLabel(logPanel, "Actor", 134, 0, "GameFontNormalSmall", 90)
    CreateLabel(logPanel, "Type", 228, 0, "GameFontNormalSmall", 128)
    CreateLabel(logPanel, "Message", 360, 0, "GameFontNormalSmall", 300)
    frame.log.empty = CreateField(logPanel, 0, -24, 620)
    frame.log.empty:SetText("(no events recorded)")
    for index = 1, LOG_ROWS do
        local row = CreateFrame("Frame", nil, logPanel)
        row:SetSize(672, 18)
        row:SetPoint("TOPLEFT", logPanel, "TOPLEFT", 0, -24 - ((index - 1) * 18))
        row.time = CreateField(row, 0, 0, 130)
        row.actor = CreateField(row, 134, 0, 90)
        row.kind = CreateField(row, 228, 0, 128)
        row.message = CreateField(row, 360, 0, 300)
        frame.log.rows[index] = row
    end

    local bottomClose = CreateButton(frame, "Close", 80, 24)
    bottomClose:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18)
    bottomClose:SetScript("OnClick", function() frame:Hide() end)

    self.masterFrame = frame
    self:MasterUI_Refresh()
end
