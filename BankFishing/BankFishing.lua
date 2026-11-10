local addonName, addon = ...
local displayName = "Bait to Plate"
local logoTexture = "Interface\\AddOns\\BankFishing\\Logo.tga"
local binding = "CLICK BankFishingCastButton:LeftButton"
addon.binding = binding
local fishingSpellID = 7620
_G["BINDING_NAME_" .. binding] = displayName .. ": Cast / Reel In"

local castButton = CreateFrame("Button", "BankFishingCastButton", UIParent, "SecureActionButtonTemplate")
castButton:SetSize(1, 1)
castButton:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, -1)
castButton:EnableMouse(false)
castButton:RegisterForClicks("AnyUp", "AnyDown")
castButton:SetAttribute("type", "spell")
castButton:SetAttribute("useOnKeyDown", false)

local events = CreateFrame("Frame")
local fishingName
local interactKeys = {}
local waitingForRelease = false
local fishingEnabled = true
local uiState
local restorePending = false

local function SavePosition(frame, key)
    frame:StopMovingOrSizing()
    local x, y = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if uiState and x and y and parentX and parentY then
        uiState[key] = { x = x - parentX, y = y - parentY }
    end
end

local function RestorePosition(frame, position)
    if type(position) == "table" and type(position.x) == "number" and type(position.y) == "number" then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", position.x, position.y)
    end
end

local function UpdateInteractBindings(isFishing)
    if InCombatLockdown() then
        return
    end

    local keys = isFishing and { GetBindingKey(binding) } or {}
    local changed = #keys ~= #interactKeys
    for index, key in ipairs(keys) do
        changed = changed or key ~= interactKeys[index]
    end
    if not changed then
        return
    end

    interactKeys = keys
    ClearOverrideBindings(events)
    for _, key in ipairs(keys) do
        SetOverrideBinding(events, false, key, "INTERACTTARGET")
    end
end

local function IsFishing()
    local name = UnitChannelInfo("player")
    return not issecretvalue(name) and name ~= nil and name == fishingName
end

local fishingButton = CreateFrame("Button", "BankFishingScreenButton", UIParent,
    "SecureActionButtonTemplate,UIPanelButtonTemplate")
fishingButton:SetPoint("CENTER", UIParent, "CENTER", 215, -130)
fishingButton:SetSize(132, 32)
fishingButton:SetText("Cast Fishing")
fishingButton:RegisterForClicks("LeftButtonUp")
fishingButton:SetAttribute("useOnKeyDown", false)
fishingButton:SetMovable(true)
fishingButton:SetClampedToScreen(true)
fishingButton:SetDontSavePosition(true)
fishingButton:RegisterForDrag("RightButton")
fishingButton:SetScript("OnDragStart", function(self)
    if not InCombatLockdown() then
        self:StartMoving()
    end
end)
fishingButton:SetScript("OnDragStop", function(self)
    SavePosition(self, "fishingButton")
end)

local function GetNativeInteractName()
    local frame = GamepadMainActionBarFrame
    local bars = frame and frame.PageUnit and frame.PageUnit.actionBars
    local right = bars and bars.topBar and bars.topBar.Right
    local button = right and right.ActionButton1
    local aspect = Enum.ForbiddenAspect and Enum.ForbiddenAspect.ScriptedInput
    if not button or button:IsForbidden() or not aspect
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

local function CanReachBobber()
    local guid = UnitGUID("softinteract")
    if issecretvalue(guid) or not guid
        or guid:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)%-") ~= "35591" then
        return false
    end
    local inRange = UnitIsInInteractRange("softinteract")
    return not issecretvalue(inRange) and inRange == true
end

local function EnableInteractKey()
    local setting = Settings.GetSetting("PROXY_ENABLE_INTERACT")
    if setting and not setting:GetValue() then
        -- Use the same setting as the checkbox in WoW's Controls menu.
        setting:SetValue(true, true)
    end
    return setting and setting:GetValue()
end

local function ShowFishingError(message)
    UIErrorsFrame:AddMessage(displayName .. ": " .. message, 1, 0.82, 0)
end

fishingButton:SetScript("PreClick", function(self)
    if not fishingEnabled or InCombatLockdown() then
        return
    end

    self:SetAttribute("type", nil)
    local interactEnabled = EnableInteractKey()
    if not IsFishing() then
        if fishingName then
            self:SetAttribute("spell", fishingName)
            self:SetAttribute("type", "spell")
        end
        return
    end

    if not interactEnabled then
        ShowFishingError("Enable Interact Key in Options > Gameplay > Controls.")
        return
    end

    local interactName = GetNativeInteractName()
    if not interactName then
        ShowFishingError("WoW's Interact button is unavailable. Right-click the bobber.")
        return
    end
    if not CanReachBobber() or C_PetInfo.IsPetOrderMoveToPending() then
        ShowFishingError("No in-range bobber selected. Face it or right-click it to reel in.")
        return
    end

    -- Blizzard's Interact button handles a down/up pair as one tap.
    local tap = "/click " .. interactName .. " LeftButton "
    self:SetAttribute("macrotext", "/stopmacro [combat]\n" .. tap .. "1\n" .. tap .. "0")
    self:SetAttribute("type", "macro")
end)

