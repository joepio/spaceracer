"""Exercise the real Godot process through Gamenight's WebSocket protocol.

Standard library only. Uses the GameNight SDK's fake host
(addons/gamenight/fake_host.py) and opaque controller tokens; physical
controller/focus testing remains a separate hardware check.
"""
import argparse
import json
import os
from pathlib import Path
import sys
import tempfile
import threading
import time

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / "addons" / "gamenight"))
from fake_host import FakeHost  # noqa: E402


def wait(read, predicate, timeout=15):
    deadline = time.monotonic() + timeout
    latest = None
    while time.monotonic() < deadline:
        try:
            latest = read()
            if predicate(latest): return latest
        except (OSError, ValueError, KeyError):
            pass
        time.sleep(.03)
    raise AssertionError(f"Timed out; last state: {latest}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--packed", action="store_true", help="Run the PCK beside the executable, not project sources")
    parser.add_argument("--launcher-script", help="Exercise the Windows debug wrapper instead of launching the game directly")
    parser.add_argument("--host-launcher", help="Exercise the daemon's --launch-hidden process/job wrapper too")
    args = parser.parse_args()
    # The Windows console wrapper starts another process; use the actual engine
    # so our lifetime/exit and failure-cleanup assertions own the right process.
    executable = args.godot.replace("_console.exe", ".exe")
    stop = threading.Event()
    host = None
    with tempfile.TemporaryDirectory(prefix="spaceracer-integration-") as temporary:
        probe = Path(temporary) / "probe.json"
        # This suite tests protocol/controller behavior with sound disabled;
        # hardware audio-device changes must not interrupt the native renderer.
        command = [executable, "--position", "-20000,-20000", "--audio-driver", "Dummy"]
        if not args.packed: command += ["--path", str(PROJECT)]
        if args.headless: command.append("--headless")
        if args.launcher_script:
            assert args.packed, "The debug launcher requires a packaged build"
            command = [str(Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe"),
                       "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", args.launcher_script,
                       "-BuildDirectory", str(Path(executable).parent), "-Managed"]
            if args.headless: command.append("-Headless")
        if args.host_launcher:
            command = [args.host_launcher, "--launch-hidden", *command]
        try:
            # The fake host checks the hello's game id and launch token.
            host = FakeHost(executable, "spaceracer", command=command, timeout=20,
                            env=dict(SPACERACER_PROBE_PATH=str(probe)))
            host.welcome()
            host.setting("laps", 1)
            host.setting("weapon_pickups", False)
            host.setting("difficulty", "easy")
            host.setting("biome", "forest")
            seats = [host.local_seat(i, f"p{i}", controller=token) for i, token in [(0, "ordinal:7"), (2, "ordinal:2")]]
            players = [dict(id="p0", name="Azure", color="#00aaff", skin_color="#8a6644"),
                       dict(id="p2", name="Rose", color="#ff4488", skin_color="#efbd89")]
            session = "spaceracer-session-one"
            host.prepare(seats, players, session=session)
            def read():
                # The optional probe is rewritten by the game; retry a partial read.
                return wait(lambda: json.loads(probe.read_text()), lambda state: isinstance(state, dict), timeout=2)
            state = wait(read, lambda s: s["phase"] == "ready")
            assert state["muted"] and not state["running"] and state["views"] == 2
            assert args.headless or not state["visible"]
            assert state["clock"] == 0 and state["countdown"] == 3
            assert state["difficulty"] == "easy"
            assert state["biome"] == "forest"
            host.setting("biome", "city")
            wait(read, lambda s: s["next_biome"] == "city")
            assert read()["biome"] == "forest", "World changes apply next race"
            host.setting("difficulty", "hard")
            wait(read, lambda s: s["next_difficulty"] == "hard")
            assert read()["difficulty"] == "easy", "Difficulty changes apply next race"
            frames = [dict(controller="ordinal:2", axes=[32767,0,0,0,0,32767], buttons=0),
                      dict(controller="ordinal:7", axes=[-32767,0,0,0,0,32767], buttons=0)]

            def stream():
                while not stop.wait(.025):
                    try: host.frames(*frames)
                    except OSError: return

            threading.Thread(target=stream, daemon=True).start()
            host.start()
            active = wait(read, lambda s: s["clock"] > .8)
            assert active["racers"][0]["x"] < -5 and active["racers"][1]["x"] > 5, active
            assert active["muted"] == (not active["sound_enabled"]) and active["running"]
            frames[1]["axes"][2] = 16384
            frames[1]["axes"][3] = -32767
            frames[1]["axes"][4] = 16384
            stick_state = wait(read, lambda s: s["racers"][0]["trim"] > .9)
            assert .45 < stick_state["racers"][0]["braking"] < .5
            assert stick_state["racers"][1]["trim"] == 0, "Right stick must stay with its controller owner"
            frames[1]["axes"][2:5] = [0, 0, 0]
            frames[1]["buttons"] = 4
            fire_state = wait(read, lambda s: s["racers"][0]["fire_held"] and s["racers"][0]["braking"] == 0)
            assert not fire_state["racers"][1]["fire_held"], "Weapon input must stay with its controller owner"
            frames[1]["buttons"] = 0
            host.send(dict(type="pause", session="wrong-session"))
            time.sleep(.15)
            assert read()["running"]
            host.pause()
            paused = wait(read, lambda s: s["phase"] == "paused")
            time.sleep(.4)
            assert read()["clock"] == paused["clock"] and read()["muted"]
            assert read()["vfx_clock"] == paused["vfx_clock"], "Engine effects must freeze while paused"
            assert read()["speed_travel"] == paused["speed_travel"], "Speed presentation must freeze while paused"
            assert read()["speed_camera_clock"] == paused["speed_camera_clock"], "Speed camera vibration must freeze while paused"
            assert read()["city_time"] == paused["city_time"], "City traffic must freeze while paused"
            assert read()["traffic_position"] == paused["traffic_position"], "Air traffic must freeze while paused"
            assert read()["tunnel_time"] == paused["tunnel_time"], "Tunnel lighting must freeze while paused"
            assert args.headless or not read()["visible"]
            # A live profile update must preserve progress and profile ownership.
            players[0].update(name="Azure Updated", color="#22ee99", avatar=json.dumps(dict(v=1,w=48,h=48,px=["#ff00ff"]+[None]*2303)))
            host.send(dict(type="party_updated", session=session, seats=seats, players=list(reversed(players)), presence=[]))
            updated = wait(read, lambda s: s["racers"][0]["name"] == "Azure Updated")
            assert updated["clock"] == paused["clock"] and updated["racers"][1]["name"] == "Rose"
            host.resume()
            resumed = wait(read, lambda s: s["clock"] > paused["clock"] + .2 and s["racers"][0].get("face_revision",0) >= 2)
            assert resumed["racers"][0]["face_signature"][0] == players[0]["avatar"], "Hull decal follows player identity"
            assert resumed["racers"][1]["face_revision"] == 1, "Other pilot decal remains cached"
            stop.set()
            time.sleep(.4)
            before = read()["racers"][0]["speed"]
            time.sleep(.4)
            assert read()["racers"][0]["speed"] < before, "Lost host stream must release throttle"
            # Start pauses locally; only Back returns to GameNight. Held buttons
            # act once, and returning to a managed race preserves its players.
            def button_frames(buttons, count=8):
                for _ in range(count):
                    host.frames(dict(controller="ordinal:7", axes=[0]*6, buttons=buttons))
                    time.sleep(.025)
            button_frames(0)
            button_frames(128, 20)
            local_pause = wait(read, lambda s: s["phase"] == "running" and not s["running"])
            assert host.count("request_overlay") == 0
            time.sleep(.15)
            assert read()["clock"] == local_pause["clock"], "Start freezes the current race"
            button_frames(0)
            button_frames(128)
            wait(read, lambda s: s["running"] and s["clock"] > local_pause["clock"])
            assert read()["racers"][0]["name"] == "Azure Updated"
            button_frames(0)
            button_frames(64, 20)
            assert host.count("request_overlay") == 1
            host.dispose()
            wait(read, lambda s: s["phase"] == "idle" and s["racers"] == [])
            host.prepare(seats, players, session="spaceracer-session-two", wait_ready=False)
            wait(read, lambda s: s["phase"] == "ready" and s["session"] == "spaceracer-session-two")
            assert read()["difficulty"] == "hard"
            assert read()["biome"] == "city"
            host.setting("biome", "cell")
            wait(read, lambda s: s["next_biome"] == "cell")
            assert read()["biome"] == "city", "Cell applies to the next race"
            host.dispose()
            wait(read, lambda s: s["phase"] == "idle")
            host.prepare(seats, players, session="spaceracer-session-cell", wait_ready=False)
            cell_state = wait(read, lambda s: s["phase"] == "ready" and s["session"] == "spaceracer-session-cell")
            assert cell_state["biome"] == "cell" and cell_state["views"] == 2
            host.start()
            active_cell = wait(read, lambda s: s["clock"] > .3)
            host.pause()
            paused_cell = wait(read, lambda s: s["phase"] == "paused")
            time.sleep(.2)
            assert read()["city_time"] == paused_cell["city_time"], "Cell organisms freeze during pause"
            host.disconnect()
            assert host.exit_code(8) == 0
            output = host.output()
            assert "SCRIPT ERROR" not in output and "ERROR:" not in output, output
            print("PASS native WebSocket authentication, hidden prepare, sparse controller ownership, weapon input, pause/resume, stale input, live profiles, Start pause / Back lobby, dispose/reprepare, disconnect exit")
        except BaseException:
            if host: print(host.output())
            raise
        finally:
            stop.set()
            if host: host.close()


if __name__ == "__main__":
    main()
