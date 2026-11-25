local addonName, addon = ...
local displayName = "Bait to Plate"
local compat = addon.Compat
local issecretvalue = compat.IsSecret
local C_Item = compat.Item
local logoTexture = "Interface\\AddOns\\BankFishing\\Logo.tga"
local binding = "CLICK BankFishingCastButton:LeftButton"
addon.binding = binding
local fishingSpellID = 7620
local mainHandSlot = 16
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
local fishingButtonHidden = false
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

local function FishingPoleEquipped()
    return compat.FishingPoleEquipped()
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
fishingButton:Hide()

local function RefreshFishingButton()
    local poleEquipped = compat.CanShowFishingControls()
    if not InCombatLockdown() then
        fishingButton:SetShown(fishingEnabled and not fishingButtonHidden and poleEquipped)
    end
    addon.SetPoolPinsEnabled(compat.supportsPoolData and fishingEnabled and uiState ~= nil and uiState.enabled ~= false
        and uiState.showFishingPools ~= false and poleEquipped)
end

local function GetNativeInteractName()
    return compat.GetNativeInteractName()
end

local function CanReachBobber()
    return compat.CanReachBobber()
end

local function EnableInteractKey()
    return compat.EnableInteractKey()
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
        ShowFishingError("Press your bound Cast / Reel In key or right-click the bobber.")
        return
    end
    if not CanReachBobber() or (C_PetInfo and C_PetInfo.IsPetOrderMoveToPending and C_PetInfo.IsPetOrderMoveToPending()) then
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
        fishingButtonHidden = not fishingButtonHidden
        RefreshFishingButton()
    end
end

local function UpdateInteractRange(isFishing)
    compat.UpdateInteractRange(isFishing)
end

local function SyncBindings()
    local isFishing = fishingEnabled and IsFishing()
    addon.UpdateFishingAudio(isFishing)
    if not InCombatLockdown() then
        if isFishing then
            EnableInteractKey()
        end
        UpdateInteractRange(isFishing)
        local reelLabel = compat.isForever and "Reel In" or "Use bound key"
        fishingButton:SetText(isFishing and reelLabel or "Cast Fishing")
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

