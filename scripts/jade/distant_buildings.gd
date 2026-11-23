extends RefCounted
## Bake material IDs into UV2 so each distant house draws once. Near shells retain their individual parts.
const A=preload("res://scripts/jade/architecture.gd")
const G=preload("res://scripts/geometry.gd")
const SKINS={"plaster":1,"lime":1,"coffer":5,"wood_relief":2,"lacquer":2,"tiles":3,"masonry":4,"cloud_beam":5,"polychrome":5,"casement":6,"crane_panel":7,"stone_relief":8,"lotus_marble":8,"amber_tiles":11,"quay_oak":12}
static var distant: ShaderMaterial
static var shells: Dictionary={}
static func finish() -> ShaderMaterial:
	if distant==null:
		distant=ShaderMaterial.new();distant.shader=preload("res://assets/shaders/jade_distant_house.gdshader")
		for pair in [["plaster","lime"],["wood","lacquer"],["tile","tiles"],["masonry","masonry"],["frieze","cloud_beam"],["screen","casement"],["crane","crane_panel"],["relief","stone_relief"],["amber","amber_tiles"]]:
			distant.set_shader_parameter(pair[0],load("res://assets/jade/"+pair[1]+".png"))
		distant.set_shader_parameter("timber",preload("res://assets/terrain/coastal/quay_oak.png"))
	return distant
static func bake(room: Node3D,kind: String) -> void:
	if not shells.has(kind):
		var combined:=SurfaceTool.new();combined.begin(Mesh.PRIMITIVE_TRIANGLES)
		var inv:=room.global_transform.affine_inverse()
		for m: MeshInstance3D in room.find_children("*","MeshInstance3D",true,false):
			if room.get_node("Furnishing").is_ancestor_of(m):continue
			var transform_:=inv*m.global_transform
			for i in range(m.mesh.get_surface_count() if m.mesh!=null else 0):
				var mat:=m.get_active_material(i);var index:=0;var tint:=Color.WHITE
				if mat is StandardMaterial3D:
					tint=mat.albedo_color
					if mat.albedo_texture:index=SKINS.get(mat.albedo_texture.resource_path.get_file().get_basename(),0)
				if mat is ShaderMaterial:
					if mat.shader==preload("res://assets/shaders/jade_window.gdshader"):index=9
					if mat.shader==preload("res://assets/shaders/jade_silk_lantern.gdshader"):index=10;tint=Color("ad472b")
				var arrays:=m.mesh.surface_get_arrays(i)
				var pos: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var norms: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array()
				var tex: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
				var order: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
				var colours: PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null and mat is StandardMaterial3D and mat.vertex_color_use_as_albedo else PackedColorArray()
				var normal_matrix:=transform_.basis.inverse().transposed()
				for v in range(0,pos.size() if order.is_empty() else order.size(),3):
					var one:=v if order.is_empty() else order[v];var two:=v+1 if order.is_empty() else order[v+1];var three:=v+2 if order.is_empty() else order[v+2]
					if ((pos[two]-pos[one]).cross(pos[three]-pos[one])).length_squared()<.003:continue
					for k in [one,two,three]:
						combined.set_color(tint.srgb_to_linear()*(colours[k] if not colours.is_empty() else Color.WHITE));combined.set_uv2(Vector2(index,0));combined.set_uv(tex[k]*Vector2(mat.uv1_scale.x,mat.uv1_scale.y) if not tex.is_empty() and mat is StandardMaterial3D else (tex[k] if not tex.is_empty() else Vector2.ZERO))
						combined.set_normal((normal_matrix*norms[k]).normalized() if not norms.is_empty() else Vector3.UP);combined.add_vertex(transform_*pos[k])
		combined.index()
		# The far skyline can cover dozens of houses. Bake screen-space LODs once,
		# keeping the full mesh and the same material IDs at nearer transitions.
		var levels:=ImporterMesh.new()
		levels.add_surface(Mesh.PRIMITIVE_TRIANGLES,combined.commit_to_arrays(),[],{},finish())
		levels.generate_lods(55.,80.,[])
		shells[kind]=levels.get_mesh()
	var proxy:=G.mesh(room,shells[kind],Vector3.ZERO,null,"DistantShell");proxy.hide()
static func batch_fixtures(world: Node3D) -> void:
	var cells: Dictionary={}
	for fixture in world.get_children():
		if fixture.get_script() in [preload("res://scripts/jade/gallery_view.gd"),preload("res://scripts/jade/gate_view.gd")]:continue
		if not fixture.has_meta("furniture_kind") and not fixture.has_meta("grove") and not fixture.is_in_group("jade_bridge_spans"):continue
		for m: MeshInstance3D in fixture.find_children("*","MeshInstance3D",true,false):
			if m.mesh==null or m.material_override!=null or m.get_parent().get_meta("camera_canopy",false):continue
			var p:=m.global_position;var tile:=Vector2i(floori(p.x/30.),floori(p.z/30.));var key:=str(tile)+":"+str(m.mesh.get_instance_id())
			if not cells.has(key):cells[key]=[]
			cells[key].append(m)
	for rows: Array in cells.values():
		if rows.size()<2:continue
		var source: MeshInstance3D=rows[0]
		var base:=source.global_position;var chunk:=MultiMeshInstance3D.new();chunk.name="GroupedScenery";chunk.position=base
		chunk.visibility_range_begin=source.visibility_range_begin;chunk.visibility_range_end=source.visibility_range_end;chunk.cast_shadow=source.cast_shadow
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=source.mesh;mm.instance_count=rows.size()
		for i in range(rows.size()):
			var t: Transform3D=rows[i].global_transform;t.origin-=base;mm.set_instance_transform(i,t);rows[i].free()
		chunk.multimesh=mm;world.add_child(chunk)
