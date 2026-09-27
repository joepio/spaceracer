extends RefCounted
## Authored centreline pieces, selected by the procedural recipe.
static func build(track:RefCounted)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	if track.difficulty=="easy": return result
	var family:int=track.Profiles.index(track.seed_value)
	var recipes:Array=[]
	if family==0: recipes.append(["spiral",.33,.405])
	if family==2: recipes.append(["hairpin",.19,.29])
	# Normal introduces one wider spiral; exposed switchbacks belong to Hard.
	if track.difficulty!="hard" and family!=0: return result
	for recipe in recipes:
		var start:float=recipe[1];var end:float=recipe[2]
		var origin:Vector3=track.base_position(start)
		var finish:Vector3=track.base_position(end)
		var forward:Vector3=finish-origin;forward.y=0.;forward=forward.normalized()
		var right:=forward.cross(Vector3.UP)
		var span:=Vector2(finish.x-origin.x,finish.z-origin.z).length()
		var points:Array[Vector3]=[origin]
		if recipe[0]=="spiral":
			var radius:=95. if track.difficulty=="hard" else 120.
			var entry:=origin+forward*span*.30
			for i in range(25):
				var theta:=TAU*i/24.
				points.append(entry+right*radius*(1.-cos(theta))+forward*radius*sin(theta)+Vector3.UP*170.*i/24.)
			points.append(origin+forward*span*.76+Vector3.UP*125.)
		else:
			var radius:=58.
			for i in range(13):
				var theta:=PI*i/12.
				points.append(origin+forward*(180.+radius*sin(theta))+right*radius*(1.-cos(theta)))
			for i in range(13):
				var theta:=PI*i/12.
				points.append(origin+forward*(60.-radius*sin(theta))+right*(radius*3.-radius*cos(theta))+Vector3.UP*12.)
			points.append(origin+forward*span*.65+right*radius*4.+Vector3.UP*12.)
		points.append(finish)
		var curve:=Curve3D.new();curve.bake_interval=2.
		for i in range(points.size()):
			var tangent:Vector3
			if i==0: tangent=(track.base_position(start+.0001)-origin).normalized()*origin.distance_to(points[1])*.33
			elif i==points.size()-1: tangent=(track.base_position(end+.0001)-finish).normalized()*finish.distance_to(points[i-1])*.33
			else: tangent=(points[i+1]-points[i-1]).normalized()*minf(points[i].distance_to(points[i-1]),points[i].distance_to(points[i+1]))*.34
			curve.add_point(points[i],-tangent,tangent)
		result.append({"kind":recipe[0],"start":start,"end":end,"curve":curve,"length":curve.get_baked_length()})
	return result

static func at(components:Array[Dictionary],u:float)->Dictionary:
	for c in components:
		if u>=c.start and u<c.end: return c
	return {}
