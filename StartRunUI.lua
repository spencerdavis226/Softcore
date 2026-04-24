-- Simple v0.3 Start New Run window.

local SC = Softcore

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
    { label = "Allow flying (mounts & Druid flight form)", key = "flying" },
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4ade80Softcore:|r " .. tostring(message))
end

local function GetOptionText(options, value)
    for _, option in ipairs(options) do
        if option.value == value then
            return option.text
        end
    end

    return tostring(value or "")
end

local function CreateLabel(parent, text, point, relativeTo, relativePoint, x, y, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
    label:SetPoint(point, relativeTo, relativePoint, x, y)
    label:SetText(text)
    return label
end

local function CreateSection(parent, title, x, y)
    return CreateLabel(parent, title, "TOPLEFT", parent, "TOPLEFT", x, y, "GameFontNormal")
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
    dropdown.options = options
    return dropdown
end

local function IsDisallowed(value)
    return value ~= nil and value ~= "ALLOWED" and value ~= "LOG_ONLY"
end

local function SetDisallowedRule(rules, key, checked)
    rules[key] = checked and DISALLOWED_OUTCOME or "ALLOWED"
end

local function CreateAllowCheckbox(parent, spec, x, y)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    checkbox.label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
    checkbox.label:SetWidth(260)
    checkbox.label:SetJustifyH("LEFT")
    checkbox.label:SetText(spec.label)
    checkbox:SetChecked(not IsDisallowed(parent.selectedRules[spec.key]))
    checkbox:SetScript("OnClick", function(self)
        SetDisallowedRule(parent.selectedRules, spec.key, not self:GetChecked())
    end)
    parent.checkboxes[spec.key] = checkbox
    return checkbox
end

local function ApplyPreset(frame, preset)
    local rules = frame.selectedRules

    rules.groupingMode = preset == "IRONMAN" and "SOLO_SELF_FOUND" or "SYNCED_GROUP_ALLOWED"
    rules.gearQuality = preset == "IRONMAN" and "WHITE_GRAY_ONLY" or "ALLOWED"
    rules.maxLevelGap = preset == "IRONMAN" and DISALLOWED_OUTCOME or "ALLOWED"
    rules.maxLevelGapValue = 3
    rules.heirlooms = DISALLOWED_OUTCOME
    rules.dungeonRepeat = preset == "IRONMAN" and DISALLOWED_OUTCOME or "ALLOWED"
    rules.instanceWithUnsyncedPlayers = "ALLOWED"
    rules.unsyncedMembers = "ALLOWED"

    for _, spec in ipairs(ECONOMY_RULES) do
        SetDisallowedRule(rules, spec.key, preset == "IRONMAN" or spec.key == "auctionHouse" or spec.key == "mailbox" or spec.key == "trade" or spec.key == "bank" or spec.key == "warbandBank" or spec.key == "guildBank")
    end

    for _, spec in ipairs(MOVEMENT_RULES) do
        SetDisallowedRule(rules, spec.key, preset == "IRONMAN")
    end

    if SC.ApplyGroupingMode then
        SC:ApplyGroupingMode(rules)
    end

    if frame.RefreshControls then
        frame:RefreshControls()
    end
end

local function UpdatePrimaryButton(frame)
    local db = SC.db or SoftcoreDB
    local active = db and db.run and db.run.active

    if active then
        frame.warning:SetText("A run is already active. Use /sc reset confirm first.")
        frame.primaryButton:Disable()
        return
    end

    frame.warning:SetText("")

    local pendingId = db and db.pendingProposalId
    local pendingProposal = pendingId and db.proposals and db.proposals[pendingId]
    if pendingProposal and (pendingProposal.status == "PENDING" or pendingProposal.status == "ACCEPTED") then
        frame.primaryButton:SetText("Proposal Pending")
        frame.primaryButton:Disable()
        return
    end

    frame.primaryButton:Enable()

    if IsInGroup() then
        frame.primaryButton:SetText("Propose Run")
        local hasUnsynced = false
        local groupRows = SC.Sync_GetGroupRows and SC:Sync_GetGroupRows() or {}
        for _, peer in ipairs(groupRows) do
            if peer.unsynced then
                hasUnsynced = true
                break
            end
        end
        if hasUnsynced then
            frame.warning:SetText("Some group members are not running Softcore. They must sync or leave before the run can start.")
        end
    else
        frame.primaryButton:SetText("Start Run")
    end
end

function SC:OpenStartRunWindow()
    if self.startRunFrame then
        self.startRunFrame:Show()
        UpdatePrimaryButton(self.startRunFrame)
        return
    end

    local frame = CreateFrame("Frame", "SoftcoreStartRunFrame", UIParent, "BackdropTemplate")
    frame:SetSize(760, 760)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.92)

    frame.selectedRules = self:GetDefaultRuleset()
    frame.selectedRules.dungeonRepeat = "ALLOWED"
    frame.selectedRules.instanceWithUnsyncedPlayers = "ALLOWED"
    frame.selectedRules.unsyncedMembers = "ALLOWED"
    if self.ApplyGroupingMode then
        self:ApplyGroupingMode(frame.selectedRules)
    end
    frame.dropdowns = {}
    frame.checkboxes = {}

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText("Softcore: Start New Run")

    frame.warning = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.warning:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    frame.warning:SetWidth(700)
    frame.warning:SetJustifyH("LEFT")
    frame.warning:SetText("")

    CreateSection(frame, "Run Setup", 18, -58)

    local casual = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    casual:SetSize(86, 22)
    casual:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -80)
    casual:SetText("Casual")
    casual:SetScript("OnClick", function() ApplyPreset(frame, "CASUAL") end)

    local ironman = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    ironman:SetSize(86, 22)
    ironman:SetPoint("LEFT", casual, "RIGHT", 8, 0)
    ironman:SetText("Ironman")
    ironman:SetScript("OnClick", function() ApplyPreset(frame, "IRONMAN") end)

    CreateSection(frame, "Core Rules", 18, -126)
    local deathText = CreateLabel(frame, "Death is permanent for each character.", "TOPLEFT", frame, "TOPLEFT", 18, -154, "GameFontHighlightSmall")
    deathText:SetWidth(330)
    deathText:SetJustifyH("LEFT")
    CreateLabel(frame, "Grouping Mode", "TOPLEFT", frame, "TOPLEFT", 18, -190)
    frame.groupingDropdown = CreateDropdown(frame, "SoftcoreRuleDropdownGroupingMode", GROUPING_OPTIONS, frame.selectedRules.groupingMode, function(value)
        frame.selectedRules.groupingMode = value
        if SC.ApplyGroupingMode then
            SC:ApplyGroupingMode(frame.selectedRules)
        end
        frame.groupHelp:SetShown(value ~= "SOLO_SELF_FOUND")
    end, 140)
    frame.groupingDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 132, -182)
    frame.groupHelp = CreateLabel(frame, "Party members must be synced with matching Softcore rules.", "TOPLEFT", frame, "TOPLEFT", 18, -226, "GameFontHighlightSmall")
    frame.groupHelp:SetWidth(330)
    frame.groupHelp:SetJustifyH("LEFT")
    frame.groupHelp:SetShown(frame.selectedRules.groupingMode ~= "SOLO_SELF_FOUND")

    CreateSection(frame, "Economy / Storage Rules", 18, -270)
    local y = -298
    for _, spec in ipairs(ECONOMY_RULES) do
        CreateAllowCheckbox(frame, spec, 18, y)
        y = y - 32
    end

    CreateSection(frame, "Movement Rules", 395, -126)
    y = -154
    for _, spec in ipairs(MOVEMENT_RULES) do
        CreateAllowCheckbox(frame, spec, 395, y)
        y = y - 32
    end

    CreateSection(frame, "Gear / Item Rules", 395, -240)
    CreateLabel(frame, "Gear limit", "TOPLEFT", frame, "TOPLEFT", 395, -268)
    frame.gearDropdown = CreateDropdown(frame, "SoftcoreRuleDropdownGearQuality", GEAR_OPTIONS, frame.selectedRules.gearQuality, function(value)
        frame.selectedRules.gearQuality = value
    end, 145)
    frame.gearDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 520, -260)
    CreateAllowCheckbox(frame, { label = "Allow heirlooms", key = "heirlooms" }, 395, -310)

    CreateSection(frame, "Group / Dungeon Rules", 395, -382)
    frame.maxGapCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.maxGapCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 395, -410)
    frame.maxGapCheck.label = frame.maxGapCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.maxGapCheck.label:SetPoint("LEFT", frame.maxGapCheck, "RIGHT", 2, 0)
    frame.maxGapCheck.label:SetText("Enforce max level gap")
    frame.maxGapCheck:SetChecked(frame.selectedRules.maxLevelGap ~= "ALLOWED")
    frame.maxGapCheck:SetScript("OnClick", function(self)
        frame.selectedRules.maxLevelGap = self:GetChecked() and DISALLOWED_OUTCOME or "ALLOWED"
        frame:RefreshControls()
    end)

    CreateLabel(frame, "Max gap", "TOPLEFT", frame, "TOPLEFT", 426, -448)
    frame.maxGapBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.maxGapBox:SetSize(42, 22)
    frame.maxGapBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 492, -442)
    frame.maxGapBox:SetAutoFocus(false)
    frame.maxGapBox:SetNumeric(true)
    frame.maxGapBox:SetText(tostring(frame.selectedRules.maxLevelGapValue or 3))
    frame.maxGapBox:SetScript("OnTextChanged", function(self)
        local value = tonumber(self:GetText())
        if value then
            frame.selectedRules.maxLevelGapValue = value
        end
    end)

    CreateAllowCheckbox(frame, { label = "Allow repeated dungeons", key = "dungeonRepeat" }, 395, -486)

    function frame:RefreshControls()
        if SC.ApplyGroupingMode then
            SC:ApplyGroupingMode(self.selectedRules)
        end
        self.selectedRules.instanceWithUnsyncedPlayers = "ALLOWED"
        self.selectedRules.unsyncedMembers = "ALLOWED"

        UIDropDownMenu_SetText(self.groupingDropdown, GetOptionText(GROUPING_OPTIONS, self.selectedRules.groupingMode))
        UIDropDownMenu_SetText(self.gearDropdown, GetOptionText(GEAR_OPTIONS, self.selectedRules.gearQuality))
        self.groupHelp:SetShown(self.selectedRules.groupingMode ~= "SOLO_SELF_FOUND")

        for key, checkbox in pairs(self.checkboxes) do
            checkbox:SetChecked(not IsDisallowed(self.selectedRules[key]))
        end

        self.maxGapCheck:SetChecked(self.selectedRules.maxLevelGap ~= "ALLOWED")
        self.maxGapBox:SetText(tostring(self.selectedRules.maxLevelGapValue or 3))

        UpdatePrimaryButton(self)
    end

    frame.primaryButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.primaryButton:SetSize(120, 24)
    frame.primaryButton:SetPoint("BOTTOMLEFT", 18, 18)
    frame.primaryButton:SetText("Start Run")
    frame.primaryButton:SetScript("OnClick", function()
        UpdatePrimaryButton(frame)
        local db = SC.db or SoftcoreDB
        if db.run.active then return end

        if SC.ApplyGroupingMode then
            SC:ApplyGroupingMode(frame.selectedRules)
        end
        frame.selectedRules.instanceWithUnsyncedPlayers = "ALLOWED"
        frame.selectedRules.unsyncedMembers = "ALLOWED"

        local runName = "Softcore Run"

        if IsInGroup() then
            local proposal = SC:CreateRunProposal(runName, frame.selectedRules, "RUN")
            if proposal then
                Print("proposed run: " .. proposal.runName)
                UpdatePrimaryButton(frame)
            end
        else
            SC:StartRun({
                runName = runName,
                ruleset = frame.selectedRules,
            })
            frame:Hide()
        end
    end)

    local cancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cancel:SetSize(80, 24)
    cancel:SetPoint("LEFT", frame.primaryButton, "RIGHT", 8, 0)
    cancel:SetText("Cancel")
    cancel:SetScript("OnClick", function() frame:Hide() end)

    self.startRunFrame = frame
    frame:RefreshControls()
    UpdatePrimaryButton(frame)
end
