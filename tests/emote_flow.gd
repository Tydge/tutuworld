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

# The pupil spans the gap between lids. Its triangles must clear the curved
# cheek even at their centers when the surprised cat opens its eyes wide.
func pupil_clears_cheek(mesh: ArrayMesh, pivot: Vector3) -> bool:
	const Surface = preload("res://scripts/characters/cat_surface.gd")
	var indices: PackedInt32Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	var target: PackedVector3Array = mesh.surface_get_blend_shape_arrays(0)[0][Mesh.ARRAY_VERTEX]
	for i in range(0,indices.size(),3):
		var p := pivot+(target[indices[i]]+target[indices[i+1]]+target[indices[i+2]])/3.
		var skin := Surface.face_point(Vector2(p.x,p.y))
		if p.z < skin.z-Surface.INK_OFFSET:
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
		var mouth_transform: Transform3D = actor.mouth.transform
		var brush: MeshInstance3D = actor.eyes.get_node_or_null("Brushwork")
		var neutral_ink: Mesh = brush.mesh if brush != null else null
		tick(actor, 75)
		var base := rig(actor)
		for id in Emotes.KEY_ORDER + Emotes.SOCIAL:
			actor.trigger_emote(id)
			tick(actor, 54)
			check(actor.emote == id and not actor.seated and not actor.sleeping and actor.can_move,species+" performs "+id+" without gameplay locks")
			check(rig(actor) != base,species+" changes body pose for "+id)
			if species == "bunny":
				check(actor.eyes.visible and actor.eyes.transform.is_equal_approx(eye_transform) and (brows == null or brows.transform == brow_transform), "Rabbit eye and eyebrow geometry stays neutral for "+id)
				if id in ["wave","thanks","love","agree"]:
					check(actor.mouth.visible and actor.mouth.transform==mouth_transform,"Rabbit keeps its resting mouth for "+id)
					if id=="thanks":
						var mesh: ArrayMesh = actor.emote_face.mesh
						var left := false
						var right := false
						var only_cheeks := true
						for v: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
							left = left or v.x<0.
							right = right or v.x>0.
							only_cheeks = only_cheeks and absf(v.x)>.34 and v.y<-.14 and v.y>-.24
						check(actor.emote_face.visible and mesh.get_surface_count()==1 and left and right and only_cheeks,"Rabbit thanks adds just two blush marks below the eyes")
					else:
						check(actor.emote_face==null or not actor.emote_face.visible,"Rabbit shows the untouched resting face for "+id)
				elif id in Emotes.SOCIAL:
					var face: AABB = actor.emote_face.mesh.get_aabb()
					check(actor.emote_face.visible and not actor.mouth.visible and face.end.y < -.20 and face.position.y > -.53,"Only the rabbit mouth receives expression geometry for "+id)
				else:
					check(actor.emote_face == null,"Rabbit legacy emotes keep their original face")
			if Emotes.is_expression(id):
				check(is_instance_valid(actor.emote_effects) and actor.emote_effects.visible,species+" shows comic effect for "+id)
				if species != "bunny":
					var native_eyes: bool = (species=="cat_teacher" and id in Emotes.SOCIAL) or (species=="panda" and id=="refuse")
					check(actor.emote_face.visible and actor.emote_face.mesh.get_surface_count()>0 and actor.eyes.visible==native_eyes and not actor.mouth.visible,species+" shows its expression for "+id)
					if native_eyes:
						check(actor.emote_face.mesh.get_aabb().end.y<-.14,species+" keeps extra face paint below the eyes for "+id)
					if species=="cat_teacher" and id in Emotes.SOCIAL:
						check(brush.mesh.get_blend_shape_count()==1 and brush.get_blend_shape_value(0)>.9 and brush.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==neutral_ink.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"Cat uses the original eye strokes as the neutral shape for "+id)
						if id=="shock":
							check(pupil_clears_cheek(brush.mesh,actor.eyes.position),"Cat surprised pupils clear the curved cheek")
			if id=="sweat":
				check(actor.emote_effects.particles.size()==1 and actor.emote_effects.particles[0].has_node("BigSweatDrop"),species+" shows one oversized sweat drop")
			if id=="love":
				check(actor.emote_effects.particles[0].has_node("Heart"),species+" sends a shaped heart")
			if id == "lie":
				check(actor.visual.basis.y.dot(Vector3.UP)<.13 and actor.visual.position.y>.4,species+" lies horizontally instead of rotating into the ground")
			if id == "sit":
				check(actor.visual.position.y<-.12 and actor.left_leg.transform.basis.y.dot(Vector3.UP)<.35,species+" sits at floor height with paws forward")
			if Emotes.is_short(id):
				tick(actor, 75)
				if brush!=null and id in Emotes.SOCIAL:
					check(brush.mesh==neutral_ink,"Cat restores its exact resting eye mesh after "+id)
				check(actor.emote.is_empty() and actor.eyes.visible and actor.mouth.visible and (actor.emote_effects==null or not actor.emote_effects.visible),species+" finishes and restores neutral face after two seconds for "+id)
			else:
				var hold_frames := int(ceil(float(Emotes.DANCES.get(id,8.0))*2.1/STEP))
				tick(actor,hold_frames)
				check(actor.emote == id,species+" retains or loops "+id)
				actor.stop_emote()
			tick(actor, 40)

		actor.trigger_emote("snicker")
		tick(actor, 36)
		actor.trigger_emote("laugh")
		tick(actor, 36)
		if species == "bunny":
			check(actor.eyes.visible and actor.mouth.visible and not actor.emote_face.visible,"Rabbit restores its own face when a legacy laugh interrupts a social emote")
		else:
			check(actor.emote_face.visible and actor.emote_face.current==species+"/laugh",species+" switches to its legacy laugh face")
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

