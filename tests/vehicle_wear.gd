extends SceneTree
const Ship=preload("res://src/ship.gd")
const Race=preload("res://src/race.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var ship:=Ship.build(Color("bf3334"));root.add_child(ship)
	var other:=Ship.build(Color("2f94bf"));root.add_child(other)
	var race:=Race.new([{"slot":0}],31);var p:Dictionary=race.racers[0]
	var smoke:MultiMeshInstance3D=ship.get_meta("damage_smoke")
	for energy in [100.,55.,12.,1.,85.,100.]:
		p.energy=energy;Ship.Wear.update(ship,p,4.)
		for material in ship.get_meta("damage_materials"):
			check(is_equal_approx(float(material.get_shader_parameter("damage")),1.-energy/100.),"All painted panels follow energy, including recharging")
		check(smoke.visible==(energy<Ship.Wear.SMOKE_ENERGY),"Only critical energy produces smoke")
	p.energy=5.;Ship.Wear.update(ship,p,4.)
	var before:=smoke.multimesh.get_instance_transform(3)
	Ship.Wear.update(ship,p,4.)
	check(before==smoke.multimesh.get_instance_transform(3),"Smoke freezes when race time is paused")
	check(smoke.multimesh.instance_count==12,"Critical smoke has a fixed twelve-quad budget")
	p.crashed=true;Ship.Wear.update(ship,p,5.);check(not smoke.visible,"Crash VFX take over from running-engine smoke")
	p.crashed=false;p.recovery=1.;Ship.Wear.update(ship,p,5.);check(not smoke.visible,"Recovery suppresses critical smoke")
	check(float(other.get_meta("visual_damage"))==-1.,"Another player's paint is not modified")
	check(ship.get_meta("paint_materials").size()==3,"Team paint and pilot decals keep their existing material mapping")
	print("VEHICLE_WEAR_TESTS ",checks," checks, ",failures," failures")
	ship.queue_free();other.queue_free();await process_frame;quit(1 if failures else 0)
