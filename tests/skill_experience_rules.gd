extends SceneTree
const S=preload("res://scripts/services/session.gd")
const Stats=preload("res://scripts/services/character_stats.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var session:=S.new();session.name="Session";root.add_child(session)
	session.create_character("技能兔兔","bunny","bow_sage");var first: String=session.active_character_id
	session.state().skill_experience.mining=Stats.skill_start(3)+7;session.state().skills.mining=3
	check(is_equal_approx(session.authority.action_duration("gather","iron"),5.0/1.03),"Mining level three applies three percent speed")
	session.create_character("技能猫猫","cat_teacher","scarf_red")
	check(session.state().skill_experience.mining==0,"New character has independent skill XP")
	session.select_character(first)
	check(session.state().skill_experience.mining==35 and session.state().skills.mining==3,"Switching preserves new skill progress")
	session.save_path="user://skill_experience_qa.json";session.test_mode=false;session.save_game()
	var loaded:=S.new();loaded.save_path=session.save_path;loaded.load_save()
	check(loaded.state().skill_experience.mining==35 and loaded.state().skills.mining==3,"Disk save preserves exact new XP")
	check(loaded.state().skill_rules_version==Stats.PROGRESSION_VERSION,"Per-character migration version persisted")
	var legacy: Dictionary=session.snapshot();legacy.erase("skill_rules_version");legacy.skill_experience.mining=1000;legacy.skills.mining=20
	var migrated=session.restore_state(legacy)
	check(migrated.state.skills.values().all(func(x): return x==1) and migrated.state.skill_experience.values().all(func(x): return x==0),"Old curve resets five skills to one and zero XP")
	check(migrated.state.coins==legacy.coins and migrated.state.inventory==legacy.inventory,"Reset preserves other character progress")
	legacy.erase("skill_experience");legacy.erase("skills");migrated=session.restore_state(legacy)
	check(migrated.state.skills.values().all(func(x): return x==1),"Missing old skill fields also starts at one")
	loaded.free();session.test_mode=true
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(session.save_path+suffix): DirAccess.remove_absolute(session.save_path+suffix)
	print("SKILL_EXPERIENCE_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
