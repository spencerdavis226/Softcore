-- Event handlers for local-only MVP tracking.

local SC = Softcore

local eventFrame

local WARNING_EVENTS = {
    TRADE_SHOW = { rule = "trade", detail = "Trade window opened." },
    MAIL_SHOW = { rule = "mailbox", detail = "Mailbox opened." },
    AUCTION_HOUSE_SHOW = { rule = "auctionHouse", detail = "Auction house opened." },
}

local ACCESS_EVENTS = {
    BANKFRAME_OPENED = { rule = "bank", detail = "Player bank opened." },
    GUILDBANKFRAME_OPENED = { rule = "guildBank", detail = "Guild bank opened." },
    VOID_STORAGE_OPEN = { rule = "voidStorage", detail = "Void storage opened." },
    CRAFTINGORDERS_SHOW_CUSTOMER = { rule = "craftingOrders", detail = "Crafting orders opened." },
    MERCHANT_SHOW = { rule = "vendor", detail = "Vendor opened." },
}

local movementState = {
    mounted = false,
    flying = false,
    mountWarnedAt = 0,
    flyingWarnedAt = 0,
}

local MOVEMENT_WARNING_THROTTLE = 30
local ACCESS_WARNING_THROTTLE = 30
local accessWarnedAt = {}

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
        SC:AddLog("DEATH", "Character died. Run failed permanently.")
        SC:ApplyRuleOutcome("death", {
            playerKey = playerKey,
            detail = "Character died. Character failed permanently.",
        })
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

    local warning = WARNING_EVENTS[event]
    SC:ApplyRuleOutcome(warning.rule, {
        playerKey = SC:GetPlayerKey(),
        detail = warning.detail,
    })
    Broadcast(event)
end

local function ApplyAccessRule(ruleName, detail)
    local db = SC.db or SoftcoreDB
    if not db or not db.run or not db.run.active or db.run.failed then
        return
    end

    local now = time()
    if now - (accessWarnedAt[ruleName] or 0) < ACCESS_WARNING_THROTTLE then
        return
    end

    accessWarnedAt[ruleName] = now
    SC:ApplyRuleOutcome(ruleName, {
        playerKey = SC:GetPlayerKey(),
        detail = detail,
    })
    Broadcast(ruleName)
end

local function HandleAccessEvent(event)
    local access = ACCESS_EVENTS[event]
    if access then
        ApplyAccessRule(access.rule, access.detail)
    end
end

local function IsWarbandBankAccessEvent(event, ...)
    local bankType = ...

    -- In-game verification note: Warband bank access is account-bank based in The War Within.
    -- ACCOUNT_BANK_PANEL_OPENED appears in community API references, while BANK_TABS_CHANGED
    -- and PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED are account-bank adjacent. Keep all detection
    -- isolated here and verify the exact open-path events with /etrace on Retail.
    if event == "ACCOUNT_BANK_PANEL_OPENED" or event == "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" then
        return true
    end

    if Enum and Enum.BankType and bankType == Enum.BankType.Account then
        return true
    end

    return false
end

local function SafeRegisterEvent(frame, event)
    -- Some storage APIs are expansion/client-version sensitive. pcall keeps older clients
    -- from failing addon load while still allowing /etrace verification on Retail.
    pcall(frame.RegisterEvent, frame, event)
end

local function ApplyMovementRule(ruleName, detail, throttleField)
    local now = time()
    if now - (movementState[throttleField] or 0) < MOVEMENT_WARNING_THROTTLE then
        return
    end

    movementState[throttleField] = now
    SC:ApplyRuleOutcome(ruleName, {
        playerKey = SC:GetPlayerKey(),
        detail = detail,
    })
    Broadcast(ruleName)
end

local function CheckMovementRules()
    local db = SC.db or SoftcoreDB
    if not db or not db.run or not db.run.active then
        return
    end

    local mounted = IsMounted and IsMounted()
    -- In-game verification note: IsFlying() should catch mounted flight and Druid flight form
    -- in modern clients, but shapeshift edge cases may need live testing.
    local flying = IsFlying and IsFlying()

    if mounted and not movementState.mounted then
        ApplyMovementRule("mounts", "Mounted while on a Softcore run.", "mountWarnedAt")
    end

    if flying and not movementState.flying then
        ApplyMovementRule("flying", "Flying while on a Softcore run.", "flyingWarnedAt")
    end

    movementState.mounted = mounted and true or false
    movementState.flying = flying and true or false
end

function SC:Events_Register()
    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_DEAD")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("TRADE_SHOW")
    eventFrame:RegisterEvent("MAIL_SHOW")
    eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
    eventFrame:RegisterEvent("BANKFRAME_OPENED")
    eventFrame:RegisterEvent("GUILDBANKFRAME_OPENED")
    eventFrame:RegisterEvent("MERCHANT_SHOW")
    SafeRegisterEvent(eventFrame, "VOID_STORAGE_OPEN")
    SafeRegisterEvent(eventFrame, "CRAFTINGORDERS_SHOW_CUSTOMER")
    SafeRegisterEvent(eventFrame, "ACCOUNT_BANK_PANEL_OPENED")
    SafeRegisterEvent(eventFrame, "BANK_TABS_CHANGED")
    SafeRegisterEvent(eventFrame, "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    eventFrame:RegisterUnitEvent("UNIT_AURA", "player")

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_DEAD" then
            HandlePlayerDead()
        elseif event == "PLAYER_LEVEL_UP" then
            HandleLevelUp(...)
            if SC.CheckMaxLevelGap then
                SC:CheckMaxLevelGap(true)
            end
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            HandleZoneChanged()
            if SC.CheckInstanceIntegrity then
                SC:CheckInstanceIntegrity()
            end
        elseif event == "PLAYER_EQUIPMENT_CHANGED" then
            if SC.ScanEquippedGear then
                SC:ScanEquippedGear(true)
            end
        elseif event == "BAG_UPDATE_DELAYED" then
            if SC.ScanEquippedGear then
                SC:ScanEquippedGear(false)
            end
        elseif WARNING_EVENTS[event] then
            HandleWarning(event)
        elseif ACCESS_EVENTS[event] then
            HandleAccessEvent(event)
        elseif IsWarbandBankAccessEvent(event, ...) then
            ApplyAccessRule("warbandBank", "Warband bank opened or accessed.")
        elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "UNIT_AURA" then
            -- In-game verification note: mount/flying state updates can arrive through either
            -- display or aura events depending on mount type, shapeshift form, and client build.
            CheckMovementRules()
        elseif event == "GROUP_ROSTER_UPDATE" then
            SC:AddLog("GROUP_ROSTER", "Group roster changed.")
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
            if SC.CheckMaxLevelGap then
                SC:CheckMaxLevelGap(true)
            end
            Broadcast("GROUP_ROSTER_UPDATE")
        elseif event == "PLAYER_ENTERING_WORLD" then
            if SC.ScanEquippedGear then
                SC:ScanEquippedGear(true)
            end
            if SC.CheckInstanceIntegrity then
                SC:CheckInstanceIntegrity()
            end
            if SC.CheckMaxLevelGap then
                SC:CheckMaxLevelGap(true)
            end
            Broadcast("PLAYER_ENTERING_WORLD")
        end

        if SC.UI_Update then
            SC:UI_Update()
        end
    end)
end
