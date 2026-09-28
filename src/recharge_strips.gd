extends RefCounted
## Shared road charging: unlimited supply, with no collection order or cooldown.
const RATE:=34.
const LEFT:=-.88
const RIGHT:=.30
const CENTER:=(LEFT+RIGHT)*.5

static func eligible(track:RefCounted,index:int)->bool:
	var n:Dictionary=track.nodes[index]
	return index*track.step>180. and n.zone!="boost" and not n.loop and not n.air_gap and n.split_gap<.01 and n.shape_angle<.01 and n.width>=22. and absf(n.curve)<.006 and absf(n.slope)<.32 and n.feature in ["ribbon","open","chicane","narrows"] and track.jump_at(index*track.step,160.).is_empty()

static func install(track:RefCounted)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	var invalid:Array[int]=[0]
	var curvature:Array[float]=[0.]
	for i in range(track.nodes.size()):
		if track.nodes[i].zone=="repair": track.nodes[i].zone=""
		invalid.append(invalid[-1]+(0 if eligible(track,i) else 1))
		curvature.append(curvature[-1]+absf(track.nodes[i].curve))
	for fraction in [.055,.40,.73]:
		var chosen:=-1;var span:=0;var best:=INF
		# Prefer long gentle sections; short technical tracks can use a smaller
		# section instead of placing charging on a jump, tube, fork or hairpin.
		for length_value in [300.,220.,160.]:
			var candidate_span:=ceili(length_value/track.step)
			for start in range(track.nodes.size()-candidate_span-1):
				if invalid[start+candidate_span+1]!=invalid[start]: continue
				var center:float=(start+candidate_span*.5)*track.step
				var nearby:=false
				for strip in result:
					if absf(center-strip.center)<850.: nearby=true;break
				if nearby: continue
				var score:float=absf(center-track.length*fraction)+(curvature[start+candidate_span]-curvature[start])/candidate_span*60000.+(300.-length_value)*1.7
				if score<best: best=score;chosen=start;span=candidate_span
		if chosen<0: continue
		for i in range(chosen,chosen+span):
			track.nodes[i].zone="repair";track.nodes[i].rails=true
		# Recharge must not ask an inexperienced racer to hug an exposed edge.
		for i in range(maxi(0,chosen-6),mini(track.nodes.size(),chosen+span+6)):
			if eligible(track,i): track.nodes[i].rails=true
		result.append({"start":chosen*track.step,"end":(chosen+span)*track.step,"center":(chosen+span*.5)*track.step})
	result.sort_custom(func(a,b):return a.start<b.start)
	return result

static func apply(p:Dictionary,n:Dictionary,dt:float)->void:
	if p.airborne or p.crashed or p.finished or p.recovery>0. or p.warp_time>0. or p.energy<=0. or p.energy>=100.: return
	if n.zone!="repair" or p.lift>=1. or p.x<n.width*LEFT or p.x>n.width*RIGHT: return
	p.energy=minf(100.,p.energy+RATE*dt)
	p.energy_fx=.18
