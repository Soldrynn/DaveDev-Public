# DaveDev Public

Free, source-available FiveM resources by DaveDev. Each resource lives in its own folder with
its own `README.md` and its own `LICENSE.md`; there is no blanket license for this repository,
so please read the one that ships with the resource you're using.

| Resource | What it is | License |
| --- | --- | --- |
| [`DaveDev_Flashlite`](DaveDev_Flashlite) | A standalone flashlight with smooth aiming, synced beam visuals and native audio cues. No framework, inventory or NUI needed. | [DaveDev Flashlite Public Source License](DaveDev_Flashlite/LICENSE.md) |
| [`DaveDev_SFX`](DaveDev_SFX) | A small shared sound player that DaveDev resources can use in place of `interact-sound` or `xsound`. Plays each resource's own audio. | [DaveDev SFX Public Source License](DaveDev_SFX/LICENSE.md) |

## Downloads

- Flashlite: [v1.0.1 release and resource ZIP](https://github.com/Soldrynn/DaveDev-Public/releases/tag/v1.0.1).
- SFX: [source on main](https://github.com/Soldrynn/DaveDev-Public/tree/main/DaveDev_SFX).
  Its source manifest is version `2.0.0`; no separate SFX GitHub release has been
  published as of 9 October 2026. Download or clone the repository and copy the
  `DaveDev_SFX` folder.

Releases are per resource. See [release and download notes](docs/RELEASING.md)
for reproducible source copies and the naming convention for future releases.

## Install

Download or clone the repository and copy the folder you want into your resources, then
`ensure` it in your server config. Each resource's README covers the details.

```cfg
ensure DaveDev_SFX
ensure DaveDev_Flashlite
```

## Paid resources

The expanded versions live on the DaveDev store: https://davedev.tebex.io/

"DaveDev Immersive Flashlight" is the full flashlight with framework and inventory support,
battery simulation, quick-holster, bundled SFX and support tooling. It uses `DaveDev_SFX` for
its audio, so the copy here is the same one that ships with it.

## Contributing

Bug reports and pull requests are welcome through GitHub. Public forks are for review and
contribution only; the licenses explain what can and can't be redistributed.

## Validation and security

[Static validation](docs/VALIDATION.md) checks Lua and JavaScript syntax and
resource file references. In-game testing is still needed before release.
See [SECURITY.md](SECURITY.md) for reporting a security concern privately.

## Support

Documentation: https://davedev.gitbook.io/wiki/

Support and suggestions: https://discord.gg/wgPZTwFgaz
