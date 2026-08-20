--------------------------------------------------------------------------
-- 手柄兼容性能模式
--------------------------------------------------------------------------
AddComponentPostInit("playercontroller", function(self)

    -- 这个不用修改
    -- local old_DoControllerDropItemFromInvTile = self.DoControllerDropItemFromInvTile

    -- Use invitem -> Scene target
    local old_DoControllerUseItemOnSceneFromInvTile = self.DoControllerUseItemOnSceneFromInvTile
    function self:DoControllerUseItemOnSceneFromInvTile(item)
        item = item or self:GetCursorInventoryObject()
        if item and item.IsFake then
            -- 从终端移动到玩家身上
            local slot, container = self:GetCursorInventorySlotAndContainer()
            -- container.IsFake == true
            if slot and container then
                container:MoveItemFromAllOfSlot(slot, self.inst)
            end
            return
        elseif item and self.inst:IsUsingSimpleStorage() and item.replica.inventoryitem:IsGrandOwner(self.inst) then
            -- 从玩家身上/背包移到终端
            if TheWorld.ismastersim then
                BufferedAction(self.inst, nil, ACTIONS.CONTROLLER_STORE_TERMINAL, item):Do()
            else
                SendModRPCToServer(MOD_RPC["SimpleStorage"]["ACTIONS.CONTROLLER_STORE_TERMINAL"], item)
            end
            return
        end
        return old_DoControllerUseItemOnSceneFromInvTile(self, item)
    end

    -- Inv action
    local old_DoControllerUseItemOnSelfFromInvTile = self.DoControllerUseItemOnSelfFromInvTile
    function self:DoControllerUseItemOnSelfFromInvTile(item)
        -- 执行动作
        item = item or self:GetCursorInventoryObject()
        if item and item.IsFake then
            local inventory = self.inst.replica.inventory
            inventory:UseItemFromInvTile(item)
            return
        end
        return old_DoControllerUseItemOnSelfFromInvTile(self, item)
    end

    -- Inspect
    local old_DoControllerInspectItemFromInvTile = self.DoControllerInspectItemFromInvTile
    function self:DoControllerInspectItemFromInvTile(item)
        if item and item.IsFake then
            -- FakeItem禁用检查
            return
        end
        return old_DoControllerInspectItemFromInvTile(self, item)
    end

    -- 动作收集
    local old_GetItemUseAction = self.GetItemUseAction
    function self:GetItemUseAction(active_item, target)
        if active_item then
            if active_item.IsFake then
                return
            elseif self.inst:IsUsingSimpleStorage() and active_item.replica.inventoryitem:IsGrandOwner(self.inst) then
                -- 移动身上/背包物品到终端
                return BufferedAction(self.inst, nil, ACTIONS.CONTROLLER_STORE_TERMINAL, active_item)
            end
        end
        return old_GetItemUseAction(self, active_item, target)
    end

    local old_GetItemSelfAction = self.GetItemSelfAction
    function self:GetItemSelfAction(item)
        if item and item.IsFake then
            return
        end
        return old_GetItemSelfAction(self, item)
    end
end)

AddClassPostConstruct("components/inventory_replica", function(self)

    local old_ControllerUseItemOnItemFromInvTile = self.ControllerUseItemOnItemFromInvTile
    function self:ControllerUseItemOnItemFromInvTile(inv_item, active_item)
        if inv_item and inv_item.IsFake then
            -- 禁止物品对FakeItem动作
            return
        end
        return old_ControllerUseItemOnItemFromInvTile(self, inv_item, active_item)
    end
end)

