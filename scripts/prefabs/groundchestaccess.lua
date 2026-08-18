local assets =
{
    Asset("ANIM", "anim/dragonfly_chest.zip"),
    Asset("ANIM", "anim/ui_chest_3x3.zip"),
    Asset("ANIM", "anim/ui_chest_upgraded_3x3.zip"),
}

local function OnHammered(inst, worker)
    if inst.components.container ~= nil then
        inst.components.container:Close()
    end
    inst.components.lootdropper:DropLoot()
    inst:Remove()
end

local function OnHit(inst)
    inst.AnimState:PlayAnimation("hit")
    inst.AnimState:PushAnimation("closed", false)
end

local function OnOpen(inst)
    if inst._storageaccess_capture ~= nil then
        inst._storageaccess_capture(inst)
    end
end

local function OnClose(inst)
    if inst._storageaccess_flush ~= nil then
        inst._storageaccess_flush(inst)
    end
end

local function OnSave(inst, data)
    -- Предметы не должны сохраняться внутри точки доступа.
    if inst.components.container ~= nil and not inst.components.container:IsEmpty() and inst._storageaccess_flush ~= nil then
        inst._storageaccess_flush(inst)
    end
    data.empty = true
end

local function OnRemoveEntity(inst)
    if inst.components.container ~= nil and not inst.components.container:IsEmpty() and inst._storageaccess_flush ~= nil then
        inst._storageaccess_flush(inst)
    end
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("dragonflychest.png")
    inst:AddTag("structure")
    inst:AddTag("groundchestaccess")

    inst.AnimState:SetBank("dragonfly_chest")
    inst.AnimState:SetBuild("dragonfly_chest")
    -- Не меняем цвет модели: иконка рецепта и объект в мире должны выглядеть одинаково.
    inst.AnimState:SetMultColour(1.0, 1.0, 1.0, 1.0)
    inst.AnimState:PlayAnimation("closed")

    inst.Light:SetFalloff(0.8)
    inst.Light:SetIntensity(0.6)
    inst.Light:SetRadius(1.5)
    inst.Light:SetColour(0.25, 0.8, 1.0)
    inst.Light:Enable(true)

    MakeObstaclePhysics(inst, 0.4)
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("container")
    inst.components.container:WidgetSetup("groundchestaccess")
    inst.components.container.onopenfn = OnOpen
    inst.components.container.onclosefn = OnClose
    inst.components.container.openlimit = 1
    inst.components.container.skipopensnd = true
    inst.components.container.skipclosesnd = true

    -- Опционально делаем точку доступа прототипером уровня Наука II.
    -- Это использует штатные компоненты DST и включается только настройкой
    -- crafting_integration; постоянного крафтового хранилища здесь нет.
    if GLOBAL.STORAGE_LINK_CRAFTING_INTEGRATION and GLOBAL.TechTree ~= nil then
        inst:AddTag("prototyper")
        inst:AddComponent("prototyper")
        inst.components.prototyper.trees = GLOBAL.TechTree.Create({ SCIENCE = 4 })
    end

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:AddChanceLoot("boards", 1.0)
    inst.components.lootdropper:AddChanceLoot("rope", 1.0)

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(2)
    inst.components.workable:SetOnWorkCallback(OnHit)
    inst.components.workable:SetOnFinishCallback(OnHammered)

    MakeSmallBurnable(inst, nil, nil, true)
    MakeMediumPropagator(inst)
    MakeSnowCovered(inst)

    inst.OnSave = OnSave
    inst.OnRemoveEntity = OnRemoveEntity

    return inst
end

return Prefab("groundchestaccess", fn, assets),
    MakePlacer("groundchestaccess_placer", "dragonfly_chest", "dragonfly_chest", "closed")
