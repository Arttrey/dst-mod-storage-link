GLOBAL.SimpleStorageRightActionString = {}
local FakeContainer = require("ss_util/fakecontainer").FakeContainer

local InvSlot = require("widgets/invslot")
local UpvalueHelper = require "ss_util/upvaluehelper"

local GetTime = GLOBAL.GetTime
--------------------------------------------------------------------------
-- 可连接检测
--------------------------------------------------------------------------

--黑名单容器 --由wiefean提供
local ContainerBlacklist = {
	["ocean_trawler"] = true, --捕鱼器
	["dragonflyfurnace"] = true, --龙鳞火炉
	["shadowfieldexciter"] = true, --影场激发器(影场激发器mod)
	["axashcan"] = true, --垃圾桶(建家档mod)
	["plant_nepenthes_l"] = true, --巨食草(棱镜mod)
	["simmeredmoonlight"] = true, --月炆宝炊(棱镜mod)
	["simmeredmoonlight_inf"] = true, --月炆宝炊无限(棱镜mod)
	["simmeredmoonlight_pro"] = true, --便携月炆宝炊(棱镜mod)
	["simmeredmoonlight_pro_inf"] = true, --便携月炆宝炊无限(棱镜mod)
}

GLOBAL.CanTerminalConnect = function(target)
    if target == nil then
        return false
    end
    if target.prefab == nil or ContainerBlacklist[target.prefab] then
        return false
    end
    local container = target.replica and target.replica.container
    local is_standard_container = container and container.type == "chest"
    local is_compatible_mod_container = TUNING.SS_SUPPORT_MOD_CONTAINERS and container and container.type == nil
    return container and (is_standard_container or is_compatible_mod_container) and
    (not container.usespecificslotsforitems) and
    (not target:HasTag("locomotor")) and target.replica.inventoryitem == nil
end

--------------------------------------------------------------------------
-- 放物品到终端优先级
--------------------------------------------------------------------------

local function IsSameSkin(v1, v2)
    if TheWorld.ismastersim then
        return v1.skinname == v2.skinname
    elseif v1.AnimState and v2.AnimState then
        return v1.AnimState:GetSkinBuild() == v2.AnimState:GetSkinBuild()
    end
end

local function IsPreserver(inst)
    if inst == nil then
        return false
    end
    if inst.IsFake then
        return inst.ispreserver
    end
    if inst:HasAnyTag("fridge", "foodpreserver") then
        return true
    end
    if inst.components.preserver then
        return true
    end
    return false
end

local FOODTYPE = GLOBAL.FOODTYPE
local function LowPriorityCheck(self, item, container)
    if container.lowpriorityselection then
        return true
    end

    if container.IsInfiniteStackSize and container:IsInfiniteStackSize() then
        return true
    end

    local hasspoilage = false
    if not (item:HasTag("fresh") or item:HasTag("stale") or item:HasTag("spoiled")) then
        -- do nothing
    elseif item:HasTag("show_spoilage") then
        hasspoilage = true
    else
        for k, v in pairs(FOODTYPE) do
            if item:HasTag("edible_"..v) then
                hasspoilage = true
                break
            end
        end
    end

    if hasspoilage then
        local ispreserver = IsPreserver(container.inst)
        return not ispreserver
    end

    return false
