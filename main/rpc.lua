local ModifyFakeContainer = require("ss_util/fakecontainer").ModifyFakeContainer

local GetActionString = GLOBAL.GetActionString
local checknumber = GLOBAL.checknumber
local checkentity = GLOBAL.checkentity
local checkstring = GLOBAL.checkstring

--------------------------------------------------------------------------
-- ClientRPC Handler
--------------------------------------------------------------------------
AddClientModRPCHandler("SimpleStorage", "OpenFakeContainer", function(encodedata)
    if ThePlayer and ThePlayer.HUD then
        -- print("压缩", encodedata:len())
        encodedata = TheSim:DecodeAndUnzipString(encodedata)
        -- print("解压后", encodedata:len())

        local status, fake = pcall(function() return json.decode(encodedata) end)
        if status then
            ModifyFakeContainer(fake)
            ThePlayer.HUD:OpenFakeContainer(fake)
        else
            PopupSimpleStorageJsonError()
        end
    end
end)

AddClientModRPCHandler("SimpleStorage", "RefreshFakeContainer", function(encodedata, slot)
    local terminalwidget = ThePlayer and ThePlayer.HUD and ThePlayer.HUD.terminalwidget
    if terminalwidget and terminalwidget.isopen then
        -- print("压缩", encodedata:len())
        encodedata = TheSim:DecodeAndUnzipString(encodedata)
        -- print("解压后", encodedata:len())

        local status, fake = pcall(function() return json.decode(encodedata) end)
        if status then
            ModifyFakeContainer(fake)
            terminalwidget.containers[fake.GUID] = fake
            if not checknumber(slot) then
                slot = nil
            end
            terminalwidget:Refresh(fake, slot)
            ThePlayer:PushEvent("refreshcrafting")
        else
            PopupSimpleStorageJsonError()
        end
    end
end)

AddClientModRPCHandler("SimpleStorage", "CloseFakeContainer", function(guid)
    local terminalwidget = ThePlayer and ThePlayer.HUD and ThePlayer.HUD.terminalwidget
    if terminalwidget and terminalwidget.isopen then
        terminalwidget.containers[guid] = nil
        local fake = {
            GUID = guid,
            only_for_close = true,
        }
        terminalwidget:Refresh(fake)
        ThePlayer:PushEvent("refreshcrafting")
    end
end)

AddClientModRPCHandler("SimpleStorage", "RefreshRightActionString", function(guid, str)
    if ThePlayer == nil then return end

    GLOBAL.SimpleStorageRightActionString.STRING = tostring(str)
    GLOBAL.SimpleStorageRightActionString.GUID = guid

    ThePlayer:PushEvent("simplestorage_updatetooltip")
end)

--------------------------------------------------------------------------
-- RPC Handler
--------------------------------------------------------------------------
AddModRPCHandler("SimpleStorage", "Container:MoveItemFromHalfOfSlot",function(player, source, slot, dest)
    if not checknumber(slot) then
        return
    end
    if checknumber(source) and checkentity(dest) then
        source = Ents[source]
        if source and source:IsValid() and source.components.container then
            source.components.container:MoveItemFromHalfOfSlot(slot, dest, player)
        end
    elseif checkentity(source) and checknumber(dest) then
        dest = Ents[dest]
        if source.components.container and dest and dest:IsValid() then
            source.components.container:MoveItemFromHalfOfSlot(slot, dest, player)
        end
    end
end)

AddModRPCHandler("SimpleStorage", "Container:MoveItemFromAllOfSlot",function(player, source, slot, dest)
    if not checknumber(slot) then
        return
    end
    if checknumber(source) and checkentity(dest) then
        source = Ents[source]
        if source and source:IsValid() and source.components.container then
            source.components.container:MoveItemFromAllOfSlot(slot, dest, player)
        end
    elseif checkentity(source) and checknumber(dest) then
        dest = Ents[dest]
        if source.components.container and dest and dest:IsValid() then
            source.components.container:MoveItemFromAllOfSlot(slot, dest, player)
        end
    end
end)

