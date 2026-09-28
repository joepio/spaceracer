extends SceneTree
const Race=preload("res://src/race.gd")
const Cheats=preload("res://src/dev_cheats.gd")
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok: failures+=1;push_error(message)
func fresh()->RefCounted:
	var race:=Race.new([{"slot":0},{"slot":1},{"slot":2,"bot":true}],31,3,"easy","city")
	race.countdown=0.;race.clock=5.
	for i in range(3): race.racers[i].distance=400.-i*35.
	return race
func _initialize()->void: call_deferred("run")
func run()->void:
	var dev:=Cheats.new();var race:=fresh()
	check(dev.grant(race,KEY_D)==0 and race.weapons.bombs.is_empty(),"Cheats start disabled")
	dev.enabled=true
	check(dev.grant(race,KEY_D)==3 and race.racers.all(func(p):return p.weapon=="bomb"),"D equips all human and AI racers")
	check(race.weapons.bombs.is_empty(),"Grant never drops a bomb")
	check(not race.racers[0].airborne,"Cheat does not teleport or launch the car")
	for key in dev.KEYS:
		race=fresh();race.racers[0].drone_time=3.;race.racers[0].weapon_guard=.7
		check(dev.grant(race,key)==3 and race.racers.all(func(p):return p.weapon==dev.KEYS[key]),"Letter equips matching item")
		check(race.weapons.missiles.is_empty() and race.weapons.pulses.is_empty() and race.weapons.bombs.is_empty() and race.weapons.rail_shots.is_empty(),"Equipping spawns no attack")
		check(race.racers[0].drone_time==3. and race.racers[0].weapon_guard==.7 and race.racers[1].warp_time==0.,"Existing effects and protections remain unchanged")
	race=fresh();race.racers[1].crashed=true;race.racers[2].finished=true
	check(dev.grant(race,KEY_D)==1,"Crashed and finished racers are left alone")
	check(dev.grant(race,KEY_A)==0,"Unmapped letters retain normal behavior")
	race=fresh();race.racers[0].weapon="bomb"
	check(not race.weapons.activate(race,0),"Normal gameplay still requires flight")
	print("DEV_CHEAT_TESTS failures=",failures);quit(1 if failures else 0)
