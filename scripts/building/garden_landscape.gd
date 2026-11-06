extends RefCounted
## Authored planting groups with deterministic variation, shared foliage shading,
## clear walking lanes, and no plants or furniture on the private parcels.
const G=preload("res://scripts/geometry.gd")
static func canopy(st: SurfaceTool,center: Vector3,size_: Vector3,color: Color,seed_: float,conifer: bool=false) -> void:
	var rings:=12;var segments:=24;var start: int=st.get_meta("vertex_count",0)
	st.set_meta("vertex_count",start+(rings+1)*(segments+1))
	for row in range(rings+1):
		var v: float=row/float(rings);var theta: float=v*PI
		for col in range(segments+1):
			var a: float=col*TAU/segments
			var lobe: float=1.+sin(a*3.+seed_)*.09*sin(theta)+cos(a*5.-seed_)*.04*sin(theta*2.)
			var p:=Vector3(cos(a)*sin(theta)*lobe,cos(theta),sin(a)*sin(theta)*lobe)
			if conifer:p=Vector3(cos(a)*pow(v,.85)*lobe,.75-v,sin(a)*pow(v,.85)*lobe)
			st.set_color(color*(.94+.07*(1.-v)));st.set_uv(Vector2(col/float(segments),v));st.add_vertex(center+p*size_)
	for row in range(rings):
		for col in range(segments):
			var i: int=start+row*(segments+1)+col
			for j in [i,i+segments+1,i+1,i+1,i+segments+1,i+segments+2]:st.add_index(j)
static func tree(root: Node3D,p: Vector3,index: int,kind: int) -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=17011+index*2039
	var node:=Node3D.new();node.name="PublicTree%d"%index;node.position=p;node.rotation.y=rng.randf()*TAU;node.set_meta("tree_species",["oak","birch","pine","coastal_pine"][kind]);root.add_child(node)
	var h: float=rng.randf_range(4.4,6.2) if kind!=3 else rng.randf_range(3.7,4.7)
	var lean:=Vector3(rng.randf_range(-.18,.18),0,rng.randf_range(-.18,.18));var bark:=G.mat("c8c6b4" if kind==1 else ("8c765d" if kind==3 else "81654c"))
	if kind==3:lean.x=.75
	G.capsule(node,Vector3(0,.03,0),Vector3(lean.x,h*.66,lean.z),.12 if kind==1 else .20,bark,"Trunk")
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var color:=Color(["426c42","74905a","315d4a","547754"][kind]).lightened(rng.randf_range(-.045,.045))
	if kind==2:
		for tier in range(4):canopy(st,Vector3(0,h*.46+tier*h*.13,0),Vector3(1.65-tier*.30,h*.5,1.65-tier*.30),color,rng.randf()*50,true)
	else:
		var clumps: int=4 if kind!=1 else 3
		for i in range(clumps):
			var a: float=i*2.399+rng.randf_range(-.4,.4)
			var width: float=rng.randf_range(1.2,1.65) if kind==0 else (rng.randf_range(.75,1.05) if kind==1 else rng.randf_range(1.2,1.55))
			var center:=Vector3(lean.x+cos(a)*.7,h*(.68+i*.055),lean.z+sin(a)*.6)
			canopy(st,center,Vector3(width,h*.23 if kind!=3 else h*.14,width*.86),color,rng.randf()*50)
			G.capsule(node,Vector3(lean.x*.5,h*.45,lean.z*.5),center-Vector3.UP*.3,.055 if kind==1 else .085,bark,"Bough")
	st.generate_normals();var material:=ShaderMaterial.new();material.shader=preload("res://assets/shaders/occlusion_fade.gdshader");material.set_shader_parameter("vertex_tint",true)
	var crown:=Node3D.new();crown.name="Crown";crown.position.y=h*.75;node.add_child(crown);G.mesh(crown,st.commit(),Vector3(0,-h*.75,0),material,"LeafCanopy")
	if kind==1:
		for i in range(6):
			var mark:=G.box(node,Vector3(lean.x*.4,.45+i*.40,.125),Vector3(.13,.035,.012),G.mat("686c60"),"BarkMark");mark.rotation.y=i*.75
	preload("res://scripts/city/prop_collisions.gd").cylinder(node,"TreeCollision",Vector3(0,h*.26,0),.24,h*.52)