--------------------------------------------------------------------------
-- 手柄光标访问终端
--------------------------------------------------------------------------
local function UpdateCursorText(self)
    -- 兼容FakeItem
    local W = 68
    local TIP_YFUDGE = 16
    local CURSOR_STRING_DELAY = 10

    local inv_item = self:GetCursorItem()

    local active_item = self.cursortile and self.cursortile.item
    if active_item and active_item.replica.inventoryitem == nil then
        active_item = nil
    end

    if inv_item == nil and active_item == nil then
        self.actionstringtitle:SetString("")
        self.actionstringbody:SetString("")
        self.actionstring:Hide()
        return
    end

    local controller_id = TheInput:GetControllerID()

    if inv_item then
        local itemname = self:GetDescriptionString(inv_item)
        self.actionstringtitle:SetString(itemname)
    elseif active_item then
        local itemname = self:GetDescriptionString(active_item)
        self.actionstringtitle:SetString(itemname)
    end
    self:SetTooltipColour(unpack(NORMAL_TEXT_COLOUR))

    local str = {}

    if not self.open and inv_item then
        -- 左键：拿取
        table.insert(str, TheInput:GetLocalizedControl(controller_id, CONTROL_INVENTORY_USEONSCENE) .. " " .. STRINGS.UI.HUD.TAKE)

        -- 右键：操作
        if inv_item.IsFake then
            table.insert(str, TheInput:GetLocalizedControl(controller_id, CONTROL_INVENTORY_USEONSELF) .. " " .. STRINGS.UNKNOWACTION)
        else
            local self_action = self.owner.components.playercontroller:GetItemSelfAction(inv_item)
            if self_action then
                table.insert(str, TheInput:GetLocalizedControl(controller_id, CONTROL_INVENTORY_USEONSELF) .. " " .. self_action:GetActionString())
            end
        end

        -- 下键：丢弃
        table.insert(str, TheInput:GetLocalizedControl(controller_id, CONTROL_INVENTORY_DROP) .. " " .. STRINGS.ACTIONS.DROP.GENERIC)
    else

        if active_item == nil and inv_item then
            --Y：收藏
            table.insert(str, TheInput:GetLocalizedControl(controller_id, CONTROL_USE_ITEM_ON_ITEM) .. " " .. STRINGS.UI.CRAFTING_MENU.SORTING.FAVORITE)
        end

        if active_item and active_item.replica.stackable and active_item.replica.stackable:IsStack() then
            --X：放一个
            table.insert(str, TheInput:GetLocalizedControl(controller_id, CONTROL_PUTSTACK) .. " " .. STRINGS.UI.HUD.PUTONE)
        end
        if active_item == nil and inv_item and inv_item.replica.stackable and inv_item.replica.stackable:IsStack() then
            -- X：拿一半
            table.insert(str, TheInput:GetLocalizedControl(controller_id, CONTROL_PUTSTACK) .. " " .. STRINGS.UI.HUD.GETHALF)
        end

        if active_item == nil and inv_item then
            -- A：选择
            table.insert(str, TheInput:GetLocalizedControl(controller_id, CONTROL_ACCEPT) .. " " .. STRINGS.UI.HUD.SELECT)

            -- 下键：丢弃
            table.insert(str, TheInput:GetLocalizedControl(controller_id, CONTROL_INVENTORY_DROP) .. " " .. STRINGS.ACTIONS.DROP.GENERIC)
        elseif active_item then
            -- A：放入
            table.insert(str, TheInput:GetLocalizedControl(controller_id, CONTROL_ACCEPT) .. " " .. STRINGS.UI.HUD.PUT)
        end

    end

    local was_shown = self.actionstring.shown
    local old_string = self.actionstringbody:GetString()
    local new_string = table.concat(str, '\n')
    if old_string ~= new_string then
        self.actionstringbody:SetString(new_string)
        self.actionstringtime = CURSOR_STRING_DELAY
        self.actionstring:Show()
    end

    local w0, h0 = self.actionstringtitle:GetRegionSize()
    local w1, h1 = self.actionstringbody:GetRegionSize()

    local wmax = math.max(w0, w1)

    local dest_pos = self.active_slot:GetWorldPosition()

    local xscale, yscale, zscale = self.root:GetScale():Get()

    self.actionstringtitle:SetPosition(0, h0/2 + h1)
    self.actionstringbody:SetPosition(0, h1/2)
    dest_pos.y = dest_pos.y + (W/2 + TIP_YFUDGE) * yscale

    if dest_pos:DistSq(self.actionstring:GetPosition()) > 1 then
        self.actionstringtime = CURSOR_STRING_DELAY
        if was_shown then
            self.actionstring:MoveTo(self.actionstring:GetPosition(), dest_pos, .1)
        else
            self.actionstring:SetPosition(dest_pos)
            self.actionstring:Show()
        end
    end

