DaveDevFlashliteClient = DaveDevFlashliteClient or {}

local Client = DaveDevFlashliteClient
local cfg = FlashliteConfig or {}
Client.config = cfg

function Client.ensureModel(model)
  if lib and lib.requestModel then
    lib.requestModel(model, 10000)
    return
  end

  while not HasModelLoaded(model) do
    RequestModel(model)
    Wait(0)
  end
end

function Client.ensureAnim(dict)
  if lib and lib.requestAnimDict then
    lib.requestAnimDict(dict, 10000)
    return
  end

  while not HasAnimDictLoaded(dict) do
    RequestAnimDict(dict)
    Wait(0)
  end
end

local constants = {
  DEG2RAD = 0.017453292519943295,
  FULL_CIRCLE = 360.0,
  HALF_CIRCLE = 180.0,
}
Client.constants = constants

local utils = Client.utils or {}
Client.utils = utils

function utils.clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

function utils.deg2rad(d)
  return d * constants.DEG2RAD
end

function utils.normdeg(d)
  d = d % constants.FULL_CIRCLE
  if d > constants.HALF_CIRCLE then
    d = d - constants.FULL_CIRCLE
  end
  return d
end

function utils.angdiff(a, b)
  local d = (b - a + constants.HALF_CIRCLE) % constants.FULL_CIRCLE - constants.HALF_CIRCLE
  return (d < -constants.HALF_CIRCLE) and (d + constants.FULL_CIRCLE) or d
end

function utils.lerp(a, b, t)
  return a + (b - a) * t
end

function utils.lerpAng(a, b, t)
  return a + utils.angdiff(a, b) * t
end

local function rotX(v, a)
  local c, s = math.cos(a), math.sin(a)
  return vector3(v.x, v.y * c - v.z * s, v.y * s + v.z * c)
end

local function rotY(v, a)
  local c, s = math.cos(a), math.sin(a)
  return vector3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c)
end

local function rotZ(v, a)
  local c, s = math.cos(a), math.sin(a)
  return vector3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)
end

function utils.rotateZYX(v, rx, ry, rz)
  local r = rotZ(v, rz)
  r = rotY(r, ry)
  r = rotX(r, rx)
  return r
end

local commandsCfg = cfg.commands or {}
local equipCfg = commandsCfg.equip or {}
local equipKeybindCfg = equipCfg.keybind or {}
local toggleCfg = commandsCfg.toggleLight or {}
local equipKeybindCommand = equipKeybindCfg.command or equipKeybindCfg.name or '+davedev_flashlite'
local equipDescription = equipCfg.description or 'Equip or holster your Flashlite'

Client.commands = {
  equipEnabled = equipCfg.enabled ~= false,
  equipCommand = equipCfg.name or 'flashlite',
  equipDescription = equipDescription,
  equipKeybindEnabled = equipCfg.enabled ~= false and equipKeybindCfg.enabled ~= false,
  equipKeybindCommand = equipKeybindCommand,
  equipKeybindReleaseCommand = equipKeybindCommand:gsub('^%+', '-'),
  equipKeybindDescription = equipKeybindCfg.description or equipDescription,
  equipKeybindMapper = equipKeybindCfg.mapper or 'keyboard',
  equipKeybindKey = equipKeybindCfg.key or 'O',
  registerEquipKeymap = equipKeybindCfg.registerKeyMapping ~= false,

  toggleEnabled = toggleCfg.enabled ~= false,
  toggleCommand = toggleCfg.name or 'flashlite_toggle',
  toggleDescription = toggleCfg.description or 'Toggle Flashlite beam',
  toggleKey = toggleCfg.key or 'MOUSE_MIDDLE',
  registerToggleKeymap = toggleCfg.registerKeyMapping ~= false,
}

constants.SHADOW_ID_MIN = 1
constants.SHADOW_ID_MAX = 16
constants.SHADOW_ID_RANGE = constants.SHADOW_ID_MAX - constants.SHADOW_ID_MIN + 1

local lightCfg = cfg.light or {}
local controlsCfg = cfg.controls or {}
local optimizationCfg = cfg.optimization or {}

constants.FLASHLIGHT_MODEL = `prop_cs_police_torch`
constants.HAND_BONE_ID = 0xDEAD
constants.FOLLOW_CONTROL = controlsCfg.followControl or 25
constants.CONE_INCREASE = controlsCfg.coneIncrease or 241
constants.CONE_DECREASE = controlsCfg.coneDecrease or 242
constants.YAW_LIMIT = lightCfg.yawLimit or 35.0
constants.PITCH_LIMIT = lightCfg.pitchLimit or 50.0
constants.INVERT_PITCH = controlsCfg.invertPitch == true

constants.LIGHT_COLOR_R = (lightCfg.color and lightCfg.color.r) or 255
constants.LIGHT_COLOR_G = (lightCfg.color and lightCfg.color.g) or 255
constants.LIGHT_COLOR_B = (lightCfg.color and lightCfg.color.b) or 240
constants.BASE_BRIGHTNESS = lightCfg.brightness or 12.0
constants.HARDNESS = lightCfg.hardness or 0.35
constants.BASE_RADIUS = lightCfg.radius or 12.0
constants.FALLOFF = lightCfg.falloff or 12.0
constants.ORIGIN_FORWARD_OFFSET = lightCfg.originForwardOffset or 0.18
constants.ORIGIN_UP_OFFSET = lightCfg.originUpOffset or 0.02

