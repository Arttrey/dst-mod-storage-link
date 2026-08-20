local ru = TUNING.SS_RUSSIAN

--------------------------------------------------------------------------
-- 远程 打开无线终端动作
--------------------------------------------------------------------------
local function openfn(act)
    local player = act.doer
    if player:IsUsingSimpleStorage() then return false end

    -- 有线/无线终端
    local terminal = act.invobject or act.target
    if terminal then
        local cmp = terminal.components.wirelessterminal or terminal.components.terminalconnector
        local success, reason = cmp:CanOpenTerminal()

        if success then
            player.components.inventory:CloseAllChestContainers()
            player:SetUsingSimpleStorage(true)
            cmp:OpenTerminal(player)
            return true
        else
            return success, reason
        end
    end
end

AddAction("REMOTEOPENTERMINAL", ru and "Открыть" or "Open", function(act)
    local success, reason = openfn(act)
    if reason then
        -- 处理instant动作失败原因
        local str = STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.REMOTEOPENTERMINAL[reason]
        act.doer.components.talker:Say(str)
    end
end)

ACTIONS.REMOTEOPENTERMINAL.instant = true
ACTIONS.REMOTEOPENTERMINAL.mount_valid = true

--------------------------------------------------------------------------
-- 打开有线终端动作
--------------------------------------------------------------------------
AddAction("OPENTERMINAL", ru and "Открыть" or "Open", openfn)

ACTIONS.OPENTERMINAL.invalid_hold_action = true
ACTIONS.OPENTERMINAL.mount_valid = true

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.OPENTERMINAL, "give"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.OPENTERMINAL, "give"))

--------------------------------------------------------------------------
-- 远程 关闭终端动作
--------------------------------------------------------------------------
local function closefn(act)
    local player = act.doer
    local inventory = player.components.inventory

    for k in pairs(inventory.fake_opencontainers or {}) do
        k.components.container:RemoteClose(player)
    end

    player:SetUsingSimpleStorage(false)

    -- 取消自动关闭任务
    if player.auto_close_terminal_task then
        player.auto_close_terminal_task:Cancel()
        player.auto_close_terminal_task = nil
    end

    return true
end

AddAction("REMOTECLOSETERMINAL", ru and "Закрыть" or "Close", closefn)

ACTIONS.REMOTECLOSETERMINAL.instant = true
ACTIONS.REMOTECLOSETERMINAL.mount_valid = true

--------------------------------------------------------------------------
-- 绑定动作
--------------------------------------------------------------------------
AddAction("LINKTERMINAL", ru and "Привязать" or "Bind", function(act)
    if act.invobject and act.target then
        local wirelessterminal = act.invobject.components.wirelessterminal
        local terminalconnector = act.target.components.terminalconnector

        if wirelessterminal and terminalconnector then
            -- 记录uuid
            wirelessterminal.target_uuid[TheShard:GetShardId()] = terminalconnector.uuid

            act.doer.components.inventory:ReturnActiveItem()
            local str = ru and "Терминал успешно привязан!" or "Successfully bound this terminal!"
            act.doer.components.talker:Say(str)
            return true
        end
    end
end)

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.LINKTERMINAL, "give"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.LINKTERMINAL, "give"))

--------------------------------------------------------------------------
-- 动作收集
--------------------------------------------------------------------------
AddComponentAction("INVENTORY", "wirelessterminal",-- 无线
function(inst, doer, actions, right)
    if doer:IsUsingSimpleStorage() then
        table.insert(actions, ACTIONS.REMOTECLOSETERMINAL)
    else
        table.insert(actions, ACTIONS.REMOTEOPENTERMINAL)
    end
end)

AddComponentAction("SCENE", "terminalconnector",-- 有线
function(inst, doer, actions, right)
    if not doer:IsUsingSimpleStorage() then
        table.insert(actions, ACTIONS.OPENTERMINAL)
    end
end)

AddComponentAction("USEITEM", "wirelessterminal",-- 绑定
function(inst, doer, target, actions, right)
    if target and target:HasTag("terminalconnector") then
        table.insert(actions, ACTIONS.LINKTERMINAL)
    end
end)
