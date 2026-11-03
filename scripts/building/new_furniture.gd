extends RefCounted
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
const Fabric=preload("res://scripts/appearance/fabric_material.gd")
static func build(b: RefCounted,n: Node3D,kind: String) -> void:
	var oak: Material=b.material("b58b62",1);var cream: Material=b.material("ede2cb");var brass: Material=b.material("c5a66a");var sage: Material=b.material("7f9d88")
	match kind:
		"tea_service":
			G.ball(n,Vector3(0,.18,0),Vector3(.24,.17,.21),b.material("5b9388"));G.cylinder(n,Vector3(0,.36,0),.14,.035,cream);G.ball(n,Vector3(0,.40,0),Vector3.ONE*.045,oak)
			G.capsule(n,Vector3(.17,.20,0),Vector3(.34,.29,0),.06,b.material("5b9388"))
			for x in [-.34,.34]:G.cylinder(n,Vector3(x,.035,.25),.17,.035,cream);G.cylinder(n,Vector3(x,.12,.25),.105,.12,b.material("e6bd7d"));G.cylinder(n,Vector3(x,.185,.25),.088,.009,b.material("84623e"))
		"field_journal":
			b.rounded(n,Vector3(0,.055,0),Vector3(.58,.09,.42),.02,b.material("719376"),"FieldJournal");b.block(n,Vector3(0,.057,.02),Vector3(.52,.05,.38),cream,"Pages")
			b.block(n,Vector3(.16,.105,.02),Vector3(.025,.007,.40),brass,"Ribbon");G.capsule(n,Vector3(-.24,.115,-.13),Vector3(.15,.115,.18),.014,oak,"Pencil")
		"pressed_leaves":
			b.rounded(n,Vector3(0,.58,0),Vector3(.80,.98,.08),.035,b.material("b8925c"));b.block(n,Vector3(0,.58,.051),Vector3(.66,.84,.02),b.material("f0dfb4"))
			for j in range(3):
				var leaf:=G.ball(n,Vector3(sin(j*2.)*.12,.38+j*.18,.075),Vector3(.1,.14,.025),b.material("709a75"));leaf.rotation.z=j*.7
			for x in [-.25,.25]:G.capsule(n,Vector3(x,.08,-.22),Vector3(x,.60,-.04),.028,oak)
		"ceramic_vases":
			for i in range(3):
				var x: float=(i-1)*.27;var h: float=[.42,.65,.34][i];var m: Material=[cream,sage,b.material("c99a8b")][i]
				G.ball(n,Vector3(x,h*.34,0),Vector3(.14,h*.30,.14),m);G.cylinder(n,Vector3(x,h*.73,0),.07,h*.40,m,.095)
				var ring:=TorusMesh.new();ring.inner_radius=.065;ring.outer_radius=.085;ring.rings=16;ring.ring_segments=6;G.mesh(n,ring,Vector3(x,h*.94,0),brass)
			for i in range(3):G.capsule(n,Vector3(0,.5,0),Vector3(-.15+i*.16,.98+sin(i)*.08,0),.012,sage);G.ball(n,Vector3(-.15+i*.16,.98+sin(i)*.08,0),Vector3(.075,.05,.045),cream)
		"woven_basket":
			b.rounded(n,Vector3(0,.35,0),Vector3(.86,.65,.70),.12,oak)
			for y in [.10,.22,.34,.46,.58]:
				for side in [-1,1]:b.rounded(n,Vector3(0,y,side*.35),Vector3(.85,.028,.025),.008,cream)
			for side in [-1,1]:G.capsule(n,Vector3(side*.40,.52,-.20),Vector3(side*.40,.87,0),.035,oak);G.capsule(n,Vector3(side*.40,.87,0),Vector3(side*.40,.52,.20),.035,oak)
			var cloth: Material=Fabric.material({"color":"8fae9c","accent":"ede2cb","pattern":"stripes"})
			b.rounded(n,Vector3(.12,.66,.02),Vector3(.52,.11,.62),.05,cloth,"FoldedThrow");P.box(n,"BasketCollision",Vector3(0,.35,0),Vector3(.86,.70,.70))
		"moon_mobile":
			G.capsule(n,Vector3(0,1.35,0),Vector3(0,.85,0),.014,brass)
			for i in range(20):
				var a: float=-PI*.65+i*PI*1.3/19.;var c: float=-PI*.65+(i+1)*PI*1.3/19.
				G.capsule(n,Vector3(cos(a)*.36,.59+sin(a)*.36,0),Vector3(cos(c)*.36,.59+sin(c)*.36,0),.065,cream,"Crescent")
			for i in range(3):
				var x: float=(i-1)*.37;var y: float=.20+absf(x)*.6;G.capsule(n,Vector3(x,.78,0),Vector3(x,y,0),.008,brass)
				var star: MeshInstance3D=b.rounded(n,Vector3(x,y,0),Vector3(.13,.13,.055),.015,brass,"Star");star.rotation.z=PI*.25
		"petal_armchair":
			var cloth: Material=Fabric.material({"color":"c49b9b","accent":"f0e4ce","pattern":"solid"})
			for x in [-.54,.54]:
				for z in [-.48,.48]:b.rounded(n,Vector3(x,.22,z),Vector3(.12,.44,.12),.035,oak)
			b.rounded(n,Vector3(0,.64,.04),Vector3(1.48,.28,1.30),.14,cloth)
			for i in range(5):
				var x: float=(i-2)*.26;var h:=1.53+.17*cos((i-2)*.6)
				b.rounded(n,Vector3(x,1.13,-.51),Vector3(.37,h-.6,.27),.13,cloth,"PetalBack")
			for side in [-1,1]:b.rounded(n,Vector3(side*.66,.96,.02),Vector3(.23,.51,1.17),.11,cloth)
			b.rounded(n,Vector3(0,.83,.17),Vector3(1.12,.18,1.0),.09,cream,"SeatCushion");P.box(n,"ArmchairCollision",Vector3(0,.75,0),Vector3(1.50,1.45,1.35));b.group(n,"SeatAnchor",Vector3(0,.94,.21));b.group(n,"ExitAnchor",Vector3(0,.20,1.45))
		"floor_lamp":
			G.cylinder(n,Vector3(0,.07,0),.34,.14,brass);G.cylinder(n,Vector3(0,1.20,0),.035,2.3,brass)
			G.cylinder(n,Vector3(0,2.28,0),.43,.50,cream,.27)
			for i in range(16):var a:=i*TAU/16.;G.capsule(n,Vector3(cos(a)*.42,2.04,sin(a)*.42),Vector3(cos(a)*.27,2.52,sin(a)*.27),.012,brass)
			b.bulb(n,Vector3(0,2.13,0),.11);light(n,Vector3(0,2.08,0),1.8,7.);P.cylinder(n,"LampCollision",Vector3(0,.3,0),.34,.60)
		"lotus_pendant":
			G.cylinder(n,Vector3(0,1.01,0),.17,.07,brass);G.cylinder(n,Vector3(0,.75,0),.018,.5,brass)
			for i in range(8):
				var a:=i*TAU/8.;var petal:=G.ball(n,Vector3(cos(a)*.30,.39,sin(a)*.30),Vector3(.20,.33,.09),cream,"PorcelainPetal");petal.rotation=Vector3(0,-a+PI*.5,-.35)
			G.cylinder(n,Vector3(0,.18,0),.19,.08,brass);b.bulb(n,Vector3(0,.17,0),.13);light(n,Vector3(0,.12,0),2.8,8.)
		"canopy_bed","cloud_bed":
			var theme: String=b.blueprint.get("theme","forest");b.blueprint.theme="forest" if kind=="canopy_bed" else "coastal";b.build_bed(n);b.blueprint.theme=theme;b.discard(n.get_node("Bedside"))
			if kind=="canopy_bed":
				for x in [-1.30,1.30]:
					for z in [-2.17,2.17]:G.capsule(n,Vector3(x,.15,z),Vector3(x,3.15,z),.065,b.material("b18b61",1));G.ball(n,Vector3(x,3.22,z),Vector3.ONE*.11,brass);P.cylinder(n,"CanopyPostCollision",Vector3(x,1.65,z),.08,3.3)
				for x in [-1.30,1.30]:G.capsule(n,Vector3(x,3.15,-2.17),Vector3(x,3.15,2.17),.065,b.material("b18b61",1))
				for z in [-2.17,2.17]:G.capsule(n,Vector3(-1.30,3.15,z),Vector3(1.30,3.15,z),.065,b.material("b18b61",1))
				var fabric: Material=Fabric.material({"color":"e6d8ba","accent":"fff4dc","pattern":"sprig"})
				for side in [-1,1]:
					for fold in range(4):G.capsule(n,Vector3(side*(1.18-fold*.045),1.3,-2.05),Vector3(side*(1.17-fold*.065),3.13,-2.05),.075,fabric,"CanopyDrape")
			else:
				for child in n.get_children():
					if child is MeshInstance3D and child.position.z< -2.1 and child.position.y>.7:b.discard(child)
				var fabric: Material=Fabric.material({"color":"c59d9c","accent":"f1e3dc","pattern":"solid"})
				for i in range(5):b.rounded(n,Vector3((i-2)*.47,1.10,-2.13),Vector3(.58,1.18+.12*cos((i-2)*.65),.23),.18,fabric,"CloudHeadboard")
		"rose_arch":
			for side in [-1,1]:
				b.rounded(n,Vector3(side*1.53,1.45,0),Vector3(.18,2.9,.75),.045,cream)
				for y in [.35,.8,1.25,1.7,2.15,2.6]:b.block(n,Vector3(side*1.53,y,0),Vector3(.30,.055,.90),oak)
			for i in range(20):
				var a:=i*PI/20.;var c:=(i+1)*PI/20.;G.capsule(n,Vector3(cos(a)*1.53,2.45+sin(a)*.95,0),Vector3(cos(c)*1.53,2.45+sin(c)*.95,0),.10,cream)
			for side in [-1,1]:
				P.box(n,"ArchPost",Vector3(side*1.53,1.35,0),Vector3(.34,2.7,.9))
				for i in range(9):
					var p:=Vector3(side*(1.48+sin(i*1.8)*.15),.45+i*.32,sin(i)*.28);G.ball(n,p,Vector3(.21,.09,.15),sage)
					for petal in range(5):G.ball(n,p+Vector3(cos(petal*TAU/5.)*.09,.10,sin(petal*TAU/5.)*.09),Vector3(.09,.07,.08),b.material("dba6a3"))
		"lily_pond":
			var base:=G.cylinder(n,Vector3(0,.17,0),1.85,.32,b.material("b9b7a1"));base.scale.z=.78
			var ring:=TorusMesh.new();ring.inner_radius=1.56;ring.outer_radius=1.87;ring.rings=48;ring.ring_segments=8;var rim:=G.mesh(n,ring,Vector3(0,.33,0),cream,"PondRim");rim.scale=Vector3(1.,.55,.78)
			var water:=G.mat("71a59f",.24);var surface:=G.cylinder(n,Vector3(0,.32,0),1.62,.015,water);surface.scale.z=.78
			for i in range(6):
				var a:=i*2.4;var p:=Vector3(cos(a)*( .5+i*.12),.36,sin(a)*(.4+i*.10));G.cylinder(n,p,.22,.015,sage)
				if i%2==0:
					for j in range(7):G.ball(n,p+Vector3(cos(j*TAU/7.)*.10,.08,sin(j*TAU/7.)*.10),Vector3(.10,.12,.055),b.material("e6b6b4"))
			var body:=StaticBody3D.new();body.name="PondCollision";body.collision_layer=4;body.collision_mask=0
			var collision:=CollisionShape3D.new();var shape:=ConvexPolygonShape3D.new();var points:=PackedVector3Array()
			for y in [0.,.42]:
				for i in range(24):var a:=i*TAU/24.;points.append(Vector3(cos(a)*1.86,y,sin(a)*1.86*.78))
			shape.points=points;collision.shape=shape;body.add_child(collision);n.add_child(body)
	# Explicit authored groups also cover warm trim details with the primary finish.
	var A=preload("res://scripts/building/appearance.gd")
	for mesh in n.find_children("*","MeshInstance3D",true,false):
		if A.protected(mesh):continue
		var slot: String=A.parts(kind)[0].id;var color_: String=A.source_color(mesh.material_override)
		for part in A.parts(kind):
			if color_ in part.colors:slot=part.id;break
		mesh.set_meta("appearance_part",slot)
static func light(n: Node3D,p: Vector3,energy: float,range_: float) -> void:
	var lamp:=OmniLight3D.new();lamp.name="FixtureLight";lamp.position=p;lamp.light_color=Color("ffdfa8");lamp.light_energy=energy;lamp.omni_range=range_;lamp.omni_attenuation=1.5;lamp.shadow_enabled=true;n.add_child(lamp)
