extends SceneTree
## Compare the cat's face to its own white fur on identical geometry in the city.
const Surface = preload("res://scripts/characters/cat_surface.gd")
const SkinSamples = [Vector2(0,-.025), Vector2(.12,-.20), Vector2(-.14,-.28), Vector2(-.40,.055)]
const InkSamples = {
	"cheek": Vector2(.4274,-.2304),
	"pupil": Vector2(.305,-.078),
	"lip": Vector2(.014,-.34),
}
const Times = {"noon": .5, "dusk": (18.+38./60.)/24., "night": .95}
var city: Node3D
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func take_frame() -> Image:
	for frame in range(4):
		await process_frame
		RenderingServer.force_draw()
	return root.get_texture().get_image()

func sample(image: Image, actor: Node3D, point: Vector2) -> Color:
	return world_pixel(image,actor.head.to_global(Surface.face_point(point)))

func world_pixel(image: Image, world: Vector3) -> Color:
	var pixel: Vector2 = city.camera.unproject_position(world)*Vector2(image.get_size())/root.get_visible_rect().size
	return image.get_pixelv(Vector2i(pixel))

func set_face_material(actor: Node3D, material: Material, show_ink: bool) -> void:
	actor.head.get_node("RoundCatHead").material_override = material
	for part in ["Eyes", "Mouth", "CheekMarkings", "Nose"]:
		actor.head.get_node(part).visible = show_ink

func compare(actor: Node3D, phase: String, actual: Image, reference: Image) -> void:
	var worst := 0.
	for point in SkinSamples:
		var fur := sample(actual,actor,point)
		var body := sample(reference,actor,point)
		worst = maxf(worst,maxf(absf(fur.r-body.r),maxf(absf(fur.g-body.g),absf(fur.b-body.b))))
	print("CAT_CITY_FUR ",actor.name," ",phase," difference=",worst)
	if worst > .035:
		failures.append("%s %s head and body materials disagree" % [actor.name,phase])
	for part in InkSamples:
		var point: Vector2 = InkSamples[part]
		var ink := sample(actual,actor,point).get_luminance()
		var fur := sample(reference,actor,point).get_luminance()
		if ink >= fur*.83:
			failures.append("%s %s %s is missing or too bright against fur (%.3f / %.3f)" % [actor.name,phase,part,ink,fur])

# A convex belly should shade the same with its own shadow caster enabled.
# Keep the rest of the character present so the head still shadows the chest.
func compare_belly_shadow(actor: Node3D, actual: Image) -> void:
	var torso: MeshInstance3D = actor.get_node("Visual/Torso")
	var casting := torso.cast_shadow
	torso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var reference := await take_frame()
	torso.cast_shadow = casting
	var affected := 0
	var count := 0
	for iy in range(-13,11):
		for ix in range(-12,13):
			var xy := Vector2(ix,iy)*.04
			var world := torso.to_global(Vector3(xy.x,xy.y,sqrt(1.-xy.length_squared())))
			var delta := world_pixel(reference,world).get_luminance()-world_pixel(actual,world).get_luminance()
			if delta > .015:
				affected += 1
			count += 1
	print("CAT_CITY_SHADOW ",affected,"/",count)
	# Allow isolated shadow-map pixels near grazing angles on different GPUs.
	if affected > .05*count:
		failures.append("Daytime sunlight draws shadow bands across the belly")

func run() -> void:
	var session := preload("res://scripts/services/session.gd").new()
	session.name = "Session"
	root.add_child(session)
	session.settings.background_throttle = false
	if not session.create_character("灯下的小猫","cat_teacher","bow_rose").ok:
		quit(1)
		return
	city = preload("res://scenes/city.tscn").instantiate()
	root.add_child(city)
	while not city.camera or city.preparing:
		await process_frame
	session.active = false
	city.set_process(false)
	city.hud.hide()
	var actors: Array[Node3D] = [city.bunny,city.get_node("CatTeacher")]
	for npc in city.npcs:
		if npc not in actors:
			npc.hide()
			npc.process_mode = Node.PROCESS_MODE_DISABLED
	var head_mesh: MeshInstance3D = actors[0].head.get_node("RoundCatHead")
	var original := head_mesh.material_override
	var white: Material = actors[0].get_node("Visual/LeftArm/Arm").material_override
	var center := Vector3(-9.,.07,17.6)
	for i in range(actors.size()):
		var actor := actors[i]
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		actor.position = center+Vector3(1.15 if i==0 else -1.15,0,0)
		actor.visual.rotation = Vector3.ZERO
		actor.reset_physics_interpolation()
	city.camera.position = center+Vector3(.15,2.25,6.1)
	city.camera.look_at(center+Vector3.UP*1.32)
	city.camera.reset_physics_interpolation()
	var out := preload("res://tests/test_support.gd").output_dir()
	var cheek_luminance := {}
	for phase in Times:
		var fraction: float = Times[phase]
		session.state().time = fraction*3600.
		city.update_lighting(fraction)
		var actual := await take_frame()
		actual.save_png(out.path_join(phase+".png"))
		if phase == "noon":
			await compare_belly_shadow(actors[0],actual)
		cheek_luminance[phase] = sample(actual,actors[0],InkSamples.cheek).get_luminance()
		for actor in actors:
			set_face_material(actor,white,false)
		var reference := await take_frame()
		for actor in actors:
			compare(actor,phase,actual,reference)
			set_face_material(actor,original,true)
	print("CAT_CHEEK_PAINT ",cheek_luminance)
	if cheek_luminance.dusk >= cheek_luminance.noon*.82:
		failures.append("Cheek paint stays bright in evening light")
	print("CAT_CITY_LIGHTING_RESULT ","PASS" if failures.is_empty() else "FAIL"," ",failures)
	city.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
