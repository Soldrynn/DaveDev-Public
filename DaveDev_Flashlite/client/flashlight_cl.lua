local Client = DaveDevFlashliteClient
if not Client then error('DaveDevFlashliteClient modules were not loaded before flashlight_cl.lua') end

local K = Client.constants
local U = Client.utils
local Commands = Client.commands
if not K or not U or not Commands then error('DaveDevFlashliteClient core module is incomplete') end

local STATE = Client.createState()
local Remote = Client.createRemoteManager()

local function releaseAuthorizedSession()
  local token = STATE.sessionToken
  STATE.sessionToken = nil
  if token then
    TriggerServerEvent('davedev_flashlite:server:Unmounted', token)
  end
end

local function getCachedPed()
  local now = GetGameTimer()
  if not STATE.cachedPed or now - STATE.cachedPedTime > 100 then
    STATE.cachedPed = PlayerPedId()
    STATE.cachedPedTime = now
    STATE.cachedBoneIndex = GetPedBoneIndex(STATE.cachedPed, K.HAND_BONE_ID)
  end
  return STATE.cachedPed, STATE.cachedBoneIndex
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
        if IsEntityPlayingAnim(ped, K.HOLD_ANIM_DICT, K.HOLD_ANIM_NAME, 3) then
          if STATE.holdAnimLostAt ~= 0 then
            STATE.holdAnimLightReadyAt = now + K.HOLD_ANIM_LIGHT_RESUME_DELAY_MS
          end
          STATE.animPlaying = true
          STATE.holdAnimLostAt = 0
        else
          STATE.animPlaying = false
          STATE.holdAnimLightReadyAt = 0
          if STATE.holdAnimLostAt == 0 then
            STATE.holdAnimLostAt = now
          elseif now - STATE.holdAnimLostAt >= K.HOLD_ANIM_RESTART_DELAY_MS then
            Client.playHoldAnim(STATE, ped)
            STATE.holdAnimLostAt = now
          end
        end
      end

      Client.setControlsDisabled(true)

      if now - STATE.lastControlCheck >= controlCheckInterval then
        STATE.lastControlCheck = now
        local rmb = IsDisabledControlPressed(0, K.FOLLOW_CONTROL) or IsControlPressed(0, K.FOLLOW_CONTROL)
        local rmb2 = IsDisabledControlPressed(0, 25) or IsControlPressed(0, 25)
        STATE.aim = rmb or rmb2

        if STATE.aim or K.ALWAYS_TRACK then
          if IsDisabledControlJustPressed(0, K.CONE_INCREASE) or IsControlJustPressed(0, K.CONE_INCREASE) then
            STATE.tuneIndex = math.min(K.HALF_STEPS, STATE.tuneIndex + 1)
            TriggerServerEvent('davedev_flashlite:server:Tuning', STATE.sessionToken, STATE.tuneIndex)
          elseif IsDisabledControlJustPressed(0, K.CONE_DECREASE) or IsControlJustPressed(0, K.CONE_DECREASE) then
            STATE.tuneIndex = math.max(-K.HALF_STEPS, STATE.tuneIndex - 1)
            TriggerServerEvent('davedev_flashlite:server:Tuning', STATE.sessionToken, STATE.tuneIndex)
          end

          local tYawRel, tPitch = Client.computeTargetRelAngles(ped)
          local smoothing = (STATE.aim and K.FOLLOW_SMOOTH or K.FOLLOW_SMOOTH * 0.35) * frameTime
          STATE.relYaw = U.lerp(STATE.relYaw, tYawRel, smoothing)
          STATE.relPitch = U.lerp(STATE.relPitch, K.INVERT_PITCH and -tPitch or tPitch, smoothing)

          if now - STATE.lastShare >= K.SHARE_INTERVAL_MS then
            STATE.lastShare = now
            local dy = (STATE._lastNet and math.abs(U.angdiff(STATE._lastNet.ry, STATE.relYaw))) or math.huge
            local dp = (STATE._lastNet and math.abs(STATE.relPitch - STATE._lastNet.p)) or math.huge
            if dy > K.MIN_YAW_DELTA or dp > K.MIN_PITCH_DELTA or (K.FORCE_IDLE_SHARE and not STATE.aim) then
              TriggerServerEvent('davedev_flashlite:server:Orientation', STATE.sessionToken, STATE.relYaw, STATE.relPitch)
              STATE._lastNet = { ry = STATE.relYaw, p = STATE.relPitch }
            end
          end
        end
      end

      local holdAnimInterrupted = STATE.holdAnimLostAt ~= 0
      local holdLightSuppressed = holdAnimInterrupted or (STATE.holdAnimLightReadyAt ~= 0 and now < STATE.holdAnimLightReadyAt)
      if STATE.holdAnimLightReadyAt ~= 0 and now >= STATE.holdAnimLightReadyAt then
        STATE.holdAnimLightReadyAt = 0
      end

      if STATE.corona and STATE.corona ~= 0 and DoesEntityExist(STATE.corona) then
        SetEntityVisible(STATE.corona, STATE.lightOn and not holdLightSuppressed, 0)
      end

      if not holdAnimInterrupted then
        local rx = K.ATTACH_ROT_X + STATE.relYaw * K.YAW_SCALE
        local rz = K.ATTACH_ROT_Z + STATE.relPitch * K.PITCH_SCALE
        local needReattach = false
        if K.REATTACH_EVERY_FRAME then
          needReattach = true
        elseif (not STATE._apYaw) or math.abs(rx - STATE._apYaw) > 0.05 or math.abs(rz - STATE._apPitch) > 0.05 then
          needReattach = true
        elseif now - lastForcedReattach > K.REATTACH_INTERVAL_MS then
          needReattach = true
        end

        if needReattach then
          STATE._apYaw, STATE._apPitch = Client.attachPropForAim(ped, STATE.prop, boneIndex, STATE.relYaw, STATE.relPitch, true)
          lastForcedReattach = now
        end
      end

      local origin, forward
      if STATE.prop and STATE.propExists then
        origin, forward = Client.getPropBeamTransform(STATE.prop)
      end

      if not (origin and forward) and ped and boneIndex and not holdAnimInterrupted then
        origin, forward = Client.getFallbackBeamTransform(ped, boneIndex, STATE.relYaw, STATE.relPitch)
      end

      if origin and forward then
        if STATE.lightOn and not holdLightSuppressed then
          Client.drawBeam(STATE, origin, forward)
        end

        STATE.lastOrigin, STATE.lastDir = origin, forward
      end

      Wait(0)
    end
  end)
