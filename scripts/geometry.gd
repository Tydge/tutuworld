class_name GardenGeometry
extends RefCounted

static var palette: Dictionary = {}
static var outlines: ShaderMaterial

static func mat(hex: String, roughness: float = 0.85, emission: float = 0.0) -> StandardMaterial3D:
	var key := hex + str(roughness) + str(emission)
	if palette.has(key): return palette[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = roughness
	if emission > 0:
		m.emission_enabled = true
		m.emission = Color(hex)
		m.emission_energy_multiplier = emission
	palette[key] = m
	return m

static func outline_mat() -> ShaderMaterial:
	if outlines == null:
		outlines = ShaderMaterial.new()
		var shader := Shader.new()
		# Correct for each part's scale so ears, head and skin share the same stroke.
		shader.code = "shader_type spatial; render_mode unshaded, cull_front; uniform float outline_width = 0.035; void vertex(){ mat3 inverse_modelview = inverse(mat3(MODELVIEW_MATRIX)); vec3 normal_view = normalize(transpose(inverse_modelview) * NORMAL); VERTEX += inverse_modelview * normal_view * outline_width; } void fragment(){ ALBEDO = vec3(0.004, 0.003, 0.006); }"
		outlines.shader = shader
	return outlines

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, material: Material, label: String = "Shape") -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = label
	n.mesh = shape
	n.material_override = material
	n.position = pos
	parent.add_child(n)
	return n

static func ball(parent: Node3D, pos: Vector3, size: Vector3, material: Material, label: String = "Pebble", outlined: bool = false) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 24
	s.rings = 12
	var n := mesh(parent, s, pos, material, label)
	n.scale = size
	if outlined:
		var hull := mesh(n, s, Vector3.ZERO, outline_mat(), "InkOutline")
		hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

static func box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, label: String = "Block") -> MeshInstance3D:
	var s := BoxMesh.new()
	s.size = size
	return mesh(parent, s, pos, material, label)

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material, top: float = -1.0, label: String = "Cylinder") -> MeshInstance3D:
	var s := CylinderMesh.new()
	s.bottom_radius = radius
	s.top_radius = radius if top < 0 else top
	s.height = height
	s.radial_segments = 20
	return mesh(parent, s, pos, material, label)

static func capsule(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material, label: String = "Capsule", outlined: bool = false) -> MeshInstance3D:
	var s := CapsuleMesh.new()
	s.radius = radius
	s.height = a.distance_to(b) + radius * 2.0
	s.radial_segments = 16
	s.rings = 5
	var n := mesh(parent, s, (a+b)*0.5, material, label)
	if a.distance_to(b) > 0.001:
		n.quaternion = Quaternion(Vector3.UP, (b-a).normalized())
	if outlined:
		mesh(n, s, Vector3.ZERO, outline_mat(), "InkOutline")
	return n

static func line(parent: Node3D, points: Array, radius: float, material: Material) -> void:
	for i in range(points.size()-1):
		capsule(parent, points[i], points[i+1], radius, material, "InkStroke")

static func solid_box(parent: Node3D, pos: Vector3, size: Vector3, label: String = "Collision") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = pos
	var shape := CollisionShape3D.new()
	var resource := BoxShape3D.new()
	resource.size = size
	shape.shape = resource
	body.add_child(shape)
	parent.add_child(body)
	return body

static func solid_cylinder(parent: Node3D, pos: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var resource := CylinderShape3D.new()
	resource.radius = radius
	resource.height = height
	shape.shape = resource
	body.add_child(shape)
	parent.add_child(body)

static func text3d(parent: Node3D, words: String, pos: Vector3, font_size: int = 48, color: Color = Color("554d40")) -> Label3D:
	var n := Label3D.new()
	n.text = words
	n.font_size = font_size
	n.pixel_size = 0.009
	n.modulate = color
	n.outline_size = 0
	n.position = pos
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC"])
	n.font = load("res://assets/fonts/NotoSansSC.ttf") if FileAccess.file_exists("res://assets/fonts/NotoSansSC.ttf") else f
	parent.add_child(n)
	return n
