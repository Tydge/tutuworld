extends RefCounted
## Blueprint -> independently replaceable floor, wall, opening, roof and furniture modules.
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
const Fabric=preload("res://scripts/city/fabric_library.gd")
var blueprint: Dictionary
var root: Node3D
var materials: Dictionary={}
var rounded_cache: Dictionary={}
var batch_materials: Dictionary={}
var floor_y:=.18
var height:=4.4
var thickness:=.24
static func build(world: Node3D,definition: Dictionary) -> Node3D:
	var builder=load("res://scripts/city/home_builder.gd").new()
	return pack_module(world,builder.construct(world,definition),"res://scenes/seabreeze_home.scn")
static func pack_module(world: Node3D,house: Node3D,filename: String) -> Node3D:
	var placement:=house.position
	house.position=Vector3.ZERO;own_modules(house,house)
	var scene:=PackedScene.new()
	if scene.pack(house)!=OK: push_error("Could not pack building modules");return house
	ResourceSaver.save(scene,filename,ResourceSaver.FLAG_COMPRESS)
	world.remove_child(house);house.free()
	var packed: PackedScene=ResourceLoader.load(filename,"PackedScene",ResourceLoader.CACHE_MODE_REPLACE)
	var instance: Node3D=packed.instantiate();instance.assembling=true;instance.position=placement
	world.add_child(instance);return instance
static func own_modules(node: Node,owner_: Node) -> void:
	for child in node.get_children(): child.owner=owner_;own_modules(child,owner_)
func group(parent: Node3D,id: String,p:=Vector3.ZERO) -> Node3D:
	var n:=Node3D.new();n.name=id;n.position=p;parent.add_child(n);return n
func material(color: String,pattern: int=0) -> Material:
	var key:=color+str(pattern)
	if not materials.has(key):
		var m:=ShaderMaterial.new();m.shader=load("res://assets/shaders/home_surface.gdshader")
		m.set_shader_parameter("tint",Color(color));m.set_shader_parameter("pattern",pattern)
		m.set_shader_parameter("roughness_value",.82 if pattern in [1,2] else .94)
		materials[key]=m
	return materials[key]
func block(parent: Node3D,p: Vector3,size_: Vector3,m: Material,id: String="Part",collision: bool=false) -> MeshInstance3D:
	var mesh:=G.box(parent,p,size_,m,id)
	if collision: P.box(parent,id+"Collision",p,size_)
	return mesh
func rounded(parent: Node3D,p: Vector3,size_: Vector3,r: float,m: Material,id: String="SoftEdge") -> MeshInstance3D:
	var key:=str(size_)+str(r)
	if not rounded_cache.has(key): rounded_cache[key]=rounded_box(size_,r)
	return G.mesh(parent,rounded_cache[key],p,m,id)
func rounded_box(size_: Vector3,r: float) -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half:=size_*.5
	r=minf(r,minf(half.x,minf(half.y,half.z))*.85)
	var inner:=half-Vector3.ONE*r
	for basis in [Basis(Vector3.RIGHT,Vector3.UP,Vector3.BACK),Basis(Vector3.LEFT,Vector3.UP,Vector3.FORWARD),Basis(Vector3.BACK,Vector3.UP,Vector3.LEFT),Basis(Vector3.FORWARD,Vector3.UP,Vector3.RIGHT),Basis(Vector3.RIGHT,Vector3.BACK,Vector3.DOWN),Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP)]:
		var u: Vector3=basis.x;var v: Vector3=basis.y;var n: Vector3=basis.z
		var a: float=half.dot(u.abs());var b: float=half.dot(v.abs());var c: float=half.dot(n.abs())
		var xs: Array[float]=[-a,-a+r*.3,-a+r,0,a-r,a-r*.3,a]
		var ys: Array[float]=[-b,-b+r*.3,-b+r,0,b-r,b-r*.3,b]
		for y in range(6):
			for x in range(6):
				for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
					var q: Vector3=u*xs[x+corner.x]+v*ys[y+corner.y]+n*c
					var core:=q.clamp(-inner,inner);var normal: Vector3=(q-core).normalized()
					st.set_normal(normal);st.set_uv(Vector2(xs[x+corner.x]/size_.length(),ys[y+corner.y]/size_.length()))
					st.add_vertex(core+normal*r)
	return st.commit()
func floor_collision(parent: Node3D,p: Vector3,size_: Vector3) -> void:
	var body:=G.solid_box(parent,p,size_,"WalkFloor");body.collision_layer=8;body.collision_mask=0