end
-- run on client
GLOBAL.FindBestTerminalContainer = function(self, item, containers, exclude_containers)
    if item == nil or containers == nil then
        return
    end

    exclude_containers = exclude_containers or {}

    local terminalwidget = ThePlayer and ThePlayer.HUD and ThePlayer.HUD.terminalwidget
    local unselect_containers = terminalwidget and terminalwidget:GetUnselectContainers() or {}

    local containerwithsameitem = nil
    local containerwithemptyslot = nil
    local containerwithnonstackableslot = nil
    local containerwithlowpirority = nil

    for k, v in pairs(containers) do
        if (not exclude_containers[k]) and (not unselect_containers[k.prefab]) then
            local container = k.replica.container or k.replica.inventory
            -- 首先能进容器
            if container and container:CanTakeItemInSlot(item) then
                local isfull = container:IsFull()
                -- 可以堆叠
                if container:AcceptsStacks() then
                    -- 有空格子
                    if not isfull and containerwithemptyslot == nil then
                        -- 低优先级
                        local islowpirority = LowPriorityCheck(self, item, container)
                        if islowpirority then
                            containerwithlowpirority = k
                        else
                            containerwithemptyslot = k
                        end
                    end
                    -- 有相同物品
                    for k1, v1 in pairs(container:GetItems()) do
                        -- 修改皮肤判断
                        if v1.prefab == item.prefab and IsSameSkin(v1, item) then
                            -- 还可以堆叠
                            if v1.replica.stackable and not v1.replica.stackable:IsFull() then
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
    -- 次优先：相同物品 > 空格子 > 非堆叠格子 > 低优先级
    return containerwithsameitem or containerwithemptyslot or containerwithnonstackableslot or containerwithlowpirority
end

local function HookFindBestContainer()
    local old_FindBestContainer = UpvalueHelper.Get(InvSlot.TradeItem, "FindBestContainer")

    if old_FindBestContainer then

        local new_FindBestContainer = function(self, ...)
            if ThePlayer and ThePlayer:IsUsingSimpleStorage() then
                return FindBestTerminalContainer(self, ...)
            else
                return old_FindBestContainer(self, ...)
            end
        end

        UpvalueHelper.Set(InvSlot.TradeItem, "FindBestContainer", new_FindBestContainer)
    end
end

HookFindBestContainer()

-- delay hook again
AddSimPostInit(function()
    HookFindBestContainer()
end)

--------------------------------------------------------------------------
-- 标签记录
--------------------------------------------------------------------------

AddGlobalClassPostConstruct("entityscript", "EntityScript", function(self)
    self.tags_backup = {}

    local old_AddTag = self.AddTag
    function self:AddTag(tag)
        self.tags_backup[tag] = 1
        return old_AddTag(self, tag)
    end

    local old_RemoveTag = self.RemoveTag
    function self:RemoveTag(tag)
        self.tags_backup[tag] = nil
        return old_RemoveTag(self, tag)
    end
end)

--------------------------------------------------------------------------
-- 提高终端原型优先级
--------------------------------------------------------------------------

AddComponentPostInit("builder", function(self)
    local old_EvaluateTechTrees = self.EvaluateTechTrees
    function self:EvaluateTechTrees(...)
        local ret_tbl = {old_EvaluateTechTrees(self, ...)}

        local prototyper = self.current_prototyper
        if prototyper and prototyper.prefab == "terminalconnector" then
            self.override_current_prototyper = prototyper
        end

        return unpack(ret_tbl)
    end
end)

--------------------------------------------------------------------------
-- 终端打开时修改动作收集
--------------------------------------------------------------------------

AddComponentPostInit("playeractionpicker", function(self)
    local old_GetSceneActions = self.GetSceneActions
    function self:GetSceneActions(useitem, right, ...)
        local sorted_acts = old_GetSceneActions(self, useitem, right, ...) or {}
        local act = sorted_acts[1]

        if act and act.action == ACTIONS.RUMMAGE and self.inst:IsUsingSimpleStorage() and CanTerminalConnect(act.target) then
            table.remove(sorted_acts, 1)
        end

        return sorted_acts
    end
end)

--------------------------------------------------------------------------
-- 这些函数需要获取terminalcontainers
--------------------------------------------------------------------------

local function NeedTerminalContainers(self, fn_name)
    local old_fn = self[fn_name]
    if old_fn == nil then return end

    self[fn_name] = function(self, ...)
        local inventory = ThePlayer and ThePlayer.replica.inventory
        if inventory == nil then return old_fn(self, ...) end

        if inventory.need_terminal_containers == nil then
            inventory.need_terminal_containers = fn_name
        end

        -- 避免old_fn函数内部修改need_terminal_containers
        local ret_tbl = {old_fn(self, ...)}

        if inventory.need_terminal_containers == fn_name then
            inventory.need_terminal_containers = nil
        end

        return unpack(ret_tbl)
    end
