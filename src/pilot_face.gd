extends RefCounted
## GameNight face coordinates are anchored to the head, never painted bounds.
var signature:Array=[]
var artwork:Texture2D
var decal:Texture2D
var origin:=Vector2(24,28)
var revision:=0

static func decode(payload:Variant)->Image:
	if payload is String:
		if payload.is_empty() or payload.length()>1048576: return null
		var parser:=JSON.new()
		if parser.parse(payload)!=OK: return null
		payload=parser.data
	var legacy:bool=payload is Array
	if legacy:
		var side:=int(sqrt(payload.size()))
		payload={"v":1,"w":side,"h":side,"px":payload}
	if not payload is Dictionary or payload.get("v",0)!=1: return null
	var w:=int(payload.get("w",0));var h:=int(payload.get("h",0))
	var pixels:Variant=payload.get("px",[])
	if w<1 or h<1 or w>256 or h>256 or not pixels is Array or pixels.size()!=w*h: return null
	var image:=Image.create(w,h,false,Image.FORMAT_RGBA8)
	for i in range(pixels.size()):
		var pixel:Variant=pixels[i]
		if pixel==null or (legacy and pixel=="#0f172a"): continue
		if not pixel is String or pixel.length()!=7 or not pixel.begins_with("#") or not pixel.substr(1).is_valid_hex_number(): return null
		image.set_pixel(i%w,i/w,Color.html(pixel))
	return image

static func head_origin(size:Vector2i)->Vector2:
	return Vector2(2. if size.x==16 else (10. if size.x==32 else size.x*.5),5. if size.y==16 else (13. if size.y==32 else size.y*.5+4.))

func update(profile:Dictionary)->bool:
	var next:Array=[profile.get("avatar",""),profile.get("skin_color",""),profile.get("color","")]
	if next[0]==null: next[0]=""
	if next==signature and decal!=null: return false
	signature=next.duplicate(true);revision+=1
	var art:=decode(next[0])
	artwork=ImageTexture.create_from_image(art) if art!=null else null
	origin=head_origin(art.get_size()) if art!=null else Vector2(24,28)
	# Supersampled skin/rim with crisp pixel artwork. This is baked only on a
	# profile change; the ship's opaque material samples it without extra draws.
	var canvas:=Vector2i(48,48) if art==null else Vector2i(maxi(48,art.get_width()),maxi(48,art.get_height()))
	var center:=head_origin(canvas)
	var image:=Image.create(canvas.x*4,canvas.y*4,false,Image.FORMAT_RGBA8)
	var skin:=Color.from_string(str(next[1]),Color("f5e9be"))
	var rim:=Color.from_string(str(next[2]),Color("6fe5de"))
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var point:=(Vector2(x,y)+Vector2.ONE*.5)/4.
			var distance:=point.distance_to(center)
			if distance<13.:
				var ink:=skin if distance<12. else rim
				ink.a=clampf((13.-distance)*4.,0.,1.)
				image.set_pixel(x,y,ink)
	if art!=null:
		var enlarged:=art.duplicate();enlarged.resize(art.get_width()*4,art.get_height()*4,Image.INTERPOLATE_NEAREST)
		image.blend_rect(enlarged,Rect2i(Vector2i.ZERO,enlarged.get_size()),Vector2i((center-origin)*4.))
	else:
		var dark:=Color("1a2033")
		for rect in [Rect2i(19,25,3,3),Rect2i(27,25,3,3),Rect2i(21,33,7,1)]:
			image.fill_rect(Rect2i(rect.position*4,rect.size*4),dark)
	image.generate_mipmaps()
	decal=ImageTexture.create_from_image(image)
	return true
