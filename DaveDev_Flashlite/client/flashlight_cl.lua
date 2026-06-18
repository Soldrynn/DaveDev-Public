local cfg = FlashliteConfig or {}
local commandsCfg = cfg.commands or {}
local equipCfg = commandsCfg.equip or {}
local equipKeybindCfg = equipCfg.keybind or {}
local toggleCfg = commandsCfg.toggleLight or {}

local EQUIP_ENABLED = equipCfg.enabled ~= false
local EQUIP_COMMAND = equipCfg.name or 'flashlite'
local EQUIP_DESC = equipCfg.description or 'Equip or holster your Flashlite'
local EQUIP_KEYBIND_ENABLED = equipCfg.enabled ~= false and equipKeybindCfg.enabled ~= false
local EQUIP_KEYBIND_COMMAND = equipKeybindCfg.command or equipKeybindCfg.name or '+davedev_flashlite'
local EQUIP_KEYBIND_RELEASE_COMMAND = EQUIP_KEYBIND_COMMAND:gsub('^%+', '-')
local EQUIP_KEYBIND_DESC = equipKeybindCfg.description or EQUIP_DESC
local EQUIP_KEYBIND_MAPPER = equipKeybindCfg.mapper or 'keyboard'
local EQUIP_KEYBIND_KEY = equipKeybindCfg.key or 'O'
local REGISTER_EQUIP_KEYMAP = equipKeybindCfg.registerKeyMapping ~= false

local TOGGLE_ENABLED = toggleCfg.enabled ~= false
local TOGGLE_COMMAND = toggleCfg.name or 'flashlite_toggle'
local TOGGLE_DESC = toggleCfg.description or 'Toggle Flashlite beam'
local TOGGLE_KEY = toggleCfg.key or 'MOUSE_MIDDLE'
local REGISTER_KEYMAP = toggleCfg.registerKeyMapping ~= false

local SHADOW_ID_MIN = 1
local SHADOW_ID_MAX = 16
local SHADOW_ID_RANGE = SHADOW_ID_MAX - SHADOW_ID_MIN + 1
local shadowUsage = {}

local function acquireShadowId(preferred)
  local candidate = preferred and math.floor(preferred) or nil
  if candidate and candidate >= SHADOW_ID_MIN and candidate <= SHADOW_ID_MAX then
    if not shadowUsage[candidate] then
      shadowUsage[candidate] = 1
      return candidate
    end
  end

  for id = SHADOW_ID_MIN, SHADOW_ID_MAX do
    if not shadowUsage[id] then
      shadowUsage[id] = 1
      return id
    end
  end

  candidate = candidate or SHADOW_ID_MIN
  if candidate < SHADOW_ID_MIN or candidate > SHADOW_ID_MAX then
    candidate = ((candidate - SHADOW_ID_MIN) % SHADOW_ID_RANGE) + SHADOW_ID_MIN
  end
  shadowUsage[candidate] = (shadowUsage[candidate] or 0) + 1
  return candidate
end

local function releaseShadowId(id)
  if not id then return end
  local candidate = math.floor(id)
  if candidate < SHADOW_ID_MIN or candidate > SHADOW_ID_MAX then return end
  local uses = shadowUsage[candidate]
  if not uses then return end
  uses = uses - 1
  if uses <= 0 then
    shadowUsage[candidate] = nil
  else
    shadowUsage[candidate] = uses
  end
end

local localPlayerHandle = PlayerId and PlayerId() or 0
local localServerId = GetPlayerServerId and GetPlayerServerId(localPlayerHandle) or 0
local LOCAL_SHADOW_ID = acquireShadowId((((tonumber(localServerId) or 0) % SHADOW_ID_RANGE) + SHADOW_ID_MIN))

local DEG2RAD = 0.017453292519943295
local FULL_CIRCLE = 360.0
local HALF_CIRCLE = 180.0

local lightCfg = cfg.light or {}
local controlsCfg = cfg.controls or {}
local optimizationCfg = cfg.optimization or {}
local audioCfg = cfg.audio or {}

local FLASHLIGHT_MODEL = `prop_cs_police_torch`
local HAND_BONE_ID = 0xDEAD
local FOLLOW_CONTROL = controlsCfg.followControl or 25
local CONE_INCREASE = controlsCfg.coneIncrease or 241
local CONE_DECREASE = controlsCfg.coneDecrease or 242
local YAW_LIMIT = lightCfg.yawLimit or 35.0
local PITCH_LIMIT = lightCfg.pitchLimit or 50.0
local INVERT_PITCH = controlsCfg.invertPitch == true

local LIGHT_COLOR_R = (lightCfg.color and lightCfg.color.r) or 255
local LIGHT_COLOR_G = (lightCfg.color and lightCfg.color.g) or 255
local LIGHT_COLOR_B = (lightCfg.color and lightCfg.color.b) or 240
local BASE_BRIGHTNESS = lightCfg.brightness or 12.0
local HARDNESS = lightCfg.hardness or 0.35
local BASE_RADIUS = lightCfg.radius or 12.0
local FALLOFF = lightCfg.falloff or 12.0
local ORIGIN_FORWARD_OFFSET = lightCfg.originForwardOffset or 0.18
local ORIGIN_UP_OFFSET = lightCfg.originUpOffset or 0.02

local tuning = lightCfg.tuning or {}
local STEP_FACTOR = tuning.stepFactor or 0.12
local MIN_RADIUS = tuning.minRadius or 0.1
local MAX_RADIUS = tuning.maxRadius or 1.6
local BRIGHTNESS_EXP = tuning.brightnessExp or 2.0
local MIN_BRIGHTNESS = tuning.minBrightness or 0.5
local MAX_BRIGHTNESS = tuning.maxBrightness or 24.0
local DISTANCE_EXP = tuning.distanceExp or 0.8
local MIN_DISTANCE = tuning.minDistance or (lightCfg.maxDistance or 25.0) * 0.6
local MAX_DISTANCE = tuning.maxDistance or (lightCfg.maxDistance or 25.0) * 2.0
local BASE_MAX_DIST = lightCfg.maxDistance or 25.0
local TUNING_STEPS = tuning.steps or 5
local HALF_STEPS = math.floor(TUNING_STEPS / 2)