func construct(world: Node3D,definition: Dictionary) -> Node3D:
	blueprint=definition;floor_y=definition.floor_height;height=definition.wall_height;thickness=definition.wall_thickness
	root=Node3D.new();root.name=definition.get("node_name","SeabreezeHome")
	root.set_script(load("res://scripts/city/seabreeze_home.gd"));root.assembling=true
	root.floor_size=Vector2(definition.size[0],definition.size[1]);root.floor_level=floor_y;root.wall_height=height;root.roof_rise=definition.roof_rise
	root.position=Vector3(definition.origin[0],definition.origin[1],definition.origin[2])
	root.set_meta("buildable_reference",true);root.set_meta("blueprint_id",definition.id);root.set_meta("building_definition",definition.duplicate(true))
	root.set_meta("building_name",definition.name)
	if definition.has("door_id"): root.set_meta("door_id",definition.door_id)
	world.add_child(root)
	var structure:=group(root,"Structure")
	build_floor(group(structure,"Floor"))
	var walls:=group(structure,"Walls")
	for wall in definition.walls: build_wall(walls,wall)
	build_roof(group(structure,"Roof"))
	build_door(group(root,"Door"))
	var furnishing:=group(root,"Furnishing")
	for item in definition.furniture:
		var n:=group(furnishing,item.id,Vector3(item.position[0],floor_y+item.position[1],item.position[2]))
		n.set_meta("module_id",item.id);n.set_meta("module_type",item.kind);n.rotation.y=deg_to_rad(item.yaw)
		match item.kind:
			"sofa": build_sofa(n)
			"tea_table": build_tea_table(n)
			"bed": build_bed(n)
			"desk": build_desk(n)
			"hearth": build_hearth(n)
			"bookshelf": build_bookshelf(n)
			"workbench": preload("res://scripts/city/production_builder.gd").build_workbench(self,n)
			_: preload("res://scripts/city/forest_furniture.gd").build(self,n,item.kind)
		if item.has("facility"): preload("res://scripts/city/production_facilities.gd").configure(n,item.facility)
		bake_section(n)
	build_room_details(group(root,"RoomDetails"))
	build_garden(group(root,"Garden"))
	build_lights(group(root,"Lighting"))
	for wall in walls.get_children(): bake_section(wall)
	for section in [structure.get_node("Floor"),structure.get_node("Roof"),root.get_node("Door/Hinge"),root.get_node("RoomDetails"),root.get_node("Garden"),root.get_node("PorchCanopy")]: bake_section(section)
	return root
func build_floor(n: Node3D) -> void:
	var base:=material("c6b595")
	var w: float=blueprint.size[0];var d: float=blueprint.size[1]
	rounded(n,Vector3(0,floor_y-.145,0),Vector3(w+.44,.28,d+.44),.07,base,"Foundation")
	floor_collision(n,Vector3(0,floor_y-.17,0),Vector3(w+.32,.34,d+.32))
	var m:=ShaderMaterial.new();m.shader=load("res://assets/shaders/home_floor.gdshader")
	m.set_shader_parameter("wood_color",Color(blueprint.get("floor_color","cda56e")))
	m.set_shader_parameter("room_half_size",Vector2(w*.5,d*.5))
	block(n,Vector3(0,floor_y-.035,0),Vector3(w,.07,d),m,"OakFloor")
func wall_piece(n: Node3D,x: float,y: float,width_: float,tall: float) -> void:
	if width_<.001 or tall<.001: return
	block(n,Vector3(x,floor_y+y,0),Vector3(width_,tall,thickness),material(blueprint.materials.plaster),"Plaster",true)
	# The dado and skirting are deliberately raised from the plaster, no coplanar faces.
	var top: float=minf(y+tall*.5,.76);var bottom: float=maxf(y-tall*.5,0)
	if top>bottom:
		block(n,Vector3(x,floor_y+(top+bottom)*.5,-thickness*.5-.022),Vector3(width_,top-bottom,.035),material(blueprint.materials.panel),"InsideDado")
		block(n,Vector3(x,floor_y+.09,-thickness*.5-.045),Vector3(width_,.18,.055),material(blueprint.materials.trim),"Skirting")
		if top>.74: rounded(n,Vector3(x,floor_y+.78,-thickness*.5-.04),Vector3(width_,.07,.06),.015,material(blueprint.materials.trim),"DadoCap")
func build_wall(parent: Node3D,data: Dictionary) -> void:
	var a:=Vector2(data.a[0],data.a[1]);var b:=Vector2(data.b[0],data.b[1]);var dir: Vector2=(b-a).normalized();var length_: float=a.distance_to(b)
	var n:=group(parent,data.id,Vector3((a.x+b.x)*.5,0,(a.y+b.y)*.5));n.rotation.y=-atan2(dir.y,dir.x)
	n.set_meta("module_id",data.id);n.set_meta("module_type","wall");n.set_meta("outward",Vector3(-dir.y,0,dir.x));n.set_meta("length",length_)
	var openings: Array=data.openings.duplicate(true);openings.sort_custom(func(x,y): return x.offset<y.offset)
	var cursor: float=-length_*.5
	for opening in openings:
		var x: float=opening.offset-length_*.5;var left: float=x-opening.width*.5
		wall_piece(n,(cursor+left)*.5,height*.5,left-cursor,height)
		if opening.bottom>0: wall_piece(n,x,opening.bottom*.5,opening.width,opening.bottom)
		var above: float=height-opening.bottom-opening.height
		wall_piece(n,x,height-above*.5,opening.width,above)
		build_opening(n,x,opening)
		cursor=x+opening.width*.5
	wall_piece(n,(cursor+length_*.5)*.5,height*.5,length_*.5-cursor,height)
	for side in [-1,1]: rounded(n,Vector3(side*(length_*.5-.07),floor_y+height*.5,thickness*.5+.045),Vector3(.15,height,.12),.025,material(blueprint.materials.trim),"CornerTrim")
	rounded(n,Vector3(0,floor_y+height-.12,0),Vector3(length_,.18,.35),.035,material(blueprint.materials.trim),"Cornice")
