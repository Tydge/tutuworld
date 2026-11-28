extends RefCounted
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
const A=preload("res://scripts/jade/architecture.gd")
const RIM: Array[Vector2] = [Vector2(-.54,1),Vector2(.54,1),Vector2(1,.51),Vector2(1,-.51),Vector2(.54,-1),Vector2(-.54,-1),Vector2(-1,-.51),Vector2(-1,.51)]
static func side_wing(n: Node3D,w: float,h: float,d: float,floor_edge: float) -> void:
	var center:=Vector3(-w-1.95,0,-d*.42+.3);var size_:=Vector3(3.95,h*.79,d*1.16)
	var west:=n.get_node("West") as Node3D
	var wing:=A.group(n,"SideChamber",center)
	var shell:=A.group(west,"SideEaves")
	shell.transform=west.transform.affine_inverse()*wing.transform
	A.mesh_part(shell,"Annex"+str(w)+str(floor_edge),func(m):
		A.roof(m,size_.x*.5+.54,size_.z*.5+.76,1.56,size_.y,true)
		var inner: float=-w-floor_edge-center.x
		A.paint(m,Vector3((inner-size_.x*.5)*.5,-.09,0),Vector3(inner+size_.x*.5,.34,size_.z),"masonry")
		A.paint(m,Vector3(-size_.x*.5,size_.y*.5,0),Vector3(.24,size_.y,size_.z-.24),"lime")
		for side in [-1,1]:
			A.paint(m,Vector3(0,size_.y*.5,side*size_.z*.5),Vector3(size_.x,size_.y,.24),"lime")
			A.lattice(m,Vector3(0,size_.y*.56,side*size_.z*.5+.14),2.2,1.7)
			A.column(m,Vector3(-size_.x*.5,size_.y*.5,side*size_.z*.5),.19,size_.y))
	for side in [-1,1]:P.box(wing,"EndWall",Vector3(0,size_.y*.5,side*size_.z*.5),Vector3(size_.x,size_.y,.24))
	P.box(wing,"SideWall",Vector3(-size_.x*.5,size_.y*.5,0),Vector3(.24,size_.y,size_.z))
	G.solid_box(wing,Vector3.DOWN*.09,Vector3(size_.x,.34,size_.z)).collision_layer=8
static func octagon(n: Node3D,w: float,h: float,d: float) -> void:
	var exterior:=A.group(n,"Exterior")
	var walls: Dictionary={}
	for face in ["Front","West","East","Rear"]:walls[face]=A.group(n,face)
	var rim := RIM
	for i in range(8):
		var a: Vector2=rim[i]*Vector2(w,d);var b: Vector2=rim[(i+1)%8]*Vector2(w,d)
		var mid: Vector2=(a+b)*.5;var width:=a.distance_to(b);var front:=i==0
		var parent: Node3D=walls["Front" if front else ("Rear" if i in [3,4,5] else ("East" if i<3 else "West"))]
		var frame:=A.group(parent,"Bay",Vector3(mid.x,0,mid.y));frame.rotation.y=-(b-a).angle()
		A.mesh_part(frame,"TeaBay"+str(i)+str(w),func(m):
			A.column(m,Vector3(width*.5,h*.5,0),.19,h)
			if not front:
				A.paint(m,Vector3.UP*.57,Vector3(width,1.14,.25),"lime")
				A.lattice(m,Vector3(0,h*.67,0),width*.80,.99)
				A.box(m,Vector3.UP*1.19,Vector3(width+.06,.12,.39),"805439")
			A.paint(m,Vector3.UP*(h-.24),Vector3(width+.09,.48,.45),"polychrome"))
		if not front:P.box(frame,"Parapet",Vector3.UP*.57,Vector3(width,1.14,.25))
		P.cylinder(frame,"Column",Vector3(width*.5,h*.50,0),.19,h)
	A.mesh_part(exterior,"PavilionCanopy"+str(w),func(m): canopy(m,w,h,d))

static func canopy(m: Node3D,w: float,h: float,d: float) -> void:
	var sheet:=SurfaceTool.new();sheet.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(8):
		var a: Vector2=RIM[i]*(Vector2(w,d)+Vector2(1.35,1.35));var b: Vector2=RIM[(i+1)%8]*(Vector2(w,d)+Vector2(1.35,1.35))
		for j in range(6):
			for k in range(8):
				for uv in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
					var t: float=(j+uv.y)/6.;var v: float=(k+uv.x)/8.;var q:=a.lerp(b,v)*lerpf(.035,1.,t)
					var y:=h+3.7*pow(1.-t,1.55)+.74*pow(absf(2.*v-1.),3.)*t*t
					sheet.set_uv(Vector2((k+uv.x)*.32,t*4.5));sheet.add_vertex(Vector3(q.x,y,q.y))
		var edge:=Vector3(a.x,h+.74,a.y)
		A.beam(m,edge,edge+Vector3(a.x*.06,.43,a.y*.06),.116,"ba9b62")
	sheet.generate_normals();var roof_mesh:=sheet.commit()
	G.mesh(m,roof_mesh,Vector3.ZERO,A.finish("tiles"))
	var soffit:=A.finish("coffer");soffit.cull_mode=BaseMaterial3D.CULL_DISABLED;G.mesh(m,roof_mesh,Vector3.DOWN*.13,soffit)
	G.cylinder(m,Vector3.UP*(h+3.83),.24,.48,G.mat("bc9859"),.08)
