local Client = DaveDevFlashliteClient

function Client.resetState(state)
  state.active = false
  state.busy = false
  state.aim = false
  state.prop = nil
  state.propExists = false
  state.corona = nil
  state.coronaExists = false
  state.relYaw = 0.0
  state.relPitch = -5.0
  state._apYaw = nil
  state._apPitch = nil
  state.lastOrigin = nil
  state.lastDir = nil
  state.lastShare = 0
  state.tuneIndex = 0
  state.prev = state.prev or {}
  state.prev.canUseWeapons = nil
  state._lastNet = nil
  state.animPlaying = false
  state.holdAnimLostAt = 0
  state.holdAnimLightReadyAt = 0
  state.lightOn = false
  state.lastUsePayload = nil
  state.lastAnimCheck = 0
  state.lastControlCheck = 0
  state.cachedPed = nil
  state.cachedPedTime = 0
  state.cachedBoneIndex = nil
  state.sessionToken = nil
  state.pendingDeactivate = false
  return state
end

function Client.createState()
  return Client.resetState({})
end
