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
	p.boost=1.0
	Ship.animate_effects(ship,p,warm.vfx_clock,0)
	check(ship.get_node("EngineLight").light_energy>cruise_energy*1.5,"Boost increases dynamic exhaust illumination")
	p.recovery=1.0
	Ship.animate_effects(ship,p,warm.vfx_clock,0)
	check(not ship.get_node("EngineLight").visible and ship.get_node("EngineLight").light_energy==0,"Crashed craft cannot leave an orphan light pool")
	check(not ship.get_node("EngineLightR").visible and ship.get_node("EngineLightR").light_energy==0,"Both nozzle lights turn off on crash")
	Ship.set_jet_tint(ship,Color.MAGENTA)
	p.recovery=0
	Ship.animate_effects(ship,p,warm.vfx_clock,0)
	check(ship.get_node("EngineLightR").light_color==ship.get_node("EngineLight").light_color and ship.get_node("EngineLight").light_color.r>.6,"Live player color updates both nozzle lights")
	check(ship.get_node("EngineCore-1").material_override.emission.r>.7,"Live player color updates luminous nozzle core")
	ship.free()
	print("EFFECT_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
