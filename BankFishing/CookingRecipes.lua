local _, addon = ...
local compat = addon.Compat

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
    { 18246, 275, "Mightfish Steak", 13948, 13893, { { 2692, 1 }, { 3713, 1 } }, true },
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
    [251524] = "Whimsyfin",
}
local kelsey = { "Both factions: Kelsey Yance", "Old Port Authority, Booty Bay, Stranglethorn Vale (28.2, 74.4)" }
local gikkix = { "Both factions: Gikkix", "Steamwheedle Port, Tanaris (66.6, 22.1)" }
local feralas = {
    "Alliance: Vivianna, Feathermoon Stronghold, Feralas",
    "Horde: Sheendra Tallgrass, Camp Mojache, Feralas",
}
local recipeSources = {
    [7751] = {
        "Alliance: Tharynn Bouden, Goldshire, Elwynn Forest",
        "Horde: Sewa Mistrunner, Thunder Bluff",
    },
    [7752] = {
        "Alliance: Kriggon Talsone, Westfall (36.2, 90.1)",
        "Horde: Zansoa, Sen'jin Village, Durotar",
    },
    [7753] = {
        "Alliance: Tharynn Bouden, Goldshire, Elwynn Forest",
        "Horde: Naal Mistrunner, Thunder Bluff",
    },
    [6415] = { "Alliance: Laird, Auberdine, Darkshore (36.8, 44.3)" },
    [7754] = { "Alliance: Khara Deepwater, Thelsamar, Loch Modan (40.3, 39.3)" },
    [7827] = {
        "Alliance: Catherine Leland, Stormwind",
        "Horde: Shankys, Orgrimmar",
        "Both factions: Gritta Chumwater, Powderfuse Port, Riverglades (78.4, 55.0)",
    },
    [25704] = {
        "Alliance: Erika Tate, Stormwind",
        "Horde: Naal Mistrunner, Thunder Bluff, or Xen'to, Orgrimmar",
    },
    [8238] = { "Rare drop in The Barrens", "Examples: Witchwing Harpies and Venture Co. Peons" },
    [1252566] = {
        "Rare drop in Redridge Mountains",
        "Examples: Greater Tarantulas, Redridge Thrashers, and Great Goretusks",
    },
    [7755] = {
        "Alliance: Catherine Leland, Stormwind",
        "Horde: Naal Mistrunner, Thunder Bluff",
        "Both factions: Gritta Chumwater, Powderfuse Port, Riverglades (78.4, 55.0)",
    },
    [20916] = kelsey,
    [7828] = kelsey,
    [25954] = kelsey,
    [1247741] = { "Reported source: Cooking trainer. Specific trainer unverified." },
    [18239] = kelsey,
    [18241] = kelsey,
    [1319313] = { "World pickup: supply cart at Ariden's Camp, Deadwind Pass (52.4, 34.3)" },
    [18238] = gikkix,
    [18240] = gikkix,
    [18242] = kelsey,
    [18243] = gikkix,
    [18244] = gikkix,
    [18247] = feralas,
    [18245] = feralas,
    [18246] = feralas,
}

if not compat.isForever then
    local foreverOnly = { [1252566] = true, [1247741] = true, [1319313] = true }
    local classicRecipes = {}
    local interface = select(4, GetBuildInfo())
    local postCataclysm = interface >= 40000

    for _, recipe in ipairs(recipes) do
        if not foreverOnly[recipe[1]] then
            -- Classic seafood uses a cooking fire in the other clients.
            recipe[7] = nil
            if postCataclysm then
                -- Cataclysm removed spices from these older food recipes.
                -- Water remains an ingredient for the soups and stews.
                if recipe[6] and recipe[6][1][1] ~= 159 then
                    recipe[6] = nil
                end
            end
            classicRecipes[#classicRecipes + 1] = recipe
        end
    end
    recipes = classicRecipes
    ingredientNames[251524] = nil
    ingredientNames[8959] = nil
    ingredientNames[13890] = nil
    recipeSources[1252566] = nil
    recipeSources[1247741] = nil
    recipeSources[1319313] = nil

    -- These suppliers only exist in Forever's Riverglades zone.
    recipeSources[7827][3] = nil
    recipeSources[7755][3] = nil

    if postCataclysm then
        for _, recipe in ipairs(recipes) do
            recipeSources[recipe[1]] = { "Current recipe source has not been verified for this game version." }
            if recipe[1] == 6415 then
                recipe[4] = nil
            end
        end
        recipeSources[6415] = { "Learn from a Cooking trainer." }
        recipeSources[7754] = { "Alliance: Khara Deepwater, Loch Modan" }
        recipeSources[18242] = { "Both factions: Kelsey Yance, Booty Bay, The Cape of Stranglethorn" }
        recipeSources[18246] = {
            "Both factions: Kelsey Yance, Booty Bay, The Cape of Stranglethorn",
            "Horde: Sheendra Tallgrass, Camp Mojache, Feralas",
        }
        recipeSources[18247] = { "Horde: Sheendra Tallgrass, Camp Mojache, Feralas" }
    end
end

addon.CookingRecipes = recipes
addon.CookingIngredientNames = ingredientNames
addon.CookingRecipeSources = recipeSources
addon.CookingGuideName = compat.isForever and "Cooking" or "Classic Cooking"
