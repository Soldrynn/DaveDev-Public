local Client = DaveDevFlashliteClient
local K = Client.constants
local U = Client.utils

local function ensureRemoteShadowId(remotes, sid)
  local remote = remotes[sid]
  if not remote then return Client.LOCAL_SHADOW_ID end
  if remote.shadowId then return remote.shadowId end

  local sidNum = tonumber(sid) or 0
  local preferred = (sidNum % K.SHADOW_ID_RANGE) + K.SHADOW_ID_MIN
  remote.shadowId = Client.acquireShadowId(preferred)
  return remote.shadowId
end

local function releaseRemoteShadow(remote)
  if remote and remote.shadowId then
    Client.releaseShadowId(remote.shadowId)
    remote.shadowId = nil
  end
end

local function clearRemoteEntities(remote)
  if not remote then return end
  if remote.prop and remote.prop ~= 0 then DeleteObject(remote.prop) end
  if remote.corona and remote.corona ~= 0 then DeleteObject(remote.corona) end
  remote.prop = nil
  remote.corona = nil
  remote.coronaExists = false
  releaseRemoteShadow(remote)
end

function Client.createRemoteManager()
  local remotes = {}
  local thread = { running = false }
  local manager = {}

  function manager:remove(sid)
    local remote = remotes[sid]
    if not remote then return end
    clearRemoteEntities(remote)
    remotes[sid] = nil
  end

  function manager:clearAll()
    for sid, _ in pairs(remotes) do
      self:remove(sid)
    end
    thread.running = false
  end

  function manager:reset()
    self:clearAll()
    remotes = {}
  end

  local function hasActiveRemotes()
    for _, data in pairs(remotes) do
      if data and data.active then return true end
    end
    return false
  end

  local function countCoronas()
    local count = 0
    for _, data in pairs(remotes) do
      if data.corona and data.corona ~= 0 then count = count + 1 end
    end
    return count
  end

  function manager:ensureLoop()
    if thread.running then return end
    thread.running = true

    CreateThread(function()
      local frameTime, myPed, myPos, k, distanceSq
      local maxDistSq = K.MAX_SHARE_DISTANCE * K.MAX_SHARE_DISTANCE
      local distanceCheckInterval = 200
      local lastDistanceCheck = 0

      while hasActiveRemotes() do
        frameTime = GetFrameTime()
        k = 1.0 - math.exp(-K.REMOTE_SMOOTH * frameTime)

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
          local remote = remotes[sid]
          if remote and remote.active then
            seenThisFrame[sid] = true
            local ped = GetPlayerPed(pid)
            if ped and ped ~= 0 then
              remote.lastSeen = now
              local pedPos = GetEntityCoords(ped)
              if myPos and pedPos then
                distanceSq = (myPos.x - pedPos.x) ^ 2 + (myPos.y - pedPos.y) ^ 2 + (myPos.z - pedPos.z) ^ 2

                if distanceSq <= maxDistSq then
                  anyNear = true

                  if not remote.prop or remote.prop == 0 then
                    remote.prop = Client.spawnLocalPropFor(ped)
                    remote.apYaw, remote.apPitch = nil, nil
                    remote.bone = GetPedBoneIndex(ped, K.HAND_BONE_ID)
                    if K.CORONA_REMOTE_ENABLED and remote.lightOn and (K.CORONA_REMOTE_MAX < 0 or countCoronas() < K.CORONA_REMOTE_MAX) then
                      remote.corona = Client.spawnCoronaFor(remote.prop, ped)
                      remote.coronaExists = remote.corona and remote.corona ~= 0 or false
                      if remote.corona and remote.coronaExists then SetEntityVisible(remote.corona, true, 0) end
                    end
                  elseif not remote.corona and K.CORONA_REMOTE_ENABLED and remote.prop and remote.prop ~= 0 and remote.lightOn then
                    if K.CORONA_REMOTE_MAX < 0 or countCoronas() < K.CORONA_REMOTE_MAX then
                      remote.corona = Client.spawnCoronaFor(remote.prop, ped)
                      remote.coronaExists = remote.corona and remote.corona ~= 0 or false
                      if remote.corona and remote.coronaExists then SetEntityVisible(remote.corona, true, 0) end
                    end
                  end

                  remote.ry = (remote.ry and U.lerpAng(remote.ry, remote.ry_t, k)) or remote.ry_t
                  remote.p = (remote.p and U.lerp(remote.p, remote.p_t, k)) or remote.p_t

                  local yawRel = remote.ry or 0.0
                  local rx = K.ATTACH_ROT_X + yawRel * K.YAW_SCALE
                  local rz = K.ATTACH_ROT_Z + (remote.p or 0.0) * K.PITCH_SCALE
                  if (not remote.apYaw) or math.abs(rx - remote.apYaw) > 0.05 or math.abs(rz - remote.apPitch) > 0.05 then
                    remote.apYaw, remote.apPitch = Client.attachPropForAim(ped, remote.prop, remote.bone or GetPedBoneIndex(ped, K.HAND_BONE_ID), yawRel, remote.p or 0.0, false)
                  end

                  if remote.lightOn then
                    local shadowId = ensureRemoteShadowId(remotes, sid)
                    local origin, forward = Client.getPropBeamTransform(remote.prop)
                    if not (origin and forward) then
                      origin, forward = Client.getFallbackBeamTransform(ped, remote.bone or GetPedBoneIndex(ped, K.HAND_BONE_ID), remote.ry or 0.0, remote.p or 0.0)
                    end

                    if origin and forward then
                      local factorOverride = 1.0 + ((remote.tuneIndex or 0) * K.STEP_FACTOR)
                      Client.drawBeam(nil, origin, forward, factorOverride, shadowId)
                    end
                  else
                    releaseRemoteShadow(remote)
                  end

                  if remote.corona and remote.corona ~= 0 then
                    SetEntityVisible(remote.corona, remote.lightOn == true, 0)
                  end
                else
                  clearRemoteEntities(remote)
                end
              end
            elseif remote.lastSeen and now - remote.lastSeen > K.REM_STALE_TIMEOUT then
              self:remove(sid)
            end
          end
        end

        for sid, data in pairs(remotes) do
          if data and data.active and not seenThisFrame[sid] and data.lastSeen and now - data.lastSeen > K.REM_STALE_TIMEOUT then
            self:remove(sid)
          end
        end

        if anyNear then
          Wait(0)
        else
          Wait(250)
        end
      end

      self:clearAll()
    end)
  end

  function manager:onOrientation(src, relYaw, pitch)
    if src == GetPlayerServerId(PlayerId()) then return end
    local sid = src
    remotes[sid] = remotes[sid] or {}
    remotes[sid].active = true
    if remotes[sid].lightOn == nil then remotes[sid].lightOn = false end
    remotes[sid].ry_t = U.clamp(U.normdeg(relYaw), -K.YAW_LIMIT, K.YAW_LIMIT)
    remotes[sid].p_t = U.clamp(pitch, -K.PITCH_LIMIT, K.PITCH_LIMIT)
    remotes[sid].lastSeen = GetGameTimer()
    self:ensureLoop()
  end

  function manager:onUnmounted(src)
    self:remove(src)
  end

  function manager:onBeamState(src, isOn)
    if src == GetPlayerServerId(PlayerId()) then return end
    local sid = src
    remotes[sid] = remotes[sid] or {}
    remotes[sid].lightOn = isOn == true
    remotes[sid].lastSeen = GetGameTimer()

    if not remotes[sid].lightOn then
      releaseRemoteShadow(remotes[sid])
    end
    if remotes[sid].corona and DoesEntityExist(remotes[sid].corona) then
      SetEntityVisible(remotes[sid].corona, remotes[sid].lightOn, 0)
    end
    if remotes[sid].active then self:ensureLoop() end
  end

  function manager:onTuning(src, tuneIndex)
    if src == GetPlayerServerId(PlayerId()) then return end
    local sid = src
    remotes[sid] = remotes[sid] or {}
    remotes[sid].tuneIndex = tuneIndex
    remotes[sid].lastSeen = GetGameTimer()
  end

  return manager
end
