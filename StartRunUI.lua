-- Simple v0.3 Start New Run window.

local SC = Softcore

local DISALLOWED_OUTCOME = "WARNING"

local GROUPING_OPTIONS = {
    { text = "Group", value = "SYNCED_GROUP_ALLOWED" },
    { text = "Solo", value = "SOLO_SELF_FOUND" },
}

local GEAR_OPTIONS = {
    { text = "No restriction", value = "ALLOWED" },
    { text = "White/gray only", value = "WHITE_GRAY_ONLY" },
    { text = "Green or lower", value = "GREEN_OR_LOWER" },
    { text = "Blue or lower", value = "BLUE_OR_LOWER" },
    { text = "Epic or lower", value = "EPIC_OR_LOWER" },
}

local ECONOMY_RULES = {
    { label = "Disallow Auction House", key = "auctionHouse" },
    { label = "Disallow Mailbox", key = "mailbox" },
    { label = "Disallow Trade", key = "trade" },
    { label = "Disallow Bank", key = "bank" },
    { label = "Disallow Warband Bank", key = "warbandBank" },
    { label = "Disallow Guild Bank", key = "guildBank" },
}

local MOVEMENT_RULES = {
    { label = "Disallow mounts", key = "mounts" },
    { label = "Disallow flying", key = "flying" },
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

local function CreateDisallowCheckbox(parent, spec, x, y)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    checkbox.label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
    checkbox.label:SetWidth(260)
    checkbox.label:SetJustifyH("LEFT")
    checkbox.label:SetText(spec.label)
    checkbox:SetChecked(IsDisallowed(parent.selectedRules[spec.key]))
    checkbox:SetScript("OnClick", function(self)
        SetDisallowedRule(parent.selectedRules, spec.key, self:GetChecked())
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

local function GetRunName(frame)
    local runName = strtrim(frame.nameBox:GetText() or "")
    if runName == "" then
        runName = "Softcore Run"
        frame.nameBox:SetText(runName)
    end

    return runName
end

local function UpdateActiveRunState(frame)
    local db = SC.db or SoftcoreDB
    local active = db and db.run and db.run.active

    if active then
        frame.warning:SetText("A run is already active. This window will not overwrite it. Use /sc reset confirm first.")
        frame.proposeButton:Disable()
        frame.soloButton:Disable()
    else
        frame.warning:SetText("")
        frame.proposeButton:Enable()
        frame.soloButton:Enable()
    end
end

function SC:OpenStartRunWindow(prefillName)
    if self.startRunFrame then
        self.startRunFrame:Show()
        if prefillName and self.startRunFrame.nameBox then
            self.startRunFrame.nameBox:SetText(prefillName)
        end
        UpdateActiveRunState(self.startRunFrame)
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
    CreateLabel(frame, "Run name", "TOPLEFT", frame, "TOPLEFT", 18, -86)
    frame.nameBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.nameBox:SetSize(260, 24)
    frame.nameBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 88, -80)
    frame.nameBox:SetAutoFocus(false)
    frame.nameBox:SetText(prefillName or "Softcore Run")

    local casual = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    casual:SetSize(86, 22)
    casual:SetPoint("TOPLEFT", frame, "TOPLEFT", 380, -80)
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
    end, 90)
    frame.groupingDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 132, -182)
    local groupHelp = CreateLabel(frame, "Group: party members must be synced with matching Softcore rules.", "TOPLEFT", frame, "TOPLEFT", 18, -226, "GameFontHighlightSmall")
    groupHelp:SetWidth(330)
    groupHelp:SetJustifyH("LEFT")

    CreateSection(frame, "Economy / Storage Rules", 18, -270)
    local y = -298
    for _, spec in ipairs(ECONOMY_RULES) do
        CreateDisallowCheckbox(frame, spec, 18, y)
        y = y - 32
    end

    CreateSection(frame, "Movement Rules", 395, -126)
    y = -154
    for _, spec in ipairs(MOVEMENT_RULES) do
        CreateDisallowCheckbox(frame, spec, 395, y)
        y = y - 32
    end

    CreateSection(frame, "Gear / Item Rules", 395, -240)
    CreateLabel(frame, "Gear restriction", "TOPLEFT", frame, "TOPLEFT", 395, -268)
    frame.gearDropdown = CreateDropdown(frame, "SoftcoreRuleDropdownGearQuality", GEAR_OPTIONS, frame.selectedRules.gearQuality, function(value)
        frame.selectedRules.gearQuality = value
    end, 145)
    frame.gearDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 520, -260)
    CreateDisallowCheckbox(frame, { label = "Disallow heirlooms", key = "heirlooms" }, 395, -310)

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

    CreateDisallowCheckbox(frame, { label = "Disallow repeated dungeons", key = "dungeonRepeat" }, 395, -486)

    function frame:RefreshControls()
        if SC.ApplyGroupingMode then
            SC:ApplyGroupingMode(self.selectedRules)
        end
        self.selectedRules.instanceWithUnsyncedPlayers = "ALLOWED"
        self.selectedRules.unsyncedMembers = "ALLOWED"

        UIDropDownMenu_SetText(self.groupingDropdown, GetOptionText(GROUPING_OPTIONS, self.selectedRules.groupingMode))
        UIDropDownMenu_SetText(self.gearDropdown, GetOptionText(GEAR_OPTIONS, self.selectedRules.gearQuality))

        for key, checkbox in pairs(self.checkboxes) do
            checkbox:SetChecked(IsDisallowed(self.selectedRules[key]))
        end

        self.maxGapCheck:SetChecked(self.selectedRules.maxLevelGap ~= "ALLOWED")
        self.maxGapBox:SetText(tostring(self.selectedRules.maxLevelGapValue or 3))
    end

    frame.proposeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.proposeButton:SetSize(110, 24)
    frame.proposeButton:SetPoint("BOTTOMLEFT", 18, 18)
    frame.proposeButton:SetText("Propose Run")
    frame.proposeButton:SetScript("OnClick", function()
        UpdateActiveRunState(frame)
        if (SC.db or SoftcoreDB).run.active then
            return
        end

        if SC.ApplyGroupingMode then
            SC:ApplyGroupingMode(frame.selectedRules)
        end
        frame.selectedRules.instanceWithUnsyncedPlayers = "ALLOWED"
        frame.selectedRules.unsyncedMembers = "ALLOWED"

        local proposal = SC:CreateRunProposal(GetRunName(frame), frame.selectedRules, "RUN")
        if proposal then
            Print("proposed run: " .. proposal.runName)
            frame:Hide()
        end
    end)

    frame.soloButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.soloButton:SetSize(110, 24)
    frame.soloButton:SetPoint("LEFT", frame.proposeButton, "RIGHT", 8, 0)
    frame.soloButton:SetText("Start Solo Run")
    frame.soloButton:SetScript("OnClick", function()
        UpdateActiveRunState(frame)
        if (SC.db or SoftcoreDB).run.active then
            return
        end

        if SC.ApplyGroupingMode then
            SC:ApplyGroupingMode(frame.selectedRules)
        end
        frame.selectedRules.instanceWithUnsyncedPlayers = "ALLOWED"
        frame.selectedRules.unsyncedMembers = "ALLOWED"

        SC:StartRun({
            runName = GetRunName(frame),
            ruleset = frame.selectedRules,
        })
        frame:Hide()
    end)

    local cancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cancel:SetSize(80, 24)
    cancel:SetPoint("LEFT", frame.soloButton, "RIGHT", 8, 0)
    cancel:SetText("Cancel")
    cancel:SetScript("OnClick", function() frame:Hide() end)

    self.startRunFrame = frame
    frame:RefreshControls()
    UpdateActiveRunState(frame)
end
