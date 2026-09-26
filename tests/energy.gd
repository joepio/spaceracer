extends SceneTree
const Race=preload("res://src/race.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	for hz in [30,60,120]:
		var race:=Race.new([{"slot":0}],31)
		race.countdown=0.
		var p:Dictionary=race.racers[0]
		p.energy=50.;p.energy_previous=50.
		for tick in range(hz*12): race.step(1./hz,[{}])
		check(is_equal_approx(p.energy,65.),"Two-second delay then ten seconds of slow refill, Hz=%d"%hz)
		p.energy-=10.
		race.step(1./hz,[{}])
		var after_hit:float=p.energy
		for tick in range(hz*2): race.step(1./hz,[{}])
		check(is_equal_approx(p.energy,after_hit),"Damage pauses refill for two seconds")
		for tick in range(hz): race.step(1./hz,[{}])
		check(is_equal_approx(p.energy,after_hit+1.5),"Refill resumes after damage")
	var race:=Race.new([{"slot":0}],31)
	var p:Dictionary=race.racers[0]
	p.energy=50.;p.energy_previous=50.;p.energy_refill_delay=0.
	race.step(1.,[{}])
	check(p.energy==50.,"Countdown does not refill energy")
	race.countdown=0.;race.over=true;race.step(1.,[{}])
	check(p.energy==50.,"Completed race does not refill energy")
	for field in ["boost","warp_time","emp_time","crashed","recovery","finished"]:
		var sample:Dictionary=p.duplicate(true)
		sample[field]=true if field in ["crashed","finished"] else 1.
		Race.refill_energy(sample,1.)
		check(sample.energy==50. and sample.energy_refill_delay==2.,"Refill waits during "+field)
	p.energy=99.5;p.energy_previous=99.5;p.energy_refill_delay=0.
	Race.refill_energy(p,1.)
	check(p.energy==100.,"Refill caps at full energy")
	p.energy=0.;p.energy_previous=0.;p.energy_refill_delay=0.
	Race.refill_energy(p,1.)
	check(p.energy==0.,"Refill cannot revive a depleted hull")
	print("ENERGY_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