function addon.ToggleFishingButton()
    if fishingEnabled and not InCombatLockdown() then
        fishingButton:SetShown(not fishingButton:IsShown())
    end
end

local interactRangeCVar = "SoftTargetInteractRange"
local temporaryRange
local function UpdateInteractRange(isFishing)
    local range = tonumber(C_CVar.GetCVar(interactRangeCVar))
    if isFishing then
        if not temporaryRange and range and range < 60
            and pcall(C_CVar.SetTempCVar, interactRangeCVar, "60") then
            temporaryRange = tonumber(C_CVar.GetCVar(interactRangeCVar))
        end
    elseif temporaryRange then
        local applied = temporaryRange
        temporaryRange = nil
        if range == applied then
            C_CVar.RemoveTempCVar(interactRangeCVar)
        end
    end
end

local function SyncBindings()
    if not InCombatLockdown() then
        local isFishing = fishingEnabled and IsFishing()
        UpdateInteractRange(isFishing)
        fishingButton:SetText(isFishing and "Reel In" or "Cast Fishing")
        UpdateInteractBindings(isFishing)
    end
end

local function WaitForRelease()
    if not fishingEnabled then
        return
    end
    -- Reeling can end the channel on key down. Leave the Interact binding
    -- in place through key up so that release cannot also cast a new line.
    waitingForRelease = true
    events:SetScript("OnUpdate", function(self)
        for _, key in ipairs(interactKeys) do
            local input = key:gsub("ALT%-", ""):gsub("CTRL%-", ""):gsub("SHIFT%-", ""):gsub("META%-", "")
            if IsKeyDown(input, true) then
                return
            end
        end
        self:SetScript("OnUpdate", nil)
        waitingForRelease = false
        SyncBindings()
    end)
end

events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGOUT" or event == "PLAYER_REGEN_DISABLED" then
        UpdateInteractRange(false)
        return
    end
    if event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        WaitForRelease()
        return
    end

    if InCombatLockdown() then
        return
    end

    if event == "PLAYER_LOGIN" or event == "SPELLS_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
        local name = C_Spell.GetSpellName(fishingSpellID)
        if name and name ~= fishingName then
            fishingName = name
            castButton:SetAttribute("spell", name)
        end
    end

    if restorePending and (event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED") then
        addon.RestoreUIState()
    end

    if not waitingForRelease then
        SyncBindings()
    end
end)

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("UPDATE_BINDINGS")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")

