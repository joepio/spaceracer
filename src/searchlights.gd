extends RefCounted
## Rooftop searchlights sweep the night sky above the tallest towers. Visual
## only: additive cones with no lights, shadows or collisions.
const HEIGHT:=1400.
var beams:Array[Dictionary]=[]

static func cone_mesh()->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES:=14
	for side in range(SIDES):
		var a0:=side*TAU/SIDES;var a1:=(side+1)*TAU/SIDES
		for corner in [[a0,0.],[a0,1.],[a1,0.],[a1,0.],[a0,1.],[a1,1.]]:
			var angle:float=corner[0];var v:float=corner[1]
			var radius:=lerpf(1.6,60.,v)
			surface.set_uv(Vector2(angle/TAU,v));surface.set_normal(Vector3(cos(angle),0.,sin(angle)))
			surface.add_vertex(Vector3(cos(angle)*radius,v*HEIGHT,sin(angle)*radius))
	return surface.commit()

func build(parent:Node3D,buildings:Array,seed_value:int)->void:
	var tall:=buildings.duplicate()
	tall.sort_custom(func(a:Dictionary,b:Dictionary):return a.height>b.height)
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value+44017
	var mesh:=cone_mesh()
	var tints:=[Color("cfe3ff"),Color("cfe3ff"),Color("ff9ad5"),Color("8ff2ff")]
	var materials:Array[ShaderMaterial]=[]
	for tint in tints:
		var material:=ShaderMaterial.new();material.shader=load("res://src/searchlight.gdshader")
		material.set_shader_parameter("tint",tint);materials.append(material)
	var used:Array[Vector3]=[]
	for building in tall:
		if beams.size()>=10: break
		var roof:Vector3=building.center+Vector3.UP*building.height
		# Spread the beams across the skyline instead of one cluster.
		var crowded:=false
		for other in used:
			if Vector2(other.x-roof.x,other.z-roof.z).length()<700.: crowded=true
		if crowded: continue
		used.append(roof)
		var beam:=MeshInstance3D.new();beam.name="Searchlight";beam.mesh=mesh
		beam.material_override=materials[beams.size()%materials.size()]
		beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.set_meta("gi_dynamic",true);beam.layers=2
		beam.position=roof
		parent.add_child(beam)
		beams.append({"node":beam,"heading":rng.randf()*TAU,"sweep":rng.randf_range(.5,1.1),
			"speed":rng.randf_range(.18,.32),"phase":rng.randf()*TAU,"tilt":rng.randf_range(.22,.42)})

func animate(time:float)->void:
	for beam in beams:
		var heading:float=beam.heading+sin(time*beam.speed+beam.phase)*beam.sweep
		var tilt:float=beam.tilt+.08*sin(time*beam.speed*1.7+beam.phase*2.)
		beam.node.basis=Basis(Vector3.UP,heading)*Basis(Vector3.RIGHT,tilt)