func rendered_tip(limb) -> Vector3:
	# Use the skin's actual inverse bind and animated bone, not the IK target.
	var skin = limb.skin_parts[0]
	var mesh: MeshInstance3D = skin.instance
	var rest_tip: Vector3 = mesh.transform.affine_inverse()*limb.end
	var distal: Transform3D = skin.skeleton.get_bone_global_pose(1)*mesh.skin.get_bind_pose(1)
	return mesh.to_global(distal*rest_tip)

func test_stage_dances() -> void:
	const Score := Emotes.Score
	const Outfit := preload("res://scripts/city/outfit.gd")
	for species in Animals.Catalog.ids():
		var actor := Animals.create(species)
		root.add_child(actor)
		actor.set_physics_process(false)
		actor.network_replica = true
		actor.set_visual_heading(.82)
		Outfit.apply(actor,{"body":"overalls_honey"})
		var original := {}
		for limb in [actor.left_arm,actor.right_arm,actor.left_leg,actor.right_leg]:
			var mesh: MeshInstance3D = limb.get_child(0)
			for part in [mesh,mesh.get_node("InkOutline")]:
				original[part] = [part.mesh,part.skin,part.skeleton]

		for id in Score.DURATIONS:
			var period: float = Score.DURATIONS[id]
			Outfit.apply(actor,{"body":"oxford_shirt_tide" if id==Score.STREET else "overalls_honey"})
			actor.trigger_emote(id)
			var previous := [Vector3.ZERO,Vector3.ZERO]
			var planted := [false,false]
			var slip := 0.
			var floor_error := 0.
			var worst_scale := 0.
			var min_clearance := INF
			var opening: Array
			var seam_error := 0.
			var frames := roundi(period/STEP)
			for frame in range(frames*2+1):
				actor.animate_pose(STEP)
				var p := Score.sample(id,actor.emote_age)
				var contact := [p.left_step.y<.00001 and p.flight<.00001,p.right_step.y<.00001 and p.flight<.00001]
				for side in 2:
					var paw := rendered_tip(actor.dance_rig.legs[side])
					if contact[side]:
						floor_error=maxf(floor_error,absf(paw.y-actor.rig_profile.leg_radius))
						if planted[side]:
							slip=maxf(slip,paw.distance_to(previous[side]))
					planted[side]=contact[side]
					previous[side]=paw
				var up := Vector3(actor.visual.basis.x.y,actor.visual.basis.y.y,actor.visual.basis.z.y)
				var bottom: float=(actor.visual.transform*actor.rig_profile.body_center).y-(up*actor.rig_profile.body_radii).length()
				min_clearance=minf(min_clearance,bottom)
				for limb in actor.dance_rig.arms+actor.dance_rig.legs:
					worst_scale=maxf(worst_scale,limb.pivot.scale.distance_to(Vector3.ONE))
				if frame==frames-1:
					opening=rig(actor)
				if frame==frames*2-1:
					var closing:=rig(actor)
					for i in opening.size():
						seam_error=maxf(seam_error,opening[i].origin.distance_to(closing[i].origin))
						seam_error=maxf(seam_error,opening[i].basis.get_rotation_quaternion().angle_to(closing[i].basis.get_rotation_quaternion()))
			var clothed = actor.dance_rig.arms[0] if id==Score.STREET else actor.dance_rig.legs[0]
			check(not clothed.clothing.is_empty(),species+" bends the worn sleeve or trouser cuff")
			check(is_instance_valid(actor.dance_rig.fan)==(id==Score.CLOUD),species+" equips the correct dance prop")
			check(period>=10. and seam_error<.002,species+" wraps a complete "+id+" score")
			check(slip<.001 and floor_error<.001,species+" plants the rendered paws in "+id+" slip="+str(slip)+" floor="+str(floor_error))
			check(worst_scale<.0001 and min_clearance>0.,species+" preserves limb size and clears the floor in "+id)
			actor.trigger_emote(id)
			check(actor.dance_rig==null and not actor.visual.has_node("SilkFan") and absf(angle_difference(actor.visual_heading(),.82))<.001,species+" exits "+id+" facing the original heading")
			for part in original:
				check([part.mesh,part.skin,part.skeleton]==original[part] and not part.has_node("DanceJoints"),species+" restores original skin and outline")
		actor.sync_emote({"emote":Score.CLOUD,"emote_age":8.4,"emote_revision":32})
		actor.animate_pose(STEP)
		check(actor.dance_rig!=null and actor.emote_age>8.4,species+" joins a dance already in progress")
		Outfit.apply(actor,{})
		actor.trigger_emote("think")
		actor.animate_pose(STEP)
		check(actor.dance_rig==null and actor.emote=="think",species+" switches straight back to a legacy emote")
		actor.free()

