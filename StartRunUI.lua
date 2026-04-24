-- Simple v0.3 Start New Run window.

local SC = Softcore

local SEVERITY_OPTIONS = {
    { text = "Allowed", value = "ALLOWED" },
    { text = "Log only", value = "LOG_ONLY" },
    { text = "Warning", value = "WARNING" },
    { text = "Fatal", value = "FATAL" },
}

local GEAR_OPTIONS = {
    { text = "No restriction", value = "ALLOWED" },
    { text = "White/gray only", value = "WHITE_GRAY_ONLY" },
    { text = "Up to green", value = "COMMON_OR_UNCOMMON" },
    { text = "No epics", value = "NO_EPICS" },
}

local GROUPING_OPTIONS = {
    { text = "Group allowed with synced Softcore players", value = "SYNCED_GROUP_ALLOWED" },
    { text = "Solo / self-found only", value = "SOLO_SELF_FOUND" },
}

local SECTION_ROWS = {
    economy = {
        { label = "Auction House", key = "auctionHouse", options = SEVERITY_OPTIONS },
        { label = "Mailbox", key = "mailbox", options = SEVERITY_OPTIONS },
        { label = "Trade", key = "trade", options = SEVERITY_OPTIONS },
        { label = "Bank", key = "bank", options = SEVERITY_OPTIONS },
        { label = "Warband Bank", key = "warbandBank", options = SEVERITY_OPTIONS },
        { label = "Guild Bank", key = "guildBank", options = SEVERITY_OPTIONS },
    },
    movement = {
        { label = "Mounts", key = "mounts", options = SEVERITY_OPTIONS },
        { label = "Flying", key = "flying", options = SEVERITY_OPTIONS },
    },
    gear = {
        { label = "Gear restriction", key = "gearQuality", options = GEAR_OPTIONS },
        { label = "Heirlooms", key = "heirlooms", options = SEVERITY_OPTIONS },
    },
    group = {
        { label = "Unsynced group member", key = "unsyncedMembers", options = SEVERITY_OPTIONS },
        { label = "Dungeon Repeat", key = "dungeonRepeat", options = SEVERITY_OPTIONS },
        { label = "Unsynced in Instance", key = "instanceWithUnsyncedPlayers", options = SEVERITY_OPTIONS },
    },
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
    local header = CreateLabel(parent, title, "TOPLEFT", parent, "TOPLEFT", x, y, "GameFontNormal")
    return header
end

local function CreateDropdown(parent, name, options, selectedValue, onSelect)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, 145)
    UIDropDownMenu_SetText(dropdown, GetOptionText(options, selectedValue))
    UIDropDownMenu_Initialize(dropdown, function(self, level)
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

local function CreateRuleDropdown(parent, spec, x, y)
    CreateLabel(parent, spec.label, "TOPLEFT", parent, "TOPLEFT", x, y)
    local dropdown = CreateDropdown(parent, "SoftcoreRuleDropdown" .. spec.key, spec.options, parent.selectedRules[spec.key], function(value)
        parent.selectedRules[spec.key] = value
    end)
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 140, y + 8)
    parent.dropdowns[spec.key] = dropdown
    return dropdown
end

