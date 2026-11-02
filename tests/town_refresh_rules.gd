extends SceneTree
const DB=preload("res://scripts/services/game_data.gd")
const A=preload("res://scripts/services/local_authority.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var a=A.new();var counts: Dictionary={};var deadlines: Array=[]
	for r in DB.resources():
		counts[r.item]=counts.get(r.item,0)+1
		check(Vector2(r.x,r.z/.88).length()<52,"Spawn inside island "+r.id)
		var point:=Vector2(r.x,r.z);a.state.player_position=[point.x,.1,point.y]
		var tool: String=DB.item(r.item).get("tool","")
		if tool!="":
			a.state.inventory.erase(tool)
			check(not a.execute({"verb":"gather","target":r.id}).ok,"Missing tool rejected "+r.id);a.add(tool,1)
		a.state.stamina_recovery_elapsed=0.0
		var before: int=a.state.experience
		var stamina: float=a.state.stamina
		check(a.execute({"verb":"gather","target":r.id}).ok,"Gather starts "+r.id)
		check(is_equal_approx(a.job.duration,2.0/1.01),"Base two seconds plus level-one speed "+r.id)
		a.tick(2.0)
		check(not a.state.resources[r.id].available and a.state.experience==before+1 and a.state.stamina==stamina-1,"Single reward and work stamina "+r.id)
		var wait: float=a.state.resources[r.id].respawn_at-a.state.time
		check(wait>=3600 and wait<=7200,"Game-time 1–2 day deadline "+r.id)
		deadlines.append(wait)
		if tool!="": check(a.count(tool)>0,"Permanent tool "+r.id)
	check(counts=={"limestone":5,"copper":5,"branch":5,"orange":4},"Exactly five of each ground resource and four fruit trees")
	check(deadlines.max()-deadlines.min()>2000,"Staggered refresh times")
	var fruit:=DB.resource("city_orange_0")
	a.state.player_position=[fruit.x,.1,fruit.z];a.state.resources[fruit.id].available=true
	a.state.attributes.harvest=.25
	check(a.execute({"verb":"gather","target":fruit.id}).ok and is_equal_approx(a.job.duration,2.0/1.26),"Oranges consume harvest attribute and planting speed")
	a.tick(.4);var count_before:=a.count("orange");a.execute({"verb":"cancel"})
	check(a.count("orange")==count_before and a.state.resources[fruit.id].available,"Cancelled picking keeps fruit")
	a.state.food_effect={};a.state.time=a.state.resources.resource_00.respawn_at-.01;a.tick(.005)
	check(not a.state.resources.resource_00.available,"No early respawn")
	a.tick(.01);check(a.state.resources.resource_00.available and a.state.resources.resource_00.generation==1,"Respawn at saved deadline")
	var session=load("res://scripts/services/session.gd").new()
	var restored=session.restore_state(a.state)
	check(restored.state.resources==a.state.resources,"Resource deadlines and generations survive save restore")
	session.settings.fps_limit_enabled=false;session.settings.fps_limit=90;session.settings.background_throttle=false
	session.save_path="user://town_refresh_qa.json";session.test_mode=false
	check(session.save_game(),"Write independent test save")
	var loaded=load("res://scripts/services/session.gd").new();loaded.save_path=session.save_path;loaded.load_save()
	check(not loaded.settings.fps_limit_enabled and loaded.settings.fps_limit==90 and not loaded.settings.background_throttle,"Power choices persist through save/load")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(session.save_path+suffix): DirAccess.remove_absolute(session.save_path+suffix)
	loaded.free();session.free()
	print("TOWN_REFRESH_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
