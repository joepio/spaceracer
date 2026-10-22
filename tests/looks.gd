extends SceneTree
## Random airframes per race and colours that never repeat between racers.
const World=preload("res://src/world.gd")
const Design=preload("res://src/racer_design.gd")
var failures:=0
var checks:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void:
	var models:=Design.VARIANTS.size()
	var first_models:={}
	for round_index in range(40):
		var racers:Array=[]
		for i in range(6): racers.append({"slot":i,"bot":i>=2})
		World.deal_designs(racers)
		var dealt:={}
		for p in racers.slice(0,models): dealt[p.design]=true
		check(dealt.size()==models,"No model repeats before every model is in the race")
		first_models[racers[0].design]=true
	check(first_models.size()==models,"Player one does not always get the same model")
	# Two humans with the same profile colour, and AI whose slot colours match the humans.
	var racers:Array=[{"slot":0,"bot":false,"color":"#ff617b"},{"slot":1,"bot":false,"color":"#ff617b"},
		{"slot":2,"bot":true},{"slot":3,"bot":true,"color":"#e36c76"},{"slot":4,"bot":true},{"slot":5,"bot":true,"color":"#53ffe0"}]
	World.assign_tints(racers)
	check(racers[0].tint==Color("#ff617b"),"The first human keeps their profile colour")
	for i in range(racers.size()):
		for j in range(i+1,racers.size()):
			var gap:=World.color_gap(racers[i].tint,[racers[j].tint] as Array[Color])
			check(gap>=World.SAME_HUMAN_COLOR,"Racers %d and %d have different colours (gap %.3f)"%[i,j,gap])
	# GameNight guest colours stay as chosen even when they sit near each other.
	var guests:Array=[]
	var palette:=["#4daf7c","#e36c76","#648cdd","#d7ad43","#a67bdd","#49b8bc","#d88950","#cf7aaf"]
	for i in range(8): guests.append({"slot":i,"bot":false,"color":palette[i]})
	World.assign_tints(guests)
	for i in range(8): check(guests[i].tint==Color(palette[i]),"Distinct guest colour %s is kept"%palette[i])
	# A full grid of AI still gets twelve distinct colours.
	var crowd:Array=[]
	for i in range(12): crowd.append({"slot":i,"bot":true})
	World.assign_tints(crowd)
	for i in range(12):
		var others:Array[Color]=[]
		for j in range(12): if j!=i: others.append(crowd[j].tint)
		check(World.color_gap(crowd[i].tint,others)>=.05,"Twelve AI racers never share a colour")
	print("LOOKS_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
