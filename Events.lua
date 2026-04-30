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
    vehicleActive = false,
    vehicleReason = nil,
    mountWarnedAt = 0,
    flyingWarnedAt = 0,
    flightPathWarnedAt = 0,
}

local MOVEMENT_WARNING_THROTTLE = 30
local ACCESS_WARNING_THROTTLE = 30
local accessWarnedAt = {}
local petBattleActive = false
local DRUID_TRAVEL_FORM_ID = 3

local function Broadcast(reason)
    if SC.Sync_BroadcastStatus then
        SC:Sync_BroadcastStatus(reason)
    end
end

local function HandlePlayerDead()
    local db = SC.db or SoftcoreDB
    if not db or not db.run or not db.run.active then return end
    if SC.IsLocalCharacterFailed and SC:IsLocalCharacterFailed() then return end

    local playerKey = SC:GetPlayerKey()
    local participant = SC:GetOrCreateParticipant(playerKey)
    if participant.status == "FAILED" then return end

    db.run.deathCount = (db.run.deathCount or 0) + 1
    participant.deathCount = (participant.deathCount or 0) + 1
    local announcementDetail

    local maxDeaths = db.run.ruleset and db.run.ruleset.maxDeaths
    local maxDeathsValue = tonumber(db.run.ruleset and db.run.ruleset.maxDeathsValue) or 1

    if maxDeaths and maxDeathsValue > 1 then
        if participant.deathCount >= maxDeathsValue then
            local detail = "Death limit reached (" .. participant.deathCount .. "/" .. maxDeathsValue .. " deaths)."
            announcementDetail = detail
            SC:AddLog("DEATH", detail)
            SC:MarkParticipantFailed(playerKey, detail)
            SC:AddViolation("death", detail, "FATAL", playerKey)
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Softcore: character failed — death limit reached (" .. participant.deathCount .. "/" .. maxDeathsValue .. ").|r")
        else
            local remaining = maxDeathsValue - participant.deathCount
            local detail = "Died (" .. participant.deathCount .. "/" .. maxDeathsValue .. " deaths, " .. remaining .. " remaining)."
            announcementDetail = detail
            SC:AddLog("DEATH", detail)
            db.run.warningCount = (db.run.warningCount or 0) + 1
            if participant.status == "ACTIVE" then
                participant.status = "WARNING"
            end
            SC:AddViolation("death", detail, "WARNING", playerKey)
            DEFAULT_CHAT_FRAME:AddMessage("|cfffbbf24Softcore: death recorded — " .. remaining .. " life/lives remaining.|r")
        end
    else
        announcementDetail = "Character died. Character failed permanently."
        SC:AddLog("DEATH", "Character died. Run failed permanently.")
        SC:ApplyRuleOutcome("death", {
            playerKey = playerKey,
            detail = announcementDetail,
        })
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555Softcore: character failed due to death.|r")
    end

    if SC.AnnounceLocalDeath then
        SC:AnnounceLocalDeath(announcementDetail)
    end
    Broadcast("PLAYER_DEAD")
end

local function HandleLevelUp(level)
    local db = SC.db or SoftcoreDB
    if not db then
        return
    end

    db.character.level = level or UnitLevel("player") or db.character.level
    if not db.run or not db.run.active or (SC.IsLocalCharacterFailed and SC:IsLocalCharacterFailed()) then
        return
    end

    SC:GetOrCreateParticipant(SC:GetPlayerKey()).currentLevel = db.character.level
    SC:AddLog("LEVEL_UP", "Reached level " .. tostring(db.character.level) .. ".")
    if SC.Achievements_OnLevelChanged then
        SC:Achievements_OnLevelChanged(db.character.level)
    end
    Broadcast("PLAYER_LEVEL_UP")
end

local function HandleZoneChanged()
    local db = SC.db or SoftcoreDB
    if not db then return end

    db.character.zone = GetRealZoneText() or db.character.zone or "Unknown"
    if not db.run or not db.run.active or (SC.IsLocalCharacterFailed and SC:IsLocalCharacterFailed()) then
        return
    end
end

local pvpWarnedAt = 0
local PVP_WARNING_THROTTLE = 60
local PVP_ADVISORY_THROTTLE = 300
local pvpAdvisoryWarnedAt = {}

