extends Node3D
## Short, localized hit bursts reuse the crash fire/smoke at a much smaller scale.
const Blast=preload("res://src/blast_vfx.gd")
const LIFE:=.55
var blast:Node3D

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
	visible=false

func show_hit(p:Dictionary)->void:
	var age:float=p.get("impact_age",LIFE)
	visible=p.get("impact_id",0)>0 and age<LIFE and not p.crashed
	if not visible: return
	var id:int=p.impact_id*97+p.slot
	var frame:Transform3D=p.impact_frame
	var travel:Vector3=p.impact_velocity*age
	blast.show_blast(id,frame.origin+travel*.92,age*2.4,p.impact_size)
	blast.heat.visible=false
	blast.flash.visible=age<.09
	blast.flash.omni_range=6.;blast.flash.light_energy=2.*(1.-clampf(age/.09,0.,1.))
