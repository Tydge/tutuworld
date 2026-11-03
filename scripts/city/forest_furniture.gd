extends RefCounted
# Furniture stays in separate module roots; meshes are baked only within each module.
static func build(b: RefCounted,n: Node3D,kind: String) -> void:
	var G=preload("res://scripts/geometry.gd")
	var P=preload("res://scripts/city/prop_collisions.gd")
	var F=preload("res://scripts/appearance/fabric_material.gd")
	var oak: Material=b.material("b58b54",1)
	var pale: Material=b.material("e5c994",1)
	match kind:
		"forest_settee":
			for x in [-1.4,1.4]:
				for z in [-.5,.5]: G.capsule(n,Vector3(x,.04,z),Vector3(x*.95,.65,z),.07,oak)
			b.rounded(n,Vector3(0,.58,0),Vector3(3.3,.18,1.45),.08,pale)
			for i in range(12): G.capsule(n,Vector3(-1.5+i*.27,.62,-.6),Vector3(-1.5+i*.27,1.46,-.6),.04,pale)
			G.capsule(n,Vector3(-1.65,1.50,-.6),Vector3(1.65,1.50,-.6),.085,oak)
			var fabric: Material=F.material({"color":"bf7f57","accent":"efd2a0","pattern":"solid"})
			for side in [-1,1]:
				b.rounded(n,Vector3(side*.76,.78,.06),Vector3(1.47,.28,1.25),.12,fabric)
				G.capsule(n,Vector3(side*1.64,1.02,-.6),Vector3(side*1.64,1.02,.60),.075,oak)
				var pillow=b.rounded(n,Vector3(side*1.13,1.13,-.29),Vector3(.63,.65,.23),.10,F.material({"color":"688d86","accent":"eddbac","pattern":"tartan","pattern_scale":5.0}));pillow.rotation.z=side*.2
			P.box(n,"SetteeCollision",Vector3(0,.72,0),Vector3(3.4,1.4,1.5))
			b.group(n,"SeatAnchor",Vector3(.15,.94,.20));b.group(n,"ExitAnchor",Vector3(.1,.20,1.5))
		"forest_tea_table":
			G.cylinder(n,Vector3(0,.64,0),1.12,.15,pale)
			for i in range(3):
				var p:=Vector3(cos(i*TAU/3)*.6,0,sin(i*TAU/3)*.6)
				G.capsule(n,p+Vector3(0,.04,0),p*.8+Vector3(0,.6,0),.08,oak)
			P.cylinder(n,"TableCollision",Vector3(0,.36,0),1.15,.72)
			G.ball(n,Vector3(.1,.86,.1),Vector3(.24,.17,.21),b.material("5b9388"))
			G.cylinder(n,Vector3(.1,1.04,.1),.14,.035,b.material("e7d5b2"));G.ball(n,Vector3(.1,1.08,.1),Vector3.ONE*.045,oak)
			G.capsule(n,Vector3(.27,.88,.1),Vector3(.44,.97,.1),.06,b.material("5b9388"))
			for x in [-.51,.54]:
				G.cylinder(n,Vector3(x,.74,-.35),.17,.035,b.material("f2ddb8"));G.cylinder(n,Vector3(x,.82,-.35),.105,.12,b.material("e6bd7d"));G.cylinder(n,Vector3(x,.887,-.35),.088,.009,b.material("84623e"))
			b.rounded(n,Vector3(-.4,.77,.47),Vector3(.58,.06,.38),.02,b.material("719376"),"FieldJournal")
		"forest_workbench":
			for x in [-1.05,1.05]:
				for z in [-.45,.45]: G.capsule(n,Vector3(x,.02,z),Vector3(x,1.04,z),.07,oak)
			b.rounded(n,Vector3(0,1.08,0),Vector3(2.55,.18,1.15),.05,pale)
			b.rounded(n,Vector3(0,.35,0),Vector3(2.3,.12,.95),.035,oak)
			for x in [-.72,0,.72]:
				b.rounded(n,Vector3(x,.62,0),Vector3(.56,.46,.70),.045,b.material("c69f6b",1))
				for i in range(4): b.block(n,Vector3(x-.20+i*.13,.63,.36),Vector3(.035,.36,.025),pale)
			b.pot(n,Vector3(.7,1.19,.13),.60)
			G.cylinder(n,Vector3(-.65,1.32,.0),.16,.25,b.material("d9b16f"),.19)
			for i in range(4): G.capsule(n,Vector3(-.65,1.32,0),Vector3(-.72+i*.05,1.72,sin(i)*.09),.012,b.material("6c8f62"))
			b.rounded(n,Vector3(-.1,1.19,.0),Vector3(.55,.025,.45),.01,b.material("eee1bc"))
			P.box(n,"BenchCollision",Vector3(0,.6,0),Vector3(2.65,1.2,1.15))
			var stool: Node3D=b.group(n,"Stool",Vector3(0,0,-1.25))
			G.cylinder(stool,Vector3(0,.62,0),.42,.15,b.material("7c9b84"))
			for i in range(3):
				var p:=Vector3(cos(i*TAU/3)*.27,0,sin(i*TAU/3)*.27);G.capsule(stool,p,p+Vector3(0,.58,0),.05,oak)
			P.cylinder(stool,"StoolCollision",Vector3(0,.35,0),.43,.7)
			b.group(n,"SeatAnchor",Vector3(0,.75,-1.25));b.group(n,"ExitAnchor",Vector3(-1.65,.20,-1.1))
		"forest_stove":
			var iron: Material=b.material("426b61")
			b.rounded(n,Vector3(0,.06,0),Vector3(1.8,.12,1.65),.06,b.material("a8ac95",3))
			for x in [-.43,.43]:
				for z in [-.32,.32]: G.capsule(n,Vector3(x,.12,z),Vector3(x,.5,z),.07,iron)
			b.rounded(n,Vector3(0,.85,0),Vector3(1.2,.98,.90),.12,iron)
			b.rounded(n,Vector3(0,.83,.465),Vector3(.83,.62,.05),.08,b.material("d3b26d"))
			b.block(n,Vector3(0,.83,.50),Vector3(.68,.49,.035),b.material("333d36"))
			var fire: Node3D=b.group(n,"FireWindow",Vector3(0,.48,.51));fire.scale=Vector3(.5,.42,.25);b.build_fire(fire)
			G.cylinder(n,Vector3(0,2.84,-.22),.15,3.0,iron)
			for y in [1.42,2.35,3.4]: G.cylinder(n,Vector3(0,y,-.22),.185,.08,b.material("c7ab71"))
			G.ball(n,Vector3(.48,.83,.57),Vector3(.04,.08,.04),oak)
			P.box(n,"StoveCollision",Vector3(0,.75,0),Vector3(1.4,1.5,1.15))
		"forest_cabinet":
			b.rounded(n,Vector3(0,.92,0),Vector3(1.55,1.84,.67),.05,pale)
			for y in [.36,.93,1.50]:
				for x in [-.37,.37]:
					b.rounded(n,Vector3(x,y,.36),Vector3(.67,.48,.06),.025,b.material("789a7d"))
					G.ball(n,Vector3(x,y,.405),Vector3.ONE*.035,b.material("d5ba70"))
			b.pot(n,Vector3(.4,1.87,0),.5)
			P.box(n,"CabinetCollision",Vector3(0,.92,0),Vector3(1.6,1.84,.75))
		"forest_rug":
			var rug: Material=F.material({"color":"d8ba80","accent":"6f9b80","pattern":"tartan","pattern_scale":1.8})
			G.cylinder(n,Vector3(0,.022,0),2.35,.035,rug)
			var ring:=TorusMesh.new();ring.inner_radius=2.18;ring.outer_radius=2.28;ring.rings=64;ring.ring_segments=8
			var part=G.mesh(n,ring,Vector3(0,.045,0),b.material("8fae8e"));part.scale.y=.10
		"forest_planter": b.pot(n,Vector3.ZERO,1.25)