func build_opening(n: Node3D,x: float,data: Dictionary) -> void:
	var w: float=data.width;var h: float=data.height;var bottom: float=data.bottom+floor_y
	var trim:=material(blueprint.materials.trim)
	for side in [-1,1]: rounded(n,Vector3(x+side*(w*.5+.035),bottom+h*.5,0),Vector3(.13,h+.12,.40),.024,trim,"OpeningJamb")
	rounded(n,Vector3(x,bottom+h+.025,0),Vector3(w+.20,.15,.42),.025,trim,"OpeningHead")
	if data.type=="door": return
	rounded(n,Vector3(x,bottom-.025,0),Vector3(w+.25,.14,.55),.03,trim,"WindowSill")
	var glass:=StandardMaterial3D.new();glass.albedo_color=Color("b3d6cf",.10);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.roughness=.22;glass.metallic_specular=.5;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	var pane:=block(n,Vector3(x,bottom+h*.5,0),Vector3(w-.12,h-.12,.016),glass,"WindowGlass");pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for z in [-.13,.13]:
		rounded(n,Vector3(x,bottom+h*.5,z),Vector3(.065,h,.055),.016,trim,"WindowMullion")
		rounded(n,Vector3(x,bottom+h*.56,z),Vector3(w,.065,.055),.016,trim,"WindowCrossbar")
	# Soft folded curtains sit inside the wall, clear of the glazing.
	for side in [-1,1]:
		for fold in range(3):
			G.capsule(n,Vector3(x+side*(w*.5-.12-fold*.09),bottom+.1,-.29),Vector3(x+side*(w*.5-.14-fold*.09),bottom+h-.08,-.29),.065,material("e6d8ba"),"CurtainFold")
		rounded(n,Vector3(x+side*(w*.5-.20),bottom+h*.40,-.36),Vector3(.30,.075,.12),.02,material("c49b69"),"CurtainTie")
	G.capsule(n,Vector3(x-w*.5-.22,bottom+h+.18,-.27),Vector3(x+w*.5+.22,bottom+h+.18,-.27),.035,material("aa855a"),"CurtainRail")
func triangle_prism(parent: Node3D,y: float,z: float,width_: float,rise: float,depth: float,m: Material) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3]=[Vector3(-width_*.5,y,z-depth*.5),Vector3(width_*.5,y,z-depth*.5),Vector3(0,y+rise,z-depth*.5),Vector3(-width_*.5,y,z+depth*.5),Vector3(width_*.5,y,z+depth*.5),Vector3(0,y+rise,z+depth*.5)]
	for face in [[0,1,2],[5,4,3],[0,3,4],[0,4,1],[1,4,5],[1,5,2],[2,5,3],[2,3,0]]:
		for i in face: st.add_vertex(points[i])
	st.generate_normals();G.mesh(parent,st.commit(),Vector3.ZERO,m,"SolidGable")
func build_roof(n: Node3D) -> void:
	n.set_meta("module_type","roof")
	var w: float=blueprint.size[0];var d: float=blueprint.size[1];var rise: float=blueprint.roof_rise;var span: float=w*.5+.5
	var angle:=atan2(rise,span);var slope_length:=sqrt(span*span+rise*rise)
	var y: float=floor_y+height;var roof:=material(blueprint.materials.roof,2);var trim:=material(blueprint.materials.trim)
	block(n,Vector3(0,y-.03,0),Vector3(w+.3,.16,d+.3),material("f0e4cf"),"Ceiling")
	P.box(n,"CeilingCollision",Vector3(0,y+.02,0),Vector3(w+.3,.14,d+.3))
	for side in [-1,1]:
		var slope:=block(n,Vector3(side*span*.5,y+rise*.5,0),Vector3(slope_length,.20,d+1.15),roof,"RoofSlope")
		slope.rotation.z=-side*angle
		rounded(n,Vector3(side*(span-.02),y-.04,0),Vector3(.20,.30,d+1.25),.04,trim,"Eave")
	for z in [-d*.5-.04,d*.5+.04]:
		triangle_prism(n,y,z,w,rise-.13,.24,material(blueprint.materials.plaster))
		for side in [-1,1]:
			var fascia:=rounded(n,Vector3(side*span*.5,y+rise*.5+.065,z+signf(z)*.62),Vector3(slope_length+.12,.20,.20),.025,trim,"Fascia")
			fascia.rotation.z=-side*angle
	G.capsule(n,Vector3(0,y+rise+.08,-d*.5-.70),Vector3(0,y+rise+.08,d*.5+.70),.12,material("497b78"),"RidgeCap")
	for z in [-d*.5-.85,d*.5+.85]: G.ball(n,Vector3(0,y+rise+.08,z),Vector3(.16,.15,.13),material("c9ae78"),"RidgeFinial")
	if blueprint.get("chimney",true):
		# Chimney has an actual dark inset mouth, rather than an open roof shell.
		block(n,Vector3(-2.8,y+1.60,-4.2),Vector3(.76,2.3,.72),material("b18b6b",3),"Chimney")
		rounded(n,Vector3(-2.8,y+2.77,-4.2),Vector3(.96,.16,.92),.035,material("cfb590"),"ChimneyCap")
		block(n,Vector3(-2.8,y+2.86,-4.2),Vector3(.50,.02,.48),material("4d514a"),"ChimneyMouth")
