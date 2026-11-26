extends RefCounted
## A temporary two-link rig on the existing skin, outline and worn sleeves.
## No new visible geometry. Bind poses and collision remain those of the actor.
const Score := preload("res://scripts/characters/dance_score.gd")

class Binding:
	static var capsule_skins := {}
	var instance: MeshInstance3D
	var original: Mesh
	var old_path: NodePath
	var old_skin: Skin
	var skeleton: Skeleton3D
	var mesh_basis: Basis

	func _init(limb: Node3D, part: MeshInstance3D, end: Vector3) -> void:
		instance = part
		original = part.mesh
		old_path = part.skeleton
		old_skin = part.skin
		var local := limb.global_transform.affine_inverse() * part.global_transform
		mesh_basis = local.basis.orthonormalized()
		var mesh := weighted_mesh(original,local,end)
		skeleton = Skeleton3D.new()
		skeleton.name = "DanceJoints"
		part.add_child(skeleton)
		skeleton.add_bone("upper")
		skeleton.add_bone("lower")
		skeleton.set_bone_parent(1,0)
		skeleton.set_bone_rest(1,Transform3D(Basis.IDENTITY,local.affine_inverse()*(end*.5)))
		skeleton.reset_bone_poses()
		part.mesh = mesh
		part.skeleton = part.get_path_to(skeleton)
		part.skin = skeleton.create_skin_from_rest_transforms()

	func bend(rotation: Quaternion) -> void:
		var axes := mesh_basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(1,axes.inverse()*rotation*axes)

	func release() -> void:
		if is_instance_valid(instance):
			instance.skeleton = old_path
			instance.skin = old_skin
			instance.mesh = original
			skeleton.free()

	static func weighted_mesh(source: Mesh, local: Transform3D, end: Vector3) -> ArrayMesh:
		# Capsule resources are authored per side and species. The outline uses
		# the same rest space and can share the weighted vertex buffer.
		if source is CapsuleMesh and capsule_skins.has(source):
			return capsule_skins[source]
		var result := ArrayMesh.new()
		for surface in source.get_surface_count():
			var arrays := source.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones := PackedInt32Array()
			var weights := PackedFloat32Array()
			bones.resize(vertices.size()*4)
			weights.resize(vertices.size()*4)
			for i in vertices.size():
				var distance := (local*vertices[i]).dot(end)/end.length_squared()
				var lower := smoothstep(.33,.67,distance)
				bones[i*4+1] = 1
				weights[i*4] = 1.-lower
				weights[i*4+1] = lower
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			result.surface_set_material(surface,source.surface_get_material(surface))
		if source is CapsuleMesh:
			capsule_skins[source] = result
		return result

class Limb:
	var pivot: Node3D
	var end: Vector3
	var skin_parts: Array[Binding] = []
	var clothing: Array[Binding] = []
	var tip: Vector3

	func _init(node: Node3D, rest_end: Vector3) -> void:
		pivot = node
		end = rest_end
		# The first mesh is the authored capsule on all three animals.
		var fur := pivot.get_child(0) as MeshInstance3D
		skin_parts.append(Binding.new(pivot,fur,end))
		skin_parts.append(Binding.new(pivot,fur.get_node("InkOutline"),end))
		fit_clothing()

	func fit_clothing() -> void:
		for part in clothing:
			part.release()
		clothing.clear()
		for slot in pivot.get_children():
			if not str(slot.name).begins_with("Wardrobe_"):
				continue
			if slot is MeshInstance3D:
				clothing.append(Binding.new(pivot,slot,end))
			for mesh in slot.find_children("*","MeshInstance3D",true,false):
				clothing.append(Binding.new(pivot,mesh,end))

	func aim(upper: Vector3, lower: Vector3) -> void:
		var axis := end.normalized()
		pivot.quaternion = Quaternion(axis,upper)
		var bend := Quaternion(axis,pivot.quaternion.inverse()*lower)
		for part in skin_parts:
			part.bend(bend)
		for part in clothing:
			part.bend(bend)
		tip = pivot.position + (upper+lower)*(.5*end.length())

	func reach(target: Vector3, side: float) -> void:
		var offset := target-pivot.position
		var direction := offset.normalized()
		var reach_length := minf(offset.length()/end.length(),.99999)
		# The knee points slightly outwards as it folds towards the audience.
		var pole := Vector3(side*.35,0,1).slide(direction).normalized()
		var fold := pole*sqrt(maxf(0.,1.-reach_length*reach_length))
		aim(direction*reach_length+fold,direction*reach_length-fold)

	func release() -> void:
		for part in clothing + skin_parts:
			part.release()

var actor: CharacterBody3D
var arms: Array[Limb] = []
var legs: Array[Limb] = []
var hip: Vector3
var fan: Node3D
var foot_radius: float
var entry: Array[Quaternion] = []

func _init(animal: CharacterBody3D) -> void:
	actor = animal
	if actor.emote==Score.CLOUD:
		fan = preload("res://scripts/characters/dance_fan.gd").make(actor.visual)
	var grip: Vector3 = actor.rig_profile.grip_offset
	arms.append(Limb.new(actor.left_arm,Vector3(-grip.x,grip.y,grip.z)))
	arms.append(Limb.new(actor.right_arm,grip))
	for pivot in [actor.left_leg,actor.right_leg]:
		legs.append(Limb.new(pivot,actor.rig_profile.leg_end))
	hip = (actor.leg_rest_left+actor.leg_rest_right)*.5
	foot_radius = actor.rig_profile.leg_radius
	for arm in arms:
		entry.append(arm.pivot.quaternion)
	actor.wardrobe_changed.connect(refit)

