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
import subprocess
import zipfile


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
    subprocess.run([str(args.godot.resolve()), "--headless", "--path", str(source), "--editor", "--import", "--quit"], check=True)
    subprocess.run([str(args.godot.resolve()), "--headless", "--path", str(source), "--export-pack", "Windows Desktop", str(output / "IonRush.pck")], check=True)
    shutil.copy2(args.godot, output / "IonRush.exe")
    shutil.copy2(source / "README.md", output / "README.md")
    shutil.copy2(source / "LICENSE", output / "LICENSE")
    shutil.copytree(source / "third_party", output / "licenses")
    (output / "shelf.json").write_text(json.dumps([{
        "id": "ion-rush", "title": "Ion Rush", "min_players": 1, "max_players": 4, "players": "1–4",
        "launch": {"command": str(output / "IonRush.exe"), "args": ["--position", "-20000,-20000"], "cwd": str(output)},
    }], indent=2) + "\n", encoding="utf-8")
    sums = []
    for name in ("IonRush.exe", "IonRush.pck"):
        sums.append(hashlib.sha256((output / name).read_bytes()).hexdigest() + "  " + name)
    (output / "SHA256SUMS.txt").write_text("\n".join(sums)+"\n", encoding="utf-8")
    archive = output / "ion-rush-windows.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as packed:
        for path in sorted(output.rglob("*")):
            if path.is_file() and path != archive and path.name not in ("shelf.json", ".gdignore"):
                packed.write(path, path.relative_to(output))
    print(f"Playable: {output / 'IonRush.exe'}\nGameNight shelf: {output / 'shelf.json'}\nPortable ZIP: {archive}")


if __name__ == "__main__":
    main()