func build_door(n: Node3D) -> void:
	var wall: Dictionary={};var opening: Dictionary={}
	for candidate in blueprint.walls:
		for hole in candidate.openings:
			if hole.type=="door": wall=candidate;opening=hole;break
	var a:=Vector2(wall.a[0],wall.a[1]);var b:=Vector2(wall.b[0],wall.b[1]);var direction: Vector2=(b-a).normalized()
	var point: Vector2=a+direction*float(opening.offset)
	n.position=Vector3(point.x,floor_y+opening.bottom,point.y);n.rotation.y=-atan2(direction.y,direction.x)
	var width_: float=opening.width-.14;var tall: float=opening.height-.05
	var hinge:=group(n,"Hinge",Vector3(-width_*.5,0,0))
	root.door_width=width_;root.door_height=tall
	var door_mat:=material("6e9d90");var trim:=material("eee3c8")
	rounded(hinge,Vector3(width_*.5,tall*.5,0),Vector3(width_,tall,.16),.06,door_mat,"DoorLeaf")
	for side in [-1,1]:
		rounded(hinge,Vector3(width_*.5,tall*.73,side*.102),Vector3(width_-.58,tall*.34,.055),.055,material("bdd8cc"),"DoorUpperPanel")
		rounded(hinge,Vector3(width_*.5,tall*.29,side*.102),Vector3(width_-.58,tall*.35,.055),.055,material("639181"),"DoorLowerPanel")
		for x in [.28,width_-.28]: rounded(hinge,Vector3(x,tall*.5,side*.115),Vector3(.055,tall-.35,.045),.014,trim,"DoorStile")
		G.ball(hinge,Vector3(width_-.44,tall*.44,side*.18),Vector3.ONE*.070,G.mat("c9a958",.36),"DoorHandle")
	P.box(hinge,"LeafCollision",Vector3(width_*.5,tall*.5,0),Vector3(width_,tall,.20))
	P.box(n,"PortalCollision",Vector3(0,tall*.5,0),Vector3(width_,tall,.24))
	group(n,"ActionAnchor",Vector3(0,.02,.15))
func contact(parent: Node3D,p: Vector3,size_: Vector2) -> void:
	var m: ShaderMaterial
	if not materials.has("contact"):
		m=ShaderMaterial.new();m.shader=load("res://assets/shaders/contact_shadow.gdshader");materials.contact=m
	m=materials.contact
	var plane:=PlaneMesh.new();plane.size=size_
	var n:=G.mesh(parent,plane,p,m,"ContactShade");n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func pot(parent: Node3D,p: Vector3,scale_: float=1.0) -> void:
	var n:=group(parent,"CeramicPlant",p);n.scale=Vector3.ONE*scale_
	G.cylinder(n,Vector3(0,.26,0),.22,.50,G.mat("cd9d74"),.30)
	var rim:=TorusMesh.new();rim.inner_radius=.245;rim.outer_radius=.30;rim.rings=16;rim.ring_segments=8;G.mesh(n,rim,Vector3(0,.51,0),G.mat("e0ba8c"))
	G.cylinder(n,Vector3(0,.50,0),.24,.015,material("6a6550"))
	P.cylinder(n,"PotCollision",Vector3(0,.40,0),.30,.80)
	for i in range(7):
		var a: float=i*TAU/7;var tip:=Vector3(cos(a)*.36,.85+(i%3)*.16,sin(a)*.36)
		G.capsule(n,Vector3(0,.48,0),tip,.018,material("5c8653"))
		var leaf:=G.ball(n,tip,Vector3(.10,.24,.055),material("7ca86c" if i%2 else "5c9767"));leaf.rotation=Vector3(.25*cos(a),a,-.45)
func build_sofa(n: Node3D) -> void:
	var cloth:=Fabric.material({"color":"8fae9c","accent":"e7dcc0","pattern":"solid"})
	var pale:=material("eadfca");var oak:=material("a9855f",1)
	for x in [-1.28,1.28]:
		for z in [-.52,.52]: rounded(n,Vector3(x,.20,z),Vector3(.18,.40,.18),.025,oak)
	rounded(n,Vector3(0,.50,0),Vector3(3.35,.34,1.48),.15,cloth)
	rounded(n,Vector3(0,1.05,-.52),Vector3(3.35,1.18,.35),.14,cloth)
	for side in [-1,1]:
		rounded(n,Vector3(side*1.53,.86,.03),Vector3(.32,.78,1.48),.14,cloth)
		rounded(n,Vector3(side*.73,.76,.12),Vector3(1.42,.22,1.13),.095,material("afc1aa"))
		var cushion:=rounded(n,Vector3(side*1.0,1.12,-.25),Vector3(.66,.67,.22),.12,pale);cushion.rotation.z=side*.18
	var quilt:=Fabric.material({"color":"ba8177","accent":"f1dfbd","pattern":"tartan","pattern_scale":6.0})
	rounded(n,Vector3(-1.16,.90,.20),Vector3(.34,.055,1.04),.02,quilt,"SofaThrow")
	P.box(n,"SofaCollision",Vector3(0,.73,0),Vector3(3.42,1.4,1.5))
	group(n,"SeatAnchor",Vector3(.15,.88,.25));group(n,"ExitAnchor",Vector3(.1,.20,1.45))
	contact(n,Vector3(0,.004,0),Vector2(4.0,2.2))
