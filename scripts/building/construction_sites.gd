extends RefCounted
## Public, temporary construction boundaries. Drafts and lease tokens stay private.
const Land=preload("res://scripts/building/parcels.gd")
const MESSAGE:="这块地皮正在施工，完成后再来参观吧。"
static func at(sites: Dictionary,point: Vector3,margin: float=.55) -> String:
	for id in sites:
		if id in Land.IDS and Land.bounds(id).grow(margin).has_point(Vector2(point.x,point.z)):return id
	return ""
static func sync(host: Node3D,sites: Dictionary) -> void:
	var root:=host.get_node_or_null("ConstructionSites")
	if root==null:root=Node3D.new();root.name="ConstructionSites";host.add_child(root)
	for child in root.get_children():
		if not sites.has(str(child.name)):root.remove_child(child);child.free()
	for id in sites:
		if id not in Land.IDS or root.has_node(NodePath(id)):continue
		var node:=Node3D.new();node.name=id;root.add_child(node)
		var rect:=Land.bounds(id);var center:=rect.get_center()
		for side in range(4):
			var horizontal:=side<2;var p:=Vector3(center.x,12,center.y)
			if horizontal:p.z=rect.position.y if side==0 else rect.end.y
			else:p.x=rect.position.x if side==2 else rect.end.x
			var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;body.position=p;node.add_child(body)
			var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(rect.size.x+.2,28,.12) if horizontal else Vector3(.12,28,rect.size.y+.2);shape.shape=box;body.add_child(shape)
			var rail:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(rect.size.x,.12,.10) if horizontal else Vector3(.10,.12,rect.size.y);rail.mesh=mesh;rail.position=p;rail.position.y=.8
			var material:=StandardMaterial3D.new();material.albedo_color=Color("e3bb68");rail.material_override=material;node.add_child(rail)
		var label:=preload("res://scripts/geometry.gd").text3d(node,"施工中 · 暂停进入",Land.sign_position(id)+Vector3(0,2.8,0),24,Color("d59237"));label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