local function IsRunActiveForPvpAdvisory()
    local db = SC.db or SoftcoreDB
    if not db or not db.run or not db.run.active then return false end
    if SC.IsLocalCharacterFailed and SC:IsLocalCharacterFailed() then return false end
    return true
end

local function IsRunActiveForLocalAudit()
    local db = SC.db or SoftcoreDB
    if not db or not db.run or not db.run.active then return false end
    if SC.IsLocalCharacterFailed and SC:IsLocalCharacterFailed() then return false end
    return true
end

local function SafeUnitBoolean(func, unit)
    if not func then return false end

    local ok, result = pcall(func, unit)
    return ok and result == true
end

local function SafeGlobalBoolean(func)
    if not func then return false end

    local ok, result = pcall(func)
    return ok and result == true
end

local function AddLocalAudit(kind, message, extra)
    if not IsRunActiveForLocalAudit() then return end

    extra = extra or {}
    extra.suppressAuditSync = true
    SC:AddLog(kind, message, extra)
end

local function IsWarModeActive()
    if not C_PvP then return false end

    if C_PvP.IsWarModeActive then
        local ok, active = pcall(C_PvP.IsWarModeActive)
        if ok and active then return true end
    end

    if C_PvP.IsWarModeDesired then
        local ok, desired = pcall(C_PvP.IsWarModeDesired)
        if ok and desired then return true end
    end

    return false
end

local function WarnPvpAdvisory(key, detail)
    if not IsRunActiveForPvpAdvisory() then return end

    local now = time()
    if now - (pvpAdvisoryWarnedAt[key] or 0) < PVP_ADVISORY_THROTTLE then
        return
    end
    pvpAdvisoryWarnedAt[key] = now

    DEFAULT_CHAT_FRAME:AddMessage("|cfffbbf24Softcore: " .. tostring(detail) .. "|r")
    SC:AddLog("PVP_ADVISORY", detail, {
        suppressAuditSync = true,
    })
end

local function CheckPlayerPvpAdvisory()
    if not IsRunActiveForPvpAdvisory() then return end

    if IsWarModeActive() then
        WarnPvpAdvisory("warMode", "War Mode is enabled during this run.")
    elseif UnitIsPVP and UnitIsPVP("player") then
        WarnPvpAdvisory("playerPvpFlag", "Your character is PvP flagged during this run.")
    end
end

local function CheckTargetPvpAdvisory()
    if not IsRunActiveForPvpAdvisory() then return end
    if not UnitExists or not UnitExists("target") then return end
    if UnitIsUnit and UnitIsUnit("target", "player") then return end
    if UnitIsPlayer and not UnitIsPlayer("target") then return end
    if not UnitIsPVP or not UnitIsPVP("target") then return end

    local name = UnitName and UnitName("target") or "target"
    WarnPvpAdvisory("targetPvpFlag:" .. tostring(name or "?"), "Target is PvP flagged: " .. tostring(name or "unknown") .. ".")
end

local function CheckInstancedPvP()
    local db = SC.db or SoftcoreDB
    if not db or not db.run or not db.run.active then return end
    if SC.IsLocalCharacterFailed and SC:IsLocalCharacterFailed() then return end

    local _, instanceType = GetInstanceInfo()
    if instanceType ~= "pvp" and instanceType ~= "arena" then return end

    local now = time()
    if now - pvpWarnedAt < PVP_WARNING_THROTTLE then return end
    pvpWarnedAt = now

    SC:ApplyRuleOutcome("instancedPvP", {
        playerKey = SC:GetPlayerKey(),
        detail = "Entered instanced PvP (" .. tostring(instanceType) .. ").",
    })
    Broadcast("instancedPvP")
end

local function HandleWarning(event)
    local db = SC.db or SoftcoreDB
    if not db or not db.run or not db.run.active or (SC.IsLocalCharacterFailed and SC:IsLocalCharacterFailed()) then
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
    if not db or not db.run or not db.run.active or (SC.IsLocalCharacterFailed and SC:IsLocalCharacterFailed()) then
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

