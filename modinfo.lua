name = "Chest Access Point RU"
description = "Точка доступа к ближайшим обычным и чешуйчатым сундукам: поиск, перенос и автоматическая сортировка без собственного постоянного хранилища."
author = "Codex"
version = "1.3.0"
forumthread = ""

api_version = 10
dst_compatible = true
all_clients_require_mod = true
client_only_mod = false
server_only_mod = false

configuration_options = {
    {
        name = "language",
        label = "Language / Язык",
        hover = "Interface language / Язык интерфейса.",
        options = {
            {description = "English", data = "en"},
            {description = "Русский", data = "ru"},
        },
        default = "en",
    },
    {
        name = "search_radius",
        label = "Chest radius / Радиус сундуков",
        hover = "Distance for finding nearby chests / Расстояние поиска ближайших сундуков.",
        -- DST не предоставляет тип slider в стандартном modinfo.lua.
        -- Поэтому доступны все значения от 1 до 15 с шагом 1.
        options = {},
        default = 8,
    },
}

for radius = 1, 15 do
    configuration_options[2].options[radius] = {
        description = radius .. " tiles / " .. radius .. " клеток",
        data = radius,
    }
end
