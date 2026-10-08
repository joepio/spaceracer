# Third-party notices

`addons/gamenight` is the MIT-licensed Godot transport vendored from
[GameNight](https://github.com/ontola/gamenight), `sdk/godot/addons/gamenight`,
kept identical to GameNight `main` by `sdk/godot/sync.py`; CI checks it.
Its license is `GameNight-LICENSE.txt`. `src/bridge.gd` implements SpaceRacer’s
host lifecycle and controller adapter on top of that transport.

The portable development package uses Godot 4.5.2, distributed under the MIT
license in `Godot-LICENSE.txt`. Its bundled dependency notices are reproduced
in `Godot-COPYRIGHT.txt`. No runtime download or external game assets are needed.