func build_tea_table(n: Node3D) -> void:
	var oak:=material("c29a68",1)
	for x in [-.83,.83]:
		for z in [-.30,.30]: G.capsule(n,Vector3(x,.04,z),Vector3(x*.9,.62,z*.9),.055,material("96754f"))
	rounded(n,Vector3(0,.66,0),Vector3(2.35,.15,1.22),.15,oak)
	P.box(n,"TeaTableCollision",Vector3(0,.37,0),Vector3(2.35,.74,1.25))
	var ceramic:=G.mat("efe4ca",.55)
	G.cylinder(n,Vector3(.48,.80,0),.14,.16,ceramic,.16);G.cylinder(n,Vector3(.48,.885,0),.12,.012,G.mat("9a6948"))
	G.ball(n,Vector3(.65,.81,0),Vector3(.08,.06,.055),ceramic)
	rounded(n,Vector3(-.50,.77,.08),Vector3(.66,.07,.43),.025,material("6d9c95"),"LittleBook")
	block(n,Vector3(-.5,.82,.08),Vector3(.56,.025,.35),material("e9dfc6"))
	contact(n,Vector3(0,.004,0),Vector2(2.8,1.7))
func build_bed(n: Node3D) -> void:
	var oak:=material("b18b61",1)
	for x in [-1.05,1.05]:
		for z in [-1.85,1.85]: rounded(n,Vector3(x,.24,z),Vector3(.16,.48,.16),.035,oak)
	rounded(n,Vector3(0,.50,0),Vector3(2.5,.30,4.2),.08,oak)
	if blueprint.get("theme","")=="forest":
		for i in range(9): G.capsule(n,Vector3(-1.12+i*.28,.52,-2.14),Vector3(-1.12+i*.28,1.52+sin(i*PI/8)*.22,-2.14),.04,oak)
		G.capsule(n,Vector3(-1.3,1.60,-2.14),Vector3(1.3,1.60,-2.14),.09,oak)
	else: rounded(n,Vector3(0,.85,-2.14),Vector3(2.6,1.5,.16),.08,oak)
	rounded(n,Vector3(0,.75,0),Vector3(2.37,.30,4.04),.13,material("eee6d4"))
	var quilt:=ShaderMaterial.new();quilt.shader=load("res://assets/shaders/sleep_quilt.gdshader")
	quilt.set_shader_parameter("fabric_mask",load("res://assets/fabrics/tartan.svg"))
	quilt.set_shader_parameter("dye",Color("bb885a" if blueprint.get("theme","")=="forest" else "719e9c"));quilt.set_shader_parameter("accent",Color("e8dfbf"))
	var cloth:=PlaneMesh.new();cloth.size=Vector2(2.48,2.34);cloth.subdivide_width=30;cloth.subdivide_depth=32
	var blanket:=G.mesh(n,cloth,Vector3(0,.985,.78),quilt,"Quilt")
	blanket.set_meta("dynamic_mesh",true)
	var pillow:=rounded(n,Vector3(0,1.0,-1.03),Vector3(1.85,.20,1.04),.10,material("f3e9d3"),"Pillow")
	pillow.set_meta("dynamic_mesh",true)
	group(n,"ActionAnchor",Vector3(-2.6 if blueprint.get("theme","")=="forest" else -2.1,.20,.30));group(n,"SleepExit",Vector3(-2.6 if blueprint.get("theme","")=="forest" else -2.0,.20,1.5))
	P.box(n,"BedCollision",Vector3(0,.65,0),Vector3(2.6,1.30,4.3))
	var table:=group(n,"Bedside",Vector3(-1.9,0,-.9))
	rounded(table,Vector3(0,.40,0),Vector3(.74,.80,.70),.06,material("d1b58a",1))
	P.box(table,"BedsideCollision",Vector3(0,.40,0),Vector3(.74,.80,.70))
	G.ball(table,Vector3(0,.55,.37),Vector3.ONE*.035,G.mat("b79758",.4))
	G.cylinder(table,Vector3(0,.86,0),.20,.05,G.mat("c8a16c"))
	G.cylinder(table,Vector3(0,1.06,0),.035,.38,G.mat("b59b66"))
	G.cylinder(table,Vector3(0,1.34,0),.31,.33,G.mat("efe0ad",.8,.1),.18)
	contact(n,Vector3(0,.004,0),Vector2(3.4,4.0))
func build_desk(n: Node3D) -> void:
	var oak:=material("c6a779",1)
	for x in [-1.0,1.0]:
		for z in [-.37,.37]: rounded(n,Vector3(x,.50,z),Vector3(.14,1,.14),.025,oak)
	rounded(n,Vector3(0,1.06,0),Vector3(2.65,.16,1.10),.075,oak)
	rounded(n,Vector3(0,.84,.05),Vector3(2.28,.32,.84),.035,material("b99566"))
	G.ball(n,Vector3(0,.84,-.40),Vector3(.055,.035,.025),G.mat("c1a564"))
	P.box(n,"DeskCollision",Vector3(0,.62,0),Vector3(2.65,1.24,1.10))
	block(n,Vector3(.1,1.155,-.06),Vector3(.74,.025,.52),material("eee5cb"),"Letter")
	for i in range(4): block(n,Vector3(.05,1.17,-.19+i*.065),Vector3(.44,.004,.010),material("b2ac91"))
	pot(n,Vector3(.86,1.14,.16),.65)
	var chair:=group(n,"Chair",Vector3(0,0,-1.1))
	for x in [-.35,.35]:
		for z in [-.32,.32]: G.capsule(chair,Vector3(x,.06,z),Vector3(x,.64,z),.055,oak)
	rounded(chair,Vector3(0,.68,0),Vector3(.92,.16,.88),.08,material("839f8a"))
	rounded(chair,Vector3(0,1.07,-.37),Vector3(.92,.72,.13),.06,oak)
	P.box(chair,"ChairCollision",Vector3(0,.65,0),Vector3(.98,1.30,.95))
	group(n,"SeatAnchor",Vector3(0,.78,-1.1))
	group(n,"ExitAnchor",Vector3(-1.5,.20,-1.5))
	contact(n,Vector3(0,.004,0),Vector2(3.0,1.5))