end

AddClassPostConstruct("widgets/invslot", function(self)
    self.inst:DoStaticTaskInTime(0, function()
        NeedTerminalContainers(self, "TradeItem")
    end)
end)

AddClassPostConstruct("widgets/itemtile", function(self)
    self.inst:DoStaticTaskInTime(0, function()
        NeedTerminalContainers(self, "GetDescriptionString")
    end)
end)

--------------------------------------------------------------------------
-- 背包修改
--------------------------------------------------------------------------

AddClassPostConstruct("components/inventory_replica", function(self)

    -- 目标容器IsFake处理
    local old_MoveItemFromAllOfSlot = self.MoveItemFromAllOfSlot
    function self:MoveItemFromAllOfSlot(slot, container)
        if container and container.IsFake then
            if TheWorld.ismastersim then
                container = Ents[container.GUID]
                if container and container:IsValid() then
                    self.inst.components.inventory:MoveItemFromAllOfSlot(slot, container)
                end
            else
                local guid = container.GUID
                SendModRPCToServer(MOD_RPC["SimpleStorage"]["Inventory:MoveItemFromAllOfSlot"], slot, guid)
            end
            return
        end
        return old_MoveItemFromAllOfSlot(self, slot, container)
    end

    local old_MoveItemFromHalfOfSlot = self.MoveItemFromHalfOfSlot
    function self:MoveItemFromHalfOfSlot(slot, container)
        if container and container.IsFake then
            if TheWorld.ismastersim then
                container = Ents[container.GUID]
                if container and container:IsValid() then
                    self.inst.components.inventory:MoveItemFromHalfOfSlot(slot, container)
                end
            else
                local guid = container.GUID
                SendModRPCToServer(MOD_RPC["SimpleStorage"]["Inventory:MoveItemFromHalfOfSlot"], slot, guid)
            end
            return
        end
        return old_MoveItemFromHalfOfSlot(self, slot, container)
    end

    -- 目标物品IsFake处理
    local old_UseItemFromInvTile = self.UseItemFromInvTile
    function self:UseItemFromInvTile(item)
        if item and item.IsFake then
            if TheWorld.ismastersim then
                item = Ents[item.GUID]
                if item and item:IsValid() then
                    self.inst.components.inventory:UseItemFromInvTile(item)
                end
            else
                local guid = item.GUID
                SendModRPCToServer(MOD_RPC["SimpleStorage"]["Inventory:UseItemFromInvTile"], guid)
            end
            return
        end
        return old_UseItemFromInvTile(self, item)
    end

    local old_DropItemFromInvTile = self.DropItemFromInvTile
    function self:DropItemFromInvTile(item, single)
        if item and item.IsFake then
            if TheWorld.ismastersim then
                item = Ents[item.GUID]
                if item and item:IsValid() then
                    self.inst.components.inventory:DropItemFromInvTile(item, single)
                end
            else
                local guid = item.GUID
                SendModRPCToServer(MOD_RPC["SimpleStorage"]["Inventory:DropItemFromInvTile"], guid, single)
            end
            return
        end
        return old_DropItemFromInvTile(self, item, single)
    end

    -- 拥有材料判断
    local old_Has = self.Has
    function self:Has(prefab, amount, checkallcontainers, ...)
        local enough, num_found = old_Has(self, prefab, amount, checkallcontainers, ...)
        -- 主机会直接走inventory组件，在那里已经做了处理
        if TheWorld.ismastersim then
            return enough, num_found
        end

        if checkallcontainers then
            local terminalwidget = self.inst.HUD and self.inst.HUD.terminalwidget
            if terminalwidget and terminalwidget.isopen then
                local num_add = terminalwidget:CalcItemNum(prefab)
                num_found = num_found + num_add
                enough = enough or (num_found >= amount)
            end
        end

        return enough, num_found
    end

    -- 获取终端的容器
    local old_GetOpenContainers = self.GetOpenContainers
    function self:GetOpenContainers(...)
        local containers = old_GetOpenContainers(self, ...) or {}
        if self.need_terminal_containers == nil then
            return containers
        end

        local ret = shallowcopy(containers)
        local terminalwidget = self.inst.HUD and self.inst.HUD.terminalwidget
        if terminalwidget then
            for guid, container in pairs(terminalwidget.containers) do
                ret[container] = true
            end
        end
        return ret
    end

    -- 宝石核心兼容
    self.inst:DoTaskInTime(0, function()
        NeedTerminalContainers(self, "FindCraftingItems")
    end)

    -- 两个新接口函数
    -- 移动单个active_item
    function self:MoveItemFromOneOfActive(container)
        if container and container.IsFake then
            if TheWorld.ismastersim then
                container = Ents[container.GUID]
                if container and container:IsValid() then
                    self.inst.components.inventory:MoveItemFromOneOfActive(container)
                end
            else
                SendModRPCToServer(MOD_RPC["SimpleStorage"]["Inventory:MoveItemFromOneOfActive"], container.GUID)
            end
            return
        end
    end

    -- 移动全部active_item
    function self:MoveItemFromAllOfActive(container)
        if container and container.IsFake then
            if TheWorld.ismastersim then
                container = Ents[container.GUID]
                if container and container:IsValid() then
                    self.inst.components.inventory:MoveItemFromAllOfActive(container)
                end
            else
                SendModRPCToServer(MOD_RPC["SimpleStorage"]["Inventory:MoveItemFromAllOfActive"], container.GUID)
            end
            return
        end
    end

    -- 预览activeitem，用于客机文本和图形提前显示
    function self:GetActiveItemWithTerminalPreview()
        if TheWorld.ismastersim or self.classified == nil then
            return self:GetActiveItem()
        end
        return self.classified:GetActiveItemWithTerminalPreview()
    end
end)

