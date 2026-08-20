require "class"

local Widget = require "widgets/widget"
local Text = require "widgets/text"
local UIAnim = require "widgets/uianim"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local TEMPLATES = require "widgets/redux/templates"
local TerminalScrolllist = require "widgets/terminalscrolllist"

local HARD_IMAGE_ATALS = {
    hiddenmoonlight_inf = {image = "hiddenmoonlight.tex", atlas = "images/map_icons/hiddenmoonlight.xml"},
    chest_whitewood_inf = {image = "chest_whitewood.tex", atlas = "images/map_icons/chest_whitewood.xml"},
    chest_whitewood_big_inf = {image = "chest_whitewood_big.tex", atlas = "images/inventoryimages/chest_whitewood_big.xml"},
}

local CONTAINER_ICON_DATA = {}
local MOD_MINIMAP_ATLAS = {}

local TerminalSideBar = Class(Widget, function(self, owner, terminalwidget)
    Widget._ctor(self, "TerminalSideBar")
    self.terminalwidget = terminalwidget
    self.unselect_containers = {}
    self.prefabs_index = {}
    self:InitPanel()
    terminalwidget.sidebar_filter_fn = self:GetFilterFunction()
end)

function TerminalSideBar:GetFilterFunction()
    return function(data)
        local prefab = data and data.container and data.container.prefab
        return prefab == nil or (not self.unselect_containers[prefab])
    end
end

local function InitModMapAtlas()
    for _, atlases in ipairs(ModManager:GetPostInitData("MinimapAtlases")) do
        for _, path in ipairs(atlases) do
            table.insert(MOD_MINIMAP_ATLAS, resolvefilepath(path))
        end
    end
end

local function GetModMinimapAtlas(image)
    for i, atlas in ipairs(MOD_MINIMAP_ATLAS) do
        if TheSim:AtlasContains(atlas, image) then
            return atlas
        end
    end
end

local function GetContainerIconData(prefab)
    -- init
    if InitModMapAtlas ~= nil then
        InitModMapAtlas()
        InitModMapAtlas = nil
    end

    -- lookup
    if CONTAINER_ICON_DATA[prefab] then
        return CONTAINER_ICON_DATA[prefab]
    end

    -- default
    local data = {
        prefab = prefab,
        name = STRINGS.NAMES[string.upper(prefab)] or prefab,
        image = "treasurechest.tex",
        atlas = GetInventoryItemAtlas("treasurechest.tex"),
        default = true,
    }

    -- check hard data first
    local hard_data = HARD_IMAGE_ATALS[prefab]
    if hard_data and softresolvefilepath(hard_data.atlas) then
        data.image = hard_data.image
        data.atlas = hard_data.atlas
        data.default = false
    end

    -- check minimap atlas
    if data.default then
        local image = prefab..".png"
        local atlas = GetMinimapAtlas(image)
        if atlas then
            data.image = image
            data.atlas = atlas
            data.default = false
        end
    end

    -- check mod inv/minimap atlas
    if data.default then
        local image = prefab..".tex"
        local atlas = GetInventoryItemAtlas(image, true) or GetModMinimapAtlas(image)
        if atlas then
            data.image = image
            data.atlas = atlas
            data.default = false
        end
    end

    -- check recipe atlas
    if data.default then
        local recipe = AllRecipes[prefab]
        if recipe then
            data.image = recipe.image
            data.atlas = recipe.atlas or GetInventoryItemAtlas(data.image)
            data.default = false
        end
    end

    -- recheck recipe atlas
    if data.default then
        for recipe_name, recipe in pairs(AllRecipes) do
            if recipe.product == prefab then
                data.image = recipe.image
                data.atlas = recipe.atlas or GetInventoryItemAtlas(data.image)
                data.default = false
                break
            end
        end
    end

    -- return anything we found
    CONTAINER_ICON_DATA[prefab] = data
    return data
end

function TerminalSideBar:TrySeeContainerIcon(prefab)
    -- true means we do nothing here
    if prefab == nil then return true end

    local index = self.prefabs_index[prefab]
    if index == nil then return true end

    local start_index = self.grid.displayed_start_index
    local end_index = start_index + self.grid.visible_rows

    if index >= start_index and index <= end_index then
        return true
    end

    self.grid:ScrollToScrollPos(index + 1) -- row = index + 1
    return false
end

function TerminalSideBar:HighlightContainerIcon(prefab)
    if self.highlight_prefab == prefab then return end
    self.highlight_prefab = prefab

    if self:TrySeeContainerIcon(prefab) then
        self.grid:RefreshView(true) --强制刷新
    end
end

function TerminalSideBar:OnButtonClick(prefab, control)
    if prefab == nil then return end

    if control == CONTROL_ACCEPT then
        -- 切换状态
        if self.unselect_containers[prefab] then
            self.unselect_containers[prefab] = false
        else
            self.unselect_containers[prefab] = true
        end
    elseif control == CONTROL_SECONDARY then
        -- 先将其他容器置为相反状态
        local state = not self.unselect_containers[prefab]
        for v in pairs(self.prefabs_index) do
            if v ~= prefab then
                self.unselect_containers[v] = state
            end
        end
        -- 如果state为false
        if not state then
            self.unselect_containers[prefab] = false
        end
    end
    
    -- 强制刷新
    self.grid:RefreshView(true)
    -- 刷新终端显示
    self.terminalwidget:MakeInvGrid()
    self.terminalwidget:RefreshPanel()
