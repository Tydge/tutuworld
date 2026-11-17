extends SceneTree
const S=preload("res://scripts/services/session.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func run() -> void:
	var directory:=preload("res://tests/test_support.gd").output_dir()
	var session:=S.new();session.test_mode=true;session.save_path=directory+"/roster.json"
	session.create_character("重启兔","bunny","bow_rose");var cat:=session.create_character("重启猫","cat_teacher","scarf_blue")
	session.test_mode=false;check(session.save_game(),"Save active cat after first rabbit")
	session.free()
	var preferences:=FileAccess.open(directory+"/preferences.json",FileAccess.WRITE);preferences.store_string(JSON.stringify({"player_species":"bunny"}));preferences.close()
	session=S.new();session.name="Session";session.save_path=directory+"/roster.json";root.add_child(session)
	session.load_save();session.load_preferences(directory+"/preferences.json")
	check(session.active_character_id==cat.id and session.state().species=="cat_teacher","Restart restores active cat despite stale rabbit preferences")
	# City models must also use the character even if an old extension dirties this mirror.
	session.settings.player_species="bunny"
	var city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.5).timeout
	check(city.bunny.rig_profile.resource_path.contains("cat"),"Actual city creates cat rig from character record")
	city.bunny.position=Vector3(0,.2,9);city.camera.position=Vector3(3,3,14);city.camera.look_at(city.bunny.position+Vector3.UP*1.3)
	for i in range(4):await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(directory+"/cat-after-restart.png")
	city.queue_free();await process_frame;session.free()
	print("CHARACTER_RESTART_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
