PrefabFiles = { "groundchestaccess" }

local _G = GLOBAL
local Vector3 = _G.Vector3
local TheSim = _G.TheSim
local TheWorld = _G.TheWorld
local TUNING = _G.TUNING
local STRINGS = _G.STRINGS
local TECH = _G.TECH

local MOD_NAME = "Storage link"
local LANGUAGE = GetModConfigData("language", MOD_NAME) or "en"
local SEARCH_RADIUS = GetModConfigData("search_radius", MOD_NAME) or 8
local SORT_MODE = GetModConfigData("sort_mode", MOD_NAME) or "nearest"
local CRAFTING_INTEGRATION = GetModConfigData("crafting_integration", MOD_NAME) or false
_G.STORAGE_LINK_CRAFTING_INTEGRATION = CRAFTING_INTEGRATION
local MAX_SLOTS = 400
local SLOT_COLUMNS = 10
local VISIBLE_ROWS = 5
local VISIBLE_SLOTS = SLOT_COLUMNS * VISIBLE_ROWS
local MAX_SCROLL_ROW = math.max(0, math.ceil((MAX_SLOTS - VISIBLE_SLOTS) / SLOT_COLUMNS))

local function Localized(english, russian)
    return LANGUAGE == "ru" and russian or english
end

STRINGS.NAMES.GROUNDCHESTACCESS = Localized("Chest Access Point", "Точка доступа к сундукам")
STRINGS.CHARACTERS.GENERIC.DESCRIBE.GROUNDCHESTACCESS = Localized("Access to nearby chests.", "Доступ к ближайшим сундукам.")
STRINGS.RECIPE_DESC.GROUNDCHESTACCESS = Localized("Combines nearby chests into one menu.", "Объединяет ближайшие сундуки в одно меню.")

local SEARCH_HINT = Localized("Search item", "Поиск предмета")
local SCROLL_TEXT = Localized("Rows %d-%d", "Строки %d-%d")
local FILTER_LABELS = {
    all = Localized("All", "Все"),
    food = Localized("Food", "Еда"),
    tools = Localized("Tools", "Инструменты"),
    combat = Localized("Combat", "Бой"),
    other = Localized("Other", "Прочее"),
}

local containers = require("containers")
local params = containers.params

if params.groundchestaccess == nil then
    params.groundchestaccess =
    {
        widget =
        {
            slotpos = {},
            bgatlas = "images/plantregistry.xml",
            bgimage = "backdrop.tex",
            slotbg = {},
            numslots = MAX_SLOTS,
            animbank = "ui_chest_3x3",
            animbuild = "ui_chest_3x3",
            animbank_upgraded = "ui_chest_upgraded_3x3",
            animbuild_upgraded = "ui_chest_upgraded_3x3",
            pos = Vector3(0, 0, 0),
            side_align_tip = 160,
        },
        type = "groundchestaccess",
        openlimit = 1,
    }

    -- Пул слотов создаётся группами 10 x 5 в одной позиции. Клиентская часть
    -- показывает нужное окно строк и прокручивает его кнопками/колесом мыши.
    for group = 1, math.ceil(MAX_SLOTS / VISIBLE_SLOTS) do
        for y = 2, -2, -1 do
            for x = -5, 4 do
                table.insert(params.groundchestaccess.widget.slotpos, Vector3(75 * x + 37.5, 75 * y, 0))
                table.insert(params.groundchestaccess.widget.slotbg,
                    { atlas = "images/hud.xml", image = "inv_slot.tex" })
            end
        end
    end
end

-- Сетевой classified-контейнер создаёт пул слотов по этому максимуму.
-- Увеличиваем его до размера временного буфера до первого открытия контейнеров.
containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS or 0, MAX_SLOTS)

AddRecipe2(
    "groundchestaccess",
    {
        Ingredient("transistor", 4),
        Ingredient("nightmarefuel", 4),
        Ingredient("cutstone", 4),
        Ingredient("goldnugget", 2),
        Ingredient("livinglog", 2),
    },
    TECH.SCIENCE_TWO,
    { placer = "groundchestaccess_placer", description = "Shared access to nearby chests", image = "dragonflychest.tex" },
    { "PROTOTYPERS", "CONTAINERS" }
)

local function IsSupportedChest(inst)
    if inst == nil or not inst:IsValid() or inst.components.container == nil then
        return false
    end

    -- Улучшение обычного/чешуйчатого сундука меняет его вместимость, но не требует
    -- отдельного prefab. Поэтому проверяем и базовые имена, и возможные варианты.
    local prefab = inst.prefab or ""
    return inst:HasTag("chest") and (
        prefab == "treasurechest"
        or prefab == "dragonflychest"
        or string.find(prefab, "treasurechest", 1, true) ~= nil
        or string.find(prefab, "dragonflychest", 1, true) ~= nil
    )
