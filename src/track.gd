extends RefCounted
const Components=preload("res://src/track_components.gd")
const HazardCollision=preload("res://src/obstacles.gd")
const Profiles=preload("res://src/track_profiles.gd")
## Closed magnetic ribbon with continuous frames through inverted sections.
const THEMES = [
	["MIDNIGHT GRID", Color("050b26"), Color("223e85"), Color("24eacd"), Color("ff4d9e")],
	["COPPER DISTRICT", Color("170b2b"), Color("713f62"), Color("ffb43e"), Color("46dfff")],
	["PULSE CITY", Color("051631"), Color("185b83"), Color("58e5ff"), Color("ff65c6")],
	["NEON HEIGHTS", Color("100822"), Color("513c8d"), Color("d387ff"), Color("50ffb9")],
]
var nodes: Array[Dictionary] = []
var length := 0.0
var step: float
var seed_value: int
var theme: Array
var layout: String
var profile:Dictionary
var loops: Array[Dictionary] = []
var radius: float
var lobes: int
var amplitude: float
var phase: float
var stretch: float
var hills: int
var climb: float
var corner_a_width:float
var corner_b_width:float
var corner_shift:float
var features:Array[Dictionary]=[]
const DIFFICULTIES := ["easy","normal","hard"]
var difficulty := "normal"
const BIOMES := ["city","forest","cell"]
var biome := "city"
var water_level:float=-INF
var jumps:Array[Dictionary]=[]
var obstacles:RefCounted
var hazards:=HazardCollision.new()
var components:Array[Dictionary]=[]
var dead_ends:Array[Dictionary]=[]

func base_position(u: float) -> Vector3:
	var a := u * TAU
	# Broad sweepers alternate with localized tighter corner complexes.
	var corner_a := exp(-pow(angle_difference(a, 2.7+corner_shift) / corner_a_width, 2))
	var corner_b := exp(-pow(angle_difference(a, 5.45-corner_shift) / corner_b_width, 2))
	var r:float=radius+amplitude*sin(lobes*a+phase)+(260*corner_a-175*corner_b)*profile.corner_scale
	for corner in profile.corners:
		var width:float=corner[2]*(1.4 if difficulty=="easy" else (.72 if difficulty=="hard" else 1.))
		var center:float=corner[0]*TAU+corner_shift
		# A paired offset makes a proper left/right chicane in the centreline.
		r+=corner[1]*(exp(-pow(angle_difference(a,center-.11)/width,2))-exp(-pow(angle_difference(a,center+.11)/width,2)))
	var ridge := 170 * exp(-pow((u - .55) / .075, 2))
	var altitude:=200 + climb * sin(hills * a + phase) + 12 * sin(3*a+phase*.4) + ridge
	if biome=="forest": altitude=80+climb*.42*sin(hills*a+phase)+6*sin(3*a+phase*.4)+ridge*.3
	if profile.shape=="stadium":
		var horizontal:=Profiles.stadium(u,radius,stretch)
		return Vector3(horizontal.x,altitude,horizontal.y)
	return Vector3(sin(a) * r * stretch, altitude, cos(a) * r)

static func smooth_phase(t: float) -> float:
	return t*t*t*(t*(t*6-15)+10)

