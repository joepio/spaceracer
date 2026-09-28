"""Write checksums and a GameNight entry for a versioned Windows release."""
import argparse
import base64
import hashlib
import json
import math
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = "https://github.com/joepio/spaceracer"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--tag", required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"v\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?", args.tag):
        parser.error("Use a version tag such as v0.4.0 or v0.4.1-preview.1")
    archive = args.directory / "spaceracer-windows.zip"
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (args.directory / "release-sha256.txt").write_text(f"{digest}  {archive.name}\n", encoding="utf-8")
    with zipfile.ZipFile(archive) as packed:
        for required in ["SpaceRacer.exe", "SpaceRacer.pck", "LICENSE", "README.md"]:
            if required not in packed.namelist():
                raise ValueError(f"Missing release file: {required}")
        installed_bytes = sum(item.file_size for item in packed.infolist())
    def art(name):
        return "data:image/png;base64," + base64.b64encode((ROOT / "assets/gamenight" / name).read_bytes()).decode("ascii")
    entry = {
        "$schema": "../schema.json", "id": "spaceracer", "title": "SpaceRacer",
        "tagline": "High-speed hover racing, airborne shortcuts and weapons across three procedural worlds.",
        "developer": "Joep Meindertsma", "players": {"min": 1, "max": 4, "best": 4},
        "match_minutes": 5, "price": "free", "tags": ["racing", "versus", "splitscreen", "godot"],
        "color": "#53ffe0", "cover": art("cover.png"), "icon": art("icon.png"),
        "integration": {"level": "integrated", "protocol": 1},
        "requirements": {"disk_mb": math.ceil(installed_bytes / 1_000_000), "ram_mb": 4096,
                         "cpu": "Modern quad-core; split-screen is more demanding",
                         "gpu": "Vulkan-capable GPU; dedicated graphics recommended for High and split-screen"},
        "links": {"source": REPOSITORY, "homepage": REPOSITORY,
                  "releases": f"{REPOSITORY}/releases"},
        "downloads": {"windows": {"url": f"{REPOSITORY}/releases/download/{args.tag}/{archive.name}",
                                  "sha256": digest, "size_mb": math.ceil(archive.stat().st_size / 1_000_000),
                                  "entrypoint": "SpaceRacer.exe"}},
    }
    (args.directory / "spaceracer.catalog.json").write_text(json.dumps(entry, indent=2) + "\n", encoding="utf-8")
    print(f"Release {args.tag}: {archive.stat().st_size} bytes; SHA256 {digest}")


if __name__ == "__main__":
    main()
