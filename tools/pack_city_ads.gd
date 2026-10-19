extends SceneTree
## Mechanical atlas packing only; generated source posters remain unmodified.
## The full-size sources live outside the repository (GameNight project archive,
## archive/spaceracer/docs/city-advertising/). Pass their folder after `--`:
##   godot --headless --script res://tools/pack_city_ads.gd -- --sources=/path/to/city-advertising
func _initialize()->void:
	var sources:="res://docs/city-advertising"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sources="): sources=arg.trim_prefix("--sources=")
	var names:=["sable","soma","tally","veil","monolith","aperture"]
	for name in names:
		if not FileAccess.file_exists(sources.path_join(name+".png")):
			push_error("Missing poster source %s. The full-size posters are archived outside the repo (archive/spaceracer/docs/city-advertising/); pass -- --sources=<that folder>." % sources.path_join(name+".png"))
			quit(1)
			return
	var atlas:=Image.create(1536,2048,false,Image.FORMAT_RGB8)
	for i in range(names.size()):
		var poster:=Image.load_from_file(sources.path_join(names[i]+".png"))
		assert(poster!=null)
		poster.convert(Image.FORMAT_RGB8)
		poster.resize(512,1024,Image.INTERPOLATE_LANCZOS)
		atlas.blit_rect(poster,Rect2i(0,0,512,1024),Vector2i((i%3)*512,(i/3)*1024))
	assert(atlas.save_png("res://assets/corporate-posters.png")==OK)
	print("Packed six corporate posters: 1536x2048")
	quit()
