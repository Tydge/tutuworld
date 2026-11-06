extends RefCounted
const G=preload("res://scripts/geometry.gd")
const Land=preload("res://scripts/building/parcels.gd")
const PAD:=Rect2(58,-20,104,60)
# Legacy layout/import envelope. Gameplay editing uses a checked Land parcel.
const PLOT:=Rect2(61,-7,98,34)
const CONNECTOR:=Rect2(40,9.835,22,6.33)
const CENTER:=Vector3(79,0,10)
const REVISION:=5
static func contains(point: Vector3) -> bool:return PAD.has_point(Vector2(point.x,point.z)) or CONNECTOR.has_point(Vector2(point.x,point.z))
static func within(point: Vector2) -> bool:
	if Land.includes(PLOT,point):return true
	for id in Land.IDS:
		if Land.includes(Land.bounds(id),point):return true
	return false
static func outline(rect: Rect2,radius: float,height_: float) -> PackedVector3Array:
	var points:=PackedVector3Array()
	var centers: Array[Vector2]=[rect.position+Vector2(radius,radius),Vector2(rect.end.x-radius,rect.position.y+radius),rect.end-Vector2.ONE*radius,Vector2(rect.position.x+radius,rect.end.y-radius)]
	for corner in range(4):
		for step in range(13):
			var a: float=PI+(corner+step/12.)*PI*.5
			points.append(Vector3(centers[corner].x+cos(a)*radius,height_,centers[corner].y+sin(a)*radius))
	return points
static func triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	for p in [a,c,b]:st.set_uv(Vector2(p.x,p.z));st.add_vertex(p)
static func band(inner: PackedVector3Array,outer: PackedVector3Array) -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(inner.size()):
		var j: int=(i+1)%inner.size()
		triangle(st,inner[i],outer[j],outer[i]);triangle(st,inner[i],inner[j],outer[j])
	st.generate_normals();return st.commit()
static func cap(points: PackedVector3Array) -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);var center:=Vector3(PAD.get_center().x,points[0].y,PAD.get_center().y)
	for i in range(points.size()):triangle(st,center,points[(i+1)%points.size()],points[i])
	st.generate_normals();return st.commit()
static func ground(root: Node3D,mesh: ArrayMesh,material: Material,name_: String) -> void:
	var surface:=G.mesh(root,mesh,Vector3.ZERO,material,name_);surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var body:=StaticBody3D.new();body.name=name_+"Collision";body.collision_layer=8;body.collision_mask=0;root.add_child(body)
	var collision:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.set_faces(mesh.get_faces());collision.shape=shape;body.add_child(collision)
static func bench(root: Node3D,p: Vector3,turn: float) -> void:
	var node:=Node3D.new();node.name="PublicBench";node.position=p;node.rotation.y=turn;root.add_child(node)
	var wood:=G.mat("b69367");var metal:=G.mat("527365")
	for z in [-.25,0.,.25]:G.box(node,Vector3(0,.56,z),Vector3(2.3,.10,.21),wood)
	for y in [.92,1.18]:G.box(node,Vector3(0,y,-.37),Vector3(2.3,.17,.08),wood)
	for x in [-.85,.85]:
		G.box(node,Vector3(x,.29,0),Vector3(.09,.58,.68),metal);G.box(node,Vector3(x,.85,-.36),Vector3(.09,.72,.09),metal)
	var seat:=Marker3D.new();seat.name="SeatAnchor";seat.position=Vector3(0,.62,.05);node.add_child(seat)
	var exit:=Marker3D.new();exit.name="ExitAnchor";exit.position=Vector3(0,.04,1.45);node.add_child(exit)
	preload("res://scripts/city/prop_collisions.gd").box(node,"BenchCollision",Vector3(0,.55,-.05),Vector3(2.3,1.1,.85))
