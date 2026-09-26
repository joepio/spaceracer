extends RefCounted
## Bounded rigid fragments, simulated at 60 Hz by the pausable race clock.
const Track=preload("res://src/track.gd")
var pieces:Array[Dictionary]=[]
var age:=0.
var accumulator:=0.
var origin:=Vector3.ZERO
var focus:=Vector3.ZERO

func _init(parts:Array,p:Dictionary)->void:
	origin=p.air_position;focus=origin
	var velocity:Vector3=p.crash_velocity
	var normal:Vector3=p.crash_normal
	if normal.length_squared()>.1 and velocity.dot(normal)<0.:
		velocity=velocity.slide(normal)*.30+normal*minf(24.,-velocity.dot(normal)*.12)
	else: velocity*=.30
	for i in range(parts.size()):
		var part:Dictionary=parts[i]
		var spread:Vector3=part.frame.origin-origin
		var direction:Vector3=(spread+Vector3(sin(i*2.4),1.5,cos(i*1.7))).normalized()
		pieces.append({"frame":part.frame,"half":part.half,
			"velocity":velocity+direction*(7.+i%4*2.)+Vector3.UP*4.,
			"spin":Vector3(sin(i*3.1),cos(i*2.3),sin(i*1.9+1.))*5.,
			"radius":clampf(part.half.length()*.35,.18,1.2),"distance":p.distance,"sleep":false})

static func bounce(piece:Dictionary,normal:Vector3,dt:float)->void:
	var toward:float=piece.velocity.dot(normal)
	if toward<0.:
		piece.velocity-=normal*toward*(1.24 if toward< -3. else 1.)
		piece.spin=piece.spin*.72+normal.cross(piece.velocity)*.035
	var tangent:Vector3=piece.velocity.slide(normal)
	piece.velocity-=tangent*(1.-exp(-dt*9.))
	piece.spin*=exp(-dt*5.)

func step(dt:float,track:RefCounted,distance:float)->void:
	accumulator+=minf(dt,.25)
	while accumulator>=1./60.:
		accumulator-=1./60.
		integrate(1./60.,track,distance)

func integrate(dt:float,track:RefCounted,distance:float)->void:
	age+=dt
	var center:=Vector3.ZERO
	for piece in pieces:
		if not piece.sleep:
			var contacted:=false
			var frame:Transform3D=piece.frame
			var previous:=frame.origin
			piece.velocity=(piece.velocity+Vector3.DOWN*32.*dt)*exp(-dt*.45)
			piece.spin*=exp(-dt*.25)
			var spin:Vector3=piece.spin*dt
			if spin.length_squared()>.000001:
				frame.basis=(Basis(spin.normalized(),spin.length())*frame.basis).orthonormalized()
			frame.origin+=piece.velocity*dt
			if track.obstacles!=null:
				var hit:Dictionary=track.obstacles.trace(previous,frame.origin,piece.radius)
				if not hit.is_empty():
					contacted=true
					frame.origin=hit.position+hit.normal*.03
					bounce(piece,hit.normal,dt)
			var road:Dictionary=track.project(frame.origin,piece.distance,400. if age<.02 else 45.)
			piece.distance=road.distance
			if Track.supported(road.node,road.lateral):
				var up:Vector3=Track.surface_frame(road.node,road.lateral).y
				var surface:Vector3=Track.point(road.node,road.lateral)
				var half:Vector3=piece.half
				var extent:float=absf(up.dot(frame.basis.x))*half.x+absf(up.dot(frame.basis.y))*half.y+absf(up.dot(frame.basis.z))*half.z
				var before:float=(previous-surface).dot(up)
				var height:float=(frame.origin-surface).dot(up)
				if before>=-extent and height<extent and height> -8.:
					contacted=true
					frame.origin+=up*(extent-height+.02)
					bounce(piece,up,dt)
			# Water and the city floor catch the remains; they cannot fall forever.
			var floor_y:float=track.water_level if track.biome=="forest" else -180.
			if frame.origin.y<floor_y+piece.radius:
				contacted=true
				frame.origin.y=floor_y+piece.radius
				bounce(piece,Vector3.UP,dt)
				if track.biome=="forest": piece.velocity*=.65;piece.spin*=.7
			piece.frame=frame
			# Static friction settles slow fragments; never freeze a piece in midair.
			if contacted and age>1. and piece.velocity.length()<(.5 if age<8. else 2.) and piece.spin.length()<.3: piece.sleep=true
		center+=piece.frame.origin
	if not pieces.is_empty(): focus=origin+(center/pieces.size()-origin).limit_length(65.)