local function IsWarbandBankUIVisible()
    local panel = _G.AccountBankPanel
    if panel and panel.IsShown and panel:IsShown() then
        return true
    end
    if C_Bank and C_Bank.IsBankOpen and Enum and Enum.BankType then
        local ok, open = pcall(C_Bank.IsBankOpen, Enum.BankType.Account)
        if ok and open then
            return true
        end
    end
    return false
end

local function IsWarbandBankAccessEvent(event, ...)
    local bankType = ...

    -- Warband / account bank (The War Within+). ACCOUNT_BANK_PANEL_OPENED is a direct open signal.
    -- PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED and BANK_TABS_CHANGED (Account) can fire from client
    -- sync without the bank UI shown — e.g. around flight masters / taxi — so require a visible
    -- account-bank panel (or C_Bank.IsBankOpen) for those.
    if event == "ACCOUNT_BANK_PANEL_OPENED" then
        return true
    end

    if event == "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" then
        return IsWarbandBankUIVisible()
    end

    if Enum and Enum.BankType and bankType == Enum.BankType.Account then
        return IsWarbandBankUIVisible()
    end

    return false
end

local function SafeRegisterEvent(frame, event)
    -- Some storage APIs are expansion/client-version sensitive. pcall keeps older clients
    -- from failing addon load while still allowing /etrace verification on Retail.
    pcall(frame.RegisterEvent, frame, event)
end

local function GetForcedMovementReason()
    if SafeUnitBoolean(UnitOnTaxi, "player") then
        return "taxi"
    end

    if SafeUnitBoolean(UnitInVehicle, "player")
        or SafeUnitBoolean(UnitUsingVehicle, "player")
        or SafeUnitBoolean(UnitHasVehicleUI, "player")
        or SafeGlobalBoolean(CanExitVehicle) then
        return "vehicle"
    end

    if SafeGlobalBoolean(HasOverrideActionBar) then
        return "override"
    end

    return nil
end

local function FormatForcedMovementReason(reason)
    if reason == "taxi" then return "taxi or forced flight" end
    if reason == "override" then return "override action bar" end
    return "vehicle"
end

local function IsDruidGroundTravelFormActive(flying)
    if not UnitClass or not GetShapeshiftFormID then
        return false
    end

    local _, classFile = UnitClass("player")
    if classFile ~= "DRUID" then
        return false
    end

    local formId = GetShapeshiftFormID()
    if formId ~= DRUID_TRAVEL_FORM_ID then
        return false
    end

    if flying or SafeGlobalBoolean(IsSwimming) then
        return false
    end

    return true
end

local function ApplyMovementRule(ruleName, detail, throttleField)
    if not IsRunActiveForLocalAudit() then
        return
    end

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
    if SC.IsLocalCharacterFailed and SC:IsLocalCharacterFailed() then
        return
    end

    local forcedReason = GetForcedMovementReason()
    if forcedReason then
        if not movementState.vehicleActive or movementState.vehicleReason ~= forcedReason then
            AddLocalAudit("FORCED_MOVEMENT", "Vehicle or forced movement active: " .. FormatForcedMovementReason(forcedReason) .. ".", {
                reason = forcedReason,
            })
        end
        movementState.vehicleActive = true
        movementState.vehicleReason = forcedReason
        movementState.mounted = false
        movementState.flying = false
        return
    elseif movementState.vehicleActive then
        AddLocalAudit("FORCED_MOVEMENT_ENDED", "Vehicle or forced movement ended.", {
            reason = movementState.vehicleReason,
        })
        movementState.vehicleActive = false
        movementState.vehicleReason = nil
        movementState.mounted = false
        movementState.flying = false
    end

    local mounted = IsMounted and IsMounted()
    -- In-game verification note: IsFlying() should catch mounted flight and Druid flight form
    -- in modern clients, but shapeshift edge cases may need live testing.
    local flying = IsFlying and IsFlying()
    local druidGroundTravelForm = IsDruidGroundTravelFormActive(flying)

    if (mounted or druidGroundTravelForm) and not movementState.mounted then
        local detail = druidGroundTravelForm
            and "Used Druid land Travel Form while on a Softcore run."
            or "Mounted while on a Softcore run."
        ApplyMovementRule("mounts", detail, "mountWarnedAt")
    end

    if flying and not movementState.flying then
        ApplyMovementRule("flying", "Flying while on a Softcore run.", "flyingWarnedAt")
    end

    movementState.mounted = (mounted or druidGroundTravelForm) and true or false
    movementState.flying = flying and true or false
