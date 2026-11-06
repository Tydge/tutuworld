extends SceneTree
## Developer-only: bake the same full-portion 3D dishes used on dining tables.
const Food=preload("res://scripts/city/food_visual.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(480,320)
	var view:=SubViewport.new();view.size=Vector2i(192,192);view.own_world_3d=true;view.transparent_bg=true;view.msaa_3d=Viewport.MSAA_4X;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(0,0,0,0);env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("fff6e5");env.ambient_light_energy=.70;environment.environment=env;view.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-25,0);sun.light_energy=1.2;view.add_child(sun)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.02;view.add_child(camera);camera.position=Vector3(.7,1.4,1.15);camera.look_at(Vector3(0,.08,0));camera.current=true
	var manifest:={"source_sha256":FileAccess.get_file_as_string("res://scripts/city/food_visual.gd").sha256_text(),"shader_sha256":FileAccess.get_file_as_string("res://assets/shaders/food_surface.gdshader").sha256_text(),"size":192,"icons":{}}
	for id in Food.IDS:
		var meal:=Food.make(id);view.add_child(meal);var steam:=meal.get_node_or_null("MealSteam")
		if steam!=null:steam.hide()
		for i in range(4):await process_frame;RenderingServer.force_draw()
		var img:=view.get_texture().get_image();var path: String="res://assets/ui/food/"+id+".png"
		if img==null or img.is_empty() or img.get_used_rect().get_area()<100 or img.save_png(path)!=OK:push_error("Invalid food icon "+id);quit(1);return
		manifest.icons[id]=FileAccess.get_sha256(path)
		meal.free()
	var record:=FileAccess.open("res://assets/ui/food/manifest.json",FileAccess.WRITE);record.store_string(JSON.stringify(manifest,"\t")+"\n");record.close()
	print("FOOD_ICONS_RENDERED count=",Food.IDS.size());quit()
