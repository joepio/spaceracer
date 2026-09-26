"""Build and verify a sideloadable, debug-signed Android APK (Godot 4.5.2).

Install Godot Android export templates and configure its Java/Android SDK paths
first. This development build is for direct installation, not Play Store upload.
"""
import argparse
import hashlib
import os
from pathlib import Path
import subprocess
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--sdk", type=Path, default=Path(os.environ.get("ANDROID_HOME", Path.home() / "AppData/Local/Android/Sdk")))
    parser.add_argument("--java", type=Path, default=Path(os.environ.get("JAVA_HOME", "C:/Program Files/Android/Android Studio/jbr")))
    parser.add_argument("--output", type=Path, default=Path("build/android/IonRush.apk"))
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["JAVA_HOME"] = str(args.java)
    keystore = Path(env.get("GODOT_ANDROID_KEYSTORE_DEBUG_PATH", Path.home() / ".android/debug.keystore"))
    if not keystore.is_file():
        parser.error("Configure GODOT_ANDROID_KEYSTORE_DEBUG_PATH or create ~/.android/debug.keystore with Android Studio")
    env.setdefault("GODOT_ANDROID_KEYSTORE_DEBUG_PATH", str(keystore))
    env.setdefault("GODOT_ANDROID_KEYSTORE_DEBUG_USER", "androiddebugkey")
    env.setdefault("GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD", "android")
    command = [str(args.godot.resolve()), "--headless", "--path", str(source)]
    subprocess.run(command + ["--editor", "--import", "--quit"], check=True, env=env)
    subprocess.run(command + ["--export-debug", "Android", str(output)], check=True, env=env)
    signer = args.sdk / "build-tools/35.0.0/lib/apksigner.jar"
    subprocess.run([str(args.java / "bin/java.exe"), "-jar", str(signer), "verify", "--verbose", str(output)], check=True, env=env)
    with zipfile.ZipFile(output) as apk:
        assert "lib/arm64-v8a/libgodot_android.so" in apk.namelist(), "ARM64 runtime missing"
        assert "assets/project.binary" in apk.namelist(), "Game project missing"
        assert apk.testzip() is None, "Corrupt APK entry"
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix(".sha256").write_text(f"{digest}  {output.name}\n", encoding="utf-8")
    print(f"Verified APK: {output} ({output.stat().st_size / 1048576:.1f} MiB)")


if __name__ == "__main__":
    main()
