require "class"

local ItemTile = require "widgets/terminal_itemtile"
local InvSlot = require "widgets/terminal_invslot"
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local UIAnim = require "widgets/uianim"
local ImageButton = require "widgets/imagebutton"
local TEMPLATES = require "widgets/redux/templates"
local TerminalScrolllist = require "widgets/terminalscrolllist"
local TerminalSideBar = require "widgets/terminalsidebar"

local ru = TUNING.SS_RUSSIAN
local pinyin = require "ss_util/pinyin"

local NAME_PINYIN = {}
local FILTER_ATLAS = resolvefilepath(CRAFTING_ICONS_ATLAS)
local FNS = require "ss_util/terminalfn"

local FILTER_DEFS = {
    {name = "EVERYTHING", label = ru and "Все" or "Everything", atlas = FILTER_ATLAS, image = "filter_none.tex"},

    {name = "TOOLS", label = ru and "Инструменты" or "Tools", atlas = FILTER_ATLAS, image = "filter_tool.tex", fn = FNS.tool_filter_fn},

    {name = "WEAPONS", label = ru and "Оружие" or "Weapons", atlas = FILTER_ATLAS, image = "filter_weapon.tex", fn = FNS.weapon_filter_fn},

	{name = "CLOTHING", label = ru and "Броня и одежда" or "Armor & Clothing", atlas = FILTER_ATLAS, image = "filter_warable.tex", fn = FNS.warable_filter_fn},

    {name = "REFINE", label = ru and "Обработка" or "Refine", atlas = FILTER_ATLAS,	image = "filter_refine.tex", fn = FNS.refine_filter_fn},

    {name = "MAGIC", label = ru and "Магия" or "Magic", atlas = FILTER_ATLAS, image = "filter_skull.tex", fn = FNS.magic_filter_fn},

    {name = "GARDENING", label = ru and "Еда и садоводство" or "Food & Gardening", atlas = FILTER_ATLAS, image = "filter_gardening.tex", fn = FNS.gardening_filter_fn},

    {name = "FAVORITES", label = ru and "Избранное (клавиша F)" or "Collect items with key F", atlas = FILTER_ATLAS, image = "filter_favorites.tex", fn = FNS.favorites_filter_fn},
}

local SORTMODE = {
    QUANTITY = 1,
    STRING = 2,
    TYPE = 3,
    FRESHNESS = 4,
}

-- Extra equipment slots shown at the far left of the vanilla/extended HUD.
-- They are deliberately excluded from the "Store All" action.
local PROTECTED_INVENTORY_SLOTS = {
    [1] = true,
    [2] = true,
    [3] = true,
    [4] = true,
    [5] = true,
}

local TerminalWidget = Class(Widget, function(self, owner)
    Widget._ctor(self, "TerminalWidget")
    self.owner = owner

    if self.owner.HUD:IsCraftingOpen() then
        self:SetPosition(260, 0, 0)
    else
        self:SetPosition(0, 0, 0)
    end

    self.bgroot = self:AddChild(Widget("TerminalWidgetBGRoot"))

    self.root = self:AddChild(Widget("TerminalWidgetRoot"))

    self.left_root = self:AddChild(Widget("TerminalWidgetLeftRoot"))
    self.left_root:SetPosition(-410, 0)

    self.isopen = false
    self.containers = {}

    self.itempool = {}
    self.grouped_itempool = {}

    self.griddata = {}
    self.itemnum = {}

    self.inv = {}

    self.sortmode = FNS.get_sortmode()
    if self.sortmode < SORTMODE.QUANTITY or self.sortmode > SORTMODE.FRESHNESS then
        self.sortmode = SORTMODE.QUANTITY
    end
end)

function TerminalWidget:Open(containers)
    -- 重复Open时调用
    self:Close()

    self.isopen = true
    self.containers = containers

    self:InitPanel()
    self:Refresh()

    self:Show()
    self:Enable()
end

