extends RefCounted
## Precompute screen-space mesh levels for the moving crowd while building the city.
## Each limb retains its pivot, material and full-resolution surface at close range.
const Animals=preload("res://scripts/characters/animal_catalog.gd")
const G=preload("res://scripts/geometry.gd")

static func levels(source: Mesh) -> ArrayMesh:
	var lod:=ImporterMesh.new()
	for i in source.get_surface_count():
		var surface:=SurfaceTool.new()
		surface.create_from(source,i)
		surface.index()
		lod.add_surface(Mesh.PRIMITIVE_TRIANGLES,surface.commit_to_arrays(),[],{},source.surface_get_material(i))
	lod.generate_lods(55.,80.,[])
	return lod.get_mesh()

static func bake(world: Node3D) -> void:
	var models: Dictionary={}
	for path in Animals.SCENES.values():
		var actor: Node3D=load(path).instantiate()
		var brows:=actor.get_node_or_null("Visual/Head/FixedEyebrows")
		if brows:
			var ink:=SurfaceTool.new()
			ink.begin(Mesh.PRIMITIVE_TRIANGLES)
			for part: MeshInstance3D in brows.get_children():
				G.append_indexed(ink,part.mesh,0,part.transform)
			models["brows"]=levels(ink.commit())
		for part: MeshInstance3D in actor.get_node("Visual").find_children("*","MeshInstance3D",true,false):
			var mesh:=part.mesh
			if mesh==null or (brows and brows.is_ancestor_of(part)):continue
			if mesh.resource_path.is_empty() or models.has(mesh.resource_path):continue
			if mesh.get_faces().size()>=300:models[mesh.resource_path]=levels(mesh)
		actor.free()
	world.set_meta("resident_meshes",models)

static func apply(actor: CharacterBody3D,models: Dictionary) -> void:
	for part: MeshInstance3D in actor.get_node("Visual").find_children("*","MeshInstance3D",true,false):
		if part.mesh and models.has(part.mesh.resource_path):part.mesh=models[part.mesh.resource_path]
	var brows:=actor.get_node_or_null("Visual/Head/FixedEyebrows")
	if brows and models.has("brows"):
		var brush:=brows.get_child(0) as MeshInstance3D
		var ink:=brush.material_override
		for stroke in brows.get_children():stroke.free()
		var joined:=G.mesh(brows,models["brows"],Vector3.ZERO,ink,"Ink")
		joined.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
