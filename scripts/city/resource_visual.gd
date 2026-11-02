extends RefCounted
const G=preload("res://scripts/geometry.gd")
static func fruit_cluster(tree_: Node3D) -> Node3D:
	var cluster:=Node3D.new();cluster.name="HarvestableOranges"
	tree_.get_node("Crown").add_child(cluster)
	var crown: Node3D=tree_.get_node("Crown")
	var shell: MeshInstance3D=crown.get_node_or_null("SoftCrown")
	var radius: float=tree_.get_meta("fruit_crown_size",Vector2(1.65,1.5)).x
	var height_: float=tree_.get_meta("fruit_crown_size",Vector2(1.65,1.5)).y
	for i in range(5):
		var angle:=.45+i*TAU/5
		var p:=Vector3(sin(angle)*radius*.91,-height_*.35,cos(angle)*radius*.91)
		G.ball(cluster,p,Vector3(.22,.24,.22),G.mat("ed9a35"),"Orange")
		G.capsule(cluster,p+Vector3(0,.20,0),p+Vector3(0,.32,0),.020,G.mat("8b7750"))
		var leaf:=G.ball(cluster,p+Vector3(.10,.25,0),Vector3(.13,.035,.065),G.mat("508b4b"));leaf.rotation.z=.35
	return cluster
static func make(item: String) -> Node3D:
	var visual:=Node3D.new()
	if item=="birch":
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
