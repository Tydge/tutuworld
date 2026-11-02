extends SceneTree
const S=preload("res://scripts/services/session.gd")
var session: Node
var title: Node3D
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func sample(label_: String,seconds: float) -> void:
	var values: Array[float]=[]
	var last:=Time.get_ticks_usec()
	var stop:=last+int(seconds*1000000)
	var over50:=0
	while Time.get_ticks_usec()<stop:
		await process_frame
		var now:=Time.get_ticks_usec()
		var ms: float=(now-last)/1000.0
		values.append(ms)
		if ms>50: over50+=1
		last=now
	values.sort()
	print("CHARACTER_MENU_BENCH ",label_," frames=",values.size()," p95=",values[int(values.size()*.95)]," max=",values[-1]," over50=",over50)
	if over50>0: failures.append(label_)
func run() -> void:
	root.size=Vector2i(1440,900)
	session=S.new()
	session.name="Session"
	root.add_child(session)
	session.create_character("软糖","bunny","bow_rose")
	session.create_character("团子","cat_teacher","scarf_blue")
	title=load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	var loading:=Time.get_ticks_msec()
	while not title.characters_ready: await process_frame
	print("CHARACTER_PREVIEWS_PREPARED ms=",Time.get_ticks_msec()-loading)
	await create_timer(.3).timeout
	var before:=Time.get_ticks_usec()
	title.start_game()
	print("MENU_OPEN ms=",(Time.get_ticks_usec()-before)/1000.0)
	await sample("first_roster_open",2)
	var menu: Control=title.character_menu
	before=Time.get_ticks_usec()
	menu.begin_create()
	print("CREATE_FORM ms=",(Time.get_ticks_usec()-before)/1000.0)
	await sample("first_creation_open",2)
	menu.name_input.text="棉花"
	menu.name_input.text_changed.emit("棉花")
	for species in ["cat_teacher","bunny"]:
		before=Time.get_ticks_usec()
		menu.draft_species=species
		menu.draft_item="scarf_green" if species=="cat_teacher" else "vest_honey"
		menu.clothing_category="neck" if species=="cat_teacher" else "body"
		menu.build_create()
		print("MODEL_AND_CLOTH_CHANGE ",species," ms=",(Time.get_ticks_usec()-before)/1000.0)
		await sample("switch_"+species,2)
	menu.go_back()
	await sample("back_to_roster",2)
	print("CHARACTER_MENU_PERFORMANCE_RESULT ","PASS" if failures.is_empty() else "FAIL"," failures=",failures)
	quit(0 if failures.is_empty() else 1)
