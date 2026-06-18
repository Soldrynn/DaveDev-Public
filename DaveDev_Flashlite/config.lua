FlashliteConfig = {
  commands = {
    equip = {
      enabled = true,
      name = 'flashlite',
      description = 'Equip or holster your Flashlite',
      suggestion = '/flashlite - Equip or holster your Flashlite',
      keybind = {
        enabled = true,
        command = '+davedev_flashlite',
        description = 'Equip or holster your Flashlite',
        mapper = 'keyboard',
        key = 'O',
        registerKeyMapping = true,
      },
    },
    toggleLight = {
      enabled = true,
      name = 'flashlite_toggle',
      description = 'Toggle your Flashlite beam',
      key = 'MOUSE_MIDDLE',
      registerKeyMapping = true,
    },
  },

  controls = {
    followControl = 25,
    coneIncrease = 241,
    coneDecrease = 242,
    invertPitch = false,
  },

  light = {
    maxDistance = 35.0,
    color = { r = 235, g = 235, b = 255 },
    brightness = 8.0,
    hardness = 0.5,
    radius = 12.0,
    falloff = 55.0,
    originForwardOffset = 0.25,
    originUpOffset = 0.02,
    yawLimit = 35.0,
    pitchLimit = 50.0,

    tuning = {
      steps = 10,
      stepFactor = 0.15,
      minRadius = 2.5,
      maxRadius = 25.0,
      minBrightness = 1.0,
      maxBrightness = 5.0,
      brightnessExp = 5.0,
      distanceExp = 0.30,
      minDistance = 10.0,
      maxDistance = 65.0,
    },
  },

  optimization = {
    followSmoothing = 16.0,
    remoteSmoothing = 28.0,
    shareIntervalMs = 80,
    maxShareDistance = 150.0,
    minYawDeltaDeg = 0.25,
    minPitchDeltaDeg = 0.25,
    staleTimeoutMs = 15000,
    reattachEveryFrame = true,
    reattachIntervalMs = 400,
  },

  audio = {
    enabled = true,
    on = {
      name = 'CLICK_BACK',
      soundset = 'WEB_NAVIGATION_SOUNDS_PHONE',
    },
    off = {
      name = 'CLICK_BACK',
      soundset = 'WEB_NAVIGATION_SOUNDS_PHONE',
    },
  },

  corona = {
    enabled = true,
    remoteEnabled = true,
    maxRemote = -1,
  },
}
