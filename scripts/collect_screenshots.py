#!/usr/bin/env python3
"""Copy the screenshots exported from an xcresult into readable file names.

`xcrun xcresulttool export attachments` writes files with generated names plus a
manifest.json. The manifest's exact shape is not documented, so this walks it
for any object that names an exported file and a human-readable name, and falls
back to keeping every image under its exported name.
"""
import argparse
import json
from pathlib import Path
import re
import shutil

IMAGE_SUFFIXES = {'.png', '.jpg', '.jpeg', '.heic'}


def readable_names(manifest):
    """Return {exported file name: readable name} from any manifest shape."""
    names = {}

    def walk(node):
        if isinstance(node, dict):
            exported = next((v for k, v in node.items() if k.lower().endswith('filename') and isinstance(v, str)), None)
            readable = node.get('suggestedHumanReadableName') or node.get('name')
            if exported and isinstance(readable, str):
                names[exported] = readable
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(manifest)
    return names


def clean(name, suffix):
    """Drop the `_0_<UUID>` tail Xcode appends and keep the name filesystem-safe."""
    stem = Path(name).stem
    stem = re.sub(r'_\d+_[0-9A-Fa-f-]{36}$', '', stem)
    stem = re.sub(r'[^A-Za-z0-9._-]+', '-', stem).strip('-') or 'screenshot'
    return stem + suffix


def collect(source, destination):
    destination.mkdir(parents=True, exist_ok=True)
    manifest_path = source / 'manifest.json'
    names = readable_names(json.loads(manifest_path.read_text())) if manifest_path.exists() else {}
    copied = []
    for path in sorted(source.rglob('*')):
        if path.suffix.lower() not in IMAGE_SUFFIXES:
            continue
        base = destination / clean(names.get(path.name, path.name), path.suffix.lower())
        target, counter = base, 2
        while target.exists():
            target = base.with_name(f'{base.stem}-{counter}{base.suffix}')
            counter += 1
        shutil.copyfile(path, target)
        copied.append(target.name)
    return copied


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    copied = collect(args.source, args.destination)
    print(f'{len(copied)} screenshots')
    for name in copied:
        print(name)


if __name__ == '__main__':
    main()