static func flower_patch(root: Node3D,p: Vector3,size_: Vector2,seed_: int) -> void:
	var node:=Node3D.new();node.name="PerennialBorder%d"%seed_;node.position=p;root.add_child(node)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);var rng:=RandomNumberGenerator.new();rng.seed=seed_
	var colors: Array[Color]=[Color("e4c99e"),Color("c4b3d4"),Color("e5ab98"),Color("f0e5be")]
	for i in range(30):
		var q:=Vector3(rng.randf_range(-size_.x*.5,size_.x*.5),.035,rng.randf_range(-size_.y*.5,size_.y*.5))
		preload("res://scripts/city/meadow_blossoms.gd").bloom(st,q,colors[(i/7+seed_)%4],rng,rng.randf_range(.6,1.05))
	st.generate_normals();var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/forest_blossoms.gdshader");var mesh:=G.mesh(node,st.commit(),Vector3.ZERO,mat,"MixedPerennials");mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
static func path(root: Node3D,paving: Material) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(32):
		var x0: float=62.+i*3.;var x1: float=x0+3.
		var u:=smoothstep(62.,76.,x0);var v:=smoothstep(62.,76.,x1)
		var z0:=lerpf(13.,10.,u);var z1:=lerpf(13.,10.,v);var w0:=lerpf(3.165,1.8,u);var w1:=lerpf(3.165,1.8,v)
		quad(st,Vector3(x0,.025,z0-w0),Vector3(x1,.025,z1-w1),Vector3(x1,.025,z1+w1),Vector3(x0,.025,z0+w0))
	# Split at the plaza to avoid coplanar overlapping road triangles.
	for ends in [[-15.,5.],[15.,35.]]:quad(st,Vector3(108.4,.026,ends[0]),Vector3(111.6,.026,ends[0]),Vector3(111.6,.026,ends[1]),Vector3(108.4,.026,ends[1]))
	st.generate_normals();var material: Material=paving.duplicate()
	if material is ShaderMaterial:material.set_shader_parameter("stone_color",Color("b2b59f"))
	G.mesh(root,st.commit(),Vector3.ZERO,material,"WindingGardenWalk")
	var disk:=CylinderMesh.new();disk.top_radius=5.2;disk.bottom_radius=5.2;disk.height=.035;disk.radial_segments=64
	G.mesh(root,disk,Vector3(110,.02,10),material,"GardenPlaza")
