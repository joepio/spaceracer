extends RefCounted
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

func base_position(u: float) -> Vector3:
	var a := u * TAU
	# Broad sweepers alternate with localized tighter corner complexes.
	var corner_a := exp(-pow(angle_difference(a, 2.7+corner_shift) / corner_a_width, 2))
	var corner_b := exp(-pow(angle_difference(a, 5.45-corner_shift) / corner_b_width, 2))
	var r := radius + amplitude * sin(lobes * a + phase) + 260 * corner_a - 175 * corner_b
	var ridge := 170 * exp(-pow((u - .55) / .075, 2))
	return Vector3(sin(a) * r * stretch, 200 + climb * sin(hills * a + phase) + 45 * sin(5*a) + ridge, cos(a) * r)

static func smooth_phase(t: float) -> float:
	return t*t*t*(t*(t*6-15)+10)

func raw_position(u: float) -> Vector3:
	var p := base_position(u)
	for loop in loops:
		if u <= loop.start or u >= loop.end: continue
		var q: float = (u-loop.start)/(loop.end-loop.start)
		var theta := TAU*smooth_phase(q)
		# Separate the crossing laterally so the loop never intersects itself.
		p += loop.forward * loop.radius * sin(theta)
		p += Vector3.UP * loop.radius * (1-cos(theta))
		p += loop.right * 160 * sin(theta) * pow(sin(PI*q),2)
	return p

func _init(track_seed: int = 1) -> void:
	seed_value = track_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = track_seed
	theme = THEMES[rng.randi_range(0,3)]
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
	layout = ["SKYLINE DIVE","ORBITAL SWITCHBACK","DOUBLE HELIX"][posmod(track_seed,3)]
	var starts: Array[float] = [.16]
	if posmod(track_seed,3)==2: starts.append(.68)
	for start in starts:
		var center: float = start+.052
		var f := base_position(center+.001)-base_position(center-.001)
		f.y=0
		f=f.normalized()
		loops.append({"start":start,"end":start+.105,"radius":rng.randf_range(185,225),"forward":f,"right":f.cross(Vector3.UP)})
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
		nodes.append({"p":raw[j].lerp(raw[j+1],f),"u":u,"width":23+6*pow(sin(u*TAU*3+phase),2),
			"bank":0.0,"zone":zone,"tunnel":u>.33 and u<.38,"loop":loop_section,"section":section,
			"right_hint":hint.normalized().cross(Vector3.UP)})
	for i in range(count):
		var delta:Vector3=nodes[(i+1)%count].p-nodes[posmod(i-1,count)].p
		nodes[i].forward=delta.normalized()
		nodes[i].heading=atan2(-delta.x,delta.z)
		nodes[i].slope=nodes[i].forward.y
	for i in range(count):
		var n:=nodes[i]
		var f:Vector3=n.forward
		var right:Vector3=(n.right_hint-f*n.right_hint.dot(f)).normalized()
		var derivative:Vector3=(nodes[(i+1)%count].forward-nodes[posmod(i-1,count)].forward)/(2*step)
		var bend:=derivative.dot(right)
		n.bank=clampf(-bend*90,-.62,.62) * (.4 if n.loop else 1.0)
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

func build_features()->void:
	# A separate stream preserves the seed's centreline while varying feature size
	# and position. All sections have long, smooth entry/exit ramps.
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value+91837
	for recipe in [["open",.275,.315],["halfpipe",.405,.49],["split",.535,.615],["tube",.805,.92]]:
		var shift:=rng.randf_range(-.006,.006)
		features.append({"kind":recipe[0],"start":recipe[1]+shift,"end":recipe[2]+shift,
			"size":rng.randf_range(.90,1.10)})
	for n in nodes:
		n.shape_angle=0.
		n.split_gap=0.
		n.rails=true
		n.feature="ribbon"
		for feature in features:
			if n.u<=feature.start or n.u>=feature.end: continue
			var q:float=(n.u-feature.start)/(feature.end-feature.start)
			var blend:=smooth_phase(clampf(minf(q,1.-q)/.24,0.,1.))
			n.feature=feature.kind
			match feature.kind:
				"open":
					n.rails=false
					n.section="OPEN SKY · NO RAILS"
				"halfpipe":
					n.shape_angle=1.48*blend
					n.width=lerpf(n.width,52.*feature.size,blend)
					n.rails=false
					n.section="HALF PIPE"
				"tube":
					n.shape_angle=PI*blend
					n.width=lerpf(n.width,PI*30.*feature.size,blend)
					n.rails=false
					n.section="360° MAGNETIC TUBE"
				"split":
					n.split_gap=18.*feature.size*blend
					n.width+=n.split_gap
					n.section="SPLIT ROUTE"
			break
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
		"rails":a.rails,"feature":a.feature,"zone":a.zone,"tunnel":a.tunnel,"loop":a.loop,"section":a.section}

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
