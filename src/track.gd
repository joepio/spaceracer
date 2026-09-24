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

func sample(distance: float) -> Dictionary:
	var f:=fposmod(distance,length)/step
	var i:=int(f)
	f-=i
	var a:=nodes[i]
	var b:=nodes[(i+1)%nodes.size()]
	return {"p":a.p.lerp(b.p,f),"width":lerpf(a.width,b.width,f),"frame":a.frame.slerp(b.frame,f),
		"heading":lerp_angle(a.heading,b.heading,f),"slope":lerpf(a.slope,b.slope,f),
		"crest":lerpf(a.crest,b.crest,f),"curve":lerpf(a.curve,b.curve,f),"bank":lerpf(a.bank,b.bank,f),
		"zone":a.zone,"tunnel":a.tunnel,"loop":a.loop,"section":a.section}

static func point(n: Dictionary,lateral:float,height:float=0)->Vector3:
	return n.p-n.frame.x*lateral+n.frame.y*height

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
	return {"distance":distance,"node":n,"lateral":-(position-n.p).dot(n.frame.x)}