local ATTACH_POS_X = 0.080
local ATTACH_POS_Y = 0.020
local ATTACH_POS_Z = -0.030
local ATTACH_ROT_X = 12.0
local ATTACH_ROT_Y = 0.0
local ATTACH_ROT_Z = -18.0
local YAW_SCALE = 1.0
local PITCH_SCALE = 1.15
local PIVOT_FORWARD = 0.0
local PIVOT_UP = 0.0
local PIVOT_AXIS = 'y'

local SHARE_INTERVAL_MS = optimizationCfg.shareIntervalMs or 80
local MIN_YAW_DELTA = optimizationCfg.minYawDeltaDeg or 0.25
local MIN_PITCH_DELTA = optimizationCfg.minPitchDeltaDeg or 0.25
local MAX_SHARE_DISTANCE = optimizationCfg.maxShareDistance or 150.0
local REM_STALE_TIMEOUT = optimizationCfg.staleTimeoutMs or 15000

local FOLLOW_SMOOTH = optimizationCfg.followSmoothing or 16.0
local REMOTE_SMOOTH = optimizationCfg.remoteSmoothing or 28.0
local ALWAYS_TRACK = false
local FORCE_IDLE_SHARE = true
local REATTACH_EVERY_FRAME = optimizationCfg.reattachEveryFrame ~= false
local REATTACH_INTERVAL_MS = optimizationCfg.reattachIntervalMs or 400
local ALT_ROTATION_MODE = false

local AUDIO_ENABLED = audioCfg.enabled ~= false
local AUDIO_RELEASE_MS = 1000

local function resolveAudioCue(value, defaultName, defaultSoundset)
  if type(value) == 'table' then
    return {
      name = value.name or defaultName,
      soundset = value.soundset or audioCfg.soundset or defaultSoundset,
    }
  end

  if type(value) == 'string' and value ~= '' then
    return {
      name = value,
      soundset = audioCfg.soundset or defaultSoundset,
    }
  end

  return {
    name = defaultName,
    soundset = audioCfg.soundset or defaultSoundset,
  }
end

local AUDIO_ON = resolveAudioCue(audioCfg.on, 'Click', 'DLC_HEIST_HACKING_SNAKE_SOUNDS')
local AUDIO_OFF = resolveAudioCue(audioCfg.off, 'CLICK_BACK', 'WEB_NAVIGATION_SOUNDS_PHONE')

local behaviorCfg = {
  coronaUseTipOffsets = true,
  coronaTipForward = 0.0,
  coronaTipInvert = false,
  coronaFinalDX = 0.0,
  coronaFinalDY = -0.39,
  coronaFinalDZ = 0.0,
}

local PIVOT_LOCAL = (PIVOT_AXIS == 'x') and vector3(PIVOT_FORWARD, 0.0, PIVOT_UP) or vector3(0.0, PIVOT_FORWARD, PIVOT_UP)

local function ensureModel(model) if lib and lib.requestModel then lib.requestModel(model, 10000) else while not HasModelLoaded(model) do RequestModel(model) Wait(0) end end end
local function ensureAnim(dict)  if lib and lib.requestAnimDict then lib.requestAnimDict(dict, 10000) else while not HasAnimDictLoaded(dict) do RequestAnimDict(dict) Wait(0) end end end

local function clamp(x,lo,hi) if x<lo then return lo elseif x>hi then return hi else return x end end
local function deg2rad(d) return d * DEG2RAD end
local function normdeg(d) d = d % FULL_CIRCLE; if d > HALF_CIRCLE then d = d - FULL_CIRCLE end; return d end
local function angdiff(a,b) local d=(b-a+HALF_CIRCLE)%FULL_CIRCLE-HALF_CIRCLE return (d<-HALF_CIRCLE) and (d+FULL_CIRCLE) or d end
local function lerp(a,b,t) return a + (b - a) * t end
local function lerpAng(a,b,t) return a + angdiff(a,b) * t end

local function rotX(v,a) local c,s=math.cos(a),math.sin(a); return vector3(v.x, v.y*c - v.z*s, v.y*s + v.z*c) end
local function rotY(v,a) local c,s=math.cos(a),math.sin(a); return vector3(v.x*c + v.z*s, v.y, -v.x*s + v.z*c) end
local function rotZ(v,a) local c,s=math.cos(a),math.sin(a); return vector3(v.x*c - v.y*s, v.x*s + v.y*c, v.z) end
local function rotateZYX(v, rx,ry,rz) local r=rotZ(v,rz); r=rotY(r,ry); r=rotX(r,rx); return r end

local function playNativeToggleAudio(isOn, entity)
  if not AUDIO_ENABLED then return end
  local cue = isOn and AUDIO_ON or AUDIO_OFF
  local soundName = cue and cue.name
  local soundset = cue and cue.soundset
  if type(soundName) ~= 'string' or soundName == '' then return end
  if type(soundset) ~= 'string' or soundset == '' then return end

  local soundId = GetSoundId()
  if not soundId or soundId < 0 then return end

  if entity and entity ~= 0 and DoesEntityExist(entity) then
    PlaySoundFromEntity(soundId, soundName, entity, soundset, false, 0)
  else
    PlaySoundFrontend(soundId, soundName, soundset, true)
  end

  if SetTimeout then
    SetTimeout(AUDIO_RELEASE_MS, function()
      ReleaseSoundId(soundId)
    end)
  else
    ReleaseSoundId(soundId)
  end
end

local STATE = {
  active=false, busy=false, aim=false,
  prop=nil, propExists=false,
  corona=nil, coronaExists=false,
  relYaw=0.0, relPitch=-5.0,
  _apYaw=nil, _apPitch=nil,
  lastOrigin=nil, lastDir=nil,
  lastShare=0, tuneIndex=0,
  prev = { canUseWeapons=nil },
  _lastNet=nil,
  animPlaying=false,
  lightOn=false,
  lastUsePayload=nil,
  lastAnimCheck=0,
  lastControlCheck=0,
  cachedPed=nil,
  cachedPedTime=0,
  cachedBoneIndex=nil,
  sessionToken=nil,
  pendingDeactivate=false
}

local function releaseAuthorizedSession()
  local token = STATE.sessionToken
  STATE.sessionToken = nil
  if token then
    TriggerServerEvent('davedev_flashlite:server:Unmounted', token)
  end
end

local REM = {}
local REM_THREAD = { running=false }