-- Catch stats window
do
    local stats = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    stats:SetPoint("CENTER", UIParent, "CENTER", 425, -145)
    stats:SetSize(332, 380)
    stats:SetFrameStrata("MEDIUM")
    stats:SetClampedToScreen(true)
    stats:SetMovable(true)
    stats:SetDontSavePosition(true)
    stats:EnableMouse(true)
    stats:RegisterForDrag("LeftButton")
    stats:SetScript("OnDragStart", stats.StartMoving)
    stats:SetScript("OnDragStop", function(self)
        SavePosition(self, "statsWindow")
    end)
    stats:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    stats:SetBackdropColor(0.035, 0.065, 0.085, 0.98)
    stats:SetBackdropBorderColor(0.30, 0.51, 0.54)

    local close = CreateFrame("Button", nil, stats, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 1, 1)
    close:SetScript("OnClick", function()
        stats:Hide()
    end)

    local function MakeLine(parent, font, x, y, width)
        local line = parent:CreateFontString(nil, "ARTWORK", font)
        line:SetPoint("TOPLEFT", x, y)
        line:SetWidth(width)
        line:SetWordWrap(false)
        line:SetJustifyH("LEFT")
        return line
    end

    local function MakeFill(parent, x, y, width, height, r, g, b, alpha)
        local fill = parent:CreateTexture(nil, "BACKGROUND")
        fill:SetPoint("TOPLEFT", x, y)
        fill:SetSize(width, height)
        fill:SetColorTexture(r, g, b, alpha)
        return fill
    end

    local function MakeIcon(parent, x, y, size, file)
        local icon = parent:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", x, y)
        icon:SetSize(size, size)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icon:SetTexture(file)
        return icon
    end

    local function MakeSection()
        local section = CreateFrame("Frame", nil, stats)
        section:SetAllPoints(stats)
        return section
    end

    MakeIcon(stats, 15, -13, 35, logoTexture)
    MakeLine(stats, "GameFontNormalLarge", 59, -13, 229):SetText(displayName)
    local subtitle = MakeLine(stats, "GameFontHighlightSmall", 59, -35, 225)
    subtitle:SetTextColor(0.65, 0.80, 0.81)
    subtitle:SetText("Catch journal & cooking guide")
    MakeFill(stats, 14, -56, 304, 1, 0.40, 0.66, 0.65, 0.55)

    local dashboard = MakeSection()
    local function MakeMetric(x, label)
        MakeFill(dashboard, x, -96, 147, 54, 0.10, 0.22, 0.26, 1)
        MakeFill(dashboard, x, -96, 2, 54, 0.38, 0.78, 0.68, 1)
        local caption = MakeLine(dashboard, "GameFontHighlightSmall", x + 11, -104, 130)
        caption:SetTextColor(0.69, 0.84, 0.84)
        caption:SetText(label)
        return MakeLine(dashboard, "GameFontNormalLarge", x + 11, -122, 130)
    end

    local totalMetric = MakeMetric(14, "FISH & OTHER CATCHES")
    local typesMetric = MakeMetric(171, "CATCH TYPES")
    local function MakeCatchLine(y, label)
        local icon = MakeIcon(dashboard, 16, y, 21)
        local caption = MakeLine(dashboard, "GameFontNormalSmall", 44, y - 5, 57)
        caption:SetText(label)
        local value = MakeLine(dashboard, "GameFontHighlight", 101, y - 4, 215)
        return { icon = icon, value = value }
    end
    local latest = MakeCatchLine(-163, "Latest")
    local first = MakeCatchLine(-190, "First")
    MakeFill(dashboard, 14, -221, 304, 1, 0.40, 0.66, 0.65, 0.40)
    MakeLine(dashboard, "GameFontNormalSmall", 15, -231, 250):SetText("TOP CATCHES")

    local rows = {}
    for index = 1, 5 do
        local y = -248 - (index - 1) * 20
        local row = CreateFrame("Frame", nil, dashboard)
        row:SetPoint("TOPLEFT", 14, y)
        row:SetSize(304, 19)
        MakeFill(row, 0, 0, 304, 19, 0.09, 0.17, 0.21, 1)
        local bar = MakeFill(row, 0, 0, 1, 19, 0.15, 0.34, 0.36, 0.95)
        local quantity = MakeLine(row, "GameFontHighlightSmall", 261, -4, 34)
        quantity:SetJustifyH("RIGHT")
        rows[index] = {
            frame = row, bar = bar, quantity = quantity,
            icon = MakeIcon(row, 4, -2, 15),
            name = MakeLine(row, "GameFontHighlightSmall", 26, -4, 228),
        }
    end
    local empty = MakeLine(dashboard, "GameFontHighlightSmall", 15, -254, 302)
    empty:SetText("Loot a catch to start filling the journal.")
    local footer = MakeLine(dashboard, "GameFontDisableSmall", 15, -354, 302)

    local cooking = MakeSection()
    cooking:Hide()
    local cookingSummary = MakeLine(cooking, "GameFontNormal", 15, -98, 299)
    local cookingHint = MakeLine(cooking, "GameFontHighlightSmall", 15, -120, 302)
    cookingHint:SetWordWrap(true)

    -- Spell ID, minimum skill, name, recipe item, primary catch, and extra reagents.
    -- Reagents are item ID followed by the quantity required per craft.
    local recipes = {
        { 7751, 1, "Brilliant Smallfish", 6325, 6291 },
        { 7752, 1, "Slitherskin Mackerel", 6326, 6303 },
        { 7753, 50, "Longjaw Mud Snapper", 6328, 6289 },
        { 6415, 50, "Fillet of Frenzy", 5485, 5468, { { 2678, 1 } } },
        { 7754, 50, "Loch Frenzy Delight", 6329, 6317, { { 2678, 1 } } },
        { 7827, 50, "Rainbow Fin Albacore", 6368, 6361 },
        { 25704, 80, "Smoked Sagefish", 21099, 21071, { { 2678, 1 } } },
        { 8238, 85, "Savory Deviate Delight", 6661, 6522, { { 2678, 1 } } },
        { 1252566, 85, "Savory Whimsyfin Delight", 251526, 251524, { { 2678, 1 } } },
        { 7755, 100, "Bristle Whisker Catfish", 6330, 6308 },
        { 20916, 175, "Mithril Headed Trout", 17062, 8365 },
        { 7828, 175, "Rockscale Cod", 6369, 6362 },
        { 25954, 175, "Sagefish Delight", 21219, 21153, { { 2692, 1 } } },
        { 1247741, 210, "Spinefin Halibut", nil, 8959 },
        { 18239, 225, "Cooked Glossy Mightfish", 13940, 13754, { { 3713, 1 } } },
        { 18241, 225, "Filet of Redgill", 13941, 13758 },
        { 1319313, 225, "Plated Armorfish", 286153, 13890, { { 3713, 1 } } },
        { 18238, 225, "Spotted Yellowtail", 13939, 4603 },
        { 18240, 240, "Grilled Squid", 13942, 13755, { { 3713, 1 } }, true },
        { 18242, 240, "Hot Smoked Bass", 13943, 13756, { { 2692, 2 } }, true },
        { 18243, 250, "Nightfin Soup", 13945, 13759, { { 159, 1 } } },
        { 18244, 250, "Poached Sunscale Salmon", 13946, 13760, nil, true },
        { 18247, 275, "Baked Salmon", 13949, 13889, { { 3713, 1 } }, true },
        { 18245, 275, "Lobster Stew", 13947, 13888, { { 159, 1 } }, true },
        { 18246, 275, "Mightfish Steak", 13948, 13893, { { 2692, 1 }, { 3713, 1 } } },
        { 470370, 300, "Smoked Redgill", 232443, 13758 },
        { 470359, 300, "Darkclaw Bisque", 232437, 13888, { { 227813, 1 } } },
    }
    local ingredientNames = {
        [159] = "Refreshing Spring Water", [2678] = "Mild Spices",
        [2692] = "Hot Spices", [3713] = "Soothing Spices",
        [4603] = "Raw Spotted Yellowtail", [6289] = "Raw Longjaw Mud Snapper",
        [5468] = "Soft Frenzy Flesh", [8959] = "Raw Spinefin Halibut",
        [6291] = "Raw Brilliant Smallfish", [6303] = "Raw Slitherskin Mackerel",
        [6308] = "Raw Bristle Whisker Catfish", [6317] = "Raw Loch Frenzy",
        [6361] = "Raw Rainbow Fin Albacore", [6362] = "Raw Rockscale Cod",
        [6522] = "Deviate Fish", [8365] = "Raw Mithril Head Trout",
        [13754] = "Raw Glossy Mightfish", [13755] = "Raw Winter Squid",
        [13756] = "Raw Summer Bass", [13758] = "Raw Redgill",
        [13759] = "Raw Nightfin Snapper", [13760] = "Raw Sunscale Salmon",
        [13888] = "Darkclaw Lobster", [13889] = "Raw Whitescale Salmon",
        [13890] = "Raw Plated Armorfish", [13893] = "Large Raw Mightfish",
        [21071] = "Raw Sagefish", [21153] = "Raw Greater Sagefish",
        [227813] = "Drinkable Stratholme Holy Water", [251524] = "Whimsyfin",
    }
    local recipeVendors = {
        [7751] = "Tharynn Bouden (Goldshire) or Sewa Mistrunner (Thunder Bluff)",
        [7753] = "Tharynn Bouden (Goldshire) or Naal Mistrunner (Thunder Bluff)",
        [7755] = "Catherine Leland (Stormwind) or Naal Mistrunner (Thunder Bluff)",
        [20916] = "Tansy Puddlefizz (Ironforge) or Shankys (Orgrimmar)",
        [18241] = "Kelsey Yance (Booty Bay)",
    }

    local function GetCookingSkill()
        local cookingIndex = select(5, GetProfessions())
        if cookingIndex then
            local _, _, skill, maximum = GetProfessionInfo(cookingIndex)
            return skill or 0, maximum or 0
        end
        local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(185)
        return info and info.skillLevel or 0, info and info.maxSkillLevel or 0
    end

    local function GetRecipeKnowledge()
        local guid = UnitGUID("player")
        if not BankFishingDB or issecretvalue(guid) or not guid then
            return
        end
        BankFishingDB.cookingKnown = BankFishingDB.cookingKnown or {}
        local known = BankFishingDB.cookingKnown[guid]
        if not known then
            known = {}
            BankFishingDB.cookingKnown[guid] = known
        end
        return known
    end

    local function ScanCookingRecipes()
        if not C_TradeSkillUI.IsTradeSkillReady() or C_TradeSkillUI.IsTradeSkillLinked()
            or C_TradeSkillUI.IsTradeSkillGuild() or C_TradeSkillUI.IsTradeSkillGuildMember()
            or C_TradeSkillUI.IsNPCCrafting() then
            return
        end
        local info = C_TradeSkillUI.GetBaseProfessionInfo()
        if not info or info.professionID ~= 185 then
            return
        end
        local known = GetRecipeKnowledge()
        if not known then
            return
        end
        for _, recipe in ipairs(recipes) do
            local id = recipe[1]
            local recipeInfo = C_TradeSkillUI.GetRecipeInfo(id)
            if recipeInfo and type(recipeInfo.learned) == "boolean" then
                known[id] = recipeInfo.learned
                known.checked = true
            end
        end
    end

    local function TooltipSection(title)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(title, 0.70, 0.88, 0.85)
    end

    local function ShowRecipeTooltip(row)
        local entry = row.entry
        if not entry then
            return
        end
        GameTooltip:SetOwner(row, "ANCHOR_LEFT")
        GameTooltip:SetText(entry.name)
        TooltipSection("Requirements")
        GameTooltip:AddDoubleLine("Cooking skill", tostring(entry.skill), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Station", entry.station, 1, 1, 1, 1, 1, 1)
        local recipeStatus
        if entry.known == nil then
            recipeStatus = "Open Cooking to check"
        elseif entry.known then
            recipeStatus = "Learned"
        elseif entry.hasScroll then
            recipeStatus = "Scroll in your bags"
        else
            recipeStatus = entry.scroll and "Missing recipe" or "Visit a trainer"
        end
        GameTooltip:AddDoubleLine("Recipe", recipeStatus, 1, 1, 1, 1, 0.80, 0.43)

        TooltipSection("Ingredients per craft")
        GameTooltip:AddDoubleLine("Ingredient", "In bags / Needed", 0.70, 0.74, 0.74, 0.70, 0.74, 0.74)
        for _, item in ipairs(entry.ingredients) do
            local name = C_Item.GetItemNameByID(item.id) or ingredientNames[item.id]
            local quantity = ("%d / %d"):format(item.have, item.need)
            local missing = item.need - item.have
            if missing > 0 then
                GameTooltip:AddDoubleLine(name, quantity .. ("  (need %d more)"):format(missing), 1, 1, 1, 1, 0.58, 0.40)
            else
                GameTooltip:AddDoubleLine(name, quantity, 1, 1, 1, 0.58, 0.88, 0.71)
            end
        end
        local vendor = entry.known == false and not entry.hasScroll and recipeVendors[entry.id]
        if vendor then
            TooltipSection("Where to get the recipe")
            GameTooltip:AddLine(vendor, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end

    local cookingRows = {}
    for index = 1, 5 do
        local row = CreateFrame("Frame", nil, cooking)
        row:SetPoint("TOPLEFT", 14, -148 - (index - 1) * 38)
        row:SetSize(304, 36)
        row:EnableMouse(true)
        MakeFill(row, 0, 0, 304, 36, 0.10, 0.19, 0.23, 1)
        row.icon = MakeIcon(row, 6, -6, 24)
        row.name = MakeLine(row, "GameFontHighlight", 37, -4, 258)
        row.status = MakeLine(row, "GameFontHighlightSmall", 37, -20, 258)
        row:SetScript("OnEnter", ShowRecipeTooltip)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        cookingRows[index] = row
    end

    local previous = CreateFrame("Button", nil, cooking, "UIPanelButtonTemplate")
    previous:SetPoint("TOPLEFT", 14, -347)
    previous:SetSize(60, 22)
    previous:SetText("Prev")
    local nextPage = CreateFrame("Button", nil, cooking, "UIPanelButtonTemplate")
    nextPage:SetPoint("TOPLEFT", 79, -347)
    nextPage:SetSize(60, 22)
    nextPage:SetText("Next")
    local pageText = MakeLine(cooking, "GameFontHighlightSmall", 146, -354, 54)
    local openCooking = CreateFrame("Button", nil, cooking, "UIPanelButtonTemplate")
    openCooking:SetPoint("TOPLEFT", 204, -347)
    openCooking:SetSize(114, 22)
    openCooking:SetText("Open Cooking")
    openCooking:SetScript("OnClick", function()
        C_TradeSkillUI.OpenTradeSkill(185)
    end)
    openCooking:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Open Cooking")
        GameTooltip:AddLine("Opens WoW's Cooking window and checks your recipes.", 1, 1, 1, true)
        TooltipSection("Cooking basics")
        GameTooltip:AddLine("Craft near the station shown on the recipe.", 1, 1, 1, true)
        GameTooltip:AddLine("Starter foods: Charred Wolf Meat and Herb Baked Egg.", 1, 1, 1, true)
        GameTooltip:AddLine("Check finished food for level and Well Fed effects.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    openCooking:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local page = 1
    local function RefreshCooking()
        local skill, maximum = GetCookingSkill()
        local known = GetRecipeKnowledge() or {}
        local available = {}
        local bagCounts = {}
        local ready = 0
        local function CountItem(itemID)
            if not bagCounts[itemID] then
                bagCounts[itemID] = C_Item.GetItemCount(itemID, false, false, false, false)
            end
            return bagCounts[itemID]
        end
        for _, recipe in ipairs(recipes) do
            local id, required, name, scroll, fish, extras, oven = unpack(recipe, 1, 7)
            local learned = known[id]
            if learned == nil and C_SpellBook.IsSpellKnown(id) then
                learned = true
            end
            local fishCount = CountItem(fish)
            local ingredients = { { id = fish, have = fishCount, need = 1 } }
            local portions = fishCount
            for _, reagent in ipairs(extras or {}) do
                local itemID, amount = unpack(reagent)
                local have = CountItem(itemID)
                ingredients[#ingredients + 1] = { id = itemID, have = have, need = amount }
                portions = math.min(portions, math.floor(have / amount))
            end
            local canCook = learned == true and skill >= required and portions > 0
            if canCook then
                ready = ready + 1
            end
            available[#available + 1] = {
                id = id, skill = required, name = name, fish = fish, fishCount = fishCount,
                ingredients = ingredients, portions = portions, canCook = canCook, known = learned,
                scroll = scroll, hasScroll = learned ~= true and scroll and CountItem(scroll) > 0,
                station = oven and "an Iron Oven" or "a cooking fire",
            }
        end
        table.sort(available, function(a, b)
            if a.canCook ~= b.canCook then
                return a.canCook
            end
            if (a.fishCount > 0) ~= (b.fishCount > 0) then
                return a.fishCount > 0
            end
            if a.skill ~= b.skill then
                return a.skill < b.skill
            end
            return a.name < b.name
        end)

        cookingSummary:SetText(skill > 0 and ("Cooking %d / %d  |  %d ready"):format(skill, maximum, ready)
            or "Cooking untrained")
        if skill == 0 then
            cookingHint:SetText("Learn Cooking from a trainer to get started.")
        elseif not known.checked then
            cookingHint:SetText("Open Cooking to check your learned recipes.")
        else
            cookingHint:SetText("Hover a recipe for ingredients and requirements.")
        end
        openCooking:SetEnabled(skill > 0)
        local pages = math.ceil(#available / #cookingRows)
        page = math.min(math.max(1, page), pages)
        previous:SetEnabled(page > 1)
        nextPage:SetEnabled(page < pages)
        pageText:SetText(("%d / %d"):format(page, pages))

        for index, row in ipairs(cookingRows) do
            local entry = available[(page - 1) * #cookingRows + index]
            row.entry = entry
            row:SetShown(entry ~= nil)
            if entry then
                row.icon:SetTexture(C_Item.GetItemIconByID(entry.fish) or 134400)
                row.name:SetText(entry.name)
                if entry.canCook then
                    row.status:SetText(("Can make %d"):format(entry.portions))
                    row.status:SetTextColor(0.54, 0.92, 0.69)
                else
                    local status
                    if skill < entry.skill then
                        status = "Needs Cooking " .. entry.skill
                    elseif entry.known ~= true then
                        status = entry.hasScroll and "Recipe in bags"
                            or (entry.known == false and (entry.scroll and "Recipe missing" or "Visit trainer")
                                or "Check recipe")
                    else
                        status = entry.fishCount == 0 and "No fish in bags" or "Missing ingredients"
                    end
                    row.status:SetText(status)
                    row.status:SetTextColor(1, 0.78, 0.47)
                end
            end
        end
    end

    previous:SetScript("OnClick", function()
        page = page - 1
        RefreshCooking()
    end)
    nextPage:SetScript("OnClick", function()
        page = page + 1
        RefreshCooking()
    end)
    cooking:SetScript("OnShow", function()
        page = 1
        ScanCookingRecipes()
        RefreshCooking()
    end)
    cooking:RegisterEvent("BAG_UPDATE_DELAYED")
    cooking:RegisterEvent("SKILL_LINES_CHANGED")
    cooking:RegisterEvent("NEW_RECIPE_LEARNED")
    cooking:RegisterEvent("TRADE_SKILL_SHOW")
    cooking:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
    cooking:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
    cooking:SetScript("OnEvent", function(self, event, recipeID)
        if event == "NEW_RECIPE_LEARNED" then
            local known = GetRecipeKnowledge()
            if known and recipeID and not issecretvalue(recipeID) then
                for _, recipe in ipairs(recipes) do
                    if recipe[1] == recipeID then
                        known[recipeID] = true
                        break
                    end
                end
            end
        elseif event ~= "BAG_UPDATE_DELAYED" and event ~= "SKILL_LINES_CHANGED" then
            ScanCookingRecipes()
        end
        if self:IsVisible() then
            RefreshCooking()
        end
    end)


    local pending = {}
    local session = { items = {}, total = 0 }
    local history = { items = {}, total = 0 }
    local showingHistory = false

    local function RefreshStats()
        local view = showingHistory and history or session
        local ranked = {}
        for id, item in pairs(view.items) do
            ranked[#ranked + 1] = { id = id, name = item.name, total = item.total, icon = item.icon }
        end
        table.sort(ranked, function(a, b)
            if a.total == b.total then
                return a.name < b.name
            end
            return a.total > b.total
        end)

        local function ShowCatch(line, entry)
            line.icon:SetShown(entry ~= nil)
            if entry then
                line.icon:SetTexture(entry.icon or C_Item.GetItemIconByID(tonumber(entry.id)) or 134400)
                line.value:SetText(entry.quantity .. " x " .. entry.name)
            else
                line.value:SetText("No catch yet")
            end
        end
        totalMetric:SetText(tostring(view.total))
        typesMetric:SetText(tostring(#ranked))
        ShowCatch(latest, view.latest)
        ShowCatch(first, view.first)
        empty:SetShown(#ranked == 0)
        for index, row in ipairs(rows) do
            local item = ranked[index]
            row.frame:SetShown(item ~= nil)
            if item then
                row.icon:SetTexture(item.icon or C_Item.GetItemIconByID(tonumber(item.id)) or 134400)
                row.name:SetText(item.name)
                row.quantity:SetText(tostring(item.total))
                row.bar:SetWidth(math.max(1, 304 * item.total / ranked[1].total))
            end
        end
        local others = #ranked - #rows
        local period = showingHistory and "Saved across sessions" or "Session starts on reload or login"
        footer:SetText(others > 0 and ("+" .. others .. " other item types") or period)
    end

    local tabs = {}
    for index, label in ipairs({ "Session", "All-Time", "Cooking" }) do
        local tab = CreateFrame("Button", nil, stats, "UIPanelButtonTemplate")
        tab:SetPoint("TOPLEFT", 14 + (index - 1) * 103, -63)
        tab:SetSize(98, 23)
        tab:SetText(label)
        tab:SetScript("OnClick", function()
            for buttonIndex, button in ipairs(tabs) do
                button:SetEnabled(buttonIndex ~= index)
            end
            showingHistory = index == 2
            dashboard:SetShown(index ~= 3)
            cooking:SetShown(index == 3)
            RefreshStats()
        end)
        tabs[index] = tab
    end
    tabs[1]:Disable()

    local function SnapshotFishingLoot()
        local fishingLoot = IsFishingLoot()
        if issecretvalue(fishingLoot) or not fishingLoot then
            return
        end
        local count = GetNumLootItems()
        if issecretvalue(count) then
            return
        end
        for slot = 1, count do
            local link = GetLootSlotLink(slot)
            local id = not issecretvalue(link) and link and link:match("|Hitem:(%d+)")
            if id and pending[slot] ~= false then
                local icon, name, quantity = GetLootSlotInfo(slot)
                if not issecretvalue(name) and name and not issecretvalue(quantity) and quantity and quantity > 0 then
                    local safeIcon = not issecretvalue(icon) and type(icon) == "number" and icon or nil
                    pending[slot] = { id = id, name = name, quantity = quantity, icon = safeIcon }
                end
            end
        end
    end

    local function RecordCatch(view, entry)
        local item = view.items[entry.id]
        if not item then
            item = { name = entry.name, total = 0, icon = entry.icon }
            view.items[entry.id] = item
        end
        item.total = item.total + entry.quantity
        view.total = view.total + entry.quantity
        view.first = view.first or entry
        view.latest = entry
    end

    stats:RegisterEvent("ADDON_LOADED")
    stats:RegisterEvent("LOOT_READY")
    stats:RegisterEvent("LOOT_OPENED")
    stats:RegisterEvent("LOOT_SLOT_CLEARED")
    stats:RegisterEvent("LOOT_CLOSED")
    stats:SetScript("OnEvent", function(_, event, slot)
        if event == "ADDON_LOADED" then
            if slot == addonName then
                if type(BankFishingDB) == "table" and type(BankFishingDB.items) == "table"
                    and type(BankFishingDB.total) == "number" then
                    history = BankFishingDB
                else
                    BankFishingDB = history
                end
                if type(history.ui) ~= "table" then
                    history.ui = {}
                end
                uiState = history.ui
                restorePending = true
                stats:UnregisterEvent("ADDON_LOADED")
                RefreshStats()
            end
        elseif not fishingEnabled then
            return
        elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
            SnapshotFishingLoot()
        elseif event == "LOOT_CLOSED" then
            pending = {}
        else
            if issecretvalue(slot) then
                return
            end
            local entry = pending[slot]
            if not entry then
                return
            end
            pending[slot] = false
            RecordCatch(session, entry)
            RecordCatch(history, entry)
            RefreshStats()
        end
    end)

    function addon.ToggleStats()
        if fishingEnabled then
            stats:SetShown(not stats:IsShown())
        end
    end

    function addon.ShowCatchStats(enabled)
        pending = {}
        stats:SetShown(enabled)
    end

    function addon.RestoreStatsPosition()
        RestorePosition(stats, uiState.statsWindow)
    end

    RefreshStats()
end

local minimapButton = CreateFrame("Button", "BankFishingMinimapButton", Minimap)
minimapButton:SetSize(31, 31)
minimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 8)
minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapButton:RegisterForDrag("RightButton")
minimapButton:SetNormalTexture(logoTexture)
local minimapIcon = minimapButton:GetNormalTexture()
minimapIcon:ClearAllPoints()
minimapIcon:SetPoint("CENTER")
minimapIcon:SetSize(18, 18)
minimapIcon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
local minimapBackground = minimapButton:CreateTexture(nil, "BACKGROUND")
minimapBackground:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
minimapBackground:SetSize(24, 24)
minimapBackground:SetPoint("CENTER")
local minimapBorder = minimapButton:CreateTexture(nil, "OVERLAY")
minimapBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
minimapBorder:SetSize(50, 50)
minimapBorder:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local defaultMinimapAngle = math.rad(225)
local function PositionMinimapButton(angle)
    local iconLibrary = LibStub and LibStub("LibDBIcon-1.0", true)
    local inset = iconLibrary and iconLibrary.radius or 5
    local xRadius = Minimap:GetWidth() / 2 + inset
    local yRadius = Minimap:GetHeight() / 2 + inset
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", xRadius * math.cos(angle), yRadius * math.sin(angle))
end

PositionMinimapButton(defaultMinimapAngle)

local function UpdateMinimapDrag()
    local x, y = GetCursorPosition()
    local centerX, centerY = Minimap:GetCenter()
    if not centerX or not centerY then
        return
    end
    local scale = Minimap:GetEffectiveScale()
    local angle = math.atan2(y / scale - centerY, x / scale - centerX)
    PositionMinimapButton(angle)
    if uiState then
        uiState.minimapAngle = angle
    end
end

local draggedMinimapButton = false
minimapButton:SetScript("OnMouseDown", function(_, button)
    if button == "RightButton" then
        draggedMinimapButton = false
    end
end)

minimapButton:SetScript("OnDragStart", function(self)
    draggedMinimapButton = true
    GameTooltip:Hide()
    self:SetScript("OnUpdate", UpdateMinimapDrag)
end)

minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    UpdateMinimapDrag()
end)

local function SetFishingEnabled(enabled)
    fishingEnabled = enabled
    waitingForRelease = false
    events:SetScript("OnUpdate", nil)
    castButton:SetAttribute("type", fishingEnabled and "spell" or nil)
    fishingButton:SetShown(fishingEnabled)
    addon.ShowCatchStats(fishingEnabled)
    minimapIcon:SetDesaturated(not fishingEnabled)
    SyncBindings()
end

function addon.RestoreUIState()
    restorePending = false
    RestorePosition(fishingButton, uiState.fishingButton)
    addon.RestoreStatsPosition()
    local angle = type(uiState.minimapAngle) == "number" and uiState.minimapAngle or defaultMinimapAngle
    PositionMinimapButton(angle)
    SetFishingEnabled(uiState.enabled ~= false)
end

minimapButton:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
        if not draggedMinimapButton then
            addon.OpenSettings()
        end
        return
    end
    if InCombatLockdown() then
        ShowFishingError("You can toggle the addon after combat.")
        return
    end
    local enabled = not fishingEnabled
    if uiState then
        uiState.enabled = enabled
    end
    SetFishingEnabled(enabled)
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(displayName)
    GameTooltip:AddLine(fishingEnabled and "Left-click to hide" or "Left-click to show", 1, 1, 1)
    GameTooltip:AddLine("Right-click for settings", 1, 1, 1)
    GameTooltip:AddLine("Right-drag to move", 1, 1, 1)
    GameTooltip:Show()
end)
minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Add-on settings panel
local panel = CreateFrame("Frame")
panel:Hide()

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -18)
title:SetText(displayName)

local instructions = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
instructions:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
instructions:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
instructions:SetJustifyH("LEFT")
instructions:SetText("Equip a fishing pole and face the water. Click Cast Fishing, then click Reel In after the splash. The button enables WoW's Interact Key when used. Right-drag it to move it.")

local bindingText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
bindingText:SetPoint("TOPLEFT", instructions, "BOTTOMLEFT", 0, -24)

local keybindings = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
keybindings:SetPoint("TOPLEFT", bindingText, "BOTTOMLEFT", 0, -8)
keybindings:SetSize(160, 24)
keybindings:SetText("Open Keybindings")
keybindings:SetScript("OnClick", function()
    Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID)
end)

local bindingHint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
bindingHint:SetPoint("TOPLEFT", keybindings, "BOTTOMLEFT", 0, -8)
bindingHint:SetText("Under AddOns, look for " .. displayName .. ": Cast / Reel In.")

local function CreateSettingCheckbox(label, variable)
    local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    text:SetText(label)

    local function Refresh()
        local setting = Settings.GetSetting(variable)
        checkbox:SetEnabled(setting ~= nil)
        checkbox:SetChecked(setting and setting:GetValue() or false)
    end

    checkbox:SetScript("OnClick", function(self)
        local setting = Settings.GetSetting(variable)
        if setting then
            setting:SetValue(self:GetChecked())
        end
        Refresh()
    end)
    return checkbox, Refresh
end

local interact, RefreshInteract = CreateSettingCheckbox("Enable Interact Key (required)", "PROXY_ENABLE_INTERACT")
interact:SetPoint("TOPLEFT", bindingHint, "BOTTOMLEFT", -4, -17)
local autoLoot, RefreshAutoLoot = CreateSettingCheckbox("Auto Loot (optional)", "autoLootDefault")
autoLoot:SetPoint("TOPLEFT", interact, "BOTTOMLEFT", 0, -3)

local statsButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
statsButton:SetPoint("TOPLEFT", autoLoot, "BOTTOMLEFT", 4, -12)
statsButton:SetSize(160, 24)
statsButton:SetText("Toggle Catch Stats")
statsButton:SetScript("OnClick", addon.ToggleStats)

local function Refresh()
    local keys = { GetBindingKey(addon.binding) }
    local display = #keys > 0 and table.concat(keys, " / ") or "Unassigned"
    bindingText:SetText("Current binding: " .. display)
    RefreshInteract()
    RefreshAutoLoot()
end

panel:SetScript("OnShow", Refresh)
panel:RegisterEvent("UPDATE_BINDINGS")
panel:RegisterEvent("CVAR_UPDATE")
panel:SetScript("OnEvent", function(self)
    if self:IsVisible() then
        Refresh()
    end
end)

local category = Settings.RegisterCanvasLayoutCategory(panel, displayName)
Settings.RegisterAddOnCategory(category)
function addon.OpenSettings()
    Settings.OpenToCategory(category:GetID())
end
SLASH_BANKFISHING1 = "/bankfishing"
SLASH_BANKFISHING2 = "/reelandrecord"
SLASH_BANKFISHING3 = "/baittoplate"
SlashCmdList.BANKFISHING = function(message)
    if message == "button" then
        addon.ToggleFishingButton()
        return
    end
    if message == "stats" then
        addon.ToggleStats()
        return
    end
    addon.OpenSettings()
end
