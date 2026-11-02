extends RefCounted
const G=preload("res://scripts/geometry.gd")
static func anchor(parent: Node3D,id: String,p: Vector3) -> Node3D:
	var node:=Node3D.new()
	node.name=id
	node.position=p
	parent.add_child(node)
	return node
static func build(world: Node3D,kitchen: Node3D) -> void:
	var wood:=G.mat("b88954")
	var cream:=G.mat("f3dfb8")
	var teal:=G.mat("648f87")
	var counter:=anchor(kitchen,"CookingCounter",Vector3(0,0,4.35))
	G.box(counter,Vector3(0,.50,0),Vector3(3.65,1.0,.92),teal)
	G.box(counter,Vector3(0,1.03,0),Vector3(3.85,.12,1.02),cream)
	for x in [-1.25,0,1.25]:
		G.box(counter,Vector3(x,.50,.47),Vector3(1.08,.72,.04),G.mat("719c8e"))
		G.capsule(counter,Vector3(x-.16,.77,.51),Vector3(x+.16,.77,.51),.022,wood)
	var stove:=G.cylinder(counter,Vector3(0,1.105,0),.46,.04,G.mat("4c625f"))
	stove.name="Stove"
	var burner:=TorusMesh.new()
	burner.inner_radius=.27
	burner.outer_radius=.35
	burner.rings=28
	burner.ring_segments=8
	G.mesh(counter,burner,Vector3(0,1.14,0),G.mat("d69251",.6,.18))
	var pot:=G.cylinder(counter,Vector3(0,1.30,0),.32,.31,G.mat("d49b6d"),.36)
	pot.name="CookingPot"
	G.cylinder(counter,Vector3(0,1.46,0),.31,.016,G.mat("d9a352"))
	for side in [-1,1]: G.capsule(counter,Vector3(side*.34,1.39,-.09),Vector3(side*.48,1.39,.09),.035,wood)
	G.cylinder(counter,Vector3(-1.2,1.17,0),.19,.20,G.mat("ebd4a2"))
	for i in range(3):
		G.capsule(counter,Vector3(-1.26+i*.065,1.21,0),Vector3(-1.30+i*.08,1.64,-.025),.016,wood)
		G.ball(counter,Vector3(-1.30+i*.08,1.64,-.025),Vector3(.034,.055,.018),wood)
	G.box(counter,Vector3(1.14,1.12,.02),Vector3(.75,.045,.58),wood)
	for i in range(3): G.ball(counter,Vector3(.97+i*.15,1.20,0),Vector3(.09,.06,.09),G.mat("d77b59" if i%2 else "a4bb65"))
	for i in range(3):
		G.cylinder(kitchen,Vector3(-1.0+i*.65,2.43,3.22),.13,.26,G.mat(["f1dcba","9ab586","d5a373"][i]))
	G.box(kitchen,Vector3(-.35,2.27,3.25),Vector3(2.4,.11,.40),wood)
	var chef:=anchor(kitchen,"KitchenEmblem",Vector3(0,4.50,3.16))
	for i in range(3): G.ball(chef,Vector3(-.20+i*.2,.12+(.10 if i==1 else 0),0),Vector3(.21,.18,.075),cream)
	G.box(chef,Vector3(0,-.08,0),Vector3(.55,.20,.12),cream)
	anchor(kitchen,"CookAnchor",Vector3(0,.10,5.65))
	anchor(kitchen,"PotSteam",Vector3(0,1.48,4.35))
	var table:=anchor(world,"DiningTable",Vector3(27.8,0,-20))
	G.cylinder(table,Vector3(0,.03,0),2.65,.10,G.mat("c9b995"))
	var floor_body:=StaticBody3D.new()
	floor_body.name="DiningFloor"
	floor_body.collision_layer=8
	floor_body.collision_mask=0
	floor_body.position.y=-.10
	var shape:=CollisionShape3D.new()
	var cylinder:=CylinderShape3D.new()
	cylinder.radius=2.65
	cylinder.height=.36
	shape.shape=cylinder
	floor_body.add_child(shape)
	table.add_child(floor_body)
	G.cylinder(table,Vector3(0,.98,0),1.05,.14,wood)
	G.cylinder(table,Vector3(0,.48,0),.18,.96,teal)
	for i in range(3):
		var a:=i*TAU/3
		G.capsule(table,Vector3.ZERO,Vector3(sin(a)*.66,.10,cos(a)*.66),.065,teal)
	var fabric:=ShaderMaterial.new()
	var shader:=Shader.new()
	shader.code="shader_type spatial; varying vec3 p; void vertex(){p=VERTEX;} void fragment(){float a=step(.5,fract(p.x*7.0));float b=step(.5,fract(p.z*7.0));ALBEDO=mix(vec3(.94,.87,.68),vec3(.50,.68,.58),(a+b)*.22);ROUGHNESS=.98;}"
	fabric.shader=shader
	G.box(table,Vector3(0,1.06,0),Vector3(.69,.014,1.98),fabric)
	for x in [-.62,.62]:
		G.capsule(table,Vector3(x,1.075,-.26),Vector3(x,1.075,.12),.016,G.mat("d9c286"))
		G.ball(table,Vector3(x,1.075,-.32),Vector3(.045,.015,.07),G.mat("d9c286"))
	G.cylinder(table,Vector3(-.48,1.18,-.45),.10,.24,G.mat("e2c195"))
	for i in range(3):
		G.capsule(table,Vector3(-.48,1.29,-.45),Vector3(-.48+sin(i*2)*.13,1.52,-.45+cos(i*2)*.1),.009,G.mat("799660"))
		G.ball(table,Vector3(-.48+sin(i*2)*.13,1.53,-.45+cos(i*2)*.1),Vector3(.07,.04,.07),G.mat("eeb28d" if i%2 else "eedba5"))
	var chair:=anchor(table,"DiningChair",Vector3(0,0,1.5))
	for x in [-.39,.39]:
		for z in [-.32,.32]: G.box(chair,Vector3(x,.32,z),Vector3(.10,.64,.10),wood)
	G.box(chair,Vector3(0,.65,0),Vector3(.95,.12,.86),wood)
	G.ball(chair,Vector3(0,.73,0),Vector3(.43,.055,.36),G.mat("d5a179"))
	for x in [-.39,.39]: G.box(chair,Vector3(x,.97,.36),Vector3(.10,.72,.10),wood)
	for y in [.95,1.17]: G.box(chair,Vector3(0,y,.36),Vector3(.88,.13,.10),wood)
	var seat:=anchor(table,"SeatAnchor",Vector3(0,.75,1.5))
	seat.rotation.y=PI
	anchor(table,"ExitAnchor",Vector3(2.1,.20,2.5))
	anchor(table,"MealAnchor",Vector3(0,1.075,.69))
	var sign:=anchor(table,"DiningSign",Vector3(1.75,0,.9))
	G.cylinder(sign,Vector3(0,.53,0),.045,1.06,wood)
	G.box(sign,Vector3(0,1.10,0),Vector3(1.15,.6,.08),cream)
	G.text3d(sign,"一起吃饭",Vector3(0,1.12,.055),21,Color("537d68"))
