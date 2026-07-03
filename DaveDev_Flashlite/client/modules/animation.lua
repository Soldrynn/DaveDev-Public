local Client = DaveDevFlashliteClient
local K = Client.constants

local function playAnim(animDef, ped)
  Client.ensureAnim(animDef.dict)
  TaskPlayAnim(ped, animDef.dict, animDef.anim, 2.0, -2.0, -1, animDef.flags, 0.0, false, false, false)
end

function Client.playTransitionAnim(animDef, ped)
  playAnim(animDef, ped)
end

function Client.stopTransitionAnim(animDef, ped, blendOut)
  StopAnimTask(ped, animDef.dict, animDef.anim, blendOut or 0.25)
end

function Client.playHoldAnim(state, ped)
  Client.ensureAnim(K.HOLD_ANIM_DICT)
  TaskPlayAnim(ped, K.HOLD_ANIM_DICT, K.HOLD_ANIM_NAME, 2.0, -2.0, -1, K.HOLD_ANIM_FLAGS, 0.0, false, false, false)
  state.animPlaying = true
  state.holdAnimLostAt = 0
  state.holdAnimLightReadyAt = 0
end

function Client.startHoldAnim(state, ped)
  Client.playHoldAnim(state, ped)
end

function Client.stopHoldAnim(state, ped)
  if state.animPlaying then
    StopAnimTask(ped, K.HOLD_ANIM_DICT, K.HOLD_ANIM_NAME, 1.0)
  end
  state.animPlaying = false
  state.holdAnimLostAt = 0
  state.holdAnimLightReadyAt = 0
end
