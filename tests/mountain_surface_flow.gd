extends SceneTree
const RIDGE=preload("res://assets/shaders/forest_ridge.gdshader")
var checks:=0
var failures: Array[String]=[]
var game: Node3D
var materials: Array[ShaderMaterial]=[]
var output: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func draw() -> Image:
	for i in range(8):await process_frame;RenderingServer.force_draw()
	return root.get_texture().get_image()
func strength(value: float) -> void:
	for material in materials:material.set_shader_parameter("texture_strength",value)
func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir()
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("山石验收兔","bunny","bow_rose");session.state().map_id="valley";session.state().player_position=[34,.1,8]
	game=load("res://scenes/valley.tscn").instantiate();root.add_child(game);current_scene=game
	while game.preparing or game.camera==null:await process_frame
	session.active=false;game.set_process(false);game.bunny.set_physics_process(false);game.hud.hide();game.bunny.hide()
	for npc in game.npcs:npc.process_mode=Node.PROCESS_MODE_DISABLED
	var count:=0;var bound:=true;var geometry: Array=[]
	for node in game.scenery.find_children("*","GeometryInstance3D",true,false):
		var material: Material=node.material_override
		if material is ShaderMaterial and material.shader==RIDGE:
			count+=1
			if material not in materials:materials.append(material)
			var texture_: Texture2D=material.get_shader_parameter("rock_texture")
			bound=bound and texture_!=null and texture_.resource_path=="res://assets/terrain/soft_moss_rock_v1.png"
			if node is MeshInstance3D:geometry.append([node,node.mesh,node.transform])
	check(count>=16 and bound,"Runtime rounded ridges and mountain backdrop share the generated rock texture")
	check(materials.all(func(m):return not m.get_shader_parameter("shape_wobble")),"Baked mountain silhouettes and collision stay in sync")
	var settings:=ConfigFile.new();settings.load("res://assets/terrain/soft_moss_rock_v1.png.import")
	check(settings.get_value("params","compress/mode")==2 and settings.get_value("params","mipmaps/generate") and settings.get_value("params","process/size_limit")==1024,"Mountain texture uses capped VRAM compression and mipmaps")
	game.update_lighting(.4);game.camera.position=Vector3(43,7,4);game.camera.look_at(Vector3(56,3,-12))
	strength(0.);var before:=await draw();before.save_png(output+"/mountain-before.png")
	strength(.88);var after:=await draw();after.save_png(output+"/mountain-after.png")
	var difference:=0.;var samples:=0
	for y in range(0,before.get_height(),24):
		for x in range(0,before.get_width(),24):
			var a:=before.get_pixel(x,y);var b:=after.get_pixel(x,y);difference+=(absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3.;samples+=1
	check(difference/samples>.003,"Actual rendered mountain pixels change when texture is enabled")
	check(geometry.all(func(row):return row[0].mesh==row[1] and row[0].transform==row[2]),"Material upgrade does not rebuild or move mountain meshes")
	game.camera.position=Vector3(23,7,-17);game.camera.look_at(Vector3(14,6,-39));var trail:=await draw();trail.save_png(output+"/mountain-trail-after.png")
	game.update_lighting(.92);game.camera.position=Vector3(43,7,4);game.camera.look_at(Vector3(56,3,-12));var night:=await draw();night.save_png(output+"/mountain-night-after.png")
	print("MOUNTAIN_TEXTURE render_geometries=",count," shared_materials=",materials.size()," image_difference=",difference/samples)
	print("MOUNTAIN_SURFACE_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
