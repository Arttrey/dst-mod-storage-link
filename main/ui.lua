local Widget = require "widgets/widget"
local TerminalWidget = require("widgets/terminalwidget")

--------------------------------------------------------------------------
-- 添加TerminalWidget
--------------------------------------------------------------------------
AddClassPostConstruct("widgets/controls", function(self)

    -- terminalrroot
    local root = self.containerroot.parent
    local scale = TheFrontEnd:GetHUDScale()
    self.terminalrroot = root:AddChild(Widget("terminalrroot"))
    self.terminalrroot:SetScale(scale)

    local old_SetHUDSize = self.SetHUDSize
    function self:SetHUDSize()
        local scale = TheFrontEnd:GetHUDScale()
        self.terminalrroot:SetScale(scale)
        return old_SetHUDSize(self)
    end

end)

AddClassPostConstruct("screens/playerhud", function(self)

    self.terminal_containers = {}

    -- 推送打开任务
    local function QueueOpenTask()
        if self.open_terminal_task then
            self.open_terminal_task:Cancel()
        end
        -- 等所有箱子打开完毕，延迟两帧打开面板
        self.open_terminal_task = self.inst:DoTaskInTime(3*FRAMES, function()
            self.open_terminal_task = nil
            self:OpenTerminalWidget()
        end)
    end

    function self:OpenFakeContainer(container)
        if container == nil then return end
        self.terminal_containers[container.GUID] = container
        QueueOpenTask()
    end

    -- 开/关终端面板UI
    function self:OpenTerminalWidget()
        -- only called from QueueOpenTask
        if self.terminalwidget == nil then
            self.terminalwidget = self.controls.terminalrroot:AddChild(TerminalWidget(self.owner))
        end

        self.terminalwidget:Open(self.terminal_containers)
        TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/Together_HUD/container_open")

        ThePlayer:PushEvent("refreshcrafting")

        -- 移动containerroot
        self.controls.containerroot:SetPosition(300, 0)
    end

    function self:CloseTerminalWidget()
        -- only called from net dirty
        if self.terminalwidget then

            self.terminalwidget:Close()
            TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/Together_HUD/container_close")
            self.terminal_containers = {}

            ThePlayer:PushEvent("refreshcrafting")

            -- 手柄光标刷新
            if TheInput:ControllerAttached() and self.controls.inv then
                local active_slot = self.controls.inv.active_slot
                if active_slot and
                (active_slot.is_terminal_button or active_slot.is_terminal_filter or active_slot.is_terminal_slot)
                then
                    self.controls.inv:CursorDown()
                end
            end

            -- 移动containerroot
            self.controls.containerroot:SetPosition(0, 0)
        end
    end

    -- 随制作栏移动
    local old_OpenCrafting = self.OpenCrafting
    function self:OpenCrafting(search)
        if self.terminalwidget then
            local pt = self.terminalwidget:GetPosition()
            self.terminalwidget:MoveTo(pt, Vector3(260, 0, 0), 0.25)
        end
        return old_OpenCrafting(self, search)
    end

    local old_CloseCrafting = self.CloseCrafting
    function self:CloseCrafting()
        if self.terminalwidget then
            local pt = self.terminalwidget:GetPosition()
            self.terminalwidget:MoveTo(pt, Vector3(0, 0, 0), 0.25)
        end
        return old_CloseCrafting(self)
    end

    -- ESC关闭
    local old_OnControl = self.OnControl
    function self:OnControl(control, down)
        if control == CONTROL_PAUSE and not down then
            if self.terminalwidget and self.terminalwidget.isopen then
                local playercontroller = ThePlayer and ThePlayer.components.playercontroller
                if playercontroller then
                    playercontroller:DoCloseTerminalAction()
                end
                return
            end
        end
        return old_OnControl(self, control, down)
    end
end)

--------------------------------------------------------------------------
-- 禁用视角缩放
--------------------------------------------------------------------------
AddComponentPostInit("playercontroller", function(self)
    local old_DoCameraControl = self.DoCameraControl
    function self:DoCameraControl()
        if TheInput:IsControlPressed(CONTROL_ZOOM_IN) or TheInput:IsControlPressed(CONTROL_ZOOM_OUT) then
            if self.inst.HUD and
            self.inst.HUD.terminalwidget and
            self.inst.HUD.terminalwidget.focus then
                return
            end
        end
        return old_DoCameraControl(self)
    end
end)

--------------------------------------------------------------------------
-- 打开制作栏，禁止自动聚焦CRAFTING_STATION
--------------------------------------------------------------------------
AddClassPostConstruct("widgets/redux/craftingmenu_widget", function(self)
    local old_OnCraftingMenuOpen = self.OnCraftingMenuOpen
    function self:OnCraftingMenuOpen(...)
        GLOBAL.PROTOTYPER_DEFS["terminalconnector"].is_crafting_station = false
        local ret = old_OnCraftingMenuOpen(self, ...)
        GLOBAL.PROTOTYPER_DEFS["terminalconnector"].is_crafting_station = true
        return ret
    end
end)

--------------------------------------------------------------------------
-- 打字时禁用快捷键
--------------------------------------------------------------------------
local old_OnInputKey = GLOBAL.OnInputKey
GLOBAL.OnInputKey = function(key, down)
    local terminalwidget = ThePlayer and ThePlayer.HUD and ThePlayer.HUD.terminalwidget
    if terminalwidget and terminalwidget.isopen then
        if key >= KEY_A and key <= KEY_Z then
            -- TheFrontEnd按键处理补回去
            TheFrontEnd:OnRawKey(key, down)
            return
        end
    end
    return old_OnInputKey(key, down)
end

--------------------------------------------------------------------------
-- 合并短时间内的refreshcrafting
--------------------------------------------------------------------------
AddClassPostConstruct("widgets/redux/craftingmenu_hud", function(self)
    local old_UpdateRecipes = self.UpdateRecipes
    function self:UpdateRecipes(...)

        if self.update_recipes_task then
            self.update_recipes_task:Cancel()
            self.update_recipes_task = nil
            return old_UpdateRecipes(self, ...)
        end

        if ThePlayer == nil or not ThePlayer:IsUsingSimpleStorage() then
            return old_UpdateRecipes(self, ...)
        end

        self.update_recipes_task = self.inst:DoStaticTaskInTime(3*FRAMES, function()
            old_UpdateRecipes(self)
            self.update_recipes_task = nil
        end)
    end
end)

--------------------------------------------------------------------------
-- json解析失败弹窗
--------------------------------------------------------------------------
local PopupDialogScreen = require "screens/redux/popupdialog"
local last_popup_time = 0

GLOBAL.PopupSimpleStorageJsonError = function()
    print(TUNING.SS_RUSSIAN and "Simple Storage RU+: ошибка чтения данных" or "Simple Storage: JSON parsing failed")

    -- 只提醒一次
    if last_popup_time > 0.1 then
        return
    end

    local time = GetTime()
    if time - last_popup_time < 1 then
        return
    end

    local screen
    local function doclose()
        TheFrontEnd:PopScreen(screen)
        screen = nil
    end

    screen = PopupDialogScreen(modinfo.name .. STRINGS.SS_JSONERROR_POPUP.NOTICE,
        STRINGS.SS_JSONERROR_POPUP.CAUSE,
        {
            {
            text = STRINGS.SS_JSONERROR_POPUP.CONFIRM,
            cb = doclose
            },
        }
    )

    TheFrontEnd:PushScreen(screen)
    last_popup_time = time
end