function TerminalWidget:InitPanel()

    if not self.bg then

        local str1 = ru and "Сортировка: " or "Sort: "
        local str2 = {
            [SORTMODE.QUANTITY] = ru and "Количество" or "Quantity",
            [SORTMODE.STRING] = ru and "Алфавит" or "Alphabet",
            [SORTMODE.TYPE] = ru and "Тип" or "Type",
            [SORTMODE.FRESHNESS] = ru and "Свежесть" or "Freshness",
        }

        local function sortfn()
            self.sortmode = self.sortmode + 1
            if self.sortmode > SORTMODE.FRESHNESS then
                self.sortmode = SORTMODE.QUANTITY
            end
            FNS.save_sortmode(self.sortmode)
            self.bgbuttons[1]:SetText(str1..str2[self.sortmode])
            self:MakeInvGrid()
        end

        local function closefn()
            self:DoCloseAction()
        end

        local function store_inventory_fn()
            self:StoreFromInventory(false)
        end

        local function store_backpack_fn()
            self:StoreFromInventory(true)
        end

        self.bg = self.bgroot:AddChild(TEMPLATES.RectangleWindow(680, 420, "", {
            {text = str1..str2[self.sortmode], cb = sortfn},
            {text = ru and "Положить всё" or "Store All", cb = store_inventory_fn},
            {text = ru and "Положить из рюкзака" or "Store Backpack", cb = store_backpack_fn},
            {text = ru and "Закрыть терминал" or "Close Terminal", cb = closefn},
        }))

        self.bgbuttons = {
            [1] = self.bg.actions.items[1],
            [2] = self.bg.actions.items[2],
            [3] = self.bg.actions.items[3],
            [4] = self.bg.actions.items[4],
        }

        for i, button in ipairs(self.bgbuttons) do
            button:ClearFocusDirs()
            -- 手柄兼容
            button.Highlight = function(button) button:SetFocus() end
            button.DeHighlight = function(button) button:ClearFocus() end
            button.hide_cursor = true
            button.is_terminal_button = true
        end

        self.bg:SetBackgroundTint(0, 0, 0, 0.6)
    end

    if not self.line then

        self.line = self.root:AddChild(Image("images/ui.xml", "line_horizontal_white.tex"))
        self.line:SetPosition(0, 144)
        self.line:SetTint(1, 1, 1, 0.4)
        self.line:ScaleToSize(700, 5)
    end

    if not self.filterpanel then
        
        self.filterpanel = self.root:AddChild(Widget("FilterPanel"))
        self.filterpanel:SetPosition(0, 175)

        local pos_x = -336
        self.filterbuttons = {}
        for i, filter_def in ipairs(FILTER_DEFS) do
            local filterbutton = self:MakeFilterButton(filter_def)
            self.filterbuttons[filter_def.name] = self.filterpanel:AddChild(filterbutton)
            self.filterbuttons[filter_def.name]:SetPosition(pos_x, 0)
            pos_x = pos_x + 48
        end

        local searchbox = self:MakeSearchBox(186, 40)
        self.searchbox = self.filterpanel:AddChild(searchbox)
        self.searchbox:SetPosition(pos_x + 73, 0)

        local text_size = ru and 30 or 28
        self.numslots_text = self.filterpanel:AddChild(Text(BODYTEXTFONT, text_size))
        self.numslots_text:SetPosition(292, 0)
        self.numslots_text:SetString("")

        self:SelectFilter("EVERYTHING")
    end

    if not self.sidebar then
        self.sidebar = self.left_root:AddChild(TerminalSideBar(self.owner, self))
    else
        self.sidebar:InitPanel()
    end
end

-- filter button
function TerminalWidget:SelectFilter(name)
    if name == self.current_filter_name then
        return
    end
    if self.current_filter_name then
        self.filterbuttons[self.current_filter_name].button:Unselect()
    end
    self.filterbuttons[name].button:Select()
    self.current_filter_name = name
end

function TerminalWidget:MakeFilterButton(filter_def)
    local button_size = 39
	local atlas = resolvefilepath(CRAFTING_ATLAS)

	local w = Widget("filter_"..filter_def.name)
    w.scalingroot = w:AddChild(Widget("ScalingRoot"))
	w.scalingroot:SetScale(button_size/64)

	local button = w.scalingroot:AddChild(ImageButton(atlas, "filterslot_frame.tex", "filterslot_frame_highlight.tex", nil, nil, "filterslot_frame_highlight.tex"))
	w.button = button
	button:SetOnClick(function()
		self:SelectFilter(filter_def.name)
	end)
	button:SetOnSelect(function()
        -- 设置筛选函数
        self.filter_fn = filter_def.fn -- or nil
        -- 退出搜索模式
        if filter_def.name ~= "EVERYTHING" then
            self.searchbox.textbox:SetString("")
            self:SetSearchText(nil)
        end
        -- 刷新UI
        self:MakeInvGrid()
        w.bg:SetTexture(atlas, "filterslot_bg_highlight.tex")
	end)
	button:SetOnUnSelect(function()
        w.bg:SetTexture(atlas, "filterslot_bg.tex")
	end)

    w:SetTooltip(filter_def.label)

	w.focus_forward = button

	----------------
	local filter_atlas = FunctionOrValue(filter_def.atlas, self.owner, filter_def)
	local filter_image = FunctionOrValue(filter_def.image, self.owner, filter_def)

	local filter_img = button:AddChild(Image(filter_atlas, filter_image))

	filter_img:ScaleToSize(54, 54)

	filter_img:MoveToBack()
	w.filter_img = filter_img

	w.filter_def = filter_def

	w.bg = button:AddChild(Image(atlas, "filterslot_bg.tex"))
	w.bg:MoveToBack()

    -- 用于手柄
    w.Highlight = function() self:SelectFilter(filter_def.name) end
    w.DeHighlight = function() end
    w.hide_cursor = true
    w.is_terminal_filter = true

	return w