end

RegisterNetEvent('davedev_flashlite:client:Orientation', function(src, relYaw, pitch)
  Remote:onOrientation(src, relYaw, pitch)
end)

RegisterNetEvent('davedev_flashlite:client:Unmounted', function(src)
  Remote:onUnmounted(src)
end)

RegisterNetEvent('davedev_flashlite:client:BeamState', function(src, isOn)
  Remote:onBeamState(src, isOn)
end)

RegisterNetEvent('davedev_flashlite:client:Tuning', function(src, tIndex)
  Remote:onTuning(src, tIndex)
end)

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
    Client.playNativeToggleAudio(desired, STATE.prop or PlayerPedId())
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

  Client.playTransitionAnim(K.TAKE_OUT, ped)
  Wait(1400)

  STATE.prop = Client.spawnOwnerProp(ped, STATE)
  Wait(500)
  Client.stopTransitionAnim(K.TAKE_OUT, ped, 0.25)
  Client.startHoldAnim(STATE, ped)

  Wait(250)

  if STATE.prop then
    STATE.corona = Client.spawnCoronaFor(STATE.prop, ped)
    STATE.coronaExists = STATE.corona and DoesEntityExist(STATE.corona) or false
  end

  setLightState(false, { skipNet = true })

  local cam = GetFinalRenderedCamRot(2)
  local pedHeading = GetEntityHeading(ped)
  STATE.relYaw = U.clamp(U.normdeg(cam.z - pedHeading), -K.YAW_LIMIT, K.YAW_LIMIT)
  STATE.relPitch = U.clamp(U.normdeg(cam.x), -K.PITCH_LIMIT, K.PITCH_LIMIT)

  setLightState(false, { force = true })

  STATE.active = true
  STATE.busy = false
  if LocalPlayer and LocalPlayer.state then
    LocalPlayer.state:set('davedev_flashlite_active', true, true)
  end

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
  STATE.busy = true
  STATE.active = false

  if LocalPlayer and LocalPlayer.state then
    LocalPlayer.state:set('davedev_flashlite_active', false, true)
  end

  setLightState(false)
  local ped = PlayerPedId()
  Client.stopHoldAnim(STATE, ped)

  Client.playTransitionAnim(K.PUT_AWAY, ped)
  Wait(1200)
  Client.deleteOwnerProp(STATE, releaseAuthorizedSession)
  Client.stopTransitionAnim(K.PUT_AWAY, ped, 0.5)

  STATE.relYaw = 0.0
  STATE.relPitch = -5.0
  STATE.tuneIndex = 0
  STATE._apYaw = nil
  STATE._apPitch = nil
  STATE.busy = false
  STATE.aim = false
  STATE.lastOrigin = nil
  STATE.lastDir = nil
  STATE._lastNet = nil
  STATE.pendingDeactivate = false

  if LocalPlayer and LocalPlayer.state then
    LocalPlayer.state.canUseWeapons = STATE.prev.canUseWeapons
  end
