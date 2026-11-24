extends RefCounted
## Distant houses share their structural mesh and draw their own street displays.
const G=preload("res://scripts/geometry.gd")
static var shells: Dictionary={}
static var shadows: Dictionary={}
static var wall_occluders: Dictionary={}
static var distant: ShaderMaterial
static var layers: Array[Image]=[]
static var textures: Dictionary={}

# Bind each original albedo once for the whole district, including cloth, painted beams and shop goods.
static func layer(texture: Texture2D) -> int:
	if textures.has(texture):return textures[texture]
	var img:=texture.get_image()
	if img.is_compressed():img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGB8)
	img.resize(512,512,Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	img.compress(Image.COMPRESS_S3TC)
	layers.append(img)
	textures[texture]=layers.size()
	return layers.size()

static func finish_textures() -> void:
	var array:=Texture2DArray.new()
	array.create_from_images(layers)
	distant.set_shader_parameter("skins",array)
	layers.clear()
	textures.clear()

static func bake(room: Node3D) -> void:
	if distant==null:
		distant=ShaderMaterial.new()
		distant.shader=preload("res://assets/shaders/jade_distant_house.gdshader")
	var shell: Array[MeshInstance3D]=[]
	var display: Array[MeshInstance3D]=[]
	var front:=room.get_node("Front")
	var original_count: int=front.get_meta("shell_children")
	front.remove_meta("shell_children")
	var inside:=room.get_node("Furnishing")
	var stairs:=room.get_node_or_null("OutsideStair")
	for m: MeshInstance3D in room.find_children("*","MeshInstance3D",true,false):
		if inside.is_ancestor_of(m) or not m.mesh:continue
		if stairs and stairs.is_ancestor_of(m):
			# The flight follows the local street level while the house shell is shared.
			display.append(m)
			continue
		if front.is_ancestor_of(m):
			var part: Node=m
			while part.get_parent()!=front:part=part.get_parent()
			if part.get_index()>=original_count:
				display.append(m)
				continue
		shell.append(m)
	if not shells.has(room.shell_kind):shells[room.shell_kind]=combine(room,shell)
	var proxy:=G.mesh(room,shells[room.shell_kind],Vector3.ZERO,null,"DistantShell")
	var caster:=G.mesh(proxy,shadows[proxy.mesh],Vector3.ZERO,null,"BuildingShadow")
	caster.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	caster.lod_bias=.20
	proxy.lod_bias=.42
	proxy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not display.is_empty():
		var front_mesh:=combine(room,display)
		var frontage:=G.mesh(proxy,front_mesh,Vector3.ZERO,null,"Frontage")
		frontage.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		frontage.lod_bias=.60
		var trim:=G.mesh(frontage,shadows[front_mesh],Vector3.ZERO,null,"FrontageShadow")
		trim.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		trim.lod_bias=.25
	proxy.hide()
	if room.shell_kind not in ["theatre","pavilion"]:
		add_wall_occluder(room)

# The opaque panels form one shared occluder per house type. Leave all actual
# openings, upper galleries and a sliver around every exposed edge unobstructed.
static func add_wall_occluder(room: Node3D) -> void:
	if not wall_occluders.has(room.shell_kind):
		var vertices:=PackedVector3Array()
		var faces:=PackedInt32Array()
		for side: String in ["Front","Rear","West","East"]:
			var front_back: bool=side in ["Front","Rear"]
			var span: float=(room.floor_size.x if front_back else room.floor_size.y)*.5
			var depth: float=(room.floor_size.y if front_back else room.floor_size.x)*.5
			var door:=1.8 if side=="Front" or (room.shell_kind=="court" and side=="West") else 0.
			var section:=room.get_node(NodePath(side)) as Node3D
			var height: float=room.wall_height*.89-.10
			for end: float in [-1.,1.]:
				var x1:=minf(end*door,end*(span-.12))
				var x2:=maxf(end*door,end*(span-.12))
				var start:=vertices.size()
				for point in [Vector3(x1,.12,depth),Vector3(x2,.12,depth),Vector3(x2,height,depth),Vector3(x1,height,depth)]:
					vertices.append(section.transform*point)
				for i in [0,1,2,0,2,3]:faces.append(start+i)
		var shape:=ArrayOccluder3D.new()
		shape.set_arrays(vertices,faces)
		wall_occluders[room.shell_kind]=shape
	var instance:=OccluderInstance3D.new()
	instance.name="OpaqueWalls"
	instance.occluder=wall_occluders[room.shell_kind]
	room.add_child(instance)

static func combine(room: Node3D,parts: Array[MeshInstance3D]) -> ArrayMesh:
	var combined:=SurfaceTool.new()
	combined.begin(Mesh.PRIMITIVE_TRIANGLES)
	var depth:=SurfaceTool.new()
	depth.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inv:=room.global_transform.affine_inverse()
	for m in parts:
		var transform_:=inv*m.global_transform
		for i in m.mesh.get_surface_count():
			var mat:=m.get_active_material(i)
			var index:=0
			var roughness:=.86
			var tint:=Color.WHITE
			var uv_scale:=Vector2.ONE
			if mat is StandardMaterial3D:
				tint=mat.albedo_color
				roughness=mat.roughness
				uv_scale=Vector2(mat.uv1_scale.x,mat.uv1_scale.y)
				if mat.albedo_texture:index=layer(mat.albedo_texture)
			if mat is ShaderMaterial:
				if mat.shader==preload("res://assets/shaders/jade_window.gdshader"):index=-1
				if mat.shader==preload("res://assets/shaders/jade_silk_lantern.gdshader"):index=-2;tint=Color("ad472b")
			var arrays:=m.mesh.surface_get_arrays(i)
			var pos: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array()
			var tex: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
			var order: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			var colours: PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null and mat is StandardMaterial3D and mat.vertex_color_use_as_albedo else PackedColorArray()
			var normal_matrix:=transform_.basis.inverse().transposed()
			var linear_tint:=tint.srgb_to_linear()
			var layer_and_roughness:=Vector2(index,roughness)
			for v in range(0,pos.size() if order.is_empty() else order.size(),3):
				var one:=v if order.is_empty() else order[v]
				var two:=v+1 if order.is_empty() else order[v+1]
				var three:=v+2 if order.is_empty() else order[v+2]
				var edge_a:=transform_.basis*(pos[two]-pos[one])
				var edge_b:=transform_.basis*(pos[three]-pos[one])
				var area_squared:=edge_a.cross(edge_b).length_squared()
				if area_squared<.0001:continue
				if area_squared>=.0016:
					# The second sun cascade spans more than 190 m. Merge sub-texel
					# shadow vertices while keeping all coloured surface positions exact.
					var a: Vector3=(transform_*pos[one]).snappedf(.06)
					var b: Vector3=(transform_*pos[two]).snappedf(.06)
					var c: Vector3=(transform_*pos[three]).snappedf(.06)
					if a!=b and b!=c and a!=c:
						depth.add_vertex(a)
						depth.add_vertex(b)
						depth.add_vertex(c)
				for k in [one,two,three]:
					combined.set_color(linear_tint if colours.is_empty() else linear_tint*colours[k])
					combined.set_uv2(layer_and_roughness)
					combined.set_uv(Vector2.ZERO if tex.is_empty() else tex[k]*uv_scale)
					combined.set_normal((normal_matrix*norms[k]).normalized() if not norms.is_empty() else Vector3.UP)
					combined.add_vertex(transform_*pos[k])
	combined.index()
	# The far skyline can cover dozens of houses. Bake screen-space LODs once,
	# keeping the full mesh and the same material IDs at nearer transitions.
	var levels:=ImporterMesh.new()
	levels.add_surface(Mesh.PRIMITIVE_TRIANGLES,combined.commit_to_arrays(),[],{},distant)
	levels.generate_lods(55.,80.,[])
	var mesh:=levels.get_mesh()
	depth.index()
	var shadow:=ImporterMesh.new()
	shadow.add_surface(Mesh.PRIMITIVE_TRIANGLES,depth.commit_to_arrays())
	shadow.generate_lods(55.,80.,[])
	shadows[mesh]=shadow.get_mesh()
	return mesh

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
