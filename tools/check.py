"""Run the release checks and fail on Godot errors, even when it exits with code 0."""
import argparse
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def run_godot(executable, *arguments):
    command = [str(executable), "--headless", "--path", str(ROOT), *arguments]
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, encoding="utf-8", errors="replace", timeout=900)
    print(result.stdout, end="", flush=True)
    if result.returncode or re.search(r"(?:SCRIPT ERROR|SHADER ERROR|ERROR):", result.stdout):
        raise RuntimeError(f"Godot check failed: {' '.join(arguments)} (exit {result.returncode})")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    args = parser.parse_args()
    run_godot(args.godot.resolve(), "--editor", "--import", "--quit")
    for name in ["run", "menu", "flight", "effects", "city", "emp", "recharge_strips", "ai_boost", "ai_surfaces", "ai_variety", "settings", "energy", "desert", "ocean"]:
        run_godot(args.godot.resolve(), "--script", f"res://tests/{name}.gd")


if __name__ == "__main__":
    main()