end

local function FindNearbyChests(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local found = TheSim:FindEntities(x, y, z, SEARCH_RADIUS, { "chest" }, { "INLIMBO", "FX", "NOCLICK" })
    local result = {}

    for _, chest in ipairs(found) do
        if IsSupportedChest(chest) then
            local cx, cy, cz = chest.Transform:GetWorldPosition()
            chest._storageaccess_distance = (cx - x) * (cx - x) + (cz - z) * (cz - z)
            table.insert(result, chest)
        end
    end

    table.sort(result, function(a, b)
        if a._storageaccess_distance ~= b._storageaccess_distance then
            return a._storageaccess_distance < b._storageaccess_distance
        end
        return (a.GUID or 0) < (b.GUID or 0)
    end)
    return result
end

local function ItemStillHeld(item)
    return item ~= nil and item:IsValid() and item.components.inventoryitem ~= nil and item.components.inventoryitem.owner == nil
end

local function NormalizeStackForAccess(item)
    local stack = item ~= nil and item.components ~= nil and item.components.stackable or nil
    if stack ~= nil then
        -- Улучшенные сундуки используют бесконечный maxsize. В точке доступа
        -- всегда возвращаем обычный предел стака, чтобы он не разрастался.
        stack:SetIgnoreMaxSize(false)
    end
    return stack
end

local function NormalizeAccessStacks(container)
    for slot = 1, container:GetNumSlots() do
        NormalizeStackForAccess(container:GetItemInSlot(slot))
    end
end

params.groundchestaccess.itemtestfn = function(container, item, slot)
    NormalizeAccessStacks(container)
    local stack = NormalizeStackForAccess(item)
    return stack == nil or stack:StackSize() <= stack.maxsize
end

local function PutIntoContainer(container, item)
    if container == nil
        or container.inst == nil
        or not container.inst:IsValid()
        or not ItemStillHeld(item) then
        return
    end

    -- Сначала заполняем существующие стаки.
    for slot = 1, container:GetNumSlots() do
        local existing = container:GetItemInSlot(slot)
        if existing ~= nil
            and existing.components.stackable ~= nil
            and item.components.stackable ~= nil
            and item.components.stackable:CanStackWith(existing)
            and not existing.components.stackable:IsFull() then
            container:GiveItem(item, slot, nil, false)
            if not ItemStillHeld(item) then
                return
            end
        end
    end

    -- Затем используем первый подходящий свободный слот.
    for slot = 1, container:GetNumSlots() do
        if container:GetItemInSlot(slot) == nil and container:CanTakeItemInSlot(item, slot) then
            container:GiveItem(item, slot, nil, false)
            if not ItemStillHeld(item) then
                return
            end
        end
    end
end

local function ReturnItemToWorld(inst, item)
    if ItemStillHeld(item) then
        local x, y, z = inst.Transform:GetWorldPosition()
        item.Transform:SetPosition(x, y, z)
        item.components.inventoryitem:OnDropped(true)
    end
end

local function FlushAccess(inst)
    local access = inst.components.container
    if access == nil then
        return
    end

    local sources = inst._storageaccess_sources or {}
    local items = access:RemoveAllItems()

    for _, item in ipairs(items) do
        if item ~= nil then
            NormalizeStackForAccess(item)
            for _, chest in ipairs(sources) do
                if chest ~= nil and chest:IsValid() and chest.components.container ~= nil then
                    PutIntoContainer(chest.components.container, item)
                end
                if not ItemStillHeld(item) then
                    break
                end
            end
            ReturnItemToWorld(inst, item)
        end
    end

    inst._storageaccess_sources = nil
end

local function CaptureSources(inst)
    local access = inst.components.container
    if access == nil then
        return
    end
    NormalizeAccessStacks(access)
    if not access:IsEmpty() or inst._storageaccess_sources ~= nil then
        return
    end

    inst._storageaccess_sources = {}
    local pending = {}
    for _, chest in ipairs(FindNearbyChests(inst)) do
        -- Уже открытый игроком сундук не трогаем, чтобы не вмешиваться в его меню.
        if not chest.components.container:IsOpen() then
            table.insert(inst._storageaccess_sources, chest)
            local source = chest.components.container
            for slot = 1, source:GetNumSlots() do
                local item = source:RemoveItemBySlot(slot)
                if item ~= nil then
                    NormalizeStackForAccess(item)
                    table.insert(pending, { item = item, source = source, slot = slot })
                end
            end
        end
    end

    if SORT_MODE == "name" then
        table.sort(pending, function(a, b)
            local aname = a.item.prefab or ""
            local bname = b.item.prefab or ""
            if aname ~= bname then
                return aname < bname
            end
            return (a.slot or 0) < (b.slot or 0)
        end)
    end

    for _, record in ipairs(pending) do
        local item = record.item
        access:GiveItem(item, nil, nil, false)
        -- При переполнении временного буфера возвращаем предмет обратно.
        if ItemStillHeld(item) then
            record.source:GiveItem(item, record.slot, nil, false)
            ReturnItemToWorld(inst, item)
        end
    end
end

AddPrefabPostInit("groundchestaccess", function(inst)
    inst._storageaccess_capture = CaptureSources
    inst._storageaccess_flush = FlushAccess
end)

-- Кнопка закрытия ванильного контейнера вызовет onclosefn, где содержимое
-- временного буфера вернётся в реальные сундуки.

-- Клиентская часть: строка поиска, фильтры и вертикальная прокрутка
-- поверх стандартного контейнерного окна DST.
AddClassPostConstruct("widgets/containerwidget", function(self)
    local old_open = self.Open
    local old_close = self.Close
    local old_refresh = self.Refresh
    local old_oncontrol = self.OnControl
    local ImageButton = require "widgets/imagebutton"
    local Text = require "widgets/text"

    local function IsAccess(container)
        return container ~= nil and container.prefab == "groundchestaccess"
    end

    local function GetCategory(item)
        if item == nil then
            return "other"
        end
        if item:HasTag("food") then
            return "food"
        end
        if item:HasTag("weapon") or item:HasTag("armor") then
            return "combat"
        end
        if item:HasTag("tool") then
            return "tools"
        end
        return "other"
    end

    function self:StorageAccessApplySearch()
        if not IsAccess(self.container) then
            return
        end
        local query = self.storageaccess_searchbox ~= nil and self.storageaccess_searchbox:GetString() or ""
        query = string.lower(query or "")
        local category = self.storageaccess_category or "all"
        local items = self.container.replica.container:GetItems()
        local last_occupied = 0
        for slot = 1, MAX_SLOTS do
            if items[slot] ~= nil then
                last_occupied = slot
            end
        end
        local max_scroll = math.max(0, math.min(MAX_SCROLL_ROW, math.ceil(math.max(0, last_occupied - VISIBLE_SLOTS) / SLOT_COLUMNS)))
        local scroll_row = math.min(self.storageaccess_scroll_row or 0, max_scroll)
        self.storageaccess_scroll_row = scroll_row
        local first_slot = scroll_row * SLOT_COLUMNS + 1
        local last_slot = math.min(first_slot + VISIBLE_SLOTS - 1, MAX_SLOTS)
        local filter_active = query ~= "" or category ~= "all"
        for slot, widget in pairs(self.inv) do
            local item = items[slot]
            local name = item ~= nil and item:GetBasicDisplayName() or ""
            local matches_name = item ~= nil and (query == "" or string.find(string.lower(name), query, 1, true) ~= nil)
            local matches_category = item ~= nil and (category == "all" or GetCategory(item) == category)
            local visible = slot >= first_slot and slot <= last_slot
                and (not filter_active and item == nil or item ~= nil and matches_name and matches_category)
            if visible then
                widget:Show()
            else
                widget:Hide()
            end
        end
        if self.storageaccess_scrolltext ~= nil then
            self.storageaccess_scrolltext:SetString(string.format(SCROLL_TEXT,
                scroll_row + 1, math.min(scroll_row + VISIBLE_ROWS, math.ceil(MAX_SLOTS / SLOT_COLUMNS))))
        end
        if self.storageaccess_up ~= nil then
            if scroll_row > 0 then self.storageaccess_up:Enable() else self.storageaccess_up:Disable() end
        end
        if self.storageaccess_down ~= nil then
            if scroll_row < max_scroll then self.storageaccess_down:Enable() else self.storageaccess_down:Disable() end
        end
    end

    function self:Open(container, doer)
        old_open(self, container, doer)
        if not IsAccess(container) then
            return
        end

        local templates = require "widgets/redux/templates"
        self.storageaccess_scroll_row = 0
        self.storageaccess_category = "all"
        self.storageaccess_searchroot = self:AddChild(templates.StandardSingleLineTextEntry(nil, 300, 48, nil, nil, SEARCH_HINT))
        self.storageaccess_searchroot:SetPosition(Vector3(-215, 275, 0))
        self.storageaccess_searchbox = self.storageaccess_searchroot.textbox
        self.storageaccess_searchbox:SetTextLengthLimit(50)
        self.storageaccess_searchbox:SetForceEdit(true)
        self.storageaccess_searchbox:EnableWordWrap(false)
        self.storageaccess_searchbox:EnableScrollEditWindow(true)
        self.storageaccess_searchbox.OnTextInputted = function()
            self:StorageAccessApplySearch()
        end

        self.storageaccess_up = self:AddChild(ImageButton("images/ui.xml", "button_small.tex", "button_small_over.tex", "button_small_disabled.tex"))
        self.storageaccess_down = self:AddChild(ImageButton("images/ui.xml", "button_small.tex", "button_small_over.tex", "button_small_disabled.tex"))
        self.storageaccess_up:SetNormalScale(0.65)
        self.storageaccess_up:SetFocusScale(0.7)
        self.storageaccess_down:SetNormalScale(0.65)
        self.storageaccess_down:SetFocusScale(0.7)
        self.storageaccess_up:SetText("^")
        self.storageaccess_down:SetText("v")
        self.storageaccess_up:SetTextSize(24)
        self.storageaccess_down:SetTextSize(24)
        self.storageaccess_up:SetPosition(Vector3(40, 275, 0))
        self.storageaccess_down:SetPosition(Vector3(255, 275, 0))
        self.storageaccess_scrolltext = self:AddChild(Text(_G.UIFONT or _G.BUTTONFONT or _G.NUMBERFONT, 24, ""))
        self.storageaccess_scrolltext:SetPosition(Vector3(148, 275, 0))
        self.storageaccess_up:SetOnClick(function()
            self.storageaccess_scroll_row = math.max(0, (self.storageaccess_scroll_row or 0) - 1)
            self:StorageAccessApplySearch()
        end)
        self.storageaccess_down:SetOnClick(function()
            self.storageaccess_scroll_row = math.min(MAX_SCROLL_ROW, (self.storageaccess_scroll_row or 0) + 1)
            self:StorageAccessApplySearch()
        end)

        self.storageaccess_category_buttons = {}
        local category_order = { "all", "food", "tools", "combat", "other" }
        for index, category_name in ipairs(category_order) do
            local button = self:AddChild(ImageButton("images/ui.xml", "button_small.tex", "button_small_over.tex", "button_small_disabled.tex"))
            button:SetPosition(Vector3(-240 + (index - 1) * 120, 225, 0))
            button:SetNormalScale(0.65)
            button:SetFocusScale(0.7)
            button:SetText(FILTER_LABELS[category_name])
            button:SetTextSize(20)
            button:SetOnClick(function()
                self.storageaccess_category = category_name
                self.storageaccess_scroll_row = 0
                self:StorageAccessApplySearch()
            end)
            self.storageaccess_category_buttons[category_name] = button
        end
        self:StorageAccessApplySearch()
    end

    function self:OnControl(control, down)
        if IsAccess(self.container) and down then
            if (_G.CONTROL_SCROLLBACK ~= nil and control == _G.CONTROL_SCROLLBACK)
                or (_G.CONTROL_PREV ~= nil and control == _G.CONTROL_PREV) then
                self.storageaccess_scroll_row = math.max(0, (self.storageaccess_scroll_row or 0) - 1)
                self:StorageAccessApplySearch()
                return true
            elseif (_G.CONTROL_SCROLLFWD ~= nil and control == _G.CONTROL_SCROLLFWD)
                or (_G.CONTROL_NEXT ~= nil and control == _G.CONTROL_NEXT) then
                self.storageaccess_scroll_row = math.min(MAX_SCROLL_ROW, (self.storageaccess_scroll_row or 0) + 1)
                self:StorageAccessApplySearch()
                return true
            end
        end
        return old_oncontrol ~= nil and old_oncontrol(self, control, down) or false
    end

    function self:Refresh()
        old_refresh(self)
        self:StorageAccessApplySearch()
    end

    function self:Close()
        if self.storageaccess_searchroot ~= nil then
            self.storageaccess_searchroot:Kill()
            self.storageaccess_searchroot = nil
            self.storageaccess_searchbox = nil
        end
        if self.storageaccess_up ~= nil then
            self.storageaccess_up:Kill()
            self.storageaccess_up = nil
        end
        if self.storageaccess_down ~= nil then
            self.storageaccess_down:Kill()
            self.storageaccess_down = nil
        end
        if self.storageaccess_scrolltext ~= nil then
            self.storageaccess_scrolltext:Kill()
            self.storageaccess_scrolltext = nil
        end
        if self.storageaccess_category_buttons ~= nil then
            for _, button in pairs(self.storageaccess_category_buttons) do
                button:Kill()
            end
            self.storageaccess_category_buttons = nil
        end
        old_close(self)
    end
end)
