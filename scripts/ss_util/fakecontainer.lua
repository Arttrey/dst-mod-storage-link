local params = require("containers").params
local FNS = require("ss_util/fakeitem")

local function GetTableSize(table)
	local numItems = 0
	if table ~= nil then
		for _ in pairs(table) do
		    numItems = numItems + 1
		end
	end
	return numItems
end

-- Server side
local FakeItem = FNS.FakeItem

local function IsPreserver(inst)
    if inst:HasAnyTag("fridge", "foodpreserver") then
        return true
    end
    if inst.components.preserver then
        return true
    end
    return false
end

local function FakeContainer(inst)
    local container = inst.components.container
    local ret = {
        GUID = inst.GUID,
        prefab = inst.prefab,
        ispreserver = IsPreserver(inst),
        replica = {
            container = {
                numslots = container.numslots,
                slots = {},
                acceptsstacks = container.acceptsstacks,
                infinitestacksize = container.infinitestacksize,
                widgetprefab = container.widgetprefab,
            },
        },
    }

    for i = 1, container.numslots do
        local item = container:GetItemInSlot(i)
        if item then
            ret.replica.container.slots[i] = FakeItem(item)
        else
            ret.replica.container.slots[i] = "nil"
        end
    end

    return ret
end

-- Client side
local ModifyFakeItem = FNS.ModifyFakeItem

local ReturnFalse = function()
    return false
end

local ReturnTrue = function()
    return true
end

-- inst fns
local HasTag = function(inst, tag)
    return tag == "chest"
end

-- Container fns
local IsInfiniteStackSize = function(self)
    return self.infinitestacksize
end

local GetNumSlots = function(self)
    return self.numslots
end

local GetItemInSlot = function(self, slot)
    return self.slots[slot]
end

local GetItems = function(self)
    return self.slots
end

local GetWidget = function(self)
    return {}
end

local CanTakeItemInSlot = function(self, item, slot)
    return item ~= nil
    and item.replica.inventoryitem ~= nil
    and item.replica.inventoryitem:CanGoInContainer()
    and not item.replica.inventoryitem:CanOnlyGoInPocket()
    and not item.replica.inventoryitem:CanOnlyGoInPocketOrPocketContainers()
    and (self.itemtestfn == nil or self:itemtestfn(item, slot))
end

local AcceptsStacks = function(self)
    return self.acceptsstacks
end

local Has = function(self, prefab, amount, iscrafting)
    local num_found = 0
    for k,v in pairs(self.slots) do
        if v and v.prefab == prefab and not (iscrafting and v:HasTag("nocrafting")) then
            if v.replica.stackable then
                num_found = num_found + v.replica.stackable:StackSize()
            else
                num_found = num_found + 1
            end
        end
    end
    return num_found >= amount, num_found
end

local IsFull = function(self)
    return GetTableSize(self.slots) >= self.numslots
end

local IsEmpty = function(self)
    return GetTableSize(self.slots) == 0
end

local HasItemWithTag = function(self, tag, amount)
    local num_found = 0
    for k,v in pairs(self.slots) do
        if v and v:HasTag(tag) then
            if v.replica.stackable then
                num_found = num_found + v.replica.stackable:StackSize()
            else
                num_found = num_found + 1
            end
        end
    end
    return num_found >= amount, num_found
end

local MoveItemFromHalfOfSlot = function(self, slot, container)
    if TheWorld.ismastersim then
        local trueinst = Ents[self.inst.GUID]
        if trueinst and trueinst:IsValid() then
            trueinst.components.container:MoveItemFromHalfOfSlot(slot, container, ThePlayer)
        end
    else
        local guid = self.inst.GUID
        SendModRPCToServer(MOD_RPC["SimpleStorage"]["Container:MoveItemFromHalfOfSlot"], guid, slot, container)
    end
end

