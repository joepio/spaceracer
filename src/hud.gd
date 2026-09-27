extends Control
const World = preload("res://src/world.gd")
const Visor = preload("res://src/visor.gd")
var race: RefCounted
var camera:Camera3D
var player_index := 0
var font: Font = ThemeDB.fallback_font
var avatar_key: String = ""
var avatar: Texture2D
var show_map := true
var draw_scale := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func label(value: String, at: Vector2, size_value: int = 18, color: Color = Color("e1eef6")) -> void:
	# Rasterize text at output size instead of enlarging small font glyphs.
	draw_set_transform(Vector2.ZERO)
	color=color.lerp(Color(.42,.88,.96,color.a),.16)
	draw_string(font, at*draw_scale, value, HORIZONTAL_ALIGNMENT_LEFT, -1, ceili(size_value*draw_scale), color)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*draw_scale)

func _draw() -> void:
	if race == null or player_index >= race.racers.size() or size.x<1. or size.y<1.: return
	var p: Dictionary = race.racers[player_index]
	draw_scale=minf(size.x/800,size.y/450)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*draw_scale)
	var w:=size.x/draw_scale
	var h:=size.y/draw_scale
	var tint:=World.color_for(p)
	if race.over:
		results(w,h,tint)
		return
	if p.finished:
		draw_line(Vector2(24,h-65),Vector2(224,h-65),Color(tint,.30),1.,true)
		label("WINNER" if p.rank==1 else "FINISHED · %d / %d"%[p.rank,race.racers.size()],Vector2(24,h-38),20,tint)
		label("%s · %.2fs"%[str(p.get("name","Pilot")).left(18),p.time],Vector2(24,h-18),12)
		right_label("%05d"%race.track.seed_value,Vector2(w-24,h-18),10)
		return
	visor_frame(w,h,tint,p)
	draw_missile_targets(w,h)
	portrait(p,Vector2(44,43),9)
	label(str(p.get("name","Pilot")).left(18),Vector2(63,40),12,Color("adf2fa"))
	label("LAP %d / %d"%[mini(p.lap,race.laps),race.laps],Vector2(63,56),10,Color("79b7c8"))
	right_label(str(p.rank),Vector2(w-66,49),29,Color("b8f2fa"))
	right_label("/ %d"%race.racers.size(),Vector2(w-38,47),12,Color("79b7c8"))
	right_label("%02d:%05.2f"%[int(race.clock)/60,fmod(race.clock,60)],Vector2(w-38,68),10,Color("79b7c8"))
	right_label(str(roundi(p.speed*3.6)),Vector2(w-73,h-64),31,Color("b8f2fa"))
	right_label("km/h",Vector2(w-41,h-65),10,Color("79b7c8"))
	var energy_color:=Color("ff6e84") if p.energy<25 else tint
	if p.energy_fx>0.: energy_color=energy_color.lerp(Color("ffd369"),minf(1.,p.energy_fx*2.))
	energy_arc(Vector2(w-113,h-104),81.,p.energy,energy_color)
	if p.energy_fx>0.: label("+%d"%roundi(p.energy_gained),Vector2(w-209,h-44-(.8-p.energy_fx)*10.),11,Color(1.,.83,.41,minf(1.,p.energy_fx*3.)))
	var status:="Boost on lap 2" if p.lap<2 else "Boost ready"
	if p.boost>0 or p.on_pad: status="Boosting"
	elif p.slipstream>.15: status="Slipstream"
	elif p.energy<=22 and p.lap>1: status="Recharge"
	if p.airborne: status="Flight"
	elif p.unload>.45: status="Lifting"
	elif p.drifting: status="Sliding"
	elif p.trim>.2: status="Grip"
	elif p.trim<-.2: status="Low grip"
	if p.warp_time>0.: status="Autopilot"
	if race.can_reset(p):
		centered("Reset" if OS.has_feature("android") else "Y to reset",w,h*.80,12,Color("ffd08a"))
	label(status.to_upper(),Vector2(w-172,h-16),8,energy_color if p.lap>1 else Color("79aabb"))
	if show_map: minimap(Vector2(76,h-74),38)
	var item:String=race.Weapons.NAMES.get(p.weapon,"")
	if p.warp_time>0.: item="WARP  %.1f"%p.warp_time
	elif p.drone_time>0.: item="SENTRY  %.1f"%p.drone_time
	elif p.jammer_time>0.: item="JAMMER  %.1f"%p.jammer_time
	elif not item.is_empty(): item=("" if OS.has_feature("android") else "X · ")+item
	var item_flash:bool=p.pickup_fx>0. and not p.pickup_energy
	if not item.is_empty():
		draw_polyline(PackedVector2Array([Vector2(w*.5-94,h-47),Vector2(w*.5-94,h-30),Vector2(w*.5-85,h-21),Vector2(w*.5+85,h-21),Vector2(w*.5+94,h-30),Vector2(w*.5+94,h-47)]),Color(.3,.85,.88,.35),1.,true)
		centered(item,w,h-32,14 if item_flash else 12,Color("d8ffac") if item_flash else Color("97ffdf"))
	if p.evade_notice>0.: centered("EVADED",w,108,12,Color("97ffdf"))
	if p.emp_time>0.: centered("ENGINE OFF  %.1f"%p.emp_time,w,132,13,Color("a6caff"))
	elif p.jam_strength>.03: centered("SIGNAL JAMMED",w,132,12,Color("ffc58a"))
	label("%05d · %s · %s"%[race.track.seed_value,race.track.difficulty.to_upper(),race.track.biome.to_upper()],Vector2(35,h-15),8,Color("79aabb"))
	var jump:Dictionary=race.track.jump_at(p.distance,170.)
	if not jump.is_empty() and not p.airborne and p.recovery==0 and race.countdown==0 and fposmod(p.distance,race.track.length)<jump.takeoff:
		centered("JUMP %dm · KEEP SPEED"%roundi(jump.takeoff-fposmod(p.distance,race.track.length)),w,83,12,Color("ffc46b"))
	if race.countdown>0:
		centered(str(ceili(race.countdown)),w,h*.46,52)
	elif race.clock<.7:
		centered("Go",w,h*.42,40,tint)
	elif p.recovery>0:
		centered("Respawning" if p.crashed else "Recovering",w,h*.39,20,Color("ff9cad"))
	elif p.finished:
		centered("Finished  \u00b7  %d / %d"%[p.rank,race.racers.size()],w,h*.36,22)
	elif p.lap==2 and race.clock-p.lap_start<2:
		centered("Boost unlocked",w,84,13,tint)

