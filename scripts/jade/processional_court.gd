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
		var podium: float=J.approach_height(tz)+terrace[2]+.04
		for bed: float in [-8.1,8.1]:
			builder.fixture(builder.world,"jade_peony",Vector3(curb+side*2.1,podium,tz+bed),PI*.5)
		var back:=tx+side*13.55
		for i in range(4):
			var pos:=J.point(back,tz-5.6+i*3.86)
			builder.fixture(builder.world,"jade_gallery",pos,PI*.50,3.848)
		var end:=tz-10.25
		for i in range(2):
			var pos:=J.point(tx+side*(2.2+i*4.1),end)
			builder.fixture(builder.world,"jade_gallery",pos,0.,4.088)
	for side in [-1.,1.]:
		for j in range(5):
			var a:=Vector2(side*(39.5+2.7*sin((j-.5)*.48)),-82.+(j-.5)*4.22)
			var b:=Vector2(side*(39.5+2.7*sin((j+.5)*.48)),-82.+(j+.5)*4.22)
			var center:=a.lerp(b,.5)
			var wall: Node3D=builder.fixture(builder.world,"jade_court_wall",J.point(center.x,center.y),-(b-a).angle())
			wall.scale.x=(a.distance_to(b)-.06)/4.65
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

# The collision ramp remains continuous. Clip only the visible soil beneath
# the treads and side stones so a coarse hillside triangle cannot cut across a riser.
static func trim_covered_earth(ground: MeshInstance3D) -> void:
	var origin:=Vector2(ground.position.x,ground.position.z)
	var bounds:=ground.mesh.get_aabb()
	var chunk:=Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))
	for row in J.FORECOURTS:
		var side:=signf(row[0])
		var curb: float=row[0]-side*9.7
		var foot: float=curb-side*5.82
		var cut:=Rect2(Vector2(minf(foot,curb),row[1]-2.62)-origin,Vector2(absf(curb-foot),5.24))
		if not chunk.intersects(cut):continue
		var planes: Array[Plane]=[Plane(Vector3.LEFT,-cut.position.x),Plane(Vector3.RIGHT,cut.end.x),Plane(Vector3.FORWARD,-cut.position.y),Plane(Vector3.BACK,cut.end.y)]
		var surface:=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var source:=ground.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array=source[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=source[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array=source[Mesh.ARRAY_INDEX]
		for i in range(0,indices.size(),3):
			var a:=vertices[indices[i]]
			var b:=vertices[indices[i+1]]
			var c:=vertices[indices[i+2]]
			var triangle:=Rect2(Vector2(a.x,a.z),Vector2.ZERO).expand(Vector2(b.x,b.z)).expand(Vector2(c.x,c.z))
			if not triangle.intersects(cut):
				for k in range(i,i+3):
					surface.set_normal(normals[indices[k]])
					surface.add_vertex(vertices[indices[k]])
				continue
			var remaining:=PackedVector3Array([a,b,c])
			for plane in planes:
				var outside:=Geometry3D.clip_polygon(remaining,-plane)
				for j in range(1,outside.size()-1):
					for v: Vector3 in [outside[0],outside[j],outside[j+1]]:
						var w:=Geometry3D.get_triangle_barycentric_coords(v,a,b,c)
						surface.set_normal((normals[indices[i]]*w.x+normals[indices[i+1]]*w.y+normals[indices[i+2]]*w.z).normalized())
						surface.add_vertex(v)
				remaining=Geometry3D.clip_polygon(remaining,plane)
				if remaining.size()<3:break
		surface.index()
		ground.mesh=surface.commit()

# A smaller edition fits a residential plot and uses the same stair geometry.
static func make_plot_terrace(module: Node3D) -> void:
	var origin:=A.group(module,"CarvedStone",Vector3(-4.34,1.68,0))
	origin.scale=Vector3.ONE*.60
	carve(origin,2.80)
	var face:=G.solid_box(origin,Vector3(10.05,-1.42,0),Vector3(20.12,2.70,23.0))
	face.collision_layer=8

static func stone_rail(parent: Node3D,center: Vector3,yaw: float) -> void:
	var rail:=A.group(parent,"CarvedRail",center)
	rail.rotation.y=yaw
	A.paint(rail,Vector3(0,.74,0),Vector3(.26,.16,3.57),"lotus_marble")
	A.paint(rail,Vector3(0,.29,0),Vector3(.20,.32,3.44),"stone_relief")
	for end: float in [-1.,1.]:
		var foot:=Vector3(0,0,end*1.67)
		A.paint(rail,foot+Vector3.UP*.46,Vector3(.37,.92,.37),"lotus_marble")
		G.cylinder(rail,foot+Vector3.UP*1.0,.24,.16,A.finish("lotus_marble"),.16)
		G.cylinder(rail,foot+Vector3.UP*1.14,.16,.16,A.finish("lotus_marble"),.035)
	for z: float in [-.86,0.,.86]:
		A.paint(rail,Vector3(0,.55,z),Vector3(.17,.32,.13),"lotus_marble")

static func carve(root: Node3D,rise: float) -> void:
	A.mesh_part(root,"forecourt_plinth_"+str(rise),func(m):
		A.paint(m,Vector3(10.05,-2.98,0),Vector3(20.14,5.92,23.02),"masonry")
		for i in range(10):
			for j in range(11):
				A.paint(m,Vector3((i+.5)*2.01,-.067,(j-5)*2.09),Vector3(2.002,.20,2.082),"lotus_marble" if i==0 else "masonry")
		for edge in [-1.,1.]:
			for j in range(5):
				var edge_z: float=edge*(3.37+j*1.81)
				A.paint(m,Vector3(.005,-.31,edge_z),Vector3(.46,.39,1.80),"stone_relief")
				A.paint(m,Vector3(-.045,.016,edge_z),Vector3(.65,.22,1.80),"lotus_marble")
			for panel: float in [4.85,8.42]:
				stone_rail(m,Vector3(.055,.12,edge*panel),0.)
			for panel: float in [2.1,5.67]:
				stone_rail(m,Vector3(panel,.12,edge*11.24),PI*.5)
			for course in range(5):
				for block in range(8):
					var x: float=.96+block*2.37+float(course%2)*.31
					A.paint(m,Vector3(x,-.45-course*.53,edge*11.53),Vector3(2.344,.513,.23),"masonry")
		var length_:=5.8
		var count:=16
		for i in range(count):
			var t:=float(i+1)/count
			var level: float=-rise*(1.-t)+.045
			var u: float=-length_+(i+.5)*length_/count
			# The white cap owns the tread. Bury the riser top inside it.
			var bottom:=-5.8
			var body_top: float=level-.07
			var run:=length_/count
			A.paint(m,Vector3(u,(body_top+bottom)*.5,0),Vector3(run,body_top-bottom,4.70),"masonry")
			A.paint(m,Vector3(u-.018,level-.045,0),Vector3(length_/count+.055,.09,4.77),"lotus_marble")
			for edge in [-1.,1.]:
				A.paint(m,Vector3(u,(level+bottom)*.5+.18,edge*2.49),Vector3(run,level-bottom+.22,.32),"stone_relief"))
	var platform:=G.solid_box(root,Vector3(10.05,-.12,0),Vector3(20.12,.30,23.0))
	platform.collision_layer=8
	var props:=preload("res://scripts/city/prop_collisions.gd")
	for edge: float in [-1.,1.]:
		props.box(root,"FrontBalustrade",Vector3(.055,.53,edge*6.64),Vector3(.31,.98,7.14))
		props.box(root,"ReturnBalustrade",Vector3(3.88,.53,edge*11.24),Vector3(7.13,.98,.31))
	var start:=Vector3(-5.8,-rise+.06,0)
	var end:=Vector3(0,.06,0)
	var delta:=end-start
	var ramp:=G.solid_box(root,(start+end)*.5-Vector3.UP*.09,Vector3(delta.length(),.18,4.86))
	ramp.rotation.z=atan2(delta.y,delta.x)
	ramp.collision_layer=8
