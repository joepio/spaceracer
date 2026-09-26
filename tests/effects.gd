extends SceneTree
const Race=preload("res://src/race.gd")
const Flight=preload("res://src/flight.gd")
const Ship=preload("res://src/ship.gd")
var failures:=0
var checks:=0
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)
func _initialize()->void:
	call_deferred("run")
func run()->void:
	var warm:=Race.new([{"slot":0}],31)
	var cold:=Race.new([{"slot":0}],31)
	var p:Dictionary=warm.racers[0]
	var n:Dictionary=warm.track.sample(p.distance)
	var rest:=Flight.pose(p,n,0)
	check(rest.basis.y.dot(n.frame.y)>.9999,"Unstarted craft rests level on the road")
	check(absf((rest.origin-n.p).dot(n.frame.y)-.5)<.001,"Unstarted craft rests close to the surface")
	var ship:=Ship.build(Color.CYAN)
	root.add_child(ship)
	Ship.animate_effects(ship,p,0,warm.countdown)
	check(not ship.get_node("EngineLight").visible,"Cold engine emits no dynamic illumination")
	check(not ship.get_node("EngineHeat-1").visible and not ship.get_node("EngineFlare-1").visible,"Cold engines have no heat haze or optical flare")
	check(not ship.get_node("BoostArcs-1").visible,"Electrical discharge is absent from cold engines")
	var idle_color:Color=ship.get_node("EngineCore-1").material_override.albedo_color
	for tick in range(45):
		warm.step(1.0/120,[{"throttle":1.0}])
		cold.step(1.0/120,[{}])
	Ship.animate_effects(ship,p,warm.vfx_clock,warm.countdown)
	var rising:=Flight.pose(p,n,0)
	check(ship.get_node("EngineLight").visible and ship.get_node("EngineLight").light_energy>2.5,"Throttle illuminates the surroundings during countdown")
	check(p.speed==0 and p.distance==0 and warm.clock==0,"Revving during countdown cannot move the racer")
	check(p.engine_power>.99 and p.thrust==1,"Throttle powers the engine before GO")
	check(ship.get_node("EngineCore-1").material_override.albedo_color.r>idle_color.r+.7,"Engine socket becomes white-hot with throttle")
	check(ship.get_node("EngineHalo-1").material_override.get_shader_parameter("power")>.99,"Bloom halo responds before the race starts")
	check(ship.get_node("EngineFlare-1").visible and ship.get_node("EngineHeat-1").visible,"Revving before GO produces nozzle optics and heat")
	check(rising.origin.distance_to(rest.origin)>.1 and rising.basis.y.dot(n.frame.x)<-.015,"Startup raises one side first")
	for tick in range(170):
		warm.step(1.0/120,[{"throttle":1.0}])
		cold.step(1.0/120,[{}])
	var ready:=Flight.pose(p,n,0)
	check(p.startup==1 and ready.basis.y.dot(n.frame.y)>.9999,"Startup settles level at full hover height")
	warm.countdown=0
	cold.countdown=0
	for tick in range(30):
		warm.step(1.0/120,[{"throttle":1.0}])
		cold.step(1.0/120,[{"throttle":1.0}])
	check(is_equal_approx(p.speed,cold.racers[0].speed) and is_equal_approx(p.distance,cold.racers[0].distance),"Pressing throttle at GO has exactly the same acceleration and progress")
	Ship.animate_effects(ship,p,warm.vfx_clock,0)
	var accelerating:float=ship.get_node("ExhaustL").scale.z
	p.acceleration=0
	Ship.animate_effects(ship,p,warm.vfx_clock,0)
	check(accelerating>ship.get_node("ExhaustL").scale.z+3,"Jet length reflects acceleration independently of bright throttle glow")
	for tick in range(8): warm.step(1.0/120,[{"brake":1.0}])
	Ship.animate_controls(ship,p)
	Ship.animate_effects(ship,p,warm.vfx_clock,0)
	check(ship.get_node("Airbrake-1").rotation.x>1,"Brake opens the dorsal airbrakes")
	check(ship.get_node("Reverse-1").visible and ship.get_node("Reverse-1").scale.z>2,"Brake fires forward-facing reverse thrusters")
	check(ship.get_node("Reverse-1").basis.z.z<0,"Reverse jets point opposite the main exhaust")
	check(warm.vfx_clock>warm.clock,"Effects animate throughout the frozen countdown")
	p.engine_power=1.0
	p.thrust=1.0
	p.boost=0.0
	p.on_pad=false
	Ship.animate_effects(ship,p,warm.vfx_clock,0)
	var cruise_energy:float=ship.get_node("EngineLight").light_energy
	check(not ship.get_node("BoostArcs1").visible,"Normal throttle does not produce boost discharges")
	p.boost=1.0
	Ship.animate_effects(ship,p,warm.vfx_clock,0)
	check(ship.get_node("EngineLight").light_energy>cruise_energy*1.5,"Boost increases dynamic exhaust illumination")
	check(ship.get_node("EngineLight").light_energy>cruise_energy*3. and ship.get_node("EngineLight").omni_range>25.,"Boost lights strongly reach nearby road and rivals")
	check(ship.get_node("EngineFlare-1").material_override.get_shader_parameter("boost_amount")==1. and ship.get_node("EngineHeat-1").material_override.get_shader_parameter("boost_amount")==1.,"Boost strengthens flare and heat distortion together")
	check(ship.get_node("BoostArcs-1").visible and ship.get_node("BoostArcs1").visible,"Both boosting nozzles emit branching spikes")
	var frozen_light:float=ship.get_node("EngineLight").light_energy
	var frozen_jet:Vector3=ship.get_node("ExhaustL").scale
	Ship.animate_effects(ship,p,warm.vfx_clock,0)
	check(ship.get_node("EngineLight").light_energy==frozen_light and ship.get_node("ExhaustL").scale==frozen_jet,"Pause freezes irregular light and plume pulses")
	Ship.animate_effects(ship,p,warm.vfx_clock+.071,0)
	check(absf(ship.get_node("EngineLight").light_energy-frozen_light)>.01 and ship.get_node("ExhaustL").scale!=frozen_jet,"Boost power varies over time")
	check(absf(ship.get_node("EngineLight").light_energy-ship.get_node("EngineLightR").light_energy)>.01,"Left and right engines do not pulse in lockstep")
	p.recovery=1.0
	Ship.animate_effects(ship,p,warm.vfx_clock,0)
	check(not ship.get_node("EngineLight").visible and ship.get_node("EngineLight").light_energy==0,"Crashed craft cannot leave an orphan light pool")
	check(not ship.get_node("EngineLightR").visible and ship.get_node("EngineLightR").light_energy==0,"Both nozzle lights turn off on crash")
	check(not ship.get_node("EngineFlare-1").visible and not ship.get_node("EngineHeat1").visible,"Recovery removes flares and distortion from both engines")
	check(not ship.get_node("BoostArcs-1").visible and not ship.get_node("BoostArcs1").visible,"Recovery clears all electrical discharge")
	Ship.set_jet_tint(ship,Color.MAGENTA)
	p.recovery=0
	Ship.animate_effects(ship,p,warm.vfx_clock,0)
	check(ship.get_node("EngineLightR").light_color==ship.get_node("EngineLight").light_color and ship.get_node("EngineLight").light_color.r>.6,"Live player color updates both nozzle lights")
	check(ship.get_node("EngineCore-1").material_override.emission.r>.7,"Live player color updates luminous nozzle core")
	p.boost=0
	p.speed=300.
	p.airborne=false
	ship.set_meta("wake_travel",8.)
	ship.set_meta("wake_time",10.)
	Ship.animate_effects(ship,p,10.,0)
	var wake:MultiMesh=ship.get_node("EngineWake").multimesh
	var before:float=ship.get_meta("wake_travel")
	var before_position:=wake.get_instance_transform(0).origin
	Ship.animate_effects(ship,p,10.001,0)
	var after:float=ship.get_meta("wake_travel")
	var backward_speed:float=(after-before)/.001
	check(backward_speed>p.speed+200.,"Exhaust particles eject backward faster than the craft travels forward")
	# The headless dummy renderer does not retain MultiMesh instance transforms.
	if DisplayServer.get_name()!="headless":
		check((before_position.z-wake.get_instance_transform(0).origin.z)/.001>p.speed+200.,"Rendered particles move at the simulated ejection speed")
	Ship.animate_effects(ship,p,10.001,0)
	check(float(ship.get_meta("wake_travel"))==after,"Particle movement freezes with the effects clock")
	p.speed=450.
	Ship.animate_effects(ship,p,10.001,0)
	check(float(ship.get_meta("wake_travel"))==after,"Changing speed cannot teleport existing wake particles")
	p.airborne=true
	p.air_velocity=Vector3(0,0,470)
	p.boost=1.
	Ship.animate_effects(ship,p,10.002,0)
	check((float(ship.get_meta("wake_travel"))-after)/.001>470.+500.,"Boosted flight exhaust also outruns the vehicle")
	ship.free()
	print("EFFECT_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