local function ApplyPreset(frame, preset)
    local rules = frame.selectedRules

    if preset == "CASUAL" then
        rules.auctionHouse = "WARNING"
        rules.groupingMode = "SYNCED_GROUP_ALLOWED"
        rules.mailbox = "WARNING"
        rules.trade = "WARNING"
        rules.bank = "WARNING"
        rules.warbandBank = "WARNING"
        rules.guildBank = "WARNING"
        rules.mounts = "ALLOWED"
        rules.flying = "ALLOWED"
        rules.gearQuality = "ALLOWED"
        rules.heirlooms = "WARNING"
        rules.maxLevelGap = "ALLOWED"
        rules.maxLevelGapValue = 3
        rules.dungeonRepeat = "LOG_ONLY"
        rules.unsyncedMembers = "WARNING"
        rules.instanceWithUnsyncedPlayers = "WARNING"
    elseif preset == "IRONMAN" then
        rules.auctionHouse = "FATAL"
        rules.groupingMode = "SOLO_SELF_FOUND"
        rules.mailbox = "FATAL"
        rules.trade = "WARNING"
        rules.bank = "FATAL"
        rules.warbandBank = "FATAL"
        rules.guildBank = "FATAL"
        rules.mounts = "WARNING"
        rules.flying = "WARNING"
        rules.gearQuality = "WHITE_GRAY_ONLY"
        rules.heirlooms = "FATAL"
        rules.maxLevelGap = "WARNING"
        rules.maxLevelGapValue = 3
        rules.dungeonRepeat = "WARNING"
        rules.unsyncedMembers = "WARNING"
        rules.instanceWithUnsyncedPlayers = "WARNING"
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
    local db = self.db or SoftcoreDB

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
    if self.ApplyGroupingMode then
        self:ApplyGroupingMode(frame.selectedRules)
    end
    frame.maxGapBehavior = frame.selectedRules.maxLevelGap == "ALLOWED" and "WARNING" or frame.selectedRules.maxLevelGap
    frame.dropdowns = {}

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
    deathText:SetWidth(320)
    deathText:SetJustifyH("LEFT")
    CreateLabel(frame, "Grouping Mode", "TOPLEFT", frame, "TOPLEFT", 18, -190)
    frame.groupingDropdown = CreateDropdown(frame, "SoftcoreRuleDropdownGroupingMode", GROUPING_OPTIONS, frame.selectedRules.groupingMode, function(value)
        frame.selectedRules.groupingMode = value
        if SC.ApplyGroupingMode then
            SC:ApplyGroupingMode(frame.selectedRules)
        end
    end)
    UIDropDownMenu_SetWidth(frame.groupingDropdown, 230)
    frame.groupingDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 132, -182)

    CreateSection(frame, "Economy / Storage Rules", 18, -270)
    local y = -298
    for _, spec in ipairs(SECTION_ROWS.economy) do
        CreateRuleDropdown(frame, spec, 18, y)
        y = y - 42
    end

    CreateSection(frame, "Movement Rules", 395, -126)
    y = -154
    for _, spec in ipairs(SECTION_ROWS.movement) do
        CreateRuleDropdown(frame, spec, 395, y)
        y = y - 42
    end

    CreateSection(frame, "Gear / Item Rules", 395, -240)
    y = -268
    for _, spec in ipairs(SECTION_ROWS.gear) do
        CreateRuleDropdown(frame, spec, 395, y)
        y = y - 42
    end

    CreateSection(frame, "Group / Dungeon Rules", 395, -382)
    frame.maxGapCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.maxGapCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 395, -410)
    frame.maxGapCheck.label = frame.maxGapCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.maxGapCheck.label:SetPoint("LEFT", frame.maxGapCheck, "RIGHT", 2, 0)
    frame.maxGapCheck.label:SetText("Enforce max level gap")
    frame.maxGapCheck:SetChecked(frame.selectedRules.maxLevelGap ~= "ALLOWED")
    frame.maxGapCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            frame.selectedRules.maxLevelGap = frame.maxGapBehavior or "WARNING"
        else
            frame.selectedRules.maxLevelGap = "ALLOWED"
        end
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

    CreateLabel(frame, "Violation behavior", "TOPLEFT", frame, "TOPLEFT", 395, -486)
    frame.maxGapDropdown = CreateDropdown(frame, "SoftcoreRuleDropdownMaxLevelGap", SEVERITY_OPTIONS, frame.selectedRules.maxLevelGap == "ALLOWED" and "WARNING" or frame.selectedRules.maxLevelGap, function(value)
        frame.maxGapBehavior = value
        if frame.maxGapCheck:GetChecked() then
            frame.selectedRules.maxLevelGap = value
        end
    end)
    frame.maxGapDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 520, -478)

    y = -532
    for _, spec in ipairs(SECTION_ROWS.group) do
        CreateRuleDropdown(frame, spec, 395, y)
        y = y - 42
    end

    function frame:RefreshControls()
        if SC.ApplyGroupingMode then
            SC:ApplyGroupingMode(self.selectedRules)
        end

        UIDropDownMenu_SetText(self.groupingDropdown, GetOptionText(GROUPING_OPTIONS, self.selectedRules.groupingMode))

        for key, dropdown in pairs(self.dropdowns) do
            UIDropDownMenu_SetText(dropdown, GetOptionText(dropdown.options, self.selectedRules[key]))
        end

        self.maxGapCheck:SetChecked(self.selectedRules.maxLevelGap ~= "ALLOWED")
        self.maxGapBox:SetText(tostring(self.selectedRules.maxLevelGapValue or 3))
        if self.selectedRules.maxLevelGap ~= "ALLOWED" then
            self.maxGapBehavior = self.selectedRules.maxLevelGap
        end
        UIDropDownMenu_SetText(self.maxGapDropdown, GetOptionText(SEVERITY_OPTIONS, self.maxGapBehavior or "WARNING"))
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
