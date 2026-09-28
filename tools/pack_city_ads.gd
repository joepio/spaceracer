extends SceneTree
## Mechanical atlas packing only; generated source posters remain unmodified.
func _initialize()->void:
	var names:=["sable","soma","tally","veil","monolith","aperture"]
	var atlas:=Image.create(1536,2048,false,Image.FORMAT_RGB8)
	for i in range(names.size()):
		var poster:=Image.load_from_file("res://docs/city-advertising/"+names[i]+".png")
		assert(poster!=null)
		poster.convert(Image.FORMAT_RGB8)
		poster.resize(512,1024,Image.INTERPOLATE_LANCZOS)
		atlas.blit_rect(poster,Rect2i(0,0,512,1024),Vector2i((i%3)*512,(i/3)*1024))
	assert(atlas.save_png("res://assets/corporate-posters.png")==OK)
	print("Packed six corporate posters: 1536x2048")
	quit()
