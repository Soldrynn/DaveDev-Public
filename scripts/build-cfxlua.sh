#!/usr/bin/env bash
# The official Cfx.re Lua fork accepts FiveM syntax, including backtick hashes.
set -euo pipefail
if [[ $# != 1 || -e "$1" ]]; then
  echo 'Usage: bash scripts/build-cfxlua.sh <new build directory>' >&2
  exit 1
fi
revision=4b086dc082da96a8e21aaa38ef7c0f4a7697f2a4
git init "$1"
git -C "$1" remote add origin https://github.com/citizenfx/lua.git
git -C "$1" fetch --depth 1 origin "$revision"
git -C "$1" checkout --detach FETCH_HEAD
test "$(git -C "$1" rev-parse HEAD)" = "$revision"
# This uses the GLM commit recorded by the pinned parent, never a branch tip.
git -C "$1" submodule update --init --depth 1
make -C "$1" -j2 lua luac
"$1/luac" -v
