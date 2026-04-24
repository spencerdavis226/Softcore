-- Event handlers for local-only MVP tracking.

local SC = Softcore

local eventFrame

local WARNING_EVENTS = {
    TRADE_SHOW = "Trade window opened.",
    MAIL_SHOW = "Mailbox opened.",
    AUCTION_HOUSE_SHOW = "Auction house opened.",
}

local function HandlePlayerDead()
    local db = SC.db or SoftcoreDB
    if not db or not db.run then
        return
    end

    -- The first death during an active run permanently fails that run.
    if db.run.active and not db.run.failed then
        db.run.deathCount = db.run.deathCount + 1
        db.run.active = false
        db.run.valid = false
        db.run.failed = true
        SC:LogEvent("DEATH", "Character died. Run failed permanently.")
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Softcore: run failed due to death.|r")
    end
end

local function HandleLevelUp(level)
    local db = SC.db or SoftcoreDB
    if not db then
        return
    end

    db.character.level = level or UnitLevel("player") or db.character.level
    SC:LogEvent("LEVEL_UP", "Reached level " .. tostring(db.character.level) .. ".")
end

local function HandleZoneChanged()
    local db = SC.db or SoftcoreDB
    if not db then
        return
    end

    db.character.zone = GetRealZoneText() or db.character.zone or "Unknown"
    SC:LogEvent("ZONE_CHANGED", "Entered " .. tostring(db.character.zone) .. ".")
end

local function HandleWarning(event)
    local db = SC.db or SoftcoreDB
    if not db or not db.run or not db.run.active or db.run.failed then
        return
    end

    db.run.warningCount = db.run.warningCount + 1
    SC:LogEvent("WARNING", WARNING_EVENTS[event] or (event .. " occurred."))
end

function SC:Events_Register()
    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_DEAD")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("TRADE_SHOW")
    eventFrame:RegisterEvent("MAIL_SHOW")
    eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_DEAD" then
            HandlePlayerDead()
        elseif event == "PLAYER_LEVEL_UP" then
            HandleLevelUp(...)
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            HandleZoneChanged()
        elseif WARNING_EVENTS[event] then
            HandleWarning(event)
        end

        if SC.UI_Update then
            SC:UI_Update()
        end
    end)
end
