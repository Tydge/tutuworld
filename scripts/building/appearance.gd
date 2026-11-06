extends RefCounted
## Explicit model-part definitions shared by generation, validation, UI and previews.
const Fabric=preload("res://scripts/appearance/fabric_material.gd")
const HOME=preload("res://assets/shaders/home_surface.gdshader")
const DATA="res://data/furniture_appearance.json"
const Catalog=preload("res://scripts/appearance/material_catalog.gd")
static var definitions: Dictionary={}
static var _presets: Dictionary={}
static func load_data() -> void:
	if not definitions.is_empty():return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	definitions=data.furniture;_presets=data.presets
static func presets() -> Dictionary:
	load_data();return _presets
static func parts(kind: String) -> Array:
	load_data()
	return definitions.get(kind,[])
static func part(kind: String,id: String) -> Dictionary:
	for row in parts(kind):
		if row.id==id:return row
	return {}
static func allowed(definition: Dictionary) -> Array:
	return Catalog.choices(str(definition.get("family","")),"furniture",definition.get("materials",[]))
static func validate(kind: String,value: Variant) -> Dictionary:
	if not value is Dictionary or value.size()>parts(kind).size():return {"ok":false,"message":"家具部位外观格式不正确。"}
	var clean: Dictionary={}
	for id in value:
		var definition:=part(kind,str(id));var item: Variant=value[id]
		if definition.is_empty() or not item is Dictionary:return {"ok":false,"message":"请选择这件家具已有的部位。"}
		var material:=str(item.get("material","original"))
		if not material in allowed(definition):return {"ok":false,"message":"这个部位不支持所选材质。"}
		var entry:={"material":material}
		if item.has("accent") and definition.family!="fabric":return {"ok":false,"message":"只有布料花纹支持独立的花纹颜色。"}
		for channel in ["color","accent"]:
			if not item.has(channel):continue
			var color_:=str(item[channel])
			if color_.length()!=6 or not Color.html_is_valid(color_):return {"ok":false,"message":"请选择有效的部位颜色。"}
			entry[channel]=color_.to_lower()
		clean[id]=entry
	return {"ok":true,"appearance":clean}
static func source_color(material: Material) -> String:
	if material is StandardMaterial3D:return material.albedo_color.to_html(false)
	if material is ShaderMaterial:
		for key in ["tint","dye","soil_color"]:
			var value: Variant=material.get_shader_parameter(key)
			if value is Color:return value.to_html(false)
	return ""
static func prepare(module: Node3D,kind: String,builder: RefCounted) -> void:
	if kind=="flowerbed":split_flowers(module)
	var groups: Dictionary={};var unmatched: Array=[]
	for mesh in module.find_children("*","MeshInstance3D",true,false):
		var material: Material=mesh.material_override;var color_:=source_color(material);var slot:=str(mesh.get_meta("appearance_part",""));var position_: Vector3=module.to_local(mesh.global_position)
		if not protected(mesh):
			# Explicit authoring tags take precedence. Color/name selectors keep old models compatible.
			if slot!="" and part(kind,slot).is_empty():unmatched.append([str(mesh.name),"unknown part: "+slot]);slot=""
			for row in ([] if slot!="" else parts(kind)):
				if row.has("names") and str(mesh.name) in row.names:slot=row.id;break
				if row.has("names"):continue
				if color_ in row.colors and position_.y>=float(row.get("min_y",-INF)) and position_.y<=float(row.get("max_y",INF)):slot=row.id;break
			if slot=="":unmatched.append([str(mesh.name),color_])
		if protected(mesh):slot=""
		var key:=slot if slot!="" else "effects"
		if not groups.has(key):
			var group:=Node3D.new();group.name="Part_"+key;module.add_child(group);groups[key]=group
			if slot!="":group.set_meta("appearance_part",slot)
		var transform_: Transform3D=mesh.global_transform;mesh.reparent(groups[key]);mesh.global_transform=transform_
	module.set_meta("appearance_unmatched",unmatched)
	for key in groups:
		builder.bake_section(groups[key])
		for mesh in groups[key].find_children("*","MeshInstance3D",true,false):
			mesh.set_meta("appearance_part",key);mesh.set_meta("appearance_original",mesh.material_override)
static func protected(mesh: MeshInstance3D) -> bool:
	if str(mesh.name)=="Bulb":return true
	var material: Material=mesh.material_override
	if material is ShaderMaterial:
		return material.shader.resource_path.get_file() in ["contact_shadow.gdshader","fountain_water.gdshader","hearth_fire.gdshader","hearth_embers.gdshader","planar_mirror.gdshader"]
	return false
