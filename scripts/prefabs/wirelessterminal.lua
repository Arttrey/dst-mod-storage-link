local assets =
{
    Asset("ANIM", "anim/wirelessterminal.zip"),
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("wirelessterminal")
    inst.AnimState:SetBuild("wirelessterminal")
    inst.AnimState:PlayAnimation("idle", true)
    inst.AnimState:SetScale(0.85, 0.85)

    MakeInventoryFloatable(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("wirelessterminal")

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "wirelessterminal"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/wirelessterminal.xml"

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("wirelessterminal", fn, assets)