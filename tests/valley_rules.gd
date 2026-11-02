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
	var a=A.new();var coins: int=a.state.coins
	for skill in a.state.skills:
		a.state.skills[skill]=3;a.state.skill_experience[skill]=preload("res://scripts/services/character_stats.gd").skill_start(3)
	check(not a.execute({"verb":"travel","destination":"valley"}).ok,"Travel only at dock")
	a.state.player_position=[13,.2,41.5];a.state.coins=9
	check(not a.execute({"verb":"travel","destination":"valley"}).ok and a.state.map_id=="city" and a.state.coins==9,"No money: no debit or teleport")
	a.state.coins=coins
	check(a.execute({"verb":"travel","destination":"valley"}).ok and a.state.map_id=="valley" and a.state.coins==coins-10,"Outward fare exactly ten")
	check(not a.execute({"verb":"buy","shop":"tools","item":"copper_axe"}).ok,"Town commerce gated by map")
	var city: Dictionary=DB.resources()[0];a.state.player_position=[city.x,0,city.z]
	check(not a.execute({"verb":"gather","target":city.id}).ok,"Reject gathering resource on another map")
	var counts: Dictionary={};var refreshed: Array=[]
	for r in DB.resources("valley"):
		counts[r.item]=counts.get(r.item,0)+1
		a.state.player_position=[r.x,r.y,r.z];a.state.stamina=100
		var tool: String=DB.item(r.item).get("tool","")
		if tool!="":
			a.state.inventory.erase(tool)
			check(not a.execute({"verb":"gather","target":r.id}).ok,"Tool gate "+r.id);a.add(tool,1)
		var before:=a.count(r.item);var xp: int=a.state.experience
		check(a.execute({"verb":"gather","target":r.id}).ok,"Start "+r.id)
		var seconds: float=(5.0 if r.item in ["birch","iron","sandstone"] else 2.0)/1.03
		check(is_equal_approx(a.job.duration,seconds),"Correct real action duration "+r.id)
		a.tick(seconds-.01);check(a.count(r.item)==before,"No early reward "+r.id);a.tick(.02)
		var gain:=a.count(r.item)-before
		check(gain in [3,4,5] if r.item=="orange" else gain in [1,2],"Yield "+r.id)
		check(a.state.experience==xp+(2 if r.item in ["birch","iron","sandstone"] else 1) and not a.state.resources[r.id].available,"XP and hidden source "+r.id)
		var wait: float=a.state.resources[r.id].respawn_at-a.state.time
		check(wait>=3600 and wait<=7200,"One-to-two game day refresh "+r.id)
		if tool!="": check(a.count(tool)==1,"Tool retained "+r.id)
		refreshed.append(wait)
	check(counts=={"branch":5,"birch":5,"orange":5,"copper":4,"iron":2,"limestone":4,"sandstone":2},"Exact valley resource allocation")
	check(refreshed.max()-refreshed.min()>2000,"Staggered valley regrowth")
	a.state.player_position=[-5.8,.2,47.2];var before_coins: int=a.state.coins
	check(a.execute({"verb":"travel","destination":"city"}).ok and a.state.coins==before_coins,"Free return")
	check(a.state.player_position==[13,.2,39.5],"Return arrives on city pier")
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	check(session.create_character("林间熊猫","panda","scarf_green").ok,"Create named panda")
	session.state().map_id="valley";session.state().player_position=[22,4.2,-31];session.state().inventory.copper_axe=1
	var panda_id: String=session.active_character_id;session.sync_current()
	check(session.create_character("海边小兔","bunny","bow_sage").ok and session.state().map_id=="city","New character begins in city")
	check(session.select_character(panda_id).ok and session.state().map_id=="valley" and session.state().player_position==[22,4.2,-31],"Per-character map and position retained")
	check(session.scene_path()=="res://scenes/valley.tscn","Resume chooses saved map")
	var old: Dictionary=session.snapshot();old.erase("map_id");var restored=session.restore_state(old)
	check(restored.state.map_id=="city","Legacy save defaults to city")
	check(restored.state.resources.size()==46,"Both map resources share one saved world")
	session.state().player_position=[-5.8,.18,47.2]
	session.save_path="user://valley_progress_qa.json";session.test_mode=false
	check(session.save_game(),"Write isolated valley save")
	var loaded=load("res://scripts/services/session.gd").new();loaded.save_path=session.save_path;loaded.load_save()
	check(loaded.state().map_id=="valley" and loaded.authority.count("copper_axe")==1 and loaded.state().resources.size()==46,"Disk save restores valley and shared world")
	check(loaded.state().player_position==[-5.8,.18,47.2],"Extended harbor position survives disk restore")
	loaded.free()
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(session.save_path+suffix): DirAccess.remove_absolute(session.save_path+suffix)
	session.state().map_id="city";session.state().player_position=[13,.2,41.5];var previous: int=session.state().coins
	session.save_path="/dev/null/tutu_valley_qa.json"
	var rejected: Dictionary=session.dispatch("travel",{"destination":"valley"})
	check(not rejected.ok and session.state().map_id=="city" and session.state().coins==previous,"Failed travel save rolls back fare and map")
	session.test_mode=true
	print("VALLEY_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
