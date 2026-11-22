extends RefCounted
## Keep each authored albedo and silhouette when a builder recolours an individual material.
static var geometry: Dictionary={}
static func family(material: Material,kind: String) -> String:
	if material is ShaderMaterial:
		if material.shader==preload("res://assets/shaders/jade_silk_lantern.gdshader"):return "silk"
		if material.shader in [preload("res://assets/shaders/jade_foliage.gdshader"),preload("res://assets/shaders/ancient_foliage.gdshader")]:return "foliage"
		if material.shader==preload("res://assets/shaders/jade_pond.gdshader"):return "ceramic"
		if material.shader==preload("res://assets/shaders/jade_window.gdshader"):return "fabric"
		return "wood"
	if kind.begins_with("jade_tree_") and material is StandardMaterial3D:return "foliage"
	if material is StandardMaterial3D:
		var pigment: String=material.albedo_color.to_html(false)
		if kind=="jade_smith_rack" and pigment in ["647574","a1aeaa","6e7c79","8b9892","9d845d"]:return "iron"
		if kind=="jade_pastry_board" and pigment in ["cc9c63","a86d46","755038"]:return "pastry"
		if kind=="jade_steam_table":
			if pigment in ["efe1ba","cca780"]:return "pastry"
			if pigment in ["bb8958","6d5038","8d6843","b29a63","846440"]:return "woven"
		if kind=="jade_seed_bins" and pigment in ["bbaf7e","ad8456","d9bc70","aa8c67","c7a675"]:return "harvest"
		if kind in preload("res://scripts/jade/trades.gd").KINDS:return "wood"
		var tex: Texture2D=material.albedo_texture
		if tex:
			match tex.resource_path.get_file().get_basename():
				"masonry","lime","plaster","stone_relief","lotus_marble","soft_moss_rock_v1":return "stone"
				"swallows","brocade","egret":return "fabric"
				"tiles","amber_tiles":return "ceramic"
				"quay_oak","lacquer","polychrome","cloud_beam","coffer","wood_relief","casement","crane_panel":return "wood"
		if material.vertex_color_use_as_albedo:return "foliage"
		if material.emission_enabled:return "silk"
		var c: Color=material.albedo_color
		if c.g>c.r*1.09:return "ceramic"
		if c.r>c.g*1.18 and c.g>c.b*1.4 and c.r>.69:return "gilding"
		if c.r>.6 and absf(c.r-c.g)<.14:return "stone"
	return "wood"
static func tag(n: MeshInstance3D,m: Material,kind: String) -> void:
	if m==null:return
	n.material_override=m;n.set_meta("appearance_part",family(m,kind));n.set_meta("appearance_original",m)
static func prepare(module: Node3D,kind: String) -> void:
	for m: MeshInstance3D in module.find_children("*","MeshInstance3D",true,false):
		if m.get_meta("appearance_effect",false):continue
		if m.material_override!=null:tag(m,m.material_override,kind);continue
		if m.mesh==null:continue
		var source:=m.mesh
		if not geometry.has(source):
			var surfaces: Array=[]
			for i in range(source.get_surface_count()):
				var piece:=ArrayMesh.new();piece.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source.surface_get_arrays(i))
				surfaces.append(piece)
			geometry[source]=surfaces
		for i in range(source.get_surface_count()):
			var n:=MeshInstance3D.new();n.mesh=geometry[source][i];n.transform=m.transform
			n.visibility_range_begin=m.visibility_range_begin;n.visibility_range_end=m.visibility_range_end;n.cast_shadow=m.cast_shadow
			m.get_parent().add_child(n);tag(n,source.surface_get_material(i),kind)
		m.free()
