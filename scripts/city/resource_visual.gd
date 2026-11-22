extends RefCounted
const G=preload("res://scripts/geometry.gd")
static func fruit_cluster(tree_: Node3D) -> Node3D:
	var cluster:=Node3D.new();cluster.name="HarvestableOranges"
	tree_.get_node("Crown").add_child(cluster)
	var crown: Node3D=tree_.get_node("Crown")
	var size_: Vector2=tree_.get_meta("fruit_crown_size",Vector2(1.65,1.5))
	var fruit:=MultiMesh.new()
	fruit.transform_format=MultiMesh.TRANSFORM_3D
	fruit.mesh=preload("res://scenes/coastal/orange.res")
	fruit.instance_count=preload("res://scripts/city/coastal/fruit_spurs.gd").COUNT
	for i in range(fruit.instance_count):
		var angle:=.45+i*TAU/5
		var point:=Vector3(sin(angle)*size_.x*.81,-size_.y*.30,cos(angle)*size_.x*.81)
		var rotation_:=Basis(Vector3.UP,angle)
		var spur:=crown.get_node_or_null("FruitSpur%d"%i)
		if spur!=null:
			rotation_=rotation_.scaled_local(Vector3.ONE*float([.92,1.06,.98,.88,1.03][i]))
			point=spur.position-rotation_*preload("res://scripts/city/coastal/fruit_spurs.gd").STEM_END
		fruit.set_instance_transform(i,Transform3D(rotation_,point))
	var fruit_mesh:=MultiMeshInstance3D.new()
	fruit_mesh.multimesh=fruit
	var canopy: MeshInstance3D=tree_.get_node_or_null("OrchardTree/WoodAndLeaves")
	if canopy!=null:fruit_mesh.material_override=canopy.material_override
	cluster.add_child(fruit_mesh)
	return cluster
static func make(item: String) -> Node3D:
	var visual:=Node3D.new()
	if item=="cedar":
		for j in range(3):
			var p:=Vector3(0,.22+j*.11,(j-1)*.31)
			var wood:=G.cylinder(visual,p,.23,1.86,G.mat("775039"),.20);wood.rotation.z=PI/2
			for side in [-1,1]:
				var end:=G.cylinder(visual,p+Vector3(side*.94,0,0),.19,.012,G.mat("c7975d"));end.rotation.z=PI/2
				for k in [1,2]:
					var ring:=TorusMesh.new();ring.inner_radius=.052*k;ring.outer_radius=.052*k+.008
					G.mesh(visual,ring,p+Vector3(side*.952,0,0),G.mat("855635")).rotation.z=PI/2
	elif item in ["nephrite","silver_ore"]:
		for j in range(7):
			var p:=Vector3(cos(j*2.4)*.35,.20,sin(j*2.4)*.32)
			var stone:=SphereMesh.new();stone.radial_segments=7;stone.rings=3
			G.mesh(visual,stone,p,G.mat("718475" if item=="nephrite" else "586368")).scale=Vector3(.8,.72,.74)
			var gem:=G.cylinder(visual,p+Vector3(.07,.27,0),.16,.24,G.mat("7fb398" if item=="nephrite" else "d1d5d0",.28),.065);gem.rotation.z=.45*sin(j)
	elif item=="birch":
		var bark:=ShaderMaterial.new();bark.shader=load("res://assets/shaders/birch_bark.gdshader")
		var rings:=ShaderMaterial.new();rings.shader=load("res://assets/shaders/log_rings.gdshader")
		var log:=G.cylinder(visual,Vector3(0,.31,0),.32,2.1,bark,.28);log.rotation.z=PI*.5
		for side in [-1,1]:
			var end:=G.cylinder(visual,Vector3(side*1.06,.31,0),.275,.025,rings);end.rotation.z=PI*.5
		G.capsule(visual,Vector3(-.2,.47,0),Vector3(-.3,.73,.31),.065,bark)
	elif item=="branch":
		for i in range(3):
			G.capsule(visual,Vector3(-.45,.10,-.15+i*.12),Vector3(.45,.10+i*.015,.10+i*.12),.045,G.mat("98704b"))
			G.capsule(visual,Vector3(.07,.12,.04),Vector3(.16,.16,.32),.025,G.mat("98704b"))
	else:
		for i in range(4):
			var stone:=G.ball(visual,Vector3(sin(i*2)*.25,.25+i*.05,cos(i*2)*.25),Vector3(.45,.33,.38),G.mat("bec5b5" if item=="limestone" else ("c6a77b" if item=="sandstone" else "7e8987")))
			if item in ["copper","iron"]:
				G.ball(visual,stone.position+Vector3(.16,.19,.14),Vector3(.15,.10,.11),G.mat("c48a65" if item=="copper" else "abb7bd"))
				G.ball(visual,stone.position+Vector3(-.12,.17,.20),Vector3(.07,.09,.06),G.mat("80a8a0"))
	return visual
