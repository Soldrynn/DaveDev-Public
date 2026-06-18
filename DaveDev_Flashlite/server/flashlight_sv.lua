local Config = FlashliteConfig or {}
local commandsCfg = Config.commands or {}
local equipCfg = commandsCfg.equip or {}
local optimizationCfg = Config.optimization or {}

local BROADCAST_RANGE = optimizationCfg.maxShareDistance or 150.0
local ORIENTATION_RATE = optimizationCfg.shareIntervalMs or 80
local BEAM_RATE = 100
local USE_REQUEST_COOLDOWN_MS = 250
local SESSION_PENDING_TIMEOUT_MS = 15000
local SESSION_STOP_TIMEOUT_MS = 5000

local lastOrientationTime = {}
local lastBeamStateTime = {}
local lastTuningTime = {}
local lastUseRequestTime = {}
local authorizedSessions = {}

local function nowMs()
  if GetGameTimer then return GetGameTimer() end
  return math.floor(os.clock() * 1000)
end

local function isFiniteNumber(value)
  return type(value) == 'number'
      and value == value
      and value ~= math.huge
      and value ~= -math.huge
end

local function createSessionToken(src)
  return ('%x:%x:%x:%x'):format(
    tonumber(src) or 0,
    nowMs(),
    math.random(0, 0x7fffffff),
    math.random(0, 0x7fffffff)
  )
end

local function clearAuthorizedSession(src, broadcast)
  authorizedSessions[src] = nil
  if broadcast then
    TriggerClientEvent('davedev_flashlite:client:Unmounted', -1, src)
  end
end

local function scheduleSessionExpiry(src, token, delayMs)
  if not SetTimeout then return end
  SetTimeout(delayMs + 50, function()
    local session = authorizedSessions[src]
    if session and session.token == token and session.expiresAt and nowMs() >= session.expiresAt then
      clearAuthorizedSession(src, true)
    end
  end)
end

local function getCurrentSession(src)
  local session = authorizedSessions[src]
  if not session then return nil end
  if session.expiresAt and nowMs() > session.expiresAt then
    clearAuthorizedSession(src, true)
    return nil
  end
  return session
end

local function getAuthorizedSession(src, token)
  if type(token) ~= 'string' or token == '' or #token > 128 then return nil end
  local session = getCurrentSession(src)
  if not session or session.token ~= token then return nil end
  return session
end

local function prepareAuthorizedUse(src)
  local current = getCurrentSession(src)
  if current then
    if current.desiredActive == false then
      current.expiresAt = nowMs() + SESSION_STOP_TIMEOUT_MS
      scheduleSessionExpiry(src, current.token, SESSION_STOP_TIMEOUT_MS)
      return current.token, false
    end

    current.desiredActive = false
    current.pending = false
    current.expiresAt = nowMs() + SESSION_STOP_TIMEOUT_MS
    scheduleSessionExpiry(src, current.token, SESSION_STOP_TIMEOUT_MS)
    return current.token, false
  end

  local token = createSessionToken(src)
  authorizedSessions[src] = {
    token = token,
    active = false,
    pending = true,
    desiredActive = true,
    expiresAt = nowMs() + SESSION_PENDING_TIMEOUT_MS,
  }
  scheduleSessionExpiry(src, token, SESSION_PENDING_TIMEOUT_MS)
  return token, true
end

local function triggerUse(src, payload)
  if not src or src <= 0 then return end
  local token, desiredActive = prepareAuthorizedUse(src)
  if not token then return end

  payload = type(payload) == 'table' and payload or {}
  payload.sessionToken = token
  payload.desiredActive = desiredActive
  TriggerClientEvent('davedev_flashlite:client:AuthorizedUse', src, payload)
end