func build_hearth(n: Node3D) -> void:
	var stone:=material("b49b7d",3)
	rounded(n,Vector3(0,.11,.15),Vector3(2.85,.22,1.20),.06,material("b7ac92"))
	for x in [-.94,.94]: block(n,Vector3(x,.82,0),Vector3(.48,1.48,.62),stone)
	block(n,Vector3(0,1.48,0),Vector3(2.4,.35,.65),stone)
	block(n,Vector3(0,.83,-.26),Vector3(1.6,1.16,.10),material("4d5148"))
	rounded(n,Vector3(0,1.73,.04),Vector3(2.85,.18,.88),.04,material("cba87c",1),"Mantel")
	P.box(n,"HearthCollision",Vector3(0,.88,.10),Vector3(2.8,1.76,1.1))
	for i in range(3):
		var log_: MeshInstance3D=G.capsule(n,Vector3(-.50,.35+i*.10,.10),Vector3(.50,.35+i*.1,.22),.09,material("806044"));log_.rotation.y=i*.17
	build_fire(n)
	pot(n,Vector3(-.91,1.83,0),.58)
	var clock_:=G.cylinder(n,Vector3(.55,2.12,0),.27,.09,material("a58c60"));clock_.rotation.x=PI*.5
	var face:=G.cylinder(n,Vector3(.55,2.12,.056),.23,.015,G.mat("eee4c8"));face.rotation.x=PI*.5
	G.capsule(n,Vector3(.55,2.12,.075),Vector3(.55,2.27,.075),.014,material("576d60"))
	G.capsule(n,Vector3(.55,2.12,.077),Vector3(.69,2.05,.077),.014,material("576d60"))
func build_fire(n: Node3D) -> void:
	var flame_material:=ShaderMaterial.new();flame_material.shader=load("res://assets/shaders/hearth_fire.gdshader")
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tongues: Array=[[-.33,.0,.10,.55,.80,0.0],[.06,.0,.04,.83,.99,.12],[.35,.01,-.02,.53,.88,-.28],[0.0,.0,.05,.82,.93,PI*.5]]
	for i in range(tongues.size()):
		var t: Array=tongues[i];var basis:=Basis(Vector3.UP,t[5])
		for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
			st.set_color(Color(float(i)/4,0,0,1));st.set_uv(Vector2(corner.x,1-corner.y))
			st.set_normal(basis*Vector3.BACK)
			st.add_vertex(Vector3(t[0],t[1]+.34,t[2])+basis*Vector3((corner.x-.5)*float(t[3]),corner.y*float(t[4]),0))
	var flames:=G.mesh(n,st.commit(),Vector3.ZERO,flame_material,"LivingFlames");flames.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spark_material:=ShaderMaterial.new();spark_material.shader=load("res://assets/shaders/hearth_embers.gdshader")
	var sparks:=SurfaceTool.new();sparks.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(6):
		for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
			sparks.set_color(Color((i+.4)/6,0,0,1));sparks.set_uv(corner);sparks.set_normal(Vector3.BACK)
			sparks.add_vertex(Vector3(sin(i*2.4)*.38+(corner.x-.5)*.025,.45+(corner.y-.5)*.043,.20+cos(i*3.2)*.08))
	var motes:=G.mesh(n,sparks.commit(),Vector3.ZERO,spark_material,"RisingEmbers");motes.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func build_bookshelf(n: Node3D) -> void:
	var oak:=material("bd9c70",1)
	for x in [-.7,.7]: rounded(n,Vector3(x,1.17,0),Vector3(.13,2.34,.6),.035,oak)
	for y in [.12,.82,1.52,2.26]: rounded(n,Vector3(0,y,0),Vector3(1.5,.12,.65),.025,oak)
	block(n,Vector3(0,1.15,-.28),Vector3(1.4,2.3,.07),material("aa8f65"))
	for row in range(3):
		for i in range(6):
			var color: String=["789b8d","bf8b73","d1b783","73909b","a49d83"][((row*3+i)%5)]
			var h: float=.43+(i%3)*.045
			rounded(n,Vector3(-.52+i*.20,.20+row*.70+h*.5,.02),Vector3(.15,h,.40),.016,material(color),"Book")
	P.box(n,"BookshelfCollision",Vector3(0,1.17,0),Vector3(1.6,2.34,.7))
