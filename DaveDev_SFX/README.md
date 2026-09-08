# DaveDev SFX

A small, source-available sound player for FiveM. DaveDev resources depend on it for their
audio, and it doubles as a drop-in replacement for `interact-sound` on servers that don't run
one. No framework, no dependencies, one NUI page and about 200 lines of Lua.

## Install

```cfg
ensure DaveDev_SFX
```

Start it before the resources that use it. If you already run `interact-sound`, keep both:
DaveDev SFX notices and stops answering the interact-sound events, so nothing plays twice,
while its own API keeps working.

## How resources use it

Each DaveDev resource ships its own audio in a `sounds/` folder and names itself when it
plays, so you never copy files around:

```lua
-- server
exports.DaveDev_SFX:PlayWithinDistance(source, 'flashlight-on', { volume = 0.1, distance = 5.0, resource = 'DaveDev_Flashlight' })
exports.DaveDev_SFX:PlayAtCoords(coords, 'dumpster-open', { volume = 0.2, distance = 10.0, resource = 'DaveDev_Dumpsters' })
exports.DaveDev_SFX:PlayOnSource(target, 'notify', { volume = 0.3 })
exports.DaveDev_SFX:PlayOnAll('siren', { volume = 0.5 })

-- client (played for everyone in range, rate limited per player)
TriggerServerEvent('DaveDev_SFX:server:play', 'flashlight-on', { volume = 0.1, distance = 5.0, resource = GetCurrentResourceName() })

-- client, local only
exports.DaveDev_SFX:PlayLocal('click', { volume = 0.2, resource = GetCurrentResourceName() })
```

| Option | Default | Meaning |
| --- | --- | --- |
| `volume` | `0.1` | 0.0 to 1.0 |
| `distance` | `5.0` | hearing radius in metres, up to 50 |
| `resource` | none | resource whose `sounds/<name>.ogg` holds the file; it must list `sounds/*.ogg` in its `files {}` |

Sound names are file names without the extension (`.ogg` is assumed). If a resource-scoped
file can't be loaded, the player falls back to `DaveDev_SFX/html/sounds`, which is also
where files go for anything that doesn't name a resource.

## interact-sound compatibility

`InteractSound_SV:PlayWithinDistance`, `PlayOnOne` and `PlayOnAll` are answered with files
from `html/sounds` while `interact-sound` isn't running. Set `interactSoundCompat = false`
in `config.lua` to turn that off, or point `interactSoundResource` at a renamed folder.

## License

Source-available under the DaveDev SFX Public Source License in `LICENSE.md`: free to use
and modify on your own servers, not for resale or redistribution as your own. The sound
files inside other DaveDev resources stay under those resources' own licenses.

## Support

Documentation: https://davedev.gitbook.io/wiki/

Support and suggestions: https://discord.gg/wgPZTwFgaz
