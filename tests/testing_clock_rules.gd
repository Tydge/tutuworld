extends SceneTree
const S=preload("res://scripts/services/session.gd")
const DB=preload("res://scripts/services/game_data.gd")
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func run() -> void:
	var s:=S.new();s.name="ClockRules";root.add_child(s)
	check(s.can_adjust_time(),"Offline local authority allows the debug clock")
	var first: Dictionary=s.create_character("晨兔","bunny","vest_sage")
	check(first.ok and s.create_character("夜猫","cat_teacher","vest_sage").ok,"Creates both species sharing this clock")
	var food:=""
	for id in DB.catalog().items:
		if DB.item(id).kind=="food": food=id;break
	var old_time:=4*3600.0+1200
	s.state().time=old_time
	s.state().food_effect={"item":food,"expires_at":old_time+600}
	s.state().plots.plot_00={"crop":"carrot","growth":120.0,"water_stage":0,"weed_stage":0}
	s.state().resources.resource_00={"available":false,"respawn_at":old_time+120,"generation":2}
	s.characters[first.id].stamina=0.0;s.characters[first.id].last_seen=old_time-15;s.characters[first.id].stamina_recorded_at=s.real_time_now()-60
	s.characters[first.id].food_effect={"item":food,"expires_at":old_time+400}
	s.authority.job={"verb":"craft","elapsed":1.5,"duration":7.0,"target":"kitchen","item":food}
	var items: Dictionary=s.state().inventory.duplicate(true)
	var job: Dictionary=s.job().duplicate(true)
	check(s.set_testing_time(22,15).ok,"Can select an exact hour and minute")
	var now: float=s.state().time
	check(is_equal_approx(now,4*3600+3337.5) and int(now/3600)==4,"Sets 22:15 on the same day, without skipping a date")
	check(s.world.time==now,"Shared world and active snapshot agree on the clock")
	check(s.state().plots.plot_00.growth==120 and s.job()==job,"Changing the clock does not advance crops or real-time work")
	check(s.state().inventory==items and s.state().experience==0,"Clock changes grant no items or work experience")
	check(is_equal_approx(s.state().food_effect.expires_at-now,600),"Active food keeps its remaining duration")
	check(is_equal_approx(s.state().resources.resource_00.respawn_at-now,120),"Depleted gathering nodes keep their remaining respawn duration")
	check(is_equal_approx(s.characters[first.id].food_effect.expires_at-now,400),"Inactive character food keeps its remaining duration")
	check(is_equal_approx(s.characters[first.id].stamina,2),"Inactive rest already earned is settled before moving the clock")
	check(s.set_testing_time(0,0).ok and s.state().time==4*3600,"Rewind stays on the same date")
	check(is_equal_approx(s.state().food_effect.expires_at-s.state().time,600),"Rewinding neither deletes nor extends a buff")
	check(s.set_testing_time(23,59).ok and int(s.state().time/3600)==4,"23:59 does not roll into tomorrow")
	var before: Dictionary=s.snapshot()
	for moment in [[24,0],[-1,0],[12,60],[12,-1]]: check(not s.set_testing_time(moment[0],moment[1]).ok,"Reject invalid time "+str(moment))
	check(s.snapshot()==before,"Invalid input leaves state unchanged")
	s.transport_mode="remote"
	check(not s.can_adjust_time() and not s.set_testing_time(12,0).ok,"Multiplayer transport rejects local time changes")
	s.transport_mode="local_authority";s.server_endpoint="wss://example.invalid"
	check(not s.can_adjust_time() and not s.set_testing_time(12,0).ok,"A configured online session also rejects time changes")
	s.server_endpoint=""
	s.authority.job.clear()
	s.test_mode=false;s.save_path="/missing-tutu-clock-test/path/save.json"
	var old_characters: Dictionary=s.characters.duplicate(true)
	before=s.snapshot()
	check(not s.set_testing_time(6,0).ok and s.snapshot()==before and s.characters==old_characters,"A save failure rolls the clock and character records back")
	var fixture: String="/tmp/tutu-clock-%d.json"%OS.get_process_id()
	s.save_path=fixture
	check(s.set_testing_time(18,30).ok,"Adjusted time saves through the normal atomic save path")
	var loaded:=S.new();root.add_child(loaded);loaded.save_path=fixture;loaded.load_save()
	check(absf(loaded.state().time-s.state().time)<.1,"Adjusted clock survives reload")
	check(loaded.select_character(first.id).ok and absf(loaded.state().food_effect.expires_at-loaded.state().time-400)<.1,"Switching to the other species preserves its food and the shared adjusted clock")
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(fixture+suffix): DirAccess.remove_absolute(fixture+suffix)
	s.test_mode=true
	s.state().time=1200;s.state().food_effect={"item":food,"expires_at":1800}
	s.characters[first.id].stamina=0;s.characters[first.id].last_seen=1185;s.characters[first.id].stamina_recovery_elapsed=0;s.characters[first.id].stamina_recorded_at=s.real_time_now()-60
	s.characters[first.id].food_effect={"item":food,"expires_at":1600}
	check(s.set_testing_time(0,0).ok and s.state().time==0,"Can rewind the first day all the way to midnight")
	check(s.characters[first.id].last_seen==0 and is_equal_approx(s.characters[first.id].stamina,2),"First-day rewind keeps nonnegative timestamps and already-earned rest")
	print("TESTING_CLOCK_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