end

AddClassPostConstruct("widgets/inventorybar", function(self)

    local old_GetInventoryLists = self.GetInventoryLists
    function self:GetInventoryLists(same_container_only)
        local lists = old_GetInventoryLists(self, same_container_only)
        if not same_container_only then
            local terminalwidget = ThePlayer and ThePlayer.HUD.terminalwidget
            if terminalwidget and terminalwidget.isopen then
                -- 物品格子
                local start_index = terminalwidget.grid.displayed_start_index or 0
                local inv = {}
                for i = 1, 7*15 do
                    inv[i] = terminalwidget.inv[i+start_index]
                end
                table.insert(lists, inv)
                -- 背景按钮 和 筛选按钮
                if not self.open then
                    table.insert(lists, terminalwidget.bgbuttons)
                    table.insert(lists, terminalwidget.filterbuttons)
                end
            end
        end
        return lists
    end

    -- 兼容滚动
    local old_CursorUp = self.CursorUp
    function self:CursorUp()
        local terminal_index = self.active_slot and self.active_slot.terminal_index
        if terminal_index then
            local grid = ThePlayer.HUD.terminalwidget.grid
            local start_index = grid.displayed_start_index
            local layout_index = terminal_index - start_index
            if layout_index >= 1 and layout_index <= 15 then -- 硬编码
                if grid.current_scroll_pos ~= 1 then
                    grid:Scroll(-1)
                    return
                end
            end
        end
        return old_CursorUp(self)
    end

    local old_CursorDown = self.CursorDown
    function self:CursorDown()
        local terminal_index = self.active_slot and self.active_slot.terminal_index
        if terminal_index then
            local grid = ThePlayer.HUD.terminalwidget.grid
            local start_index = grid.displayed_start_index
            local layout_index = terminal_index - start_index
            if layout_index >= 91 and layout_index <= 105 then -- 硬编码
                if grid.current_scroll_pos < grid.end_pos then
                    grid:Scroll(1)
                    return
                end
            end
        end
        return old_CursorDown(self)
    end

    -- 兼容FakeItem
    local old_GetCursorItem = self.GetCursorItem
    function self:GetCursorItem()
        if self.active_slot and self.active_slot.tile and self.active_slot.tile.fakeitem then
            return self.active_slot.tile.fakeitem
        end
        return old_GetCursorItem(self)
    end

    -- CursorText
    local old_UpdateCursorText = self.UpdateCursorText
    function self:UpdateCursorText()
        -- 终端内物品格
        if self.active_slot and self.active_slot.is_terminal_slot then
            return UpdateCursorText(self)
        end
        -- 按钮
        if self.active_slot and self.active_slot.container == nil then
            self.actionstringtitle:SetString("")
            self.actionstringbody:SetString("")
            self.actionstring:Hide()
            return
        end
        return old_UpdateCursorText(self)
    end

    -- 缩放终端
    local old_OpenControllerInventory = self.OpenControllerInventory
    function self:OpenControllerInventory()
        if not self.open then
            -- 缩放
            local terminalwidget = ThePlayer.HUD.terminalwidget
            if terminalwidget then
                terminalwidget:ScaleTo(1, self.selected_scale/self.base_scale, 0.2)
            end
            -- 从按钮上移开
            if self.active_slot then
                if self.active_slot.is_terminal_button then
                    self:CursorUp()
                elseif self.active_slot.is_terminal_filter then
                    self:CursorDown()
                end
            end
        end
        return old_OpenControllerInventory(self)
    end

    local old_CloseControllerInventory = self.CloseControllerInventory
    function self:CloseControllerInventory()
        if self.open then
            -- 缩放
            local terminalwidget = ThePlayer.HUD.terminalwidget
            if terminalwidget then
                terminalwidget:ScaleTo(self.selected_scale/self.base_scale, 1, 0.1)
            end
        end
        return old_CloseControllerInventory(self)
    end

    -- Y: 收藏
    local old_OnControl = self.OnControl
    function self:OnControl(control, down)
        local active_item = self.owner.replica.inventory:GetActiveItem()
        local inv_item = self:GetCursorItem()
        if self.open and (not down) and control == CONTROL_USE_ITEM_ON_ITEM and active_item == nil and inv_item then
            if self.active_slot and self.active_slot.ToggleFavorite then
                self.active_slot:ToggleFavorite()
                return true
            end
        end
        return old_OnControl(self, control, down)
    end
end)