local MoveItemFromAllOfSlot = function(self, slot, container)
    if TheWorld.ismastersim then
        local trueinst = Ents[self.inst.GUID]
        if trueinst and trueinst:IsValid() then
            trueinst.components.container:MoveItemFromAllOfSlot(slot, container, ThePlayer)
        end
    else
        local guid = self.inst.GUID
        SendModRPCToServer(MOD_RPC["SimpleStorage"]["Container:MoveItemFromAllOfSlot"], guid, slot, container)
    end
end

local TakeActiveItemFromHalfOfSlot = function(self, slot)
    if TheWorld.ismastersim then
        local trueinst = Ents[self.inst.GUID]
        if trueinst and trueinst:IsValid() then
            trueinst.components.container:TakeActiveItemFromHalfOfSlot(slot, ThePlayer)
        end
    else
        local guid = self.inst.GUID
        SendModRPCToServer(MOD_RPC["SimpleStorage"]["Container:TakeActiveItemFromHalfOfSlot"], guid, slot)
    end
end

local TakeActiveItemFromAllOfSlot = function(self, slot)
    if TheWorld.ismastersim then
        local trueinst = Ents[self.inst.GUID]
        if trueinst and trueinst:IsValid() then
            trueinst.components.container:TakeActiveItemFromAllOfSlot(slot, ThePlayer)
        end
    else
        local guid = self.inst.GUID
        SendModRPCToServer(MOD_RPC["SimpleStorage"]["Container:TakeActiveItemFromAllOfSlot"], guid, slot)
    end
end

local inst_meta = {
    __index = {
        IsValid = ReturnTrue,
        -- 对于容器，不处理任何标签
        HasTag = ReturnFalse,
        HasTags = ReturnFalse,
        HasAllTags = ReturnFalse,
        HasOneOfTags = ReturnFalse,
        HasAnyTag = ReturnFalse,
    }
}

local container_meta = {
    __index = {
        -- 基本容器函数
        Open = ReturnFalse,
        Close = ReturnFalse,
        IsBusy = ReturnFalse,
        IsSideWidget = ReturnFalse,
        IsOpenedBy = ReturnTrue,
        CanBeOpened = ReturnTrue,
        IsInfiniteStackSize = IsInfiniteStackSize,
        IsReadOnlyContainer = ReturnFalse,
        ShouldPrioritizeContainer = ReturnFalse,
        -- 获取容器信息
        GetNumSlots = GetNumSlots,
        GetItemInSlot = GetItemInSlot,
        GetItems = GetItems,
        GetWidget = GetWidget,
        -- 物品检测
        CanTakeItemInSlot = CanTakeItemInSlot,
        AcceptsStacks = AcceptsStacks,
        Has = Has,
        IsFull = IsFull,
        IsEmpty = IsEmpty,
        HasItemWithTag = HasItemWithTag,
        -- 拿取物品相关
        MoveItemFromHalfOfSlot = MoveItemFromHalfOfSlot,
        MoveItemFromAllOfSlot = MoveItemFromAllOfSlot,
        TakeActiveItemFromHalfOfSlot = TakeActiveItemFromHalfOfSlot,
        TakeActiveItemFromAllOfSlot = TakeActiveItemFromAllOfSlot,
    }
}

local function ModifyFakeContainer(inst)
    inst.IsFake = true
    setmetatable(inst, inst_meta)
    -- container_replica
    local container = inst.replica.container
    container.inst = inst
    setmetatable(container, container_meta)
    local widgetprefab = container.widgetprefab or inst.prefab
    container.itemtestfn = params[widgetprefab] and params[widgetprefab].itemtestfn
    -- ModifyFakeItem
    for i = 1, container.numslots do
        local item = container.slots[i]
        if item ~= "nil" then
            ModifyFakeItem(item)
        else
            container.slots[i] = nil
        end
    end
end

return {
    FakeContainer = FakeContainer,
    ModifyFakeContainer = ModifyFakeContainer
}
