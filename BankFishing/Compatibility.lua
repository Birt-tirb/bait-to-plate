local _, addon = ...
local Compat = {}
addon.Compat = Compat

local interface = GetBuildInfo and select(4, GetBuildInfo()) or 0
Compat.isForever = interface >= 16000 and interface < 17000
Compat.isRetail = not Compat.isForever and
    ((WOW_PROJECT_MAINLINE ~= nil and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) or interface >= 100000)
Compat.supportsPoolData = Compat.isForever or (interface >= 10000 and interface < 40000)

function Compat.IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

function Compat.GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    end
    if GetSpellInfo then
        return GetSpellInfo(spellID)
    end
end

Compat.Item = {}

function Compat.Item.GetItemInfoInstant(item)
    local query = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if query then
        return query(item)
    end
end

function Compat.Item.GetItemNameByID(itemID)
    if C_Item and C_Item.GetItemNameByID then
        return C_Item.GetItemNameByID(itemID)
    end
    local query = C_Item and C_Item.GetItemInfo or GetItemInfo
    if query then
        return query(itemID)
    end
end

function Compat.Item.GetItemIconByID(itemID)
    local query = C_Item and C_Item.GetItemIconByID or GetItemIcon
    if query then
        return query(itemID)
    end
    local info = C_Item and C_Item.GetItemInfo or GetItemInfo
    if info then
        return select(10, info(itemID))
    end
end

function Compat.Item.GetItemCount(...)
    local query = C_Item and C_Item.GetItemCount or GetItemCount
    return query and query(...) or 0
end

function Compat.IsSpellKnown(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(spellID)
    end
    if IsPlayerSpell then
        return IsPlayerSpell(spellID)
    end
    return IsSpellKnown and IsSpellKnown(spellID) or false
end

function Compat.GetFishingPoleSlot()
    -- Retail's FishingToolSlot is a profession slot. Classic poles use main hand.
    local slot = Compat.isRetail and 28 or 16
    local itemID = GetInventoryItemID("player", slot)
    if Compat.IsSecret(itemID) or not itemID then
        return
    end
    local _, _, _, _, _, itemClass, subclass = Compat.Item.GetItemInfoInstant(itemID)
    if (itemClass == 2 and subclass == 20) or
        (Compat.isRetail and itemClass == 19 and subclass == 9) then
        return slot
    end
end

function Compat.FishingPoleEquipped()
    return Compat.GetFishingPoleSlot() ~= nil
end

function Compat.CanShowFishingControls()
    if Compat.isRetail then
        return Compat.IsSpellKnown(7620) or Compat.IsSpellKnown(131474)
    end
    return Compat.FishingPoleEquipped()
end

function Compat.PoleLureTime()
    local slot = Compat.GetFishingPoleSlot()
    if not slot then
        return 0
    end
    if C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo then
        local enchant = C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot)
        local remaining = enchant and enchant.remainingTimeMs
        if not Compat.IsSecret(remaining) and type(remaining) == "number" then
            return math.max(0, math.ceil(remaining / 1000))
        end
        return 0
    end
    if slot ~= 16 then
        return 0
    end
    if C_Item and C_Item.GetWeaponEnchantInfo and Enum and Enum.WeaponSlot and Enum.ItemEnchantType then
        local enchants = C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot.MainHand)
        for _, enchant in ipairs(enchants or {}) do
            if not Compat.IsSecret(enchant.hasEnchant) and enchant.hasEnchant
                and enchant.enchantType == Enum.ItemEnchantType.Temporary
                and not Compat.IsSecret(enchant.timeLeft) and type(enchant.timeLeft) == "number" then
                return math.max(0, math.ceil(enchant.timeLeft / 1000))
            end
        end
        return 0
    end
    if GetWeaponEnchantInfo then
        local active, remaining = GetWeaponEnchantInfo()
        if not Compat.IsSecret(active) and active and not Compat.IsSecret(remaining)
            and type(remaining) == "number" then
            return math.max(0, math.ceil(remaining / 1000))
        end
    end
    return 0
end

function Compat.GetCookingSkill()
    local trade = C_TradeSkillUI
    if Compat.isRetail then
        -- The included recipes belong to Retail's Classic Cooking skill line.
        local info = trade and trade.GetProfessionInfoBySkillLineID and trade.GetProfessionInfoBySkillLineID(2548)
        return info and info.skillLevel or 0, info and info.maxSkillLevel or 0
    end
    if GetProfessions and GetProfessionInfo then
        local cooking = select(5, GetProfessions())
        if cooking then
            local _, _, skill, maximum = GetProfessionInfo(cooking)
            return skill or 0, maximum or 0
        end
    end
    if trade and trade.GetProfessionInfoBySkillLineID then
        local info = trade.GetProfessionInfoBySkillLineID(185)
        return info and info.skillLevel or 0, info and info.maxSkillLevel or 0
    end
    if GetNumSkillLines and GetSkillLineInfo then
        local cookingName = Compat.GetSpellName(2550)
        for index = 1, GetNumSkillLines() do
            local name, header, _, skill, _, _, maximum = GetSkillLineInfo(index)
            if not header and name == cookingName then
                return skill or 0, maximum or 0
            end
        end
    end
    return 0, 0
end