func visor_frame(w:float,h:float,tint:Color,p:Dictionary)->void:
	var ink:=Color(.25,.73,.85,.34)
	# Open, contoured brackets suggest the inner visor rim without a cockpit mask.
	for side in [-1.,1.]:
		var edge:float=w*.5+side*(w*.5-18.)
		var inward:float=-side
		draw_polyline(PackedVector2Array([Vector2(edge+inward*177,16),Vector2(edge+inward*20,16),Vector2(edge,37),Vector2(edge,97),Vector2(edge+inward*8,112)]),ink,1.1,true)
		draw_polyline(PackedVector2Array([Vector2(edge,h-117),Vector2(edge,h-45),Vector2(edge+inward*28,h-18),Vector2(edge+inward*183,h-18)]),Color(ink,.20),1.,true)
		for tick in range(7):
			var y:=h*.5-32.+tick*10.
			draw_line(Vector2(edge+inward*8,y),Vector2(edge+inward*(15. if tick%3==0 else 11.),y),Color(ink,.24),1.,true)
	# A small roll reference belongs to the flight mode, not the racing apex.
	if p.airborne and not p.crashed:
		var center:=Vector2(w*.5,h*.43)
		var slope:=clampf(p.air_roll,-.7,.7)
		for side in [-1.,1.]:
			var a:=Vector2(side*13,0).rotated(slope)
			var b:=Vector2(side*31,0).rotated(slope)
			draw_line(center+a,center+b,Color(tint,.48),1.,true)
		draw_arc(center,4.,0.,TAU,16,Color(tint,.45),1.,true)

func energy_arc(center:Vector2,radius:float,energy:float,color:Color)->void:
	for i in range(24):
		var a:=lerpf(PI*.16,PI*.84,float(i)/24.)
		var b:=lerpf(PI*.16,PI*.84,float(i+1)/24.)-.009
		var filled:=float(23-i)<energy*.24
		draw_arc(center,radius,a,b,4,Color(color,.86) if filled else Color(.3,.65,.73,.16),2.5,true)
	draw_arc(center,radius+5,PI*.16,PI*.84,40,Color(.3,.75,.83,.24),.8,true)

func draw_missile_targets(w:float,h:float)->void:
	if not is_instance_valid(camera) or int(race.vfx_clock*4.)%2!=0: return
	var marked:={}
	for missile in race.weapons.missiles:
		if missile.evaded or marked.has(missile.target): continue
		var eta:float=race.Weapons.missile_eta(race,missile)
		if not is_finite(eta) or eta<2.: continue
		marked[missile.target]=true
		var pose:Transform3D=race.Weapons.pose(race,race.racers[missile.target])
		var low:=Vector2(INF,INF)
		var high:=Vector2(-INF,-INF)
		var behind:=false
		for x in [-5.,5.]:
			for y in [-.7,2.]:
				for z in [-4.5,5.]:
					var point:=pose*Vector3(x,y,z)
					if camera.is_position_behind(point): behind=true;continue
					var screen:=camera.unproject_position(point)/Vector2(camera.get_viewport().size)*Vector2(w,h)
					low=low.min(screen);high=high.max(screen)
		if behind or high.x<0. or low.x>w or high.y<0. or low.y>h: continue
		low-=Vector2.ONE*4.;high+=Vector2.ONE*4.
		var length:=clampf(minf(high.x-low.x,high.y-low.y)*.24,5.,15.)
		var red:=Color(1.,.12,.2,.95)
		for corner in [low,Vector2(high.x,low.y),high,Vector2(low.x,high.y)]:
			var inward:=Vector2(1. if corner.x==low.x else -1.,1. if corner.y==low.y else -1.)
			var dimensions:=Vector2(w,h)
			draw_line(Visor.project_marker(corner,dimensions),Visor.project_marker(corner+Vector2(inward.x*length,0.),dimensions),red,1.8,true)
			draw_line(Visor.project_marker(corner,dimensions),Visor.project_marker(corner+Vector2(0.,inward.y*length),dimensions),red,1.8,true)

