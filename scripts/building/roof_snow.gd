extends RefCounted
## Snow is a roof finish, so cutaways, shadows and batching share the roof lifecycle.
const SURFACE=preload("res://assets/shaders/home_surface.gdshader")
const TEXTURE=preload("res://assets/terrain/winter/powder_snow_v1.png")
static func apply(section: Node3D,enabled: bool) -> void:
	section.set_meta("snow",enabled)
	if not enabled:return
	for part in section.find_children("*","MeshInstance3D",true,false):
		var source: Material=part.material_override
		if source is ShaderMaterial and source.shader==SURFACE:
			var coat: ShaderMaterial=source.duplicate()
			coat.set_shader_parameter("roof_snow",true);coat.set_shader_parameter("roof_snow_texture",TEXTURE)
			part.material_override=coat
