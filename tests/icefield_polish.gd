extends SceneTree
const L=preload("res://scripts/icefield/icefield_layout.gd")
const Celestial=preload("res://scripts/icefield/polar_celestial.gd")
var failures: Array=[]
var checks:=0
var game: Node3D
var output: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func photo(id: String) -> Image:
	await process_frame;RenderingServer.force_draw()
	var frame:=root.get_texture().get_image();frame.save_png(output+"/"+id+".png");return frame
func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir()
	var before:=Celestial.at_time(.9999);var after:=Celestial.at_time(.0001)
	check(before.key_direction.distance_to(after.key_direction)<.003 and absf(before.energy-after.energy)<.001,"Sun and moon are continuous across midnight")
	check(before.solar==0. and before.specular<.04 and before.key_direction.y>.7,"Midnight has subdued overhead moonlight and no horizon sun")
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.settings.background_throttle=false;session.settings.interior_view_mode=2
	session.create_character("冰原画面回归","bunny","scarf_red");session.state().map_id="icefield";session.state().player_position=L.arrival()
	game=load("res://scenes/icefield.tscn").instantiate();root.add_child(game);current_scene=game
	while game.camera==null or game.preparing:await process_frame
	print("DRAW_STATE can_draw=",DisplayServer.window_can_draw()," visible=",root.visible," mode=",root.mode," enabled=",RenderingServer.is_render_loop_enabled())
	session.active=false;game.set_process(false);game.bunny.can_move=false;game.hud.hide()
	var weather: Node=game.get_node("WinterAtmosphere");check(weather.snow.amount<=70,"Snowfall uses a small fixed budget of fine dots")
	weather.hide()
	for npc in game.npcs:
		for child in npc.get_children():
			if child.get_script()==load("res://scripts/city/npc_driver.gd"):child.set_physics_process(false)
	for fire in L.CAMPFIRES:
		check(game.scenery.get_node("SnowPineGroves").get_children().filter(func(n):return n is MultiMeshInstance3D).all(func(n):
			for i in range(n.multimesh.instance_count):
				var p: Vector3=(n.global_transform*n.multimesh.get_instance_transform(i)).origin
				if Vector2(p.x,p.z).distance_to(fire)<8.:return false
			return true),"Campfire clearing stays outside fir tree crowns "+str(fire))
	var shop: Node3D=game.scenery.get_node("Shop_clothes")
	check(not shop.has_node("WinterRoof"),"Shop has no detached roof overlay")
	for roof in shop.sections.filter(func(section):return section.roof):
		check(roof.materials.any(func(m):return m.get_shader_parameter("roof_snow")==true),"Shop snow and canopy share their registered cutaway materials")
	game.bunny.position=shop.to_global(Vector3(0,.22,1.4));game.bunny.reset_physics_interpolation()
	game.camera.position=shop.to_global(Vector3(1.,9.,14.));game.camera.look_at(game.bunny.position+Vector3.UP)
	for frame in range(48):await process_frame;RenderingServer.force_draw()
	check(shop.sections.filter(func(section):return section.roof).all(func(section):return section.alpha<.01),"Free occlusion hides roof snow and the awning together")
	await photo("01-snow-shop-cutaway")
	# A bright calibration object exists only in the reflected world. Its projected
	# center must match the main camera's virtual image during continuous orbiting.
	game.bunny.position=Vector3(50,.84,20);game.bunny.reset_physics_interpolation();game.update_lighting(.5)
	var manager: Node=game.get_node("LakeReflection")
	var marker:=MeshInstance3D.new();var ball:=SphereMesh.new();ball.radius=.75;ball.height=1.5;marker.mesh=ball
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color(1,0,1);marker.material_override=mat
	manager.reflection_root.add_child(marker);marker.position=Vector3(50,3.,8.)
	for frame in range(3):
		game.camera.position=Vector3(57,7.8,37);game.camera.look_at(Vector3(50,1,12));await process_frame;RenderingServer.force_draw()
	var max_error:=0.;var missing:=0;var updated: int=manager.updates
	for i in range(14):
		game.camera.position=Vector3(50,.8,20)+Vector3(7.,7.,17.).rotated(Vector3.UP,float(i)*.025);game.camera.look_at(Vector3(50,1.,12.))
		await process_frame;RenderingServer.force_draw()
		var frame:=root.get_texture().get_image();var expected: Vector2=game.camera.unproject_position(manager.mirror(marker.position));var sum:=Vector2.ZERO;var count_:=0
		var scale_: Vector2=Vector2(frame.get_size())/game.get_viewport().get_visible_rect().size;expected*=scale_
		for y in range(maxi(0,int(expected.y)-55),mini(frame.get_height(),int(expected.y)+55)):
			for x in range(maxi(0,int(expected.x)-55),mini(frame.get_width(),int(expected.x)+55)):
				var c:=frame.get_pixel(x,y)
				if c.r>c.g+.13 and c.b>c.g+.13:sum+=Vector2(x,y);count_+=1
		if count_>20:max_error=maxf(max_error,(sum/count_).distance_to(expected))
		print("ORBIT_SAMPLE ",i," center=",sum/maxi(1,count_)," expected=",expected," pixels=",count_)
		if count_<=20:missing+=1
		if i in [0,7,13]:frame.save_png(output+"/02-reflection-orbit-%02d.png"%i)
	print("REFLECTION_ORBIT max_pixel_error=",max_error," missing=",missing," updates=",manager.updates-updated)
	check(manager.updates-updated>=14,"Reflection capture updates every displayed orbit frame")
	check(missing==0 and max_error<6.,"Reflected object stays registered to the surface during camera motion")
	marker.queue_free()
	await reflected_stars(manager)
	# Physical boundary approach: mountain faces stop the pawn before the fallback
	# map clamp. The open coast visibly descends into water before that clamp.
	game.bunny.can_move=true;game.bunny.network_controlled=true;game.bunny.run_enabled=true
	for a in [0.,-PI*.25,-PI*.5,PI,PI*.5]:
		var p:=Vector3(cos(a)*L.RADII.x*.90,0,sin(a)*L.RADII.y*.90);p.y=L.height_at(p.x,p.z)+.04
		game.bunny.position=p;game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation();game.bunny.network_direction=Vector3(cos(a),0,sin(a))
		await create_timer(4.).timeout;var stopped: Vector3=game.bunny.position
		var water_edge:=L.height_at(stopped.x+cos(a),stopped.z+sin(a))<.1
		check(L.ellipse(stopped.x,stopped.z)<.963 or water_edge,"Boundary is reached at a visible mountain or water edge "+str(a))
	game.bunny.network_direction=Vector3.ZERO
	# Launch with full ice momentum near the south lip and then walk back inland.
	for x in [-33.,0.,43.]:
		var z:=L.RADII.y*sqrt(.915*.915-pow(x/L.RADII.x,2.))-.65
		game.bunny.position=Vector3(x,L.walk_height(x,z)+.03,z)
		game.bunny.velocity=Vector3.ZERO
		game.bunny.reset_physics_interpolation()
		for frame in range(6):await physics_frame
		game.bunny.velocity.z=5.95
		game.bunny.network_direction=Vector3.BACK
		game.bunny.network_jump=true
		var airborne:=false
		for frame in range(75):
			await physics_frame
			airborne=airborne or not game.bunny.is_on_floor()
		var landed: Vector3=game.bunny.position
		check(airborne and landed.distance_to(Vector3(x,L.walk_height(x,z),z))<2. and L.can_walk(landed) and landed.y>0. and game.bunny.is_on_floor(),"Running jump lands on dry southern shore "+str(x))
		game.bunny.network_direction=Vector3.FORWARD
		for frame in range(75):await physics_frame
		check(game.bunny.position.z<landed.z-.9,"Can immediately walk inland after the coastal jump "+str(x))
		game.bunny.network_direction=Vector3.ZERO
	print("ICEFIELD_POLISH_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)

func reflected_stars(manager: Node) -> void:
	game.update_lighting(.94)
	var origin:=Vector3(50.,3.,62.)
	var heading:=Vector3(.08,-.43,1.).normalized()
	game.camera.position=origin
	game.camera.look_at(origin+heading)
	for frame in range(5):await process_frame;RenderingServer.force_draw()
	var image: Image=manager.viewport.get_texture().get_image()
	var size_:=image.get_size()
	var peaks: Array[Dictionary]=[]
	# Observe genuine isolated stars in a clear sector of the reflected southern sky.
	for y in range(size_.y/3,size_.y*2/3,1):
		for x in range(size_.x/5,size_.x*4/5,1):
			var light:=image.get_pixel(x,y).b
			if light<.28:continue
			var background: float=(image.get_pixel(x-5,y).b+image.get_pixel(x+5,y).b)*.5
			if light-background<.10 or light<image.get_pixel(x-1,y).b or light<=image.get_pixel(x+1,y).b or light<image.get_pixel(x,y-1).b or light<=image.get_pixel(x,y+1).b:continue
			var screen:=Vector2(x+.5,y+.5)
			var direction: Vector3=manager.reflected.project_ray_normal(screen)
			peaks.append({"direction":direction,"energy":star_energy(image,Vector2i(x,y))})
	var stable:=0
	var observed:=mini(peaks.size(),32)
	var tracks: Array=[]
	for i in range(observed):tracks.append(true)
	for step in range(1,8):
		game.camera.position=origin+Vector3.RIGHT*.06*step
		game.camera.look_at(game.camera.position+heading.rotated(Vector3.UP,.00037*step))
		await process_frame;RenderingServer.force_draw()
		image=manager.viewport.get_texture().get_image()
		for i in range(observed):
			var star: Dictionary=peaks[i]
			var xy: Vector2=manager.reflected.unproject_position(manager.reflected.global_position+star.direction*500.)
			var energy:=star_energy(image,Vector2i(xy.floor()))
			if absf(energy-star.energy)>maxf(.14,star.energy*.22):tracks[i]=false
	stable=tracks.count(true)
	print("REFLECTED_STARS stable=",stable," observed=",observed)
	check(observed>=4 and stable>=ceili(float(observed)*.90),"Tracked stars retain reflected light across subpixel camera motion")
	await photo("03-night-ice-moving")

func star_energy(image: Image,center: Vector2i) -> float:
	var background: float=(image.get_pixel(center.x-5,center.y).b+image.get_pixel(center.x+5,center.y).b)*.5
	var sum:=0.
	for y in range(center.y-3,center.y+4):
		for x in range(center.x-3,center.x+4):
			sum+=maxf(image.get_pixel(x,y).b-background,0.)
	return sum