func right_label(value:String,at:Vector2,size_value:int,color:Color=Color("e1eef6"))->void:
	label(value,at-Vector2(font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value).x,0),size_value,color)

func results(w:float,h:float,tint:Color)->void:
	var left:=24.
	var bottom:float=126.+race.racers.size()*28.
	draw_polyline(PackedVector2Array([Vector2(12,95),Vector2(12,65),Vector2(24,53),Vector2(306,53),Vector2(306,bottom-12),Vector2(294,bottom),Vector2(12,bottom)]),Color(.25,.73,.85,.35),1.,true)
	label("Race complete",Vector2(left,82),22)
	var row:=112.
	for item in race.standings():
		label(str(item.rank),Vector2(left,row),13,World.color_for(item))
		label(str(item.get("name","Pilot")).left(19),Vector2(left+28,row),13)
		right_label("%.2fs"%item.time if item.finished else "DNF",Vector2(left+270,row),12,Color("a0b2bf"))
		draw_line(Vector2(left,row+10),Vector2(left+270,row+10),Color(1,1,1,.08),1)
		row+=28
	label("Next circuit shortly",Vector2(left,row+12),10,tint)
	label("%05d · %s · %s"%[race.track.seed_value,race.track.difficulty.to_upper(),race.track.biome.to_upper()],Vector2(24,h-18),10,tint)

func centered(value: String,w:float,y:float,size_value:int,color:Color=Color("dbe7f1"))->void:
	label(value,Vector2((w-font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value).x)/2,y),size_value,color)

func minimap(center:Vector2,radius:float)->void:
	draw_arc(center,radius+8,PI*.15,PI*1.86,48,Color(.3,.72,.85,.30),1.,true)
	for i in range(12):
		var direction:=Vector2.from_angle(i*TAU/12.)
		draw_line(center+direction*(radius+8),center+direction*(radius+11),Color(.3,.72,.85,.32),1.,true)
	var points := PackedVector2Array()
	for i in range(0,race.track.nodes.size(),4):
		var p:Vector3=race.track.nodes[i].p
		points.append(center+Vector2(p.x,p.z)*radius/1800)
	points.append(points[0])
	draw_polyline(points,Color(.7,.85,.95,.25),1.3,true)
	for p in race.racers:
		var n:Dictionary=race.track.sample(p.distance)
		draw_circle(center+Vector2(p.air_position.x if p.airborne else n.p.x,p.air_position.z if p.airborne else n.p.z)*radius/1800,2.8 if p==race.racers[player_index] else 1.6,World.color_for(p))

func portrait(p:Dictionary,center:Vector2,radius:float)->void:
	draw_circle(center,radius+2,World.color_for(p))
	draw_circle(center,radius,Color.from_string(str(p.get("skin_color","")),Color("f5e9be")))
	var payload:Variant=p.get("avatar",{})
	var key:=JSON.stringify(payload)
	if key!=avatar_key:
		avatar_key=key
		avatar=null
		if payload is String:
			var parser:=JSON.new()
			payload=parser.data if parser.parse(payload)==OK else null
		if payload is Dictionary:
			var aw:=int(payload.get("w",0))
			var ah:=int(payload.get("h",0))
			var pixels:Variant=payload.get("px",[])
			if aw in [16,32,48] and ah in [16,32,48] and pixels is Array and pixels.size()==aw*ah:
				var image:=Image.create(aw,ah,false,Image.FORMAT_RGBA8)
				for i in range(pixels.size()):
					if pixels[i] is String:
						image.set_pixel(i%aw,i/aw,Color.from_string(pixels[i],Color.TRANSPARENT))
				avatar=ImageTexture.create_from_image(image)
	if avatar:
		var factor:=radius/12
		var origin:=Vector2(24,28)
		if avatar.get_width()==32: origin=Vector2(10,13)
		elif avatar.get_width()==16: origin=Vector2(2,5)
		draw_texture_rect(avatar,Rect2(center-origin*factor,avatar.get_size()*factor),false)
	else:
		draw_circle(center+Vector2(-4,-2),1.5,Color("1a2033"))
		draw_circle(center+Vector2(4,-2),1.5,Color("1a2033"))
		draw_line(center+Vector2(-3,5),center+Vector2(4,5),Color("1a2033"),1)