AddComponentPostInit("inventory",function(self)

    self.fake_opencontainers = {}

    -- hook opencontainers函数
    local function hook_opencontainers(fn_name)
        local old_fn = self[fn_name]
        if old_fn == nil then return end

        self[fn_name] = function(self, ...)
            local fake_opencontainers = shallowcopy(self.fake_opencontainers)
            for k, _ in pairs(fake_opencontainers) do
                self.opencontainers[k] = true
            end

            local ret_tbl = {old_fn(self, ...)}

            for k, _ in pairs(fake_opencontainers) do
                self.opencontainers[k] = nil
            end

            return unpack(ret_tbl)
        end
    end

    local hooklist = {
        "FindCraftingItems", -- 兼容宝石核心
        "GetCraftingIngredient",
        "GetItemByName",
        "RemoveItem",
        "Has",
    }

    -- 延迟以避免被覆盖
    self.inst:DoTaskInTime(0, function()
        for i, fn_name in ipairs(hooklist) do
            hook_opencontainers(fn_name)
        end
    end)

    -- 背包关闭时CloseTerminal
    local old_Close = self.Close
    function self:Close(keepactiveitem, ...)
        if self.isopen and self.inst:HasTag("player") and self.inst:IsUsingSimpleStorage() then
            local playercontroller = self.inst.components.playercontroller
            if playercontroller then
                playercontroller:DoCloseTerminalAction()
            end
        end
        return old_Close(self, keepactiveitem, ...)
    end

    -- 两个新接口函数
    -- 移动单个active_item
    function self:MoveItemFromOneOfActive(container)
        local item = self:GetActiveItem()
        if item ~= nil and container ~= nil then
            container = container.components.container
            if container ~= nil and
                container:IsOpenedBy(self.inst) and
                item.components.stackable ~= nil and
                item.components.stackable:IsStack() then

                container.currentuser = self.inst

                if container:CanTakeItemInSlot(item) then
                    local onestack = item.components.stackable:Get()
                    onestack.prevcontainer = nil
                    onestack.prevslot = nil
                    if not container:GiveItem(onestack) then
                        item.components.stackable:Put(onestack)
                    end
                end

                container.currentuser = nil
            end
        end
    end

    -- 移动全部active_item
    function self:MoveItemFromAllOfActive(container)
        local item = self:GetActiveItem()
        if item ~= nil and container ~= nil then
            container = container.components.container
            if container ~= nil and container:IsOpenedBy(self.inst) then
                container.currentuser = self.inst

                if container:CanTakeItemInSlot(item) then

                    self:RemoveItem(item, true)
                    if not container:GiveItem(item, nil, nil, false) then
                        self:GiveActiveItem(item)
                    end
                end

                container.currentuser = nil
            end
        end
    end

end)