end

local function hardCleanup(_reason)
  local ped = PlayerPedId()

  setLightState(false, { force = true })

  ClearPedSecondaryTask(ped)
  ClearPedTasksImmediately(ped)
  StopAnimTask(ped, K.HOLD_ANIM_DICT, K.HOLD_ANIM_NAME, 0.25)
  StopAnimTask(ped, K.TAKE_OUT.dict, K.TAKE_OUT.anim, 0.25)
  StopAnimTask(ped, K.PUT_AWAY.dict, K.PUT_AWAY.anim, 0.25)

  Client.deleteOwnerProp(STATE)
  Remote:clearAll()

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
  STATE.active = false
  STATE.busy = false
  STATE.aim = false
  STATE.animPlaying = false
  STATE.holdAnimLostAt = 0
  STATE.holdAnimLightReadyAt = 0
  STATE._apYaw = nil
  STATE._apPitch = nil
  STATE._lastNet = nil
  STATE.lastUsePayload = nil
  STATE.pendingDeactivate = false

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

if Commands.equipEnabled then
  RegisterCommand(Commands.equipCommand, function()
    requestEquipToggle('command')
  end, false)
end

if Commands.equipKeybindEnabled then
  RegisterCommand(Commands.equipKeybindCommand, function()
    requestEquipToggle('keybind')
  end, false)

  RegisterCommand(Commands.equipKeybindReleaseCommand, function() end, false)

  if Commands.registerEquipKeymap and RegisterKeyMapping then
    RegisterKeyMapping(Commands.equipKeybindCommand, Commands.equipKeybindDescription, Commands.equipKeybindMapper, Commands.equipKeybindKey)
  end
end

if Commands.toggleEnabled then
  RegisterCommand(Commands.toggleCommand, function()
    if STATE.active and not STATE.busy then
      setLightState(not STATE.lightOn)
    end
  end, false)

  if Commands.registerToggleKeymap and RegisterKeyMapping then
    RegisterKeyMapping(Commands.toggleCommand, Commands.toggleDescription or 'Toggle flashlight beam', 'MOUSE_BUTTON', Commands.toggleKey or 'MOUSE_MIDDLE')
  end
end

AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  hardCleanup('resource_stop')
end)

AddEventHandler('onResourceStart', function(res)
  if res ~= GetCurrentResourceName() then return end
  Client.resetState(STATE)
  Remote:reset()
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
