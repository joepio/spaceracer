"""Real installed host -> persistent local entry -> managed PowerShell -> native game.

Isolated port/profile memory; only warms the game off-screen. Standard library.
"""
import base64
import json
import os
from pathlib import Path
import socket
import struct
import subprocess
import tempfile
import threading
import time


class Client:
    def __init__(self, port):
        self.peer = socket.create_connection(("127.0.0.1", port), timeout=3)
        key = base64.b64encode(os.urandom(16)).decode()
        self.peer.sendall(f"GET / HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n".encode())
        response = b""
        while b"\r\n\r\n" not in response:
            response += self.peer.recv(1)
        assert b"101" in response
        self.peer.settimeout(None)
        self.messages = []
        threading.Thread(target=self.read, daemon=True).start()

    def exact(self, length):
        data = b""
        while len(data) < length:
            chunk = self.peer.recv(length-len(data))
            if not chunk: raise EOFError
            data += chunk
        return data

    def read(self):
        try:
            while True:
                first, second = self.exact(2)
                length = second & 127
                if length == 126: length = struct.unpack("!H", self.exact(2))[0]
                elif length == 127: length = struct.unpack("!Q", self.exact(8))[0]
                data = self.exact(length)
                if first & 15 == 1: self.messages.append(json.loads(data))
        except (OSError, EOFError):
            pass

    def send(self, kind, **values):
        data = json.dumps(dict(type=kind, **values)).encode()
        mask = os.urandom(4)
        header = bytes([129, 128+len(data)]) if len(data) < 126 else bytes([129,254])+struct.pack("!H", len(data))
        self.peer.sendall(header+mask+bytes(v ^ mask[i%4] for i,v in enumerate(data)))

    def party(self):
        return next((m["party"] for m in reversed(self.messages) if "party" in m), {})


def wait(fn, timeout=50):
    end=time.monotonic()+timeout
    while time.monotonic()<end:
        try:
            result=fn()
            if result: return result
        except (OSError, ValueError): pass
        time.sleep(.1)
    raise AssertionError("Timed out waiting for real GameNight integration")


def main():
    install=Path(os.environ["LOCALAPPDATA"])/"Ontola.GameNight.Preview/current"
    shelf=Path(os.environ["LOCALAPPDATA"])/"GameNight/local-games.json"
    with socket.socket() as reserve:
        reserve.bind(("127.0.0.1",0));port=reserve.getsockname()[1]
    with tempfile.TemporaryDirectory(prefix="ion-real-host-",ignore_cleanup_errors=True) as tmp:
        probe=Path(tmp)/"probe.json"
        env=dict(os.environ,GAMENIGHT_ADDR=f"127.0.0.1:{port}",GAMENIGHT_LIBRARY=str(shelf),
                 GAMENIGHT_NO_PREWARM="1",GAMENIGHT_NO_LOBBY_WATCH="1",GAMENIGHT_PLAYER_MEMORY=str(Path(tmp)/"players.json"),ION_PROBE_PATH=str(probe),RUST_LOG="info")
        for name in ["GAMENIGHT_WEB","GAMENIGHT_EXIT_WITH_LOBBY","GAMENIGHT_STARTUP_GATE"]: env.pop(name,None)
        log=open(Path(tmp)/"daemon.log","w+",encoding="utf-8")
        daemon=subprocess.Popen([str(install/"bin/gamenight-daemon.exe")],cwd=install,env=env,stdout=log,stderr=log,creationflags=subprocess.CREATE_NO_WINDOW)
        client=None
        try:
            client=wait(lambda:Client(port),10)
            client.send("hello",role="overlay")
            party=wait(client.party)
            local=next(g for g in party["library"] if g["id"]=="ion-rush")
            assert local["title"]=="Ion Rush (Local)"
            client.send("open_overlay")
            wait(lambda: client.party().get("overlay_open"))
            client.send("join_party",name="Local integration pilot",color="#50efcc",library=["ion-rush"])
            wait(lambda: len(client.party().get("players",[]))==1)
            client.send("queue_next",game="ion-rush")
            def ready():
                if not probe.exists(): return False
                state=json.loads(probe.read_text(encoding="utf-8"))
                return state if state.get("phase")=="ready" else False
            state=wait(ready)
            assert not state["running"] and not state["visible"] and state["muted"]
            assert state["racers"][0]["name"]=="Local integration pilot"
            assert state["racers"][0]["face_revision"]==1
            assert state["clock"]==0 and state["countdown"]==3
            print("PASS installed host -> local shelf -> latest immutable PCK -> authenticated native hidden Ready, player identity and decal")
        except BaseException:
            if client:
                print(json.dumps([m for m in client.messages if m.get("type")=="error"]))
                print(json.dumps({k:v for k,v in client.party().items() if k in ["warming","warm_session","active_session","connected_games","playlist"]}))
            print("probe:",probe.read_text(encoding="utf-8")[:900] if probe.exists() else "absent")
            log.flush();log.seek(0);print(log.read())
            raise
        finally:
            if client: client.peer.close()
            daemon.terminate();daemon.wait(timeout=8)
            log.close()
        time.sleep(2) # Game's host-disconnect handler releases the managed wrapper.


if __name__=="__main__": main()
