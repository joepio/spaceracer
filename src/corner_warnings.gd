extends RefCounted
## One warning per demanding bend, not a repeating roadside pattern.
const FEATURES:=["ribbon","hairpin","spiral","chicane","narrows","open"]
const EDGE:=.002

static func severity(peak:float,angle:float)->int:
	if peak<.0085 or angle<deg_to_rad(35.): return 0
	if (peak>=.016 and angle>=deg_to_rad(130.)) or (peak>=.024 and angle>=deg_to_rad(75.)): return 3
	return 2 if peak>=.0125 else 1

static func eligible(n:Dictionary)->bool:
	return not n.loop and not n.air_gap and n.feature in FEATURES

static func corners(track:RefCounted)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	var bends:Array[float]=[]
	var count:int=track.nodes.size()
	var begin:=0
	for i in range(count):
		var bend:=0.
		for offset in range(-2,3): bend+=track.nodes[posmod(i+offset,count)].curve/5.
		bends.append(bend)
		if absf(bend)<EDGE or not eligible(track.nodes[i]): begin=i
	var current:Dictionary={}
	for offset in range(1,count+1):
		var i:=posmod(begin+offset,count)
		var n:Dictionary=track.nodes[i]
		var bend:=bends[i]
		var valid:=eligible(n) and absf(bend)>=EDGE
		if not current.is_empty() and (not valid or signf(bend)!=current.turn):
			current.level=severity(current.peak,current.angle)
			result.append(current);current={}
		if not valid: continue
		var distance:float=(begin+offset)*track.step
		if current.is_empty():
			current={"start":distance,"end":distance,"apex":distance,"turn":signf(bend),"peak":0.,"angle":0.,"exposed":false}
		current.end=distance
		if absf(bend)>current.peak: current.peak=absf(bend);current.apex=distance
		current.angle+=absf(bend)*track.step
		current.exposed=current.exposed or not n.rails
	if not current.is_empty():
		current.level=severity(current.peak,current.angle);result.append(current)
	return result

static func plan(track:RefCounted)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	var bends:=corners(track)
	for i in range(bends.size()):
		var corner:Dictionary=bends[i]
		if corner.level==0: continue
		var lead:float=[0.,160.,210.,280.][corner.level]
		var distance:float=corner.start-lead
		# An S-bend's second arrow must not precede the first bend's apex.
		if i>0: distance=maxf(distance,float(bends[i-1].apex)+45.)
		elif bends.size()>1: distance=maxf(distance,float(bends[-1].apex)-track.length+45.)
		var latest:float=corner.start-27.
		if not result.is_empty(): distance=maxf(distance,float(result[-1].unwrapped)+160.)
		# A sign must describe the connected road ahead, not a corner beyond a
		# flight gap, tube or fork. Move it past any intervening special section.
		var approach:=distance
		while approach<corner.start:
			var n:Dictionary=track.nodes[posmod(roundi(approach/track.step),track.nodes.size())]
			if not eligible(n) or n.tunnel or n.split_gap>=.01: distance=approach+track.step
			approach+=track.step
		while distance<=latest:
			var n:Dictionary=track.nodes[posmod(roundi(distance/track.step),track.nodes.size())]
			if eligible(n) and not n.tunnel and n.split_gap<.01:
				var sign_info:=corner.duplicate()
				sign_info.distance=fposmod(distance,track.length)
				sign_info.unwrapped=distance
				sign_info.ahead=corner.start-distance
				result.append(sign_info)
				break
			distance+=track.step
	if result.size()>1 and result[0].unwrapped+track.length-result[-1].unwrapped<160.:
		result.pop_back()
	return result
