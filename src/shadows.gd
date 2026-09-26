extends RefCounted
## Long, blended sun cascades and bounded, gradual local-shadow handoffs.
var selection_clock:=-1.
var frame_clock:=-1.
var selected:Array[Light3D]=[]

static func configure_sun(sun:DirectionalLight3D,quality:float,views:int,renderer:String)->void:
	sun.shadow_enabled=renderer in ["forward_plus","mobile"]
	var mobile:=renderer=="mobile"
	var detailed:=not mobile and quality>=.8
	var four_splits:=detailed and views==1
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if four_splits else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance=(650. if views==1 else 520.) if mobile else ((1400. if views==1 else 1100.) if detailed else 800.)
	sun.directional_shadow_blend_splits=true
	sun.directional_shadow_split_1=.06 if four_splits else (.12 if detailed else .2)
	sun.directional_shadow_split_2=.18
	sun.directional_shadow_split_3=.46
	# Hundreds of metres of fade instead of a ~0.2 second band at boost speed.
	sun.directional_shadow_fade_start=.55
	sun.directional_shadow_pancake_size=0.

func update(lights:Array,positions:Array[Vector3],clock:float,enabled:bool)->void:
	var dt:=maxf(0.,clock-frame_clock) if frame_clock>=0. else 0.
	frame_clock=clock
	if selection_clock<0. or clock-selection_clock>=.15:
		selection_clock=clock
		selected.clear()
		if enabled:
			for position in positions:
				var candidates:Array=lights.duplicate()
				candidates.sort_custom(func(a:Light3D,b:Light3D):
					return a.global_position.distance_to(position)-(45. if a.shadow_enabled else 0.) < b.global_position.distance_to(position)-(45. if b.shadow_enabled else 0.))
				for light:Light3D in candidates.slice(0,2):
					if light.global_position.distance_to(position)<380. and not selected.has(light): selected.append(light)
	if not enabled: selected.clear()
	# At most two active plus two fading slots per view. Rapid travel cannot
	# accumulate unbounded shadow maps; new lights wait for a free fade slot.
	var capacity:=mini(16,maxi(4,positions.size()*4))
	var active:=0
	for light:Light3D in lights:
		if light.shadow_enabled: active+=1
	for light in selected:
		if not light.shadow_enabled and active<capacity:
			light.shadow_opacity=0.
			light.shadow_enabled=true
			active+=1
	for light:Light3D in lights:
		if not light.shadow_enabled: continue
		light.shadow_opacity=move_toward(light.shadow_opacity,1. if selected.has(light) else 0.,dt*2.)
		if light.shadow_opacity<=0. and not selected.has(light): light.shadow_enabled=false
