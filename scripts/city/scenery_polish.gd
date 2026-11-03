extends RefCounted
const G=preload("res://scripts/geometry.gd")
const DB=preload("res://scripts/services/game_data.gd")
static func tree_at(world: Node3D,point: Vector3) -> Node3D:
	var nearest: Node3D;var distance_:=999.0
	for tree_ in world.get_children():
		if not str(tree_.name).begins_with("Tree"): continue
		var gap: float=tree_.position.distance_squared_to(point)
		if gap<distance_: nearest=tree_;distance_=gap
	return nearest
static func apply(world: Node3D) -> void:
	preload("res://scripts/city/terrain_materials.gd").apply(world)
	preload("res://scripts/city/environment_materials.gd").apply(world)
	if world.get_meta("scenery_polished",false):
		refresh_groundcover(world)
		return
	world.set_meta("scenery_polished",true)
	var trees: Array[Node3D]=[];var kept: Array[Node3D]=[]
	for node in world.get_children():
		if str(node.name).begins_with("Tree"): trees.append(node)
	# Give the four park fruit trees priority; leave generous walking gaps between crowns.
	trees.sort_custom(func(a,b): return priority(a.position)>priority(b.position))
	for tree_ in trees:
		var legal:=true
		for other in kept:
			if tree_.position.distance_to(other.position)<5.4: legal=false;break
		for source in DB.resources():
			if source.item!="orange" and tree_.position.distance_to(Vector3(source.x,0,source.z))<2.2: legal=false
		if not legal: world.remove_child(tree_);tree_.queue_free();continue
		kept.append(tree_)
		# Decorative fruit and its stalks are replaced with one harvestable cluster per selected tree.
		var crown: Node3D=tree_.get_node("Crown")
		var soft:=crown.get_node_or_null("SoftCrown")
		if is_instance_valid(soft): tree_.set_meta("fruit_crown_size",Vector2(soft.scale.x,soft.scale.y))
		for part in crown.get_children():
			if str(part.name).begins_with("Fruit") or (part is MeshInstance3D and (part.mesh is CapsuleMesh or part.mesh is SphereMesh)):
				crown.remove_child(part);part.queue_free()
	refresh_groundcover(world)
	var beach:=world.get_node_or_null("SouthBeach")
	if is_instance_valid(beach):
		for part in beach.get_children():
			if part is MeshInstance3D and part.material_override is StandardMaterial3D and part.material_override.albedo_color.is_equal_approx(Color("9ca873")): beach.remove_child(part);part.queue_free()
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=blade_mesh(true);mm.instance_count=4
		var grasses:=MultiMeshInstance3D.new();grasses.name="DuneGrasses";grasses.multimesh=mm;beach.add_child(grasses)
		var m:=ShaderMaterial.new();m.shader=load("res://assets/shaders/meadow_blades.gdshader");grasses.material_override=m;grasses.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in range(4):
			mm.set_instance_transform(i,Transform3D(Basis(Vector3.UP,i*1.3),[Vector3(-23,.04,33),Vector3(30,.04,32),Vector3(-30,.04,36),Vector3(34,.04,37)][i]))
			mm.set_instance_color(i,Color("9ca873"))
	polish_horizon(world)
static func priority(point: Vector3) -> int:
	for source in DB.resources():
		if source.item=="orange" and point.distance_to(Vector3(source.x,0,source.z))<.5: return 10
	return 0
static func blade_mesh(dune: bool=false) -> ArrayMesh:
	if not dune: return clover_mesh()
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(7 if dune else 5):
		var a:=blade*2.399;var h: float=(.47 if dune else .26)*(1.0+sin(blade*3.1)*.28)
		var width: float=.038 if dune else .045
		var right:=Vector3(cos(a),0,sin(a));var out:=Vector3(sin(a),0,-cos(a))
		for segment in range(4):
			for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
				var u: float=(segment+corner.y)/4.;var taper: float=pow(1.0-u,.7)
				var center: Vector3=out*(.025+u*u*h*.60)+Vector3(0,h*u,0)
				st.set_uv(Vector2(corner.x,u));st.set_normal((Vector3.UP*.75-out*.25).normalized())
				st.add_vertex(center+right*(corner.x*2-1)*width*taper)
	return st.commit()
