extends RefCounted
const Parts = preload("res://scripts/appearance/model_parts.gd")
const G = preload("res://scripts/geometry.gd")
const HATS = preload("res://assets/tailoring/millinery.glb")
const CUTS = {
	"bunny": preload("res://assets/tailoring/bunny.glb"),
	"cat_teacher": preload("res://assets/tailoring/cat_teacher.glb"),
	"panda": preload("res://assets/tailoring/panda.glb")
}

static func fit(actor: Node3D, root: Node3D, item: Dictionary, cloth: ShaderMaterial) -> void:
	var rig: Resource = actor.rig_profile
	var slot := str(item.slot)
	var style := str(item.style)
	var pieces := Parts.from_scene(HATS if slot == "head" else CUTS[rig.species_id])
	var accent := str(item.accent)
	var main := Color(item.color)
	var materials := {
		"Cloth": cloth,
		"Chain": cloth,
		"Ribbon": G.mat(accent, .54),
		"Binding": G.mat(Color(accent).lerp(main,.38).lightened(.12).to_html(false), .64),
		"Collar": G.mat("efe3c3" if style=="day_dress" else "eee9d9", .82),
		"Brass": G.mat("cea459", .34),
		"Turquoise": G.mat("5fa695", .30),
		"Pearl": G.mat("f7ebce", .35)
	}
	if style == "gold_chain":
		cloth.set_shader_parameter("metallic_value", .64)
		cloth.set_shader_parameter("roughness_value", .26)
		cloth.set_shader_parameter("specular_value", .72)
	if style == "silk_bowtie":
		cloth.shader = preload("res://assets/shaders/bowtie_satin.gdshader")
		preload("res://scripts/appearance/fabric_material.gd").configure(cloth,item)
		materials["SilkBack"] = G.mat(main.darkened(.19).to_html(false), .46)
	var anchor := actor.get_node("Visual/Head" if slot == "head" else "Visual")
	anchor.add_child(root)
	match slot:
		"head":
			root.scale = rig.headwear_scale
			root.rotation.x = .22
			root.position = rig.hat_offset + Vector3(-rig.hat_offset.x, .035, .235)
		"neck":
			root.position = rig.neck_center
		"body":
			root.position = rig.body_center
			for side in ["Left", "Right"]:
				var sleeve := place(pieces[style+"_"+side.to_lower()], materials)
				sleeve.name = "Wardrobe_body_sleeve"
				actor.get_node("Visual/"+side+"Arm").add_child(sleeve)
	var main_piece := place(pieces[style], materials)
	if style == "day_dress":
		main_piece.set_script(preload("res://scripts/appearance/skirt_motion.gd"))
		main_piece.set("actor", actor)
	root.add_child(main_piece)

static func place(mesh: Mesh, materials: Dictionary) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	for surface in mesh.get_surface_count():
		var role := mesh.surface_get_material(surface).resource_name
		piece.set_surface_override_material(surface, materials[role])
	return piece