--------------------------------------------------------------------------
-- 容器修改
--------------------------------------------------------------------------

AddClassPostConstruct("components/container_replica", function(self)
    -- 目标容器IsFake处理
    local old_MoveItemFromAllOfSlot = self.MoveItemFromAllOfSlot
    function self:MoveItemFromAllOfSlot(slot, container)
        if container and container.IsFake then
            if TheWorld.ismastersim and ThePlayer then
                container = Ents[container.GUID]
                if container and container:IsValid() then
                    self.inst.components.container:MoveItemFromAllOfSlot(slot, container, ThePlayer)
                end
            else
                local source = self.inst
                local dest = container.GUID
                SendModRPCToServer(MOD_RPC["SimpleStorage"]["Container:MoveItemFromAllOfSlot"], source, slot, dest)
            end
            return
        end
        return old_MoveItemFromAllOfSlot(self, slot, container)
    end

    local old_MoveItemFromHalfOfSlot = self.MoveItemFromHalfOfSlot
    function self:MoveItemFromHalfOfSlot(slot, container)
        if container and container.IsFake then
            if TheWorld.ismastersim and ThePlayer then
                container = Ents[container.GUID]
                if container and container:IsValid() then
                    self.inst.components.container:MoveItemFromHalfOfSlot(slot, container, ThePlayer)
                end
            else
                local source = self.inst
                local dest = container.GUID
                SendModRPCToServer(MOD_RPC["SimpleStorage"]["Container:MoveItemFromHalfOfSlot"], source, slot, dest)
            end
            return
        end
        return old_MoveItemFromHalfOfSlot(self, slot, container)
    end
end)