local coronaCfg = cfg.corona or {}
local CORONA_ENABLED = coronaCfg.enabled ~= false
local CORONA_MODEL = `flashlight_corona_prop`
local CORONA_POS = { x = 0.0, y = 0.175, z = 0.010 }
local CORONA_ROT = { x = -90.0, y = 0.0, z = 0.0 }
local CORONA_REMOTE_ENABLED = (coronaCfg.remoteEnabled ~= false)
local CORONA_REMOTE_MAX = coronaCfg.maxRemote or -1
local CORONA_FLAG_ADJUSTMENTS = {
  { flag = 322, offset = { x = 0.088, y = 0.0, z = 0.010 } },
}

local function _computeCoronaOffsets(_ped)
  local useTip   = behaviorCfg.coronaUseTipOffsets
  local fwdExtra = useTip and ((behaviorCfg.coronaTipForward or 0.055) * (behaviorCfg.coronaTipInvert and -1 or 1)) or 0.38
  local upExtra  = useTip and (behaviorCfg.coronaTipUp or 0.0) or 0.05
  local posX = (CORONA_POS.x or 0.0) + fwdExtra
  local posY = (CORONA_POS.y or 0.0)
  local posZ = (CORONA_POS.z or 0.0) + upExtra

  local fdX = (behaviorCfg.coronaFinalDX or 0.0)
  local fdY = (behaviorCfg.coronaFinalDY or 0.0)
  local fdZ = (behaviorCfg.coronaFinalDZ or 0.0)

  return (posX - fdX), (posY + fdY - 0.06), (posZ + fdZ - 0.017)
end

local function _applyCoronaFlagAdjustments(ped, ox, oy, oz)
  if not ped or ped == 0 then return ox, oy, oz end
  if type(CORONA_FLAG_ADJUSTMENTS) ~= 'table' then return ox, oy, oz end

  for i = 1, #CORONA_FLAG_ADJUSTMENTS do
    local adj = CORONA_FLAG_ADJUSTMENTS[i]
    if type(adj) == 'table' then
      local flagId = adj.flag or adj.id
      if flagId then
        local flagCheck = adj.p2
        if flagCheck == nil then flagCheck = true end
        if GetPedConfigFlag(ped, flagId, flagCheck) then
          local offsets = adj.offset or adj
          if type(offsets) == 'table' then
            ox = ox + (offsets.x or 0.0)
            oy = oy + (offsets.y or 0.0)
            oz = oz + (offsets.z or 0.0)
          end
        end
      end
    end
  end

  return ox, oy, oz
end

local function spawnCoronaFor(prop, ped, opts)
  if not CORONA_ENABLED or not prop or not ped or ped == 0 then return nil end

  opts = opts or {}
  local networked = opts.networked == true

  ensureModel(CORONA_MODEL)
  local ppos = GetEntityCoords(ped)

  local c = CreateObject(CORONA_MODEL, ppos.x, ppos.y, ppos.z - 2.0, networked, networked, false)
  if not c or c == 0 then
    c = (CreateObjectNoOffset and CreateObjectNoOffset(CORONA_MODEL, ppos.x, ppos.y, ppos.z - 2.0, networked, networked, false)) or c
  end
  if not c or c == 0 then return nil end

  SetEntityCollision(c, false, false)
  SetEntityInvincible(c, true)
  SetEntityProofs(c, true,true,true,true,true,true,true,true)
  SetEntityAsMissionEntity(c, true, true)
  SetEntityCanBeDamaged(c, false)
  FreezeEntityPosition(c, true)
  SetEntityLodDist(c, 5000)

  local ox,oy,oz = _computeCoronaOffsets(ped)
  ox, oy, oz = _applyCoronaFlagAdjustments(ped, ox, oy, oz)
  AttachEntityToEntity(c, prop, 0x188E, ox, oy, oz, CORONA_ROT.x + 95.0, CORONA_ROT.y, CORONA_ROT.z, false,false,false,false,2,true)
  return c
end

local holdAnimCfg = (cfg.anim and cfg.anim.hold) or cfg.anim or {}
local HOLD_ANIM_DICT = holdAnimCfg.dict or 'flashlightanim@walk@base'
local HOLD_ANIM_NAME = holdAnimCfg.name or 'base'
local TAKE_OUT = { dict = 'amb@world_human_smoking@male@male_a@enter', anim = 'enter', flags = 51 }
local PUT_AWAY = { dict = 'amb@world_human_stand_mobile@male@text@exit', anim = 'exit', flags = 51 }

local function getCachedPed()
  local now = GetGameTimer()
  if not STATE.cachedPed or now - STATE.cachedPedTime > 100 then
    STATE.cachedPed = PlayerPedId()
    STATE.cachedPedTime = now
    STATE.cachedBoneIndex = GetPedBoneIndex(STATE.cachedPed, HAND_BONE_ID)
  end
  return STATE.cachedPed, STATE.cachedBoneIndex
end

local function attachToBone(ped,obj,boneId,ox,oy,oz, rx,ry,rz)
  local bone = GetPedBoneIndex(ped, boneId)
  AttachEntityToEntity(obj, ped, bone, ox,oy,oz, rx,ry,rz, true,true,false, true, 2, true)
end

local function attachToBoneCached(ped,obj,boneIndex,ox,oy,oz, rx,ry,rz)
  AttachEntityToEntity(obj, ped, boneIndex, ox,oy,oz, rx,ry,rz, true,true,false, true, 2, true)
end

local function spawnLocalPropFor(ped)
  ensureModel(FLASHLIGHT_MODEL)
  local p = CreateObject(FLASHLIGHT_MODEL, 0.0,0.0,0.0, false,false,false)
  SetEntityCollision(p, false, false)
  SetEntityNoCollisionEntity(p, ped, true)
  SetEntityDynamic(p, false)
  SetEntityHasGravity(p, false)
  FreezeEntityPosition(p, true)
  SetEntityInvincible(p, true)
  SetEntityCanBeDamaged(p, false)
  SetEntityProofs(p, true, true, true, true, true, true, true, true)
  SetEntityAsMissionEntity(p, true, true)
  SetEntityLodDist(p, 5000)

  attachToBone(ped, p, HAND_BONE_ID, ATTACH_POS_X, ATTACH_POS_Y, ATTACH_POS_Z, ATTACH_ROT_X, ATTACH_ROT_Y, ATTACH_ROT_Z)
  return p
