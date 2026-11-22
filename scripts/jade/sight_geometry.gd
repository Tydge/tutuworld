extends Resource
## Shared mesh geometry for camera cutaways, without extra physics bodies.
@export var triangles := PackedVector3Array()
@export var bounds := AABB()
var tree: TriangleMesh

const BODY_OFFSETS := [Vector3.ZERO, Vector3(0,.87,0), Vector3(-.38,.30,0), Vector3(.38,.30,0), Vector3(0,-.59,0)]
const LENS_CLEARANCE := 2.2
static var lens_frame := -1
static var lens_camera := 0
static var world_rays := PackedVector3Array()

static func profile(mesh: Mesh) -> Resource:
	if mesh.has_meta("jade_sight_profile"):
		return mesh.get_meta("jade_sight_profile")
	var out := new()
	var faces := mesh.get_faces()
	for i in range(0,faces.size(),3):
		var a := faces[i]
		var b := faces[i+1]
		var c := faces[i+2]
		# Tiny knobs, tile ends and lattice wires do not conceal a character.
		if (b-a).cross(c-a).length_squared() < .0016:
			continue
		out.triangles.append(a)
		out.triangles.append(b)
		out.triangles.append(c)
	if not out.triangles.is_empty():
		out.bounds = AABB(out.triangles[0],Vector3.ZERO)
		for v in out.triangles:
			out.bounds = out.bounds.expand(v)
	mesh.set_meta("jade_sight_profile",out)
	return out

static func bake_room(room: Node3D, names: Array = ["Exterior","Front","Rear","West","East"]) -> void:
	var sections: Dictionary = {}
	for section in names:
		var part := room.get_node_or_null(section)
		if not part:
			continue
		var pieces: Array = []
		var limit := AABB()
		for m: MeshInstance3D in part.find_children("*","MeshInstance3D",true,false):
			if m.mesh == null or m.get_meta("appearance_effect",false):
				continue
			var data := profile(m.mesh)
			if data.triangles.is_empty():
				continue
			var pose := m.transform
			var parent := m.get_parent() as Node3D
			while parent and parent != room:
				pose = parent.transform * pose
				parent = parent.get_parent() as Node3D
			var bound: AABB = (pose * data.bounds).grow(.025)
			limit = bound if pieces.is_empty() else limit.merge(bound)
			pieces.append([bound,pose.affine_inverse(),data])
		if not pieces.is_empty():
			sections[section] = [limit,pieces]
	room.set("sight_sections",sections)

func prepare_tree() -> void:
	if tree == null:
		tree = TriangleMesh.new()
		tree.create_from_faces(triangles)

static func prepare_sections(sections: Dictionary) -> void:
	for section: Array in sections.values():
		for piece: Array in section[1]:
			piece[2].prepare_tree()

func hits(begin: Vector3,end: Vector3) -> bool:
	prepare_tree()
	return not tree.intersect_segment(begin,end).is_empty()

static func obscures(section: Array,head: Vector3,eye: Vector3) -> bool:
	if section.is_empty():
		return false
	var limit: AABB = section[0]
	if limit.grow(.99).intersects_segment(head,eye) == null:
		return false
	for piece in section[1]:
		var bound: AABB = piece[0]
		if bound.grow(.99).intersects_segment(head,eye) == null:
			continue
		var inverse: Transform3D = piece[1]
		var local_eye := inverse * eye
		for offset in BODY_OFFSETS:
			var start: Vector3 = head + offset
			if bound.intersects_segment(start,eye) != null and piece[2].hits(inverse*start,local_eye):
				return true
	return false

static func lens_rays(camera: Camera3D) -> PackedVector3Array:
	var frame := Engine.get_process_frames()
	if frame != lens_frame or camera.get_instance_id() != lens_camera:
		var size_ := camera.get_viewport().get_visible_rect().size
		world_rays.clear()
		for y in [.2,.5,.8]:
			for x in [.2,.5,.8]:
				world_rays.append(camera.project_ray_normal(size_*Vector2(x,y))*LENS_CLEARANCE)
		lens_frame = frame
		lens_camera = camera.get_instance_id()
	return world_rays

## At a wall corner the actor can be visible through a narrow slit while a beam
## fills the frame. Require two distinct screen samples inside the near volume.
static func clips_lens(section: Array,room: Node3D,eye: Vector3,camera: Camera3D) -> bool:
	if section.is_empty():
		return false
	var inverse := room.global_basis.inverse()
	var scale_ := inverse.get_scale().abs()
	var reach := LENS_CLEARANCE * scale_[scale_.max_axis_index()] + .03
	var limit: AABB = section[0]
	if not limit.grow(reach).has_point(eye):
		return false
	var covered := 0
	for ray in lens_rays(camera):
		var end := eye + inverse * ray
		if limit.intersects_segment(eye,end) == null:
			continue
		for piece in section[1]:
			var bound: AABB = piece[0]
			if bound.intersects_segment(eye,end) == null:
				continue
			var local_: Transform3D = piece[1]
			if piece[2].hits(local_*eye,local_*end):
				covered += 1
				break
		if covered >= 2:
			return true
	return false
