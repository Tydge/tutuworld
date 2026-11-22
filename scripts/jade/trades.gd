extends RefCounted
## Goods that a pedestrian can recognise from across the lane. The same joinery is placeable.
const A=preload("res://scripts/jade/architecture.gd")
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
const KINDS=["jade_steam_table","jade_pastry_board","jade_smith_rack","jade_seed_bins"]
static func table(n: Node3D,wide: float,top: float) -> void:
	for x in [-1.,1.]:
		for z in [-1.,1.]:
			A.box(n,Vector3(x*(wide*.5-.15),top*.5,z*.46),Vector3(.14,top,.14),"745136")
		A.box(n,Vector3(x*(wide*.5-.15),top*.33,0),Vector3(.12,.14,1.06),"8a6441")
	A.paint(n,Vector3.UP*top,Vector3(wide,.16,1.18),"wood_relief")
static func torus(n: Node3D,pos: Vector3,r: float,thickness: float,pigment: String) -> void:
	var circle:=TorusMesh.new()
	circle.outer_radius=r;circle.inner_radius=r-thickness;circle.rings=24;circle.ring_segments=6
	G.mesh(n,circle,pos,G.mat(pigment))
static func steamers(n: Node3D) -> void:
	table(n,3.36,.86)
	for i in range(3):
		var center:=Vector3((i-1)*1.04,.95,0)
		var tiers:=3 if i==0 else (2 if i==2 else 1)
		for j in range(tiers):
			var pos:=center+Vector3.UP*(.14+j*.25)
			G.cylinder(n,pos,.49,.27,G.mat("bb8958"),.48)
			for ring in [-.115,.08]:torus(n,pos+Vector3.UP*ring,.498,.038,"6d5038")
		var top:=center+Vector3.UP*(tiers*.25+.035)
		G.cylinder(n,top,.455,.035,G.mat("8d6843"))
		if i==0:
			var lid:=A.group(n,"WovenLid",top+Vector3(.10,.18,-.24))
			lid.rotation.x=-.53
			G.cylinder(lid,Vector3.ZERO,.45,.055,G.mat("b29a63"))
			for j in range(7):
				var z: float=(j-3)*.108
				A.box(lid,Vector3(0,.043,z),Vector3(2.*sqrt(.185-z*z),.018,.038),"846440")
			continue
		for j in range(7):
			var a:=TAU*j/6.
			var q:=top+(Vector3(cos(a),0,sin(a))*.27 if j<6 else Vector3.ZERO)
			G.ball(n,q+Vector3.UP*.077,Vector3(.125,.105,.125),G.mat("efe1ba"))
			for k in range(4):
				var b:=k*PI*.5
				var ridge:=G.ball(n,q+Vector3(.052*cos(b),.15,.052*sin(b)),Vector3(.016,.018,.050),G.mat("cca780"))
				ridge.rotation.y=-b+PI*.5
static func pastries(n: Node3D) -> void:
	table(n,3.18,.83)
	for i in range(3):
		var tray:=A.group(n,"LacquerTray",Vector3((i-1)*.94,.95,.03))
		tray.rotation.y=(i-1)*.09
		A.paint(tray,Vector3.ZERO,Vector3(.85,.11,.88),"lacquer")
		for j in range(6):
			var p:=Vector3((j%2-.5)*.36,.094,(j/2-1)*.25)
			G.cylinder(tray,p,.132,.093,G.mat("cc9c63" if i!=2 else "a86d46"),.147)
			var almond:=G.ball(tray,p+Vector3(.015,.055,0),Vector3(.067,.021,.029),G.mat("755038"))
			almond.rotation.y=j*1.79
static func smith(n: Node3D) -> void:
	for x in [-1.4,1.4]:
		A.box(n,Vector3(x,.09,0),Vector3(.41,.18,.90),"574a40")
		A.beam(n,Vector3(x,.13,-.30),Vector3(x,2.62,.10),.14,"78563d")
	A.paint(n,Vector3(0,2.58,.09),Vector3(3.04,.19,.20),"wood_relief")
	A.box(n,Vector3(0,.71,.03),Vector3(2.86,.16,.22),"785a43")
	for i in range(5):
		var tool:=A.group(n,"ForgedTool",Vector3((i-2)*.56,1.98,.22))
		tool.rotation.z=(i-2)*.06
		G.cylinder(tool,Vector3.DOWN*.42,.067,1.05,G.mat("9b7043"))
		if i%2==0:
			var head:=G.cylinder(tool,Vector3(.12,.06,0),.23,.32,G.mat("647574",.45),.12)
			head.rotation.z=PI*.50
			A.box(tool,Vector3(.27,.05,0),Vector3(.097,.40,.10),"a1aeaa")
		else:
			A.beam(tool,Vector3(-.31,-.09,0),Vector3(0,.12,0),.13,"6e7c79")
			A.beam(tool,Vector3(0,.12,0),Vector3(.37,-.13,0),.10,"8b9892")
		torus(tool,Vector3.UP*.22,.091,.025,"9d845d")
static func bins(n: Node3D) -> void:
	table(n,3.15,.67)
	for i in range(4):
		var center:=Vector3((i-1.5)*.71,.84,0)
		G.cylinder(n,center,.24,.26,G.mat("a77e4c"),.33)
		torus(n,center+Vector3.UP*.115,.35,.032,"d1ab77")
		G.ball(n,center+Vector3.UP*.118,Vector3(.30,.09,.30),G.mat(["bbaf7e","ad8456","d9bc70","aa8c67"][i]))
		for j in range(24):
			var r:=.25*sqrt((j+.5)/24.);var phase:=j*2.399
			var pip:=G.ball(n,center+Vector3(cos(phase)*r,.212-r*.17,sin(phase)*r),Vector3(.033,.021,.052),G.mat("c7a675"))
			pip.rotation.y=phase
static func make(n: Node3D,kind: String) -> void:
	match kind:
		"jade_steam_table":A.mesh_part(n,kind,steamers)
		"jade_pastry_board":A.mesh_part(n,kind,pastries)
		"jade_smith_rack":A.mesh_part(n,kind,smith)
		"jade_seed_bins":A.mesh_part(n,kind,bins)
	var tall:=2.48 if kind=="jade_smith_rack" else 1.0
	P.box(n,"TradeGoods",Vector3.UP*tall*.5,Vector3(3.10,tall,1.04))
	if kind=="jade_steam_table":
		var steam:=MeshInstance3D.new()
		var card:=QuadMesh.new();card.size=Vector2(.95,1.37)
		steam.set_meta("appearance_effect",true);steam.mesh=card;steam.name="Steam";steam.position=Vector3(.2,2.01,.01)
		var mist:=ShaderMaterial.new();mist.shader=preload("res://assets/shaders/jade_steam.gdshader")
		steam.material_override=mist;steam.visibility_range_end=28.;steam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;n.add_child(steam)
