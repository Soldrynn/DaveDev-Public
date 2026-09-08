DaveDevSFXConfig = {
    debug = false,                            -- console prints for troubleshooting

    -- interact-sound compatibility: answer the InteractSound_SV:* events with files
    -- from html/sounds. Automatically dormant while the real interact-sound runs.
    interactSoundCompat = true,
    interactSoundResource = 'interact-sound', -- folder/ensure name if you renamed it

    clientRateLimitMs = 250,                  -- minimum gap between sounds requested by one player
}
