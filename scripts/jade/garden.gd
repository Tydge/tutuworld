extends RefCounted
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
const J=preload("res://scripts/jade/layout.gd")
const NAMES={"jade_moon_gate":"粉墙月洞门","jade_market_stall":"布蓬货摊","jade_silk_stall":"锦缎布摊","jade_gallery":"园林折廊","jade_rockery":"太湖叠石","jade_pool":"曲水荷池","jade_quay":"石砌驳岸","jade_pier":"南津栈桥","jade_span":"白石桥面"}
static func make(n: Node3D,kind: String) -> void:
	var a=load("res://scripts/jade/architecture.gd")
	a.mesh_part(n,kind,draw_model.bind(kind))
	match kind:
		"jade_moon_gate":
			for side in [-1,1]:P.box(n,"GardenWall",Vector3(side*3.1,1.85,0),Vector3(2.3,3.7,.54))
		"jade_market_stall","jade_silk_stall":P.box(n,"Counter",Vector3(0,.52,0),Vector3(3.5,1.05,1.8))
		"jade_gallery":
			for x in [-2.,2.]:
				for z in [-1.3,1.3]:P.cylinder(n,"Post",Vector3(x,1.6,z),.14,3.2)
		"jade_rockery":P.cylinder(n,"Stone",Vector3.UP*.6,1.25,1.2)
		"jade_quay":P.box(n,"Quay",Vector3.UP*.96,Vector3(4.2,1.92,.8))
		"jade_span","jade_pier":G.solid_box(n,Vector3.DOWN*.09,Vector3(8.9,.2,3.02) if kind=="jade_span" else Vector3(4.2,.28,3.6)).collision_layer=8
static func draw_model(m: Node3D,kind: String) -> void:
	var a=load("res://scripts/jade/architecture.gd")
	match kind:
		"jade_moon_gate":
			for side in [-1,1]:
				for i in range(16):
					var y: float=(i+.5)*.2375
					var gap:=sqrt(maxf(0.,1.79*1.79-pow(y-1.65,2)))
					a.paint(m,Vector3(side*(4.2+gap)*.5,y,0),Vector3(4.2-gap,.239,.52),"lime")
				for k in range(17):
					var t: float=k*PI/17.;var u: float=(k+1)*PI/17.
					a.beam(m,Vector3(side*1.81*sin(t),1.65+1.81*cos(t),.30),Vector3(side*1.81*sin(u),1.65+1.81*cos(u),.30),.16,"8b8271")
			a.roof(m,4.55,.67,.45,3.82,false)
		"jade_market_stall","jade_silk_stall":
			for x in [-1.55,1.55]:
				for z in [-.82,.82]:a.box(m,Vector3(x,1.29,z),Vector3(.14,2.58,.15),"694634")
			a.paint(m,Vector3(0,.88,0),Vector3(3.5,.19,1.8),"lacquer")
			preload("res://scripts/jade/shopfront.gd").canvas(m,4.06,2.73,2.91,kind=="jade_silk_stall")
			for k in range(5):
				var x: float=(k-2)*.61
				if kind=="jade_silk_stall":
					var bolt:=G.cylinder(m,Vector3(x,1.2,0),.20,1.3,a.finish(["swallows","brocade"][k%2]));bolt.rotation.x=PI/2
				else:
					G.cylinder(m,Vector3(x,1.05,.02),.32,.16,G.mat("a57844"),.38)
					for j in range(6):G.ball(m,Vector3(x+cos(j)*.18,1.19+.035*(j%2),sin(j)*.18),Vector3(.14,.13,.13),G.mat(["ca8347","b95039","88a158","daa748","907057"][k]))
		"jade_gallery":
			for side in [-1,1]:
				var panel:=a.paint(m,Vector3(0,3.88,side*.88),Vector3(4.61,.16,2.04),"tiles") as MeshInstance3D;panel.rotation.x=side*.43
				var lining:=a.paint(m,Vector3(0,3.77,side*.88),Vector3(4.62,.11,2.02),"coffer") as MeshInstance3D;lining.rotation.x=side*.43
				for k in range(-6,7):a.beam(m,Vector3(k*.35,4.18,0),Vector3(k*.35,3.37,side*1.84),.10,"76583b")
			a.box(m,Vector3.UP*4.34,Vector3(4.62,.14,.19),"718079")
			a.paint(m,Vector3(0,.055,0),Vector3(4.5,.10,3.1),"masonry")
			for x in [-2.,2.]:
				for z in [-1.3,1.3]:G.cylinder(m,Vector3(x,1.7,z),.14,3.4,a.finish("lacquer"))
			a.paint(m,Vector3(0,3.18,1.32),Vector3(4.3,.32,.33),"polychrome")
		"jade_rockery":preload("res://scripts/jade/water_garden.gd").scholar_stones(m)
		"jade_pool":preload("res://scripts/jade/water_garden.gd").pond(m)
		"jade_quay":a.paint(m,Vector3(0,.96,0),Vector3(4.2,1.92,.8),"masonry")
		"jade_span":a.paint(m,Vector3.DOWN*.16,Vector3(8.9,.32,3.02),"masonry")
		"jade_pier":
			for j in range(8):a.box(m,Vector3(0,.04,j*.45-1.6),Vector3(4.2,.12,.44),"8d6849")
			for x in [-1.97,1.97]:
				for z in [-1.55,1.55]:G.cylinder(m,Vector3(x,-.1,z),.15,1.7,G.mat("71533f"))
static func dress(builder: SceneTree) -> void:
	for row in [[106,-19,"jade_moon_gate",.22],[123,-45,"jade_pool",0],[128,-44,"jade_rockery",.35],[119,-46,"jade_rockery",-.55],[114,-26,"jade_gallery",.75],[117,-29,"jade_gallery",.75],[119,-33,"jade_gallery",.23],[119,-37,"jade_gallery",-.15],[-116,-30,"jade_moon_gate",.45],[-119,-36,"jade_gallery",1.1],[-122,-38,"jade_gallery",1.1],[-118,-48,"jade_pool",0],[71,-143,"jade_moon_gate",-.4],[76,-149,"jade_pool",0],[79,-151,"jade_rockery",0],[-44,-151,"jade_pool",0],[-48,-151,"jade_rockery",0]]:
		builder.fixture(builder.world,row[2],J.point(row[0],row[1]),row[3])
	for row in [[-1,56],[1,63],[-1,83],[1,101],[-1,125],[1,141],[-1,157],[1,177]]:
		var z: float=row[1];var side: float=row[0];var x:=J.lane(z)+side*6.1
		builder.fixture(builder.world,"jade_silk_stall" if int(z)%3==0 else "jade_market_stall",J.point(x,z),-side*PI*.5+sin(z)*.17)
	for bx in J.BRIDGES:
		for side in [-1,1]:
			for j in range(-7,8):
				if absi(j)<2:continue
				var x: float=bx+j*4.1;var z: float=J.river_z(x)+side*12.5
				builder.fixture(builder.world,"jade_quay",Vector3(x,J.height_at(x,z)-1.75,z),-.13*cos(x*.015))