local tuning = lightCfg.tuning or {}
constants.STEP_FACTOR = tuning.stepFactor or 0.12
constants.MIN_RADIUS = tuning.minRadius or 0.1
constants.MAX_RADIUS = tuning.maxRadius or 1.6
constants.BRIGHTNESS_EXP = tuning.brightnessExp or 2.0
constants.MIN_BRIGHTNESS = tuning.minBrightness or 0.5
constants.MAX_BRIGHTNESS = tuning.maxBrightness or 24.0
constants.DISTANCE_EXP = tuning.distanceExp or 0.8
constants.MIN_DISTANCE = tuning.minDistance or (lightCfg.maxDistance or 25.0) * 0.6
constants.MAX_DISTANCE = tuning.maxDistance or (lightCfg.maxDistance or 25.0) * 2.0
constants.BASE_MAX_DIST = lightCfg.maxDistance or 25.0
constants.TUNING_STEPS = tuning.steps or 5
constants.HALF_STEPS = math.floor(constants.TUNING_STEPS / 2)

constants.ATTACH_POS_X = 0.080
constants.ATTACH_POS_Y = 0.020
constants.ATTACH_POS_Z = -0.030
constants.ATTACH_ROT_X = 12.0
constants.ATTACH_ROT_Y = 0.0
constants.ATTACH_ROT_Z = -18.0
constants.YAW_SCALE = 1.0
constants.PITCH_SCALE = 1.15
constants.PIVOT_FORWARD = 0.0
constants.PIVOT_UP = 0.0
constants.PIVOT_AXIS = 'y'
constants.PIVOT_LOCAL = (constants.PIVOT_AXIS == 'x')
    and vector3(constants.PIVOT_FORWARD, 0.0, constants.PIVOT_UP)
    or vector3(0.0, constants.PIVOT_FORWARD, constants.PIVOT_UP)

constants.SHARE_INTERVAL_MS = optimizationCfg.shareIntervalMs or 80
constants.MIN_YAW_DELTA = optimizationCfg.minYawDeltaDeg or 0.25
constants.MIN_PITCH_DELTA = optimizationCfg.minPitchDeltaDeg or 0.25
constants.MAX_SHARE_DISTANCE = optimizationCfg.maxShareDistance or 150.0
constants.REM_STALE_TIMEOUT = optimizationCfg.staleTimeoutMs or 15000
constants.FOLLOW_SMOOTH = optimizationCfg.followSmoothing or 16.0
constants.REMOTE_SMOOTH = optimizationCfg.remoteSmoothing or 28.0
constants.ALWAYS_TRACK = false
constants.FORCE_IDLE_SHARE = true
constants.REATTACH_EVERY_FRAME = optimizationCfg.reattachEveryFrame ~= false
constants.REATTACH_INTERVAL_MS = optimizationCfg.reattachIntervalMs or 400
constants.ALT_ROTATION_MODE = false

local holdAnimCfg = (cfg.anim and cfg.anim.hold) or cfg.anim or {}
constants.HOLD_ANIM_DICT = holdAnimCfg.dict or 'flashlightanim@walk@base'
constants.HOLD_ANIM_NAME = holdAnimCfg.name or 'base'
constants.HOLD_ANIM_FLAGS = holdAnimCfg.flags or 51
constants.HOLD_ANIM_RESTART_DELAY_MS = holdAnimCfg.restartDelayMs or 1200
constants.HOLD_ANIM_LIGHT_RESUME_DELAY_MS = 100
constants.TAKE_OUT = { dict = 'amb@world_human_smoking@male@male_a@enter', anim = 'enter', flags = 51 }
constants.PUT_AWAY = { dict = 'amb@world_human_stand_mobile@male@text@exit', anim = 'exit', flags = 51 }

local shadowUsage = {}

function Client.acquireShadowId(preferred)
  local candidate = preferred and math.floor(preferred) or nil
  if candidate and candidate >= constants.SHADOW_ID_MIN and candidate <= constants.SHADOW_ID_MAX then
    if not shadowUsage[candidate] then
      shadowUsage[candidate] = 1
      return candidate
    end
  end

  for id = constants.SHADOW_ID_MIN, constants.SHADOW_ID_MAX do
    if not shadowUsage[id] then
      shadowUsage[id] = 1
      return id
    end
  end

  candidate = candidate or constants.SHADOW_ID_MIN
  if candidate < constants.SHADOW_ID_MIN or candidate > constants.SHADOW_ID_MAX then
    candidate = ((candidate - constants.SHADOW_ID_MIN) % constants.SHADOW_ID_RANGE) + constants.SHADOW_ID_MIN
  end
  shadowUsage[candidate] = (shadowUsage[candidate] or 0) + 1
  return candidate
end

function Client.releaseShadowId(id)
  if not id then return end
  local candidate = math.floor(id)
  if candidate < constants.SHADOW_ID_MIN or candidate > constants.SHADOW_ID_MAX then return end
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
Client.LOCAL_SHADOW_ID = Client.acquireShadowId((((tonumber(localServerId) or 0) % constants.SHADOW_ID_RANGE) + constants.SHADOW_ID_MIN))