events:SetScript("OnEvent", function(_, event, slot)
    if event == "PLAYER_LOGOUT" or event == "PLAYER_REGEN_DISABLED" then
        UpdateInteractRange(false)
        return
    end
    if event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        WaitForRelease()
        return
    end

    if event == "PLAYER_EQUIPMENT_CHANGED" then
        if slot == mainHandSlot or compat.isRetail then
            RefreshFishingButton()
        end
        return
    end

    if InCombatLockdown() then
        return
    end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED"
        or event == "SPELLS_CHANGED" or event == "SKILL_LINES_CHANGED" then
        RefreshFishingButton()
    end

    if event == "PLAYER_LOGIN" or event == "SPELLS_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
        local name = compat.GetSpellName(fishingSpellID)
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
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:RegisterEvent("UPDATE_BINDINGS")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")

-- Catch stats window
do
    local stats = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    stats:Hide()
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

    local recipes = addon.CookingRecipes
    local ingredientNames = addon.CookingIngredientNames
    local recipeSources = addon.CookingRecipeSources

    local function GetCookingSkill()
        return compat.GetCookingSkill()
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
        local known = GetRecipeKnowledge()
        if known then
            compat.ScanCookingRecipes(recipes, known)
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
        local sources = recipeSources[entry.id]
        if sources then
            TooltipSection("Where to get the recipe")
            for _, source in ipairs(sources) do
                GameTooltip:AddLine(source, 1, 1, 1, true)
            end
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
    local openCooking = CreateFrame("Button", nil, cooking, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    openCooking:SetPoint("TOPLEFT", 204, -347)
    openCooking:SetSize(114, 22)
    openCooking:SetText("Open Cooking")
    openCooking:RegisterForClicks("LeftButtonUp")
    openCooking:SetAttribute("useOnKeyDown", false)
    compat.ConfigureCookingButton(openCooking)
    openCooking:SetScript("PostClick", function()
        compat.OpenCooking()
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
            if learned == nil and compat.IsSpellKnown(id) then
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

        cookingSummary:SetText(skill > 0 and ("%s %d / %d  |  %d ready"):format(addon.CookingGuideName, skill, maximum, ready)
            or (addon.CookingGuideName .. " untrained"))
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

local function SetFishingEnabled(enabled, showStats)
    fishingEnabled = enabled
    addon.SetFishingAudioVolume(uiState and uiState.fishingSoundVolume)
    addon.SetFishingAudioEnabled(fishingEnabled and uiState ~= nil and uiState.boostFishingSound == true)
    waitingForRelease = false
    events:SetScript("OnUpdate", nil)
    castButton:SetAttribute("type", fishingEnabled and "spell" or nil)
    fishingButtonHidden = false
    RefreshFishingButton()
    addon.ShowCatchStats(fishingEnabled and showStats ~= false)
    minimapIcon:SetDesaturated(not fishingEnabled)
    SyncBindings()
end

function addon.RestoreUIState()
    restorePending = false
    RestorePosition(fishingButton, uiState.fishingButton)
    addon.RestoreStatsPosition()
    local angle = type(uiState.minimapAngle) == "number" and uiState.minimapAngle or defaultMinimapAngle
    PositionMinimapButton(angle)
    SetFishingEnabled(uiState.enabled ~= false, uiState.showStatsOnStartup == true)
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
instructions:SetText(compat.isForever
    and "Equip a fishing pole and face the water. Click Cast Fishing, then click Reel In after the splash. The button enables WoW's Interact Key when used. Right-drag it to move it."
    or "Face the water and click Cast Fishing. Bind Cast / Reel In to a key below, then press it after the splash to reel in and again to cast. Right-drag the button to move it.")

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
        local setting = Settings and Settings.GetSetting and Settings.GetSetting(variable)
        checkbox:SetEnabled(setting ~= nil)
        checkbox:SetChecked(setting and setting:GetValue() or false)
    end

    checkbox:SetScript("OnClick", function(self)
        local setting = Settings and Settings.GetSetting and Settings.GetSetting(variable)
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

local poolPins = CreateFrame("CheckButton", "BankFishingPoolPinsCheckbox", panel, "UICheckButtonTemplate")
poolPins:SetPoint("TOPLEFT", autoLoot, "BOTTOMLEFT", 0, -3)
local poolLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
poolLabel:SetPoint("LEFT", poolPins, "RIGHT", 4, 0)
poolLabel:SetText("Show fishing pools")
poolPins:SetScript("OnClick", function(self)
    if uiState then
        uiState.showFishingPools = self:GetChecked()
        RefreshFishingButton()
    end
end)
poolPins:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Fishing pool locations")
    GameTooltip:AddLine("Show known pool and wreckage locations while a fishing pole is equipped.", 1, 1, 1, true)
    GameTooltip:AddLine(compat.supportsPoolData and "A location can be empty when you visit."
        or "The included locations cover Forever and pre-Cataclysm Azeroth.", 0.7, 0.85, 0.83, true)
    GameTooltip:Show()
end)
poolPins:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local fishingAudio = CreateFrame("CheckButton", "BankFishingAudioCheckbox", panel, "UICheckButtonTemplate")
fishingAudio:SetPoint("TOPLEFT", poolPins, "BOTTOMLEFT", 0, -3)
local audioLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
audioLabel:SetPoint("LEFT", fishingAudio, "RIGHT", 4, 0)
audioLabel:SetText("Louder fishing splash")

local audioVolume = CreateFrame("Slider", "BankFishingAudioVolumeSlider", panel, "OptionsSliderTemplate")
audioVolume:SetPoint("TOPLEFT", fishingAudio, "BOTTOMLEFT", 8, -16)
audioVolume:SetSize(220, 16)
audioVolume:SetMinMaxValues(0, 100)
audioVolume:SetValueStep(5)
audioVolume:SetObeyStepOnDrag(true)
_G.BankFishingAudioVolumeSliderText:SetText("Fishing volume")
_G.BankFishingAudioVolumeSliderLow:SetText("0%")
_G.BankFishingAudioVolumeSliderHigh:SetText("100%")
local audioVolumeText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
audioVolumeText:SetPoint("LEFT", audioVolume, "RIGHT", 12, 0)
local refreshingAudioVolume = false

local function RefreshAudioVolume()
    local percent = addon.GetFishingAudioVolume() * 100
    refreshingAudioVolume = true
    audioVolume:SetValue(percent)
    refreshingAudioVolume = false
    audioVolumeText:SetText(("%d%%"):format(math.floor(percent + 0.5)))
    audioVolume:SetEnabled(uiState ~= nil and uiState.boostFishingSound == true)
end

audioVolume:SetScript("OnValueChanged", function(_, value)
    audioVolumeText:SetText(("%d%%"):format(math.floor(value + 0.5)))
    if not refreshingAudioVolume and uiState then
        uiState.fishingSoundVolume = value / 100
        addon.SetFishingAudioVolume(uiState.fishingSoundVolume)
    end
end)
fishingAudio:SetScript("OnClick", function(self)
    if uiState then
        uiState.boostFishingSound = self:GetChecked()
        addon.SetFishingAudioEnabled(fishingEnabled and uiState.boostFishingSound == true)
        addon.UpdateFishingAudio(fishingEnabled and IsFishing())
        RefreshAudioVolume()
    end
end)
fishingAudio:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Louder fishing splash")
    local percent = math.floor(addon.GetFishingAudioVolume() * 100 + 0.5)
    GameTooltip:AddLine(("Set Master and Effects volume to %d%% while fishing."):format(percent), 1, 1, 1, true)
    GameTooltip:AddLine("Mute music and ambience until fishing ends, then restore your sound settings.", 0.7, 0.85, 0.83, true)
    GameTooltip:AddLine("WoW provides the bite splash. Other sound effects are audible too.", 0.7, 0.85, 0.83, true)
    GameTooltip:Show()
end)
fishingAudio:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local startupStats = CreateFrame("CheckButton", "BankFishingStartupStatsCheckbox", panel, "UICheckButtonTemplate")
startupStats:SetPoint("TOPLEFT", audioVolume, "BOTTOMLEFT", -8, -28)
local startupStatsLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
startupStatsLabel:SetPoint("LEFT", startupStats, "RIGHT", 4, 0)
startupStatsLabel:SetText("Show catch stats at startup")
startupStats:SetScript("OnClick", function(self)
    if uiState then
        uiState.showStatsOnStartup = self:GetChecked()
    end
end)
startupStats:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Show catch stats at startup")
    GameTooltip:AddLine("Open the catch window when you log in or reload the UI.", 1, 1, 1, true)
    GameTooltip:AddLine("Catch tracking continues while the window is hidden.", 0.7, 0.85, 0.83, true)
    GameTooltip:Show()
end)
startupStats:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local lureSound = CreateFrame("CheckButton", "BankFishingLureSoundCheckbox", panel, "UICheckButtonTemplate")
lureSound:SetPoint("TOPLEFT", startupStats, "BOTTOMLEFT", 0, -3)
local lureSoundLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
lureSoundLabel:SetPoint("LEFT", lureSound, "RIGHT", 4, 0)
lureSoundLabel:SetText("Lure expiry sound")
lureSound:SetScript("OnClick", function(self)
    if uiState then
        uiState.lureExpirySound = self:GetChecked()
    end
end)
lureSound:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Lure expiry sound")
    GameTooltip:AddLine("Play one short reminder when an active lure expires on your equipped pole.", 1, 1, 1, true)
    GameTooltip:AddLine("The lure icon briefly glows even when this sound is off.", 0.7, 0.85, 0.83, true)
    GameTooltip:Show()
end)
lureSound:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local statsButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
statsButton:SetPoint("TOPLEFT", lureSound, "BOTTOMLEFT", 4, -12)
statsButton:SetSize(160, 24)
statsButton:SetText("Toggle Catch Stats")
statsButton:SetScript("OnClick", addon.ToggleStats)

