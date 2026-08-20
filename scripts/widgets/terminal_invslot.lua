local ItemSlot = require "widgets/itemslot"
local ItemTile = require "widgets/terminal_itemtile"

local InvSlot = Class(ItemSlot, function(self, num, atlas, bgim, owner, container)
    ItemSlot._ctor(self, atlas, bgim, owner)
    self.owner = owner
    self.container = container
    self.num = num
    self.is_terminal_slot = true
end)

function InvSlot:OnControl(control, down)
    if InvSlot._base.OnControl(self, control, down) then return true end
    if not down then
        return false
    end
    if control == CONTROL_ACCEPT then
        --generic click, with possible modifiers
        if TheInput:IsControlPressed(CONTROL_FORCE_TRADE) then
            if self:CanTradeItem() then
                self:TradeItem(TheInput:IsControlPressed(CONTROL_FORCE_STACK))
            else
                return false
            end
        else
            self:Click(TheInput:IsControlPressed(CONTROL_FORCE_STACK))
        end
    elseif control == CONTROL_SECONDARY then
        local active_item = ThePlayer.replica.inventory and ThePlayer.replica.inventory:GetActiveItem()
        if active_item == nil then
            if TheInput:IsControlPressed(CONTROL_FORCE_TRADE) then
                self:DropItem(TheInput:IsControlPressed(CONTROL_FORCE_STACK))
            else
                self:UseItem()
            end
        else
            return false
        end
        --the rest are explicit control presses for controllers
    elseif control == CONTROL_SPLITSTACK then
        self:Click(true)
    elseif control == CONTROL_TRADEITEM then
        if self:CanTradeItem() then
            self:TradeItem(false)
        else
            return false
        end
    elseif control == CONTROL_TRADESTACK then
        if self:CanTradeItem() then
            self:TradeItem(true)
        else
            return false
        end
    elseif control == CONTROL_INSPECT then
        return false --检查功能禁用
    else
        return false
    end
    return true
end

function InvSlot:OnRawKey(key, down)
    if not self.focus then return false end
    if down and key == KEY_F then
        self:ToggleFavorite()
        return true
    end
end

local FindBestContainer = FindBestTerminalContainer

function InvSlot:Click(stack_mod)
    local slot_number = self.num
    local character = ThePlayer
    local inventory = character and character.replica.inventory or nil
    if inventory == nil then return end

    local active_item = inventory and inventory:GetActiveItem() or nil
    local container = self.container
    local container_item = container and container:GetItemInSlot(slot_number) or nil

    if active_item ~= nil or container_item ~= nil then
        if active_item == nil then
            --拿起格子内物品
            local takehalf = false
            if stack_mod and
                container_item.replica.stackable ~= nil and
                container_item.replica.stackable:IsStack() then
                --Take half stack
                container:TakeActiveItemFromHalfOfSlot(slot_number)
                takehalf = true
            else
                --Take entire stack
                container:TakeActiveItemFromAllOfSlot(slot_number)
            end
            -- 预览
            self:PreviewTakeActiveItemFromTerminal(inventory, container_item, takehalf)
            TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_object")
        else
            --放入物品到一个最优的容器内
            local terminal_containers = self.terminalwidget.containers
            local containers = {}
            for guid, container in pairs(terminal_containers) do
                containers[container] = true
            end
            local dest_inst = FindBestContainer(self, active_item, containers)
            if dest_inst then
                -- 调用两个新加的inventory接口
                local putone =false
                if stack_mod and
                active_item.replica.stackable ~= nil and
                active_item.replica.stackable:IsStack() then
                    inventory:MoveItemFromOneOfActive(dest_inst)
                    putone = true
                else
                    inventory:MoveItemFromAllOfActive(dest_inst)
                end
                -- 预览
                local container = dest_inst.replica.container
                self:PreviewPutActiveItemToTerminal(inventory, container, putone)
                TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_object")
            else
                TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
            end
        end
    end
end

function InvSlot:PreviewTakeActiveItemFromTerminal(inventory, item, half)
    local classified = inventory.classified
    if TheWorld.ismastersim or classified == nil then return end

    classified:PreviewTakeActiveItemFromTerminal(item, half)
end

function InvSlot:PreviewPutActiveItemToTerminal(inventory, container, one)
    local classified = inventory.classified
    if TheWorld.ismastersim or classified == nil then return end

    classified:PreviewPutActiveItemToTerminal(container, one)
end

function InvSlot:CanTradeItem()
    if self.container == nil then return false end
    local item = self.container and self.container:GetItemInSlot(self.num) or nil
    return item ~= nil
end

function InvSlot:TradeItem(stack_mod)

    local slot_number = self.num
    local character = ThePlayer
    local inventory = character and character.replica.inventory or nil
    local container = self.container
    local container_item = container and container:GetItemInSlot(slot_number) or nil

    if character ~= nil and inventory ~= nil and container_item ~= nil then
        local opencontainers = inventory:GetOpenContainers()
        -- print("=============================")
        -- for k, v in pairs(opencontainers) do
        --     print("opencontainers:", k, v)
        -- end

        local overflow = inventory:GetOverflowContainer()
        local backpack = nil
        if overflow ~= nil --[[and overflow:IsOpenedBy(character)]] then
            backpack = overflow.inst
            overflow = backpack.replica.container
            if overflow == nil then
                backpack = nil
            end
        else
            overflow = nil
        end

        local exclude_containers = {}
        for guid, container in pairs(self.terminalwidget.containers) do
            exclude_containers[container] = true
        end
        if backpack then
            exclude_containers[backpack] = true
        end

        local dest_inst = FindBestContainer(self, container_item, opencontainers, exclude_containers) or
        (inventory:IsOpenedBy(character) and character or backpack)

        -- print("dest_inst:", dest_inst)

        if dest_inst ~= nil then
            if stack_mod and
                container_item.replica.stackable ~= nil and
                container_item.replica.stackable:IsStack() then
                container:MoveItemFromHalfOfSlot(slot_number, dest_inst)
            else
                container:MoveItemFromAllOfSlot(slot_number, dest_inst)
            end
            TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_object")
        else
            TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
        end
    end
end

function InvSlot:DropItem(single)
    if self.owner and self.owner.replica.inventory and self.tile and self.tile.fakeitem then
		self.owner.replica.inventory:DropItemFromInvTile(self.tile.fakeitem, single)
    end
end

function InvSlot:UseItem()
    if self.tile ~= nil and self.tile.fakeitem ~= nil then
        local inventory = ThePlayer and ThePlayer.replica.inventory
        if inventory then
            inventory:UseItemFromInvTile(self.tile.fakeitem)
        end
    end
end

function InvSlot:ToggleFavorite()
    if self.tile and self.tile.fakeitem then
        self.terminalwidget:ToggleFavorite(self.tile)
    end
end

return InvSlot