func raw_position(u: float) -> Vector3:
	var component:=Components.at(components,u)
	if not component.is_empty(): return component.curve.sample_baked((u-component.start)/(component.end-component.start)*component.length,true)
	var p := base_position(u)
	for jump in jumps:
		if u<=jump.start or u>=jump.end: continue
		var t:float=(u-jump.start)/(jump.end-jump.start)
		var line:=base_position(jump.start).lerp(base_position(jump.end),t)
		# Straighten the flight corridor, with tangent-continuous approach/exit.
		var blend:=smooth_phase(clampf(minf(t,1.-t)/.22,0.,1.))
		var altitude:=p.y
		p=p.lerp(line,blend)
		p.y=altitude
		var lip:float=jump.lip
		var land:float=jump.land
		var height:float
		if t<lip:
			height=jump.rise*(pow(t/lip,2.) if jump.get("turbo",false) else smooth_phase(t/lip))
		elif t<land: height=lerpf(jump.rise,jump.drop,smooth_phase((t-lip)/(land-lip)))
		else: height=jump.drop*(1.-smooth_phase((t-land)/(1.-land)))
		p.y+=height
		if difficulty=="hard" and t>lip:
			# Offset the landing island across the gap, then ease back into the course.
			var side:Vector3=(base_position(jump.start+.001)-base_position(jump.start)).normalized().cross(Vector3.UP).normalized()
			var across:float=smooth_phase(clampf((t-lip)/(land-lip),0.,1.))
			if t>land+.20: across=1.-smooth_phase(clampf((t-land-.20)/(1.-land-.20),0.,1.))
			p+=side*float(jump.offset)*across
	for loop in loops:
		if u <= loop.start or u >= loop.end: continue
		var q: float = (u-loop.start)/(loop.end-loop.start)
		var theta := TAU*smooth_phase(q)
		# Separate the crossing laterally so the loop never intersects itself.
		p += loop.forward * loop.radius * sin(theta)
		p += Vector3.UP * loop.radius * (1-cos(theta))
		p += loop.right * 160 * sin(theta) * pow(sin(PI*q),2)
	return p

