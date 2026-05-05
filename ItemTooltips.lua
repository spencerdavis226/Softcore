-- Advisory item tooltip flags for the current local run.

local SC = Softcore

local SOFTCORE_TOOLTIP_LINE = "Softcore: Not allowed for this run"

local QUALITY_HEIRLOOM = 7

local function IsRuleDisallowed(ruleValue)
    return ruleValue ~= nil and ruleValue ~= "ALLOWED" and ruleValue ~= "LOG_ONLY" and ruleValue ~= false
end

local function GetItemInfoCompat(itemRef)
    if C_Item and C_Item.GetItemInfo then
        local ok, itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType = pcall(C_Item.GetItemInfo, itemRef)
        if ok then
            return itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType
        end
    elseif GetItemInfo then
        local ok, itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType = pcall(GetItemInfo, itemRef)
        if ok then
            return itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType
        end
    end

    return nil
end

local function GetItemInfoInstantCompat(itemRef)
    if C_Item and C_Item.GetItemInfoInstant then
        local ok, itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID = pcall(C_Item.GetItemInfoInstant, itemRef)
        if ok then
            return itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID
        end
    elseif GetItemInfoInstant then
        local ok, itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID = pcall(GetItemInfoInstant, itemRef)
        if ok then
            return itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID
        end
    end

    return nil
end

local function Trim(text)
    return string.gsub(tostring(text or ""), "^%s*(.-)%s*$", "%1")
end

local function NormalizeTooltipText(text)
    text = tostring(text or "")
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    return Trim(text)
end

local function AddCandidateName(names, value)
    value = Trim(value)
    if value ~= "" then
        names[value] = true
    end
end

local function AddCraftedByMarker(markers, formatText, playerName)
    if not formatText or formatText == "" or not playerName or playerName == "" then
        return
    end

    local ok, marker = pcall(string.format, formatText, playerName)
    if ok and marker and marker ~= "" then
        markers[NormalizeTooltipText(marker)] = true
    end
end

local function GetPlayerCraftingNames()
    local names = {}
    local playerName = UnitName("player")
    local fullName, fullRealm = UnitFullName("player")
    local realm = fullRealm
    if not realm or realm == "" then
        realm = GetRealmName and GetRealmName() or nil
    end

    AddCandidateName(names, playerName)
    AddCandidateName(names, fullName)
    if fullName and realm and realm ~= "" then
        AddCandidateName(names, fullName .. "-" .. realm)
        AddCandidateName(names, fullName .. " - " .. realm)
    elseif playerName and realm and realm ~= "" then
        AddCandidateName(names, playerName .. "-" .. realm)
        AddCandidateName(names, playerName .. " - " .. realm)
    end

    return names
end

local function IsSelfCraftedTooltipLine(text)
    local markers = {}
    local formats = {
        _G.ITEM_CREATED_BY,
        "Made by %s",
        "Crafted by %s",
        "Created by %s",
    }

    for playerName in pairs(GetPlayerCraftingNames()) do
        for _, formatText in ipairs(formats) do
            AddCraftedByMarker(markers, formatText, playerName)
        end
    end

    return markers[NormalizeTooltipText(text)] == true
end

local function TooltipDataShowsSelfCrafted(data)
    for _, line in ipairs(data and data.lines or {}) do
        if line.leftText and IsSelfCraftedTooltipLine(line.leftText) then
            return true
        end
    end

    return false
end

local function TooltipFrameShowsSelfCrafted(tooltip)
    local name = tooltip and tooltip.GetName and tooltip:GetName()
    if not name then return false end

    for i = 1, tooltip:NumLines() do
        local line = _G[name .. "TextLeft" .. i]
        if line and IsSelfCraftedTooltipLine(line:GetText() or "") then
            return true
        end
    end

    return false
end

local function TooltipAlreadyHasSoftcoreLine(tooltip)
    local name = tooltip and tooltip.GetName and tooltip:GetName()
    if not name then return false end

    for i = 1, tooltip:NumLines() do
        local line = _G[name .. "TextLeft" .. i]
        if line and NormalizeTooltipText(line:GetText() or "") == SOFTCORE_TOOLTIP_LINE then
            return true
        end
    end

    return false
end