AddModRPCHandler("SimpleStorage", "Container:TakeActiveItemFromHalfOfSlot",function(player, guid, slot)
    if not (checknumber(guid) and checknumber(slot)) then
        return
    end
    local inst = Ents[guid]
    if inst and inst:IsValid() and inst.components.container then
        inst.components.container:TakeActiveItemFromHalfOfSlot(slot, player)
    end
end)

AddModRPCHandler("SimpleStorage", "Container:TakeActiveItemFromAllOfSlot",function(player, guid, slot)
    if not (checknumber(guid) and checknumber(slot)) then
        return
    end
    local inst = Ents[guid]
    if inst and inst:IsValid() and inst.components.container then
        inst.components.container:TakeActiveItemFromAllOfSlot(slot, player)
    end
end)

AddModRPCHandler("SimpleStorage", "Inventory:MoveItemFromHalfOfSlot",function(player, slot, guid)
    if not (checknumber(guid) and checknumber(slot)) then
        return
    end
    local container = Ents[guid]
    if container and container:IsValid() and container.components.container and player.components.inventory then
        player.components.inventory:MoveItemFromHalfOfSlot(slot, container)
    end
end)

AddModRPCHandler("SimpleStorage", "Inventory:MoveItemFromAllOfSlot",function(player, slot, guid)
    if not (checknumber(guid) and checknumber(slot)) then
        return
    end
    local container = Ents[guid]
    if container and container:IsValid() and container.components.container and player.components.inventory then
        player.components.inventory:MoveItemFromAllOfSlot(slot, container)
    end
end)

AddModRPCHandler("SimpleStorage", "Inventory:UseItemFromInvTile", function(player, guid)
    if not checknumber(guid) then
        return
    end
    local item = Ents[guid]
    if item and item:IsValid() and player.components.inventory then
        player.components.inventory:UseItemFromInvTile(item)
    end
end)

AddModRPCHandler("SimpleStorage", "Inventory:DropItemFromInvTile", function(player, guid, single)
    if not (checknumber(guid) and checkbool(single)) then
        return
    end
    local item = Ents[guid]
    if item and item:IsValid() and player.components.inventory then
        player.components.inventory:DropItemFromInvTile(item, single)
    end
end)

AddModRPCHandler("SimpleStorage", "Inventory:MoveItemFromOneOfActive",function(player, container)
    -- container is GUID
    if checknumber(container) then
        container = Ents[container]
        if not (container and container:IsValid() and container.components.container) then
            return
        end
    else
        return
    end

    local inventory = player.components.inventory
    if inventory then
        inventory:MoveItemFromOneOfActive(container)
    end
end)

AddModRPCHandler("SimpleStorage", "Inventory:MoveItemFromAllOfActive",function(player, container)
    -- container is GUID
    if checknumber(container) then
        container = Ents[container]
        if not (container and container:IsValid() and container.components.container) then
            return
        end
    else
        return
    end

    local inventory = player.components.inventory
    if inventory then
        inventory:MoveItemFromAllOfActive(container)
    end
end)

AddModRPCHandler("SimpleStorage", "DoCloseTerminalAction",function(player)
    local playercontroller = player and player.components.playercontroller
    if playercontroller then
        playercontroller:DoCloseTerminalAction()
    end
end)

AddModRPCHandler("SimpleStorage", "RequestRightActionString",function(player, guid)
    if not checknumber(guid) then return end
    local item = Ents[guid]
    if item == nil or not item:IsValid() then return end

    local actions = {}
    item:CollectActions("INVENTORY", player, actions, nil)

    local choose = nil
    for i, action in ipairs(actions) do
        if choose == nil or action.priority > choose.priority then
            choose = action
        end
    end

    local id = choose and choose.id
    if id == nil then return end

    local str = GetActionString(id, nil)
    if str == "ACTION" then
        str = STRINGS.UNKNOWACTION
    end

    SendModRPCToClient(CLIENT_MOD_RPC["SimpleStorage"]["RefreshRightActionString"], player.userid, guid, str)
end)
