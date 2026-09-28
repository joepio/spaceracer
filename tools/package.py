"""Build a portable Windows game and a local Gamenight shelf from a Godot editor.

No export templates or installed runtime needed: the official engine executable
also runs a same-named PCK. For a smaller shipping binary, use Godot's standard
Windows Desktop export with release templates instead.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import zipfile
from check import run_godot


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True, help="GUI Godot .exe (not the console wrapper)")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    if output.exists():
        parser.error("Use a fresh output directory")
    if "console" in args.godot.name:
        parser.error("Pass the GUI executable, not the console wrapper")
    output.mkdir(parents=True)
    (output / ".gdignore").write_text("", encoding="utf-8")
    run_godot(args.godot.resolve(), "--editor", "--import", "--quit")
    run_godot(args.godot.resolve(), "--export-pack", "Windows Desktop", str(output / "SpaceRacer.pck"))
    shutil.copy2(args.godot, output / "SpaceRacer.exe")
    shutil.copy2(source / "README.md", output / "README.md")
    shutil.copy2(source / "LICENSE", output / "LICENSE")
    shutil.copytree(source / "third_party", output / "licenses")
    generated_art = output / "licenses" / "generated-art"
    generated_art.mkdir()
    for name in ("README.md", "generation-prompts.json"):
        shutil.copy2(source / "assets" / name, generated_art / name)
    shutil.copy2(source / "docs/city-advertising/generation-prompts.json", generated_art / "corporate-posters-prompts.json")
    (output / "shelf.json").write_text(json.dumps([{
        "id": "spaceracer", "title": "SpaceRacer", "min_players": 1, "max_players": 4, "players": "1–4",
        "launch": {"command": str(output / "SpaceRacer.exe"), "args": ["--position", "-20000,-20000"], "cwd": str(output)},
    }], indent=2) + "\n", encoding="utf-8")
    sums = []
    for name in ("SpaceRacer.exe", "SpaceRacer.pck"):
        sums.append(hashlib.sha256((output / name).read_bytes()).hexdigest() + "  " + name)
    (output / "SHA256SUMS.txt").write_text("\n".join(sums)+"\n", encoding="utf-8")
    archive = output / "spaceracer-windows.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as packed:
        for path in sorted(output.rglob("*")):
            if path.is_file() and path != archive and path.name not in ("shelf.json", ".gdignore"):
                packed.write(path, path.relative_to(output))
    print(f"Playable: {output / 'SpaceRacer.exe'}\nGameNight shelf: {output / 'shelf.json'}\nPortable ZIP: {archive}")


if __name__ == "__main__":
    main()
