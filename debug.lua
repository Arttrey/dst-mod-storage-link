-- -- debug

-- TUNING.TAIERUI_SPEED = 10
-- TUNING.TAIERUI = nil
-- local keys = {up=273,down=274,right=275,left=276}
-- for k,v in pairs(keys) do
--     TheInput:AddKeyUpHandler(v, function()
--         if TUNING.TAIERUI then
--             local pos = TUNING.TAIERUI:GetPosition()
--             if v == 273 then
--                 TUNING.TAIERUI:SetPosition(pos.x,pos.y+TUNING.TAIERUI_SPEED,0)
--             elseif v == 274 then
--                 TUNING.TAIERUI:SetPosition(pos.x,pos.y-TUNING.TAIERUI_SPEED,0)
--             elseif v == 275 then
--                 TUNING.TAIERUI:SetPosition(pos.x+TUNING.TAIERUI_SPEED,pos.y,0)
--             elseif v == 276 then
--                 TUNING.TAIERUI:SetPosition(pos.x-TUNING.TAIERUI_SPEED,pos.y,0)
--             end
--             print(TUNING.TAIERUI:GetPosition())
--         end
--     end)
-- end



-- AddClassPostConstruct("widgets/button", function(self)
--     local ongainfocus = self.ongainfocus or function() end
--     self.ongainfocus = function()
--         print(self, self.atlas, self.image)
--         ongainfocus()
--     end
-- end)

local prefabs
local prefab_count

local function randomprefab()
    if prefabs == nil then
        prefabs = {}
        prefab_count = 0
        for prefab, data in pairs(GLOBAL.Prefabs) do
            if data.fn then
                table.insert(prefabs, prefab)
                prefab_count = prefab_count + 1
            end
        end
    end
    return prefabs[math.random(1, prefab_count)]
end

GLOBAL.c_terminal_fill = function(prefab)
    local inst = c_select()
    local container = inst and inst.components.container
    if container then
        for i = 1, container:GetNumSlots() do
            local item = container:GetItemInSlot(i)
            if item == nil then
                local success = false
                repeat
                    local item = SpawnPrefab(prefab or randomprefab())
                    success = container:GiveItem(item)
                    if not success and item then
                        item:Remove()
                    end
                until success
            end
        end
    end
end