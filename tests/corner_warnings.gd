extends SceneTree
const Warnings=preload("res://src/corner_warnings.gd")
const Track=preload("res://src/track.gd")
const Markers=preload("res://src/turn_markers.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	check(Warnings.severity(.006,PI)==0,"Gentle bends need no sign")
	check(Warnings.severity(.025,.3)==0,"A brief curvature spike needs no sign")
	check(Warnings.severity(.01,1.)==1,"Meaningful moderate bend is yellow")
	check(Warnings.severity(.017,1.5)==2,"Sharp corner alone is not red")
	check(Warnings.severity(.017,PI)==3,"Very tight hairpin is red")
	var seen:={}
	for seed_value in [31,32,33,35,39,45,80385]:
		var track:=Track.new(seed_value,"hard")
		var holder:=Node3D.new();root.add_child(holder);Markers.build(holder,track)
		var counts:=[0,0,0];var exposed:=0;var starts:={}
		var previous:=-INF
		for sign_info in holder.get_meta("turn_markers",[]):
			counts[sign_info.level-1]+=1;seen[sign_info.level]=true
			if sign_info.exposed: exposed+=1
			var n:Dictionary=track.sample(sign_info.distance)
			check(not n.air_gap and n.split_gap==0. and not n.tunnel,"Signs mount beside solid open road")
			check(sign_info.frame.origin.distance_to(n.p)>n.width,"Sign remains outside driving deck")
			check(sign_info.unwrapped<=sign_info.start-27.,"Warning precedes actual corner")
			check(not starts.has(sign_info.start),"Only one warning per corner")
			check(sign_info.unwrapped-previous>=159.9,"Warnings are spaced apart")
			starts[sign_info.start]=true;previous=sign_info.unwrapped
		if seed_value==33:
			check(counts[1]>0 and counts[2]<=2 and exposed>0,"Opened-up Switchback still warns for sharp exposed bends without forcing red")
			check(starts.size()<=12,"Hard Switchback does not spam warnings")
		check(holder.get_child_count()<=3,"All signs share at most three draws without added lights")
		print("CORNER_SIGNS seed=",seed_value," yellow/orange/red=",counts," exposed=",exposed)
		holder.queue_free()
	check(seen.has(1) and seen.has(2),"Generated tracks retain moderate and sharp warnings; synthetic extreme hairpin above covers red")
	await process_frame
	print("CORNER_WARNING_TESTS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
