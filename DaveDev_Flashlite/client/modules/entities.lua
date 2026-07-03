local Client = DaveDevFlashliteClient
local K = Client.constants

function Client.attachToBone(ped, obj, boneId, ox, oy, oz, rx, ry, rz)
  local bone = GetPedBoneIndex(ped, boneId)
  AttachEntityToEntity(obj, ped, bone, ox, oy, oz, rx, ry, rz, true, true, false, true, 2, true)
end

function Client.attachToBoneCached(ped, obj, boneIndex, ox, oy, oz, rx, ry, rz)
  AttachEntityToEntity(obj, ped, boneIndex, ox, oy, oz, rx, ry, rz, true, true, false, true, 2, true)
end

local function configureProp(prop, ped)
  SetEntityCollision(prop, false, false)
  SetEntityNoCollisionEntity(prop, ped, true)
  SetEntityDynamic(prop, false)
  SetEntityHasGravity(prop, false)
  FreezeEntityPosition(prop, true)
  SetEntityInvincible(prop, true)
  SetEntityCanBeDamaged(prop, false)
  SetEntityProofs(prop, true, true, true, true, true, true, true, true)
  SetEntityAsMissionEntity(prop, true, true)
  SetEntityLodDist(prop, 5000)
end

function Client.spawnLocalPropFor(ped)
  Client.ensureModel(K.FLASHLIGHT_MODEL)
  local prop = CreateObject(K.FLASHLIGHT_MODEL, 0.0, 0.0, 0.0, false, false, false)
  configureProp(prop, ped)
  Client.attachToBone(ped, prop, K.HAND_BONE_ID, K.ATTACH_POS_X, K.ATTACH_POS_Y, K.ATTACH_POS_Z, K.ATTACH_ROT_X, K.ATTACH_ROT_Y, K.ATTACH_ROT_Z)
  return prop
end

function Client.spawnOwnerProp(ped, state)
  Client.ensureModel(K.FLASHLIGHT_MODEL)
  local prop = CreateObject(K.FLASHLIGHT_MODEL, 0.0, 0.0, 0.0, false, false, false)
  configureProp(prop, ped)

  local timeout = 0
  while not DoesEntityExist(prop) and timeout < 100 do
    Wait(10)
    timeout = timeout + 1
  end

  if DoesEntityExist(prop) then
    Client.attachToBone(ped, prop, K.HAND_BONE_ID, K.ATTACH_POS_X, K.ATTACH_POS_Y, K.ATTACH_POS_Z, K.ATTACH_ROT_X, K.ATTACH_ROT_Y, K.ATTACH_ROT_Z)
    if state then state.propExists = true end
    return prop
  end

  if DoesEntityExist(prop) then DeleteObject(prop) end
  if state then state.propExists = false end
  return nil
end

function Client.deleteOwnerProp(state, releaseSession)
  if state.prop and state.prop ~= 0 then
    DeleteObject(state.prop)
  end
  state.prop = nil
  state.propExists = false

  if state.corona and state.corona ~= 0 then
    DeleteObject(state.corona)
  end
  state.corona = nil
  state.coronaExists = false

  if releaseSession then
    releaseSession()
  end
end
