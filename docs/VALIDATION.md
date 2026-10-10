# Resource validation

The `FiveM static validation` check runs on pull requests, pushes to `main` and
maintenance branches, and manual runs. It checks:

- Every resource Lua file with the official Cfx.re Lua compiler's parse-only mode.
  Backtick hashes and CfxLua syntax are checked directly, without rewriting code.
- Every resource JavaScript file with `node --check`.
- Manifest script, data file and NUI paths, including globs and local NUI assets.
- Each resource's README and license are present.
- The validator's own positive and negative tests.

The SFX fallback audio patterns under `html/sounds` may be empty. These three
specific patterns are allowed only in SFX's `files` list; missing scripts, other
empty patterns and unlisted NUI assets fail. External resource references and
remote NUI assets need explicit validation rules before they can be added.
`data_file` keeps its type: `AUDIO_WAVEPACK` points to a resource-local directory
with `.awc` files included in the manifest's `files` list. Other data-file types
must point to files.

## Run locally

You need Python 3.10+, Node.js 24, Git, GNU Make and a C++ compiler on Linux.
From the repository root:

```sh
bash scripts/build-cfxlua.sh .cfxlua
export CFXLUA="$PWD/.cfxlua/lua"
export CFXLUAC="$PWD/.cfxlua/luac"
python3 -m unittest discover -s scripts/tests -v
python3 scripts/validate.py
```

The build helper requires a new directory and does not replace an existing one.
Subsequent checks can reuse the built tools. It pins
[citizenfx/lua at 4b086dc](https://github.com/citizenfx/lua/commit/4b086dc082da96a8e21aaa38ef7c0f4a7697f2a4)
and the GLM submodule recorded by that commit. Review and test that source pin
when updating the toolchain. Dependabot covers the SHA-pinned GitHub Actions.

Manifest metadata is collected in an isolated Lua environment without standard
libraries, with a process time limit. This is a practical file-reference check,
not a complete implementation of FXServer's manifest loader.

## What still needs FiveM

These checks do not start FXServer or execute client/server resource scripts.
They do not test native calls, events, gameplay, multiplayer sync, streamed
binary assets or actual audio playback. Before a release, start the resource on
a test server and exercise its normal use and resource restart behavior.

References: [CfxLua](https://docs.fivem.net/docs/scripting-manual/runtimes/lua/)
and [resource manifests](https://docs.fivem.net/docs/scripting-reference/resource-manifest/).
