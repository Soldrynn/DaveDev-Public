--[[
    DaveDev SFX - server

    A small shared sound player other resources depend on. Two ways in:

    1. Native API (preferred). Sounds can live in the calling resource's own
       `sounds/` folder, so every resource ships its own audio.
         exports.DaveDev_SFX:PlayWithinDistance(source, sound, opts)
         exports.DaveDev_SFX:PlayAtCoords(coords, sound, opts)
         exports.DaveDev_SFX:PlayOnSource(target, sound, opts)
         exports.DaveDev_SFX:PlayOnAll(sound, opts)
         TriggerServerEvent('DaveDev_SFX:server:play', sound, opts)   -- from a client
       opts = { volume = 0.1, distance = 5.0, resource = 'DaveDev_Flashlight' }

    2. interact-sound compatibility. The InteractSound_SV:* events are answered
       with sounds from this resource's html/sounds folder, but only while the
       real interact-sound is not running, so there is never double audio.
]]

local RESOURCE_NAME = GetCurrentResourceName()
local Config = DaveDevSFXConfig or {}

local MAX_DISTANCE = 50.0
local MAX_NAME_LENGTH = 64
local CLIENT_RATE_LIMIT_MS = tonumber(Config.clientRateLimitMs) or 250
local INTERACT_SOUND = Config.interactSoundResource or 'interact-sound'

local lastClientPlayback = {}

local function debugPrint(message)
    if Config.debug ~= true then return end
    print(('[%s] %s'):format(RESOURCE_NAME, message))
end

local function clamp(value, minimum, maximum, fallback)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return fallback end
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function sanitizeSound(sound)
    if type(sound) ~= 'string' or sound == '' or #sound > MAX_NAME_LENGTH then return nil end
    if sound:find('..', 1, true) or sound:find('/', 1, true) or sound:find('\\', 1, true) then return nil end
    if not sound:match('^[%w_.%-]+$') then return nil end
    return sound
end

-- The resource whose sounds/ folder holds the file. nil = this resource's html/sounds.
local function sanitizeResource(resource)
    if resource == nil or resource == '' or resource == RESOURCE_NAME then return nil end
    if type(resource) ~= 'string' or #resource > MAX_NAME_LENGTH or not resource:match('^[%w_%-]+$') then return nil end
    if GetResourceState(resource) == 'missing' then return nil end
    return resource
end

local function toVector3(data)
    if type(data) == 'vector3' or type(data) == 'vector4' then
        return vector3(data.x + 0.0, data.y + 0.0, data.z + 0.0)
    end
    if type(data) == 'table' and data.x and data.y and data.z then
        return vector3(data.x + 0.0, data.y + 0.0, data.z + 0.0)
    end
    return nil
end

local function sourceCoords(src)
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        return GetEntityCoords(ped)
    end
    return nil
end

local function buildPayload(sound, opts)
    opts = type(opts) == 'table' and opts or {}
    return {
        sound = sound,
        volume = clamp(opts.volume, 0.0, 1.0, 0.1),
        resource = sanitizeResource(opts.resource),
    }
end

local function clientCanPlay(src)
    if not src or src <= 0 then return true end
    local now = GetGameTimer()
    local last = lastClientPlayback[src]
    if last and (now - last) < CLIENT_RATE_LIMIT_MS then return false end
    lastClientPlayback[src] = now
    return true
end

---------------------------------------------------------------------------
-- Native API
---------------------------------------------------------------------------
local function playAtCoords(coords, sound, opts)
    sound = sanitizeSound(sound)
    coords = toVector3(coords)
    if not sound or not coords then return false end
    local payload = buildPayload(sound, opts)
    payload.coords = coords
    payload.distance = clamp(type(opts) == 'table' and opts.distance or nil, 0.0, MAX_DISTANCE, 5.0)
    TriggerClientEvent('DaveDev_SFX:play', -1, payload)
    return true
end

local function playWithinDistance(src, sound, opts)
    local coords = sourceCoords(tonumber(src))
    if not coords then return false end
    return playAtCoords(coords, sound, opts)
end

local function playOnSource(target, sound, opts)
    sound = sanitizeSound(sound)
    target = tonumber(target)
    if not sound or not target or target <= 0 or not GetPlayerName(target) then return false end
    TriggerClientEvent('DaveDev_SFX:play_direct', target, buildPayload(sound, opts))
    return true
end

local function playOnAll(sound, opts)
    sound = sanitizeSound(sound)
    if not sound then return false end
    TriggerClientEvent('DaveDev_SFX:play_direct', -1, buildPayload(sound, opts))
    return true
end

exports('PlayWithinDistance', playWithinDistance)
exports('PlayAtCoords', playAtCoords)
exports('PlayOnSource', playOnSource)
exports('PlayOnAll', playOnAll)

-- Client-originated playback around the player.
RegisterNetEvent('DaveDev_SFX:server:play', function(sound, opts)
    local src = source
    if not clientCanPlay(src) then return end
    playWithinDistance(src, sound, type(opts) == 'table' and opts or {})
end)

---------------------------------------------------------------------------
-- interact-sound compatibility (dormant while interact-sound is running)
---------------------------------------------------------------------------
local function compatActive()
    if Config.interactSoundCompat == false then return false end
    local state = GetResourceState(INTERACT_SOUND)
    return state ~= 'started' and state ~= 'starting'
end

exports('IsCompatActive', compatActive)

RegisterNetEvent('InteractSound_SV:PlayWithinDistance', function(distance, sound, volume)
    local src = source
    if not compatActive() or not clientCanPlay(src) then return end
    playWithinDistance(src, sound, { distance = distance, volume = volume })
end)

RegisterNetEvent('InteractSound_SV:PlayOnOne', function(target, sound, volume)
    if (source and source > 0) or not compatActive() then return end
    playOnSource(target, sound, { volume = volume })
end)

RegisterNetEvent('InteractSound_SV:PlayOnAll', function(sound, volume)
    if (source and source > 0) or not compatActive() then return end
    playOnAll(sound, { volume = volume })
end)

---------------------------------------------------------------------------
-- Housekeeping
---------------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    lastClientPlayback[source] = nil
end)

AddEventHandler('onResourceStart', function(res)
    if res == RESOURCE_NAME then
        debugPrint(('Started. interact-sound compatibility %s.'):format(compatActive() and 'active' or 'dormant (interact-sound is running)'))
    elseif res == INTERACT_SOUND then
        debugPrint('interact-sound started, compatibility events are now dormant.')
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == INTERACT_SOUND then
        debugPrint('interact-sound stopped, compatibility events are active again.')
    end
end)