func build_room_details(n: Node3D) -> void:
	if blueprint.get("theme","")=="workshop":
		preload("res://scripts/city/production_builder.gd").decorate_workshop(self,n);return
	if blueprint.get("theme","")=="forest":
		var art:=group(n,"PressedLeafArt",Vector3(1.3,floor_y+2.65,-4.83))
		for i in range(3):
			rounded(art,Vector3((i-1)*1.05,0,0),Vector3(.80,.98,.08),.035,material("b8925c"))
			block(art,Vector3((i-1)*1.05,0,.051),Vector3(.66,.84,.02),material("f0dfb4"))
			for j in range(3):
				var leaf:=G.ball(art,Vector3((i-1)*1.05+sin(j*2.)*.12,-.2+j*.18,.075),Vector3(.1,.14,.025),material("709a75"));leaf.rotation.z=j*.7
		return
	var rug:=Fabric.material({"color":"dfc9a5","accent":"8fa68a","pattern":"tartan","pattern_scale":1.2})
	rounded(n,Vector3(-3.1,floor_y+.012,.35),Vector3(4.55,.025,4.5),.01,rug,"WovenRug")
	for side in [-1,1]:
		for i in range(15): G.capsule(n,Vector3(-5.2+i*.30,floor_y+.017,.35+side*2.25),Vector3(-5.2+i*.30,floor_y+.017,.35+side*2.38),.012,material("dfcba8"),"RugFringe")
	pot(n,Vector3(-5.2,floor_y,-3.45),1.4)
	pot(n,Vector3(5.25,floor_y,.9),1.2)
	# Picture framing and tiny leaves use physical relief, not flat UI art.
	rounded(n,Vector3(-5.83,floor_y+2.7,2.7),Vector3(.10,1.35,1.12),.035,material("c8aa7c"),"WallPicture")
	block(n,Vector3(-5.76,floor_y+2.7,2.7),Vector3(.025,1.16,.94),material("e9dfc4"))
	for i in range(5):
		var leaf:=G.ball(n,Vector3(-5.73,floor_y+2.45+i*.13,2.7+sin(i*2)*.20),Vector3(.016,.12,.065),material("829f7b"));leaf.rotation.x=i*.6
func build_garden(n: Node3D) -> void:
	var paving:=material("c6bea3")
	rounded(n,Vector3(0,.03,6.0),Vector3(4.45,.28,2.35),.07,paving,"PorchLanding")
	floor_collision(n,Vector3(0,-.01,6.0),Vector3(4.45,.36,2.35))
	for i in range(int(blueprint.get("garden_path_stones",5))):
		var z: float=7.25+i*.95
		rounded(n,Vector3(.07*sin(i),.015,z),Vector3(2.85,.12,.78),.09,material("d3c7aa"),"PathStone")
		floor_collision(n,Vector3(.07*sin(i),-.08,z),Vector3(2.85,.31,.78))
	# Porch canopy is independent of the main roof; head clearance > 3.6 m.
	for x in [-1.92,1.92]:
		rounded(n,Vector3(x,2.0,6.55),Vector3(.18,3.7,.18),.035,material("dfcdac"),"PorchPost")
		P.box(n,"PostCollision",Vector3(x,1.9,6.55),Vector3(.22,3.8,.22))
	var canopy:=group(root,"PorchCanopy")
	var hood:=block(canopy,Vector3(0,4.05,5.9),Vector3(4.7,.20,2.25),material("679b91",2),"PorchCanopy");hood.rotation.x=.08
	rounded(canopy,Vector3(0,3.90,6.95),Vector3(4.85,.22,.20),.035,material("eee2c6"),"CanopyFascia")
	for x in ([-4.4,4.4] if blueprint.get("garden_flowerbeds",true) else []):
		rounded(n,Vector3(x,.11,6.2),Vector3(2.25,.22,1.9),.15,material("c6b58f"),"RaisedFlowerBed")
		for i in range(8):
			var p:=Vector3(x+sin(i*2.4)*.75,.28,6.2+cos(i*2.4)*.60)
			G.ball(n,p,Vector3(.33,.22,.31),material("77a376"))
			for petal in range(5): G.ball(n,p+Vector3(cos(petal*TAU/5)*.09,.23,sin(petal*TAU/5)*.09),Vector3(.075,.04,.075),material("e6bb89" if i%2 else "d99886"))
			G.ball(n,p+Vector3(0,.26,0),Vector3.ONE*.045,material("d7b65a"))
		P.box(n,"FlowerBedCollision",Vector3(x,.27,6.2),Vector3(2.3,.54,1.9))
	for side in ([-1,1] if blueprint.get("garden_fence",true) else []):
		for i in range(8):
			var x: float=side*(2.4+i*.45)
			rounded(n,Vector3(x,.48,10.5),Vector3(.16,.96,.12),.035,material("d6bb91"),"GardenPicket")
		for y in [.25,.68]: block(n,Vector3(side*4.0,y,10.5),Vector3(3.55,.09,.10),material("c2a279"))
		P.box(n,"GardenFenceCollision",Vector3(side*4.0,.48,10.5),Vector3(3.6,.96,.16))
	pot(n,Vector3(-2.65,.05,5.65),1.1);pot(n,Vector3(2.65,.05,5.65),1.0)
	var sign_:=group(n,"Nameplate",Vector3(-2.7,1.45,5.25))
	rounded(sign_,Vector3.ZERO,Vector3(1.5,.66,.14),.06,material("d1b58a"))
	G.text3d(sign_,blueprint.get("name","海风小屋"),Vector3(0,0,.082),22,Color("426c5e"))
	var mail:=group(n,"Mailbox",Vector3(-5.55,0,9.1))
	block(mail,Vector3(0,.65,0),Vector3(.12,1.3,.12),material("9c7b55"))
	rounded(mail,Vector3(0,1.25,0),Vector3(.68,.48,.48),.12,material("709d8c"))
	block(mail,Vector3(0,1.30,.25),Vector3(.35,.025,.025),material("f0dfb7"))
	P.box(mail,"MailboxCollision",Vector3(0,.78,0),Vector3(.70,1.55,.52))