end

local function spawnOwnerProp(ped)
  ensureModel(FLASHLIGHT_MODEL)
  local p = CreateObject(FLASHLIGHT_MODEL, 0.0,0.0,0.0, false,false,false)

  SetEntityCollision(p, false, false); SetEntityNoCollisionEntity(p, ped, true)
  SetEntityDynamic(p, false); SetEntityHasGravity(p, false)
  FreezeEntityPosition(p, true)
  SetEntityInvincible(p, true); SetEntityCanBeDamaged(p, false)
  SetEntityProofs(p, true, true, true, true, true, true, true, true)
  SetEntityAsMissionEntity(p, true, true)
  SetEntityLodDist(p, 5000)

  local timeout = 0
  while not DoesEntityExist(p) and timeout < 100 do
    Wait(10)
    timeout = timeout + 1
  end

  if DoesEntityExist(p) then
    attachToBone(ped, p, HAND_BONE_ID, ATTACH_POS_X, ATTACH_POS_Y, ATTACH_POS_Z, ATTACH_ROT_X, ATTACH_ROT_Y, ATTACH_ROT_Z)
    STATE.propExists = true
  else
    if DoesEntityExist(p) then DeleteObject(p) end
    STATE.propExists = false
    return nil
  end
  return p
end

local function deleteOwnerProp()
  if STATE.prop and STATE.prop ~= 0 then
    DeleteObject(STATE.prop)
  end
  STATE.prop=nil
  STATE.propExists=false
  if STATE.corona and STATE.corona ~= 0 then
    DeleteObject(STATE.corona)
  end
  STATE.corona=nil; STATE.coronaExists=false
  releaseAuthorizedSession()
end

local DISABLES = { {0,24}, {0,25}, {0,FOLLOW_CONTROL}, {0,44}, {0,140}, {0,141}, {0,142}, {0,37}, {0,45}, {0,289} }
local function setControlsDisabled(on)
  if not on then return end
  for i=1,#DISABLES do DisableControlAction(DISABLES[i][1], DISABLES[i][2], true) end
end

local function ensureRemoteShadowId(sid)
  local R = REM[sid]
  if not R then return LOCAL_SHADOW_ID end
  if R.shadowId then return R.shadowId end
  local sidNum = tonumber(sid) or 0
  local preferred = ((sidNum % SHADOW_ID_RANGE) + SHADOW_ID_MIN)
  R.shadowId = acquireShadowId(preferred)
  return R.shadowId
end

local function releaseRemoteShadow(R)
  if R and R.shadowId then
    releaseShadowId(R.shadowId)
    R.shadowId = nil
  end
end

local function clearRemoteEntities(R)
  if not R then return end
  if R.prop and R.prop ~= 0 then DeleteObject(R.prop) end
  if R.corona and R.corona ~= 0 then DeleteObject(R.corona) end
  R.prop=nil; R.corona=nil; R.coronaExists=false
  releaseRemoteShadow(R)
end

local function removeRemoteEntry(sid)
  local R = REM[sid]
  if not R then return end
  clearRemoteEntities(R)
  REM[sid] = nil
end

local function drawBeam(origin, dir, factorOverride, shadowId)
  local factor = type(factorOverride)=='number' and factorOverride or (1.0 + ((STATE.tuneIndex or 0) * STEP_FACTOR))

  local tunedRadius = BASE_RADIUS * factor
  local radius = math.min(MAX_RADIUS, math.max(MIN_RADIUS, tunedRadius))

  local tunedBrightness = BASE_BRIGHTNESS / math.max(0.1, (factor ^ BRIGHTNESS_EXP))
  local brightness = math.min(MAX_BRIGHTNESS, math.max(MIN_BRIGHTNESS, tunedBrightness))

  local tunedMaxDist = BASE_MAX_DIST / math.max(0.1, (factor ^ DISTANCE_EXP))
  local distance = math.min(MAX_DISTANCE, math.max(MIN_DISTANCE, tunedMaxDist))

  local id = shadowId or LOCAL_SHADOW_ID
  DrawSpotLightWithShadow(origin.x,origin.y,origin.z, dir.x,dir.y,dir.z, LIGHT_COLOR_R,LIGHT_COLOR_G,LIGHT_COLOR_B, distance,brightness,HARDNESS,radius,FALLOFF,id)
end

local function computeTargetRelAngles(ped)
  local cam = GetFinalRenderedCamRot(2)
  local pedHeading = GetEntityHeading(ped)
  local yawRel  = normdeg(cam.z - pedHeading)
  local pitch   = normdeg(cam.x)
  return clamp(yawRel, -YAW_LIMIT, YAW_LIMIT),
         clamp(pitch, -PITCH_LIMIT, PITCH_LIMIT)
end

