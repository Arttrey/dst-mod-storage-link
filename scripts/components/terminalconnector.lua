
local function uuid()
    local seed = {'e','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f'}
    local tb = {}
    for i = 1, 32 do
        table.insert(tb,seed[math.random(1,16)])
    end
    local sid = table.concat(tb)
    return string.format('%s-%s-%s-%s-%s',
        string.sub(sid,1,8),
        string.sub(sid,9,12),
        string.sub(sid,13,16),
        string.sub(sid,17,20),
        string.sub(sid,21,32)
    )
end

local TerminalConnector = Class(function(self, inst)
    self.inst = inst

    self.containers = {}
    self.uuid = uuid()

    self.inst:DoTaskInTime(0, function()
        if TheWorld.terminalconnectors == nil then
            TheWorld.terminalconnectors = {}
        end
        TheWorld.terminalconnectors[self.uuid] = self.inst
    end)

end)

function TerminalConnector:RefreshContainers()
    self.containers = {}
    local x, y, z = self.inst:GetPosition():Get()
    local radius = TUNING.SS_LINKRADIUS
    local ents = TheSim:FindEntities(x, y, z, radius, nil, {"INLIMBO", "FX", "locomotor"})
    for i, ent in ipairs(ents) do
        if CanTerminalConnect(ent) then
            table.insert(self.containers, ent)
        end
    end
end

function TerminalConnector:CanOpenTerminal()
    self:RefreshContainers()
    if next(self.containers) ~= nil then
        return true
    end
    return false, "NOCONTAINER"
end

function TerminalConnector:OpenTerminal(doer, wireless)
    if doer == nil or not doer:IsValid() then
        return
    end
    for i, container in ipairs(self.containers) do
        if container and container:IsValid() and container.components.container then
            container.components.container:RemoteOpen(doer)
        end
    end
    -- 自动关闭任务
    local inst = self.inst
    doer.auto_close_terminal_task = doer:DoPeriodicTask(10*FRAMES, function()
        if not inst:IsValid() or doer:HasTag("playerghost") or not (wireless or doer:IsNear(inst, 3)) then
            -- 存储终端消失/玩家死亡/有线状态下离终端太远
            local playercontroller = doer.components.playercontroller
            if playercontroller then
                playercontroller:DoCloseTerminalAction()
            end
        end
    end)
end

function TerminalConnector:OnSave()
    return {uuid = self.uuid}
end

function TerminalConnector:OnLoad(data)
    if data and data.uuid then
        self.uuid = data.uuid
    end
end

return TerminalConnector