"""Exercise the real Godot process through Gamenight's WebSocket protocol.

Standard library only. Uses a synthetic host and opaque controller tokens;
physical controller/focus testing remains a separate hardware check.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import socket
import struct
import subprocess
import tempfile
import threading
import time


class Host:
    def __init__(self):
        self.server = socket.socket()
        self.server.bind(("127.0.0.1", 0))
        self.server.listen()
        self.server.settimeout(20)
        self.port = self.server.getsockname()[1]
        self.messages = []
        self.lock = threading.Lock()
        self.peer = None

    def connect(self):
        self.peer, _ = self.server.accept()
        self.peer.settimeout(20)
        request = b""
        while b"\r\n\r\n" not in request:
            request += self.peer.recv(1)
        headers = dict(line.split(":", 1) for line in request.decode().split("\r\n")[1:] if ":" in line)
        key = next(v.strip() for k, v in headers.items() if k.lower() == "sec-websocket-key")
        accept = base64.b64encode(hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()).decode()
        self.peer.sendall(("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " + accept + "\r\n\r\n").encode())
        self.peer.settimeout(None)
        threading.Thread(target=self.read, daemon=True).start()

    def exact(self, length):
        data = b""
        while len(data) < length:
            chunk = self.peer.recv(length - len(data))
            if not chunk:
                raise EOFError
            data += chunk
        return data

    def read(self):
        try:
            while True:
                first, second = self.exact(2)
                length = second & 127
                if length == 126: length = struct.unpack("!H", self.exact(2))[0]
                elif length == 127: length = struct.unpack("!Q", self.exact(8))[0]
                mask = self.exact(4) if second & 128 else None
                data = self.exact(length)
                if mask: data = bytes(value ^ mask[i % 4] for i, value in enumerate(data))
                if first & 15 == 1: self.messages.append(json.loads(data))
        except (OSError, EOFError, ValueError):
            pass

    def send(self, kind, **values):
        data = json.dumps(dict(type=kind, **values)).encode()
        header = bytes([129, len(data)]) if len(data) < 126 else bytes([129, 126]) + struct.pack("!H", len(data))
        with self.lock:
            self.peer.sendall(header + data)

    def close(self):
        if self.peer:
            self.peer.shutdown(socket.SHUT_RDWR)
            self.peer.close()
        self.server.close()


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
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    # The Windows console wrapper starts another process; use the actual engine
    # so our lifetime/exit and failure-cleanup assertions own the right process.
    executable = args.godot.replace("_console.exe", ".exe")
    host = Host()
    child = None
    stop = threading.Event()
    with tempfile.TemporaryDirectory(prefix="ion-integration-") as temporary:
        probe = Path(temporary) / "probe.json"
        env = dict(os.environ, GAMENIGHT="1", GAMENIGHT_GAME_ID="ion-rush",
                   GAMENIGHT_TOKEN="ion-test-token", GAMENIGHT_ADDR=f"127.0.0.1:{host.port}", ION_PROBE_PATH=str(probe))
        log = open(Path(temporary) / "godot.log", "w+")
        try:
            # This suite tests protocol/controller behavior with sound disabled;
            # hardware audio-device changes must not interrupt the native renderer.
            command = [executable, "--position", "-20000,-20000", "--audio-driver", "Dummy"]
            if not args.packed: command += ["--path", str(project)]
            if args.headless: command.append("--headless")
            child = subprocess.Popen(command, env=env, stdout=log, stderr=log)
            host.connect()
            hello = wait(lambda: host.messages, lambda messages: any(m["type"] == "hello" for m in messages))
            assert next(m for m in hello if m["type"] == "hello")["token"] == "ion-test-token"
            host.send("welcome", protocol_version=1, party={})
            host.send("setting_changed", key="laps", value=1)
            host.send("setting_changed", key="difficulty", value="easy")
            host.send("setting_changed", key="biome", value="forest")
            seats = [dict(index=i, occupant=dict(kind="local", player_id=f"p{i}"), controller=token)
                     for i, token in [(0, "ordinal:7"), (2, "ordinal:2")]]
            players = [dict(id="p0", name="Azure", color="#00aaff", skin_color="#8a6644"),
                       dict(id="p2", name="Rose", color="#ff4488", skin_color="#efbd89")]
            session = "ion-session-one"
            host.send("prepare", game="ion-rush", session=session, seats=seats, players=players)
            wait(lambda: host.messages, lambda messages: any(m["type"] == "ready" for m in messages))
            def read():
                # The optional probe is rewritten by the game; retry a partial read.
                return wait(lambda: json.loads(probe.read_text()), lambda state: isinstance(state, dict), timeout=2)
            state = wait(read, lambda s: s["phase"] == "ready")
            assert state["muted"] and not state["running"] and state["views"] == 2
            assert args.headless or not state["visible"]
            assert state["clock"] == 0 and state["countdown"] == 3
            assert state["difficulty"] == "easy"
            assert state["biome"] == "forest"
            host.send("setting_changed", key="biome", value="city")
            wait(read, lambda s: s["next_biome"] == "city")
            assert read()["biome"] == "forest", "World changes apply next race"
            host.send("setting_changed", key="difficulty", value="hard")
            wait(read, lambda s: s["next_difficulty"] == "hard")
            assert read()["difficulty"] == "easy", "Difficulty changes apply next race"
            frames = [dict(controller="ordinal:2", axes=[32767,0,0,0,0,32767], buttons=0),
                      dict(controller="ordinal:7", axes=[-32767,0,0,0,0,32767], buttons=0)]

            def stream():
                while not stop.wait(.025):
                    try: host.send("controller_frame", controllers=frames)
                    except OSError: return

            threading.Thread(target=stream, daemon=True).start()
            host.send("start", session=session)
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
            host.send("pause", session="wrong-session")
            time.sleep(.15)
            assert read()["running"]
            host.send("pause", session=session)
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
            host.send("party_updated", session=session, seats=seats, players=list(reversed(players)), presence=[])
            updated = wait(read, lambda s: s["racers"][0]["name"] == "Azure Updated")
            assert updated["clock"] == paused["clock"] and updated["racers"][1]["name"] == "Rose"
            host.send("resume", session=session)
            wait(read, lambda s: s["clock"] > paused["clock"] + .2)
            stop.set()
            time.sleep(.4)
            before = read()["racers"][0]["speed"]
            time.sleep(.4)
            assert read()["racers"][0]["speed"] < before, "Lost host stream must release throttle"
            # Back is ignored; Start accepts one press after release, even when held.
            time.sleep(1.1)
            for _ in range(8):
                host.send("controller_frame", controllers=[dict(controller="ordinal:7",axes=[0]*6,buttons=64)])
                time.sleep(.025)
            assert sum(m["type"] == "request_overlay" for m in host.messages) == 0
            for _ in range(20):
                host.send("controller_frame", controllers=[dict(controller="ordinal:7",axes=[0]*6,buttons=128)])
                time.sleep(.025)
            assert sum(m["type"] == "request_overlay" for m in host.messages) == 1
            host.send("dispose", session=session)
            wait(read, lambda s: s["phase"] == "idle" and s["racers"] == [])
            host.send("prepare", game="ion-rush", session="ion-session-two", seats=seats, players=players)
            wait(read, lambda s: s["phase"] == "ready" and s["session"] == "ion-session-two")
            assert read()["difficulty"] == "hard"
            assert read()["biome"] == "city"
            host.close()
            child.wait(timeout=8)
            assert child.returncode == 0
            log.flush(); log.seek(0)
            output = log.read()
            assert "SCRIPT ERROR" not in output and "ERROR:" not in output, output
            print("PASS native WebSocket authentication, hidden prepare, sparse controller ownership, weapon input, pause/resume, stale input, live profiles, Start gate, dispose/reprepare, disconnect exit")
        except BaseException:
            log.flush(); log.seek(0)
            print(log.read())
            raise
        finally:
            stop.set()
            if child and child.poll() is None:
                child.terminate(); child.wait(timeout=5)
            log.close()


if __name__ == "__main__":
    main()