local function runOwnerLoop()
CreateThread(function()
  local frameTime, now, ped, boneIndex
  local lastForcedReattach = 0
  local animCheckInterval = 100
  local controlCheckInterval = 16
  while STATE.active do
    frameTime = GetFrameTime()
    now = GetGameTimer()
    ped, boneIndex = getCachedPed()

    if ped and now - STATE.lastAnimCheck >= animCheckInterval then
      STATE.lastAnimCheck = now
      if not IsEntityPlayingAnim(ped, HOLD_ANIM_DICT, HOLD_ANIM_NAME, 3) then
        ensureAnim(HOLD_ANIM_DICT)
        TaskPlayAnim(ped, HOLD_ANIM_DICT, HOLD_ANIM_NAME, 2.0, -2.0, -1, 51, 0.0, false, false, false)
        STATE.animPlaying = true
      end
    end

    setControlsDisabled(true)

    if now - STATE.lastControlCheck >= controlCheckInterval then
      STATE.lastControlCheck = now
      local rmb = IsDisabledControlPressed(0, FOLLOW_CONTROL) or IsControlPressed(0, FOLLOW_CONTROL)
      local rmb2= IsDisabledControlPressed(0, 25) or IsControlPressed(0, 25)
      STATE.aim = rmb or rmb2

      if STATE.aim or ALWAYS_TRACK then
        if IsDisabledControlJustPressed(0, CONE_INCREASE) or IsControlJustPressed(0, CONE_INCREASE) then
          STATE.tuneIndex = math.min(HALF_STEPS, STATE.tuneIndex + 1)
          TriggerServerEvent('davedev_flashlite:server:Tuning', STATE.sessionToken, STATE.tuneIndex)
        elseif IsDisabledControlJustPressed(0, CONE_DECREASE) or IsControlJustPressed(0, CONE_DECREASE) then
          STATE.tuneIndex = math.max(-HALF_STEPS, STATE.tuneIndex - 1)
          TriggerServerEvent('davedev_flashlite:server:Tuning', STATE.sessionToken, STATE.tuneIndex)
        end

        local tYawRel, tPitch = computeTargetRelAngles(ped)
        local s = (STATE.aim and FOLLOW_SMOOTH or (FOLLOW_SMOOTH * 0.35)) * frameTime
        STATE.relYaw   = lerp(STATE.relYaw, tYawRel, s)
        STATE.relPitch = lerp(STATE.relPitch, INVERT_PITCH and -tPitch or tPitch, s)

        if now - STATE.lastShare >= SHARE_INTERVAL_MS then
          STATE.lastShare = now
          local dy = (STATE._lastNet and math.abs(angdiff(STATE._lastNet.ry, STATE.relYaw))) or math.huge
          local dp = (STATE._lastNet and math.abs(STATE.relPitch - STATE._lastNet.p)) or math.huge
          if dy > MIN_YAW_DELTA or dp > MIN_PITCH_DELTA or (FORCE_IDLE_SHARE and not STATE.aim) then
            TriggerServerEvent('davedev_flashlite:server:Orientation', STATE.sessionToken, STATE.relYaw, STATE.relPitch)
            STATE._lastNet = { ry = STATE.relYaw, p = STATE.relPitch }
          end
        end
      end
    end

      local rx = ATTACH_ROT_X + STATE.relYaw * YAW_SCALE
      local rz = ATTACH_ROT_Z + STATE.relPitch * PITCH_SCALE
      local needReattach = false
      if REATTACH_EVERY_FRAME then
        needReattach = true
      else
        if (not STATE._apYaw) or (math.abs(rx - STATE._apYaw) > 0.05) or (math.abs(rz - STATE._apPitch) > 0.05) then
          needReattach = true
        elseif now - lastForcedReattach > REATTACH_INTERVAL_MS then
          needReattach = true
        end
      end
      if needReattach then
        local rotPivot = rotateZYX(PIVOT_LOCAL, deg2rad(rx), deg2rad(ATTACH_ROT_Y), deg2rad(rz))
        local attachPos = vector3(ATTACH_POS_X, ATTACH_POS_Y, ATTACH_POS_Z)
        local posComp = attachPos + (PIVOT_LOCAL - rotPivot)
        if ALT_ROTATION_MODE and STATE.prop and DoesEntityExist(STATE.prop) then
          if not boneIndex then boneIndex = GetPedBoneIndex(ped, HAND_BONE_ID) end
          if boneIndex and boneIndex ~= -1 then
            local boneWorld = GetWorldPositionOfEntityBone(ped, boneIndex)
            if boneWorld then
              local dx = boneWorld.x + posComp.x
              local dy = boneWorld.y + posComp.y
              local dz = boneWorld.z + posComp.z
              SetEntityCoordsNoOffset(STATE.prop, dx, dy, dz, false,false,false)
              SetEntityRotation(STATE.prop, rx, ATTACH_ROT_Y, rz, 2, true)
            end
          end
        else
          attachToBoneCached(ped, STATE.prop, boneIndex, posComp.x, posComp.y, posComp.z, rx, ATTACH_ROT_Y, rz)
        end
        STATE._apYaw, STATE._apPitch = rx, rz
        lastForcedReattach = now
      end

      local origin, forward
      if STATE.prop and STATE.propExists and DoesEntityExist(STATE.prop) then
        local fx,fy,fz, ux,uy,uz, px,py,pz = table.unpack({GetEntityMatrix(STATE.prop)})
        if fx and fy and fz and px and py and pz and ux and uy and uz then
          forward = vector3(fx, fy, fz)
          local up = vector3(ux, uy, uz)
          origin = vector3(px + fx * ORIGIN_FORWARD_OFFSET + ux * ORIGIN_UP_OFFSET,
                       py + fy * ORIGIN_FORWARD_OFFSET + uy * ORIGIN_UP_OFFSET,
                       pz + fz * ORIGIN_FORWARD_OFFSET + uz * ORIGIN_UP_OFFSET)
        end
      end

      if not (origin and forward) and ped and boneIndex then
        local pedHeading = GetEntityHeading(ped)
        local worldYaw = normdeg(pedHeading + STATE.relYaw)
        local handPos = GetWorldPositionOfEntityBone(ped, boneIndex)
        local pr = deg2rad(STATE.relPitch)
        local heading = deg2rad(worldYaw)
        local cospr, sinpr = math.cos(pr), math.sin(pr)
        local sinheading, cosheading = math.sin(heading), math.cos(heading)
        forward = vector3(cospr * -sinheading, cospr * cosheading, sinpr)
        origin = vector3(handPos.x + forward.x * 0.25, 
                     handPos.y + forward.y * 0.25, 
                     handPos.z + forward.z * 0.25 + 0.02)
      end

      if origin and forward then
        if STATE.lightOn then
          drawBeam(origin, forward)
        end

        STATE.lastOrigin, STATE.lastDir = origin, forward
      end

      Wait(0)
    end
  end)
end

