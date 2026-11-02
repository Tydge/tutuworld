extends SceneTree
const S=preload("res://scripts/services/session.gd")
const A=preload("res://scripts/services/local_authority.gd")
const DB=preload("res://scripts/services/game_data.gd")
var failures: Array[String]=[]
var checks:=0
var save_file:="user://qa_roster_rules.json"
func check(ok: bool,label_: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func cleanup() -> void:
	for suffix in ["",".bak",".v2.bak",".tmp"]: DirAccess.remove_absolute(save_file+suffix)
func _initialize() -> void:
	cleanup()
	var session:=S.new()
	session.save_path=save_file
	session.test_mode=true
	check(session.character_list().is_empty(),"Fresh island has no phantom default character")
	var starters:=DB.starter_clothes()
	check(starters.size()==9,"Nine basic starter clothes")
	for slot in ["head","neck","body"]:
		var count_:=0
		var cheapest:=100000
		for id in DB.catalog().items:
			var item:=DB.item(id)
			if item.get("slot","")==slot: cheapest=mini(cheapest,item.price)
		for id in starters:
			if DB.item(id).slot==slot:
				count_+=1
				check(DB.item(id).price==cheapest,"Starter is a cheapest basic option: "+id)
		check(count_==3,"Three options for "+slot)
	check(not session.create_character("  ","bunny","bow_rose").ok,"Blank name rejected")
	check(not session.create_character("a\nb","bunny","bow_rose").ok,"Control characters rejected")
	check(not session.create_character("1234567890123","bunny","bow_rose").ok,"Overlong name rejected")
	check(not session.create_character("兔","dragon","bow_rose").ok,"Unknown species rejected")
	check(not session.create_character("兔","bunny","pickaxe").ok,"Nonstarter cannot be gifted")
	var first:=session.create_character("  软糖  ","bunny","bow_rose")
	check(first.ok and session.state().character_name=="软糖","Creates a named rabbit with trimmed name")
	var first_id: String=first.id
	check(session.state().inventory.size()==5 and session.authority.count("bow_rose")==1 and session.state().equipment.head=="bow_rose","Exactly one free garment, equipped, alongside normal seeds")
	check(not session.create_character("软糖","cat_teacher","scarf_blue").ok,"Duplicate name rejected without overwriting")
	session.state().experience=17
	session.state().coins=321
	session.authority.add("pickaxe",1)
	session.state().plots.plot_00={"crop":"carrot","growth":0.0,"water_stage":0,"weed_stage":0}
	session.authority.tick(500)
	session.state().stamina=10
	var shared_time: float=session.state().time
	var second:=session.create_character("团子","cat_teacher","scarf_blue")
	check(second.ok and second.id!=first_id and session.settings.player_species=="cat_teacher","Cat has a separate persistent identity")
	var second_id: String=second.id
	check(session.state().plots.plot_00.crop=="carrot" and session.state().plots.plot_00.growth==500 and session.state().time==shared_time,"New character enters the same world and crops")
	check(session.state().experience==0 and session.state().coins==650 and session.authority.count("pickaxe")==0,"Backpack, coins and experience are independent")
	check(session.state().equipment=={"head":"","neck":"scarf_blue","body":""} and session.authority.count("bow_rose")==0,"Starter selection does not grant clothes from other slots")
	session.authority.tick(100)
	session.state().experience=3
	session.authority.add("branch",9)
	session.state().resources.resource_00.available=false
	session.state().resources.resource_00.respawn_at=session.state().time+180
	check(session.select_character(first_id).ok,"Can choose an existing rabbit")
	check(session.state().experience==17 and session.state().coins==321 and session.authority.count("pickaxe")==1 and session.authority.count("branch")==0,"Restores rabbit progress without cat inventory")
	check(session.state().plots.plot_00.growth==600 and not session.state().resources.resource_00.available and session.state().time==shared_time+100,"World growth, resource depletion and clock stay shared")
	check(session.state().stamina==10,"Advancing only the game clock grants no inactive real-time stamina")
	check(session.state().character_name=="软糖" and session.state().equipment.head=="bow_rose","Name and clothing are preserved per character")
	check(not session.select_character("missing").ok,"Invalid selection does not replace active character")
	session.test_mode=false
	check(session.save_game(),"Roster and shared world save atomically")
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(save_file))
	check(data.schema==3 and data.characters.size()==2 and data.world.has("plots") and not data.world.has("inventory") and not data.characters[first_id].has("plots"),"Save separates a single world from character inventories")
	var restored:=S.new()
	restored.save_path=save_file
	restored.load_save()
	check(restored.character_list().size()==2 and restored.state().character_name=="软糖","Multiple characters and active selection survive restart")
	restored.test_mode=true
	restored.select_character(second_id)
	check(restored.state().character_name=="团子" and restored.state().experience==3 and restored.authority.count("branch")==9 and restored.settings.player_species=="cat_teacher","Cat identity and progress survive restart")
	restored.free()
	# Failed creation must leave both current progress and roster intact.
	session.save_path="user://missing_directory_qa/no_save.json"
	var before:=session.snapshot()
	check(not session.create_character("不能丢存档","bunny","vest_honey").ok and session.characters.size()==2 and session.snapshot()==before,"Failed write rolls back character creation")
	session.free()
	# Legacy data migrates without losing inventory, equipment or world progress.
	var legacy:=A.new()
	legacy.state.inventory.bell_red=1
	legacy.state.equipment.neck="bell_red"
	legacy.state.experience=9
	legacy.state.plots.plot_02={"crop":"tomato","growth":42,"water_stage":0,"weed_stage":0}
	var file:=FileAccess.open(save_file,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":2,"saved_at":Time.get_unix_time_from_system(),"settings":{"player_species":"cat_teacher"},"state":legacy.state}))
	file.close()
	restored=S.new()
	restored.save_path=save_file
	restored.load_save()
	check(restored.characters.size()==1 and restored.settings.player_species=="cat_teacher" and restored.state().experience==9 and restored.state().equipment.neck=="bell_red" and restored.state().plots.plot_02.crop=="tomato","Legacy single character and island migrate intact")
	check(restored.save_game() and FileAccess.file_exists(save_file+".v2.bak") and JSON.parse_string(FileAccess.get_file_as_string(save_file+".v2.bak")).schema==2,"First migration keeps a permanent untouched legacy backup")
	restored.free()
	cleanup()
	print("CHARACTER_ROSTER_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
