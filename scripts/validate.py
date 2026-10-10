#!/usr/bin/env python3
"""Static resource checks. These do not run FiveM, a server, or resource code."""
from collections import defaultdict
from html.parser import HTMLParser
from pathlib import Path, PurePosixPath
import os
import subprocess
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_READER = ROOT / "scripts/read-manifest.lua"
# SFX receives audio from other resources. Its local fallback folder is optional.
OPTIONAL_GLOBS = {
    ("DaveDev_SFX", "html/sounds/*.ogg"),
    ("DaveDev_SFX", "html/sounds/*.mp3"),
    ("DaveDev_SFX", "html/sounds/*.wav"),
}
PATH_KEYS = {"client_script", "server_script", "shared_script", "file", "ui_page"}


def run(command):
    result = subprocess.run(command, capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise ValueError((result.stderr or result.stdout).strip())
    return result.stdout


def read_manifest(path):
    output = run([os.environ.get("CFXLUA", "lua"), str(MANIFEST_READER), str(path)])
    metadata = defaultdict(list)
    for line in output.splitlines():
        key, value = line.split("\t", 1)
        metadata[key].append(value)
    return metadata


def resolve_files(resource, value, *, directory=False):
    """Resolve local, resource-relative manifest paths without following escapes."""
    if value.startswith("@"):
        raise ValueError(f"External resource reference needs an explicit validation rule: {value}")
    path = PurePosixPath(value)
    if not value or path.is_absolute() or ".." in path.parts or "\\" in value or ":" in value:
        raise ValueError(f"Unsafe or unsupported resource path: {value}")
    # FiveM's **.lua shorthand means the same as **/*.lua.
    pattern = value.replace("**.", "**/*.")
    matches = sorted(p for p in resource.glob(pattern) if (p.is_dir() if directory else p.is_file()))
    for candidate in matches:
        if not candidate.resolve().is_relative_to(resource.resolve()):
            raise ValueError(f"Resource path escapes its folder: {value}")
    return matches


class PageAssets(HTMLParser):
    def __init__(self):
        super().__init__()
        self.paths = []

    def handle_starttag(self, tag, attributes):
        for key, value in attributes:
            if value and (key == "src" or (tag == "link" and key == "href")):
                self.paths.append(value)


def validate_resource(resource):
    metadata = read_manifest(resource / "fxmanifest.lua")
    if not metadata["fx_version"] or "gta5" not in metadata["game"]:
        raise ValueError("Manifest must declare fx_version and game 'gta5'")
    if len(metadata["version"]) != 1 or not metadata["version"][0].strip():
        raise ValueError("Manifest must declare one nonempty resource version")
    for required in ("README.md", "LICENSE.md"):
        if not (resource / required).is_file():
            raise ValueError(f"Missing package file: {required}")
    packaged = set()
    pages = []
    wavepacks = []
    path_keys = PATH_KEYS | {key for key in metadata if key.startswith("data_file:")}
    for key in sorted(path_keys):
        for value in metadata[key]:
            is_wavepack = key == "data_file:AUDIO_WAVEPACK"
            matches = resolve_files(resource, value, directory=is_wavepack)
            if not matches:
                if key == "file" and (resource.name, value) in OPTIONAL_GLOBS:
                    continue
                target_kind = "directories" if is_wavepack else "files"
                raise ValueError(f"{key} references no {target_kind}: {value}")
            if is_wavepack:
                wavepacks.extend(matches)
            if key == "file":
                packaged.update(path.resolve() for path in matches)
            if key == "ui_page":
                pages.extend(matches)
    for wavepack in wavepacks:
        waves = resolve_files(resource, wavepack.relative_to(resource).as_posix() + "/*.awc")
        if not waves:
            raise ValueError(f"AUDIO_WAVEPACK has no .awc files: {wavepack.name}")
        if any(wave.resolve() not in packaged for wave in waves):
            raise ValueError(f"AUDIO_WAVEPACK audio is missing from files: {wavepack.name}")
    for page in pages:
        if page.resolve() not in packaged:
            raise ValueError(f"ui_page is missing from files: {page.name}")
        assets = PageAssets()
        assets.feed(page.read_text(encoding="utf-8"))
        for value in assets.paths:
            parsed = urlsplit(value)
            if parsed.scheme or parsed.netloc:
                raise ValueError(f"Remote NUI asset needs an explicit validation rule: {value}")
            target = (page.parent / unquote(parsed.path)).resolve()
            if not target.is_relative_to(resource.resolve()) or not target.is_file():
                raise ValueError(f"NUI asset is missing or outside the resource: {value}")
            if target not in packaged:
                raise ValueError(f"NUI asset is missing from files: {value}")
    return metadata


def main():
    for resource in ROOT.glob("DaveDev_*"):
        if resource.is_symlink():
            raise ValueError(f"Resource folder must not be a symlink: {resource.name}")
        if resource.is_dir() and not (resource / "fxmanifest.lua").is_file():
            raise ValueError(f"Missing resource manifest: {resource.name}/fxmanifest.lua")
    manifests = sorted(ROOT.glob("*/fxmanifest.lua"))
    if not manifests:
        raise ValueError("No resource manifests found")
    counts = {"lua": 0, "js": 0}
    for manifest in manifests:
        resource = manifest.parent
        for path in sorted(resource.rglob("*")):
            if path.is_symlink():
                raise ValueError(f"Symlink is not supported in a resource package: {path}")
            if path.suffix == ".lua" and path.is_file():
                run([os.environ.get("CFXLUAC", "luac"), "-p", str(path)])
                counts["lua"] += 1
            elif path.suffix == ".js" and path.is_file():
                run(["node", "--check", str(path)])
                counts["js"] += 1
        metadata = validate_resource(resource)
        print(f"PASS {resource.name} {metadata['version'][0]}: manifest and package references")
    print(f"PASS {counts['lua']} Lua files (CfxLua), {counts['js']} JavaScript files (Node syntax)")
    print("Static checks only. FiveM startup, gameplay, networking and audio still need in-game testing.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.TimeoutExpired) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