local function ensureRemoteLoop()
  if REM_THREAD.running then return end
  REM_THREAD.running = true
  CreateThread(function()
    local frameTime, myPed, myPos, k, kHead, distanceSq
    local maxDistSq = MAX_SHARE_DISTANCE * MAX_SHARE_DISTANCE
    local distanceCheckInterval = 200
    local lastDistanceCheck = 0

    local function hasActiveRemotes()
      for _, data in pairs(REM) do if data and data.active then return true end end
      return false
    end

    local function countCoronas()
      local count = 0
      for _, data in pairs(REM) do
        if data.corona and data.corona ~= 0 then count = count + 1 end
      end
      return count
    end

    while hasActiveRemotes() do
      frameTime = GetFrameTime()
      k = 1.0 - math.exp(-(REMOTE_SMOOTH) * frameTime)
      kHead = 1.0 - math.exp(-10.0 * frameTime)

      local now = GetGameTimer()
      if now - lastDistanceCheck >= distanceCheckInterval then
        lastDistanceCheck = now
        myPed = PlayerPedId()
        myPos = GetEntityCoords(myPed)
      end

      local anyNear = false

      local seenThisFrame = {}

      for _, pid in ipairs(GetActivePlayers()) do
        local sid = GetPlayerServerId(pid)
        local R = REM[sid]
        if R and R.active then
          seenThisFrame[sid] = true
          local ped = GetPlayerPed(pid)
          if ped and ped ~= 0 then
            R.lastSeen = now
            local pedPos = GetEntityCoords(ped)
            if myPos and pedPos then
              distanceSq = (myPos.x - pedPos.x) ^ 2 + (myPos.y - pedPos.y) ^ 2 + (myPos.z - pedPos.z) ^ 2

              if distanceSq <= maxDistSq then
                anyNear = true

                if not R.prop or R.prop == 0 then
                  R.prop = spawnLocalPropFor(ped)
                  R.apYaw, R.apPitch = nil, nil
                  R.bone = GetPedBoneIndex(ped, HAND_BONE_ID)
                  if CORONA_REMOTE_ENABLED and R.lightOn and (CORONA_REMOTE_MAX < 0 or countCoronas() < CORONA_REMOTE_MAX) then
                    R.corona = spawnCoronaFor(R.prop, ped)
                    R.coronaExists = R.corona and R.corona ~= 0 or false
                    if R.corona and R.coronaExists then SetEntityVisible(R.corona, true, 0) end
                  end
                elseif not R.corona and CORONA_REMOTE_ENABLED and R.prop and R.prop ~= 0 and R.lightOn then
                  if CORONA_REMOTE_MAX < 0 or countCoronas() < CORONA_REMOTE_MAX then
                    R.corona = spawnCoronaFor(R.prop, ped)
                    R.coronaExists = R.corona and R.corona ~= 0 or false
                    if R.corona and R.coronaExists then SetEntityVisible(R.corona, true, 0) end
                  end
                end

                R.ry = (R.ry and lerpAng(R.ry, R.ry_t, k)) or R.ry_t
                R.p  = (R.p  and lerp(R.p,   R.p_t,  k)) or R.p_t

                local yawRel = R.ry or 0.0
                local rx = ATTACH_ROT_X + yawRel * YAW_SCALE
                local rz = ATTACH_ROT_Z + (R.p or 0.0) * PITCH_SCALE
                if (not R.apYaw) or math.abs(rx - R.apYaw) > 0.05 or math.abs(rz - R.apPitch) > 0.05 then
                  local rotPivot = rotateZYX(PIVOT_LOCAL, deg2rad(rx), deg2rad(ATTACH_ROT_Y), deg2rad(rz))
                  local posComp = vector3(ATTACH_POS_X, ATTACH_POS_Y, ATTACH_POS_Z) + (PIVOT_LOCAL - rotPivot)
                  local boneIndex = R.bone or GetPedBoneIndex(ped, HAND_BONE_ID)
                  attachToBoneCached(ped, R.prop, boneIndex, posComp.x, posComp.y, posComp.z, rx, ATTACH_ROT_Y, rz)
                  R.apYaw, R.apPitch = rx, rz
                end

                local origin, forward
                if R.lightOn then
                  local shadowId = ensureRemoteShadowId(sid)
                  if R.prop and R.prop ~= 0 then
                    local fx,fy,fz, ux,uy,uz, px,py,pz = table.unpack({GetEntityMatrix(R.prop)})
                    if fx and fy and fz and px and py and pz and ux and uy and uz then
                      forward = vector3(fx, fy, fz)
                      origin = vector3(px + fx * ORIGIN_FORWARD_OFFSET + ux * ORIGIN_UP_OFFSET,
                                    py + fy * ORIGIN_FORWARD_OFFSET + uy * ORIGIN_UP_OFFSET,
                                    pz + fz * ORIGIN_FORWARD_OFFSET + uz * ORIGIN_UP_OFFSET)
                    end
                  end

                  if not (origin and forward) then
                    local pedHeading = GetEntityHeading(ped)
                    local worldYaw = normdeg(pedHeading + (R.ry or 0.0))
                    local pr = deg2rad(R.p or 0.0)
                    local heading = deg2rad(worldYaw)
                    local handPos = GetWorldPositionOfEntityBone(ped, R.bone or GetPedBoneIndex(ped, HAND_BONE_ID))
                    local cospr, sinpr = math.cos(pr), math.sin(pr)
                    local sinheading, cosheading = math.sin(heading), math.cos(heading)
                    forward = vector3(cospr * -sinheading, cospr * cosheading, sinpr)
                    origin = vector3(handPos.x + forward.x * 0.25,
                                  handPos.y + forward.y * 0.25,
                                  handPos.z + forward.z * 0.25 + 0.02)
                  end

                  if origin and forward then
                    local factorOverride = 1.0 + ((R.tuneIndex or 0) * STEP_FACTOR)
                    drawBeam(origin, forward, factorOverride, shadowId)
                  end
                else
                  releaseRemoteShadow(R)
                end

                if R.corona and R.corona ~= 0 then
                  SetEntityVisible(R.corona, R.lightOn == true, 0)
                end
              else
                clearRemoteEntities(R)
              end
            end
          else
            if R.lastSeen and (now - R.lastSeen > REM_STALE_TIMEOUT) then
              removeRemoteEntry(sid)
            end
          end
        end
      end

      for sid, data in pairs(REM) do
        if data and data.active and not seenThisFrame[sid] then
          if data.lastSeen and (now - data.lastSeen > REM_STALE_TIMEOUT) then
            removeRemoteEntry(sid)
          end
        end
      end

      if anyNear then
        Wait(0)
      else
        Wait(250)
      end
    end

    for sid, _ in pairs(REM) do
      removeRemoteEntry(sid)
    end
    REM_THREAD.running=false
  end)
end

