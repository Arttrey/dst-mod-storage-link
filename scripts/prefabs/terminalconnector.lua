require "prefabutil"
local TechTree = require("techtree")

local assets =
{
    Asset("ANIM", "anim/terminalconnector.zip"),
}

local function onhammered(inst, worker)
    if inst.components.burnable ~= nil and inst.components.burnable:IsBurning() then
        inst.components.burnable:Extinguish()
    end
    inst.components.lootdropper:DropLoot()
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("metal")
    inst:Remove()
end

local function onhit(inst, worker)

end

local function onsave(inst, data)
    if inst:HasTag("burnt") or (inst.components.burnable ~= nil and inst.components.burnable:IsBurning()) then
        data.burnt = true
    end
end

local function onload(inst, data)
    if data ~= nil and data.burnt and inst.components.burnable ~= nil and inst.components.burnable.onburnt ~= nil then
        inst.components.burnable.onburnt(inst)
    end
end

local function onbuilt(inst)
    inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/firesupressor_craft")
    inst.AnimState:PlayAnimation("onbuilt", false)
end

local function onturnon(inst)
    inst.AnimState:PushAnimation("turnon")
    if not inst.SoundEmitter:PlayingSound("idlesound") then
        inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_lvl2_idle_LP", "idlesound")
        inst.SoundEmitter:SetVolume("idlesound", 0.6)
    end
    local base_tree = {}
    if TUNING.SS_NEARBY_STATIONS then
        local radius = TUNING.SS_LINKRADIUS
        local x, y, z = inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, radius, {"prototyper"})
        for i, ent in ipairs(ents) do
            if ent.components.prototyper and ent ~= inst then
                local tree = ent.components.prototyper:GetTechTrees() or {}
                for k, v in pairs(tree) do
                    if type(v) == "number" and v > 0 then
                        if base_tree[k] then
                            base_tree[k] = math.max(base_tree[k], v)
                        else
                            base_tree[k] = v
                        end
                    end
                end
            end
        end
    end
    inst.components.prototyper.trees = TechTree.Create(base_tree)
end

local function onturnoff(inst)
    inst.AnimState:PushAnimation("turnoff")
    inst.SoundEmitter:KillSound("idlesound")
end

--------------------------------------------------------------------------
-- 1.55 -> 15
local PLACER_SCALE = 1.55 * math.sqrt(TUNING.SS_LINKRADIUS/15)

local function OnEnableHelper(inst, enabled)
    if enabled then
        if inst.helper == nil then
            inst.helper = CreateEntity()

            --[[Non-networked entity]]
            inst.helper.entity:SetCanSleep(false)
            inst.helper.persists = false

            inst.helper.entity:AddTransform()
            inst.helper.entity:AddAnimState()

            inst.helper:AddTag("CLASSIFIED")
            inst.helper:AddTag("NOCLICK")
            inst.helper:AddTag("placer")

            inst.helper.Transform:SetScale(PLACER_SCALE, PLACER_SCALE, PLACER_SCALE)
            
            inst.helper.AnimState:SetBank("firefighter_placement")
            inst.helper.AnimState:SetBuild("firefighter_placement")
            inst.helper.AnimState:PlayAnimation("idle")
            inst.helper.AnimState:SetLightOverride(1)
            inst.helper.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
            inst.helper.AnimState:SetLayer(LAYER_BACKGROUND)
            inst.helper.AnimState:SetSortOrder(1)
            inst.helper.AnimState:SetAddColour(0.6, 0.6, 0.1, 0)

            inst.helper.entity:SetParent(inst.entity)
        end
    elseif inst.helper ~= nil then
        inst.helper:Remove()
        inst.helper = nil
    end
end

--------------------------------------------------------------------------

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    -- inst.MiniMapEntity:SetPriority(5)
    -- inst.MiniMapEntity:SetIcon("firesuppressor.png")

	inst:SetDeploySmartRadius(1) --recipe min_spacing/2
    MakeObstaclePhysics(inst, 0.75)

    inst.AnimState:SetBank("terminalconnector")
    inst.AnimState:SetBuild("terminalconnector")
    inst.AnimState:PlayAnimation("turnoff", false)

    inst:AddTag("giftmachine")
    inst:AddTag("structure")
    inst:AddTag("terminalconnector")
    -- 制作标签
    inst:AddTag("lunar_forge")
    inst:AddTag("shadow_forge")
    inst:AddTag("carpentry_station")

    if not TheNet:IsDedicated() then
        local deployhelper = inst:AddComponent("deployhelper")
        deployhelper.onenablehelper = OnEnableHelper

        local old_StartHelper = deployhelper.StartHelper
        function deployhelper:StartHelper(recipename, placerinst)
            local name = tostring(recipename)
            if name == "magician_chest" then
                return
            elseif name == "terminalconnector" or string.find(name, "chest") then
                return old_StartHelper(self, recipename, placerinst)
            end
        end
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("terminalconnector")

    inst:ListenForEvent("onbuilt", onbuilt)

    inst:AddComponent("inspectable")

    inst:AddComponent("prototyper")
    -- 基本科技树
    inst.components.prototyper.trees = TechTree.Create()
    inst.components.prototyper.onturnon = onturnon
    inst.components.prototyper.onturnoff = onturnoff

    inst:UnregisterComponentActions("prototyper")

    inst:AddComponent("lootdropper")

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(onhammered)
    inst.components.workable:SetOnWorkCallback(onhit)

    inst.OnSave = onsave
    inst.OnLoad = onload

    MakeHauntableWork(inst)

    return inst
end

local function placer_postinit_fn(inst)

    local placer2 = CreateEntity()

    --[[Non-networked entity]]
    placer2.entity:SetCanSleep(false)
    placer2.persists = false

    placer2.entity:AddTransform()
    placer2.entity:AddAnimState()

    placer2:AddTag("CLASSIFIED")
    placer2:AddTag("NOCLICK")
    placer2:AddTag("placer")

    local s = 1 / PLACER_SCALE
    placer2.Transform:SetScale(s, s, s)

    placer2.AnimState:SetBank("terminalconnector")
    placer2.AnimState:SetBuild("terminalconnector")
    placer2.AnimState:PlayAnimation("turnoff")
    placer2.AnimState:SetLightOverride(1)

    placer2.entity:SetParent(inst.entity)

    inst.components.placer:LinkEntity(placer2)
end


return Prefab("terminalconnector", fn, assets),
    MakePlacer("terminalconnector_placer", "firefighter_placement", "firefighter_placement", "idle", true, nil, nil, PLACER_SCALE, nil, nil, placer_postinit_fn)