func _init(track_seed: int = 1, challenge:String="normal", setting:String="city") -> void:
	seed_value = track_seed
	biome=setting if setting in BIOMES else "city"
	difficulty=challenge if challenge in DIFFICULTIES else "normal"
	profile=Profiles.recipe(track_seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = track_seed
	theme = THEMES[rng.randi_range(0,3)]
	if biome=="forest": theme=["VERDANT REACH",Color("173c43"),Color("426a60"),Color("8bd8bd"),Color("e5b96c")]
	if biome=="cell": theme=["THE CELL",Color("153c42"),Color("716080"),Color("83dfc6"),Color("eda3ba")]
	radius = rng.randf_range(900,1100)
	lobes = rng.randi_range(2,4)
	amplitude = rng.randf_range(65,155)
	phase = rng.randf()*TAU
	stretch = rng.randf_range(1,1.3)
	hills = rng.randi_range(2,3)
	climb = rng.randf_range(105,170)
	corner_a_width=rng.randf_range(.15,.16)
	corner_b_width=rng.randf_range(.18,.195)
	corner_shift=rng.randf_range(-.055,.055)
	if difficulty=="easy":
		corner_a_width*=1.35
		corner_b_width*=1.35
	elif difficulty=="hard":
		corner_a_width*=.62
		corner_b_width*=.70
	layout=profile.name
	for start:float in profile.loops:
		var center: float = start+.052
		var f := base_position(center+.001)-base_position(center-.001)
		f.y=0
		f=f.normalized()
		loops.append({"start":start,"end":start+.105,"radius":rng.randf_range(185,225),"forward":f,"right":f.cross(Vector3.UP)})
	if difficulty!="easy":
		var jump_rng:=RandomNumberGenerator.new()
		jump_rng.seed=track_seed+62041
		var shift:=jump_rng.randf_range(-.002,.002)
		for span in profile.jumps:
			jumps.append({"kind":"jump","start":span[0]+shift,"end":span[1]+shift,
				"lip":.38,"land":.56 if difficulty=="normal" else .61,
				"rise":12. if difficulty=="normal" else 25.,"drop":0.,"offset":34.*(1. if track_seed%2==0 else -1.)})
		if difficulty=="hard" and profile.hard_flight:
			jumps.append({"kind":"flight","start":.927,"end":.994,"lip":.27,"land":.58,"rise":28.,"drop":0.,"offset":46.*(-1. if track_seed%2==0 else 1.)})
	components=Components.build(self)
	if difficulty=="hard" and Profiles.index(seed_value) in [0,3,4]:
		var turbo:Dictionary=jumps[0]
		turbo.turbo=true;turbo.rise=38.;turbo.drop=-38.;turbo.land=.68;turbo.offset*=1.4
	var raw: Array[Vector3] = []
	var distances: Array[float] = [0.0]
	const RESOLUTION := 4096
	for i in range(RESOLUTION+1):
		var p := raw_position(float(i)/RESOLUTION)
		if i>0:
			length+=p.distance_to(raw[-1])
			distances.append(length)
		raw.append(p)
	var count := ceili(length/9)
	step=length/count
	var j:=0
	for i in range(count):
		var distance:=i*step
		while distances[j+1]<distance: j+=1
		var f:float=(distance-distances[j])/(distances[j+1]-distances[j])
		var u:float=(j+f)/RESOLUTION
		var loop_section:=false
		for loop in loops:
			if u>loop.start and u<loop.end: loop_section=true
		var zone:=""
		if u<.065: zone="repair"
		elif (u>.115 and u<.142) or (u>.63 and u<.65): zone="boost"
		var section:="MAGNETIC LOOP" if loop_section else ("SKYLINE DIVE" if u>.49 and u<.64 else ("TECHNICAL SECTOR" if u>.38 and u<.48 else "HIGH SPEED SWEEP"))
		var hint:=base_position(u+.001)-base_position(u-.001)
		hint.y=0
		var enclosed:=false
		for span in profile.tunnels:
			if u>span[0] and u<span[1]: enclosed=true
		nodes.append({"p":raw[j].lerp(raw[j+1],f),"u":u,"width":(23+6*pow(sin(u*TAU*3+phase),2))*profile.width_scale,
			"bank":0.0,"zone":zone,"tunnel":enclosed,"loop":loop_section,"section":section,
			"right_hint":hint.normalized().cross(Vector3.UP)})
		if difficulty=="easy": nodes[-1].width+=9.
	for i in range(count):
		var delta:Vector3=nodes[(i+1)%count].p-nodes[posmod(i-1,count)].p
		nodes[i].forward=delta.normalized()
		nodes[i].heading=atan2(-delta.x,delta.z)
		nodes[i].slope=nodes[i].forward.y
		if not Components.at(components,nodes[i].u).is_empty():
			nodes[i].right_hint=nodes[i].forward.cross(Vector3.UP).normalized()
	var bank_targets:Array[float]=[]
	for i in range(count):
		var derivative:Vector3=(nodes[(i+1)%count].forward-nodes[posmod(i-1,count)].forward)/(2*step)
		var limit:=.20 if difficulty=="easy" else (.34 if difficulty=="hard" else .28)
		var bend:float=derivative.dot(nodes[i].right_hint)
		bank_targets.append(clampf(-bend*48.,-limit,limit) if not nodes[i].loop else 0.)
	for i in range(count):
		var n:=nodes[i]
		var f:Vector3=n.forward
		var right:Vector3=(n.right_hint-f*n.right_hint.dot(f)).normalized()
		var derivative:Vector3=(nodes[(i+1)%count].forward-nodes[posmod(i-1,count)].forward)/(2*step)
		# Spatial smoothing spreads bank changes over ~220 metres, not one mesh seam.
		var total:=0.;var weight:=0.
		for offset in range(-12,13):
			var w:=13.-absf(offset)
			total+=bank_targets[posmod(i+offset,count)]*w;weight+=w
		n.bank=total/weight
		right=right.rotated(f,-n.bank)
		var up:=right.cross(f).normalized()
		n.frame=Basis(-right,up,f).orthonormalized()
		n.curve=derivative.dot(right)
		n.crest=derivative.dot(up)

	# Amber edge bars precede the sharper apexes; central boost arrows remain distinct.
	for i in range(count):
		var next_corner:Dictionary=nodes[(i+10)%count]
		nodes[i].brake_hint=not nodes[i].loop and not next_corner.loop and absf(next_corner.curve)>.007
	build_features()
	if biome=="forest":
		water_level=INF
		for n in nodes: water_level=minf(water_level,n.p.y-24.)

func hits_water(position:Vector3)->bool:
	return biome=="forest" and position.y<=water_level+.6

func build_features()->void:
	# A separate stream preserves the seed's centreline while varying feature size
	# and position. All sections have long, smooth entry/exit ramps.
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value+91837
	for recipe in profile.sections:
		var shift:=rng.randf_range(-.006,.006)
		features.append({"kind":recipe[0],"start":recipe[1]+shift,"end":recipe[2]+shift,
			"size":rng.randf_range(.90,1.10)})
	for n in nodes:
		n.shape_angle=0.
		n.air_gap=false
		n.split_gap=0.
		n.rails=true
		n.feature="ribbon"
		n.dead_side=0.;n.dead_gap=false;n.preferred_route=0.
		for feature in features:
			if n.u<=feature.start or n.u>=feature.end: continue
			var q:float=(n.u-feature.start)/(feature.end-feature.start)
			var blend:=smooth_phase(clampf(minf(q,1.-q)/.24,0.,1.))
			n.feature=feature.kind
			match feature.kind:
				"chicane":
					n.section="CHICANE"
				"narrows":
					n.width=lerpf(n.width,25. if difficulty=="easy" else (15. if difficulty=="hard" else 18.),blend)
					n.section="NARROWS"
				"open":
					n.rails=difficulty=="easy"
					n.section="SKYWAY" if n.rails else "OPEN SKY · NO RAILS"
				"halfpipe":
					n.shape_angle=(1.1 if difficulty=="easy" else 1.48)*blend
					n.width=lerpf(n.width,52.*feature.size,blend)
					n.rails=difficulty=="easy"
					n.section="HALF PIPE"
				"tube":
					n.shape_angle=PI*blend
					n.width=lerpf(n.width,PI*30.*feature.size,blend)
					n.rails=difficulty=="easy"
					n.section="360° MAGNETIC TUBE"
				"split":
					n.split_gap=18.*feature.size*blend
					n.width+=n.split_gap
					n.section="SPLIT ROUTE"
					if difficulty=="hard":
						n.dead_side=1. if seed_value%2==0 else -1.
						n.preferred_route=-n.dead_side
						n.dead_gap=q>=.59
						n.section="DEAD END · "+("KEEP LEFT" if n.dead_side>0. else "KEEP RIGHT")
			break
		var component:=Components.at(components,n.u)
		if not component.is_empty():
			n.feature=component.kind;n.shape_angle=0.;n.split_gap=0.;n.tunnel=false;n.zone=""
			n.section="SPIRAL ASCENT" if component.kind=="spiral" else "HAIRPIN · BRAKE"
			if component.kind=="hairpin":
				var q:float=(n.u-component.start)/(component.end-component.start)
				n.width=lerpf(n.width,16.,smooth_phase(clampf(minf(q,1.-q)/.12,0.,1.)));n.rails=false
		for jump in jumps:
			if n.u<=jump.start or n.u>=jump.end: continue
			var t:float=(n.u-jump.start)/(jump.end-jump.start)
			n.feature=jump.kind
			n.air_gap=t>=jump.lip and t<jump.land
			n.rails=not n.air_gap
			n.zone=""
			n.width+=smooth_phase(clampf(minf(t,1.-t)/.2,0.,1.))*(18. if difficulty=="normal" else 2.)
			if jump.get("turbo",false) and t>jump.lip-.19 and t<jump.lip-.025: n.zone="boost"
			n.section="FLIGHT GAP" if n.air_gap else ("JUMP · KEEP SPEED" if t<jump.lip else "LANDING ZONE")
			if jump.get("turbo",false): n.section="TURBO JUMP · NOSE DOWN" if t<jump.land else "LANDING ZONE"
		if difficulty=="hard" and not n.loop and not n.tunnel and n.feature=="ribbon":
			if (n.u>.02 and n.u<.05) or (n.u>.285 and n.u<.335) or (n.u>.64 and n.u<.68) or (n.u>.755 and n.u<.80):
				n.rails=false
				n.section="EXPOSED SKYWAY"
	# Boundaries lie exactly on mesh nodes, shared by rendering and physics.
	for jump in jumps:
		var gap_indices:Array[int]=[]
		for i in range(nodes.size()):
			if nodes[i].feature==jump.kind and nodes[i].air_gap and nodes[i].u>jump.start and nodes[i].u<jump.end: gap_indices.append(i)
		jump.takeoff=gap_indices[0]*step
		jump.landing=(gap_indices[-1]+1)*step
		jump.respawn=jump.takeoff-260.
		features.append(jump.duplicate())
	if difficulty=="hard":
		for feature in features:
			if feature.kind!="split": continue
			var terminal_u:float=lerpf(feature.start,feature.end,.59)
			var index:=0
			while nodes[index].u<terminal_u: index+=1
			var n:Dictionary=nodes[index]
			var wall:bool=posmod(seed_value/6,2)==1
			var size:=Vector3(n.width-n.split_gap,14.,3.)
			var pose:=Transform3D(n.frame,point(n,n.dead_side*(n.width+n.split_gap)*.5,7.))
			dead_ends.append({"distance":index*step,"start":feature.start,"end":feature.end,"wall":wall,"pose":pose,"size":size,"side":n.dead_side})
			if wall: hazards.add_box(Transform3D(pose.basis.scaled_local(size),pose.origin))
	for n in nodes: n.geometry=geometry_data(n)
	for i in range(nodes.size()):
		nodes[i].before=nodes[posmod(i-1,nodes.size())].geometry
		nodes[i].after=nodes[(i+1)%nodes.size()].geometry

static func geometry_data(n:Dictionary)->Dictionary:
	return {"p":n.p,"frame":n.frame,"width":n.width,"shape_angle":n.get("shape_angle",0.)}

func sample(distance: float) -> Dictionary:
	var f:=fposmod(distance,length)/step
	var i:=int(f)
	f-=i
	var a:=nodes[i]
	var b:=nodes[(i+1)%nodes.size()]
	return {"p":a.p.lerp(b.p,f),"width":lerpf(a.width,b.width,f),"frame":a.frame.slerp(b.frame,f),
		"before":a.geometry,"after":b.geometry,
		"heading":lerp_angle(a.heading,b.heading,f),"slope":lerpf(a.slope,b.slope,f),
		"crest":lerpf(a.crest,b.crest,f),"curve":lerpf(a.curve,b.curve,f),"bank":lerpf(a.bank,b.bank,f),
		"shape_angle":lerpf(a.shape_angle,b.shape_angle,f),"split_gap":lerpf(a.split_gap,b.split_gap,f),
		"dead_side":a.dead_side,"dead_gap":a.dead_gap,"preferred_route":a.preferred_route,"air_gap":a.air_gap,"rails":a.rails,"feature":a.feature,"zone":a.zone,"tunnel":a.tunnel,"loop":a.loop,"section":a.section}

func jump_at(distance:float,approach:float=0.)->Dictionary:
	var local:=fposmod(distance,length)
	for jump in jumps:
		if local>=jump.takeoff-approach and local<jump.landing+120.: return jump
	return {}

func safe_respawn(distance:float)->float:
	var u:float=nodes[int(fposmod(distance,length)/step)].u
	for hazard in dead_ends:
		if u>=hazard.start and u<hazard.end:
			for i in range(nodes.size()):
				if nodes[i].u>=hazard.start:
					return floorf(distance/length)*length+i*step-180.
	var jump:=jump_at(distance,260.)
	if not jump.is_empty() and fposmod(distance,length)<jump.landing:
		return floorf(distance/length)*length+jump.respawn
	return distance

static func point(n: Dictionary,lateral:float,height:float=0)->Vector3:
	var position:=surface_position(n,lateral)
	return position if height==0. else position+surface_frame(n,lateral).y*height

static func surface_position(n:Dictionary,lateral:float)->Vector3:
	var angle:float=n.get("shape_angle",0.)
	if angle<.0001: return n.p-n.frame.x*lateral
	var radius:float=n.width/angle
	var theta:=lateral/radius
	return n.p-n.frame.x*radius*sin(theta)+n.frame.y*radius*(1.-cos(theta))

static func surface_frame(n:Dictionary,lateral:float)->Basis:
	var angle:float=n.get("shape_angle",0.)
	if angle<.0001: return n.frame
	var frame:Basis=n.frame*Basis(Vector3.BACK,-lateral/n.width*angle)
	if n.has("before"):
		var along:=surface_position(n.after,lateral)-surface_position(n.before,lateral)
		var forward:Vector3=(along-frame.x*along.dot(frame.x)).normalized()
		if forward.length_squared()>.9: frame=Basis(frame.x,forward.cross(frame.x).normalized(),forward)
	return frame

static func closed_tube(n:Dictionary)->bool:
	return float(n.get("shape_angle",0.))>PI-.001

static func cross_section_sphere(n:Dictionary)->Dictionary:
	# Arc width is not spatial width: a full tube's envelope is its diameter.
	var angle:float=n.get("shape_angle",0.)
	if angle<.0001: return {"center":n.p,"radius":n.width}
	var radius:float=n.width/angle
	if angle>=PI*.5: return {"center":n.p+n.frame.y*radius,"radius":radius}
	var rise:=radius*(1.-cos(angle))*.5
	var extent:=radius*sin(angle)
	return {"center":n.p+n.frame.y*rise,"radius":sqrt(extent*extent+rise*rise)}

static func lateral_at(n:Dictionary,position:Vector3)->float:
	var delta:Vector3=position-n.p
	var angle:float=n.get("shape_angle",0.)
	if angle<.0001: return -delta.dot(n.frame.x)
	var radius:float=n.width/angle
	return atan2(-delta.dot(n.frame.x),radius-delta.dot(n.frame.y))*radius

static func supported(n:Dictionary,lateral:float,margin:float=0.)->bool:
	if n.get("air_gap",false): return false
	if n.get("dead_gap",false) and lateral*float(n.get("dead_side",0.))>0.: return false
	if not closed_tube(n) and absf(lateral)>n.width-margin: return false
	var gap:float=n.get("split_gap",0.)
	return gap<.01 or absf(lateral)>gap+margin

static func basis_at(n:Dictionary)->Basis:
	return n.frame

func project(position:Vector3,reference:float,reach:float)->Dictionary:
	# Coarse spatial search, then exact projection onto nearby ribbon segments.
	var closest:=0
	var best:=INF
	for i in range(0,nodes.size(),8):
		var arc:=reference+fposmod(i*step-reference+length*.5,length)-length*.5
		if absf(arc-reference)>reach: continue
		var squared:float=position.distance_squared_to(nodes[i].p)
		if squared<best:
			best=squared
			closest=i
	var distance:=reference
	best=INF
	for offset in range(-10,11):
		var i:=posmod(closest+offset,nodes.size())
		var a:Vector3=nodes[i].p
		var delta:Vector3=nodes[(i+1)%nodes.size()].p-a
		var along:=clampf((position-a).dot(delta)/delta.length_squared(),0,1)
		var arc:=reference+fposmod((i+along)*step-reference+length*.5,length)-length*.5
		if absf(arc-reference)>reach: continue
		var squared:=position.distance_squared_to(a+delta*along)
		if squared<best:
			best=squared
			distance=arc
	var n:=sample(distance)
	# The closest centreline point can be far from the closest wall on a banked
	# tube. Refine along the actual curved deck before evaluating a landing.
	if float(n.get("shape_angle",0.))>.0001:
		for iteration in range(6):
			var lateral:=lateral_at(n,position)
			var surface:=surface_position(n,lateral)
			var tangent:Vector3=surface_position(sample(distance+.5),lateral)-surface_position(sample(distance-.5),lateral)
			var correction:=clampf((position-surface).dot(tangent)/maxf(.01,tangent.length_squared()),-step*2.,step*2.)
			distance=clampf(distance+correction,reference-reach,reference+reach)
			n=sample(distance)
			if absf(correction)<.001: break
	return {"distance":distance,"node":n,"lateral":lateral_at(n,position)}
