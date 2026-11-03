extends SceneTree
const S=preload("res://scripts/services/session.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Facilities=preload("res://scripts/city/production_facilities.gd")
const Animals=preload("res://scripts/characters/animal_factory.gd")
var checks:=0
var failures: Array=[]
var session: Node
var city: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func screenshot(name_: String) -> void:
	city.update_occluders(.5)
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/"+name_+".png")
func pose(point: Vector3) -> void:
	city.bunny.position=point;city.bunny.velocity=Vector3.ZERO;city.bunny.reset_physics_interpolation();session.set_player_position(point);city.update_target()
func walk(actor: CharacterBody3D,start: Vector3,direction: Vector3,frames: int) -> Vector3:
	actor.position=start;actor.velocity=Vector3.ZERO;actor.reset_physics_interpolation()
	for frame in range(frames):
		await physics_frame
		actor.velocity=direction*2.8+Vector3(0,-.6,0);actor.move_on_ground(1.0/60)
	var contacts: Array=[]
	for index in range(actor.get_slide_collision_count()): contacts.append(str(actor.get_slide_collision(index).get_collider().get_path()))
	print("WALK_END ",actor.rig_profile.species_id," ",start," -> ",actor.position," contacts=",contacts)
	return actor.position
func run() -> void:
	root.size=Vector2i(1440,900);Engine.max_fps=60
	session=S.new();session.name="Session";root.add_child(session);session.create_character("工坊验收兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	await create_timer(1).timeout
	session.set_process(false);session.active=true
	city.set_process(false);city.bunny.network_replica=true
	var well: Node3D=city.scenery.get_node("GardenWell")
	var workshop: Node3D=city.scenery.get_node("Workshop")
	check(city.targets.has("garden_well") and city.targets.has("workshop_bench") and city.targets.has("workshop_door"),"Actual city registers well, workbench and independent workshop door")
	check(workshop.global_position.x>city.scenery.get_node("Kitchen").global_position.x,"Workshop is east of the kitchen")
	check(city.interiors.has(workshop) and workshop.has_meta("building_definition") and well.get_meta("buildable_reference",false),"New modules preserve building / placement definitions")
	var well_transform:=well.transform;var old_anchor: Vector3=city.targets.garden_well.position
	well.position.x+=4;Facilities.refresh(city,session.authority)
	check(city.targets.garden_well.position.is_equal_approx(old_anchor+Vector3(4,0,0)),"Moving the well moves its actual interaction anchor")
	check(session.authority.facility_position("garden_well").is_equal_approx(Vector2(old_anchor.x+4,old_anchor.z)),"Authority uses moved well rather than original coordinates")
	var well_collision: Node3D=well.get_node("Structure/WellCollision")
	check(absf(well_collision.global_position.x-47)<.01,"Well collision travels with the same root")
	well.transform=well_transform;Facilities.refresh(city,session.authority)
	var bench: Node3D=workshop.get_node("Furnishing/workbench");var bench_transform:=bench.transform
	var work_anchor: Vector3=city.targets.workshop_bench.position
	bench.position.z+=1.2;bench.rotation.y=PI/2;Facilities.refresh(city,session.authority)
	check(city.targets.workshop_bench.position.is_equal_approx(bench.get_node("ActionAnchor").global_position) and not city.targets.workshop_bench.position.is_equal_approx(work_anchor),"Moving and rotating workbench moves the use position")
	check(bench.get_node("WorkbenchCollision").get_parent()==bench and bench.get_meta("module_type")=="workbench","Workbench geometry and collisions stay in an independent furniture module")
	bench.transform=bench_transform;Facilities.refresh(city,session.authority)
	# An actual body walks each opening, without teleporting through it.
	var actors: Array=[]
	for species in Animals.Catalog.ids():
		var actor:=Animals.create(species);city.add_child(actor);actor.world=city;actor.set_physics_process(false);actors.append(actor)
		var end:=await walk(actor,Vector3(37.8,.20,3),Vector3.RIGHT,83)
		check(end.x>41.2,"Garden east gate is passable without jumping: "+species)
		actor.position=Vector3(0,10,0);actor.collision_layer=0;actor.collision_mask=0
	# Door collision is genuinely opened before entry.
	pose(Vector3(34,.2,-20.6));check(workshop.door_open,"Workshop door starts open")
	check(workshop.toggle_door(city.bunny).ok,"Workshop door closes independently")
	await create_timer(.8).timeout
	check(workshop.toggle_door(city.bunny).ok,"Workshop door opens independently")
	await create_timer(.8).timeout
	check(workshop.door_open and workshop.portal_shape.disabled,"Open workshop door releases its portal collision")
	pose(Vector3(27,.2,-15))
	for actor in actors:
		actor.collision_layer=2;actor.collision_mask=15
		var end:=await walk(actor,Vector3(34,.20,-19.2),Vector3.FORWARD,170)
		check(workshop.contains_position(end) and end.z<-25.5,"Real shop-sized door, porch and floor support entry: "+actor.rig_profile.species_id)
		actor.position=Vector3(0,10,0);actor.collision_layer=0;actor.collision_mask=0
	for actor in actors: actor.queue_free()
	# Keep generated scenery and the live cutaway/lighting code in the screenshots.
	city.hud.hide();pose(Vector3(39,.2,5));city.camera.position=Vector3(52,12,18);city.camera.look_at(Vector3(39,1.0,2));city.update_lighting(.5)
	await screenshot("菜园水井-东侧小门")
	pose(Vector3(34,.2,-19.5));city.camera.position=Vector3(46,12,-9);city.camera.look_at(Vector3(30,1,-25))
	await screenshot("铜叶工坊-厨房东侧")
	pose(city.targets.workshop_bench.work_anchor.global_position);city.camera.position=Vector3(39,8,-16);city.camera.look_at(Vector3(33,1,-27))
	await create_timer(.6).timeout
	await screenshot("铜叶工坊-室内模块")
	city.hud.show();city.current_target="workshop_bench";session.authority.add("copper",18);session.authority.add("branch",8);city.hud.open_panel("workshop")
	var buttons: Array=city.hud.content.find_children("*","Button",true,false);var recipes: Array=[]
	for button in buttons:
		if button.has_meta("recipe"): recipes.append(button.get_meta("recipe"))
	check(recipes.size()==2 and recipes.has("copper_watering_can") and recipes.has("copper_axe"),"Workshop UI offers only its two manufacturing recipes")
	await screenshot("铜叶工坊-制造面板")
	city.hud.close_panel();check(city.begin_manufacturing("copper_watering_can").ok,"Manufacturing starts through real city interaction")
	await create_timer(.65).timeout
	check(city.bunny.action=="gather_stone" and is_instance_valid(city.tools.prop),"Workshop uses shared two-handed hammer animation")
	await screenshot("铜叶工坊-制造动作")
	session._process(session.job().duration+.01)
	check(session.authority.count("copper_watering_can")==1 and session.authority.count("copper")==8 and session.state().skill_experience.manufacturing==5,"Real UI / session manufacturing settles exact output, materials and XP")
	city.hud.open_panel("profile");city.hud.character_sheet.pages.current_tab=1
	check(city.hud.character_sheet.skill_controls.has("manufacturing") and city.hud.character_sheet.values.has("manufacture"),"Character panel exposes manufacturing skill and speed")
	await screenshot("制造技能-角色面板")
	city.hud.close_panel();pose(city.targets.garden_well.work_anchor.global_position)
	city.camera.position=Vector3(48,7,10);city.camera.look_at(Vector3(42,1,3));city.current_target="garden_well"
	check(city.begin_action("refill","garden_well").ok and session.job().duration==2.0,"Well E interaction starts fixed-duration refill")
	await create_timer(.6).timeout
	await screenshot("菜园水井-打水动作")
	var roof_hidden:=false
	for occluder in city.occluders:
		if occluder.get("anchor")==well: roof_hidden=occluder.alpha<.001
	check(roof_hidden,"Well roof fades when it blocks the operating character")
	session._process(2.0)
	check(session.authority.water_left()==12 and city.bunny.can_move,"Refill fills copper can and returns movement control")
	var plot: Dictionary=DB.plots()[5];session.state().plots[plot.id].crop="carrot";pose(Vector3(plot.x,.2,plot.z+1.9));city.current_target=plot.id;city.refresh_world()
	check(city.begin_action("water",plot.id).ok,"Charged copper can can water a real garden plot")
	city.camera.position=city.bunny.position+Vector3(6,5,8);city.camera.look_at(city.bunny.position+Vector3(0,1,0))
	await create_timer(.6).timeout;await screenshot("铜水壶-浇水动作")
	session._process(2.0)
	check(session.authority.water_left()==11 and not session.authority.needs(session.state().plots[plot.id]).water,"Real watering consumes one charge and satisfies crop")
	print("PRODUCTION_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
