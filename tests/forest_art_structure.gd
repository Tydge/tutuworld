extends SceneTree
var checks:=0
var failures: Array=[]
var OUT=preload("res://tests/test_support.gd").output_dir()+"/"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func run() -> void:
	root.size=Vector2i(1440,900)
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.state().map_id="valley";session.state().time=1800;session.state().player_position=[-8,.1,32]
	var game=load("res://scenes/valley.tscn").instantiate();root.add_child(game);await create_timer(1).timeout
	Engine.max_fps=30;session.active=false;game.bunny.can_move=false
	check(game.scenery.get_node_or_null("Understory")==null and game.scenery.find_children("GrassTufts","",true,false).is_empty(),"Valley has no seedling or clover groundcover geometry")
	check(game.scenery.get_meta("meadow_flower_count",0)>=200 and game.scenery.get_meta("shrub_count",0)>=20,"Grouped wildflowers and low shrub groves replace scattered spikes")
	var found:=false
	for mesh in game.scenery.find_children("TerrainChunk","MeshInstance3D",true,false):
		var tex: Texture2D=mesh.material_override.get_shader_parameter("lawn_texture")
		found=is_instance_valid(tex) and tex.resource_path=="res://assets/terrain/spring_lawn_v1.png"
		if found: break
	check(found,"Forest terrain uses imported lawn texture")
	var mip: ConfigFile=ConfigFile.new();mip.load("res://assets/terrain/spring_lawn_v1.png.import")
	check(mip.get_value("params","mipmaps/generate",false),"Mipmaps enabled for stable distant leaf detail")
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/houses/seabreeze_cottage.json"))
	var room: Dictionary=game.home.get_meta("building_definition")
	check(room.size==original.size and game.home.floor_size==Vector2(12,10),"New cottage keeps the same twelve-by-ten footprint")
	check(room.theme=="forest" and room.furniture!=original.furniture,"Different interior layout stored in editable building blueprint")
	for id in ["bed","sofa","desk","hearth","tea_table","bookshelf","rug","fern"]:
		var module: Node3D=game.home.get_node("Furnishing/"+id)
		check(module.get_meta("module_id")==id and module.has_meta("module_type"),"Independent furniture module "+id)
	var sofa: Node3D=game.home.get_node("Furnishing/sofa");var collider: Node3D=sofa.get_node("SetteeCollision");var old: Vector3=collider.global_position
	sofa.position.x+=.5
	check(is_equal_approx(collider.global_position.x-old.x,.5),"Moving a furniture module also moves its collision geometry")
	sofa.position.x-=.5
	var bed_exit: Vector3=game.home.get_node("Furnishing/bed/SleepExit").global_position
	while not game.navigation.ready_for_paths: await physics_frame
	check(game.navigation.path_between(Vector3(-8,0,32),bed_exit).size()>1,"New furniture layout leaves a connected bed route")
	game.set_process(false);game.hud.visible=false;game.bunny.hide()
	game.bunny.position=Vector3(-12,.1,11);game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation();game.update_lighting(.5)
	game.camera.position=Vector3(-20,5,19);game.camera.look_at(Vector3(-12,.25,12))
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"山谷-草坪与林下植物.png")
	game.bunny.show();game.bunny.position=game.home.to_global(Vector3(-.8,.25,2.5));game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation()
	game.camera.position=game.home.to_global(Vector3(10,12,15));game.camera.look_at(game.home.to_global(Vector3(0,1,0)))
	await create_timer(.6).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"山谷-全新林间样板间.png")
	game.queue_free();await process_frame;await process_frame
	session.state().map_id="city";session.state().player_position=[0,.1,9]
	game=load("res://scenes/city.tscn").instantiate();root.add_child(game);await create_timer(.8).timeout;session.active=false
	check(game.scenery.find_children("GrassTufts","",true,false).is_empty(),"City also removes all scattered seedling geometry")
	var city_materials:=0
	for node in game.scenery.find_children("*","GeometryInstance3D",true,false):
		if node.material_override is ShaderMaterial and node.material_override.shader==load("res://assets/shaders/meadow.gdshader"):
			city_materials+=1;check(node.material_override.get_shader_parameter("lawn_texture").resource_path=="res://assets/terrain/spring_lawn_v1.png","City meadow shares the accepted lawn texture")
	check(city_materials>0,"City meadow material is present")
	game.set_process(false);game.bunny.can_move=false;game.hud.visible=false;game.update_lighting(.5)
	game.bunny.position=Vector3(11,.1,13);game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation()
	game.camera.position=Vector3(22,9,24);game.camera.look_at(Vector3(10,1,9))
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"城镇-新草坪.png")
	print("FOREST_ART_STRUCTURE_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
