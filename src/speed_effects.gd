extends Control
## Lightweight per-view near-camera motes. No shared-world particles or lights.
var travel:=0.
var rush:=0.
var boost:=0.
var surge:=0.
var count:=24

func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	clip_contents=true

func update_effects(camera:Camera3D,dt:float,active:bool,performance:bool=false)->void:
	visible=active
	if not active: return
	rush=camera.get_meta("speed_rush",0.)
	boost=camera.get_meta("speed_boost",0.)
	surge=camera.get_meta("speed_surge",0.)
	count=14 if performance else 24
	# Integrate travel so throttle changes cannot teleport existing motes.
	travel=fposmod(travel+minf(dt,.05)*float(camera.get_meta("speed_velocity",0.))/145.,1024.)
	queue_redraw()

func _draw()->void:
	if rush<.04: return
	var origin:=Vector2(.5,.43)*size
	for i in range(count):
		var phase:=fposmod(travel+i*.61803399,1.)
		var angle:=lerpf(-1.12,1.12,fposmod(i*.75487766,.999))
		var direction:=Vector2(cos(angle)*(1. if i%2==0 else -1.),sin(angle)*.8)
		var radius:=.28+phase*phase*.8
		var head:=origin+direction*radius*size
		# Limit streaks to the periphery, leaving the car and racing line clear.
		if head.x>size.x*.31 and head.x<size.x*.69: continue
		var length:float=(.006+.016*rush+.025*boost+.008*surge)*(.25+phase)
		var tail:=head-direction*length*size
		var fade:=smoothstep(0.,.18,phase)*(1.-smoothstep(.8,1.,phase))
		var alpha:=fade*rush*(.09+.22*boost+.04*surge)
		draw_line(tail,head,Color(.7,.84,.94,alpha),1.+boost*.5,true)
		if i%3==0: draw_circle(head,1.,Color(.8,.91,1.,alpha*.8))