local function getNearbyPlayers(origin, range)
  local players = GetPlayers()
  local result = {}
  local rangeSq = (range or BROADCAST_RANGE) ^ 2

  for i = 1, #players do
    local targetId = tonumber(players[i])
    if targetId then
      local ped = GetPlayerPed(targetId)
      if ped and ped ~= 0 then
        local targetCoords = GetEntityCoords(ped)
        local delta = #(origin - targetCoords)
        if (delta * delta) <= rangeSq then
          result[#result + 1] = targetId
        end
      end
    end
  end

  return result
end

local function broadcastNearby(src, eventName, range, ...)
  local ped = GetPlayerPed(src)
  if not ped or ped == 0 then return end

  local coords = GetEntityCoords(ped)
  local players = getNearbyPlayers(coords, range or BROADCAST_RANGE)

  for i = 1, #players do
    local targetId = players[i]
    if targetId ~= src then
      TriggerClientEvent(eventName, targetId, src, ...)
    end
  end
end

local function sessionCanSync(src, token)
  local session = getAuthorizedSession(src, token)
  return session and session.desiredActive == true and (session.pending or session.active) or false
end

RegisterNetEvent('davedev_flashlite:server:SessionState', function(token, isActive)
  local src = source
  if not src or src <= 0 or type(isActive) ~= 'boolean' then return end
  local session = getAuthorizedSession(src, token)
  if not session then return end

  if not isActive then
    clearAuthorizedSession(src, true)
    return
  end

  if session.desiredActive ~= true then
    TriggerClientEvent('davedev_flashlite:client:AuthorizedUse', src, {
      sessionToken = token,
      desiredActive = false,
    })
    return
  end

  session.active = true
  session.pending = false
  session.expiresAt = nil
end)

RegisterNetEvent('davedev_flashlite:server:Orientation', function(token, relYaw, pitch)
  local src = source
  if not src or src <= 0 then return end
  if not sessionCanSync(src, token) then return end
  if not isFiniteNumber(relYaw) or not isFiniteNumber(pitch) then return end
  if relYaw < -180 or relYaw > 180 or pitch < -90 or pitch > 90 then return end

  local now = nowMs()
  local last = lastOrientationTime[src]
  if last and (now - last) < ORIENTATION_RATE then return end
  lastOrientationTime[src] = now

  broadcastNearby(src, 'davedev_flashlite:client:Orientation', BROADCAST_RANGE, relYaw, pitch)
end)

RegisterNetEvent('davedev_flashlite:server:BeamState', function(token, isOn)
  local src = source
  if not src or src <= 0 then return end
  if not sessionCanSync(src, token) then return end
  if type(isOn) ~= 'boolean' then return end

  local now = nowMs()
  local last = lastBeamStateTime[src]
  if last and (now - last) < BEAM_RATE then return end
  lastBeamStateTime[src] = now

  broadcastNearby(src, 'davedev_flashlite:client:BeamState', BROADCAST_RANGE, isOn)
end)

RegisterNetEvent('davedev_flashlite:server:Tuning', function(token, tuneIndex)
  local src = source
  if not src or src <= 0 then return end
  if not sessionCanSync(src, token) then return end
  if not isFiniteNumber(tuneIndex) then return end
  if tuneIndex < -20 or tuneIndex > 20 then return end

  local now = nowMs()
  local last = lastTuningTime[src]
  if last and (now - last) < 100 then return end
  lastTuningTime[src] = now

  broadcastNearby(src, 'davedev_flashlite:client:Tuning', BROADCAST_RANGE, tuneIndex)
end)

RegisterNetEvent('davedev_flashlite:server:Unmounted', function(token)
  local src = source
  if not src or src <= 0 then return end
  local session = getAuthorizedSession(src, token)
  if not session then return end

  lastOrientationTime[src] = nil
  lastBeamStateTime[src] = nil
  lastTuningTime[src] = nil
  clearAuthorizedSession(src, true)
end)

RegisterNetEvent('davedev_flashlite:server:RequestEquipToggle', function(payload)
  local src = source
  if not src or src <= 0 then return end
  if equipCfg.enabled == false then return end

  local now = nowMs()
  local lastUse = lastUseRequestTime[src]
  if lastUse and (now - lastUse) < USE_REQUEST_COOLDOWN_MS then return end
  lastUseRequestTime[src] = now

  payload = type(payload) == 'table' and payload or {}
  payload.reason = payload.reason or 'command'
  triggerUse(src, payload)
end)

AddEventHandler('playerDropped', function()
  local src = source
  if not src or src <= 0 then return end
  lastOrientationTime[src] = nil
  lastBeamStateTime[src] = nil
  lastTuningTime[src] = nil
  lastUseRequestTime[src] = nil
  clearAuthorizedSession(src, true)
end)
