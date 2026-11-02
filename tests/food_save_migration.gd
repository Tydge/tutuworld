extends SceneTree
const SessionScript=preload("res://scripts/services/session.gd")
const Authority=preload("res://scripts/services/local_authority.gd")
var failures: Array[String]=[]
var checks:=0
var path:="user://qa_food_migration.json"
func check(ok: bool,label_: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func write_save(state_: Dictionary,ago: float=0) -> Node:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":2,"saved_at":Time.get_unix_time_from_system()-ago,"state":state_,"settings":{"player_species":"cat_teacher"}}))
	file.close()
	var restored:=SessionScript.new()
	restored.save_path=path
	restored.load_save()
	return restored
func _initialize() -> void:
	var authority:=Authority.new()
	var legacy: Dictionary=authority.state.duplicate(true)
	legacy.erase("food_effect")
	legacy.coins=827
	legacy.inventory.bell_red=1
	legacy.equipment.neck="bell_red"
	var restored:=write_save(legacy)
	check(restored.state().food_effect.is_empty(),"Legacy city save without food effect loads empty bonus")
	check(restored.state().coins==827 and restored.state().inventory.seed_carrot==3 and restored.state().equipment.neck=="bell_red","Legacy money, seeds and neckwear preserved")
	check(restored.settings.player_species=="cat_teacher","Saved species preserved")
	restored.free()
	legacy.food_effect={"item":"food_carrot_soup","expires_at":float(legacy.time)+3600}
	restored=write_save(legacy,60)
	check(restored.authority.multiplier("move")>1 and restored.state().time>=legacy.time+59,"Unexpired food effect survives offline minute")
	restored.free()
	restored=write_save(legacy,3700)
	check(restored.state().food_effect.is_empty() and restored.authority.multiplier("move")==1,"Food expires after offline game day")
	restored.free()
	legacy.food_effect={"item":"not_a_food","expires_at":9999999}
	restored=write_save(legacy)
	check(restored.state().food_effect.is_empty(),"Unknown food effect is ignored safely")
	restored.free()
	DirAccess.remove_absolute(path)
	print("FOOD_SAVE_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
