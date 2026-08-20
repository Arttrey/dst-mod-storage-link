require("constants")
require("simutil")

local GetInventoryItemAtlas = GetInventoryItemAtlas

-- Server side
local function FakeItem(item)

    local classified = item.replica.inventoryitem.classified
    local image = classified and classified.image:value() ~= 0 and classified.image:value() or item.prefab..".tex"
    local atlas = classified and classified.atlas:value() ~= 0 and classified.atlas:value() or GetInventoryItemAtlas(image)

    local ret = {
        GUID = item.GUID,
        prefab = item.prefab,
        skinname = item.skinname,
        name = item:GetBasicDisplayName(),
        AnimState = {
            skinbuild = item.AnimState and item.AnimState:GetSkinBuild() or "",
        },
        replica = {
            stackable = item.components.stackable and
            {
                stacksize = item.components.stackable:StackSize(),
                maxsize = item.components.stackable.maxsize >= math.huge and "inf" or item.components.stackable.maxsize,
                originalmaxsize = item.components.stackable.originalmaxsize,
            } or nil,
            inventoryitem = {
                atlas = atlas,
                image = image,
            },
        },
        components = {},
        adjective = item:GetAdjective(),
        inv_image_bg = item.inv_image_bg,
        tags = item.tags_backup or {},
        hasspoilage = false,
        warable = false,
    }

    local equipslot = item.replica.equippable and item.replica.equippable:EquipSlot()
    if equipslot then
        ret.warable = (equipslot == EQUIPSLOTS.BODY or equipslot == EQUIPSLOTS.HEAD)
    end

    if item.components.armor then
        ret.components.armor = {
            percent = item.components.armor:GetPercent()
        }
    elseif item.components.perishable then
        ret.components.perishable = {
            percent = item.components.perishable:GetPercent()
        }
    elseif item.components.finiteuses then
        ret.components.finiteuses = {
            percent = item.components.finiteuses:GetPercent()
        }
    elseif item.components.fueled then
        ret.components.fueled = {
            percent = item.components.fueled:GetPercent()
        }
    end

    if item.components.rechargeable then
        ret.components.rechargeable = {
            percent = item.components.rechargeable:GetPercent(),
            time = item.components.rechargeable:GetRechargeTime(),
        }
    end

    if not (item:HasTag("fresh") or item:HasTag("stale") or item:HasTag("spoiled")) then
        -- do nothing
    elseif item:HasTag("show_spoilage") then
        ret.hasspoilage = true
    else
        for k, v in pairs(FOODTYPE) do
            if item:HasTag("edible_"..v) then
                ret.hasspoilage = true
                break
            end
        end
    end

    return ret
end

-- Client side
local ReturnFalse = function()
    return false
end

local ReturnTrue = function()
    return true
end

-- Item fns
local HasTag = function(item, tag)
    return item.tags[tag] ~= nil
end

local HasTags = function(item, ...)
    local tags = select(1, ...)
    if type(tags) ~= "table" then
        tags = {...}
    end
    for i, tag in ipairs(tags) do
        if not HasTag(item, tag) then
            return false
        end
    end
    return true
end

local HasOneOfTags = function(item, ...)
    local tags = select(1, ...)
    if type(tags) ~= "table" then
        tags = {...}
    end
    for i, tag in ipairs(tags) do
        if HasTag(item, tag) then
            return true
        end
    end
end

local GetAdjective = function(item)
    return item.adjective
end

local GetDisplayName = function(item)
    return item.name
end

local StackableSkinHack = function(item, target)
    return target.AnimState and target.AnimState:GetSkinBuild() == item.AnimState.skinbuild
end

-- GetSkinBuild
local GetSkinBuild = function(AnimState)
    return AnimState.skinbuild
end

-- Stackable fns
local IsStack = function(self)
    return self.stacksize > 1
end

local StackSize = function(self)
    return self.stacksize
end

local MaxSize = function(self)
    return self.maxsize
end

local IsFull = function(self)
    return self.stacksize >= self.maxsize
end

local OriginalMaxSize = function(self)
    return self.originalmaxsize or self.maxsize
end

-- Inventoryitem fns
local GetAtlas = function(self)
    return self.atlas
end

local GetImage = function(self)
    return self.image
end

local IsWeapon = function(self)
    return self.inst:HasTag("weapon")
end

local GetWalkSpeedMult = function(self)
    return 1
end

local GetMoisture = function(self)
    return 0
end

local item_meta = {
    __index = {
        HasTag = HasTag,
        HasTags = HasTags,
        HasAllTags = HasTags,
        HasOneOfTags = HasOneOfTags,
        HasAnyTag = HasOneOfTags,
        IsValid = ReturnTrue,
        IsAcidSizzling = ReturnFalse,
        GetAdjective = GetAdjective,
        GetDisplayName = GetDisplayName,
        GetAdjectivedName = GetDisplayName,
        GetBasicDisplayName = GetDisplayName,
        GetIsWet = ReturnFalse,
        StackableSkinHack = StackableSkinHack,
    }
}

local AnimState_meta = {
    __index = {
        GetSkinBuild = GetSkinBuild,
    }
}

local stackable_meta = {
    __index = {
        IsStack = IsStack,
        StackSize = StackSize,
        MaxSize = MaxSize,
        IsFull = IsFull,
        OriginalMaxSize = OriginalMaxSize,
    }
}

local inventoryitem_meta = {
    __index = {
        GetAtlas = GetAtlas,
        GetImage = GetImage,
        CanGoInContainer = ReturnTrue,
        CanOnlyGoInPocket = ReturnFalse,
        CanOnlyGoInPocketOrPocketContainers = ReturnFalse,
        IsGrandOwner = ReturnFalse,
        IsHeld = ReturnTrue,
        IsHeldBy = ReturnFalse,
        IsDeployable = ReturnFalse,
        IsWeapon = IsWeapon,
        GetWalkSpeedMult = GetWalkSpeedMult,
        GetMoisture = GetMoisture,
        IsWet = ReturnFalse,
        IsAcidSizzling = ReturnFalse,
    }
}

local function ModifyFakeItem(item)
    item.IsFake = true
    setmetatable(item, item_meta)
    -- AnimState
    setmetatable(item.AnimState, AnimState_meta)
    -- stackable_replica
    local stackable = item.replica.stackable
    if stackable then
        stackable.inst = item
        setmetatable(stackable, stackable_meta)
        if stackable.maxsize == "inf" then
            stackable.maxsize = math.huge
        end
    end
    -- inventoryitem_replica
    local inventoryitem = item.replica.inventoryitem
    inventoryitem.inst = item
    setmetatable(inventoryitem, inventoryitem_meta)
end

return {
    FakeItem = FakeItem,
    ModifyFakeItem = ModifyFakeItem
}
