extends SceneTree
const Race=preload("res://src/race.gd")
var failures:=0
func check(ok:bool,message:String)->void:
 if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
 var roster:Array=[]
 for i in range(6):roster.append({"slot":i,"bot":true})
 var first:=Race.new(roster,35,1,"normal","city",12345)
 var repeat:=Race.new(roster,35,1,"normal","city",12345)
 var different:=Race.new(roster,35,1,"normal","city",54321)
 check(first.track.length==different.track.length,"Driver seed never changes the shared track")
 var variations:=0
 for i in range(6):
  check(first.bot(first.racers[i])==repeat.bot(repeat.racers[i]),"AI seed reproduces decisions for debugging")
  if first.racers[i].ai.line_goal!=different.racers[i].ai.line_goal:variations+=1
 check(variations>=4,"A rematch changes most drivers' plans")
 var all_pickups:=0;var chases:=0;var skips:=0;var mistakes:=0;var great:=0;var falls:=0;var total_finished:=0
 for difficulty in ["normal","hard"]:
  for code in [31,33,35]:
   var race:=Race.new(roster,code,1,difficulty,"city",12345)
   var pickups:=0;var crashes:=0;var race_falls:=0
   var ranges:Array=[]
   for i in range(6):ranges.append(Vector2(100.,-100.))
   for tick in range(120*125):
    var inputs:Array=[];var prior:Array=[]
    for p in race.racers:
     inputs.append(race.bot(p));prior.append([p.weapon_acquired,p.crash_id,p.airborne])
    race.step(1./120.,inputs)
    for i in range(6):
     var p:Dictionary=race.racers[i]
     if p.weapon_acquired>prior[i][0]:pickups+=1
     crashes+=p.crash_id-prior[i][1]
     if p.airborne and not prior[i][2] and not race.track.sample(p.distance).air_gap and race.track.jump_at(p.distance,100.).is_empty():race_falls+=1
     ranges[i].x=minf(ranges[i].x,p.x);ranges[i].y=maxf(ranges[i].y,p.x)
    if race.over:break
   var finished:=0
   for p in race.racers:
    chases+=p.ai.pickup_chases;skips+=p.ai.pickup_skips;mistakes+=p.ai.mistakes;great+=p.ai.great_corners
    if p.finished:finished+=1
    check(is_finite(p.x) and is_finite(p.speed),"Pilot state remains finite")
   total_finished+=finished;all_pickups+=pickups;falls+=race_falls
   check(finished>=4,"Most of the pack finishes after tactical mistakes: %s %d"%[difficulty,code])
   check(ranges.filter(func(r):return r.y-r.x>12.).size()>=4,"Drivers use different lines instead of sitting in one lane")
   print("AI_VARIETY ",JSON.stringify({"difficulty":difficulty,"seed":code,"finishers":finished,"pickups":pickups,"crashes":crashes,"falls":race_falls,"time":race.clock}))
 check(chases>5 and skips>5,"Drivers both pursue and decline pickups")
 check(all_pickups>5,"Tactical item pursuit results in actual pickups")
 check(mistakes>5 and great>5,"Races contain both poor and excellent corner judgements")
 check(falls>0,"Late corner mistakes can cause real departures from unguarded road")
 check(total_finished>=30,"The varied pack remains competent across track types")
 print("AI_VARIETY_TOTAL ",JSON.stringify({"finishers":total_finished,"pickups":all_pickups,"chases":chases,"skips":skips,"mistakes":mistakes,"great_corners":great,"falls":falls,"failures":failures}))
 quit(1 if failures else 0)