AddComponentPostInit("container",function(self)
    -- 远程开关容器
    self.fake_openlist = {}

    function self:RemoteOpen(doer)
        local fake = FakeContainer(self.inst)

        local encodedata = json.encode(fake)
        encodedata = TheSim:ZipAndEncodeString(encodedata)

        SendModRPCToClient(CLIENT_MOD_RPC["SimpleStorage"]["OpenFakeContainer"], doer.userid, encodedata)
        local inventory = doer.components.inventory
        inventory.fake_opencontainers[self.inst] = true
        self.fake_openlist[doer] = true
    end

    local old_Close = self.Close
    function self:Close(doer, ...)
        if doer == nil then
            self:RemoteCloseAll()
        end
        return old_Close(self, doer, ...)
    end

    self.OnRemoveEntity = self.Close
    self.OnRemoveFromEntity = self.Close

    function self:RemoteClose(doer)
        local inventory = doer.components.inventory
        inventory.fake_opencontainers[self.inst] = nil
        self.fake_openlist[doer] = nil
    end

    function self:RemoteCloseAll()
        for doer in pairs(self.fake_openlist) do
            if doer and doer:IsValid() then
                self:RemoteClose(doer)
                -- 仅该情况下单独通知客机
                SendModRPCToClient(CLIENT_MOD_RPC["SimpleStorage"]["CloseFakeContainer"], doer.userid, self.inst.GUID)
            end
        end
        self.fake_openlist = {}
    end

    -- 监听容器物品变动
    self.terminal_refresh = function(inst, data)
        if next(self.fake_openlist) == nil then return end

        local slot = data.slot or self:GetItemSlot(data.item) or nil

        local fake = FakeContainer(inst)
        local encodedata = json.encode(fake)
        encodedata = TheSim:ZipAndEncodeString(encodedata)

        for player in pairs(self.fake_openlist) do
            if player and player:IsValid() then
                SendModRPCToClient(CLIENT_MOD_RPC["SimpleStorage"]["RefreshFakeContainer"], player.userid, encodedata, slot)
            else
                self.fake_openlist[player] = nil
            end
        end
    end

    self.inst:ListenForEvent("itemlose", self.terminal_refresh)
    self.inst:ListenForEvent("itemget", self.terminal_refresh)
    self.inst:ListenForEvent("stacksizechange", self.terminal_refresh)
    self.inst:ListenForEvent("simplestorage_refresh", self.terminal_refresh)

    -- 容器是否被打开
    local old_IsOpenedBy = self.IsOpenedBy
    function self:IsOpenedBy(player)
        if self.fake_openlist[player] then
            return true
        end
        return old_IsOpenedBy(self, player)
    end

    -- 记录widgetprefab
    local old_WidgetSetup = self.WidgetSetup
    function self:WidgetSetup(prefab, ...)
        self.widgetprefab = prefab or self.inst.prefab
        return old_WidgetSetup(self, prefab, ...)
    end

end)

--------------------------------------------------------------------------
-- 终端打开状态
--------------------------------------------------------------------------

AddPlayerPostInit(function(inst)

    -- 接口函数
    function inst:IsUsingSimpleStorage()
        local classified = inst.player_classified
        return classified and classified.usingsimplestorage:value()
    end

    function inst:SetUsingSimpleStorage(using)
        local classified = inst.player_classified
        if classified and TheWorld.ismastersim then
            classified.usingsimplestorage:set_local(using)
            classified.usingsimplestorage:set(using)
        end
    end

end)

AddPrefabPostInit("player_classified" ,function(inst)

    inst.usingsimplestorage = net_bool(inst.GUID, "usingsimplestorage", "usingsimplestorage")

    -- 玩家关闭终端UI
    if not TheNet:IsDedicated() then
        inst:ListenForEvent("usingsimplestorage",function()
            local player = inst._parent
            if player == nil or TheFocalPoint.entity:GetParent() ~= player then return end

            local using = inst.usingsimplestorage:value()

            if player.HUD and not using then
                player.HUD:CloseTerminalWidget()
            end
        end)
    end

end)

--------------------------------------------------------------------------
-- 关闭终端接口
--------------------------------------------------------------------------

AddComponentPostInit("playercontroller", function(self)
    function self:DoCloseTerminalAction()
        if TheWorld.ismastersim then
            BufferedAction(self.inst, nil, ACTIONS.REMOTECLOSETERMINAL):Do()
        else
            SendModRPCToServer(MOD_RPC["SimpleStorage"]["DoCloseTerminalAction"])
        end
    end
end)

--------------------------------------------------------------------------
-- 通知容器刷新物品
--------------------------------------------------------------------------

AddComponentPostInit("inventoryitem", function(self)

    self.last_notify_time = 0

    self.notify_terminal_refresh = function(inst, data)
        if self.owner and not data.overtime then
            local time = GetTime()
            if time - self.last_notify_time > 1.5 then
                self.owner:PushEvent("simplestorage_refresh", {item = inst})
                self.last_notify_time = time
            end
        end
    end

    self.inst:ListenForEvent("percentusedchange", self.notify_terminal_refresh)
    self.inst:ListenForEvent("rechargechange", self.notify_terminal_refresh)
end)
