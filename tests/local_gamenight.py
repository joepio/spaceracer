"""Real installed host -> persistent local entry -> managed PowerShell -> native game.

Isolated port/profile memory; only warms the game off-screen. Standard library
plus the GameNight SDK's HostClient (addons/gamenight/fake_host.py).
"""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "addons" / "gamenight"))
from fake_host import HostClient  # noqa: E402


def party(client):
    return next((m["party"] for m in reversed(client.messages) if "party" in m), {})


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
    with tempfile.TemporaryDirectory(prefix="spaceracer-real-host-",ignore_cleanup_errors=True) as tmp:
        probe=Path(tmp)/"probe.json"
        env=dict(os.environ,GAMENIGHT_ADDR=f"127.0.0.1:{port}",GAMENIGHT_LIBRARY=str(shelf),
                 GAMENIGHT_NO_PREWARM="1",GAMENIGHT_NO_LOBBY_WATCH="1",GAMENIGHT_PLAYER_MEMORY=str(Path(tmp)/"players.json"),SPACERACER_PROBE_PATH=str(probe),RUST_LOG="info")
        for name in ["GAMENIGHT_WEB","GAMENIGHT_EXIT_WITH_LOBBY","GAMENIGHT_STARTUP_GATE"]: env.pop(name,None)
        log=open(Path(tmp)/"daemon.log","w+",encoding="utf-8")
        daemon=subprocess.Popen([str(install/"bin/gamenight-daemon.exe")],cwd=install,env=env,stdout=log,stderr=log,creationflags=subprocess.CREATE_NO_WINDOW)
        client=None
        try:
            client=wait(lambda:HostClient(port),10)
            client.send(dict(type="hello",role="overlay"))
            lobby=wait(lambda: party(client))
            local=next(g for g in lobby["library"] if g["id"]=="spaceracer")
            assert local["title"]=="SpaceRacer (Local)"
            client.send(dict(type="open_overlay"))
            wait(lambda: party(client).get("overlay_open"))
            client.send(dict(type="join_party",name="Local integration pilot",color="#50efcc",library=["spaceracer"]))
            wait(lambda: len(party(client).get("players",[]))==1)
            client.send(dict(type="queue_next",game="spaceracer"))
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
                print(json.dumps({k:v for k,v in party(client).items() if k in ["warming","warm_session","active_session","connected_games","playlist"]}))
            print("probe:",probe.read_text(encoding="utf-8")[:900] if probe.exists() else "absent")
            log.flush();log.seek(0);print(log.read())
            raise
        finally:
            if client: client.close()
            daemon.terminate();daemon.wait(timeout=8)
            log.close()
        time.sleep(2) # Game's host-disconnect handler releases the managed wrapper.


if __name__=="__main__": main()
