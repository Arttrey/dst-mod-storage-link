GLOBAL.setmetatable(env,{__index=function(t,k) return GLOBAL.rawget(GLOBAL,k) end})

Assets = {
    Asset("ATLAS","images/inventoryimages/wirelessterminal.xml"),
    Asset("ATLAS","images/inventoryimages/terminalconnector.xml"),
}

PrefabFiles =  {
    "terminalconnector",
}

local locale = LOC.GetLocaleCode()
local configured_language = GetModConfigData("language") or "en"
TUNING.SS_RUSSIAN = configured_language == "ru"
-- Kept for compatibility with the copied code paths; RU+ intentionally has
-- only English and Russian interface strings.
TUNING.SS_CHINESE = false
TUNING.SS_WIRELESS = GetModConfigData("wirelessterminal") or false
TUNING.SS_LINKRADIUS = GetModConfigData("linkradius") or 15
TUNING.SS_NEARBY_STATIONS = GetModConfigData("nearby_stations") ~= false
TUNING.SS_SUPPORT_MOD_CONTAINERS = GetModConfigData("support_mod_containers") ~= false

modimport("main/hook")
modimport("main/preview")
modimport("main/rpc")
modimport("main/actions")
modimport("main/ui")
modimport("main/controller")

if TUNING.SS_RUSSIAN then

    STRINGS.NAMES.WIRELESSTERMINAL = "Беспроводной терминал хранения"
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.WIRELESSTERMINAL = "Технология или магия?"
    STRINGS.RECIPE_DESC.WIRELESSTERMINAL = "Открывает доступ к хранилищу на расстоянии."

    STRINGS.NAMES.TERMINALCONNECTOR = "Терминал хранения"
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.TERMINALCONNECTOR = "Технология или магия?"
    STRINGS.RECIPE_DESC.TERMINALCONNECTOR = "Связывает сундуки в единое хранилище."

    STRINGS.UNKNOWACTION = "Действие"

    STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.REMOTEOPENTERMINAL = {
        NOCONTAINER = "Рядом с привязанным терминалом нет доступных сундуков!",
        NOLINK = "Беспроводной терминал ещё не привязан в этом мире!",
        LINKINVALID = "Привязанный терминал больше не существует в этом мире!"
    }

    STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.OPENTERMINAL = {
        NOCONTAINER = "Рядом с этим терминалом нет доступных сундуков!",
    }

    STRINGS.SS_JSONERROR_POPUP = {
        NOTICE = ": уведомление",
        CAUSE = "Не удалось прочитать часть данных сундуков. Возможно, в одном сундуке слишком много предметов.",
        CONFIRM = "Понятно, больше не показывать",
    }
else

    STRINGS.NAMES.WIRELESSTERMINAL = "Wireless Storage Terminal"
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.WIRELESSTERMINAL = "Is this technology or magic?"
    STRINGS.RECIPE_DESC.WIRELESSTERMINAL = "Allow you to access the terminal from a distant place!"

    STRINGS.NAMES.TERMINALCONNECTOR = "Storage Terminal"
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.TERMINALCONNECTOR = "Is this technology or magic?"
    STRINGS.RECIPE_DESC.TERMINALCONNECTOR = "Link your chests together!"

    STRINGS.UNKNOWACTION = "Execute"

    STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.REMOTEOPENTERMINAL = {
        NOCONTAINER = "There are no available chests near the bound terminal!",
        NOLINK = "Wireless terminals have not been bound in the current world yet!",
        LINKINVALID = "The bound terminal is no longer in this world!"
    }

    STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.OPENTERMINAL = {
        NOCONTAINER = "There are no available chests near this terminal!",
    }

    STRINGS.SS_JSONERROR_POPUP = {
        NOTICE = ":Notice",
        CAUSE = "Partial container data parsing failed, possibly because too many items in a single container!",
        CONFIRM = "OK, I know",
    }
end

AddRecipe2(
    "terminalconnector",
    {
        Ingredient("cutstone", 4),
        Ingredient("transistor", 4),
        Ingredient("goldnugget", 4),
    },
    TECH.SCIENCE_TWO,
    {
    atlas = "images/inventoryimages/terminalconnector.xml",
    image = "terminalconnector.tex",
    nounlock = false,
    placer = "terminalconnector_placer",
    min_spacing = 2,
    },
    {
    "PROTOTYPERS",
    "CONTAINERS",
    }
)

AddPrototyperDef("terminalconnector",
    {
        icon_atlas = CRAFTING_ICONS_ATLAS,
        icon_image = "filter_none.tex",
        is_crafting_station = true,
        filter_text = TUNING.SS_RUSSIAN and "Интеграция со станцией крафта" or "Crafting Station Integration",
    }
)

if TUNING.SS_WIRELESS then

    table.insert(env.PrefabFiles, "wirelessterminal")

    AddRecipe2(
        "wirelessterminal",
        {
            Ingredient("moonstorm_static_item", 1),
            Ingredient("wagpunk_bits", 4),
            Ingredient("purebrilliance", 4),
        },
        TECH.SCIENCE_TWO,
        {
        atlas = "images/inventoryimages/wirelessterminal.xml",
        image = "wirelessterminal.tex",
        nounlock = false,
        },
        {
        "CONTAINERS",
        }
    )

end


-- modimport("debug")
