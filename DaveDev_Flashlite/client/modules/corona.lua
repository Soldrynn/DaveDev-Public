local Client = DaveDevFlashliteClient
local K = Client.constants
local cfg = Client.config or {}
local coronaCfg = cfg.corona or {}

K.CORONA_ENABLED = coronaCfg.enabled ~= false
K.CORONA_MODEL = `flashlight_corona_prop`
K.CORONA_POS = { x = 0.0, y = 0.175, z = 0.010 }
K.CORONA_ROT = { x = -90.0, y = 0.0, z = 0.0 }
K.CORONA_REMOTE_ENABLED = coronaCfg.remoteEnabled ~= false
K.CORONA_REMOTE_MAX = coronaCfg.maxRemote or -1
K.CORONA_FLAG_ADJUSTMENTS = {
  { flag = 322, offset = { x = 0.088, y = 0.0, z = 0.010 } },
}

local behaviorCfg = {
  coronaUseTipOffsets = true,
  coronaTipForward = 0.0,
  coronaTipInvert = false,
  coronaFinalDX = 0.0,
  coronaFinalDY = -0.39,
  coronaFinalDZ = 0.0,
}

local function computeCoronaOffsets(_ped)
  local useTip = behaviorCfg.coronaUseTipOffsets
  local fwdExtra = useTip and ((behaviorCfg.coronaTipForward or 0.055) * (behaviorCfg.coronaTipInvert and -1 or 1)) or 0.38
  local upExtra = useTip and (behaviorCfg.coronaTipUp or 0.0) or 0.05
  local posX = (K.CORONA_POS.x or 0.0) + fwdExtra
  local posY = K.CORONA_POS.y or 0.0
  local posZ = (K.CORONA_POS.z or 0.0) + upExtra

  local fdX = behaviorCfg.coronaFinalDX or 0.0
  local fdY = behaviorCfg.coronaFinalDY or 0.0
  local fdZ = behaviorCfg.coronaFinalDZ or 0.0

  return (posX - fdX), (posY + fdY - 0.06), (posZ + fdZ - 0.017)
end

local function applyCoronaFlagAdjustments(ped, ox, oy, oz)
  if not ped or ped == 0 then return ox, oy, oz end
  if type(K.CORONA_FLAG_ADJUSTMENTS) ~= 'table' then return ox, oy, oz end

  for i = 1, #K.CORONA_FLAG_ADJUSTMENTS do
    local adj = K.CORONA_FLAG_ADJUSTMENTS[i]
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

function Client.spawnCoronaFor(prop, ped, opts)
  if not K.CORONA_ENABLED or not prop or not ped or ped == 0 then return nil end

  opts = opts or {}
  local networked = opts.networked == true

  Client.ensureModel(K.CORONA_MODEL)
  local ppos = GetEntityCoords(ped)

  local c = CreateObject(K.CORONA_MODEL, ppos.x, ppos.y, ppos.z - 2.0, networked, networked, false)
  if not c or c == 0 then
    c = (CreateObjectNoOffset and CreateObjectNoOffset(K.CORONA_MODEL, ppos.x, ppos.y, ppos.z - 2.0, networked, networked, false)) or c
  end
  if not c or c == 0 then return nil end

  SetEntityCollision(c, false, false)
  SetEntityInvincible(c, true)
  SetEntityProofs(c, true, true, true, true, true, true, true, true)
  SetEntityAsMissionEntity(c, true, true)
  SetEntityCanBeDamaged(c, false)
  FreezeEntityPosition(c, true)
  SetEntityLodDist(c, 5000)

  local ox, oy, oz = computeCoronaOffsets(ped)
  ox, oy, oz = applyCoronaFlagAdjustments(ped, ox, oy, oz)
  AttachEntityToEntity(c, prop, 0x188E, ox, oy, oz, K.CORONA_ROT.x + 95.0, K.CORONA_ROT.y, K.CORONA_ROT.z, false, false, false, false, 2, true)
  return c
end
