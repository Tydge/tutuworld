extends RefCounted
## A folded ribbon, curved over the head instead of floating on one flat plane.
const G=preload("res://scripts/geometry.gd")
const Fabric=preload("res://scripts/city/fabric_library.gd")
const CatSurface=preload("res://scripts/characters/cat_surface.gd")
const SIZE_SCALE:=.8925 # Original revision size reduced by the requested fifteen percent.
static var meshes: Dictionary={}
static var ear_surfaces: Dictionary={}
static var surface_samples: Dictionary={}
static func build(root: Node3D,rig: Resource,item: Dictionary) -> void:
	root.position=Vector3(rig.bow_offset.x,rig.bow_offset.y+.06,0)
	root.set_meta("bow_shape","folded_ribbon")
	if not ear_surfaces.has(rig.species_id):
		var surfaces: Array=[]
		var head:=root.get_parent()
		for ear_name in ["LeftEar","RightEar"]:
			var ear:=head.get_node_or_null(ear_name)
			if ear==null: continue
			for part in ear.find_children("*","MeshInstance3D",true,false):
				if part.name=="InkOutline" or not part.mesh is SphereMesh: continue
				var transform_: Transform3D=ear.transform*part.transform
				surfaces.append({"inverse":transform_.affine_inverse(),"radius":part.mesh.radius})
		ear_surfaces[rig.species_id]=surfaces
	G.mesh(root,mesh_for(rig),Vector3.ZERO,Fabric.material(item,"bow"),"BowRibbon")
static func support_z(x: float,y: float,rig: Resource) -> float:
	var key:=str(rig.species_id)+":"+str(snappedf(x,.0001))+":"+str(snappedf(y,.0001))
	if surface_samples.has(key): return surface_samples[key]
	var z: float=rig.head_radii.z*sqrt(maxf(0,1-pow(x/rig.head_radii.x,2)-pow(y/rig.head_radii.y,2)))
	if rig.species_id=="cat_teacher" and CatSurface.head_distance(Vector3(x,y,0))<0:
		var lower:=0.0;var upper:=.72
		for i in range(13):
			var middle: float=(lower+upper)*.5
			if CatSurface.head_distance(Vector3(x,y,middle))<0: lower=middle
			else: upper=middle
		z=maxf(z,upper)
	for surface in ear_surfaces.get(rig.species_id,[]):
		var inverse: Transform3D=surface.inverse
		var origin: Vector3=inverse*Vector3(x,y,0)
		var direction: Vector3=inverse.basis*Vector3(0,0,1)
		var a: float=direction.length_squared()
		var b: float=2*origin.dot(direction)
		var c: float=origin.length_squared()-pow(float(surface.radius),2)
		var discriminant: float=b*b-4*a*c
		if discriminant>=0: z=maxf(z,(-b+sqrt(discriminant))/(2*a))
	surface_samples[key]=z
	return z
static func fit(point: Vector3,rig: Resource) -> Vector3:
	var offset:=Vector3(rig.bow_offset.x,rig.bow_offset.y+.06,0)
	var local: Vector3=Basis(Vector3.FORWARD,-rig.bow_tilt)*point*rig.headwear_scale*SIZE_SCALE
	var x: float=offset.x+local.x
	var y: float=offset.y+local.y
	var head_z: float=support_z(x,y,rig)
	# The lower edge sits on the head; the folds themselves have visible thickness.
	local.z=head_z+.018+maxf(0,local.z)
	return local
static func wing(side: int,u: float,v: float,back: bool=false) -> Vector3:
	var half_height:=lerpf(.052,.225,pow(u,.78))
	var x:=.062+.405*u-.024*pow(absf(v),6)*smoothstep(.65,1.0,u)
	var y:=v*half_height
	var fullness:=pow(maxf(0,sin(u*PI)),.8)*(1-v*v)*.082
	var crease:=cos(v*PI*2)*.012*(1-u)*sin(u*PI)
	return Vector3(side*x,y,.006 if back else .032+fullness+crease)
static func mesh_for(rig: Resource) -> ArrayMesh:
	var key:=str(rig.species_id)+str(rig.bow_offset)+str(rig.headwear_scale)+str(rig.head_radii)
	if meshes.has(key): return meshes[key]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1,1]:
		for back in [false,true]:
			for row in range(20):
				for column in range(28):
					for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
						var u: float=(column+corner.x)/28.0
						var v: float=(row+corner.y)/20.0*2-1
						st.set_uv(Vector2((side*(.062+.405*u)+.5),v*.24+.5))
						st.add_vertex(fit(wing(side,u,v,back),rig))
		# Sew each folded loop's visible outer edge to its back.
		for edge in range(4):
			for segment in range(28):
				for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
					var t: float=(segment+corner.x)/28.0
					var u: float=t if edge<2 else float(edge-2)
					var v: float=float(edge*2-1) if edge<2 else t*2-1
					st.set_uv(Vector2(u,v*.24+.5))
					st.add_vertex(fit(wing(side,u,v,corner.y==1),rig))
	# A softly squared wrap covers the pinched center, with a satin highlight.
	for row in range(40):
		for column in range(8):
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var u: float=(column+corner.x)/8.0*2-1
				var angle: float=(row+corner.y)/40.0*TAU
				var y:=signf(sin(angle))*pow(absf(sin(angle)),.52)*.103
				var z:=.058+signf(cos(angle))*pow(absf(cos(angle)),.52)*.052
				st.set_uv(Vector2(u*.085+.5,y+.5))
				st.add_vertex(fit(Vector3(u*.083,y,z),rig))
	st.index();st.generate_normals()
	var result:=st.commit();meshes[key]=result
	return result