func build_lights(n: Node3D) -> void:
	var lamp:=group(n,"Pendant",Vector3(-1.2,floor_y+3.90,-.2))
	G.cylinder(lamp,Vector3(0,.17,0),.025,.55,material("a88b57"))
	G.cylinder(lamp,Vector3(0,-.13,0),.48,.30,G.mat("e9d4a2",.85,.12),.24)
	G.cylinder(lamp,Vector3(0,-.30,0),.38,.015,G.mat("f9e6b6",.8,.3))
	var key:=SpotLight3D.new();key.name="RoomKey";key.position=Vector3(-1.2,floor_y+3.55,-.2);key.rotation.x=-PI*.5;key.light_color=Color("ffe1ad");key.light_energy=1.4;key.spot_range=9;key.spot_angle=72;key.spot_attenuation=1.0;key.shadow_enabled=true;key.shadow_blur=1.8;key.shadow_bias=.035;key.shadow_normal_bias=.45;n.add_child(key)
	var fill:=OmniLight3D.new();fill.name="RoomFill";fill.position=Vector3(0,2.4,2.6);fill.light_color=Color("f5d9b1");fill.light_energy=.35;fill.omni_range=4.8;fill.shadow_enabled=false;n.add_child(fill)
	var bedside:=OmniLight3D.new();bedside.name="BedsideLight";bedside.position=Vector3(1.4,floor_y+1.35,-3.55);bedside.light_color=Color("ffd49a");bedside.light_energy=.55;bedside.omni_range=3.3;bedside.shadow_enabled=false;n.add_child(bedside)
	var hearth:=SpotLight3D.new();hearth.name="HearthLight";hearth.position=Vector3(-2.8,1.0,-4.0);hearth.rotation.x=-.20;hearth.rotation.y=PI;hearth.light_color=Color("ffb866");hearth.light_energy=.65;hearth.spot_angle=72;hearth.spot_range=4;hearth.shadow_enabled=false;n.add_child(hearth)
	var porch:=OmniLight3D.new();porch.name="PorchLight";porch.position=Vector3(2.35,2.85,5.55);porch.light_color=Color("ffdc9b");porch.light_energy=1.3;porch.omni_range=4.5;porch.shadow_enabled=false;n.add_child(porch)
	var fixture:=group(n,"PorchFixture",porch.position)
	G.box(fixture,Vector3.ZERO,Vector3(.24,.40,.24),G.mat("f7d897",.8,.2))
	for x in [-.15,.15]: block(fixture,Vector3(x,0,0),Vector3(.035,.46,.30),material("597467"))
	block(fixture,Vector3(0,.24,0),Vector3(.36,.07,.36),material("597467"))
	for id in blueprint.get("light_positions",{}):
		var position_: Array=blueprint.light_positions[id]
		if n.has_node(NodePath(id)): n.get_node(NodePath(id)).position=Vector3(position_[0],position_[1],position_[2])
	bake_section(lamp);bake_section(fixture)
func bake_section(parent: Node3D) -> void:
	var groups: Dictionary={}
	for part in parent.find_children("*","MeshInstance3D",true,false):
		if part.get_meta("dynamic_mesh",false): continue
		var m: Material=part.material_override
		if m==null: continue
		var shape: Mesh=part.mesh
		var dye:=Color.WHITE
		var pattern:=-1
		var rough:=.94
		if m is ShaderMaterial and m.shader==load("res://assets/shaders/home_surface.gdshader"):
			dye=m.get_shader_parameter("tint")
			pattern=int(m.get_shader_parameter("pattern"))
			rough=float(m.get_shader_parameter("roughness_value"))
		elif m is StandardMaterial3D and m.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and not m.emission_enabled and m.roughness>.69:
			dye=m.albedo_color;pattern=0
		elif m is ShaderMaterial and m.shader==Fabric.shader_for("") and not m.get_shader_parameter("patterned"):
			dye=m.get_shader_parameter("dye");pattern=0
		if pattern>=0:
			var cache_key:=str(pattern)+str(rough)
			if not batch_materials.has(cache_key):
				var shared:=ShaderMaterial.new();shared.shader=load("res://assets/shaders/home_surface.gdshader")
				shared.set_shader_parameter("tint",Color.WHITE);shared.set_shader_parameter("vertex_tint",true)
				shared.set_shader_parameter("pattern",pattern);shared.set_shader_parameter("roughness_value",rough)
				batch_materials[cache_key]=shared
			m=batch_materials[cache_key]
			var colored:=ArrayMesh.new()
			for surface in range(shape.get_surface_count()):
				var arrays:=shape.surface_get_arrays(surface)
				var colors:=PackedColorArray();colors.resize(arrays[Mesh.ARRAY_VERTEX].size());colors.fill(dye.srgb_to_linear())
				arrays[Mesh.ARRAY_COLOR]=colors
				colored.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			shape=colored
		var key:=str(m.get_instance_id())+str(part.cast_shadow)
		if not groups.has(key): groups[key]={"material":m,"shadow":part.cast_shadow,"st":SurfaceTool.new()};groups[key].st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var transform_: Transform3D=parent.global_transform.affine_inverse()*part.global_transform
		# Normalize indexed primitives and unindexed bevel meshes before merging.
		# Mixing formats leaves only the first primitive referenced by the index buffer.
		var triangles:=SurfaceTool.new();triangles.create_from(shape,0);triangles.deindex()
		groups[key].st.append_from(triangles.commit(),0,transform_)
		part.get_parent().remove_child(part);part.free()
	for entry in groups.values():
		var shape: ArrayMesh=entry.st.commit()
		if shape==null: continue
		var n:=G.mesh(parent,shape,Vector3.ZERO,entry.material,"ModuleBatch");n.cast_shadow=entry.shadow