RegisterNetEvent('davedev_flashlite:client:Orientation', function(src, relYaw, pitch)
  if src == GetPlayerServerId(PlayerId()) then return end
  local sid = src
  REM[sid] = REM[sid] or {}
  REM[sid].active = true
  if REM[sid].lightOn == nil then REM[sid].lightOn = false end
  REM[sid].ry_t = clamp(normdeg(relYaw), -YAW_LIMIT, YAW_LIMIT)
  REM[sid].p_t  = clamp(pitch, -PITCH_LIMIT, PITCH_LIMIT)
  REM[sid].lastSeen = GetGameTimer()
  ensureRemoteLoop()
end)

RegisterNetEvent('davedev_flashlite:client:Unmounted', function(src)
  removeRemoteEntry(src)
end)

RegisterNetEvent('davedev_flashlite:client:BeamState', function(src, isOn)
  if src == GetPlayerServerId(PlayerId()) then return end
  local sid = src
  REM[sid] = REM[sid] or {}
  REM[sid].lightOn = isOn == true
  REM[sid].lastSeen = GetGameTimer()

  if not REM[sid].lightOn then
    releaseRemoteShadow(REM[sid])
  end
  if REM[sid].corona and DoesEntityExist(REM[sid].corona) then
    SetEntityVisible(REM[sid].corona, REM[sid].lightOn, 0)
  end
  if REM[sid].active then ensureRemoteLoop() end
end)

local function startHoldAnim(ped)
  ensureAnim(HOLD_ANIM_DICT)
  TaskPlayAnim(ped, HOLD_ANIM_DICT, HOLD_ANIM_NAME, 2.0, -2.0, -1, 51, 0.0, false, false, false)
  STATE.animPlaying = true
end
local function stopHoldAnim(ped)
  if STATE.animPlaying then StopAnimTask(ped, HOLD_ANIM_DICT, HOLD_ANIM_NAME, 1.0) end
  STATE.animPlaying=false
end

local deactivateFlashlight

local function setLightState(on, opts)
  opts = opts or {}
  local desired = on and true or false
  local previous = STATE.lightOn == true
  if not opts.force and previous == desired then
    return
  end

  STATE.lightOn = desired

  if STATE.corona and STATE.corona ~= 0 then
    SetEntityVisible(STATE.corona, desired, 0)
  end

  if LocalPlayer and LocalPlayer.state then
    LocalPlayer.state:set('davedev_flashlite_light_on', desired, true)
  end

  if previous ~= desired and not opts.skipAudio then
    playNativeToggleAudio(desired, STATE.prop or PlayerPedId())
  end

  if not opts.skipNet then
    TriggerServerEvent('davedev_flashlite:server:BeamState', STATE.sessionToken, desired)
  end

end

local function activateFlashlight()
  if STATE.active or STATE.busy then return end
  local ped = PlayerPedId()
  if IsPedInAnyVehicle(ped, false) then return end

  STATE.busy = true

  if LocalPlayer and LocalPlayer.state then
    STATE.prev.canUseWeapons = LocalPlayer.state.canUseWeapons
    LocalPlayer.state.canUseWeapons = false
  end

  ensureAnim(TAKE_OUT.dict)
  TaskPlayAnim(ped, TAKE_OUT.dict, TAKE_OUT.anim, 2.0, -2.0, -1, TAKE_OUT.flags, 0.0, false, false, false)
  Wait(1400)

  STATE.prop = spawnOwnerProp(ped)
  Wait(500)
  StopAnimTask(ped, TAKE_OUT.dict, TAKE_OUT.anim, 0.25)
  startHoldAnim(ped)

  Wait(250)

  if STATE.prop then
    STATE.corona = spawnCoronaFor(STATE.prop, ped)
    STATE.coronaExists = STATE.corona and DoesEntityExist(STATE.corona) or false
  end

  setLightState(false, { skipNet = true })

  local cam = GetFinalRenderedCamRot(2)
  local pedHeading = GetEntityHeading(ped)
  STATE.relYaw   = clamp(normdeg(cam.z - pedHeading), -YAW_LIMIT, YAW_LIMIT)
  STATE.relPitch = clamp(normdeg(cam.x), -PITCH_LIMIT, PITCH_LIMIT)

  setLightState(false, { force = true })


  STATE.active = true; STATE.busy = false
  if LocalPlayer and LocalPlayer.state then LocalPlayer.state:set('davedev_flashlite_active', true, true) end

  if STATE.pendingDeactivate then
    STATE.pendingDeactivate = false
    deactivateFlashlight()
    return
  end

  TriggerServerEvent('davedev_flashlite:server:SessionState', STATE.sessionToken, true)
  TriggerServerEvent('davedev_flashlite:server:Orientation', STATE.sessionToken, STATE.relYaw, STATE.relPitch)
  STATE._lastNet = { ry = STATE.relYaw, p = STATE.relPitch }
  TriggerServerEvent('davedev_flashlite:server:Tuning', STATE.sessionToken, STATE.tuneIndex or 0)

  runOwnerLoop()
end

deactivateFlashlight = function()
  if not STATE.active or STATE.busy then return end
  STATE.busy = true; STATE.active = false

  if LocalPlayer and LocalPlayer.state then
    LocalPlayer.state:set('davedev_flashlite_active', false, true)
  end

  setLightState(false)
  local ped = PlayerPedId()
  stopHoldAnim(ped)

  ensureAnim(PUT_AWAY.dict)
  TaskPlayAnim(ped, PUT_AWAY.dict, PUT_AWAY.anim, 2.0, -2.0, -1, PUT_AWAY.flags, 0.0, false, false, false)

  Wait(1200)
  deleteOwnerProp()
  StopAnimTask(ped, PUT_AWAY.dict, PUT_AWAY.anim, 0.5)

  STATE.relYaw,STATE.relPitch=0.0,-5.0
  STATE.tuneIndex=0; STATE._apYaw=nil; STATE._apPitch=nil
  STATE.busy=false; STATE.aim=false; STATE.lastOrigin=nil; STATE.lastDir=nil
  STATE._lastNet=nil
  STATE.pendingDeactivate=false
  if STATE.corona and STATE.corona ~= 0 then DeleteObject(STATE.corona) end
  STATE.corona=nil; STATE.coronaExists=false

  if LocalPlayer and LocalPlayer.state then
    LocalPlayer.state.canUseWeapons = STATE.prev.canUseWeapons
  end
end