static func polish_horizon(world: Node3D) -> void:
	var island:=world.get_node("Island")
	for child in island.get_children():
		if child is MeshInstance3D and Vector2(child.position.x,child.position.z).length()>80: island.remove_child(child);child.queue_free()
	var silhouettes:=Node3D.new();silhouettes.name="DistantIslets";island.add_child(silhouettes)
	for i in range(7):
		var a:=i*TAU/7+.28;var center:=Vector3(cos(a)*155,-1.5,sin(a)*164)
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segments:=28
		for ring in range(4):
			for k in range(segments):
				for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
					var r: int=ring+corner.y;var angle: float=(k+corner.x)*TAU/segments
					var radius: float=[1.0,.84,.55,.22,0.0][r]*(1+.08*sin(angle*3+i))
					var height_: float=[0.,.85,2.0,3.05,3.3][r]*(1+.17*sin(angle*3+i)+.10*cos(angle*5-i))
					st.set_color(Color("a1b7a1") if r<1 else Color("7aa995").lerp(Color("6c9b8b"),float(r)/4))
					st.add_vertex(center+Vector3(cos(angle)*radius*(14+i%3*3),height_,sin(angle)*radius*12))
		for tree_index in range(17):
			var angle: float=tree_index*2.399+i
			var radius: float=2.0+float(tree_index%4)*1.35
			var p:=center+Vector3(cos(angle)*radius,3.0-radius*.07,sin(angle)*radius*.7)
			append_crown(st,p,Vector3(.85,1.25,.85)*(1.0+sin(tree_index*4.1)*.20),Color("527f73").lerp(Color("6b9a83"),float(tree_index%4)/4))
		st.generate_normals()
		var m:=G.mat("ffffff").duplicate() as StandardMaterial3D;m.vertex_color_use_as_albedo=true;m.vertex_color_is_srgb=true
		var mesh:=G.mesh(silhouettes,st.commit(),Vector3.ZERO,m);mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func append_crown(st: SurfaceTool,p: Vector3,scale_: Vector3,color: Color) -> void:
	for y in range(6):
		for x in range(10):
			for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
				var theta: float=(y+corner.y)*PI/6;var phi: float=(x+corner.x)*TAU/10
				st.set_color(color*(.93+sin(theta)*.08))
				st.add_vertex(p+Vector3(sin(theta)*cos(phi),cos(theta),sin(theta)*sin(phi))*scale_)

static func clover_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for leaf in range(3):
		var a: float=leaf*TAU/3+.3
		var forward:=Vector3(cos(a),0,sin(a));var right:=Vector3(-sin(a),0,cos(a))
		var center:=forward*.07+Vector3(0,.065+leaf*.009,0)
		for i in range(10):
			for j in [-1,i,i+1]:
				var angle: float=j*TAU/10
				var point:=center+Vector3(0,.022,0) if j<0 else center+forward*cos(angle)*.105+right*sin(angle)*.080
				st.set_uv(Vector2(.5 if j<0 else float(i)/10.,.7 if j<0 else .4))
				st.set_normal(Vector3.UP if j<0 else (Vector3.UP+forward*cos(angle)*.18+right*sin(angle)*.18).normalized())
				st.add_vertex(point)
	return st.commit()
static func refresh_groundcover(world: Node3D) -> void:
	if world.get_meta("groundcover_revision",0)>=3: return
	world.set_meta("groundcover_revision",3)
	# Grass is carried by the terrain texture. Keep only intentional beach dune plants.
	for node in world.find_children("GrassTufts","MultiMeshInstance3D",true,false):
		node.get_parent().remove_child(node);node.free()
	var copies: Dictionary={}
	var texture_: Texture2D=load("res://assets/terrain/spring_lawn_v1.png")
	for node in world.find_children("*","GeometryInstance3D",true,false):
		var mat: Material=node.material_override
		if not mat is ShaderMaterial or mat.shader!=load("res://assets/shaders/meadow.gdshader"): continue
		var id: int=mat.get_instance_id()
		if not copies.has(id):
			copies[id]=mat.duplicate();copies[id].set_shader_parameter("lawn_texture",texture_)
		node.material_override=copies[id]
