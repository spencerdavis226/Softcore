-- Small movable status frame for the local run.

local SC = Softcore

local function SetLine(fontString, label, value)
    fontString:SetText(label .. ": " .. tostring(value))
end

local function ShortName(name)
    if not name then
        return "Unknown"
    end

    return string.match(name, "^[^-]+") or name
end

function SC:UI_Create()
    if self.uiFrame then
        self:UI_Update()
        return
    end

    local frame = CreateFrame("Frame", "SoftcoreStatusFrame", UIParent, "BackdropTemplate")
    frame:SetSize(260, 210)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
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
    frame:SetBackdropColor(0, 0, 0, 0.85)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 10, -10)
    frame.title:SetText("Softcore")

    frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.status:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -10)

    frame.level = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.level:SetPoint("TOPLEFT", frame.status, "BOTTOMLEFT", 0, -6)

    frame.deaths = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.deaths:SetPoint("TOPLEFT", frame.level, "BOTTOMLEFT", 0, -6)

    frame.warnings = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.warnings:SetPoint("TOPLEFT", frame.deaths, "BOTTOMLEFT", 0, -6)

    frame.groupTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.groupTitle:SetPoint("TOPLEFT", frame.warnings, "BOTTOMLEFT", 0, -14)
    frame.groupTitle:SetText("Group")

    frame.groupRows = {}
    for index = 1, 5 do
        local row = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row:SetPoint("TOPLEFT", frame.groupTitle, "BOTTOMLEFT", 0, -4 - ((index - 1) * 18))
        row:SetWidth(236)
        row:SetJustifyH("LEFT")
        row:SetText("")
        frame.groupRows[index] = row
    end

    self.uiFrame = frame
    self:UI_Update()
end

function SC:UI_Update()
    local db = self.db or SoftcoreDB
    if not self.uiFrame or not db or not db.run or not db.character then
        return
    end

    SetLine(self.uiFrame.status, "Status", self:GetStatusText())
    SetLine(self.uiFrame.level, "Level", db.character.level or "?")
    SetLine(self.uiFrame.deaths, "Deaths", db.run.deathCount or 0)
    SetLine(self.uiFrame.warnings, "Warnings", db.run.warningCount or 0)

    local rows = {}
    if self.Sync_GetGroupRows then
        rows = self:Sync_GetGroupRows()
    end

    for index = 1, #self.uiFrame.groupRows do
        local row = self.uiFrame.groupRows[index]
        local status = rows[index]

        if status then
            local displayStatus = "UNSYNCED"
            if self.Sync_GetDisplayStatus then
                displayStatus = self:Sync_GetDisplayStatus(status)
            end

            row:SetText(ShortName(status.name) .. " L" .. tostring(status.level or "?") .. " " .. displayStatus .. " W" .. tostring(status.warnings or 0))
        else
            row:SetText("-")
        end
    end
end