static func build(world: Node3D,grass: Material,paving: Material) -> void:
	var root:=Node3D.new();root.name="EastBuildingSite";world.add_child(root);root.set_meta("module_type","building_site");root.set_meta("buildable_reference",true)
	var lawn:=outline(PAD.grow(-4),6.,-.025);var dune:=outline(PAD,10.,-.38);var sea:=outline(PAD.grow(3),13.,-1.65)
	var sand:=ShaderMaterial.new();sand.shader=preload("res://assets/shaders/beach_sand.gdshader");sand.set_shader_parameter("sand_texture",preload("res://assets/terrain/fine_beach_sand_v1.png"))
	ground(root,cap(lawn),grass,"Lawn");ground(root,band(lawn,dune),sand,"WideSandBeach");ground(root,band(dune,sea),sand,"SlopingShore")
	var commons:=preload("res://scripts/building/garden_landscape.gd").build(root,paving)
	preload("res://scripts/building/garden_bridge.gd").build(root,CONNECTOR)
	for index in range(Land.IDS.size()):
		var id: String=Land.IDS[index];var rect:=Land.bounds(id);var plot:=Node3D.new();plot.name=id;root.add_child(plot);plot.set_meta("parcel_id",id)
		var sign:=Node3D.new();sign.name="Sign";sign.position=Land.sign_position(id);plot.add_child(sign)
		if index>=2:sign.rotation.y=PI
		for side in [-1,1]:G.box(sign,Vector3(side*1.05,.64,0),Vector3(.12,1.28,.12),G.mat("80684e"),"OakPost")
		G.box(sign,Vector3(0,1.42,0),Vector3(3.30,1.02,.18),G.mat("826d51"),"WoodFrame")
		for side in [-1,1]:
			G.box(sign,Vector3(0,1.42,side*.105),Vector3(3.13,.85,.025),G.mat("e9dfc5"),"InsetPanel")
			var title:=G.text3d(sign,Land.title(id),Vector3(0,1.60,side*.127),26,Color("355744"));title.name="ParcelName"+("Back" if side<0 else "");title.rotation.y=PI if side<0 else 0.;title.double_sided=false
			var label:=G.text3d(sign,"24×20米 · 100贝壳币",Vector3(0,1.22,side*.127),18,Color("59664e"));label.name="OwnershipLabel"+("Back" if side<0 else "");label.rotation.y=title.rotation.y;label.double_sided=false
		preload("res://scripts/city/prop_collisions.gd").box(sign,"SignCollision",Vector3(0,1.3,0),Vector3(3.3,1.2,.20))
	for row in [[Vector3(104.4,0,10),PI*.5],[Vector3(115.6,0,10),-PI*.5],[Vector3(70,0,20),PI*.5],[Vector3(150,0,16),-PI*.5]]:bench(commons,row[0],row[1])
	# A fixed, double-sided welcome board; no world-space text rotates separately.
	var welcome:=Node3D.new();welcome.name="WelcomeBoard";welcome.position=Vector3(65,0,17);root.add_child(welcome)
	G.box(welcome,Vector3(0,1.75,0),Vector3(3.8,1.2,.16),G.mat("ded2b4"),"Board")
	for side in [-1,1]:
		var title:=G.text3d(welcome,"海风花庭",Vector3(0,1.96,side*.09),29,Color("426e5c"));title.rotation.y=PI if side<0 else 0.;title.double_sided=false
		var hint:=G.text3d(welcome,"立板旁按E · 购买地皮",Vector3(0,1.54,side*.09),18,Color("6b8066"));hint.rotation.y=title.rotation.y;hint.double_sided=false
	world.set_meta("building_site_revision",REVISION)
static func ensure(world: Node3D) -> void:
	if int(world.get_meta("building_site_revision",0))>=REVISION:return
	var old:=world.get_node_or_null("EastBuildingSite")
	if not is_instance_valid(old):return
	var grass: Material=old.get_node("Lawn").material_override
	var old_path: Node=old.get_node_or_null("PavedConnection")
	if old_path==null:old_path=old.get_node_or_null("PublicPromenade")
	if old_path==null:old_path=old.get_node("GardenCommons/WindingGardenWalk")
	var paving: Material=old_path.material_override
	world.remove_child(old);old.free();build(world,grass,paving)
static func update_ownership(world: Node3D,state: Dictionary) -> void:
	var root:=world.get_node_or_null("EastBuildingSite")
	if root==null:return
	var key:=str(state.get("land_parcels",{}))+str(state.get("player_id",""))
	if root.get_meta("ownership_key","")==key:return
	root.set_meta("ownership_key",key)
	for id in Land.IDS:
		var plot:=root.get_node_or_null(id)
		if plot==null:continue
		var owner:=Land.owner(state,id);var mine:=Land.owns(state,id)
		for label in plot.find_children("OwnershipLabel*","Label3D",true,false):label.text="已购入 · 靠近后建造" if mine else ("24 × 20米 · 100贝壳币" if owner=="" else "已有主人")