static func apply(module: Node3D,row: Dictionary) -> void:
	var overrides: Dictionary=row.get("appearance",{})
	for mesh in module.find_children("*","MeshInstance3D",true,false):
		var id: String=mesh.get_meta("appearance_part","")
		if not overrides.has(id):continue
		var definition:=part(row.kind,id);var entry: Dictionary=overrides[id];var original: Material=mesh.get_meta("appearance_original",mesh.material_override);var material: Material=original.duplicate();var chosen: String=entry.get("material","original")
		var color_:=Color(entry.get("color",definition.colors[0]))
		if chosen!="original":
			if definition.family=="fabric":
				var cloth:={"color":color_.to_html(false),"accent":entry.get("accent","f2e5cf"),"pattern":chosen}
				if original is ShaderMaterial and original.shader==preload("res://assets/shaders/sleep_quilt.gdshader"):
					# Keep the quilt's animated geometry; change only its shared cloth uniforms.
					Fabric.configure(material,cloth,"quilt")
				else:material=Fabric.material(cloth,"","furniture")
			else:
				material=ShaderMaterial.new();material.shader=HOME;material.set_shader_parameter("pattern",Catalog.definition(chosen).get("surface_pattern",0));material.set_shader_parameter("roughness_value",.45 if definition.family=="metal" else .9)
			set_color(material,color_,definition,false)
		elif entry.has("color"):set_color(material,color_,definition,true)
		if entry.has("accent") and patterned(material):
			material.set_shader_parameter("accent",Color(entry.accent));material.set_shader_parameter("pattern_strength",1.)
		mesh.material_override=material
static func patterned(material: Material) -> bool:
	return material is ShaderMaterial and material.get_shader_parameter("patterned")==true
static func channels(module: Node3D,slot: String,chosen: String) -> Dictionary:
	var result:={"enabled":Catalog.is_pattern(chosen),"accent":Color("f2e5cf"),"label":Catalog.definition(chosen).get("accent_label","花纹色")}
	if chosen!="original":return result
	for mesh in module.find_children("*","MeshInstance3D",true,false):
		if mesh.get_meta("appearance_part","")!=slot:continue
		var material: Material=mesh.get_meta("appearance_original",mesh.material_override)
		if patterned(material):
			result.enabled=true;result.accent=material.get_shader_parameter("accent");return result
	return result
static func set_color(material: Material,color_: Color,definition: Dictionary,preserve: bool) -> void:
	if material is StandardMaterial3D:
		material.albedo_color=color_;return
	if not material is ShaderMaterial:return
	if material.shader==HOME:
		if preserve and material.get_shader_parameter("vertex_tint"):
			var old:=Color(definition.colors[0]).srgb_to_linear();var target:=color_.srgb_to_linear();material.set_shader_parameter("tint",Color(target.r/maxf(.001,old.r),target.g/maxf(.001,old.g),target.b/maxf(.001,old.b)).linear_to_srgb())
		else:material.set_shader_parameter("tint",color_);material.set_shader_parameter("vertex_tint",false)
	elif material.shader==preload("res://assets/shaders/farm_soil.gdshader"):material.set_shader_parameter("soil_color",color_)
	elif material.shader==preload("res://assets/shaders/forest_blossoms.gdshader"):material.set_shader_parameter("dye_multiplier",color_)
	else:material.set_shader_parameter("dye",color_)
static func preset(kind: String,id: String) -> Dictionary:
	var result: Dictionary={};var palette: Dictionary=presets()[id]
	for row in parts(kind):result[row.id]={"material":"original","color":palette["neutral" if row.get("neutral",false) else row.family]}
	return result
static func split_flowers(module: Node3D) -> void:
	for mesh in module.find_children("MixedFlowersAndLeaves","MeshInstance3D",true,false):
		var tool:=SurfaceTool.new();tool.create_from(mesh.mesh,0);tool.deindex();var source: Array=tool.commit().surface_get_arrays(0);var groups:={"PlantLeaves":[],"PlantBlooms":[]}
		for i in range(0,source[Mesh.ARRAY_VERTEX].size(),3):
			var c: Color=source[Mesh.ARRAY_COLOR][i];var key: String="PlantLeaves" if c.g>c.r*1.1 and c.g>c.b*1.1 else "PlantBlooms"
			for index_ in range(i,i+3):groups[key].append(index_)
		for key in groups:
			var output:=SurfaceTool.new();output.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in groups[key]:
				output.set_normal(source[Mesh.ARRAY_NORMAL][i]);output.set_color(source[Mesh.ARRAY_COLOR][i]);output.set_uv(source[Mesh.ARRAY_TEX_UV][i]);output.add_vertex(source[Mesh.ARRAY_VERTEX][i])
			var part:=MeshInstance3D.new();part.name=key;part.mesh=output.commit();part.material_override=mesh.material_override;part.transform=mesh.transform;part.cast_shadow=mesh.cast_shadow;mesh.get_parent().add_child(part)
		mesh.get_parent().remove_child(mesh);mesh.free()

static func restore(module: Node3D) -> void:
	for mesh in module.find_children("*","MeshInstance3D",true,false):
		if mesh.has_meta("appearance_original"):mesh.material_override=mesh.get_meta("appearance_original")
