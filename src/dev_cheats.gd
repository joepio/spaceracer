extends RefCounted
## Explicit opt-in only. F8 returns the letter keys to ordinary driving.
const KEYS:={KEY_D:"bomb",KEY_M:"missile",KEY_W:"warp",KEY_S:"drone",KEY_E:"emp",KEY_G:"railgun"}
const LEGEND:="DEV GIVE / D bomb  M missile  W warp  S sentry  E EMP  G railgun / F8 off"
var enabled:=false

func grant(race:RefCounted,key:int)->int:
	if not enabled or race==null or race.over or not KEYS.has(key): return 0
	var count:=0
	for i in range(race.racers.size()):
		var p:Dictionary=race.racers[i]
		if not race.weapons.available(p): continue
		p.weapon=KEYS[key];p.weapon_acquired=race.clock
		count+=1
	return count
