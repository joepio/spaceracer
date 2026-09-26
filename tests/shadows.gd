extends SceneTree
const Shadows=preload("res://src/shadows.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var lights:Array=[]
	for i in range(12):
		var light:=OmniLight3D.new()
		root.add_child(light);light.position=Vector3((i/2)*2000.+(i%2)*20.,0.,0.)
		light.shadow_enabled=false;lights.append(light)
	var rig:=Shadows.new()
	rig.update(lights,[Vector3.ZERO],0.,true)
	rig.update(lights,[Vector3.ZERO],.25,true)
	check(lights[0].shadow_opacity>.1 and lights[0].shadow_opacity<.9,"New local shadows fade in rather than appearing at full opacity")
	rig.update(lights,[Vector3.ZERO],.5,true)
	check(lights[0].shadow_opacity==1.,"Stable nearby shadows reach full strength")
	rig.update(lights,[Vector3(2000.,0.,0.)],.7,true)
	check(lights[0].shadow_enabled and lights[0].shadow_opacity<1. and lights[0].shadow_opacity>0.,"Outgoing shadow remains allocated during its fade")
	check(lights[2].shadow_enabled and lights[2].shadow_opacity>0. and lights[2].shadow_opacity<1.,"Incoming shadow crossfades with the outgoing light")
	var held:float=lights[0].shadow_opacity
	rig.update(lights,[Vector3(2000.,0.,0.)],.7,true)
	check(lights[0].shadow_opacity==held,"Pause freezes the shadow transition")
	for tick in range(1,120):
		var position:=Vector3((tick%6)*2000.,0.,0.)
		rig.update(lights,[position],.7+tick/60.,true)
		check(lights.filter(func(light):return light.shadow_enabled).size()<=4,"Rapid travel cannot overflow four transition slots per view")
	rig.update(lights,[Vector3.ZERO],3.3,false)
	check(lights.all(func(light):return not light.shadow_enabled),"Disabling local shadows drains every transition slot")
	for light in lights: light.free()
	print("SHADOW_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
