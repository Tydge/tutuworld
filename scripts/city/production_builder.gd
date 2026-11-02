extends RefCounted
## Self-contained placeable modules: geometry, collision and anchors share a root.
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
const Facilities=preload("res://scripts/city/production_facilities.gd")
static func group(parent: Node3D,id: String,point:=Vector3.ZERO) -> Node3D:
	var node:=Node3D.new();node.name=id;node.position=point;parent.add_child(node);return node
static func build_well(world: Node3D,row: Dictionary) -> Node3D:
	var root:=group(world,"GardenWell",Facilities.vector(row.origin));root.rotation.y=deg_to_rad(row.yaw)
	root.set_meta("buildable_reference",true);root.set_meta("module_id",row.id);root.set_meta("module_type","well");root.set_meta("object_definition",row.duplicate(true))
	Facilities.configure(root,row)
	root.set_meta("occlusion_section","Roof")
	root.set_meta("occlusion_center",Vector3(0,3.0,0))
	var stone:=G.mat("b7b39b");var wood:=G.mat("987044");var dark:=G.mat("674c33");var copper:=G.mat("ba875e",.5)
	var structure:=group(root,"Structure")
	G.cylinder(structure,Vector3(0,.035,0),1.35,.10,G.mat("c9bea0"))
	var floor_:=G.solid_box(structure,Vector3(0,-.08,0),Vector3(2.4,.24,2.4),"WellFoundation");floor_.collision_layer=8
	for row_ in range(3):
		for index in range(16):
			var angle: float=(index+row_*.5)*TAU/16
			var block:=G.box(structure,Vector3(sin(angle)*.87,.20+row_*.29,cos(angle)*.87),Vector3(.345,.27,.28),stone if (index+row_)%3 else G.mat("a6a993"),"StoneBlock")
			block.rotation.y=angle
	var rim:=TorusMesh.new();rim.inner_radius=.71;rim.outer_radius=1.05;rim.rings=48;rim.ring_segments=10
	G.mesh(structure,rim,Vector3(0,.99,0),G.mat("d0c4a7"),"WellRim")
	G.cylinder(structure,Vector3(0,.25,0),.74,.02,G.mat("263f40"),-1,"WellDepth")
	G.cylinder(structure,Vector3(0,.43,0),.73,.02,G.mat("527f80",.23),-1,"WellWater")
	P.cylinder(structure,"WellCollision",Vector3(0,.52,0),1.04,1.04)
	for side in [-1,1]:
		G.box(structure,Vector3(side*1.24,1.41,0),Vector3(.17,2.82,.20),wood,"Post")
		P.box(structure,"PostCollision",Vector3(side*1.24,1.4,0),Vector3(.20,2.8,.24))
	var axle:=G.cylinder(structure,Vector3(0,2.23,0),.085,2.95,dark);axle.rotation.z=PI/2
	G.capsule(structure,Vector3(1.52,2.23,0),Vector3(1.52,1.91,0),.05,copper)
	G.capsule(structure,Vector3(1.52,1.91,0),Vector3(1.80,1.91,0),.06,wood)
	G.cylinder(structure,Vector3(0,1.80,0),.018,.84,G.mat("d6bd8a"),-1,"BucketRope")
	var bucket:=group(root,"Bucket",Vector3(0,1.20,0))
	G.cylinder(bucket,Vector3.ZERO,.19,.34,wood,.23)
	for y in [-.12,.12]: G.cylinder(bucket,Vector3(0,y,0),.224,.035,copper)
	G.capsule(bucket,Vector3(-.20,.15,0),Vector3(0,.35,0),.022,dark);G.capsule(bucket,Vector3(0,.35,0),Vector3(.20,.15,0),.022,dark)
	var roof:=group(root,"Roof")
	for side in [-1,1]:
		var panel:=G.box(roof,Vector3(side*.79,2.95,0),Vector3(1.83,.16,2.52),G.mat("6b8f7d"),"RoofPanel");panel.rotation.z=-side*.31
	G.box(roof,Vector3(0,3.25,0),Vector3(.20,.20,2.64),dark,"Ridge")
	G.box(structure,Vector3(0,1.95,1.05),Vector3(1.42,.40,.10),wood,"Nameplate")
	G.text3d(structure,"菜园水井",Vector3(0,1.96,1.11),22,Color("f6e6bc"))
	var builder=load("res://scripts/city/home_builder.gd").new()
	for section in [structure,bucket,roof]: builder.bake_section(section)
	return root
static func build_workbench(builder: RefCounted,node: Node3D) -> void:
	var oak: Material=builder.material("ad8255",1);var dark: Material=builder.material("745a40",1);var copper:=G.mat("bf8b5d",.43)
	for x in [-1.70,1.70]:
		for z in [-.40,.40]: builder.rounded(node,Vector3(x,.51,z),Vector3(.19,1.02,.19),.035,dark)
	builder.rounded(node,Vector3(0,1.06,0),Vector3(4.2,.22,1.3),.065,oak,"Worktop")
	builder.rounded(node,Vector3(0,.32,0),Vector3(3.6,.12,1.05),.03,dark,"LowerShelf")
	P.box(node,"WorkbenchCollision",Vector3(0,.60,0),Vector3(4.2,1.2,1.3))
	for i in range(4): G.box(node,Vector3(-.6+i*.32,.45,0),Vector3(.24,.20,.78),builder.material("b99e70"),"StoredLumber")
	builder.rounded(node,Vector3(0,2.02,-.64),Vector3(4.05,1.55,.12),.04,builder.material("8b7757"),"ToolBoard")
	for i in range(4):
		var x: float=-1.4+i*.85
		G.capsule(node,Vector3(x,1.62,-.50),Vector3(x,2.40,-.50),.035,oak,"ToolHandle")
		G.box(node,Vector3(x,2.39,-.50),Vector3(.42,.16,.18),copper if i%2 else G.mat("9ca8a0",.45),"ToolHead")
	builder.rounded(node,Vector3(-1.18,1.24,.10),Vector3(.62,.27,.58),.045,G.mat("748c83"),"BenchVice")
	G.capsule(node,Vector3(-1.18,1.25,.35),Vector3(-1.18,1.25,.65),.035,copper)
	G.box(node,Vector3(.75,1.18,.05),Vector3(1.00,.025,.65),G.mat("eee1bd"),"Plans")
	for i in range(3): G.box(node,Vector3(.75,1.197,-.15+i*.13),Vector3(.58,.004,.015),G.mat("7d9c93"))
	G.cylinder(node,Vector3(1.57,1.33,-.07),.14,.35,copper,-1,"CopperOffcuts")
	G.text3d(node,"制造工作台",Vector3(0,.82,.67),24,Color("f0dfb6"))
static func decorate_workshop(builder: RefCounted,node: Node3D) -> void:
	var art:=group(node,"WorkshopEmblem",Vector3(0,2.6,-4.80))
	builder.rounded(art,Vector3.ZERO,Vector3(1.5,1.35,.12),.09,builder.material("b89769"))
	G.capsule(art,Vector3(-.36,-.34,.09),Vector3(.30,.36,.09),.07,G.mat("d6c49f"))
	G.box(art,Vector3(.30,.36,.10),Vector3(.66,.25,.18),G.mat("b98051",.45))
	G.text3d(node,"把收集的小东西，做成生活的帮手。",Vector3(0,3.55,-4.73),23,Color("7e765c"))
