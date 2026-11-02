extends SceneTree
const A=preload("res://scripts/services/local_authority.gd")
const S=preload("res://scripts/services/session.gd")
const DB=preload("res://scripts/services/game_data.gd")
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func run() -> void:
	var a:=A.new()
	check(a.state.stamina==100,"New character starts with 100 points")
	a.running=true;a.tick_stamina(1.4);a.running=false;a.tick_stamina(.4);a.running=true;a.tick_stamina(1.59)
	check(a.state.stamina==100,"Pauses do not charge early")
	a.tick_stamina(.01)
	check(a.state.stamina==99 and a.state.stamina_run_elapsed<.00001,"Three accumulated running seconds cost exactly one point")
	a.running=false;a.state.stamina_recovery_elapsed=0;a.tick_stamina(29.99)
	check(a.state.stamina==99,"Recovery waits for thirty real seconds")
	a.tick_stamina(.01);check(a.state.stamina==100,"Thirty real seconds recover one point")
	a.state.stamina=80;a.state.stamina_recovery_elapsed=0;a.sleeping=true;a.tick_stamina(14.99)
	check(a.state.stamina==80,"Sleep does not award a point early")
	a.tick_stamina(.01);check(a.state.stamina==81,"Sleeping recovers one point per fifteen real seconds")
	a.tick_stamina(9000);check(a.state.stamina==100 and a.state.stamina_recovery_elapsed==0,"Recovery caps and cannot bank time while full")
	a.sleeping=false;a.state.player_position=[22,.1,-6];a.state.inventory.watering_can=1
	check(a.execute({"verb":"plant","target":"plot_00","item":"seed_carrot"}).ok and a.state.stamina==99,"Production reserves exactly one point")
	a.execute({"verb":"cancel"});check(a.state.stamina==100 and a.count("seed_carrot")==3,"Cancelling returns the reserved point and keeps materials")
	a.execute({"verb":"plant","target":"plot_00","item":"seed_carrot"});a.tick(2.01)
	check(a.state.stamina==99 and a.state.experience==1 and a.state.plots.plot_00.crop=="carrot","Success consumes one point once and grants XP")
	a.state.stamina=0
	check(not a.execute({"verb":"water","target":"plot_00"}).ok,"No production starts at zero stamina")
	a.state.stamina=50;a.state.stamina_recovery_elapsed=0
	check(a.execute({"verb":"water","target":"plot_00"}).ok and a.state.stamina==49,"Water uses the same cost")
	a.tick(2.01);check(a.state.stamina==49 and a.count("watering_can")==1,"Permanent watering can is retained")
	var s:=S.new();root.add_child(s)
	s.create_character("耐力兔","bunny","vest_sage")
	s.state().stamina=50;s.state().stamina_run_elapsed=2.8;s.state().stamina_recovery_elapsed=11
	var now:=s.real_time_now()
	s.characters[s.active_character_id]=s.extract(s.state(),s.CHARACTER_KEYS)
	s.characters[s.active_character_id].stamina_recorded_at=now-60
	s.world=s.extract(s.state(),s.WORLD_KEYS)
	s.activate_record(s.active_character_id)
	check(s.state().stamina==52 and s.state().stamina_recovery_elapsed>10.9,"Inactive / offline recovery uses wall-clock age")
	s.authority.running=true;s.authority.tick_stamina(.2)
	check(s.state().stamina==51,"Accumulated running debt survives switching / restoration")
	var before: float=s.state().stamina
	s.set_testing_time(23,59)
	check(s.state().stamina==before,"Changing the game clock cannot grant real-time stamina")
	var fixture: String="/tmp/tutu-stamina-%d.json"%OS.get_process_id()
	s.state().stamina=70;s.state().stamina_run_elapsed=2.5;s.state().stamina_recovery_elapsed=6
	s.save_path=fixture;s.test_mode=false;check(s.save_game(),"New counters save normally")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	data.saved_at=Time.get_unix_time_from_system()-60
	var f:=FileAccess.open(fixture,FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close()
	var loaded:=S.new();root.add_child(loaded);loaded.save_path=fixture;loaded.load_save()
	check(loaded.state().stamina==72 and absf(loaded.state().stamina_run_elapsed-2.5)<.00001,"Offline recovery is applied once and keeps running remainder")
	# Sleeping and its real-time recovery survive a real save/reload for either species.
	for species in ["bunny","cat_teacher"]:
		s.create_character("睡眠"+species,species,"vest_sage")
		s.state().stamina=60;s.state().stamina_recovery_elapsed=4;s.state().rest_mode="sleep";s.state().rest_bed="home_bed";s.authority.sleeping=true
		s.test_mode=false;s.save_game()
		var asleep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture));asleep.saved_at=s.real_time_now()-30
		var sleep_file:=FileAccess.open(fixture,FileAccess.WRITE);sleep_file.store_string(JSON.stringify(asleep));sleep_file.close()
		loaded.load_save()
		check(loaded.authority.sleeping and loaded.state().rest_mode=="sleep" and loaded.state().stamina==62,"Offline bed recovery doubles exactly once: "+species)
		loaded.dispatch("wake");check(not loaded.authority.sleeping,"Saved sleeper can wake: "+species)
		s.state().rest_mode="";s.state().rest_bed="";s.authority.sleeping=false
	s.state().character_name="小青";s.state().player_position=[22,.1,-6];s.state().plots.plot_00={"crop":"","growth":0.0,"water_stage":-1,"weed_stage":-1}
	var named: Dictionary=s.dispatch("plant",{"target":"plot_00","item":"seed_carrot"})
	check(named.message.contains("小青") and not named.message.contains("兔兔"),"Production feedback uses the character name")
	s.dispatch("cancel");s.state().character_name="";s.state().species="cat_teacher"
	check(s.authority.actor_name()=="猫咪","Unnamed cat fallback uses its species")
	s.state().species="bunny";check(s.authority.actor_name()=="兔兔","Unnamed rabbit fallback uses its species")
	# A pending production is deliberately not restored, so its reservation is refunded in the save.
	s.test_mode=true;s.state().player_position=[22,.1,-6];s.state().stamina=70
	s.dispatch("plant",{"target":"plot_00","item":"seed_carrot"});s.sync_current()
	check(s.state().stamina==69 and s.characters[s.active_character_id].stamina==70,"Saving unfinished work preserves its cancellation refund")
	var rest:=A.new();rest.state.player_position=[-32.8,.2,-4.45]
	check(rest.execute({"verb":"rest","target":"home_bed"}).ok and rest.sleeping,"Bed sleep is an authority state")
	rest.state.stamina=70;rest.tick_stamina(15);check(rest.state.stamina==71,"Persistent bed state doubles recovery")
	rest.execute({"verb":"wake"});check(not rest.sleeping and rest.state.rest_mode=="","Wake clears the persistent resting state")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(fixture+suffix): DirAccess.remove_absolute(fixture+suffix)
	s.test_mode=true
	print("STAMINA_REVISION_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
