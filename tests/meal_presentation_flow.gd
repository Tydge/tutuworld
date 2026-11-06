extends SceneTree
const Food=preload("res://scripts/city/food_visual.gd")
const Meal=preload("res://scripts/city/meal_timeline.gd")
const Factory=preload("res://scripts/characters/animal_factory.gd")
const L=preload("res://scripts/building/layout.gd")
const D=preload("res://scripts/building/dining.gd")
var checks:=0
var failures: Array[String]=[]
var city: Node3D
var session: Node
var output: String
var begin_times: Array[float]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func draw() -> void:
	for i in range(4):await process_frame;RenderingServer.force_draw()
func photo(name_: String) -> void:
	await draw();root.get_texture().get_image().save_png(output+"/"+name_+".png")
func phase(t: float) -> void:
	session.authority.job.elapsed=t;city.bunny.meal_elapsed=t;city.bunny.action_time=t
	city.bunny.animate_pose(1./60.);city.culinary._process(0.);city.tools._physics_process(1./60.)
func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir()
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("料理验收兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.preparing or city.camera==null:await process_frame
	var editor=city.build_mode;editor.open_editor();var data:=L.add(L.empty(),{"type":"floor","a":[80.,-12.],"b":[99.,4.]})
	data=L.add(data,{"type":"object","kind":"dining_table","position":[89.,-5.],"yaw":90.});var table: Dictionary=data.elements[-1].duplicate(true)
	var slot: Dictionary=D.slots(table)[2];data=L.add(data,{"type":"object","kind":"dining_chair","position":[slot.position.x,slot.position.y],"yaw":slot.yaw});var chair_id: String=data.elements[-1].id
	check(editor.commit(data),"Rotated player-built dining table and chair are placed")
	editor.close_editor();city.set_process(false);city.paused=false;session.active=false
	city.tools.set_physics_process(false);city.culinary.set_process(false)
	var before_warm: Dictionary=session.snapshot();await city.culinary.warm_models()
	check(Food.models.size()==7 and city.culinary.get_node_or_null("MealWarmup")==null and session.snapshot()==before_warm,"Loading preparation caches all dishes and portions without mutating progress")
	for npc in city.npcs:npc.process_mode=Node.PROCESS_MODE_DISABLED;npc.collision_layer=0
	var original: CharacterBody3D=city.bunny;original.set_physics_process(false);original.hide();original.collision_layer=0
	var chair: Node3D=editor.room.render_cache[chair_id].node
	city.dining_target="build:"+table.id;city.update_lighting(.4)
	for id in Food.IDS:session.authority.add(id,1)
	city.hud.open_panel("dining");await photo("menu-model-thumbnails");city.hud.close_panel();city.hud.hide();city.paused=false
	for species in ["bunny","cat_teacher","panda"]:
		var actor: CharacterBody3D=Factory.create(species);city.add_child(actor);actor.world=city;actor.set_physics_process(false);actor.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;city.bunny=actor;city.tools.bunny=actor
		for id in Food.IDS:
			actor.stand_up(chair.get_node("ExitAnchor").global_position);session.set_player_position(actor.position);session.authority.add(id,2);session.state().stamina=40.
			var before: int=session.authority.count(id);var start_time:=Time.get_ticks_usec();var started: Dictionary=city.begin_dining(id);begin_times.append((Time.get_ticks_usec()-start_time)/1000.)
			check(started.ok and actor.seated,"Start actual built-table meal: "+species+" "+id)
			if not started.ok:continue
			check(city.tools.prop.get_meta("utensil")==Meal.utensil(id),"Correct spoon, fork or handheld prop: "+species+" "+id)
			phase(.56)
			var plate_error: float=city.tools.prop.get_node("FoodContact").global_position.distance_to(city.culinary.meal.global_position+Vector3.UP*.17)
			if Meal.utensil(id)!="hand":check(plate_error<.14,"Utensil reaches this rotated table, not the distant town table: "+species+" "+id+" error="+str(plate_error))
			phase(1.10)
			var mouth_error: float=city.tools.prop.get_node("FoodContact").global_position.distance_to(actor.mouth.global_position)
			check(mouth_error<.15 and city.tools.prop.get_node("Mouthful").visible,"Food reaches species mouth while still visible: "+species+" "+id+" error="+str(mouth_error))
			if id in ["food_pumpkin_soup","food_garden_salad","food_rustic_wheat_bread"]:
				var p: Vector3=city.culinary.meal.global_position;city.camera.position=p+actor.visual.global_basis*Vector3(2.35,1.7,3.1);city.camera.look_at((p+actor.mouth.global_position)*.5);await photo(species+"-"+id+"-bite")
			for bites in range(1,4):
				phase(1.21+(bites-1)*1.65)
				check(city.culinary.meal.get_meta("portion")==bites and not city.tools.prop.get_node("Mouthful").visible,"Swallow updates the matching visible portion: "+species+" "+id+" "+str(bites))
				if species=="bunny" and id in ["food_pumpkin_soup","food_garden_salad","food_rustic_wheat_bread"]:
					var p: Vector3=city.culinary.meal.global_position;city.camera.position=p+Vector3(1.35,1.2,1.5);city.camera.look_at(p+Vector3.UP*.10);actor.hide();await photo(id+"-portion-"+str(bites));actor.show()
			check(session.authority.count(id)==before,"Visual eating never deducts inventory early: "+species+" "+id)
			phase(5.95);var events: Array=session.authority.tick(.06)
			for event in events:city.on_event(event)
			check(session.authority.count(id)==before-1 and not actor.seated and not is_instance_valid(city.culinary.meal),"Six-second completion consumes once and exits safely: "+species+" "+id)
		actor.stand_up(chair.get_node("ExitAnchor").global_position);session.set_player_position(actor.position);session.authority.add("food_rustic_wheat_bread",1);city.begin_dining("food_rustic_wheat_bread");phase(2.9);var count: int=session.authority.count("food_rustic_wheat_bread");city.cancel_action()
		check(session.authority.count("food_rustic_wheat_bread")==count and not actor.seated and not city.tools.prop.visible,"Cancel halfway through a handheld meal cleans up without consuming food: "+species)
		city.bunny=original;city.tools.bunny=original;actor.free()
	city.free();session.free();await process_frame
	print("MEAL_BEGIN_TIMES max_ms=",begin_times.max()," samples=",begin_times)
	print("MEAL_PRESENTATION_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
