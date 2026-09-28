extends SceneTree
const Face=preload("res://src/pilot_face.gd")
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok: failures+=1;push_error(message)
func _initialize()->void:
	var pixels:Array=[];pixels.resize(48*48);pixels[8*48+24]="#ff00aa"
	var profile:={"avatar":JSON.stringify({"v":1,"w":48,"h":48,"px":pixels}),"skin_color":"#a87c62","color":"#45dddd"}
	var face:=Face.new()
	check(face.update(profile),"First profile creates a decal")
	check(face.artwork.get_image().get_pixel(24,8).is_equal_approx(Color("ff00aa")),"Transparent artwork retains pixels above head")
	check(face.decal.get_image().get_pixel(96,32).is_equal_approx(Color("ff00aa")),"Hat preserved in hull composite")
	check(face.decal.get_image().get_pixel(96,112).is_equal_approx(Color("a87c62")),"Skin supplied by player")
	check(not face.update(profile) and face.revision==1,"Stable profile does not rebuild texture")
	profile.skin_color="#552211";face.update(profile)
	check(face.revision==2,"Live profile changes refresh decal")
	for invalid in ["broken",{"v":2}, {"v":1,"w":2560,"h":1,"px":[]}, {"v":1,"w":1,"h":1,"px":["oops"]}]:
		check(Face.decode(invalid)==null,"Malformed avatars fall back safely")
	check(Face.head_origin(Vector2i(16,16))==Vector2(2,5),"Legacy head anchor")
	print("PILOT_FACE_TESTS failures=",failures);quit(1 if failures else 0)