func refit() -> void:
	for limb in arms+legs:
		limb.fit_clothing()

func release() -> void:
	if is_instance_valid(fan):
		fan.free()
	actor.wardrobe_changed.disconnect(refit)
	for limb in arms+legs:
		limb.release()
	actor.head.rotation.y = 0.
	var heading: float = actor.visual_heading()
	actor.emote_turn = 0.
	actor.emote_shift = Vector2.ZERO
	actor.visual.position = Vector3.ZERO
	actor.set_visual_heading(heading)

static func arm_direction(side: float,elevation: float,sweep: float) -> Vector3:
	var a := deg_to_rad(elevation)
	var b := deg_to_rad(sweep)
	return Vector3(side*cos(a)*cos(b),sin(a),cos(a)*sin(b))

func place_arm(index: int,shape: Vector3,strength: float) -> void:
	var side := -1. if index==0 else 1.
	var arm := arms[index]
	var upper := arm_direction(side,shape.x,shape.z)
	var lower := arm_direction(side,shape.x+shape.y,shape.z+15.)
	if strength<1.:
		var start := entry[index]*arm.end.normalized()
		upper = start.slerp(upper,strength).normalized()
		lower = start.slerp(lower,strength).normalized()
	arm.aim(upper,lower)

func apply(id: String,age: float) -> void:
	var pose := Score.sample(id,age)
	var strength := smoothstep(0.,.22,age)
	var heading: float = actor.visual_heading()
	var base := Basis(Vector3.UP,heading)
	var length_ := legs[0].end.length()
	var step_scale := Vector3(.78,1.,.83)*strength
	var steps := [pose.left_step*step_scale, pose.right_step*step_scale]
	var share := .5+.5*pose.weight*strength
	var feet: Array[Vector3] = []
	for i in 2:
		var rest: Vector3 = legs[i].pivot.position + legs[i].end
		rest.y = foot_radius + pose.flight*strength
		feet.append(rest + steps[i]*length_)
	var pivot := feet[0].lerp(feet[1],share)
	var spin := Basis(Vector3.UP,pose.spin)
	# Stage targets stay put under torso twists. During a complete turn only
	# the airborne foot circles the supporting paw.
	for i in 2:
		feet[i] = pivot+spin*(feet[i]-pivot)
	var midpoint := (feet[0]+feet[1])*.5
	var center := midpoint.lerp(feet[0].lerp(feet[1],share),.60)
	center.y = 0.
	var angles := pose.torso*(PI/180.)*strength
	# Broader hips on a short-legged animal allow less axial twist
	# between planted feet; transfer the remaining turn to the gaze.
	var hip_width := absf(legs[1].pivot.position.x-legs[0].pivot.position.x)
	var twist_share := clampf(length_/hip_width,.56,1.)
	var neck_turn := angles.z*(1.-twist_share)
	angles.z *= twist_share
	var torso := spin*Basis.from_euler(Vector3(angles.x,angles.z,angles.y))
	var origin := center-torso*hip
	# Keep the pelvis inside both reach circles, even when two planted
	# feet straddle a wide lunge. Lowering alone would bury the short legs.
	var floor_extension := minf(.77,pose.extension)
	for iteration in 3:
		for i in 2:
			var socket := origin+torso*legs[i].pivot.position
			var offset := Vector2(socket.x-feet[i].x,socket.z-feet[i].z)
			var min_drop := maxf(0.,floor_extension*length_-steps[i].y*length_+socket.y)
			var allowed := sqrt(maxf(.01*length_*length_,length_*length_-min_drop*min_drop))
			var correction := offset.limit_length(allowed)-offset
			origin.x += correction.x
			origin.z += correction.y
	# Choose a reachable pelvis height from both legs before solving knees.
	# This preserves the sole position and link lengths on short-legged cats.
	var height := hip.y+pose.flight*strength+length_*(lerpf(1.,pose.extension,strength)-1.)
	for i in 2:
		var socket := origin+torso*legs[i].pivot.position
		var horizontal := Vector2(socket.x-feet[i].x,socket.z-feet[i].z).length_squared()
		var ceiling := sqrt(maxf(0.,length_*length_-horizontal))
		height = minf(height,feet[i].y+ceiling-socket.y)
	origin.y += height
	var scale_: Vector3 = actor.visual_rest_scale
	actor.emote_stretch = 0.
	actor.emote_shift = Vector2.ZERO
	actor.visual.transform = Transform3D((base*torso).scaled_local(scale_),base*(origin*scale_))
	actor.emote_turn = wrapf(actor.visual.rotation.y-heading,-PI,PI)
	for i in 2:
		legs[i].reach(torso.transposed()*(feet[i]-origin),-1. if i==0 else 1.)
	place_arm(0,pose.left_arm,strength)
	place_arm(1,pose.right_arm,strength)
	if is_instance_valid(fan):
		fan.position = arms[1].tip
		# Open the face on the sweeping diagonal, then turn it through the
		# wrist as the hands gather in front of the chest.
		var open := inverse_lerp(-65.,25.,pose.right_arm.x)
		fan.rotation_degrees = Vector3(32.-open*24.,pose.right_arm.z*.92-18.,-108.+open*59.)
	var gaze := pose.gaze*(PI/180.)*strength
	actor.head.rotation = Vector3(gaze.x,gaze.z+neck_turn,gaze.y)
	for i in 2:
		var rest: float = actor.rig_profile.ear_rest[i]
		var motion: float = actor.rig_profile.ear_motion
		actor.ears[i].rotation = Vector3(pose.ear*motion,0.,rest-gaze.z*.35*motion)
