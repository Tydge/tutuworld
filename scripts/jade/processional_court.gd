extends RefCounted
## Two public terraces with side galleries frame the approach from the water gate.
const J=preload("res://scripts/jade/layout.gd")
const A=preload("res://scripts/jade/architecture.gd")
const G=preload("res://scripts/geometry.gd")
static func dress(builder: SceneTree) -> void:
	for terrace in J.FORECOURTS:
		var side: float=signf(terrace[0]);var tx: float=terrace[0];var tz: float=terrace[1]
		var curb:=tx-side*9.7
		stonework(builder,terrace)
		for shift in [-1.,1.]:
			var pos:=J.point(curb+side*.82,tz+shift*7.6)
			builder.fixture(builder.world,"jade_lamp",pos,side*PI*.5)
		var back:=tx+side*13.55
		for i in range(4):
			var pos:=J.point(back,tz-5.6+i*3.86)
			builder.fixture(builder.world,"jade_gallery",pos,PI*.50)
		var end:=tz-10.25
		for i in range(2):
			var pos:=J.point(tx+side*(2.2+i*4.1),end)
			builder.fixture(builder.world,"jade_gallery",pos)
	for side in [-1.,1.]:
		for j in range(5):
			var z: float=-82.+j*4.22;var x: float=side*(39.5+2.7*sin(j*.48))
			builder.fixture(builder.world,"jade_court_wall",J.point(x,z),PI*.47*side)
		for j in range(3):
			var pos:=J.point(side*(32.+j*3.7),-78.+.58*j)
			builder.fixture(builder.world,"jade_bamboo",pos)

# A continuous plinth closes all four faces. The stair and paved terrace share their top datum.
static func stonework(builder: SceneTree, row: Array) -> void:
	var side:=signf(row[0])
	var curb: float=row[0]-side*9.7
	var z: float=row[1]
	var top: float=J.approach_height(z)+row[2]
	var root:=A.group(builder.world,"ForecourtStone",Vector3(curb,top,z))
	if side<0.:root.rotation.y=PI
	carve(root,row[2])

# A smaller edition fits a residential plot and uses the same stair geometry.
static func make_plot_terrace(module: Node3D) -> void:
	var origin:=A.group(module,"CarvedStone",Vector3(-4.34,1.68,0))
	origin.scale=Vector3.ONE*.60
	carve(origin,2.80)
	var face:=G.solid_box(origin,Vector3(10.05,-1.42,0),Vector3(20.12,2.70,23.0))
	face.collision_layer=8

static func carve(root: Node3D,rise: float) -> void:
	A.mesh_part(root,"forecourt_plinth_"+str(rise),func(m):
		A.paint(m,Vector3(10.05,-2.98,0),Vector3(20.14,5.92,23.02),"masonry")
		for i in range(10):
			for j in range(11):
				A.paint(m,Vector3((i+.5)*2.01,-.067,(j-5)*2.09),Vector3(2.002,.20,2.082),"lotus_marble" if i==0 else "masonry")
		for edge in [-1.,1.]:
			for j in range(5):
				var edge_z: float=edge*(3.37+j*1.81)
				A.paint(m,Vector3(.005,-.31,edge_z),Vector3(.46,.39,1.813),"stone_relief")
				A.paint(m,Vector3(-.045,.016,edge_z),Vector3(.65,.22,1.815),"lotus_marble")
				if j%2==0:
					A.paint(m,Vector3(.055,.35,edge_z),Vector3(.46,.74,.46),"lotus_marble")
		var length_:=5.8
		var count:=16
		for i in range(count):
			var t:=float(i+1)/count
			var level: float=-rise*(1.-t)+.045
			var u: float=-length_+(i+.5)*length_/count
			var depth: float=5.8+level
			A.paint(m,Vector3(u,level-depth*.5,0),Vector3(length_/count+.008,depth,4.70),"masonry")
			A.paint(m,Vector3(u-.018,level-.045,0),Vector3(length_/count+.055,.09,4.77),"lotus_marble")
			for edge in [-1.,1.]:
				A.paint(m,Vector3(u,level-depth*.5+.18,edge*2.49),Vector3(length_/count+.01,depth+.22,.32),"stone_relief"))
	var platform:=G.solid_box(root,Vector3(10.05,-.12,0),Vector3(20.12,.30,23.0))
	platform.collision_layer=8
	var start:=Vector3(-5.8,-rise+.06,0)
	var end:=Vector3(0,.06,0)
	var delta:=end-start
	var ramp:=G.solid_box(root,(start+end)*.5-Vector3.UP*.09,Vector3(delta.length(),.18,4.86))
	ramp.rotation.z=atan2(delta.y,delta.x)
	ramp.collision_layer=8