end

local function ApplyFlightPathRule(detail)
    ApplyMovementRule("flightPaths", detail or "Used a flight path while on a Softcore run.", "flightPathWarnedAt")
end

local function HandlePetBattleStarted()
    if petBattleActive then return end

    petBattleActive = true
    AddLocalAudit("PET_BATTLE_STARTED", "Pet battle started.", {
        allowedByDefault = true,
    })
end

local function HandlePetBattleEnded()
    if not petBattleActive then return end

    petBattleActive = false
    AddLocalAudit("PET_BATTLE_ENDED", "Pet battle ended.", {
        allowedByDefault = true,
    })
end

function SC:CheckMovementRules()
    CheckMovementRules()
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
    SafeRegisterEvent(eventFrame, "GET_ITEM_INFO_RECEIVED")
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
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    SafeRegisterEvent(eventFrame, "PLAYER_FLAGS_CHANGED")
    SafeRegisterEvent(eventFrame, "TAXIMAP_OPENED")
    SafeRegisterEvent(eventFrame, "TAXIMAP_CLOSED")
    SafeRegisterEvent(eventFrame, "UNIT_ENTERING_VEHICLE")
    SafeRegisterEvent(eventFrame, "UNIT_ENTERED_VEHICLE")
    SafeRegisterEvent(eventFrame, "UNIT_EXITING_VEHICLE")
    SafeRegisterEvent(eventFrame, "UNIT_EXITED_VEHICLE")
    SafeRegisterEvent(eventFrame, "UPDATE_OVERRIDE_ACTIONBAR")
    SafeRegisterEvent(eventFrame, "VEHICLE_UPDATE")
    SafeRegisterEvent(eventFrame, "PLAYER_CONTROL_LOST")
    SafeRegisterEvent(eventFrame, "PLAYER_CONTROL_GAINED")
    SafeRegisterEvent(eventFrame, "PET_BATTLE_OPENING_START")
    SafeRegisterEvent(eventFrame, "PET_BATTLE_CLOSE")
    eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
    eventFrame:RegisterUnitEvent("UNIT_FACTION", "player", "target")

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
            CheckInstancedPvP()
            CheckPlayerPvpAdvisory()
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
        elseif event == "GET_ITEM_INFO_RECEIVED" then
            if SC.ScanEquippedGear then
                SC:ScanEquippedGear(true)
            end
        elseif WARNING_EVENTS[event] then
            HandleWarning(event)
        elseif ACCESS_EVENTS[event] then
            HandleAccessEvent(event)
        elseif IsWarbandBankAccessEvent(event, ...) then
            ApplyAccessRule("warbandBank", "Warband bank opened or accessed.")
        elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "UNIT_AURA" or event == "UNIT_ENTERING_VEHICLE" or event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITING_VEHICLE" or event == "UNIT_EXITED_VEHICLE" or event == "UPDATE_OVERRIDE_ACTIONBAR" or event == "VEHICLE_UPDATE" or event == "PLAYER_CONTROL_LOST" or event == "PLAYER_CONTROL_GAINED" then
            -- In-game verification note: mount/flying state updates can arrive through either
            -- display, aura, vehicle, or override-bar events depending on client build and quest mechanics.
            CheckMovementRules()
        elseif event == "PET_BATTLE_OPENING_START" then
            HandlePetBattleStarted()
        elseif event == "PET_BATTLE_CLOSE" then
            HandlePetBattleEnded()
        elseif event == "PLAYER_TARGET_CHANGED" then
            CheckTargetPvpAdvisory()
        elseif event == "PLAYER_FLAGS_CHANGED" or event == "UNIT_FACTION" then
            local unit = ...
            if not unit or unit == "player" then
                CheckPlayerPvpAdvisory()
            end
            if not unit or unit == "target" then
                CheckTargetPvpAdvisory()
            end
        elseif event == "TAXIMAP_OPENED" then
            -- Presence of the map alone is not a violation; the taxi API hook below
            -- records actual flight path use.
        elseif event == "TAXIMAP_CLOSED" then
            CheckMovementRules()
        elseif event == "GROUP_ROSTER_UPDATE" then
            if SC.ClearStalePendingProposal then
                SC:ClearStalePendingProposal()
            end
            if SC.ClearStaleRuleAmendments then
                SC:ClearStaleRuleAmendments()
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
            if SC.CheckPendingProposalOnRosterUpdate then
                SC:CheckPendingProposalOnRosterUpdate()
            end
            if SC.Sync_SendHello then
                SC:Sync_SendHello()
            end
            if SC.Sync_NudgeStatus then
                SC:Sync_NudgeStatus("GROUP_ROSTER_UPDATE", { now = true })
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(2, function()
                    Broadcast("GROUP_ROSTER_UPDATE")
                end)
            else
                Broadcast("GROUP_ROSTER_UPDATE")
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            if SC.ClearStalePendingProposal then
                SC:ClearStalePendingProposal()
            end
            if SC.ClearStaleRuleAmendments then
                SC:ClearStaleRuleAmendments()
            end
            if SC.ScanEquippedGear then
                SC:ScanEquippedGear(true)
            end
            if SC.CheckInstanceIntegrity then
                SC:CheckInstanceIntegrity()
            end
            if SC.CheckMaxLevelGap then
                SC:CheckMaxLevelGap(true)
            end
            if SC.EnforceActionCamSettings then
                SC:EnforceActionCamSettings()
            end
            CheckPlayerPvpAdvisory()
            CheckTargetPvpAdvisory()
            Broadcast("PLAYER_ENTERING_WORLD")
        end

        if SC.HUD_Refresh then
            SC:HUD_Refresh()
        end
    end)

    -- Consumable detection: hook bag item use, flag Consumable-type items.
    -- Subtype "Other" is skipped because it includes toys and misc one-use items.
    local function ApplyConsumableRule(itemRef)
        if not SC:IsRunActive() then return end
        if SC.IsLocalCharacterFailed and SC:IsLocalCharacterFailed() then return end
        local rule = SC:GetRule("consumables")
        if not rule or rule == "ALLOWED" then return end

        local itemName, link, _, _, _, itemType, itemSubType
        if C_Item and C_Item.GetItemInfo then
            itemName, link, _, _, _, itemType, itemSubType = C_Item.GetItemInfo(itemRef)
        elseif GetItemInfo then
            itemName, link, _, _, _, itemType, itemSubType = GetItemInfo(itemRef)
        end
        if itemType ~= "Consumable" or itemSubType == "Other" then return end

        SC:ApplyRuleOutcome("consumables", {
            playerKey = SC:GetPlayerKey(),
            detail = "Used consumable: " .. tostring(link or itemName or itemRef or "?") .. " (" .. tostring(itemSubType or "?") .. ").",
        })
    end

    local function OnUseContainerItem(bag, slot)
        if not (C_Container and C_Container.GetContainerItemLink) then return end
        ApplyConsumableRule(C_Container.GetContainerItemLink(bag, slot))
    end

    local function OnUseAction(slot)
        if not GetActionInfo then return end
        local actionType, itemId = GetActionInfo(slot)
        if actionType == "item" and itemId then
            ApplyConsumableRule(itemId)
        end
    end

    if C_Container and C_Container.UseContainerItem then
        hooksecurefunc(C_Container, "UseContainerItem", OnUseContainerItem)
    else
        hooksecurefunc("UseContainerItem", OnUseContainerItem)
    end
    if UseAction then
        hooksecurefunc("UseAction", OnUseAction)
    end

    -- Flight paths are most reliably detected at the taxi API call.
    if C_TaxiMap and C_TaxiMap.TakeTaxiNode then
        hooksecurefunc(C_TaxiMap, "TakeTaxiNode", function()
            ApplyFlightPathRule("Took a flight path while on a Softcore run.")
        end)
    elseif TakeTaxiNode then
        hooksecurefunc("TakeTaxiNode", function()
            ApplyFlightPathRule("Took a flight path while on a Softcore run.")
        end)
    end
end
