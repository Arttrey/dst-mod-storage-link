name = "Simple Storage RU+"
description = [[
English/Russian localization of Simple Storage RU+.
Русская и английская локализация Simple Storage RU+.

This standalone fork provides the RU+ localization and maintenance changes.
Original authors: WIGFRID and 凌子.
Original Workshop item: https://steamcommunity.com/sharedfiles/filedetails/?id=3383078008
Fork maintainer: Arttrey.

Отдельный форк содержит локализацию RU+ и изменения сопровождения.
Авторы оригинала: WIGFRID и 凌子.
Оригинал в Workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=3383078008
Поддержка форка: Arttrey.
]]

author = "Arttrey (fork of Simple Storage by WIGFRID and 凌子)"
version = "26.02.11-ruplus.3"
forumthread = ""

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false
hamlet_compatible = false

all_clients_require_mod = true
api_version = 6
api_version_dst = 10
server_filter_tags = {"SimpleStorage", "RU+", "Russian", "Storage"}

icon_atlas = "modicon.xml"
icon = "modicon.tex"
priority = -1

local function AddTitle(title)
    return {
        name = "null",
        label = title,
        options = {{ description = "", data = 0 }},
        default = 0,
    }
end

configuration_options =
{
    {
        name = "language",
        label = "Interface language",
        hover = "Language used by the terminal interface and actions.",
        options = {
            {description = "English", data = "en"},
            {description = "Русский", data = "ru"},
        },
        default = "en",
    },
    {
        name = "wirelessterminal",
        label = "Wireless Terminal",
        hover = "Enable a portable terminal linked to a storage terminal.",
        options = {
            {description = "Disable", data = false},
            {description = "Enable", data = true},
        },
        default = false,
    },
    {
        name = "linkradius",
        label = "Link Radius",
        hover = "Maximum distance between a storage terminal and containers.",
        options = {
            {description = "10", data = 10},
            {description = "15", data = 15},
            {description = "20", data = 20},
            {description = "30", data = 30},
            {description = "50", data = 50},
        },
        default = 15,
    },
    {
        name = "nearby_stations",
        label = "Use Nearby Crafting Stations",
        hover = "Use every compatible crafting station found inside the link radius.",
        options = {
            {description = "Disable", data = false},
            {description = "Enable", data = true},
        },
        default = true,
    },
    {
        name = "support_mod_containers",
        label = "Modded Container Compatibility",
        hover = "Allow compatible modded containers whose replica does not expose a standard type.",
        options = {
            {description = "Disable", data = false},
            {description = "Enable", data = true},
        },
        default = true,
    },
    AddTitle("Performance"),
    {
        name = "performance",
        label = "High Performance Mode",
        hover = "Use the optimized container synchronization mode.",
        options = {
            {description = "Enabled", data = true},
        },
        default = true,
    },
}
