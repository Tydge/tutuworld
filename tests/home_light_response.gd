extends SceneTree
var session: Node
var game: Node3D
var failures: Array[String]=[]
var checks:=0
var readings: Dictionary={}
var output:=preload("res://tests/test_support.gd").output_dir()+"/"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func cheek_brightness() -> float:
	var head: Node3D=game.bunny.get_node("Visual/Head")
	var point: Vector3=head.to_global(Vector3(.20,-.16,game.bunny.rig_profile.head_radii.z*.94))
	var pixel: Vector2i=Vector2i(game.camera.unproject_position(point))
	var photo: Image=root.get_texture().get_image()
	var values: Array[float]=[]
	for x in range(-4,5):
		for y in range(-4,5):
			var c:=photo.get_pixelv(pixel+Vector2i(x,y))
			values.append(c.r*.2126+c.g*.7152+c.b*.0722)
	values.sort();return values[values.size()/2]
func run() -> void:
	root.size=Vector2i(1440,900)
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	for species in ["bunny","cat_teacher"]:
		var created: Dictionary=session.create_character("光影兔" if species=="bunny" else "光影猫",species,"vest_sage")
		check(created.ok,"Creates actual selected species for light measurement: "+species)
		game=load("res://scenes/city.tscn").instantiate();root.add_child(game)
		await create_timer(.8).timeout
		check(game.bunny.rig_profile.species_id==species,"Controlled actor is "+species)
		session.active=false;game.bunny.can_move=false;game.hud.root_ui.hide()
		for inside in [false,true]:
			game.bunny.position=game.home.to_global(Vector3(0,.3,.6)) if inside else Vector3(0,.2,9)
			game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation()
			game.bunny.visual.rotation.y=0
			game.yaw=.12;game.pitch=.40;game.distance_=10.5
			for time_ in [.5,.92]:
				session.state().time=time_*3600;game.update_lighting()
				await create_timer(1.1).timeout;await RenderingServer.frame_post_draw
				var key: String=species+("_room_" if inside else "_park_")+("day" if time_==.5 else "night")
				readings[key]=cheek_brightness();print("CHEEK_LUMA ",key," ",readings[key])
				root.get_texture().get_image().save_png(output+"真实光照-"+key+".png")
			if not inside:
				check(readings[species+"_park_night"]<readings[species+"_park_day"]*.85,"Night actually darkens white fur: "+species)
			else:
				check(readings[species+"_room_night"]>.28,"Warm interior keeps the face readable: "+species)
		game.queue_free();await process_frame;await process_frame
	var ratio: float=readings.cat_teacher_park_night/maxf(.01,readings.bunny_park_night)
	check(ratio>.65 and ratio<1.4,"Cat and bunny have comparable night-light response; ratio="+str(ratio))
	print("LIGHT_RESPONSE_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
