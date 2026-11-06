extends RefCounted
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
static func build(b: RefCounted,n: Node3D,kind: String) -> void:
	var oak: Material=b.material("b58b62",1);var cream: Material=b.material("efe5cf");var brass: Material=b.material("c5a66a")
	match kind:
		"wall_botanical":
			b.rounded(n,Vector3(0,.525,.055),Vector3(1.2,1.05,.11),.035,oak)
			b.block(n,Vector3(0,.525,.116),Vector3(1.04,.89,.012),cream)
			for j in range(3):
				var x: float=(j-1)*.28;var stem: Material=b.material("739574")
				G.capsule(n,Vector3(x,.19,.13),Vector3(x+.05,.79+abs(j-1)*.06,.13),.009,stem)
				for i in range(3):
					var leaf:=G.ball(n,Vector3(x+(.055 if i%2==0 else -.045),.31+i*.17,.132),Vector3(.075,.115,.006),stem);leaf.rotation.z=.5 if i%2==0 else -.5
		"wall_clock":
			var rim:=G.cylinder(n,Vector3(0,.425,.085),.425,.14,oak);rim.rotation.x=PI*.5
			var face:=G.cylinder(n,Vector3(0,.425,.165),.365,.018,cream);face.rotation.x=PI*.5
			var ink: Material=b.material("526958")
			for i in range(12):
				var a:=i*TAU/12.;G.capsule(n,Vector3(sin(a)*.29,.425+cos(a)*.29,.183),Vector3(sin(a)*.32,.425+cos(a)*.32,.183),.009,ink)
			G.capsule(n,Vector3(0,.425,.193),Vector3(.15,.51,.193),.016,ink);G.capsule(n,Vector3(0,.425,.2),Vector3(-.04,.66,.2),.012,ink)
			G.ball(n,Vector3(0,.425,.207),Vector3(.025,.025,.01),ink)
		"wall_mirror":
			G.ball(n,Vector3(0,.9,.055),Vector3(.59,.89,.035),b.material("695b46"))
			var ring:=TorusMesh.new();ring.inner_radius=.94;ring.outer_radius=1.;ring.rings=48;ring.ring_segments=10
			var frame:=G.mesh(n,ring,Vector3(0,.9,.095),brass);frame.rotation.x=PI*.5;frame.scale=Vector3(.60,.60,.90)
			var shape:=QuadMesh.new();shape.size=Vector2(1.07,1.67)
			var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/planar_mirror.gdshader")
			var face:=G.mesh(n,shape,Vector3(0,.9,.105),mat,"MirrorFace");face.set_meta("dynamic_mesh",true);face.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;face.layers=1<<19
		"wall_sconce":
			b.rounded(n,Vector3(0,.32,.035),Vector3(.16,.49,.07),.035,brass)
			G.capsule(n,Vector3(0,.22,.05),Vector3(0,.22,.29),.025,brass);G.capsule(n,Vector3(0,.22,.29),Vector3(0,.50,.29),.025,brass)
			G.cylinder(n,Vector3(0,.64,.29),.25,.36,cream,.15);G.cylinder(n,Vector3(0,.45,.29),.08,.035,brass);b.bulb(n,Vector3(0,.48,.29),.065)
			var light:=OmniLight3D.new();light.name="FixtureLight";light.position=Vector3(0,.43,.29);light.light_color=Color("ffddb1");light.light_energy=.65;light.omni_range=4.8;light.shadow_enabled=true;n.add_child(light)
		"kitchen_cart":
			var dark: Material=b.material("667469")
			for x in [-.66,.66]:
				for z in [-.33,.33]:
					var wheel:=G.cylinder(n,Vector3(x,.12,z),.12,.07,dark);wheel.rotation.z=PI*.5
					b.rounded(n,Vector3(x,.66,z),Vector3(.09,.99,.09),.015,oak)
			for y in [.30,.72]:b.rounded(n,Vector3(0,y,0),Vector3(1.52,.08,.85),.025,oak)
			b.rounded(n,Vector3(0,1.14,0),Vector3(1.65,.12,.95),.035,b.material("d4b587",1))
			G.capsule(n,Vector3(.76,.94,-.3),Vector3(.76,.94,.3),.025,dark)
			P.box(n,"CartCollision",Vector3(0,.67,0),Vector3(1.60,1.06,.90))
		"spice_jars":
			b.rounded(n,Vector3(0,.025,0),Vector3(.9,.05,.48),.025,oak)
			for i in range(3):
				var x: float=(i-1)*.27;var h: float=[.27,.36,.24][i];var ceramic: Material=b.material("d3dfcd" if i==1 else "efe5cf")
				G.cylinder(n,Vector3(x,.06+h*.5,0),.11,h,ceramic,.105)
				G.cylinder(n,Vector3(x,h+.08,0),.12,.04,b.material("99794e",1));G.ball(n,Vector3(x,h+.12,0),Vector3(.028,.022,.028),b.material("99794e",1))
	if kind.begins_with("wall_"):
		var definition: Dictionary=preload("res://scripts/building/catalog.gd").OBJECTS[kind];P.box(n,"WallObjectCollision",Vector3(0,definition.height*.5,definition.offset.y),Vector3(definition.size.x,definition.height,definition.size.y))