--------------------------------------------------------------------------
-- 手柄存放物品到终端动作
--------------------------------------------------------------------------
-- run on server
local function FindBestContainer(item, containers, exclude_containers)
    -- 这里由主机执行
    if item == nil or containers == nil then
        return
    end

    local containerwithsameitem = nil
    local containerwithemptyslot = nil
    local containerwithnonstackableslot = nil
    local containerwithlowpirority = nil

    for k, v in pairs(containers) do
        if exclude_containers == nil or not exclude_containers[k] then
            local container = k.replica.container or k.replica.inventory
            if container ~= nil and container:CanTakeItemInSlot(item) then
                local isfull = container:IsFull()
                if container:AcceptsStacks() then
                    -- 有空格子
                    if not isfull and containerwithemptyslot == nil then
                        -- 低优先级 或 无限堆叠的容器
                        local islowpirority = container.lowpriorityselection or (container.IsInfiniteStackSize and container:IsInfiniteStackSize())
                        if islowpirority then
                            containerwithlowpirority = k
                        else
                            containerwithemptyslot = k
                        end
                    end
                    -- 有相同物品
                    for k1, v1 in pairs(container:GetItems()) do
                        -- 主机直接判断skinname
                        if v1.prefab == item.prefab and v1.skinname == item.skinname then
                            if v1.replica.stackable ~= nil and not v1.replica.stackable:IsFull() then
                                if container.lowpriorityselection then
                                    containerwithlowpirority = k
                                else
                                    return k
                                end
                            elseif not isfull and containerwithsameitem == nil then
                                containerwithsameitem = k
                            end
                        end
                    end
                -- 不接受堆叠
                elseif not isfull and containerwithnonstackableslot == nil then
                    containerwithnonstackableslot = k
                end
            end
        end
    end

    -- 最优先：相同可堆叠未满的物品
    -- 优先级：相同物品 > 空格子 > 非堆叠格子 > 低优先级
    return containerwithsameitem or containerwithemptyslot or containerwithnonstackableslot or containerwithlowpirority
end

AddAction("CONTROLLER_STORE_TERMINAL", STRINGS.ACTIONS.STORE.GENERIC, function(act)
    local item = act.invobject
    if item == nil or not item:IsValid() then
        return
    end

    local containers = {}
    local inventory = act.doer.components.inventory
    if inventory then
        for k, _ in pairs(inventory.opencontainers) do
            if k.components.container.type == "chest" then
                containers[k] = true
            end
        end
        for k, _ in pairs(inventory.fake_opencontainers or {}) do
            containers[k] = true
        end
    end

    local dest = FindBestContainer(item, containers)
    if dest == nil then
        return
    end

    local owner = item.components.inventoryitem.owner
    local container = owner and owner.components.container or owner.components.inventory
    if container == nil then
        return
    end

    local slot = container:GetItemSlot(item)
    if slot then
        container:MoveItemFromAllOfSlot(slot, dest, act.doer)
        --对于inventory第三个参数是多余的
    end

end)

AddModRPCHandler("SimpleStorage", "ACTIONS.CONTROLLER_STORE_TERMINAL",function(player, item)
    if not checkentity(item) then
        return
    end
    BufferedAction(player, nil, ACTIONS.CONTROLLER_STORE_TERMINAL, item):Do()
end)
