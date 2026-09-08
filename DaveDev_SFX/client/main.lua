--[[
    DaveDev SFX - client

    Plays sounds through the NUI audio element. `resource` in a payload points
    the player at that resource's sounds/ folder; without it the file is looked
    up in this resource's html/sounds folder.
]]

local function toVector3(data)
    if type(data) == 'vector3' or type(data) == 'vector4' then
        return vector3(data.x + 0.0, data.y + 0.0, data.z + 0.0)
    end
    if type(data) == 'table' and data.x and data.y and data.z then
        return vector3(data.x + 0.0, data.y + 0.0, data.z + 0.0)
    end
    return nil
end

local function playSound(sound, volume, resource)
    if type(sound) ~= 'string' or sound == '' then return false end
    SendNUIMessage({
        action = 'play',
        sound = sound,
        volume = tonumber(volume) or 0.1,
        resource = type(resource) == 'string' and resource ~= '' and resource or nil,
    })
    return true
end

-- Local-only playback, no network round trip (UI clicks, personal feedback).
--   exports.DaveDev_SFX:PlayLocal('click', { volume = 0.2, resource = 'my_resource' })
exports('PlayLocal', function(sound, opts)
    opts = type(opts) == 'table' and opts or {}
    return playSound(sound, opts.volume, opts.resource)
end)

RegisterNetEvent('DaveDev_SFX:play', function(payload)
    if type(payload) ~= 'table' then return end
    local coords = toVector3(payload.coords)
    if coords then
        local distance = tonumber(payload.distance) or 5.0
        if #(GetEntityCoords(PlayerPedId()) - coords) > distance then return end
    end
    playSound(payload.sound, payload.volume, payload.resource)
end)

RegisterNetEvent('DaveDev_SFX:play_direct', function(payload)
    if type(payload) ~= 'table' then return end
    playSound(payload.sound, payload.volume, payload.resource)
end)
