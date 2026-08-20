-- client preview activeitem when using terminal
local TIMEOUT = 0.5
local TerminalItemTile = require "widgets/terminal_itemtile"

local function PreviewTakeActiveItemFromTerminal(inst, item, half)
    local inv = ThePlayer.HUD.controls.inv
    local mousefollow = ThePlayer.HUD.controls.mousefollow
    if inv == nil or mousefollow == nil then return end

    local data = inst.terminal_preview_data
    if data.mode ~= nil then return end

    inv.hovertile = mousefollow:AddChild(TerminalItemTile(item))
    inv.hovertile:StartDrag()
    inv.hovertile.terminalpreview = true

    -- 计算拿取数量
    local takestacksize = nil -- nil means no stackable
    local stackable = item.replica.stackable
    if stackable then
        local stacksize = stackable:StackSize()
        local fullstacksize = math.min(stacksize, stackable:OriginalMaxSize())
        if half then
            takestacksize = math.floor(fullstacksize / 2)
        else
            takestacksize = fullstacksize
        end
        inv.hovertile:SetOverrideQuantity(takestacksize)

        data.stacksize = takestacksize
        data.origialstacksize = 0
    end

    data.mode = "take"
    data.item = item

    inst:QueueClearTerminalPreview()
end

local function CalcPutStackSize(item, originalstacksize, container)
    local count = originalstacksize -- 剩下几个

    for i = 1, container:GetNumSlots() do

        local slotitem = container:GetItemInSlot(i)
        if slotitem == nil then
            -- 有空格子，肯定能放进去
            count = 0
        elseif slotitem.prefab == item.prefab and item:StackableSkinHack(slotitem) and
            slotitem.replica.stackable and not slotitem.replica.stackable:IsFull() then

            local stacksize = slotitem.replica.stackable:StackSize() + count
            local maxsize = slotitem.replica.stackable:MaxSize()

            if stacksize > maxsize then
                count = stacksize - maxsize
            else
                count = 0
            end
        end

        if count <= 0 then
            break
        end
    end

    return originalstacksize - count
end

local function PreviewPutActiveItemToTerminal(inst, container, one)
    local item = inst:GetActiveItem()
    if item == nil then return end

    local inv = ThePlayer.HUD.controls.inv
    if inv == nil or inv.hovertile == nil then return end

    local data = inst.terminal_preview_data
    if data.mode ~= nil then return end

    inv.hovertile.terminalpreview = true

    local putstacksize = nil
    local stackable = item.replica.stackable
    local stacksize = stackable and stackable:StackSize() or nil
    if stackable then
        -- clac putstacksize
        if one then
            putstacksize = 1
        else
            putstacksize = CalcPutStackSize(item, stacksize, container)
        end

        data.stacksize = stacksize - putstacksize
        data.origialstacksize = stacksize
    end

    if putstacksize == nil or putstacksize == stacksize then
        -- put entire
        inv.hovertile:Hide()
    else
        -- put part
        stackable:SetPreviewStackSize(stacksize - putstacksize, "activeitem", TIMEOUT)

        inv.hovertile:SetQuantity(stacksize - putstacksize)
        inv.hovertile:ScaleTo(inv.hovertile.basescale * 2, inv.hovertile.basescale, .25)
        inv.hovertile.ispreviewing = true
    end

    data.mode = "put"
    data.item = item

    inst:QueueClearTerminalPreview()
end

local function ClearTerminalPreview(inst, restore)
    if inst.clear_terminalpreview_task then
        inst.clear_terminalpreview_task:Cancel()
        inst.clear_terminalpreview_task = nil
    end

    local inv = ThePlayer.HUD.controls.inv
    if inv == nil then return end

    local data = inst.terminal_preview_data
    local mode = data.mode

    if inv.hovertile and inv.hovertile.terminalpreview then
        inv.hovertile.terminalpreview = false

        if mode == "take" and restore then
            inv.hovertile:Kill()
            inv.hovertile = nil
        elseif mode == "put" then
            inv.hovertile:Show()
            local origialstacksize = data.origialstacksize
            if origialstacksize and restore then
                inv.hovertile:SetQuantity(origialstacksize)
                inv.hovertile.ispreviewing = false
            end
        end
    end

    inst:InitTerminalPreviewData()
end

local function QueueClearTerminalPreview(inst)
    if inst.clear_terminalpreview_task then
        inst.clear_terminalpreview_task:Cancel()
    end
    inst.clear_terminalpreview_task = inst:DoTaskInTime(TIMEOUT, function()
        inst:ClearTerminalPreview(true)
    end)
end

local function GetActiveItemWithTerminalPreview(inst)
    local data = inst.terminal_preview_data
    local mode = data.mode

    if mode == "take" then
        return data.item
    elseif mode == "put" then
        if data.stacksize == 0 or data.stacksize == nil then
            return nil
        else
            return data.item
        end
    else
        return inst:GetActiveItem()
    end
end

local function RegisterNetListeners(inst)

    inst:ListenForEvent("activedirty", function()
        inst:DoStaticTaskInTime(0, function()
            inst:ClearTerminalPreview()
        end)
    end)

    inst:ListenForEvent("stackitemdirty", function(world, item)
        if item ~= inst:GetActiveItem() then return end
        inst:DoStaticTaskInTime(0, function()
            inst:ClearTerminalPreview()
        end)
    end, TheWorld)
end

local function InitTerminalPreviewData(inst)
    inst.terminal_preview_data = {
        -- nil, "take", "put"
        mode = nil,
        item = nil,
        -- for stackable item
        origialstacksize = nil,
        stacksize = nil,
    }
end

AddPrefabPostInit("inventory_classified" ,function(inst)
    if TheWorld.ismastersim then return end
    -- client interface

    inst.PreviewTakeActiveItemFromTerminal = PreviewTakeActiveItemFromTerminal
    inst.PreviewPutActiveItemToTerminal = PreviewPutActiveItemToTerminal

    inst.ClearTerminalPreview = ClearTerminalPreview
    inst.QueueClearTerminalPreview = QueueClearTerminalPreview

    inst.GetActiveItemWithTerminalPreview = GetActiveItemWithTerminalPreview

    inst.InitTerminalPreviewData = InitTerminalPreviewData
    inst:InitTerminalPreviewData()

    inst:DoStaticTaskInTime(0, RegisterNetListeners)
end)
