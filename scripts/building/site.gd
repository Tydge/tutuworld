extends RefCounted
const PAD:=Rect2(58,-10,42,42)
const PLOT:=Rect2(61,-7,36,34)
const CONNECTOR:=Rect2(40,9.835,22,6.33)
const CENTER:=Vector3(79,0,10)
static func contains(point: Vector3) -> bool:return PAD.has_point(Vector2(point.x,point.z)) or CONNECTOR.has_point(Vector2(point.x,point.z))
static func within(point: Vector2) -> bool:return point.x>=PLOT.position.x-.001 and point.x<=PLOT.end.x+.001 and point.y>=PLOT.position.y-.001 and point.y<=PLOT.end.y+.001
static func build(world: Node3D,grass: Material,paving: Material) -> void:
	var G=preload("res://scripts/geometry.gd")
	var root:=Node3D.new();root.name="EastBuildingSite";world.add_child(root);root.set_meta("module_type","building_site");root.set_meta("buildable_reference",true)
	G.box(root,Vector3(79,-.90,11),Vector3(42,1.4,42),G.mat("bba383"),"LandFoundation")
	G.box(root,Vector3(79,-.25,11),Vector3(42.4,.25,42.4),G.mat("dfcca3"),"SandEdge")
	G.box(root,Vector3(79,-.13,11),Vector3(42,.20,42),grass,"Lawn")
	var floor_:=G.solid_box(root,Vector3(79,-.55,11),Vector3(42,1.04,42),"GroundCollision");floor_.collision_layer=8;floor_.collision_mask=0
	var center:=CONNECTOR.get_center()
	G.box(root,Vector3(center.x,.005,center.y),Vector3(CONNECTOR.size.x,.084,CONNECTOR.size.y),paving,"PavedConnection")
	var bridge:=G.solid_box(root,Vector3(center.x,-.10,center.y),Vector3(CONNECTOR.size.x,.294,CONNECTOR.size.y),"ConnectionCollision");bridge.collision_layer=8;bridge.collision_mask=0
	for z in [-6.,26.]:
		for x in [62.,96.]:
			G.cylinder(root,Vector3(x,.30,z),.055,.65,G.mat("9d8967"))
	G.box(root,Vector3(60.5,1.3,17.5),Vector3(.15,2.6,.15),G.mat("aa8458"))
	G.box(root,Vector3(60.5,2.2,17.5),Vector3(3.5,.95,.12),G.mat("eee3be"))
	G.text3d(root,"东岸建造园",Vector3(60.5,2.32,17.58),27,Color("426e5c"))
	G.text3d(root,"F6 · 建造与布置",Vector3(60.5,1.98,17.58),18,Color("617d67"))
	world.set_meta("building_site_revision",1)
