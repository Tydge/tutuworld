extends Node3D
## Public fixtures never move. Each spatial cell submits one instanced mesh per part.
## Keep the glass and iron enclosing each point light out of its own shadow map.
const FIXTURE_LAYER := 1 << 8
const LANTERN := preload("res://scenes/coastal/lantern.res")
var iron: ShaderMaterial
var halo: ShaderMaterial
var pool: ShaderMaterial
var glow_batches: Array[GeometryInstance3D] = []

func build(lamps: Array[Node]) -> void:
	if lamps.is_empty():
		return
	iron = LANTERN.surface_get_material(0).duplicate()
	var glow: MeshInstance3D = lamps[0].get_node("LanternHalo")
	var patch: MeshInstance3D = lamps[0].get_node("WarmPool")
	halo = glow.material_override.duplicate()
	pool = patch.material_override.duplicate()
	var cells: Dictionary = {}
	for lamp in lamps:
		var point := to_local(lamp.global_position)
		var cell := Vector2i(floori(point.x/20.),floori(point.z/20.))
		if not cells.has(cell):
			cells[cell] = []
		cells[cell].append(lamp)
		fit_downlight(lamp)
		for part in ["LanternFrame","GlowGlass","LanternHalo","WarmPool"]:
			lamp.get_node(part).hide()
	for cell: Vector2i in cells:
		var anchor := Vector3(cell.x*20.+10.,0.,cell.y*20.+10.)
		batch(LANTERN,iron,cells[cell],anchor,"")
		glow_batches.append(batch(glow.mesh,halo,cells[cell],anchor,"LanternHalo"))
		glow_batches.append(batch(patch.mesh,pool,cells[cell],anchor,"WarmPool"))

# The metal hood lights the pavement below. The two casting park lights each need one shadow view.
func fit_downlight(lamp: Node3D) -> void:
	var old:=lamp.get_node("NightLight") as OmniLight3D
	var light:=SpotLight3D.new()
	light.name=old.name
	light.position=old.position
	light.rotation.x=-PI*.5
	light.light_color=old.light_color
	light.light_energy=old.light_energy
	light.spot_range=minf(old.omni_range,9.2)
	light.spot_attenuation=old.omni_attenuation
	light.spot_angle=70.5
	light.spot_angle_attenuation=.36
	light.visible=old.visible
	lamp.remove_child(old)
	old.free()
	lamp.add_child(light)

func batch(mesh: Mesh, material: Material, lamps: Array, anchor: Vector3, piece: String) -> MultiMeshInstance3D:
	var draws := MultiMesh.new()
	draws.transform_format = MultiMesh.TRANSFORM_3D
	draws.mesh = mesh
	draws.instance_count = lamps.size()
	var chunk := MultiMeshInstance3D.new()
	chunk.position = anchor
	if piece.is_empty():
		chunk.layers = FIXTURE_LAYER
	chunk.multimesh = draws
	chunk.material_override = material
	add_child(chunk)
	for i in range(lamps.size()):
		var model: Node3D = lamps[i] if piece.is_empty() else lamps[i].get_node(piece)
		draws.set_instance_transform(i,chunk.global_transform.affine_inverse()*model.global_transform)
	if not piece.is_empty():
		chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return chunk

func set_warmth(value: float) -> void:
	iron.set_shader_parameter("warmth",value)
	halo.set_shader_parameter("strength",.30*value)
	pool.set_shader_parameter("strength",.16*value)
	for part in glow_batches:
		part.visible = value>.001
