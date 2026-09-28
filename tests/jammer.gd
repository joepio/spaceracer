extends SceneTree
const Race=preload("res://src/race.gd")
const Cheats=preload("res://src/dev_cheats.gd")
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok: failures+=1;push_error(message)
func _initialize()->void:
	var race:=Race.new([{"slot":0},{"slot":1}],31)
	check(not race.Weapons.NAMES.has("jammer") and not Cheats.KEYS.has(KEY_J),"Jammer is absent from inventory and cheats")
	for i in range(6000): check(race.weapons.choose(3,6)!="jammer","No jammer drops")
	var p:Dictionary=race.racers[1]
	for sample in [[2.2,1.],[1.95,.5],[1.7,0.],[1.,0.],[0.,0.]]:
		p.emp_time=sample[0]
		check(absf(race.Weapons.emp_glitch(p)-sample[1])<.001,"EMP glitch fades completely within 500 ms")
	print("EMP_GLITCH_TESTS failures=",failures);quit(1 if failures else 0)
