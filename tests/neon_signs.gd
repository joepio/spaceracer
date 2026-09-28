extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	for seed_value in [31,145,80385]:
		var track=load("res://src/track.gd").new(seed_value)
		var scenery=load("res://src/scenery.gd").new()
		scenery.layout=load("res://src/city_layout.gd").new(track)
		var parent:=Node3D.new();root.add_child(parent)
		var neon=load("res://src/city_accents.gd").new();neon.build(scenery,parent,track)
		var variants:Dictionary={};var districts:Dictionary={}
		for sign in neon.signs:
			variants[sign.variant]=true;districts[sign.district]=true
			check(scenery.layout.clear(sign.bounds),"Neon stays outside the racing and flight corridors")
			check(scenery.layout.buildings.any(func(b):return b.bounds.encloses(sign.bounds)),"Entire sign stays in a building lot")
			check(not scenery.layout.billboards.any(func(board):return board.bounds.grow(5.).intersects(sign.bounds)),"Neon does not cover existing art billboards")
			check(absf(sign.size.x/sign.size.y-neon.ASPECTS[sign.variant])<.001,"Authored sign proportions are preserved")
		check(neon.signs.size()>=320 and neon.signs.size()<=640,"Much denser signage remains within fixed budget")
		check(variants.size()==6,"All six corporate campaigns appear")
		check(districts.size()>=12,"Signage covers most of the lap")
		check(scenery.local_lights.size()<=16,"Sign density does not multiply local lights")
		check(neon.sign_renderers.size()<64,"Panels share spatial draw batches")
		neon.animate(12.5);check(neon.sign_material.get_shader_parameter("race_time")==12.5,"Animation follows the pausable race clock")
		print("NEON seed=",seed_value," signs=",neon.signs.size()," styles=",variants.size()," districts=",districts.size()," batches=",neon.sign_renderers.size())
		parent.free()
	print("NEON_TESTS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
