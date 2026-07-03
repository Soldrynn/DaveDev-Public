local Client = DaveDevFlashliteClient
local cfg = Client.config or {}
local audioCfg = cfg.audio or {}

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

function Client.playNativeToggleAudio(isOn, entity)
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
