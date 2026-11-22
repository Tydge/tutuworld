extends RefCounted
const G=preload("res://scripts/geometry.gd")
const A=preload("res://scripts/jade/architecture.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
const J=preload("res://scripts/jade/layout.gd")
const NAMES={"jade_parasol":"海棠纸伞摊","jade_cart":"木轮南货车","jade_ceramics":"青花瓷货柜","jade_silk_rack":"蓝染晾绸架"}
static func make(n: Node3D,kind: String) -> void:
	A.mesh_part(n,kind,draw.bind(kind))
	if kind=="jade_parasol":P.cylinder(n,"Stand",Vector3.UP*.6,.34,1.2)
	if kind=="jade_cart":P.box(n,"Cart",Vector3.UP*.72,Vector3(1.95,1.44,1.24))
	if kind=="jade_ceramics":P.box(n,"Shelves",Vector3.UP*.84,Vector3(2.88,1.68,1.02))
	if kind=="jade_silk_rack":
		for x in [-1.54,1.54]:P.cylinder(n,"Support",Vector3(x,1.5,0),.09,3.)
static func porcelain(n: Node3D,p: Vector3,scale_: float,kind: int) -> void:
	var vessel:=A.group(n,"Porcelain",p);vessel.scale=Vector3.ONE*scale_
	var ivory:=G.mat("dfdfce",.38);var cobalt:=G.mat("526b81",.44)
	var profile: Array=[Vector2(.119,.005),Vector2(.14,.066),Vector2(.225,.22),Vector2(.237,.34),Vector2(.122,.43),Vector2(.094,.51),Vector2(.128,.55)]
	if kind==1:profile=[Vector2(.125,.006),Vector2(.153,.09),Vector2(.30,.18),Vector2(.34,.235),Vector2(.33,.25)]
	for i in range(profile.size()-1):
		var a: Vector2=profile[i];var b: Vector2=profile[i+1]
		G.cylinder(vessel,Vector3.UP*(a.y+b.y)*.5,a.x,b.y-a.y,ivory,b.x)
	for row in [profile[1],profile[profile.size()-2]]:
		G.cylinder(vessel,Vector3.UP*row.y,row.x+.007,.018,cobalt)
	if kind!=1:
		for j in range(9):
			var a:=j*TAU/9.;var pos:=Vector3(cos(a)*.23,.286,sin(a)*.23)
			for sign_ in [-1,1]:
				var leaf:=G.ball(vessel,pos+Vector3(-sin(a)*.017*sign_,.010,cos(a)*.017*sign_),Vector3(.014,.056,.023),cobalt);leaf.rotation.y=-a;leaf.rotation.z=sign_*.42
static func parasol(n: Node3D,p: Vector3,r: float,tint: String,tilt: float) -> void:
	var umbrella:=A.group(n,"PaperCanopy",p);umbrella.rotation.z=tilt
	G.cylinder(umbrella,Vector3.DOWN*.84,.035,1.67,G.mat("937246"))
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(24):
		var a:=k*TAU/24.;var b:=(k+1)*TAU/24.
		var edge:=Vector3(cos(a)*r,-.35*r,sin(a)*r);var next:=Vector3(cos(b)*r,-.35*r,sin(b)*r)
		var center:=Vector3.UP*r*.065
		var mid:=edge*.65+Vector3.UP*r*.094;var other:=next*.65+Vector3.UP*r*.094
		for v in [center,mid,other,mid,edge,next,mid,next,other]:
			st.set_uv(Vector2(v.x,v.z)/(2*r)+Vector2.ONE*.5);st.add_vertex(v)
		A.beam(umbrella,mid-Vector3.UP*.018,edge-Vector3.UP*.018,.018,"93734e")
	st.generate_normals();var skin:=StandardMaterial3D.new();skin.albedo_texture=preload("res://assets/jade/swallows.png");skin.albedo_color=Color(tint);skin.roughness=.85;skin.cull_mode=BaseMaterial3D.CULL_DISABLED
	G.mesh(umbrella,st.commit(),Vector3.ZERO,skin);G.cylinder(umbrella,Vector3.UP*(r*.065+.05),.068,.105,G.mat("725139"))
static func draw(m: Node3D,kind: String) -> void:
	match kind:
		"jade_parasol":
			G.cylinder(m,Vector3.UP*.43,.34,.86,G.mat("947857"),.48)
			for i in range(12):
				var a:=i*TAU/12.;A.beam(m,Vector3(cos(a)*.34,.03,sin(a)*.34),Vector3(cos(a)*.46,.86,sin(a)*.46),.032,"b99a68")
			parasol(m,Vector3(.23,2.42,.05),1.33,"dfb09d",.23)
			parasol(m,Vector3(-.55,1.77,.27),.83,"a1c1b1",-.48)
		"jade_cart":
			for side in [-1,1]:
				var wheel:=A.group(m,"Wheel",Vector3(0,.55,side*.69))
				var rim:=TorusMesh.new();rim.inner_radius=.48;rim.outer_radius=.57;rim.rings=20;rim.ring_segments=6
				G.mesh(wheel,rim,Vector3.ZERO,G.mat("544b39")).rotation.x=PI/2
				for j in range(6):
					var a:=j*PI/6.;A.beam(wheel,Vector3(cos(a),sin(a),0)*.50,-Vector3(cos(a),sin(a),0)*.50,.058,"87694b")
				A.beam(m,Vector3(-.94,.79,side*.52),Vector3(1.83,.76,side*.52),.12,"84684b")
			A.paint(m,Vector3.UP*.86,Vector3(1.97,.20,1.23),"lacquer")
			for j in range(6):
				var x: float=(j%3-1)*.52;var z: float=(-.28 if j<3 else .29)
				var mat_:=G.mat("b49d75" if j%2 else "8e8d67")
				G.ball(m,Vector3(x,1.22,z),Vector3(.26,.31,.23),mat_);G.cylinder(m,Vector3(x,1.51,z),.063,.09,G.mat("6c6148"),.10)
		"jade_ceramics":
			for x in [-1.34,1.34]:
				for z in [-.44,.44]:A.box(m,Vector3(x,.98,z),Vector3(.095,1.96,.095),"745239")
			for j in range(3):
				var y:=.32+j*.69;A.paint(m,Vector3(0,y,0),Vector3(2.90,.10,.98),"lacquer")
				for i in range(4):porcelain(m,Vector3((i-1.5)*.67,y+.055,-.08+.13*(i%2)),.73+.19*((i+j)%3),(i+j)%2)
		"jade_silk_rack":
			for x in [-1.54,1.54]:
				A.box(m,Vector3(x,1.54,0),Vector3(.13,3.08,.13),"7c6348");A.box(m,Vector3(x,.08,0),Vector3(.56,.16,.67),"817764")
			A.beam(m,Vector3(-1.72,3.01,0),Vector3(1.72,3.01,0),.08,"957a53")
			for i in range(4):
				var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
				for j in range(6):
					for k in range(5):
						for c in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
							var u: float=(k+c.x)/5.;var v: float=(j+c.y)/6.
							st.set_uv(Vector2(u,v));st.add_vertex(Vector3((i-1.5)*.74+(u-.5)*.68,2.96-v*(1.49+.13*(i%3)),.12*sin(u*9.)+.14*v*v*sin(u*4.+i)))
				st.generate_normals();G.mesh(m,st.commit(),Vector3.ZERO,A.finish("swallows" if i%2==1 else "brocade"))
static func dress(builder: SceneTree) -> void:
	for row in [["jade_cart",-8.,185.,-.2],["jade_parasol",6.,151.,-.54],["jade_ceramics",-8.7,138.,1.05],["jade_silk_rack",9.8,135.,.83],["jade_parasol",-7.4,120.5,.7],["jade_cart",6.1,94.,1.4],["jade_ceramics",8.8,85.,1.18],["jade_parasol",-7.9,77.,.62],["jade_silk_rack",-10.5,62.,-.91],["jade_cart",-7.4,41.,.47],["jade_parasol",11.,38.5,-.9]]:
		var z: float=row[2];builder.fixture(builder.world,row[0],J.point(J.lane(z)+row[1],z),row[3])
