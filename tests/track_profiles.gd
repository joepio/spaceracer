extends SceneTree
const Track=preload("res://src/track.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<20: push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var report:Array=[]
	for seed_value in range(31,37):
		for level in Track.DIFFICULTIES:
			for biome in Track.BIOMES:
				var track:=Track.new(seed_value,level,biome)
				check(track.layout==Track.Profiles.title(seed_value),"Identity survives difficulty and biome changes")
				var tunnels:=0;var tight:=0;var straight:=0;var pipes:=0;var minimum_width:=INF
				for n in track.nodes:
					check(not n.tunnel or (not n.loop and not n.air_gap and n.shape_angle==0.),"Tunnels never intersect loops, flight gaps or curved decks")
					check(n.frame.is_finite() and n.frame.determinant()>.999,"Every component has a valid rideable frame")
					if n.tunnel: tunnels+=1
					if not n.loop and absf(n.curve)>.007: tight+=1
					if not n.loop and absf(n.curve)<.00005: straight+=1
					if n.feature in ["halfpipe","tube"]: pipes+=1
					minimum_width=minf(minimum_width,n.width)
				if level=="easy": check(track.jumps.is_empty() and track.nodes.all(func(n):return n.rails),"Easy keeps continuous road and rails in every family")
				for jump in track.jumps:
					check(track.jump_at(jump.takeoff+1.)==jump,"Every jump resolves its own landing, including repeated components")
				for i in range(0,track.nodes.size(),8):
					for j in range(i+8,track.nodes.size(),8):
						var arc:=minf((j-i)*track.step,track.length-(j-i)*track.step)
						if arc<200.: continue
						var a:=Track.cross_section_sphere(track.nodes[i])
						var b:=Track.cross_section_sphere(track.nodes[j])
						check(a.center.distance_to(b.center)>=a.radius+b.radius+5.,"Distant decks do not intersect: %d %s %s"%[seed_value,level,biome])
				var coverage:=float(tunnels)/track.nodes.size()
				if seed_value==32: check(coverage>.50,"Underpass spends over half a lap inside tunnels")
				if seed_value==33 and level=="hard": check(tight*track.step>450.,"Switchback has sustained tight corner complexes")
				if seed_value==34: check(track.loops.size()==3 and (level=="easy" or track.jumps.size()>=3),"Sky Circus repeats aerial set pieces")
				if seed_value==35: check(float(straight)/track.nodes.size()>.30,"Velocity has genuinely straight high-speed sectors")
				if seed_value==36: check(float(pipes)/track.nodes.size()>.40,"Pipeline spends a substantial lap in curved decks")
				if biome=="city" and level=="hard":
					var item:={"seed":seed_value,"name":track.layout,"length_m":roundi(track.length),"tunnel_percent":roundi(coverage*100.),"tight_m":roundi(tight*track.step),"loops":track.loops.size(),"jumps":track.jumps.size(),"minimum_half_width":minimum_width,"points":[]}
					for n in track.nodes: item.points.append([n.p.x,n.p.y,n.p.z,n.feature,n.tunnel,n.loop])
					report.append(item)
					print("PROFILE ",track.layout," length=",roundi(track.length)," tunnel=",roundi(coverage*100.),"% tight=",roundi(tight*track.step),"m loops=",track.loops.size()," jumps=",track.jumps.size())
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			file.store_string(JSON.stringify(report))
	print("TRACK_PROFILE_TESTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