static func quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	for p in [a,b,c,a,c,d]:st.set_uv(Vector2(p.x,p.z));st.add_vertex(p)
static func garden_details(root: Node3D) -> void:
	# Layer the public verges: soft shrubs behind flowers, small sandstone groups,
	# and low lanterns that repeat the bridge metalwork without crowding the path.
	var leaves:=SurfaceTool.new();leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rocks:=SurfaceTool.new();rocks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var metal:=SurfaceTool.new();metal.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass:=SurfaceTool.new();glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng:=RandomNumberGenerator.new();rng.seed=36071
	for p in [Vector3(70,0,16.7),Vector3(104.5,0,-3),Vector3(115.7,0,23),Vector3(150,0,12.5),Vector3(85,0,-15),Vector3(131,0,35)]:
		for j in range(5):
			var q: Vector3=p+Vector3((j-2)*.65,.35+rng.randf()*.16,sin(j*1.7)*.35)
			canopy(leaves,q,Vector3(.65,.42+rng.randf()*.18,.65),Color("56774a").lightened(rng.randf_range(-.06,.06)),rng.randf()*30.)
		for j in range(3):
			var pebble:=SphereMesh.new();pebble.radius=1.;pebble.height=2.;pebble.radial_segments=8;pebble.rings=4
			var q: Vector3=p+Vector3(1.5+j*.42,.12,.75+sin(j*2.)*.22)
			rocks.append_from(pebble,0,Transform3D(Basis.from_scale(Vector3(.34,.22,.28)*rng.randf_range(.75,1.2)),q))
	for i in range(8):
		var p: Vector3=[Vector3(73,0,7.2),Vector3(73,0,12.8),Vector3(106.4,0,-9),Vector3(113.6,0,-9),Vector3(106.4,0,29),Vector3(113.6,0,29),Vector3(147,0,7),Vector3(147,0,13)][i]
		for row in [[.04,Vector3(.32,.08,.32)],[.52,Vector3(.09,.96,.09)],[.96,Vector3(.28,.07,.28)],[1.22,Vector3(.37,.08,.37)]]:
			preload("res://scripts/building/garden_bridge.gd").append_box(metal,p+Vector3.UP*row[0],row[1])
		preload("res://scripts/building/garden_bridge.gd").append_box(glass,p+Vector3.UP*1.08,Vector3(.22,.20,.22))
		preload("res://scripts/city/prop_collisions.gd").box(root,"GardenLampCollision",p+Vector3.UP*.65,Vector3(.25,1.3,.25))
		if i%2==0:
			var light:=OmniLight3D.new();light.name="GardenLantern";light.position=p+Vector3.UP*1.2;light.light_color=Color("ffdcaa");light.light_energy=.28;light.omni_range=3.5;light.shadow_enabled=false;light.distance_fade_enabled=true;light.distance_fade_begin=20.;light.distance_fade_length=8.;root.add_child(light)
	leaves.generate_normals();var foliage:=G.mat("ffffff").duplicate();foliage.vertex_color_use_as_albedo=true;foliage.vertex_color_is_srgb=true
	G.mesh(root,leaves.commit(),Vector3.ZERO,foliage,"LayeredShrubBorders")
	rocks.generate_normals();G.mesh(root,rocks.commit(),Vector3.ZERO,G.mat("b8b09a"),"SandstoneGroups")
	G.mesh(root,metal.commit(),Vector3.ZERO,G.mat("527365",.55),"GardenPathLanterns")
	G.mesh(root,glass.commit(),Vector3.ZERO,G.mat("f0d59e",.55,.25),"GardenLanternPanes")
static func build(parent: Node3D,paving: Material) -> Node3D:
	var root:=Node3D.new();root.name="GardenCommons";parent.add_child(root);path(root,paving);garden_details(root)
	# Grouped groves with deliberate openings rather than a repeated tree grid.
	var groups: Array=[[[66.,-8.,3],[69.,-3.,0],[73.,.8,1]],[[65.5,23.,3],[70.5,26.,0],[73.,30.5,1]],[[148.,-9.,2],[153.,-5.5,0],[149.5,.5,1]],[[148.,23.5,1],[153.,27.,3],[148.5,32.,0]],[[83.,-15.,1],[94.,-15.,0]],[[124.,-15.,2],[138.,-15.,3]],[[84.,35.,0],[96.,35.,1]],[[125.,35.,3],[138.,35.,2]],[[104.,-8.,1],[116.,-10.,0]],[[104.,28.,0],[116.,30.,1]]]
	var index:=0
	for group in groups:
		for row in group:tree(root,Vector3(row[0],-.025,row[1]),index,int(row[2]));index+=1
	for row in [[104.5,-2.,2.,5.],[115.7,23.,1.8,5.],[70.,17.,3.,2.],[150.,13.,4.,2.],[87.,-15.,6.,1.2],[133.,35.,6.,1.2]]:
		flower_patch(root,Vector3(row[0],-.01,row[1]),Vector2(row[2],row[3]),101+int(row[0]))
	for i in range(3):preload("res://scripts/city/plaza_flowerbed.gd").build(root,[Vector3(110,0,10),Vector3(110,0,-13),Vector3(110,0,33)][i],i)
	for p in [Vector3(65,.0,17),Vector3(149,.0,5)]:
		for i in range(4):
			var shrub:=SurfaceTool.new();shrub.begin(Mesh.PRIMITIVE_TRIANGLES);canopy(shrub,Vector3.ZERO,Vector3(.65,.48,.62),Color("53744d"),i*3.)
			shrub.generate_normals();var m:=G.mat("ffffff").duplicate();m.vertex_color_use_as_albedo=true;m.vertex_color_is_srgb=true
			G.mesh(root,shrub.commit(),p+Vector3(i*.9,.48,sin(i)*.4),m,"LowShrub")
	return root
