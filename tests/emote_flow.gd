extends SceneTree

const Animals = preload("res://scripts/characters/animal_factory.gd")
const Emotes = preload("res://scripts/characters/emote_motion.gd")
const STEP := 1.0 / 60.0
const KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("FAIL ", label)

func tick(actor: CharacterBody3D, frames: int) -> void:
	for i in range(frames):
		actor.animate_pose(STEP)

func rig(actor: CharacterBody3D) -> Array:
	return [actor.visual.transform,actor.head.transform,actor.left_arm.transform,actor.right_arm.transform,
		actor.left_leg.transform,actor.right_leg.transform]

func pose_signature(pose: Emotes.Pose) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	for limb in [pose.left_arm,pose.right_arm,pose.left_leg,pose.right_leg]:
		values.append_array(PackedFloat32Array([limb.x,limb.y,limb.z]))
	values.append_array(PackedFloat32Array([pose.shift.x,pose.shift.y,pose.lift,pose.lean,pose.roll,pose.head_roll,pose.head_pitch,sin(pose.turn),cos(pose.turn),pose.stretch]))
	return values

func near_signature(a: PackedFloat32Array, b: PackedFloat32Array) -> bool:
	for i in range(a.size()):
		if absf(a[i]-b[i]) > .0001:
			return false
	return true

func test_poses() -> void:
	for id in Emotes.DANCES:
		var period: float = Emotes.DANCES[id]
		check(period >= 10.,id+" lasts at least ten seconds")
		check(near_signature(pose_signature(Emotes.sample(id,0.)),pose_signature(Emotes.sample(id,period))),id+" wraps at the same pose")
		check(near_signature(pose_signature(Emotes.sample(id,.37)),pose_signature(Emotes.sample(id,period+.37))),id+" repeats the complete phrase")
		check(not near_signature(pose_signature(Emotes.sample(id,.37)),pose_signature(Emotes.sample(id,period*.46+.37))),id+" develops across the phrase")

	for species in Animals.Catalog.ids():
		var actor := Animals.create(species)
		root.add_child(actor)
		actor.set_physics_process(false)
		actor.network_replica = true
		var brows: Node3D = actor.head.get_node_or_null("FixedEyebrows")
		var brow_transform: Transform3D = brows.transform if brows != null else Transform3D.IDENTITY
		var eye_transform: Transform3D = actor.eyes.transform
		tick(actor, 75)
		var base := rig(actor)
		for id in Emotes.KEY_ORDER:
			actor.trigger_emote(id)
			tick(actor, 54)
			check(actor.emote == id and not actor.seated and not actor.sleeping and actor.can_move,species+" performs "+id+" without gameplay locks")
			check(rig(actor) != base,species+" changes body pose for "+id)
			if species == "bunny":
				check(actor.eyes.visible and actor.eyes.transform.is_equal_approx(eye_transform) and (brows == null or brows.transform == brow_transform) and actor.emote_face == null,"Rabbit eye and eyebrow geometry stays neutral for "+id)
			if id in Emotes.EXPRESSIONS:
				check(is_instance_valid(actor.emote_effects) and actor.emote_effects.visible,species+" shows comic effect for "+id)
				if species != "bunny":
					check(actor.emote_face.visible and actor.emote_face.mesh.get_surface_count()>0 and not actor.eyes.visible and not actor.mouth.visible,species+" shows its expression for "+id)
			if id == "lie":
				check(actor.visual.basis.y.dot(Vector3.UP)<.13 and actor.visual.position.y>.4,species+" lies horizontally instead of rotating into the ground")
			if id == "sit":
				check(actor.visual.position.y<-.12 and actor.left_leg.transform.basis.y.dot(Vector3.UP)<.35,species+" sits at floor height with paws forward")
			if Emotes.is_short(id):
				tick(actor, 75)
				check(actor.emote.is_empty() and actor.eyes.visible and actor.mouth.visible and (actor.emote_effects==null or not actor.emote_effects.visible),species+" finishes and restores neutral face after two seconds for "+id)
			else:
				var hold_frames := int(ceil(float(Emotes.DANCES.get(id,8.0))*2.1/STEP))
				tick(actor,hold_frames)
				check(actor.emote == id,species+" retains or loops "+id)
				actor.stop_emote()
			tick(actor, 40)

		var reference := Animals.create(species)
		root.add_child(reference)
		reference.set_physics_process(false)
		reference.network_replica = true
		for speed in [3.5,5.95]:
			for comparing in [actor,reference]:
				comparing.walking = true
				comparing.animation_speed = speed
				comparing.clock = 0.
				comparing.blink_in = 50.
				comparing.blink_time = -1.
			for frame in range(120):
				for comparing in [actor,reference]:
					comparing.step_phase = frame * .16
					comparing.animate_pose(STEP)
			var actual := rig(actor)
			var unchanged := true
			var ordinary := rig(reference)
			for i in range(actual.size()):
				unchanged = unchanged and actual[i].is_equal_approx(ordinary[i])
			check(unchanged,species+" returns to the ordinary gait at speed "+str(speed))
		actor.queue_free()
		reference.queue_free()

func key(code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func wait_frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func run() -> void:
	test_poses()
	var session := preload("res://scripts/services/session.gd").new()
	session.name = "Session"
	root.add_child(session)
	check(session.create_character("动作验收","bunny","bow_rose").ok,"Create isolated player")
	var city: Node3D = load("res://scenes/city.tscn").instantiate()
	root.add_child(city)
	while city.preparing or city.bunny == null or not city.bunny.is_on_floor():
		await physics_frame
	for i in range(KEYS.size()):
		key(KEYS[i])
		await wait_frames(2)
		key(KEYS[i],false)
		check(city.bunny.emote==Emotes.KEY_ORDER[i],"In-game number key "+str((i+1)%10))
	key(KEY_5)
	await wait_frames(2)
	key(KEY_5,false)
	await wait_frames(35)
	key(KEY_5)
	await wait_frames(2)
	key(KEY_5,false)
	check(city.bunny.emote=="lie","Repeating the lying key keeps the held position")
	key(KEY_D)
	await wait_frames(7)
	key(KEY_D,false)
	check(city.bunny.emote.is_empty(),"Walking input cancels the held animation")
	await wait_frames(18)
	key(KEY_6)
	await wait_frames(18)
	key(KEY_6,false)
	check(city.bunny.emote=="sit","Sitting waits for movement")
	key(KEY_SPACE)
	await wait_frames(4)
	key(KEY_SPACE,false)
	check(city.bunny.emote.is_empty() and city.bunny.velocity.y>0.,"Jump cancels the pose and actually jumps")
	await wait_frames(60)
	city.hud.open_panel("settings")
	key(KEY_8)
	await wait_frames(2)
	key(KEY_8,false)
	check(city.bunny.emote.is_empty(),"Open panel does not activate number keys")
	city.hud.close_panel()
	city.queue_free()
	await process_frame
	session.queue_free()
	await process_frame
	print("EMOTE_FLOW_RESULT ", "PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
