extends RefCounted
## Cloth rendering adapter. Geometry, source colors and game saves stay outside.
const Catalog = preload("res://scripts/appearance/material_catalog.gd")
const SURFACE = preload("res://assets/shaders/fabric.gdshader")
const DOUBLE_SIDED = preload("res://assets/shaders/fabric_double_sided.gdshader")
static var textures: Dictionary = {}

static func shader_for(cut: String) -> Shader:
	return DOUBLE_SIDED if cut in ["drape", "bow"] else SURFACE

static func texture(id: String) -> Texture2D:
	if not Catalog.is_pattern(id):
		return null
	if not textures.has(id):
		textures[id] = load(Catalog.definition(id).texture)
	return textures[id]

static func configure(fabric: ShaderMaterial, item: Dictionary, use: String = "clothing") -> void:
	var id := str(item.get("pattern", "solid"))
	if id not in Catalog.choices("fabric", "furniture" if use in ["furniture", "quilt"] else "clothing"):
		id = "solid"
	fabric.set_shader_parameter("dye", Color(item.get("color", "629184")))
	fabric.set_shader_parameter("accent", Color(item.get("accent", "f7e5bc")))
	fabric.set_shader_parameter("patterned", Catalog.is_pattern(id))
	fabric.set_shader_parameter("pattern_strength", item.get("pattern_strength", 0.78))
	fabric.set_shader_parameter("fabric_mask", texture(id))
	fabric.set_shader_parameter("pattern_scale", item.get("pattern_scale", Catalog.scale_for(id, use)))

static func material(item: Dictionary, cut: String = "", use: String = "clothing") -> ShaderMaterial:
	var fabric := ShaderMaterial.new()
	fabric.shader = shader_for(cut)
	fabric.set_shader_parameter("cut", {"vest": 1, "overalls": 2}.get(cut, 0))
	if cut == "bow":
		fabric.set_shader_parameter("roughness_value", 0.46)
		fabric.set_shader_parameter("specular_value", 0.42)
	configure(fabric, item, use)
	return fabric
