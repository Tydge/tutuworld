extends SceneTree
const Factory=preload("res://scripts/building/module_factory.gd")
const G=preload("res://scripts/geometry.gd")
var checks:=0
var failures: Array=[]
var city: Node3D
var output: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func photo(name_: String) -> Image:
	for i in range(4):await process_frame;RenderingServer.force_draw()
	var img:=root.get_texture().get_image();img.save_png(output+"/"+name_+".png");return img
func luminance(img: Image,p: Vector3) -> float:
	var pixel: Vector2=city.camera.unproject_position(p)*Vector2(img.get_size())/city.camera.get_viewport().get_visible_rect().size;var sum:=0.
	for y in range(-2,3):
		for x in range(-2,3):
			var c:=img.get_pixel(clampi(int(pixel.x)+x,0,img.get_width()-1),clampi(int(pixel.y)+y,0,img.get_height()-1));sum+=c.r*.2126+c.g*.7152+c.b*.0722
	return sum/25.
func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir();var s=load("res://scripts/services/session.gd").new();s.name="Session";root.add_child(s);s.create_character("灯光验收兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.7).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);s.active=false;city.set_process(false);city.hud.hide();city.bunny.hide();city.update_lighting(.92)
	var stage:=Node3D.new();stage.position=Vector3(80,.18,18);city.add_child(stage);var b:=Factory.builder(stage);G.box(stage,Vector3(0,-.05,0),Vector3(12,.1,12),Factory.floor_material({"color":"cda56e","style":"wood"}))
	var lamp:=Node3D.new();stage.add_child(lamp);lamp.position=Vector3(3.5,0,0);b.build_item(lamp,"floor_lamp")
	var striped_casters:=0
	for mesh in lamp.find_children("*","MeshInstance3D",true,false):
		if mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:continue
		for surface in range(mesh.mesh.get_surface_count()):
			for v in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var p: Vector3=lamp.to_local(mesh.to_global(v))
				if p.y>2.0 and Vector2(p.x,p.z).length()>.10:striped_casters+=1
	check(striped_casters==0 and lamp.get_node("FixtureLight").shadow_enabled,"The shade and ribs cast no striped shadows while the fixture retains normal object shadows")
	var light: Light3D=lamp.get_node("FixtureLight");check(light.distance_fade_enabled and light.distance_fade_shadow<light.distance_fade_begin,"Native fixture shadow fading removes distant shadow work before the light itself fades")
	G.box(stage,Vector3(3.5,2,-1.),Vector3(5,4,.1),G.mat("eadcc5"));city.camera.position=stage.to_global(Vector3(6,2.4,4));city.camera.look_at(lamp.global_position+Vector3.UP*1.4);await photo("floor-lamp-soft-light");lamp.hide()
	var firebox:=Node3D.new();stage.add_child(firebox);b.build_item(firebox,"hearth");var fire: SpotLight3D=firebox.get_node("FixtureFireLight");fire.get_node("FireFlicker").set_process(false);fire.light_energy=2.8
	var effects: Node3D=firebox.get_node("Part_effects");var minimum_z:=INF
	for mesh in effects.find_children("*","MeshInstance3D",true,false):
		if not mesh.material_override is ShaderMaterial or mesh.material_override.shader!=preload("res://assets/shaders/hearth_fire.gdshader"):continue
		for v in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:minimum_z=minf(minimum_z,firebox.to_local(mesh.to_global(v)).z)
	check(minimum_z>-.16,"Crossed flame vertices stay in front of the opaque firebox back with a depth margin")
	city.atmosphere.ssao_enabled=false;city.camera.position=stage.to_global(Vector3(.9,1.0,-3));city.camera.look_at(stage.to_global(Vector3(0,.85,0)));effects.hide();var opaque:=await photo("firebox-rear-opaque");effects.show();var animated:=await photo("firebox-rear-fire")
	var leak:=0.
	for x in range(25):
		for y in range(22):
			var p:=stage.to_global(Vector3(-.65+x*.054,.34+y*.044,-.312));var pixel: Vector2=city.camera.unproject_position(p)*Vector2(opaque.get_size())/city.camera.get_viewport().get_visible_rect().size;var a:=opaque.get_pixel(int(pixel.x),int(pixel.y));var c:=animated.get_pixel(int(pixel.x),int(pixel.y));leak+=absf(a.r-c.r)+absf(a.g-c.g)+absf(a.b-c.b)
	print("FIRE_REAR_LEAK sum=",leak," minimum_flame_z=",minimum_z);check(leak<.3,"The actual rear view has no animated flame leaking or flashing through its black panel")
	effects.hide();city.camera.position=stage.to_global(Vector3(3,3,4));city.camera.look_at(stage.to_global(Vector3(0,.4,1.1)));fire.light_energy=2.8*.76;var low:=await photo("firelight-dim");fire.light_energy=2.8*1.24;var high:=await photo("firelight-bright");var dim:=0.;var bright:=0.
	for p in [Vector3(-.5,.004,1.2),Vector3(.5,.004,1.2),Vector3(0,.004,2.)]:dim+=luminance(low,stage.to_global(p));bright+=luminance(high,stage.to_global(p))
	print("FIRELIGHT_SURFACE_LUMA dim=",dim," bright=",bright," ratio=",bright/maxf(.0001,dim));check(bright>dim*1.035,"Brightness variations visibly affect real floor pixels even with the flame geometry hidden");effects.show();await photo("firelight-front")
	# A moving camera in the complete mode must not rewrite stable wall shaders.
	var editor: Node=city.build_mode;editor.open_editor();var layout:=preload("res://scripts/building/templates.gd").cottage();check(editor.commit(layout),"Visibility profiling fixture commits");editor.set_process(false);editor.ui.hide();editor.room.set_editor_view(false,false);s.settings.interior_view_mode=1;var room: Node3D=editor.room
	room.refresh_view(Vector3(85,3,15),Vector3(79,.2,10));var before: int=room.material_updates
	for i in range(120):room.refresh_view(Vector3(85.+i*.002,3,15),Vector3(79,.2,10))
	check(room.material_updates==before,"Camera movement in complete view sends no repeated unchanged wall material updates")
	s.settings.interior_view_mode=2;room.refresh_view(Vector3(85,3,15),Vector3(79,.2,10));var cache: Dictionary=room.occlusion_cache;var scans: int=cache.get("scans",0)
	for i in range(120):room.refresh_view(Vector3(85.+i*.00001,3,15),Vector3(79,.2,10))
	check(int(cache.get("scans",0))-scans<10,"Small repeated camera changes share bounded occlusion scans while fading still updates")
	print("FIXTURE_LIGHTING_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