end

function TerminalSideBar:InitPanel()
    self.prefabs_index = {}
    local prefabs = self:GetContainerPrefabs()
    local griddata = {}

    local index = 0 -- index start from 0
    for prefab in pairs(prefabs) do
        local data = GetContainerIconData(prefab)
        table.insert(griddata, data)
        self.prefabs_index[prefab] = index
        index = index + 1
    end

    if not self.grid then
        local atlas = resolvefilepath(CRAFTING_ATLAS)

        local function GridInvCtor(context, index)
            local w = Widget("terminal-inv-cell-".. index)
            local button = w:AddChild(ImageButton(atlas, "filterslot_frame.tex", "filterslot_frame_highlight.tex")) -- , nil, nil, "filterslot_frame_select.tex"
            w.button = button

            local old_OnControl = button.OnControl
            button.OnControl = function(button, control, ...)
                if control == CONTROL_ACCEPT or control == CONTROL_SECONDARY then
                    button.control = control
                end
                return old_OnControl(button, control, ...)
            end
            
            button:SetOnClick(function()
                self:OnButtonClick(w.prefab, button.control)
            end)
            
            w.image = button:AddChild(Image(GetInventoryItemAtlas("treasurechest.tex"), "treasurechest.tex"))
            local imagescale = 0.8
            w.image:SetScale(imagescale, imagescale, imagescale)

            w.text = button:AddChild(Text(UIFONT, 24))
    
            w.bg = button:AddChild(Image(atlas, "filterslot_bg.tex")); local bgscale = 1.05
            -- w.bg = button:AddChild(Image(atlas, "slot_bg.tex")); local bgscale = 0.55

            w.bg:SetScale(bgscale, bgscale, bgscale)
            w.bg:MoveToBack()
            return w
        end
    
        local function GridInvSetData(context, widget, data, index)
            local image = widget.image
            local button = widget.button
            local text = widget.text
            local bg = widget.bg

            if data then
                if data.default then
                    image:Hide()
                    text:SetMultilineTruncatedString(data.name, 3, 65, 15)
                else
                    image:Show()
                    image:SetTexture(resolvefilepath(data.atlas), data.image)
                    text:SetString("")
                end

                widget:SetTooltip(data.name)

                local prefab = data.prefab
                if self.unselect_containers[prefab] then
                    image:SetTint(1, 0, 0, 0.75)
                    text:SetColour(1, 0, 0, 0.75)
                else
                    image:SetTint(1, 1, 1, 1)
                    text:SetColour(1, 1, 1, 1)
                end
    
                if prefab == self.highlight_prefab then
                    button:OnGainFocus()
                else
                    button:OnLoseFocus()
                end

            else
                image:Hide()
                widget:SetTooltip(nil)
                text:SetString("")
            end

            if button.focus then
                button:OnGainFocus()
            end

            widget.prefab = data and data.prefab
        end
    
        local row_w = 64
        local row_h = 64
        local row_spacing = 16
    
        local grid = TerminalScrolllist(
        griddata,
        {
            context = {},
            widget_width  = row_w+row_spacing,
            widget_height = row_h+row_spacing,
            peek_percent     = 1,
            num_visible_rows = 6,
            num_columns      = 1,
            item_ctor_fn = GridInvCtor,
            apply_fn     = GridInvSetData,
            scrollbar_offset = -40,
            scrollbar_height_offset = 40,
            end_offset = 0,
            peek_height = -5,
        })
    
        grid.up_button:SetTextures(atlas, "scrollbar_arrow_up.tex", "scrollbar_arrow_up_hl.tex")
        grid.up_button:SetScale(1)
    
        grid.down_button:SetTextures(atlas, "scrollbar_arrow_down.tex", "scrollbar_arrow_down_hl.tex")
        grid.down_button:SetScale(1)
    
        grid.scroll_bar_line:Hide()
        grid.position_marker:Hide()
        grid.scroll_bar:Hide()
    
        grid.position_marker:Disable()
        grid.scroll_bar:Disable()
    
        grid.OnFocusMove = function(self, dir, down) end
    
        local scale = 0.7
        self.gridroot = self:AddChild(Widget("GridRoot"))
        self.gridroot:SetScale(scale, scale, scale)
    
        self.grid = self.gridroot:AddChild(grid)
    else
        self.grid:SetItemsData(griddata)
    end

end

function TerminalSideBar:GetContainerPrefabs()
    local containers = self:GetContasiners()
    local prefabs = {}
    for guid, container in pairs(containers) do
        prefabs[container.prefab] = true
    end
    return prefabs
end

function TerminalSideBar:GetContasiners()
    return self.terminalwidget.containers
end

return TerminalSideBar