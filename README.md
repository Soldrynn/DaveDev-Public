# DaveDev's Immersive Flashlite

DaveDev's Immersive Flashlite is a free standalone FiveM flashlight resource with smooth aiming, synced beam visuals, native on/off audio, and a small configuration surface.

Flashlite is built for servers that want a simple command/keybind flashlight without framework, inventory, NUI, or external audio dependencies.

## Features

- Standalone `/flashlite` equip and put-away command
- FiveM keybind support, default `O`
- Separate beam toggle, default middle mouse
- Smooth camera-driven beam aiming
- Adjustable beam spread while equipped
- Nearby-player visual sync
- Native GTA audio cues for beam on/off
- Streamed flashlight animation and corona prop
- Strict, readable config focused on controls, light tuning, audio cues, and performance

## Installation

1. Place `DaveDev_Flashlite` in your resources folder.
2. Add this to your server config:

```cfg
ensure DaveDev_Flashlite
```

No framework, inventory, item setup, NUI, or external audio resource is required.

## Controls

- `/flashlite` equips or puts away the flashlight.
- `O` equips or puts away the flashlight by default.
- `/flashlite_toggle` toggles the beam while equipped.
- Middle mouse toggles the beam by default.
- Hold aim while equipped to steer the beam.
- Use the configured cone controls while equipped to adjust light spread.

Keybinds can be changed through FiveM key bindings after the resource has started.

## Configuration

Edit `config.lua` for:

- command names and keybind defaults
- light color, distance, brightness, radius, falloff, and tuning range
- native local on/off audio cue names
- sync interval, remote draw distance, smoothing, and corona limits

Flashlite intentionally does not include framework hooks, inventory hooks, usable-item registration, public exports, custom bridge files, NUI audio, bundled SFX files, or holster sounds.

## Expanded Version

"DaveDev Immersive Flashlight" ([DaveDev Store Link](https://davedev.tebex.io/package/immersive-flashlight)) is the expanded version for servers that need framework support, inventory item use, custom bridges, public APIs, advanced integrations, bundled SFX, and support tooling.

## License

DaveDev's Immersive Flashlite is released under the included [DaveDev Flashlite Public Source License](LICENSE.md). You may use and privately modify it for your own server, but redistribution, resale, reuploading, commercial bundles, competing resource forks, branding removal, and asset/code extraction are not permitted.

## Support

Documentation: https://davedev.gitbook.io/wiki/

Support and suggestions: https://discord.gg/wgPZTwFgaz