local function Refresh()
    local keys = { GetBindingKey(addon.binding) }
    local display = #keys > 0 and table.concat(keys, " / ") or "Unassigned"
    bindingText:SetText("Current binding: " .. display)
    RefreshInteract()
    RefreshAutoLoot()
    poolPins:SetEnabled(uiState ~= nil and compat.supportsPoolData)
    poolPins:SetChecked(compat.supportsPoolData and uiState ~= nil and uiState.showFishingPools ~= false)
    fishingAudio:SetEnabled(uiState ~= nil)
    fishingAudio:SetChecked(uiState ~= nil and uiState.boostFishingSound == true)
    RefreshAudioVolume()
    startupStats:SetEnabled(uiState ~= nil)
    startupStats:SetChecked(uiState ~= nil and uiState.showStatsOnStartup == true)
    lureSound:SetEnabled(uiState ~= nil)
    lureSound:SetChecked(uiState ~= nil and uiState.lureExpirySound == true)
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

-- Lure control
do
    local lures = {
        { id = 6529, name = "Shiny Bauble" },
        { id = 268880, name = '"Secret" Bait', foreverOnly = true },
        { id = 6530, name = "Nightcrawlers" },
        { id = 6811, name = "Aquadynamic Fish Lens" },
        { id = 291005, name = "Camper's Lure", foreverOnly = true },
        { id = 6532, name = "Bright Baubles" },
        { id = 7307, name = "Flesh Eating Worm" },
        { id = 6533, name = "Aquadynamic Fish Attractor" },
    }
    if not compat.isForever then
        for index = #lures, 1, -1 do
            if lures[index].foreverOnly then
                table.remove(lures, index)
            end
        end
    end
    local lureButton = CreateFrame("Button", "BankFishingLureButton", fishingButton, "SecureActionButtonTemplate")
    lureButton:SetPoint("LEFT", fishingButton, "RIGHT", 6, 0)
    lureButton:SetSize(29, 29)
    lureButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    lureButton:SetAttribute("useOnKeyDown", false)
    lureButton:SetNormalTexture(134400)
    lureButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    local countText = lureButton:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    countText:SetPoint("BOTTOMRIGHT", -2, 1)
    local timerText = lureButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timerText:SetPoint("TOP", lureButton, "BOTTOM", 0, -2)

    local expiryGlow = lureButton:CreateTexture("BankFishingLureExpiryGlow", "OVERLAY")
    expiryGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    expiryGlow:SetBlendMode("ADD")
    expiryGlow:SetVertexColor(1, 0.72, 0.15)
    expiryGlow:SetPoint("CENTER")
    expiryGlow:SetSize(48, 48)
    expiryGlow:Hide()
    local glowRemaining = 0
    local lureExpiresAt
    local observedPoleSlot

    local function StopLureGlow()
        glowRemaining = 0
        expiryGlow:SetAlpha(1)
        expiryGlow:Hide()
    end

    local function ResetLureReminder()
        lureExpiresAt = nil
        observedPoleSlot = nil
        StopLureGlow()
    end

    local function LureExpired()
        glowRemaining = 4
        expiryGlow:SetAlpha(1)
        expiryGlow:Show()
        if uiState and uiState.lureExpirySound == true and PlaySound then
            PlaySound(SOUNDKIT and SOUNDKIT.READY_CHECK or 8960)
        end
    end

    local function SelectedItem(items, setting)
        local firstInBags
        for _, item in ipairs(items) do
            if uiState and uiState[setting] == item.id then
                return item
            end
            if not firstInBags and C_Item.GetItemCount(item.id) > 0 then
                firstInBags = item
            end
        end
        return firstInBags or items[1]
    end

    local legacyMenu
    local function ShowItemMenu(button, title, items, setting, refresh)
        local function ChooseItem(id)
            if uiState then
                uiState[setting] = id
                refresh()
            end
        end
        if not MenuUtil or not MenuUtil.CreateContextMenu then
            legacyMenu = legacyMenu or CreateFrame("Frame", nil, UIParent, "UIDropDownMenuTemplate")
            local entries = { { text = title, isTitle = true, notCheckable = true } }
            for _, item in ipairs(items) do
                local id = item.id
                local name = C_Item.GetItemNameByID(id) or item.name
                entries[#entries + 1] = {
                    text = ("%s (%d)"):format(name, C_Item.GetItemCount(id)),
                    checked = SelectedItem(items, setting).id == id,
                    func = function() ChooseItem(id) end,
                }
            end
            EasyMenu(entries, legacyMenu, button, 0, 0, "MENU")
            return
        end
        MenuUtil.CreateContextMenu(button, function(_, menu)
            menu:CreateTitle(title)
            for _, item in ipairs(items) do
                local name = C_Item.GetItemNameByID(item.id) or item.name
                menu:CreateRadio(("%s (%d)"):format(name, C_Item.GetItemCount(item.id)), function(id)
                    return SelectedItem(items, setting).id == id
                end, ChooseItem, item.id)
            end
        end)
    end

    local function PoleLureTime()
        return compat.PoleLureTime()
    end

    local function RefreshLure()
        local lure = SelectedItem(lures, "lureID")
        local seconds = PoleLureTime()
        local count = C_Item.GetItemCount(lure.id)
        local texture = lureButton:GetNormalTexture()
        texture:SetTexture(C_Item.GetItemIconByID(lure.id) or 134400)
        texture:SetDesaturated(seconds == 0)
        countText:SetText(tostring(count))
        if count == 0 then
            countText:SetTextColor(1, 0.25, 0.2)
        elseif count <= 3 then
            countText:SetTextColor(1, 0.7, 0.15)
        else
            countText:SetTextColor(1, 1, 1)
        end
        timerText:SetText(seconds > 0 and ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60) or "--")

        local poleSlot = compat.GetFishingPoleSlot()
        if not fishingEnabled or not lureButton:IsVisible() or not poleSlot then
            ResetLureReminder()
            return
        end
        if poleSlot ~= observedPoleSlot then
            ResetLureReminder()
            observedPoleSlot = poleSlot
        end
        if seconds > 0 then
            lureExpiresAt = GetTime() + seconds
            StopLureGlow()
        elseif lureExpiresAt and GetTime() >= lureExpiresAt then
            -- Zero can also mean temporarily unavailable enchant data. Wait for
            -- the observed deadline before treating a missing timer as expiry.
            lureExpiresAt = nil
            LureExpired()
        end
    end

    lureButton:SetScript("PreClick", function(self, button)
        if button ~= "LeftButton" or InCombatLockdown() then
            return
        end
        self:SetAttribute("type1", nil)
        if not FishingPoleEquipped() then
            ShowFishingError("Equip a fishing pole first.")
            return
        end
        if IsFishing() then
            ShowFishingError("Reel in before applying a lure.")
            return
        end
        if PoleLureTime() > 0 then
            ShowFishingError("Your pole already has an active lure.")
            return
        end
        local lure = SelectedItem(lures, "lureID")
        if C_Item.GetItemCount(lure.id) == 0 then
            ShowFishingError("No " .. lure.name .. " in your bags. Right-click to choose another lure.")
            return
        end
        self:SetAttribute("macrotext1", ("/stopmacro [combat]\n/use item:%d\n/use %d"):format(lure.id, compat.GetFishingPoleSlot()))
        self:SetAttribute("type1", "macro")
    end)

    lureButton:SetScript("PostClick", function(self, button)
        if button == "LeftButton" then
            if not InCombatLockdown() then
                self:SetAttribute("type1", nil)
            end
        elseif button == "RightButton" then
            ShowItemMenu(self, "Choose a fishing lure", lures, "lureID", RefreshLure)
        end
    end)

    lureButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local lure = SelectedItem(lures, "lureID")
        GameTooltip:SetItemByID(lure.id)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click to apply the selected lure.", 1, 1, 1)
        GameTooltip:AddLine("Right-click to choose a lure.", 1, 1, 1)
        GameTooltip:AddLine("The timer shows the lure on your equipped pole.", 0.7, 0.85, 0.83)
        GameTooltip:AddLine("Amber count: 3 or fewer lures. Red: none left.", 0.7, 0.85, 0.83)
        GameTooltip:AddLine("The icon briefly glows when an active lure expires.", 0.7, 0.85, 0.83)
        GameTooltip:Show()
    end)
    lureButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local refreshElapsed = 0
    lureButton:SetScript("OnUpdate", function(_, elapsed)
        if glowRemaining > 0 then
            glowRemaining = math.max(0, glowRemaining - elapsed)
            if glowRemaining == 0 then
                StopLureGlow()
            else
                expiryGlow:SetAlpha(0.35 + 0.65 * (0.5 + 0.5 * math.sin((4 - glowRemaining) * math.pi * 3)))
            end
        end
        refreshElapsed = refreshElapsed + elapsed
        if refreshElapsed >= 1 then
            refreshElapsed = 0
            RefreshLure()
        end
    end)
    lureButton:SetScript("OnShow", function()
        ResetLureReminder()
        refreshElapsed = 0
        RefreshLure()
    end)
    lureButton:SetScript("OnHide", ResetLureReminder)
    lureButton:RegisterEvent("PLAYER_LOGIN")
    lureButton:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    lureButton:RegisterEvent("BAG_UPDATE_DELAYED")
    lureButton:SetScript("OnEvent", function(self, event, slot)
        if event == "PLAYER_LOGIN" or (event == "PLAYER_EQUIPMENT_CHANGED" and (slot == 16 or slot == 28)) then
            ResetLureReminder()
        end
        if self:IsVisible() then
            RefreshLure()
        end
    end)

    local campItems = {
        { id = 279981, name = "Basic Campfire Kit" },
        { id = 279961, name = "Journeyman Campfire Kit" },
        { id = 279974, name = "Expert Campfire Kit" },
        { id = 279967, name = "Fish Bowl" },
        { id = 279965, name = "Fishing Rack" },
        { id = 279966, name = "Fishing Hut" },
    }
    local campfireButton = CreateFrame("Button", "BankFishingCampfireButton", fishingButton, "SecureActionButtonTemplate")
    campfireButton:SetPoint("LEFT", lureButton, "RIGHT", 6, 0)
    campfireButton:SetSize(29, 29)
    campfireButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    campfireButton:SetAttribute("useOnKeyDown", false)
    campfireButton:SetNormalTexture(135805)
    campfireButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    local kitCount = campfireButton:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    kitCount:SetPoint("BOTTOMRIGHT", -2, 1)

    local function RefreshCampfire()
        if not compat.isForever then
            kitCount:SetText("")
            campfireButton:GetNormalTexture():SetDesaturated(not compat.IsSpellKnown(818))
            return
        end
        local item = SelectedItem(campItems, "campfireKitID")
        local count = C_Item.GetItemCount(item.id)
        local texture = campfireButton:GetNormalTexture()
        texture:SetTexture(C_Item.GetItemIconByID(item.id) or 135805)
        texture:SetDesaturated(count == 0)
        kitCount:SetText(tostring(count))
    end

    campfireButton:SetScript("PreClick", function(self, button)
        if button ~= "LeftButton" or InCombatLockdown() then
            return
        end
        self:SetAttribute("type1", nil)
        if IsFishing() then
            ShowFishingError("Reel in before placing a camp item.")
            return
        end
        if not compat.isForever then
            self:SetAttribute("spell1", compat.GetSpellName(818))
            self:SetAttribute("type1", "spell")
            return
        end
        local item = SelectedItem(campItems, "campfireKitID")
        if C_Item.GetItemCount(item.id) == 0 then
            ShowFishingError("No " .. item.name .. " in your bags.")
            return
        end
        self:SetAttribute("macrotext1", ("/stopmacro [combat]\n/use item:%d"):format(item.id))
        self:SetAttribute("type1", "macro")
    end)

    campfireButton:SetScript("PostClick", function(self, button)
        if button == "LeftButton" then
            if not InCombatLockdown() then
                self:SetAttribute("type1", nil)
            end
        elseif button == "RightButton" and compat.isForever then
            ShowItemMenu(self, "Choose a camp item", campItems, "campfireKitID", RefreshCampfire)
        end
    end)

    campfireButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not compat.isForever then
            GameTooltip:SetText("Campfire")
            GameTooltip:AddLine("Left-click to build a campfire using Cooking.", 1, 1, 1)
            GameTooltip:Show()
            return
        end
        GameTooltip:SetItemByID(SelectedItem(campItems, "campfireKitID").id)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click to place the selected item.", 1, 1, 1)
        GameTooltip:AddLine("Right-click to choose a camp item.", 1, 1, 1)
        GameTooltip:Show()
    end)
    campfireButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    campfireButton:SetScript("OnShow", RefreshCampfire)
    campfireButton:RegisterEvent("PLAYER_LOGIN")
    campfireButton:RegisterEvent("SPELLS_CHANGED")
    campfireButton:RegisterEvent("BAG_UPDATE_DELAYED")
    campfireButton:SetScript("OnEvent", function(self)
        if self:IsVisible() then
            RefreshCampfire()
        end
    end)
end
