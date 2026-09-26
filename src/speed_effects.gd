extends Control
## A soft peripheral pressure shade; speed comes from camera/lens and scene blur.
var travel:=0.
var strength:=0.
var edge:GradientTexture2D

func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var gradient:=Gradient.new()
	gradient.colors=PackedColorArray([Color(.015,.025,.045,1.),Color(.015,.025,.045,0.)])
	edge=GradientTexture2D.new()
	edge.gradient=gradient
	edge.width=128
	edge.height=1
	edge.fill_from=Vector2.ZERO
	edge.fill_to=Vector2(1,0)

func update_effects(camera:Camera3D,dt:float,active:bool,_performance:bool=false)->void:
	visible=active
	if not active: return
	var rush:float=camera.get_meta("speed_rush",0.)
	var boost:float=camera.get_meta("speed_boost",0.)
	var surge:float=camera.get_meta("speed_surge",0.)
	strength=rush*(boost*.085+surge*.025)
	travel=fposmod(travel+minf(dt,.05)*float(camera.get_meta("speed_velocity",0.))/145.,1024.)
	queue_redraw()

func _draw()->void:
	if strength<.001 or edge==null: return
	var width:=size.x*.15
	draw_texture_rect(edge,Rect2(0,0,width,size.y),false,Color(1,1,1,strength))
	draw_set_transform(Vector2(size.x,0),0,Vector2(-1,1))
	draw_texture_rect(edge,Rect2(0,0,width,size.y),false,Color(1,1,1,strength))
	draw_set_transform(Vector2.ZERO)
