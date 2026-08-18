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
local MAX_SLOTS = 400
local PAGE_SIZE = 50
local MAX_PAGE_COUNT = math.ceil(MAX_SLOTS / PAGE_SIZE)

local function Localized(english, russian)
    return LANGUAGE == "ru" and russian or english
end

STRINGS.NAMES.GROUNDCHESTACCESS = Localized("Chest Access Point", "Точка доступа к сундукам")
STRINGS.CHARACTERS.GENERIC.DESCRIBE.GROUNDCHESTACCESS = Localized("Access to nearby chests.", "Доступ к ближайшим сундукам.")
STRINGS.RECIPE_DESC.GROUNDCHESTACCESS = Localized("Combines nearby chests into one menu.", "Объединяет ближайшие сундуки в одно меню.")

local SEARCH_HINT = Localized("Search item", "Поиск предмета")
local PAGE_TEXT = Localized("Page %d/%d", "Страница %d/%d")

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

    -- 4 страницы по 10 x 5 слотов. Для переключения страниц создаются
    -- четыре группы слотов в одной и той же позиции; видимой остаётся только выбранная группа.
    for page = 1, MAX_PAGE_COUNT do
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
    for _, chest in ipairs(FindNearbyChests(inst)) do
        -- Уже открытый игроком сундук не трогаем, чтобы не вмешиваться в его меню.
        if not chest.components.container:IsOpen() then
            table.insert(inst._storageaccess_sources, chest)
            local source = chest.components.container
            for slot = 1, source:GetNumSlots() do
                local item = source:RemoveItemBySlot(slot)
                if item ~= nil then
                    NormalizeStackForAccess(item)
                    access:GiveItem(item, nil, nil, false)
                    -- При переполнении временного буфера возвращаем предмет обратно.
                    if ItemStillHeld(item) then
                        source:GiveItem(item, slot, nil, false)
                        ReturnItemToWorld(inst, item)
                    end
                end
            end
        end
    end
end

AddPrefabPostInit("groundchestaccess", function(inst)
    inst._storageaccess_capture = CaptureSources
    inst._storageaccess_flush = FlushAccess
end)

-- Кнопка закрытия ванильного контейнера вызовет onclosefn, где содержимое
-- временного буфера вернётся в реальные сундуки.

-- Клиентская часть: добавляем строку поиска к стандартному окну контейнера.
AddClassPostConstruct("widgets/containerwidget", function(self)
    local old_open = self.Open
    local old_close = self.Close
    local old_refresh = self.Refresh
    local ImageButton = require "widgets/imagebutton"
    local Text = require "widgets/text"

    local function IsAccess(container)
        return container ~= nil and container.prefab == "groundchestaccess"
    end

    function self:StorageAccessApplySearch()
        if not IsAccess(self.container) then
            return
        end
        local query = self.storageaccess_searchbox ~= nil and self.storageaccess_searchbox:GetString() or ""
        query = string.lower(query or "")
        local items = self.container.replica.container:GetItems()
        local last_occupied = 0
        for slot = 1, MAX_SLOTS do
            if items[slot] ~= nil then
                last_occupied = slot
            end
        end
        local page_count = math.max(1, math.min(MAX_PAGE_COUNT, math.ceil(last_occupied / PAGE_SIZE)))
        local page = math.min(self.storageaccess_page or 1, page_count)
        self.storageaccess_page = page
        local first_slot = (page - 1) * PAGE_SIZE + 1
        local last_slot = math.min(page * PAGE_SIZE, MAX_SLOTS)
        for slot, widget in pairs(self.inv) do
            local item = items[slot]
            local name = item ~= nil and item:GetBasicDisplayName() or ""
            local visible = slot >= first_slot and slot <= last_slot
                and (item == nil or query == "" or string.find(string.lower(name), query, 1, true) ~= nil)
            if visible then
                widget:Show()
            else
                widget:Hide()
            end
        end
        if self.storageaccess_pagetext ~= nil then
            self.storageaccess_pagetext:SetString(string.format(PAGE_TEXT, page, page_count))
        end
        if self.storageaccess_left ~= nil then
            if page > 1 then self.storageaccess_left:Enable() else self.storageaccess_left:Disable() end
        end
        if self.storageaccess_right ~= nil then
            if page < page_count then self.storageaccess_right:Enable() else self.storageaccess_right:Disable() end
        end
    end

    function self:Open(container, doer)
        old_open(self, container, doer)
        if not IsAccess(container) then
            return
        end

        local templates = require "widgets/redux/templates"
        self.storageaccess_page = 1
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

        local left_textures = {
            normal = "arrow2_left.tex",
            over = "arrow2_left_over.tex",
            disabled = "arrow_left_disabled.tex",
            down = "arrow2_left_down.tex",
        }
        local right_textures = {
            normal = "arrow2_right.tex",
            over = "arrow2_right_over.tex",
            disabled = "arrow_right_disabled.tex",
            down = "arrow2_right_down.tex",
        }
        self.storageaccess_left = self:AddChild(ImageButton("images/plantregistry.xml", left_textures.normal, left_textures.over, left_textures.disabled, left_textures.down))
        self.storageaccess_right = self:AddChild(ImageButton("images/plantregistry.xml", right_textures.normal, right_textures.over, right_textures.disabled, right_textures.down))
        self.storageaccess_left:SetNormalScale(0.5)
        self.storageaccess_left:SetFocusScale(0.6)
        self.storageaccess_right:SetNormalScale(0.5)
        self.storageaccess_right:SetFocusScale(0.6)
        self.storageaccess_left:SetPosition(Vector3(40, 275, 0))
        self.storageaccess_right:SetPosition(Vector3(255, 275, 0))
        self.storageaccess_pagetext = self:AddChild(Text(_G.UIFONT or _G.BUTTONFONT or _G.NUMBERFONT, 28, ""))
        self.storageaccess_pagetext:SetPosition(Vector3(148, 275, 0))
        self.storageaccess_left:SetOnClick(function()
            self.storageaccess_page = math.max(1, (self.storageaccess_page or 1) - 1)
            self:StorageAccessApplySearch()
        end)
        self.storageaccess_right:SetOnClick(function()
            self.storageaccess_page = math.min(MAX_PAGE_COUNT, (self.storageaccess_page or 1) + 1)
            self:StorageAccessApplySearch()
        end)
        self:StorageAccessApplySearch()
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
        if self.storageaccess_left ~= nil then
            self.storageaccess_left:Kill()
            self.storageaccess_left = nil
        end
        if self.storageaccess_right ~= nil then
            self.storageaccess_right:Kill()
            self.storageaccess_right = nil
        end
        if self.storageaccess_pagetext ~= nil then
            self.storageaccess_pagetext:Kill()
            self.storageaccess_pagetext = nil
        end
        old_close(self)
    end
end)
