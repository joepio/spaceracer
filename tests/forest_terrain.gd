extends SceneTree
const Race=preload("res://src/race.gd")
const Terrain=preload("res://src/forest_terrain.gd")
const Obstacles=preload("res://src/obstacles.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<10: push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	for seed_value in [6,31,421]:
		for difficulty in ["easy","normal","hard"]:
			var race:=Race.new([{"slot":0}],seed_value,1,difficulty,"forest")
			var terrain:=Terrain.new(race.track)
			var dry:=0;var wet:=0
			for z in range(-2400,2400,120):
				for x in range(-2400,2400,120):
					if terrain.height_at(x,z)>terrain.water_level+2.: dry+=1
					else: wet+=1
			check(dry>400 and wet>160,"Landscape combines substantial connected land and water")
			for n in race.track.nodes:
				for lateral in [-1.,0.,1.]:
					var point:Vector3=Race.Track.point(n,n.width*lateral,0.)
					check(terrain.height_at(point.x,point.z)<point.y-8.,"Landscape cannot intersect banks, loops or jump paths")
			var point:=Vector3(1700.,0.,1200.)
			point.y=terrain.height_at(point.x,point.z)
			var hit:=terrain.trace(point+Vector3.UP*150.,point-Vector3.UP*150.,3.)
			check(not hit.is_empty() and absf(hit.position.y-point.y-3.)<.01,"Fast downward flight hits the visible ground")
			check(hit.normal.y>.5,"Ground impact gives an upward slope normal")
			check(terrain.trace(point+Vector3.UP*1000.,point+Vector3(100.,1000.,0.),3.).is_empty(),"High free flight clears the landscape")
			var obstacles:=Obstacles.new();obstacles.terrain=terrain
			obstacles.add_box(Transform3D(Basis.IDENTITY,point+Vector3.UP*60.),AABB(Vector3.ONE*-5.,Vector3.ONE*10.))
			hit=obstacles.trace(point+Vector3.UP*150.,point-Vector3.UP*150.,3.)
			check(hit.position.y>point.y+60.,"Nearer object collision wins over terrain behind it")
	# Independently compare height sampling against the shipped mesh triangles.
	var terrain:=Terrain.new(Race.new([{"slot":0}],31,1,"hard","forest").track)
	var stage:=Node3D.new();root.add_child(stage);terrain.build(stage)
	for node in stage.get_children():
		var arrays:Array=node.mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		for i in range(0,indices.size(),93):
			var a:=vertices[indices[i]];var b:=vertices[indices[i+1]];var c:=vertices[indices[i+2]]
			var center:Vector3=(a+b+c)/3.
			check(absf(center.y-terrain.height_at(center.x,center.z))<.01,"Collision surface follows rendered triangles")
			check((c-a).cross(b-a).y>0.,"Landscape faces point upward")
	stage.free()
	print("LANDSCAPE_TESTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
