extends SceneTree
const Race=preload("res://src/race.gd")
const Cell=preload("res://src/cell.gd")
const Obstacles=preload("res://src/obstacles.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void:
	if DisplayServer.get_name()=="headless":
		push_error("Cell tests need a native renderer for MultiMesh readback; use an offscreen window instead of --headless.")
		quit(1);return
	root.unfocusable=true
	call_deferred("run")
func run()->void:
	for seed_value in [31,421,99999]:
		for difficulty in ["easy","normal","hard"]:
			var race:=Race.new([{"slot":0}],seed_value,3,difficulty,"cell")
			race.track.obstacles=Obstacles.new()
			var parent:=Node3D.new();root.add_child(parent)
			var cell:=Cell.new();cell.build(parent,race)
			var kinds:Dictionary={}
			for specimen in cell.specimens:
				kinds[specimen.kind]=true
				check(cell.clear(specimen.bounds),"Specimen clears the swept track and flight corridor")
			check(kinds.has("dna") and kinds.has("protein") and kinds.has("mitochondrion") and kinds.has("nucleus"),"Every seed contains the main structures")
			check(cell.walkers.size()>8,"Populated walking organelles")
			if cell.walkers.is_empty(): parent.free();continue
			var original:=cell.bodies.get_instance_transform(0)
			var foot:=cell.feet.get_instance_transform(0)
			cell.animate(1.)
			check(not cell.bodies.get_instance_transform(0).is_equal_approx(original),"Cargo moves")
			check(not cell.feet.get_instance_transform(0).is_equal_approx(foot),"Feet articulate")
			var paused:=cell.feet.get_instance_transform(0)
			cell.animate(1.)
			check(cell.feet.get_instance_transform(0).is_equal_approx(paused),"Animation freezes with race clock")
			for time in [0.,2.,7.,18.,31.]:
				cell.animate(time)
				for i in range(cell.walkers.size()):
					check(cell.clear(cell.walkers[i].bounds),"Full walking envelope stays off the course")
					for part in range(2):
						var frame:=cell.bodies.get_instance_transform(i*2+part)
						check(frame.origin.is_finite() and cell.walkers[i].bounds.encloses(frame*cell.sphere.get_aabb()),"Moving body stays in its reserved envelope")
				check(race.track.obstacles.moving[0].is_equal_approx(cell.bodies.get_instance_transform(0)),"Collision follows animated body")
			# Scenery must never add an invisible wall across the racing surface.
			for n in race.track.nodes:
				check(race.track.obstacles.hit(n.p+n.frame.y*6.,n.p+n.frame.y*7.,3.)==null,"Track centre remains free of scenery collisions")
			var sample:=cell.bodies.get_instance_transform(0).origin
			check(race.track.obstacles.hit(sample,sample+Vector3.ONE)!=null,"Off-track walkers have collision")
			if seed_value==31 and difficulty=="hard":
				var replica_parent:=Node3D.new();root.add_child(replica_parent)
				var replica_race:=Race.new([{"slot":0}],seed_value,3,difficulty,"cell");replica_race.track.obstacles=Obstacles.new()
				var replica:=Cell.new();replica.build(replica_parent,replica_race)
				check(cell.specimens==replica.specimens and cell.walkers==replica.walkers,"Same seed reproduces scenery")
				replica_parent.free()
			print("CELL seed=%d %s specimens=%d walkers=%d"%[seed_value,difficulty,cell.specimens.size(),cell.walkers.size()])
			parent.free()
	print("CELL_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