local function hardCleanup(reason)
  local ped = PlayerPedId()

  setLightState(false, { force = true })

  ClearPedSecondaryTask(ped)
  ClearPedTasksImmediately(ped)
  StopAnimTask(ped, HOLD_ANIM_DICT, HOLD_ANIM_NAME, 0.25)
  StopAnimTask(ped, 'amb@world_human_smoking@male@male_a@enter', 'enter', 0.25)
  StopAnimTask(ped, 'amb@world_human_stand_mobile@male@text@exit', 'exit', 0.25)

  if STATE.prop and STATE.prop ~= 0 then
    DeleteObject(STATE.prop)
  end
  STATE.prop = nil; STATE.propExists=false
  if STATE.corona and STATE.corona ~= 0 then DeleteObject(STATE.corona) end
  STATE.corona=nil; STATE.coronaExists=false

  for sid, _ in pairs(REM) do
    removeRemoteEntry(sid)
  end
  REM_THREAD.running = false

  if LocalPlayer and LocalPlayer.state then
    if STATE.prev and STATE.prev.canUseWeapons ~= nil then
      LocalPlayer.state.canUseWeapons = STATE.prev.canUseWeapons
    else
      LocalPlayer.state.canUseWeapons = true
    end
    LocalPlayer.state:set('davedev_flashlite_active', false, true)
  end

  if GetSelectedPedWeapon(ped) ~= `WEAPON_UNARMED` then
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
  end

  STATE.lastOrigin, STATE.lastDir = nil, nil
  STATE.active=false; STATE.busy=false; STATE.aim=false
  STATE.animPlaying=false
  STATE._apYaw=nil; STATE._apPitch=nil
  STATE._lastNet=nil
  STATE.lastUsePayload=nil
  STATE.pendingDeactivate=false

  pcall(releaseAuthorizedSession)
end

RegisterNetEvent('davedev_flashlite:client:AuthorizedUse', function(payload)
  STATE.lastUsePayload = payload or {}
  local token = type(payload) == 'table' and payload.sessionToken or nil
  local desiredActive = type(payload) == 'table' and payload.desiredActive or nil
  if type(token) ~= 'string' or token == '' or type(desiredActive) ~= 'boolean' then return end

  if desiredActive then
    if STATE.active then
      STATE.sessionToken = token
      deactivateFlashlight()
      return
    end

    STATE.sessionToken = token
    activateFlashlight()
    if not STATE.active then
      releaseAuthorizedSession()
    end
    return
  end

  if STATE.sessionToken ~= token then return end
  if STATE.busy then
    STATE.pendingDeactivate = true
    return
  end

  if STATE.active then
    deactivateFlashlight()
  else
    releaseAuthorizedSession()
  end
end)

local function requestEquipToggle(reason)
  if STATE.busy then
    if STATE.active or STATE.sessionToken then
      STATE.pendingDeactivate = true
    end
    return
  end

  if STATE.active then
    deactivateFlashlight()
    return
  end

  TriggerServerEvent('davedev_flashlite:server:RequestEquipToggle', {
    reason = reason or 'command',
  })
end

if EQUIP_ENABLED then
  RegisterCommand(EQUIP_COMMAND, function()
    requestEquipToggle('command')
  end, false)
end

if EQUIP_KEYBIND_ENABLED then
  RegisterCommand(EQUIP_KEYBIND_COMMAND, function()
    requestEquipToggle('keybind')
  end, false)

  RegisterCommand(EQUIP_KEYBIND_RELEASE_COMMAND, function() end, false)

  if REGISTER_EQUIP_KEYMAP and RegisterKeyMapping then
    RegisterKeyMapping(EQUIP_KEYBIND_COMMAND, EQUIP_KEYBIND_DESC, EQUIP_KEYBIND_MAPPER, EQUIP_KEYBIND_KEY)
  end
end

if TOGGLE_ENABLED then
  RegisterCommand(TOGGLE_COMMAND, function()
    if STATE.active and not STATE.busy then
      setLightState(not STATE.lightOn)
    end
  end, false)

  if REGISTER_KEYMAP and RegisterKeyMapping then
    RegisterKeyMapping(TOGGLE_COMMAND, TOGGLE_DESC or 'Toggle flashlight beam', 'MOUSE_BUTTON', TOGGLE_KEY or 'MOUSE_MIDDLE')
  end
end
AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  hardCleanup('resource_stop')
end)

AddEventHandler('onResourceStart', function(res)
  if res ~= GetCurrentResourceName() then return end
  STATE.active=false; STATE.busy=false; STATE.aim=false
  STATE.prop=nil; STATE.propExists=false
  STATE.corona=nil; STATE.coronaExists=false
  STATE.relYaw=0.0; STATE.relPitch=-5.0
  STATE._apYaw=nil; STATE._apPitch=nil
  STATE.lastOrigin=nil; STATE.lastDir=nil
  STATE.lastShare=0; STATE.tuneIndex=0
  STATE.prev.canUseWeapons=nil
  STATE._lastNet=nil
  STATE.animPlaying=false
  STATE.lightOn=false
  STATE.lastAnimCheck=0
  STATE.lastControlCheck=0
  STATE.cachedPed=nil
  STATE.cachedPedTime=0
  STATE.cachedBoneIndex=nil
  STATE.sessionToken=nil
  STATE.pendingDeactivate=false
  REM = {}; REM_THREAD.running=false
end)


CreateThread(function()
  local lastCheck = 0
  local checkInterval = 300
  local weaponCheckInterval = 600
  local lastWeaponCheck = 0
  while true do
    if STATE.active then
      local now = GetGameTimer()
      local ped = getCachedPed()

      if ped and now - lastCheck >= checkInterval then
        lastCheck = now
        if IsPedInAnyVehicle(ped, false) or IsPedRagdoll(ped) or IsEntityDead(ped) then
          deactivateFlashlight()
        end
      end

      if ped and now - lastWeaponCheck >= weaponCheckInterval then
        lastWeaponCheck = now
        if GetSelectedPedWeapon(ped) ~= `WEAPON_UNARMED` then
          SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        end
      end

      Wait(100)
    else
      Wait(1000)
    end
  end
end)

RegisterNetEvent('davedev_flashlite:client:Tuning', function(src, tIndex)
  if src == GetPlayerServerId(PlayerId()) then return end
  local sid = src
  REM[sid] = REM[sid] or {}
  REM[sid].tuneIndex = tIndex
  REM[sid].lastSeen = GetGameTimer()
end)