end

-- favorite
function TerminalWidget:ToggleFavorite(itemtile)
    local item = itemtile.fakeitem
    if item == nil then
        return
    end
    -- 生成图片
    local item_image = Image(item.replica.inventoryitem:GetAtlas(), item.replica.inventoryitem:GetImage(), "default.tex")
    -- callback
    local move_cb = function()
        self.inst:DoTaskInTime(5*FRAMES,function()
            item_image:Kill()
        end)
    end
    local prefab = tostring(item.prefab)
    local start_pos, end_pos
    if FNS.is_favorite(prefab) then
        -- 取消收藏
        FNS.remove_favorite(prefab)
        start_pos = self.filterbuttons["FAVORITES"]:GetWorldPosition()
        end_pos = start_pos + Vector3(0, 80, 0)
        TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
    else
        -- 收藏
        FNS.add_favorite(prefab)
        start_pos = itemtile:GetWorldPosition()
        end_pos = self.filterbuttons["FAVORITES"]:GetWorldPosition()
        TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/research_available")
    end
    -- 移动图片
    item_image:MoveTo(start_pos, end_pos, 0.3, move_cb)
    -- 刷新
    if self.current_filter_name == "FAVORITES" then
        self:MakeInvGrid()
    end
end

-- search box
function TerminalWidget:SetSearchText(str)
    if type(str) == "string" and str:len() > 0 then
        self.search_str = string.lower(str)
    else
        -- 退出搜索状态
        self.search_str = nil
    end
end