local function AddSoftcoreTooltipLine(tooltip, itemRef, data)
    if not tooltip or TooltipAlreadyHasSoftcoreLine(tooltip) then
        return
    end

    if not itemRef then
        local _, itemLink = tooltip.GetItem and tooltip:GetItem()
        itemRef = itemLink or data and data.hyperlink
    end

    if not itemRef then
        return
    end

    if SC:IsItemRestrictedForRunTooltip(itemRef, tooltip, data) then
        tooltip:AddLine(SOFTCORE_TOOLTIP_LINE, 1, 0.15, 0.15, false)
        tooltip:Show()
    end
end

local function IsEquippableItem(itemRef)
    local _, _, _, itemEquipLoc = GetItemInfoInstantCompat(itemRef)
    return itemEquipLoc and itemEquipLoc ~= "" and itemEquipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
end

local function IsRestrictedConsumable(itemRef)
    local rule = SC.GetRule and SC:GetRule("consumables")
    if not IsRuleDisallowed(rule) then
        return false
    end

    local _, _, _, _, _, itemType, itemSubType = GetItemInfoCompat(itemRef)
    return itemType == "Consumable" and itemSubType ~= "Other"
end

local function IsRestrictedItemEnhancement(itemRef)
    local rule = SC.GetRule and SC:GetRule("enchants")
    if not IsRuleDisallowed(rule) then
        return false
    end

    local _, _, _, _, _, itemType, itemSubType = GetItemInfoCompat(itemRef)
    return itemType == "Consumable" and itemSubType == "Item Enhancement"
end

function SC:IsItemRestrictedForRunTooltip(itemRef, tooltip, data)
    if not itemRef or not self.IsRunActive or not self:IsRunActive() then
        return false
    end
    if self.IsLocalCharacterFailed and self:IsLocalCharacterFailed() then
        return false
    end

    if IsRestrictedConsumable(itemRef) or IsRestrictedItemEnhancement(itemRef) then
        return true
    end

    if not IsEquippableItem(itemRef) then
        return false
    end

    local _, itemLink, quality = GetItemInfoCompat(itemRef)
    itemLink = itemLink or itemRef

    if quality == QUALITY_HEIRLOOM then
        return IsRuleDisallowed(self:GetRule("heirlooms"))
    end

    if self.IsGearQualityInvalidForRule and self:IsGearQualityInvalidForRule(self:GetRule("gearQuality"), quality) then
        local selfCraftedAllowed = self:GetRule("selfCraftedGearAllowed") == true
        local isSelfCrafted = TooltipDataShowsSelfCrafted(data) or TooltipFrameShowsSelfCrafted(tooltip)
        if not (selfCraftedAllowed and isSelfCrafted) then
            return true
        end
    end

    if self.GetPermanentEnchantIdFromItemLink and self:GetPermanentEnchantIdFromItemLink(itemLink) and IsRuleDisallowed(self:GetRule("enchants")) then
        return true
    end

    return false
end

function SC:ItemTooltips_Register()
    if self.itemTooltipsRegistered then
        return
    end
    self.itemTooltipsRegistered = true

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            AddSoftcoreTooltipLine(tooltip, nil, data)
        end)
    end

    local function GetContainerItemLinkCompat(bag, slot)
        if C_Container and C_Container.GetContainerItemLink then
            return C_Container.GetContainerItemLink(bag, slot)
        end
        if GetContainerItemLink then
            return GetContainerItemLink(bag, slot)
        end
        return nil
    end

    local function HookTooltipMethod(tooltip, methodName, callback)
        if tooltip and tooltip[methodName] and hooksecurefunc then
            hooksecurefunc(tooltip, methodName, callback)
        end
    end

    local function HookItemTooltip(tooltip)
        HookTooltipMethod(tooltip, "SetBagItem", function(frame, bag, slot)
            AddSoftcoreTooltipLine(frame, GetContainerItemLinkCompat(bag, slot), nil)
        end)
        HookTooltipMethod(tooltip, "SetInventoryItem", function(frame, unit, slot)
            AddSoftcoreTooltipLine(frame, GetInventoryItemLink and GetInventoryItemLink(unit, slot), nil)
        end)
        HookTooltipMethod(tooltip, "SetHyperlink", function(frame, link)
            AddSoftcoreTooltipLine(frame, link, nil)
        end)
    end

    HookItemTooltip(GameTooltip)
    HookItemTooltip(ItemRefTooltip)
end
