extends RefCounted
## Seed-selected layout recipes. Biome chooses scenery; difficulty chooses risk.
const NAMES=["Grand Circuit","Underpass","Switchback","Sky Circus","Velocity","Pipeline"]
# Keep the established 00031 layout while adjacent menu seeds cycle characters.
static func index(seed_value:int)->int: return posmod(seed_value-31,NAMES.size())
static func title(seed_value:int)->String: return NAMES[index(seed_value)]

static func recipe(seed_value:int)->Dictionary:
	var result:={"name":title(seed_value),"shape":"radial","corner_scale":1.,"width_scale":1.,
		"boosts":[[.115,.142],[.63,.65]],
		"loops":[.16],"tunnels":[[.33,.38]],"corners":[],
		"sections":[["open",.275,.315],["halfpipe",.405,.49],["split",.535,.615],["tube",.805,.92]],
		"jumps":[[.070,.152]],"hard_flight":true}
	match index(seed_value):
		1:
			result.loops=[];result.corner_scale=.6;result.hard_flight=false
			result.tunnels=[[.17,.30],[.34,.51],[.55,.72],[.81,.92]]
			result.sections=[["split",.735,.795],["narrows",.365,.425]]
		2:
			result.loops=[];result.corner_scale=.25;result.hard_flight=false
			result.corners=[[.235,125.,.20],[.495,-130.,.20],[.75,120.,.19]]
			result.tunnels=[[.57,.615]]
			result.sections=[["chicane",.19,.28],["chicane",.45,.54],["chicane",.705,.795],["narrows",.83,.90]]
		3:
			result.loops=[.17,.45,.73];result.corner_scale=.45
			result.jumps=[[.070,.152],[.325,.410],[.60,.682]]
			result.tunnels=[]
			result.sections=[["open",.285,.31],["halfpipe",.845,.912]]
		4:
			result.shape="stadium";result.loops=[];result.hard_flight=false
			# Repeated acceleration lanes define Velocity: long straights and broad
			# turns stay fast, with gaps around the landing, narrows and split.
			result.boosts=[[.165,.195],[.235,.27],[.365,.40],[.515,.55],[.58,.615],
				[.635,.67],[.745,.775],[.85,.885],[.925,.97]]
			result.tunnels=[[.62,.71]]
			result.sections=[["open",.18,.26],["narrows",.30,.35],["split",.435,.50],["narrows",.78,.83]]
		5:
			result.loops=[];result.corner_scale=.3;result.width_scale=1.12
			result.tunnels=[]
			result.sections=[["halfpipe",.17,.27],["tube",.29,.42],["halfpipe",.44,.58],["split",.61,.67],["tube",.69,.82],["halfpipe",.84,.91]]
	return result

static func stadium(u:float,radius:float,stretch:float)->Vector2:
	# Two true straights joined by tangent-continuous, broad semicircles.
	var r:=radius*.65
	var straight:=radius*1.4
	var d:=fposmod(u,1.)*(2.*straight+TAU*r)
	if d<straight*.5: return Vector2(-r*stretch,d)
	d-=straight*.5
	if d<PI*r:
		var angle:=PI-d/r
		return Vector2(cos(angle)*r*stretch,straight*.5+sin(angle)*r)
	d-=PI*r
	if d<straight: return Vector2(r*stretch,straight*.5-d)
	d-=straight
	if d<PI*r:
		var angle:=-d/r
		return Vector2(cos(angle)*r*stretch,-straight*.5+sin(angle)*r)
	return Vector2(-r*stretch,-straight*.5+d-PI*r)