func key(code: Key, pressed: bool = true, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.shift_pressed = shift
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
	test_stage_dances()
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
	for code in Emotes.STAGE_KEYS:
		key(code)
		await wait_frames(3)
		key(code,false)
		check(city.bunny.emote==Emotes.STAGE_KEYS[code] and not city.screenshot_busy,"Function key plays "+Emotes.STAGE_KEYS[code])
	key(KEY_G)
	await wait_frames(3)
	key(KEY_G,false)
	check(city.bunny.emote==Emotes.STAGE_KEYS[KEY_F11],"G plays street dance without an OS function key")
	var social_ids := ["wave","cheer","thanks","love","agree","refuse","snicker","sweat","shock"]
	for i in social_ids.size():
		key(KEY_F1+i)
		await wait_frames(5)
		key(KEY_F1+i,false)
		check(city.bunny.emote==social_ids[i] and not city.hud.photo_mode and not city.build_mode.active,"F%d starts %s alone" % [i+1,social_ids[i]])
	key(KEY_F9)
	await wait_frames(2)
	key(KEY_F9,false)
	check(city.bunny.emote=="shock" and city.bunny.emote_age<.08,"Repeating a short gesture restarts it")
	var initial_run: bool = city.bunny.run_enabled
	for enabled in [true,false]:
		key(KEY_SHIFT,true,true)
		if enabled:
			await wait_frames(3)
			check(city.bunny.run_enabled!=initial_run,"Plain Shift toggles running on press")
		key(KEY_F2,true,true)
		await wait_frames(2)
		key(KEY_F2,false,true)
		key(KEY_SHIFT,false)
		await wait_frames(2)
		check(city.bunny.run_enabled==initial_run,"A Shift shortcut preserves the previous run toggle")
		check(city.hud.photo_mode==enabled and city.bunny.emote!="cheer","Shift+F2 toggles framing independently")
	var photo := InputEventKey.new()
	photo.physical_keycode=KEY_F12
	photo.pressed=true
	check(not photo.is_action_pressed("screenshot"),"Plain F12 is reserved for dance")
	photo.shift_pressed=true
	check(Emotes.from_key(photo)=="" and photo.is_action_pressed("screenshot"),"Shift+F12 retains photography")
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
	key(KEY_F6)
	await wait_frames(2)
	key(KEY_F6,false)
	check(city.bunny.emote.is_empty() and not city.build_mode.active,"Settings ignores social and build shortcuts on plain F6")
	city.hud.close_panel()
	city.queue_free()
	await process_frame
	session.queue_free()
	# Allow the audio thread to release the city ambience after scene teardown.
	await create_timer(.2).timeout
	print("EMOTE_FLOW_RESULT ", "PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
