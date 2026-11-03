extends SceneTree
const Layout=preload("res://scripts/building/layout.gd")
const Templates=preload("res://scripts/building/templates.gd")
const Session=preload("res://scripts/services/session.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func run() -> void:
	var sample:=Templates.cottage();var result:=Layout.validate(sample)
	check(result.ok,"Editable sample room contains valid floor, walls, openings, roof and furniture")
	if not result.ok:print(result);quit(1);return
	check(Layout.normalize({}).elements.is_empty(),"Old single-player saves start with an empty building plot")
	var duplicate:=sample.duplicate(true);duplicate.elements.append(duplicate.elements[0].duplicate(true));check(not Layout.validate(duplicate).ok,"Duplicate stable IDs rejected")
	var outside:=Layout.add(sample,{"type":"wall","a":[60,4],"b":[70,4]});check(not Layout.validate(outside).ok,"Construction cannot escape the test plot")
	var diagonal:=Layout.add(sample,{"type":"wall","a":[90,2],"b":[92,4]});check(not Layout.validate(diagonal).ok,"Unsupported diagonal wall cannot create mismatched collision")
	var floating:=Layout.add(Layout.empty(),{"type":"object","kind":"bed","position":[80,10]});check(not Layout.validate(floating).ok,"Indoor furniture requires a complete floor footprint")
	var garden:=Layout.add(Layout.empty(),{"type":"object","kind":"forest_planter","position":[80,10]});check(Layout.validate(garden).ok,"Outdoor objects can be placed on lawn")
	var unsupported:=Layout.add(Layout.empty(),{"type":"roof","a":[73,5],"b":[85,15]});check(not Layout.validate(unsupported).ok,"Roof requires matching floor support")
	var collision:=Layout.add(sample,{"type":"object","kind":"sofa","position":[82,8]});check(not Layout.validate(collision).ok,"Furniture overlap is rejected")
	var wall_collision:=Layout.add(sample,{"type":"object","kind":"bookshelf","position":[73,10]});check(not Layout.validate(wall_collision).ok,"Furniture cannot be embedded in walls")
	var no_wall:=Layout.add(sample,{"type":"door","wall":"missing","offset":4.});check(not Layout.validate(no_wall).ok,"Openings cannot be detached from a wall")
	var near_corner:=Layout.add(sample,{"type":"window","wall":"build_5","offset":.5});check(not Layout.validate(near_corner).ok,"Window keeps its supporting corner pier")
	var double_hole:=Layout.add(sample,{"type":"window","wall":"build_2","offset":6.});check(not Layout.validate(double_hole).ok,"Door and window cannot overlap")
	var removed:=Layout.remove(sample,"build_2");check(Layout.find(removed,"build_6").is_empty() and Layout.validate(removed).ok,"Deleting a wall removes its door attachment")
	var shell:=sample.duplicate(true);shell.elements=shell.elements.filter(func(row):return row.type!="object")
	for kind in ["forest_cabinet","bookshelf"]:
		for pose in [[Vector2(77,5.5),0],[Vector2(73.5,10),90],[Vector2(77,14.5),180],[Vector2(84.5,10),270]]:
			var item:=Layout.snap_object(shell,{"type":"object","kind":kind,"position":[pose[0].x,pose[0].y],"yaw":pose[1]})
			var result_: Dictionary=Layout.validate(Layout.add(shell,item))
			check(result_.ok,"Storage furniture snaps close to each wall without intersecting: "+kind+" "+str(pose[1]))
			check(Layout.snap_object(shell,item).position==item.position,"Wall snapping stays stable on repeated preview: "+kind+" "+str(pose[1]))
	var precise:=Layout.snap_object(shell,{"type":"object","kind":"forest_cabinet","position":[77,5.5],"yaw":0})
	var placed: Dictionary=Layout.validate(Layout.add(shell,precise)).layout
	check(not is_equal_approx(fposmod(float(precise.position[1]),.5),0.) and Layout.normalize(JSON.parse_string(JSON.stringify(placed)))==placed,"Precise wall-snapped coordinates survive layout serialization")
	var clipped:=Layout.add(shell,{"type":"object","kind":"forest_cabinet","position":[77,5.25],"yaw":0})
	check(not Layout.validate(clipped).ok,"Precise positioning still rejects a cabinet penetrating a wall")
	var free:={"type":"object","kind":"forest_cabinet","position":[79.,10.],"yaw":0}
	check(Layout.snap_object(shell,free).position==free.position,"Furniture in open space stays on its ordinary grid position")
	var s:=Session.new();s.name="Session";root.add_child(s);s.create_character("建造规则兔","bunny","bow_rose")
	check(s.set_build_layout(sample).ok,"Layout commits through Session validation")
	var previous: Dictionary=s.state().build_layout.duplicate(true);check(not s.set_build_layout(outside).ok and s.state().build_layout==previous,"Failed validation leaves the previous room intact")
	var id: String=s.active_character_id;s.create_character("建造规则猫","cat_teacher","beret_sage")
	check(s.state().build_layout.elements.size()==sample.elements.size(),"Characters on the same local island share their building layout")
	s.select_character(id);check(s.state().build_layout.elements.size()==sample.elements.size(),"Switching back preserves the complete room")
	# Real disk round-trip in a dedicated QA directory, while the player save stays untouched.
	var folder: String=ProjectSettings.globalize_path("res://.qa-artifacts/building-local/save-rules");DirAccess.make_dir_recursive_absolute(folder)
	s.set_player_position(Vector3(79,.2,12));s.test_mode=false;s.save_path=folder+"/single-player.json";check(s.save_game(),"Room saved through the actual atomic single-player writer")
	var loaded:=Session.new();loaded.name="ReloadedSession";root.add_child(loaded);loaded.test_mode=false;loaded.save_path=s.save_path;loaded.load_save()
	check(loaded.state().build_layout.elements==s.state().build_layout.elements,"Disk reload restores stable IDs, materials, openings and placements")
	check(Vector3(loaded.state().player_position[0],loaded.state().player_position[1],loaded.state().player_position[2]).distance_to(Vector3(79,.2,12))<.01,"Save migration accepts the expanded east-side player position")
	var xp: int=s.state().experience;var revision: int=s.authority.revision;s.save_path=folder+"/absent/fail.json"
	var smaller:=Layout.remove(sample,"build_9");var refused:=s.set_build_layout(smaller)
	check(not refused.ok and s.state().build_layout==previous and s.authority.revision==revision and s.state().experience==xp,"Failed disk save rolls back building, revision and player progress")
	s.test_mode=true;loaded.test_mode=true
	print("BUILDING_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
