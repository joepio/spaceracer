extends Node3D
## Short, localized hit bursts reuse the crash fire/smoke at a much smaller scale.
const Blast=preload("res://src/blast_vfx.gd")
const LIFE:=.55
var blast:Node3D
var debris:MultiMesh
var debris_mesh:MultiMeshInstance3D
var last_id:=-1
var chips:Array[Dictionary]=[]

static func record(p:Dictionary,frame:Transform3D,local_hit:Vector3,damage:float)->void:
	if damage<.1: return
	p.impact_id=int(p.get("impact_id",0))+1;p.impact_age=0.
	p.impact_frame=Transform3D(frame.basis,frame*local_hit)
	p.impact_size=.7+sqrt(clampf(damage/38.,0.,1.))*.65
	p.impact_velocity=p.air_velocity if p.airborne else p.ground_velocity
	if p.impact_velocity.length_squared()<.01: p.impact_velocity=frame.basis.z*p.speed
	p.impact_out=frame.basis*(Vector3(local_hit.x,1.8,local_hit.z).normalized())

func _ready()->void:
	blast=Blast.new();add_child(blast)
	debris=MultiMesh.new();debris.transform_format=MultiMesh.TRANSFORM_3D
	var shard:=BoxMesh.new();shard.size=Vector3(.24,.055,.42);debris.mesh=shard;debris.instance_count=7
	debris_mesh=MultiMeshInstance3D.new();debris_mesh.multimesh=debris;debris_mesh.layers=2
	debris_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var metal:=StandardMaterial3D.new();metal.albedo_color=Color("879aa9");metal.metallic=.7;metal.roughness=.3
	debris_mesh.material_override=metal;add_child(debris_mesh);visible=false

func show_hit(p:Dictionary)->void:
	var age:float=p.get("impact_age",LIFE)
	visible=p.get("impact_id",0)>0 and age<LIFE and not p.crashed
	if not visible: return
	var id:int=p.impact_id*97+p.slot
	if last_id!=id:
		last_id=id;chips.clear()
		var rng:=RandomNumberGenerator.new();rng.seed=id+631
		for i in range(7):
			chips.append({"velocity":Vector3(rng.randf_range(-6.,6.),rng.randf_range(2.,9.),rng.randf_range(-6.,6.)),
				"axis":Vector3(rng.randf_range(-1.,1.),rng.randf_range(-1.,1.),rng.randf_range(-1.,1.)).normalized(),
				"spin":rng.randf_range(8.,22.),"size":rng.randf_range(.65,1.35)})
	var frame:Transform3D=p.impact_frame
	var travel:Vector3=p.impact_velocity*age
	blast.show_blast(id,frame.origin+travel*.92,age*2.4,p.impact_size)
	blast.heat.visible=false
	blast.flash.visible=age<.09
	blast.flash.omni_range=6.;blast.flash.light_energy=2.*(1.-clampf(age/.09,0.,1.))
	for i in range(chips.size()):
		var chip:Dictionary=chips[i]
		var location:Vector3=frame.origin+travel*.9+(frame.basis*chip.velocity+p.impact_out*8.)*age+Vector3.DOWN*12.*age*age
		var scale_value:float=chip.size*p.impact_size*(1.-smoothstep(.32,LIFE,age))
		var rotation:=frame.basis*Basis(chip.axis,age*chip.spin)
		debris.set_instance_transform(i,Transform3D(rotation.scaled(Vector3.ONE*maxf(.001,scale_value)),location))
