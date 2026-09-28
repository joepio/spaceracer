extends Control
const World = preload("res://src/world.gd")
const Visor = preload("res://src/visor.gd")
var race: RefCounted
var camera:Camera3D
var player_index := 0
var font: Font = ThemeDB.fallback_font
var face:=preload("res://src/pilot_face.gd").new()
var show_map := true
var split_screen := false
var draw_scale := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST

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
	destruction_confirmation(w,h,p)
	if race.over:
		results(w,h,tint)
		return
	if p.finished:
		if p.rank==1: winner_banner(w,h*.34,58)
		draw_line(Vector2(24,h-65),Vector2(224,h-65),Color(tint,.30),1.,true)
		label("WINNER" if p.rank==1 else "FINISHED · %d / %d"%[p.rank,race.racers.size()],Vector2(24,h-38),20,tint)
		label("%s · %.2fs"%[str(p.get("name","Pilot")).left(18),p.time],Vector2(24,h-18),12)
		right_label("%05d"%race.track.seed_value,Vector2(w-24,h-18),10)
		return
	flight_reference(w,h,tint,p)
	draw_missile_targets(w,h)
	draw_rail_guide(w,h,p)
	draw_glide_guide(w,h,p)
	portrait(p,Vector2(22,25),9)
	label(str(p.get("name","Pilot")).left(18),Vector2(40,23),12,Color("adf2fa"))
	label("LAP %d / %d"%[mini(p.lap,race.laps),race.laps],Vector2(40,39),10,Color("79b7c8"))
	right_label(str(p.rank),Vector2(w-43,38),29,Color("b8f2fa"))
	right_label("/ %d"%race.racers.size(),Vector2(w-16,36),12,Color("79b7c8"))
	right_label("%02d:%05.2f"%[int(race.clock)/60,fmod(race.clock,60)],Vector2(w-16,55),10,Color("79b7c8"))
	right_label(str(roundi(p.speed*3.6)),Vector2(w-53,h-57),31,Color("b8f2fa"))
	right_label("km/h",Vector2(w-16,h-58),10,Color("79b7c8"))
	var energy_color:=Color("ff6e84") if p.energy<25 else tint
	if p.energy_fx>0.: energy_color=energy_color.lerp(Color("72ffcf"),minf(1.,p.energy_fx*6.))
	energy_arc(Vector2(w-89,h-96),76.,p.energy,energy_color)
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
	elif p.energy_fx>.05: status="Charging"
	if race.can_reset(p):
		reset_prompt(w,h*.28 if p.checkpoint_missed else h*.80,p.checkpoint_missed)
	elif p.checkpoint_flash>0.:
		label("CHECKPOINT",Vector2(16,60),10,Color(.65,1.,.9,p.checkpoint_flash/.7))
	right_label(status.to_upper(),Vector2(w-16,h-9),8,energy_color if p.lap>1 else Color("79aabb"))
	if show_map: minimap(Vector2(52,h-62),32)
	var slots:=item_slots(p)
	var item_flash:bool=p.pickup_fx>0. and not p.pickup_energy
	if not slots.is_empty():
		var item_y:=h*.80
		if race.can_reset(p) and not p.checkpoint_missed: item_y-=32.
		item_y-=(slots.size()-1)*25.
		for slot in slots:
			var color:=Color("ffd390") if slot.state=="ACTIVE" else (Color("d8ffac") if item_flash else Color("97ffdf"))
			if slot.state=="READY" and not OS.has_feature("android"):
				var width:=font.get_string_size(slot.text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
				var left:=(w-width-28.)*.5
				button_glyph("X",Vector2(left+10.,item_y-4.5),Color("8bcfff"))
				label(slot.text,Vector2(left+28.,item_y),12,color)
			else:
				centered(slot.text,w,item_y,12,color)
			item_y+=25.
	if p.evade_notice>0.: right_label("EVADED",Vector2(w-16,94),12,Color("97ffdf"))
	if p.emp_time>0.: right_label("ENGINE OFF  %.1f"%p.emp_time,Vector2(w-16,112),13,Color("a6caff"))
	label("%05d · %s · %s"%[race.track.seed_value,race.track.difficulty.to_upper(),race.track.biome.to_upper()],Vector2(16,h-9),8,Color("79aabb"))
	var jump:Dictionary=race.track.jump_at(p.distance,170.)
	if not jump.is_empty() and not p.airborne and p.recovery==0 and race.countdown==0 and fposmod(p.distance,race.track.length)<jump.takeoff:
		right_label("JUMP %dm · %s"%[roundi(jump.takeoff-fposmod(p.distance,race.track.length)),"NOSE DOWN" if jump.get("turbo",false) else "KEEP SPEED"],Vector2(w-16,76),12,Color("ffc46b"))
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

static func item_slots(p:Dictionary)->Array[Dictionary]:
	var slots:Array[Dictionary]=[]
	var active:=""
	if p.warp_time>0.: active="WARP  %.1fs"%p.warp_time
	elif p.drone_time>0.: active="SENTRY  %.1fs"%p.drone_time
	if not active.is_empty(): slots.append({"state":"ACTIVE","text":active})
	var stored:String=preload("res://src/weapons.gd").NAMES.get(p.weapon,"")
	if not stored.is_empty():
		var prefix:="STORED · " if not active.is_empty() else ""
		if p.weapon=="bomb" and not p.airborne and active.is_empty(): stored+=" / AIR ONLY"
		slots.append({"state":"STORED" if not active.is_empty() else "READY","text":prefix+stored.to_upper()})
	return slots

func destruction_confirmation(w:float,h:float,p:Dictionary)->void:
	var row:=0
	for notice in p.get("destruction_notices",[]):
		var alpha:=.9*smoothstep(0.,.14,float(notice.life))
		centered("DESTROYED %s"%str(notice.name).left(24).to_upper(),w,h*.29+row*24.,19,Color(.75,1.,.85,alpha))
		row+=1

func winner_banner(w:float,y:float,font_size:int)->void:
	centered("YOU WIN",w,y,font_size,Color(1.,.93,.66,.94))
	var half:=font.get_string_size("YOU WIN",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*.5+20.
	for side in [-1.,1.]:
		var x:float=w*.5+side*half
		draw_polyline(PackedVector2Array([Vector2(x-side*12,y-font_size*.75),Vector2(x,y-font_size*.75),Vector2(x,y+9),Vector2(x-side*12,y+9)]),Color(.6,.91,1.,.5),1.5,true)

func flight_reference(w:float,h:float,tint:Color,p:Dictionary)->void:
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

func draw_rail_guide(w:float,h:float,p:Dictionary)->void:
	var rail=preload("res://src/railgun.gd")
	if not is_instance_valid(camera) or not p.get("rail_armed",false) or not rail.ready(race,p): return
	var aim:Dictionary=rail.view_context(race,player_index,camera)
	if aim.is_empty(): return
	var dimensions:=Vector2(w,h)
	var scale_value:=dimensions/Vector2(camera.get_viewport().size)
	var points:=PackedVector2Array()
	for i in range(65):
		var angle:=TAU*i/64.
		var point:Vector2=(aim.screen+Vector2(cos(angle),sin(angle))*aim.pixels)*scale_value
		points.append(Visor.project_marker(point,dimensions,Visor.SPLIT_CURVATURE if split_screen else Visor.CURVATURE))
	var target:int=p.get("rail_preview",{}).get("target",-1)
	var color:=Color(.55,1.,.73,.85) if target>=0 else Color(.55,.94,1.,.45)
	draw_polyline(points,color,1.3,true)
	draw_weapon_target(target,dimensions,color)

func glide_screen(point:Vector3,dimensions:Vector2)->Vector2:
	var screen:=camera.unproject_position(point)/Vector2(camera.get_viewport().size)*dimensions
	return Visor.project_marker(screen,dimensions,Visor.SPLIT_CURVATURE if split_screen else Visor.CURVATURE)

func draw_glide_guide(w:float,h:float,p:Dictionary)->void:
	if not is_instance_valid(camera) or not p.get("bomb_armed",false): return
	var aim:Dictionary=p.get("bomb_preview",{})
	if aim.is_empty(): return
	var dimensions:=Vector2(w,h)
	var color:=Color(.55,1.,.73,.85) if aim.target>=0 else Color(1.,.77,.35,.7)
	var points:PackedVector3Array=aim.points
	for i in range(2,points.size()-1,2):
		if camera.is_position_behind(points[i]) or camera.is_position_behind(points[i+1]): continue
		draw_line(glide_screen(points[i],dimensions),glide_screen(points[i+1],dimensions),Color(color,.35),1.,true)
	draw_weapon_target(aim.target,dimensions,color)
	if aim.target>=0 and not camera.is_position_behind(aim.target_position):
		# Live interception dot also works over open air, without a ground impact.
		draw_arc(glide_screen(aim.target_position,dimensions),7.,0.,TAU,24,color,1.3,true)
	if not aim.landed or camera.is_position_behind(aim.position): return
	var normal:Vector3=aim.normal
	var right:=normal.cross(Vector3.FORWARD).normalized()
	if right.length_squared()<.1: right=Vector3.RIGHT
	var forward:=normal.cross(right).normalized()
	var center:Vector3=aim.position+normal*1.5
	for i in range(64):
		if i%8==7: continue
		var a:=TAU*i/64.;var b:=TAU*(i+1)/64.
		var from:Vector3=center+(right*cos(a)+forward*sin(a))*race.Weapons.DiveBomb.AIM_RADIUS
		var to:Vector3=center+(right*cos(b)+forward*sin(b))*race.Weapons.DiveBomb.AIM_RADIUS
		if camera.is_position_behind(from) or camera.is_position_behind(to): continue
		draw_line(glide_screen(from,dimensions),glide_screen(to,dimensions),color,1.6,true)
	var at:=glide_screen(center,dimensions)
	draw_arc(at,4.,0.,TAU,20,color,1.2,true)

func draw_weapon_target(index:int,dimensions:Vector2,color:Color)->void:
	if index<0 or index>=race.racers.size() or not race.weapons.available(race.racers[index]): return
	var target:Vector3=race.weapons.pose(race,race.racers[index]).origin
	if camera.is_position_behind(target): return
	var screen:=glide_screen(target,dimensions)
	for side in [-1.,1.]:
		draw_polyline(PackedVector2Array([screen+Vector2(side*10,-13),screen+Vector2(side*17,-13),screen+Vector2(side*17,13),screen+Vector2(side*10,13)]),color,1.8,true)

func draw_missile_targets(w:float,h:float)->void:
	if not is_instance_valid(camera) or int(race.vfx_clock*4.)%2!=0: return
	var marked:={}
	for missile in race.weapons.missiles:
		if missile.target<0 or missile.evaded or marked.has(missile.target): continue
		var eta:float=race.Weapons.missile_eta(race,missile)
		if not is_finite(eta) or race.Weapons.laser_strength(race,missile)>0.: continue
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
			draw_line(Visor.project_marker(corner,dimensions,Visor.SPLIT_CURVATURE if split_screen else Visor.CURVATURE),Visor.project_marker(corner+Vector2(inward.x*length,0.),dimensions,Visor.SPLIT_CURVATURE if split_screen else Visor.CURVATURE),red,1.8,true)
			draw_line(Visor.project_marker(corner,dimensions,Visor.SPLIT_CURVATURE if split_screen else Visor.CURVATURE),Visor.project_marker(corner+Vector2(0.,inward.y*length),dimensions,Visor.SPLIT_CURVATURE if split_screen else Visor.CURVATURE),red,1.8,true)

func right_label(value:String,at:Vector2,size_value:int,color:Color=Color("e1eef6"))->void:
	label(value,at-Vector2(font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value).x,0),size_value,color)

func results(w:float,h:float,tint:Color)->void:
	if race.racers[player_index].finished and race.racers[player_index].rank==1: winner_banner(w,43.,38)
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

func reset_prompt(w:float,y:float,missed:bool)->void:
	var color:=Color("ffd08a")
	if missed:
		# Keep the road apex clear while making a lost checkpoint unmistakable.
		# Race time freezes the gentle brightness pulse when the game is paused.
		var pulse:=.88+.12*sin(race.vfx_clock*TAU*1.2)
		centered("CHECKPOINT MISSED",w,y,26,Color(1.,.62,.28,pulse))
		y+=32.
	if OS.has_feature("android"):
		centered("TAP RESET" if missed else "Reset",w,y,16 if missed else 12,color)
		return
	var action:="TO RETURN" if missed else "TO RESET"
	var text_size:=16 if missed else 12
	var scale_value:=float(text_size)/12.
	var action_width:=font.get_string_size(action,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size).x
	var left:=(w-28.*scale_value-action_width)*.5
	var center:=Vector2(left+10.*scale_value,y-4.5*scale_value)
	button_glyph("Y",center,Color("ffdb64"),text_size)
	label(action,Vector2(left+28.*scale_value,y),text_size,color)

func button_glyph(glyph:String,center:Vector2,color:Color,text_size:int=12)->void:
	var scale_value:=float(text_size)/12.
	draw_circle(center,10.*scale_value,Color(color,.12))
	draw_arc(center,10.*scale_value,0.,TAU,48,color,1.5*scale_value,true)
	var width:=font.get_string_size(glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size).x
	label(glyph,Vector2(center.x-width*.5,center.y+4.5*scale_value),text_size,color)

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
	face.update(p)
	if face.artwork:
		var factor:=radius/12.
		draw_texture_rect(face.artwork,Rect2(center-face.origin*factor,face.artwork.get_size()*factor),false)
	else:
		draw_circle(center+Vector2(-4,-2),1.5,Color("1a2033"))
		draw_circle(center+Vector2(4,-2),1.5,Color("1a2033"))
		draw_line(center+Vector2(-3,5),center+Vector2(4,5),Color("1a2033"),1)
