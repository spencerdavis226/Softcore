-- Event handlers for local-only MVP tracking.

local SC = Softcore

local eventFrame

local WARNING_EVENTS = {
    TRADE_SHOW = "Trade window opened.",
    MAIL_SHOW = "Mailbox opened.",
    AUCTION_HOUSE_SHOW = "Auction house opened.",
}

local function Broadcast(reason)
    if SC.Sync_BroadcastStatus then
        SC:Sync_BroadcastStatus(reason)
    end
end

local function HandlePlayerDead()
    local db = SC.db or SoftcoreDB
    if not db or not db.run then
        return
    end

    -- The first death during an active run permanently fails this character only.
    local playerKey = SC:GetPlayerKey()
    local participant = SC:GetOrCreateParticipant(playerKey)
    if db.run.active and participant.status ~= "FAILED" then
        db.run.deathCount = db.run.deathCount + 1
        SC:MarkParticipantFailed(playerKey, "Character died.")
        SC:AddLog("DEATH", "Character died. Run failed permanently.")
        SC:AddViolation("PLAYER_DEAD", "Character died. Character failed permanently.", "FATAL", playerKey)
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Softcore: character failed due to death.|r")
        Broadcast("PLAYER_DEAD")
    end
end

local function HandleLevelUp(level)
    local db = SC.db or SoftcoreDB
    if not db then
        return
    end

    db.character.level = level or UnitLevel("player") or db.character.level
    SC:GetOrCreateParticipant(SC:GetPlayerKey()).currentLevel = db.character.level
    SC:AddLog("LEVEL_UP", "Reached level " .. tostring(db.character.level) .. ".")
    Broadcast("PLAYER_LEVEL_UP")
end

local function HandleZoneChanged()
    local db = SC.db or SoftcoreDB
    if not db then
        return
    end

    db.character.zone = GetRealZoneText() or db.character.zone or "Unknown"
    SC:AddLog("ZONE_CHANGED", "Entered " .. tostring(db.character.zone) .. ".")
end

local function HandleWarning(event)
    local db = SC.db or SoftcoreDB
    if not db or not db.run or not db.run.active or db.run.failed then
        return
    end

    db.run.warningCount = db.run.warningCount + 1
    local participant = SC:GetOrCreateParticipant(SC:GetPlayerKey())
    if participant.status == "ACTIVE" then
        participant.status = "WARNING"
    end
    SC:AddLog("WARNING", WARNING_EVENTS[event] or (event .. " occurred."))
    SC:AddViolation(event, WARNING_EVENTS[event] or (event .. " occurred."), "WARNING", participant.playerKey)
    Broadcast(event)
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
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_DEAD" then
            HandlePlayerDead()
        elseif event == "PLAYER_LEVEL_UP" then
            HandleLevelUp(...)
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            HandleZoneChanged()
        elseif WARNING_EVENTS[event] then
            HandleWarning(event)
        elseif event == "GROUP_ROSTER_UPDATE" then
            SC:AddLog("GROUP_ROSTER", "Group roster changed.")
            Broadcast("GROUP_ROSTER_UPDATE")
            if C_Timer and C_Timer.After then
                C_Timer.After(2, function()
                    Broadcast("GROUP_ROSTER_UPDATE")
                end)
            end
            if SC.Sync_MarkRoster then
                SC:Sync_MarkRoster()
            end
            if SC.RefreshParticipantsFromRoster then
                SC:RefreshParticipantsFromRoster()
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            Broadcast("PLAYER_ENTERING_WORLD")
        end

        if SC.UI_Update then
            SC:UI_Update()
        end
    end)
end
