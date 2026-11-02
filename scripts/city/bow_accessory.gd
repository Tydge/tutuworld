extends RefCounted
## A complete, softly padded bow mounted as one piece beside an ear.
const G=preload("res://scripts/geometry.gd")
const Fabric=preload("res://scripts/city/fabric_library.gd")
const SIZE_SCALE:=.8925 # Original revision size reduced by the requested fifteen percent.
static var ribbon_mesh: ArrayMesh
static func build(root: Node3D,rig: Resource,item: Dictionary) -> void:
	# Fit the whole accessory. Projecting individual vertices onto the skull/ear
	# changes the two loops into a draped strip, especially in a side view.
	var normal: Vector3=rig.bow_normal.normalized()
	var right:=Vector3.UP.cross(normal).normalized()
	root.basis=(Basis(right,normal.cross(right),normal)*Basis(Vector3.FORWARD,-rig.bow_tilt)).scaled_local(rig.headwear_scale*SIZE_SCALE)
	root.position=rig.bow_offset
	root.set_meta("bow_shape","volumetric_ribbon")
	G.mesh(root,mesh_for(),Vector3.ZERO,Fabric.material(item,"bow"),"BowRibbon")
static func wing(side: int,u: float,v: float,back: bool=false) -> Vector3:
	var half_height:=lerpf(.052,.225,pow(u,.78))
	var x:=.062+.405*u-.055*pow(absf(v),6)*smoothstep(.65,1.0,u)
	var y:=v*half_height
	var fullness:=pow(maxf(0,sin(u*PI)),.8)*(1-v*v)
	var crease:=cos(v*PI*2)*.010*(1-u)*sin(u*PI)
	var depth: float=-.018-fullness*.025 if back else .025+fullness*.085+crease
	return Vector3(side*x,y,depth)
static func knot_point(u: float,angle: float) -> Vector3:
	var y:=signf(sin(angle))*pow(absf(sin(angle)),.72)*.103*(1-.08*u*u)
	var z:=.028+signf(cos(angle))*pow(absf(cos(angle)),.72)*.085*(1-.08*u*u)
	return Vector3(u*.083,y,z)
static func triangle(st: SurfaceTool,points: Array[Vector3],uvs: Array[Vector2],outward: Vector3) -> void:
	# Godot front faces are clockwise. Keep both loops, their backs and the
	# rounded knot consistently lit instead of hiding reversed faces with culling.
	var order: Array=[0,1,2] if (points[1]-points[0]).cross(points[2]-points[0]).dot(outward)<0 else [0,2,1]
	for index in order:
		st.set_uv(uvs[index]);st.add_vertex(points[index])
static func quad(st: SurfaceTool,points: Array[Vector3],uvs: Array[Vector2],outward: Vector3) -> void:
	triangle(st,[points[0],points[1],points[2]],[uvs[0],uvs[1],uvs[2]],outward)
	triangle(st,[points[1],points[3],points[2]],[uvs[1],uvs[3],uvs[2]],outward)
static func mesh_for() -> ArrayMesh:
	if ribbon_mesh!=null: return ribbon_mesh
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners: Array[Vector2i]=[Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]
	for side in [-1,1]:
		for back in [false,true]:
			for row in range(20):
				for column in range(28):
					var points: Array[Vector3]=[];var uvs: Array[Vector2]=[]
					for corner in corners:
						var u: float=(column+corner.x)/28.0
						var v: float=(row+corner.y)/20.0*2-1
						points.append(wing(side,u,v,back))
						uvs.append(Vector2(side*(.062+.405*u)+.5,v*.24+.5))
					quad(st,points,uvs,Vector3(0,0,-1 if back else 1))
		# Closed, gently rounded fabric edges give the loops thickness in profile.
		for edge in range(4):
			var segments: int=28 if edge<2 else 20
			for segment in range(segments):
				var points: Array[Vector3]=[];var uvs: Array[Vector2]=[]
				for corner in corners:
					var t: float=float(segment+corner.x)/segments
					var u: float=t if edge<2 else float(edge-2)
					var v: float=float(edge*2-1) if edge<2 else t*2-1
					points.append(wing(side,u,v,corner.y==1));uvs.append(Vector2(u,v*.24+.5))
				var outward:=Vector3(0,-1 if edge==0 else 1,0) if edge<2 else Vector3(-side if edge==2 else side,0,0)
				quad(st,points,uvs,outward)
	# The center tie is rounded and closed, with a slight gathered waist.
	for row in range(40):
		for column in range(8):
			var points: Array[Vector3]=[];var uvs: Array[Vector2]=[]
			for corner in corners:
				var u: float=(column+corner.x)/8.0*2-1
				var angle: float=(row+corner.y)/40.0*TAU
				var point:=knot_point(u,angle)
				points.append(point);uvs.append(Vector2(u*.085+.5,point.y+.5))
			var middle: float=(row+.5)/40.0*TAU
			quad(st,points,uvs,Vector3(0,sin(middle),cos(middle)))
	for side in [-1,1]:
		for row in range(40):
			var a:=knot_point(side,row/40.0*TAU)
			var b:=knot_point(side,(row+1)/40.0*TAU)
			triangle(st,[Vector3(side*.083,0,.028),a,b],[Vector2(.5,.5),Vector2(.5+a.y,.5+a.z),Vector2(.5+b.y,.5+b.z)],Vector3(side,0,0))
	st.index();st.generate_normals()
	ribbon_mesh=st.commit()
	return ribbon_mesh
