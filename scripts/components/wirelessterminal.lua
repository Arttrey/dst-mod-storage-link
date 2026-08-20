
local WirelessTerminal = Class(function(self, inst)
    self.inst = inst
    -- 绑定的有线终端的uuid
    self.target_uuid = {}
end)

function WirelessTerminal:CanOpenTerminal()
    local target_uuid = self.target_uuid[TheShard:GetShardId()]
    if target_uuid == nil then
        return false, "NOLINK"
    end
    if TheWorld.terminalconnectors == nil then
        return false, "LINKINVALID"
    end
    local target = TheWorld.terminalconnectors[target_uuid]
    if target == nil or not target:IsValid() then
        return false, "LINKINVALID"
    end
    -- 直接调用有线终端的函数
    return target.components.terminalconnector:CanOpenTerminal()
end

function WirelessTerminal:OpenTerminal(doer)
    local target_uuid = self.target_uuid[TheShard:GetShardId()]
    local target = TheWorld.terminalconnectors[target_uuid]
    if target and target:IsValid() then
        -- 直接调用有线终端的函数
        target.components.terminalconnector:OpenTerminal(doer, true)
    end
end

function WirelessTerminal:OnSave()
    return {target_uuid = self.target_uuid}
end

function WirelessTerminal:OnLoad(data)
    if data and data.target_uuid then
        self.target_uuid = data.target_uuid
    end
end

return WirelessTerminal