local function IsOwnCookingWindow()
    local trade = C_TradeSkillUI
    if trade and trade.GetBaseProfessionInfo and trade.GetRecipeInfo then
        if (trade.IsTradeSkillReady and not trade.IsTradeSkillReady())
            or (trade.IsTradeSkillLinked and trade.IsTradeSkillLinked())
            or (trade.IsTradeSkillGuild and trade.IsTradeSkillGuild())
            or (trade.IsTradeSkillGuildMember and trade.IsTradeSkillGuildMember())
            or (trade.IsNPCCrafting and trade.IsNPCCrafting()) then
            return false
        end
        local info = trade.GetBaseProfessionInfo()
        return info and info.professionID == 185
    end
    if GetTradeSkillLine and not (IsTradeSkillLinked and IsTradeSkillLinked()) then
        local name = GetTradeSkillLine()
        return name ~= nil and name == Compat.GetSpellName(2550)
    end
    return false
end

function Compat.ScanCookingRecipes(recipes, known)
    if not known or not IsOwnCookingWindow() then
        return
    end
    local trade = C_TradeSkillUI
    if trade and trade.GetBaseProfessionInfo and trade.GetRecipeInfo then
        for _, recipe in ipairs(recipes) do
            local id = recipe[1]
            local info = trade.GetRecipeInfo(id)
            if info and type(info.learned) == "boolean" then
                known[id] = info.learned
                known.checked = true
            end
        end
    elseif GetNumTradeSkills and GetTradeSkillRecipeLink then
        local listed = {}
        for index = 1, GetNumTradeSkills() do
            local link = GetTradeSkillRecipeLink(index)
            if not Compat.IsSecret(link) and type(link) == "string" then
                local id = tonumber(link:match("enchant:(%d+)"))
                if id then
                    listed[id] = true
                end
            end
        end
        for _, recipe in ipairs(recipes) do
            local id = recipe[1]
            if listed[id] or Compat.IsSpellKnown(id) then
                known[id] = true
            end
        end
        -- Hidden or filtered legacy rows leave unlisted recipes unverified.
        known.checked = true
    end
end

function Compat.OpenCooking()
    if C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
        C_TradeSkillUI.OpenTradeSkill(185)
    end
end

function Compat.ConfigureCookingButton(button)
    if not (C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill) then
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", Compat.GetSpellName(2550))
    end
end

local function GetCVarValue(name)
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    return get and get(name)
end

function Compat.EnableInteractKey()
    local setting = Settings and Settings.GetSetting and Settings.GetSetting("PROXY_ENABLE_INTERACT")
    if setting then
        if not setting:GetValue() then
            setting:SetValue(true, true)
        end
        return setting:GetValue()
    end
    local value = GetCVarValue("SoftTargetInteract")
    if value == nil then
        return false
    end
    if tonumber(value) == 0 then
        local set = C_CVar and C_CVar.SetCVar or SetCVar
        if not set then
            return false
        end
        set("SoftTargetInteract", 3)
    end
    return true
end

function Compat.GetNativeInteractName()
    local frame = GamepadMainActionBarFrame
    local bars = frame and frame.PageUnit and frame.PageUnit.actionBars
    local button = bars and bars.topBar and bars.topBar.Right and bars.topBar.Right.ActionButton1
    local aspect = Enum and Enum.ForbiddenAspect and Enum.ForbiddenAspect.ScriptedInput
    if not button or not aspect or button:IsForbidden()
        or not button.HasAccessConstraints or button:HasAccessConstraints() ~= false
        or not button.HasAnyForbiddenAspects or button:HasAnyForbiddenAspects(aspect) ~= false
        or not button:GetScript("OnClick") then
        return
    end
    local name = button:GetName()
    if name and name:match("^[%w_]+$") and _G[name] == button then
        return name
    end
end

function Compat.CanReachBobber()
    local guid = UnitGUID("softinteract")
    if Compat.IsSecret(guid) or type(guid) ~= "string"
        or guid:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)%-") ~= "35591" then
        return false
    end
    if not UnitIsInInteractRange then
        return false
    end
    local inRange = UnitIsInInteractRange("softinteract")
    return not Compat.IsSecret(inRange) and inRange == true
end

local temporaryRange
function Compat.UpdateInteractRange(isFishing)
    if not C_CVar or not C_CVar.SetTempCVar or not C_CVar.RemoveTempCVar then
        return
    end
    local value = GetCVarValue("SoftTargetInteractRange")
    local range = not Compat.IsSecret(value) and tonumber(value)
    if isFishing then
        if not temporaryRange and range and range < 60
            and pcall(C_CVar.SetTempCVar, "SoftTargetInteractRange", "60") then
            temporaryRange = tonumber(GetCVarValue("SoftTargetInteractRange"))
        end
    elseif temporaryRange then
        local applied = temporaryRange
        temporaryRange = nil
        if range == applied then
            C_CVar.RemoveTempCVar("SoftTargetInteractRange")
        end
    end
end

local minimapDiameters = {
    outdoor = { [0] = 466.6667, 400, 333.3333, 266.6667, 200, 133.3333 },
    indoor = { [0] = 300, 240, 180, 120, 80, 50 },
}

function Compat.GetMinimapViewRadius()
    if C_Minimap and C_Minimap.GetViewRadius then
        return C_Minimap.GetViewRadius()
    end
    local zoom = Minimap:GetZoom()
    if Compat.IsSecret(zoom) then
        return
    end
    local scales = IsIndoors and IsIndoors() and minimapDiameters.indoor or minimapDiameters.outdoor
    local diameter = scales[zoom]
    return diameter and diameter / 2
end

function Compat.IsMinimapRotationIgnored()
    return C_Minimap and C_Minimap.IsRotateMinimapIgnored and C_Minimap.IsRotateMinimapIgnored() or false
end