local function CheckChinese(s)
	local f = '[%z\1-\127\194-\244][\128-\191]*'
	local line, lastLine, isBreak = '', false, false
	for v in s:gfind(f) do
		local isChinese = (#v~=1)
		if isChinese then
            return s
		end
	end
	return nil
end

function TerminalWidget:MakeSearchBox(box_width, box_height)
    local searchbox = Widget("search")

    searchbox.textbox_root = searchbox:AddChild(TEMPLATES.StandardSingleLineTextEntry(nil, box_width, box_height))
    searchbox.textbox = searchbox.textbox_root.textbox
    searchbox.textbox:SetTextLengthLimit(200)
    searchbox.textbox:SetForceEdit(true)
    searchbox.textbox:EnableWordWrap(false)
    searchbox.textbox:EnableScrollEditWindow(true)
    searchbox.textbox:SetHelpTextEdit("")
    searchbox.textbox:SetHelpTextApply(STRINGS.UI.SERVERCREATIONSCREEN.SEARCH)
    searchbox.textbox:SetTextPrompt(ru and "Поиск предмета" or "Search item", UICOLOURS.GREY)
    searchbox.textbox.prompt:SetHAlign(ANCHOR_MIDDLE)
    searchbox.textbox.OnTextInputted = function()
        -- 切换到EVERYTHING
        self:SelectFilter("EVERYTHING")
        -- 设置SearchText
		self:SetSearchText(self.searchbox.textbox:GetString())
        -- 刷新
        self:MakeInvGrid()
    end

    searchbox:SetOnGainFocus(function() searchbox.textbox:OnGainFocus() end)
    searchbox:SetOnLoseFocus(function() searchbox.textbox:OnLoseFocus() end)

    searchbox.focus_forward = searchbox.textbox

    self.search_filter_fn = function(data)
        if data then
            -- 根据prefab名匹配
            if data.prefab then
                local s = tostring(data.prefab)
                if string.find(s, self.search_str, 1, true) then
                    return true
                end
            end
            -- 根据name匹配
            if data.item and data.item:IsValid() then
                local name = data.item:GetBasicDisplayName()
                local py
                if NAME_PINYIN[name] then
                    -- 已经保存的中文name
                    py = NAME_PINYIN[name]
                else
                    if CheckChinese(name) then
                        -- 未保存的中文name
                        py = pinyin(name, true, "")
                        NAME_PINYIN[name] = py
                    else
                        -- 其他语言直接匹配name
                        name = string.lower(name)
                        return string.find(name, self.search_str, 1, true)
                    end
                end
                -- 尝试根据拼音匹配
                return string.find(py, self.search_str, 1, true)
            end
        end
        return false
    end

    return searchbox
end

-- show available slots
local function GetAvailableNumslots(containers, unselect_containers)
    unselect_containers = unselect_containers or {}
    local available = 0
    local total = 0

    for guid, container in pairs(containers) do
        if not unselect_containers[container.prefab] then
            local numslots = container.replica.container:GetNumSlots()
            total = total + numslots
            for slot = 1, numslots do
                local item = container.replica.container:GetItemInSlot(slot)
                if item == nil then
                    available = available + 1
                end
            end
        end
    end
    -- 剩余格子/总的格子
    return available, total
end

function TerminalWidget:RefreshPanel()
    -- 刷新剩余格子数
    local unselect_containers = self:GetUnselectContainers()
    local available_slots, total_slots = GetAvailableNumslots(self.containers, unselect_containers)
    local numslots_str

    if ru then
        numslots_str = "Свободно: "..tostring(available_slots).."/"..tostring(total_slots)
    else
        numslots_str = "Usable: "..tostring(available_slots).."/"..tostring(total_slots)
    end

    self.numslots_text:SetString(numslots_str)
    if available_slots == 0 then
        self.numslots_text:SetColour(1, 0.4, 0.4, 1)
    else
        self.numslots_text:SetColour(1, 1, 1, 1)
    end
end

-- RefreshItem fns
local function AddItemToGroup(self, new_data)
    -- item get
    local prefab = new_data.prefab
    if self.grouped_itempool[prefab] == nil then
        self.grouped_itempool[prefab] = {}
    end
    local skinname = new_data.skinname or "nil"
    if self.grouped_itempool[prefab][skinname] == nil then
        self.grouped_itempool[prefab][skinname] = {
            [0] = 0, --总数
        }
    end
    -- prefab总数
    local stacksize = new_data.stacksize
    if self.itemnum[prefab] == nil then
        self.itemnum[prefab] = 0
    end
    self.itemnum[prefab] = self.itemnum[prefab] + math.max(stacksize, 1)
    -- prefab - skin总数
    local tbl = self.grouped_itempool[prefab][skinname]
    tbl[0] = tbl[0] + stacksize
    table.insert(tbl, new_data)
end

local function RemoveItemFromGroup(self, old_data)
    -- item lose
    local prefab = old_data.prefab
    if self.grouped_itempool[prefab] == nil then
        return
    end
    local skinname = old_data.skinname or "nil"
    if self.grouped_itempool[prefab][skinname] == nil then
        return
    end
    local tbl = self.grouped_itempool[prefab][skinname]
    for i, data in ipairs(tbl) do
        if data == old_data then
            table.remove(tbl, i)
            break
        end
    end
    -- prefab总数
    local stacksize = old_data.stacksize
    if self.itemnum[prefab] then
        self.itemnum[prefab] = self.itemnum[prefab] - math.max(stacksize, 1)
    end
    -- prefab - skin总数
    if tbl[1] == nil then
        self.grouped_itempool[prefab][skinname] = nil
        return
    end
    tbl[0] = tbl[0] - stacksize
end

local function CtorItemData(item, container, slot)
    local stacksize = item.replica.stackable and item.replica.stackable:StackSize() or 0
    local skinname = item.skinname or item.AnimState:GetSkinBuild()
    local new_data = {
        item = item,
        stacksize = stacksize,
        prefab = item.prefab,
        skinname = skinname,
        container = container,
        slot = slot,
    }
    return new_data
end

local function RefreshSingleItem(self, container, slot)
    -- print("RefreshSingleItem")
    -- 检查格子里是否有新物品
    local new_data, added
    local item = container.replica.container:GetItemInSlot(slot)
    if item then
        new_data = CtorItemData(item, container, slot)
    end
    -- 移除这个格子原来的物品(如果有)
    local guid = container.GUID
    for i, old_data in ipairs(self.itempool) do
        if old_data.container.GUID == guid and old_data.slot == slot then
            RemoveItemFromGroup(self, old_data)
            if new_data then
                self.itempool[i] = new_data
                AddItemToGroup(self, new_data)
                added = true
            else
                table.remove(self.itempool, i)
            end
            break
        end
    end
    -- 如果前面还未添加新物品
    if new_data and not added then
        table.insert(self.itempool, new_data)
        AddItemToGroup(self, new_data)
    end
end

local function RefreshSingleContainer(self, container)
    local guid = container.GUID
    local new_itempool = {}
    -- 保留不是这个容器的物品
    for i, old_data in ipairs(self.itempool) do
        if old_data.container.GUID == guid then
            RemoveItemFromGroup(self, old_data)
        else
            table.insert(new_itempool, old_data)
        end
    end
    self.itempool = new_itempool
    -- 仅关闭用途
    if container.only_for_close then
        return
    end
    -- 重新遍历这个容器的物品
    local numslots = container.replica.container:GetNumSlots()
    for slot = 1, numslots do
        local item = container.replica.container:GetItemInSlot(slot)
        if item then
            local new_data = CtorItemData(item, container, slot)
            table.insert(self.itempool, new_data)
            --------------------------------------------------
            AddItemToGroup(self, new_data)
        end
    end
end

local function RefreshAllContainers(self)
    -- 初始化的时候
    self.itempool = {}
    self.grouped_itempool = {}
    for guid, container in pairs(self.containers) do
        local numslots = container.replica.container:GetNumSlots()
        --遍历格子
        for slot = 1, numslots do
            local item = container.replica.container:GetItemInSlot(slot)
            if item then
                local new_data = CtorItemData(item, container, slot)
                table.insert(self.itempool, new_data)
                --------------------------------------------------
                AddItemToGroup(self, new_data)
            end
        end
    end
end

-- handle item change
function TerminalWidget:RefreshItemPool(container, slot)
    if container and slot then
        -- print("refresh item in slot " .. slot .. " of container " .. container.GUID)
        RefreshSingleItem(self, container, slot)
    elseif container then
        -- print("refresh container " .. container.GUID)
        RefreshSingleContainer(self, container)
    else
        -- print("refresh all containers")
        RefreshAllContainers(self)
    end
end

function TerminalWidget:RefreshGridData()
    -- 刷新griddata，物品变动时调用
    self.griddata = {}
    for prefab, skin_tbl in pairs(self.grouped_itempool) do
        for skinname, tbl in pairs(skin_tbl) do
            if tbl[0] == 0 then
                -- 不可堆叠物品
                for i, data in ipairs(tbl) do
                    local data = shallowcopy(data)
                    table.insert(self.griddata, data)
                end
            else
                -- 找出堆叠最大的那个
                local choose = 1
                local max_stacksize = 0
                for i, data in ipairs(tbl) do
                    if data.stacksize > max_stacksize then
                        max_stacksize = data.stacksize
                        choose = i
                    end
                end
                local data = shallowcopy(tbl[choose])
                data.overridequantity = tbl[0]
                table.insert(self.griddata, data)
            end
        end
    end
end

-- filter and sort
local function ApplyFilter(griddata, filter_fn)
    if not filter_fn then
        return griddata
    end
    local ret = {}
    for i, data in ipairs(griddata) do
        if filter_fn(data) then
            table.insert(ret, data)
        end
    end
    return ret
end

local function SortGridData(griddata, sortmode)

    local function sortbyquantity(l, r)
        if l.overridequantity and r.overridequantity then
            if l.overridequantity == r.overridequantity then
                return nil
            else
                return l.overridequantity > r.overridequantity
            end
        elseif l.overridequantity then
            return true
        elseif r.overridequantity then
            return false
        else
            return nil
        end
    end

    local function sortbyprefab(l, r)
        if l.prefab and r.prefab and l.prefab ~= r.prefab then
            return tostring(l.prefab) < tostring(r.prefab)
        else
            return nil
        end
    end

    local function item_type(data)
        local item = data and data.item
        if item then
            if item:HasTag("edible_GENERIC") or item:HasTag("edible_MEAT") or
                item:HasTag("edible_VEGGIE") or item:HasTag("food") then
                return "food"
            elseif item:HasTag("weapon") then
                return "weapon"
            elseif item:HasTag("tool") then
                return "tool"
            elseif item:HasTag("wearable") or item:HasTag("armor") then
                return "clothing"
            elseif item:HasTag("gem") or item:HasTag("magic") then
                return "magic"
            end
        end
        return tostring(data and data.prefab or "")
    end

    local function sortbytype(l, r)
        local lt, rt = item_type(l), item_type(r)
        if lt ~= rt then
            return lt < rt
        end
        return nil
    end

    local function freshness(data)
        local item = data and data.item
        local perishable = item and item.replica and item.replica.perishable
        if perishable and perishable.GetPercent then
            return perishable:GetPercent() or 1
        end
        return 1
    end

    local function sortbyfreshness(l, r)
        local lf, rf = freshness(l), freshness(r)
        if lf ~= rf then
            return lf > rf
        end
        return nil
    end

    local function sortbyskinname(l, r)
        if l.skinname and r.skinname and l.skinname ~= r.skinname then
            return tostring(l.skinname) < tostring(r.skinname)
        elseif l.item and r.item then
            -- 皮肤相同根据guid排序
            return l.item.GUID < r.item.GUID
        else
            -- 这里无论如何只能返回false
            return false
        end
    end

    local ret = shallowcopy(griddata)
    if sortmode == SORTMODE.QUANTITY then
        table.sort(ret,
        function(l, r)
            -- 数量
            local result = sortbyquantity(l, r)
            if result ~= nil then return result end
            -- prefab
            result = sortbyprefab(l, r)
            if result ~= nil then return result end
            -- skinname
            return sortbyskinname(l, r)
        end)
    elseif sortmode == SORTMODE.STRING then
        table.sort(ret,
        function(l, r)
            -- prefab
            local result = sortbyprefab(l, r)
            if result ~= nil then return result end
            -- 数量
            result = sortbyquantity(l, r)
            if result ~= nil then return result end
            -- skinname
            return sortbyskinname(l, r)
        end)
    elseif sortmode == SORTMODE.TYPE then
        table.sort(ret,
        function(l, r)
            local result = sortbytype(l, r)
            if result ~= nil then return result end
            result = sortbyprefab(l, r)
            if result ~= nil then return result end
            return sortbyquantity(l, r) or sortbyskinname(l, r)
        end)
    elseif sortmode == SORTMODE.FRESHNESS then
        table.sort(ret,
        function(l, r)
            local result = sortbyfreshness(l, r)
            if result ~= nil then return result end
            result = sortbyquantity(l, r)
            if result ~= nil then return result end
            return sortbyskinname(l, r)
        end)
    end
    return ret
end

-- refresh filter/sort only
function TerminalWidget:MakeInvGrid()
    local griddata = self.griddata or {}

    -- 基础筛选（分类\搜索）
    local filter_fn = self.search_str and self.search_filter_fn or self.filter_fn
    griddata = ApplyFilter(griddata, filter_fn)

    -- 按侧边栏容器筛选
    griddata = ApplyFilter(griddata, self.sidebar_filter_fn)

    -- 排序
    griddata = SortGridData(griddata, self.sortmode)

    if not self.grid then
        local row_w = 64
        local row_h = 64
        local row_spacing = 16
        local atlas = resolvefilepath(CRAFTING_ATLAS)

        local function GridInvCtor(context, index)
            local w = Widget("terminal-inv-cell-".. index)

            local invslot = InvSlot(
                nil, 
                "images/hud.xml",
                "inv_slot.tex",
                self.owner,
                nil
            )

            invslot:SetTile(ItemTile())

            invslot:SetOnGainFocus(function()
                self:HighlightContainerIcon(invslot.container_prefab)
            end)

            -- 用于手柄兼容
            invslot.terminal_index = index
            self.inv[index] = invslot

            invslot.terminalwidget = self

            w.invslot = w:AddChild(invslot)
            w.focus_forward = w.invslot

            return w
        end

        local function GridInvSetData(context, widget, data, index)
            local invslot = widget.invslot
            local tile = invslot.tile

            local old_fakeitem = tile.fakeitem
            local old_overridequantity = tile.overridequantity

            if data then
                -- 有物品的格子
                invslot.container = data.container.replica.container
                invslot.container_prefab = data.container.prefab
                invslot.num = data.slot

                if data.item then

                    tile.fakeitem = data.item
                    tile.overridequantity = data.overridequantity
                    -- tile:Refresh()
                else

                    tile.fakeitem = nil
                    tile.overridequantity = nil
                    -- tile:Refresh()
                end

            else
                -- 空格子
                invslot.container = nil
                invslot.container_prefab = nil
                invslot.num = nil

                tile.fakeitem = nil
                tile.overridequantity = nil
                -- tile:Refresh()
            end

            if old_fakeitem ~= tile.fakeitem or old_overridequantity ~= tile.overridequantity then
                tile:Refresh()
            end

            -- 手柄兼容
            invslot.terminal_index = index
            self.inv[index] = invslot

            -- 重新聚焦
            if invslot.focus then
                invslot.ongainfocusfn()
            end
        end

        local grid = TerminalScrolllist(
        griddata,
        {
            context = {},
            widget_width  = row_w+row_spacing,
            widget_height = row_h+row_spacing,
            peek_percent     = 1,
            num_visible_rows = 6,
            num_columns      = 15,
            item_ctor_fn = GridInvCtor,
            apply_fn     = GridInvSetData,
            scrollbar_offset = 8,
            scrollbar_height_offset = -50,
            end_offset = 1,
            peek_height = -5,
        })
    
        grid.up_button:SetTextures(atlas, "scrollbar_arrow_up.tex", "scrollbar_arrow_up_hl.tex")
        grid.up_button:SetScale(0.4)
    
        grid.down_button:SetTextures(atlas, "scrollbar_arrow_down.tex", "scrollbar_arrow_down_hl.tex")
        grid.down_button:SetScale(0.4)
    
        grid.scroll_bar_line:SetTexture(atlas, "scrollbar_bar.tex")
        grid.scroll_bar_line:ScaleToSize(11, grid.scrollbar_height - 15)
    
        grid.position_marker:SetTextures(atlas, "scrollbar_handle.tex")
        grid.position_marker.image:SetTexture(atlas, "scrollbar_handle.tex")
        grid.position_marker:SetScale(.3)

        grid.custom_focus_check = function() return self.focus end

        grid:SetOnLoseFocus(function()
            self:HighlightContainerIcon(nil)
        end)

        local scale = 0.6
        self.gridroot = self.root:AddChild(Widget("GridRoot"))
        self.gridroot:SetScale(scale,scale,scale)
        self.gridroot:SetPosition(0, -30, 0)

        self.grid = self.gridroot:AddChild(grid)

        self.grid.OnFocusMove = function(self, dir, down) end
        self.grid:Show()

        self.focus_forward = self.grid
    else
        self.grid:SetItemsData(griddata)
    end

end

-- compeltely refresh
function TerminalWidget:Refresh(container, slot)
    if next(self.containers) == nil then
        self:DoCloseAction()
        return
    end

    -- 物品变动数据刷新
    self:RefreshItemPool(container, slot)
    self:RefreshGridData()

    -- UI刷新
    self:MakeInvGrid()
    self:RefreshPanel()
end

-- Move items from one player inventory source into the linked containers.
-- The operation is spread over frames so large inventories do not flood the
-- server with RPCs and each move can use the latest container state.
function TerminalWidget:StoreFromInventory(backpack_only)
    if self.store_task then
        self.store_task:Cancel()
        self.store_task = nil
    end

    local player = ThePlayer
    local inventory = player and player.replica and player.replica.inventory
    if inventory == nil or not self.isopen then
        return
    end

    local source = inventory
    if backpack_only then
        local backpack = inventory:GetOverflowContainer()
        if backpack and backpack.GetNumSlots and backpack.GetItemInSlot then
            source = backpack
        elseif backpack and backpack.replica and backpack.replica.container then
            source = backpack.replica.container
        elseif backpack and backpack.inst and backpack.inst.replica and backpack.inst.replica.container then
            source = backpack.inst.replica.container
        else
            source = nil
        end
    end
    if source == nil or source.GetNumSlots == nil then
        return
    end

    local containers = {}
    for _, container in pairs(self.containers) do
        if container and container.replica and container.replica.container then
            containers[container] = true
        end
    end

    local queue = {}
    for slot = 1, source:GetNumSlots() do
        if (backpack_only or not PROTECTED_INVENTORY_SLOTS[slot]) and
            source:GetItemInSlot(slot) ~= nil then
            table.insert(queue, slot)
        end
    end

    local index = 1
    local function move_next()
        if not self.isopen or index > #queue then
            self.store_task = nil
            return
        end

        local slot = queue[index]
        index = index + 1
        local item = source:GetItemInSlot(slot)
        if item ~= nil then
            local destination = FindBestTerminalContainer(self, item, containers)
            if destination ~= nil then
                source:MoveItemFromAllOfSlot(slot, destination)
            end
        end

        self.store_task = self.inst:DoStaticTaskInTime(FRAMES, move_next)
    end

    move_next()
end

-- close
function TerminalWidget:DoCloseAction()
    -- 客机先把ui关闭
    self:Close()
    -- 发送RPC
    local playercontroller = ThePlayer and ThePlayer.components.playercontroller
    if playercontroller then
        playercontroller:DoCloseTerminalAction()
    end
end

function TerminalWidget:Close()
    -- 关闭ui
    if self.isopen then

        self.containers = {}

        self.itempool = {}
        self.grouped_itempool = {}

        self.griddata = {}
        self.itemnum = {}

        self.inv = {}

        if self.searchbox then
            self.searchbox.textbox:SetString("")
            self:SetSearchText(nil)
        end

        self.isopen = false

        self:ClearFocus()
        self:Hide()
        self:Disable()
    end
end

-- builder count item
function TerminalWidget:CalcItemNum(prefab)
    return self.itemnum[prefab] or 0

    -- local data = self.grouped_itempool

    -- local skin_tbl = data[prefab]
    -- if skin_tbl == nil then return 0 end

    -- local num_add = 0
    -- for skinname, tbl in pairs(skin_tbl) do
    --     if tbl[0] and tbl[0] > 0 then --可堆叠物品
    --         num_add = num_add + tbl[0]
    --     else
    --         num_add = num_add + #tbl
    --     end
    -- end

    -- return num_add
end

-- sidebar fn
function TerminalWidget:HighlightContainerIcon(container_prefab)
    local inventory = ThePlayer.replica.inventory
    -- 使用预览的activeitem，如果有，不高亮侧边容器
    if inventory and inventory:GetActiveItemWithTerminalPreview() then
        container_prefab = nil
    end
    if self.sidebar then
        self.sidebar:HighlightContainerIcon(container_prefab)
    end
end

function TerminalWidget:GetUnselectContainers()
    return self.sidebar and self.sidebar.unselect_containers or {}
end

-- handle drag
function TerminalWidget:OnControl(control, down)
    if TerminalWidget._base.OnControl(self, control, down) then return true end
    if control == CONTROL_ACCEPT and down then
        self.ispressed = true
        self.startpress_time = GetTime()
        self:StartUpdating()
        return true
    else
        self.ispressed = false
    end
end

function TerminalWidget:OnUpdate(dt)
    if TheInput:IsControlPressed(CONTROL_PRIMARY) then
        if self.isdragging then
            return
        elseif GetTime() > self.startpress_time + 0.1 then
            self.isdragging = true
            self:RefreshWorldScale()
            self.drag_offset = TheInput:GetScreenPosition() - self:GetWorldPosition()
            self:FollowMouse()
        end
    else
        self.ispressed = false
        self.isdragging = false
        self:StopFollowMouse()
        self:StopUpdating()
    end
end

function TerminalWidget:FollowMouse()
    if self.followhandler == nil then
        self.followhandler = TheInput:AddMoveHandler(function(x, y) 
            self:SetWorldPositon(Vector3(x, y, 0)-self.drag_offset)
        end)
    end
end

function TerminalWidget:StopFollowMouse()
    if self.followhandler ~= nil then
        self.followhandler:Remove()
        self.followhandler = nil
    end
end

function TerminalWidget:RefreshWorldScale()
    local old_local_pt = self:GetPosition()
    local old_world_pt = self:GetWorldPosition()

    local local_offset = Vector3(10, 10, 0)
    local new_local_pt = old_local_pt + local_offset
    self:SetPosition(new_local_pt)

    local new_world_pt = self:GetWorldPosition()
    local world_offset = new_world_pt - old_world_pt

    self:SetPosition(old_local_pt)

    self.world_scale = Vector3(world_offset.x/local_offset.x, world_offset.y/local_offset.y, 0)
end

function TerminalWidget:SetWorldPositon(pos)
    if self.world_scale == nil then
        self:RefreshWorldScale()
    end
    local world_scale = self.world_scale
    local local_pt = self:GetPosition()
    local world_pt = self:GetWorldPosition()
    local world_offset = pos - world_pt
    local local_offset = Vector3(world_offset.x/world_scale.x, world_offset.y/world_scale.y, 0)
    self:SetPosition(local_pt+local_offset)
end

return TerminalWidget
