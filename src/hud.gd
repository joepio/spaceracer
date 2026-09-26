extends Control
const World = preload("res://src/world.gd")
var race: RefCounted
var camera:Camera3D
var player_index := 0
var font: Font = ThemeDB.fallback_font
var avatar_key: String = ""
var avatar: Texture2D
var show_map := true
var draw_scale := 1.0
var top_fade:GradientTexture2D
var bottom_fade:GradientTexture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient:=Gradient.new()
	gradient.offsets=PackedFloat32Array([0,.4,1])
	gradient.colors=PackedColorArray([Color(.01,.02,.04,.34),Color(.01,.02,.04,.12),Color(.01,.02,.04,0)])
	top_fade=GradientTexture2D.new()
	top_fade.gradient=gradient
	top_fade.width=1
	top_fade.height=64
	top_fade.fill_from=Vector2.ZERO
	top_fade.fill_to=Vector2(0,1)
	bottom_fade=top_fade.duplicate()
	bottom_fade.fill_from=Vector2(0,1)
	bottom_fade.fill_to=Vector2.ZERO

func label(value: String, at: Vector2, size_value: int = 18, color: Color = Color("e1eef6")) -> void:
	# Rasterize text at output size instead of enlarging small font glyphs.
	draw_set_transform(Vector2.ZERO)
	if race:
		draw_string_outline(font,at*draw_scale,value,HORIZONTAL_ALIGNMENT_LEFT,-1,ceili(size_value*draw_scale),maxi(1,ceili(draw_scale)),Color(.015,.035,.055,.75))
	draw_string(font, at*draw_scale, value, HORIZONTAL_ALIGNMENT_LEFT, -1, ceili(size_value*draw_scale), color)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*draw_scale)

func _draw() -> void:
	if race == null or player_index >= race.racers.size(): return
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
		draw_texture_rect(bottom_fade,Rect2(0,h-64,w,64),false)
		label("WINNER" if p.rank==1 else "FINISHED · %d / %d"%[p.rank,race.racers.size()],Vector2(24,h-38),20,tint)
		label("%s · %.2fs"%[str(p.get("name","Pilot")).left(18),p.time],Vector2(24,h-18),12)
		right_label("%05d"%race.track.seed_value,Vector2(w-24,h-18),10)
		return
	# Soft edge contrast keeps the road open; no floating instrument panels.
	draw_missile_targets(w,h)
	draw_texture_rect(top_fade,Rect2(0,0,w,64),false)
	draw_texture_rect(bottom_fade,Rect2(0,h-64,w,64),false)
	portrait(p,Vector2(28,30),10)
	label(str(p.get("name","Pilot")).left(18),Vector2(47,28),12)
	label("LAP %d / %d"%[mini(p.lap,race.laps),race.laps],Vector2(47,44),10,Color("98aebb"))
	right_label(str(p.rank),Vector2(w-47,40),30)
	right_label("/ %d"%race.racers.size(),Vector2(w-20,38),13,Color("a0b2bf"))
	right_label("%02d:%05.2f"%[int(race.clock)/60,fmod(race.clock,60)],Vector2(w-20,58),11,Color("a0b2bf"))
	right_label(str(roundi(p.speed*3.6)),Vector2(w-60,h-35),32)
	right_label("km/h",Vector2(w-20,h-37),11,Color("a0b2bf"))
	var energy_color:=Color("ff6e84") if p.energy<25 else tint
	if p.energy_fx>0.: energy_color=energy_color.lerp(Color("ffd369"),minf(1.,p.energy_fx*2.))
	draw_rect(Rect2(w-176,h-25,156,3),Color(1,1,1,.13))
	draw_rect(Rect2(w-176,h-25,156*p.energy/100,3),energy_color)
	if p.energy_fx>0.: label("+%d"%roundi(p.energy_gained),Vector2(w-200,h-23-(.8-p.energy_fx)*10.),11,Color(1.,.83,.41,minf(1.,p.energy_fx*3.)))
	for i in range(1,5):
		draw_rect(Rect2(w-176+156*(i*22.0/100),h-25,1,3),Color(.015,.03,.05,.75))
	var status:="Boost on lap 2" if p.lap<2 else "Boost ready"
	if p.boost>0 or p.on_pad: status="Boosting"
	elif p.energy<=22 and p.lap>1: status="Recharge"
	if p.airborne: status="Flight"
	elif p.unload>.45: status="Lifting"
	elif p.drifting: status="Sliding"
	elif p.trim>.2: status="Grip"
	elif p.trim<-.2: status="Low grip"
	if p.warp_time>0.: status="Autopilot"
	if race.can_reset(p):
		centered("Reset" if OS.has_feature("android") else "Y to reset",w,h*.80,12,Color("ffd08a"))
	label(status,Vector2(w-176,h-10),9,energy_color if p.lap>1 else Color("8b9eac"))
	if show_map: minimap(Vector2(61,h-48),44)
	var item:String=race.Weapons.NAMES.get(p.weapon,"")
	if p.warp_time>0.: item="WARP  %.1f"%p.warp_time
	elif p.drone_time>0.: item="SENTRY  %.1f"%p.drone_time
	elif p.jammer_time>0.: item="JAMMER  %.1f"%p.jammer_time
	elif not item.is_empty(): item=("" if OS.has_feature("android") else "X · ")+item
	var item_flash:bool=p.pickup_fx>0. and not p.pickup_energy
	if not item.is_empty(): centered(item,w,h-25,14 if item_flash else 12,Color("d8ffac") if item_flash else Color("97ffdf"))
	if p.evade_notice>0.: centered("EVADED",w,108,12,Color("97ffdf"))
	if p.emp_time>0.: centered("ENGINE OFF  %.1f"%p.emp_time,w,132,13,Color("a6caff"))
	elif p.jam_strength>.03: centered("SIGNAL JAMMED",w,132,12,Color("ffc58a"))
	label("%05d · %s · %s"%[race.track.seed_value,race.track.difficulty.to_upper(),race.track.biome.to_upper()],Vector2(20,h-8),8,Color("98aebb"))
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
	if p.flash>0:
		draw_rect(Rect2(0,0,w,h),Color(1,.2,.25,p.flash*.5),false,3)

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
			draw_line(corner,corner+Vector2(inward.x*length,0.),red,1.8,true)
			draw_line(corner,corner+Vector2(0.,inward.y*length),red,1.8,true)

func right_label(value:String,at:Vector2,size_value:int,color:Color=Color("e1eef6"))->void:
	label(value,at-Vector2(font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value).x,0),size_value,color)

func results(w:float,h:float,tint:Color)->void:
	var left:=24.
	draw_rect(Rect2(12,54,294,72+race.racers.size()*28),Color(.01,.02,.04,.65))
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
