extends SceneTree
const S=preload("res://scripts/services/session.gd")
const DB=preload("res://scripts/services/game_data.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for verb in ["buy","sell","equip","rest","wake"]:
		var s:=S.new();s.test_mode=true;s.create_character("保存回滚兔","bunny","bow_rose");s.test_mode=false;s.save_path="res://.qa-artifacts/missing-"+str(Time.get_ticks_usec())+"/save.json"
		s.authority.add("carrot",4);s.authority.add("beret_sage",1)
		var position_: Vector2=DB.shops().farm;s.state().player_position=[position_.x,.2,position_.y+2.]
		var args:={"shop":"farm","item":"seed_carrot"}
		if verb=="sell":args.item="carrot"
		if verb=="equip":args={"item":"beret_sage","slot":"head"}
		if verb=="rest":var p: Vector2=DB.facilities().home_bed;s.state().player_position=[p.x,.2,p.y];args={"target":"home_bed"}
		if verb=="wake":s.state().rest_mode="sleep";s.state().rest_bed="home_bed";s.authority.sleeping=true
		var before:=s.snapshot();var revision: int=s.authority.revision;var seen: Dictionary=s.authority.seen_commands.duplicate(true);var rng: int=s.authority.reward_random.state;var result:=s.dispatch(verb,args)
		check(not result.ok and s.snapshot()==before,"Failed save rejects and restores all assets/pose: "+verb)
		check(s.authority.revision==revision and s.authority.seen_commands==seen and s.authority.reward_random.state==rng,"Failed save restores revision, command cache and random state: "+verb)
		s.test_mode=true;s.free()
	print("SAVE_TRANSACTIONS_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
