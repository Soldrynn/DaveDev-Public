local Client = DaveDevFlashliteClient
local K = Client.constants
local U = Client.utils

function Client.drawBeam(state, origin, dir, factorOverride, shadowId)
  local tuneIndex = state and state.tuneIndex or 0
  local factor = type(factorOverride) == 'number' and factorOverride or (1.0 + (tuneIndex * K.STEP_FACTOR))

  local tunedRadius = K.BASE_RADIUS * factor
  local radius = math.min(K.MAX_RADIUS, math.max(K.MIN_RADIUS, tunedRadius))

  local tunedBrightness = K.BASE_BRIGHTNESS / math.max(0.1, factor ^ K.BRIGHTNESS_EXP)
  local brightness = math.min(K.MAX_BRIGHTNESS, math.max(K.MIN_BRIGHTNESS, tunedBrightness))

  local tunedMaxDist = K.BASE_MAX_DIST / math.max(0.1, factor ^ K.DISTANCE_EXP)
  local distance = math.min(K.MAX_DISTANCE, math.max(K.MIN_DISTANCE, tunedMaxDist))

  local id = shadowId or Client.LOCAL_SHADOW_ID
  DrawSpotLightWithShadow(origin.x, origin.y, origin.z, dir.x, dir.y, dir.z, K.LIGHT_COLOR_R, K.LIGHT_COLOR_G, K.LIGHT_COLOR_B, distance, brightness, K.HARDNESS, radius, K.FALLOFF, id)
end

function Client.computeTargetRelAngles(ped)
  local cam = GetFinalRenderedCamRot(2)
  local pedHeading = GetEntityHeading(ped)
  local yawRel = U.normdeg(cam.z - pedHeading)
  local pitch = U.normdeg(cam.x)
  return U.clamp(yawRel, -K.YAW_LIMIT, K.YAW_LIMIT),
      U.clamp(pitch, -K.PITCH_LIMIT, K.PITCH_LIMIT)
end

function Client.computeAttachPose(relYaw, relPitch)
  local rx = K.ATTACH_ROT_X + relYaw * K.YAW_SCALE
  local rz = K.ATTACH_ROT_Z + relPitch * K.PITCH_SCALE
  local rotPivot = U.rotateZYX(K.PIVOT_LOCAL, U.deg2rad(rx), U.deg2rad(K.ATTACH_ROT_Y), U.deg2rad(rz))
  local attachPos = vector3(K.ATTACH_POS_X, K.ATTACH_POS_Y, K.ATTACH_POS_Z)
  return attachPos + (K.PIVOT_LOCAL - rotPivot), rx, rz
end

function Client.attachPropForAim(ped, prop, boneIndex, relYaw, relPitch, allowAltMode)
  if not prop or prop == 0 then return nil, nil end

  local posComp, rx, rz = Client.computeAttachPose(relYaw, relPitch)
  if allowAltMode and K.ALT_ROTATION_MODE and DoesEntityExist(prop) then
    if not boneIndex then boneIndex = GetPedBoneIndex(ped, K.HAND_BONE_ID) end
    if boneIndex and boneIndex ~= -1 then
      local boneWorld = GetWorldPositionOfEntityBone(ped, boneIndex)
      if boneWorld then
        SetEntityCoordsNoOffset(prop, boneWorld.x + posComp.x, boneWorld.y + posComp.y, boneWorld.z + posComp.z, false, false, false)
        SetEntityRotation(prop, rx, K.ATTACH_ROT_Y, rz, 2, true)
      end
    end
  else
    Client.attachToBoneCached(ped, prop, boneIndex, posComp.x, posComp.y, posComp.z, rx, K.ATTACH_ROT_Y, rz)
  end

  return rx, rz
end

function Client.getPropBeamTransform(prop)
  if not prop or prop == 0 or not DoesEntityExist(prop) then return nil, nil end

  local fx, fy, fz, ux, uy, uz, px, py, pz = table.unpack({ GetEntityMatrix(prop) })
  if not (fx and fy and fz and ux and uy and uz and px and py and pz) then return nil, nil end

  local forward = vector3(fx, fy, fz)
  local origin = vector3(
    px + fx * K.ORIGIN_FORWARD_OFFSET + ux * K.ORIGIN_UP_OFFSET,
    py + fy * K.ORIGIN_FORWARD_OFFSET + uy * K.ORIGIN_UP_OFFSET,
    pz + fz * K.ORIGIN_FORWARD_OFFSET + uz * K.ORIGIN_UP_OFFSET
  )
  return origin, forward
end

function Client.getFallbackBeamTransform(ped, boneIndex, relYaw, relPitch)
  if not ped or not boneIndex then return nil, nil end

  local pedHeading = GetEntityHeading(ped)
  local worldYaw = U.normdeg(pedHeading + relYaw)
  local handPos = GetWorldPositionOfEntityBone(ped, boneIndex)
  local pitch = U.deg2rad(relPitch)
  local heading = U.deg2rad(worldYaw)
  local cosPitch = math.cos(pitch)
  local sinPitch = math.sin(pitch)
  local sinHeading = math.sin(heading)
  local cosHeading = math.cos(heading)
  local forward = vector3(cosPitch * -sinHeading, cosPitch * cosHeading, sinPitch)
  local origin = vector3(handPos.x + forward.x * 0.25, handPos.y + forward.y * 0.25, handPos.z + forward.z * 0.25 + 0.02)
  return origin, forward
end
