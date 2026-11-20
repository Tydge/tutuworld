extends SceneTree
const Surface=preload("res://scripts/characters/cat_surface.gd")
# Intersect the baked mesh at cheek and forehead heights. Both sides of the
# profile should follow one ellipse without a bulge at the temple.
func smooth_profile(mesh: ArrayMesh,scale_: Vector3) -> bool:
	var faces:=mesh.get_faces()
	var front:=PackedFloat32Array();var back:=PackedFloat32Array()
	const SLICES:=31
	const LOW:=-.48
	const STEP:=.035
	front.resize(SLICES);back.resize(SLICES)
	front.fill(-INF);back.fill(INF)
	for i in range(0,faces.size(),3):
		for j in range(3):
			var a:=faces[i+j]*scale_;var b:=faces[i+(j+1)%3]*scale_
			if is_equal_approx(a.y,b.y):continue
			var start:=maxi(0,ceili((minf(a.y,b.y)-LOW)/STEP))
			var end:=mini(SLICES-1,floori((maxf(a.y,b.y)-LOW)/STEP))
			for k in range(start,end+1):
				var t: float=(LOW+k*STEP-a.y)/(b.y-a.y)
				var z:=lerpf(a.z,b.z,t)
				front[k]=maxf(front[k],z)
				back[k]=minf(back[k],z)
	var worst:=0.
	for k in range(SLICES):
		var h: float=(LOW+k*STEP-Surface.CENTER_Y)/Surface.HEIGHT_RADIUS
		var radius:=Surface.DEPTH_RADIUS*sqrt(1.-h*h)
		worst=maxf(worst,maxf(absf(front[k]-radius),absf(back[k]+radius)))
	print("CAT_PROFILE_MAX_ERROR_METERS ",worst)
	return worst<.006

func _initialize() -> void:
	var scene: PackedScene=load("res://scenes/cat_teacher.tscn")
	var cat:=scene.instantiate()
	var mesh_: ArrayMesh=cat.get_node("Visual/Head/RoundCatHead").mesh
	var arrays:=mesh_.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
	var welded: Dictionary={}
	var ids: Array[int]=[]
	for point in vertices:
		var p: Vector3=point*Vector3(.70,.56,.63)
		var key:=Vector3i(roundi(p.x*1000000),roundi(p.y*1000000),roundi(p.z*1000000))
		if not welded.has(key): welded[key]=welded.size()
		ids.append(welded[key])
	var edges: Dictionary={}
	var triangles:=0
	for i in range(0,indices.size(),3):
		var a: int=ids[indices[i]]
		var b: int=ids[indices[i+1]]
		var c: int=ids[indices[i+2]]
		if a==b or b==c or c==a: continue
		triangles+=1
		for pair in [[a,b],[b,c],[c,a]]:
			var key:=Vector2i(mini(pair[0],pair[1]),maxi(pair[0],pair[1]))
			edges[key]=edges.get(key,0)+1
	var open:=0
	var nonmanifold:=0
	for count_ in edges.values():
		if count_==1: open+=1
		elif count_!=2: nonmanifold+=1
	print("CAT_SURFACE vertices=",vertices.size()," triangles=",triangles," open_edges=",open," nonmanifold=",nonmanifold)
	var pure_ears:=true
	var ear_vertices:=0
	var skull_top: float=Surface.CENTER_Y+Surface.HEIGHT_RADIUS
	for i in range(vertices.size()):
		if vertices[i].y*.56>skull_top+.034:
			ear_vertices+=1
			pure_ears=pure_ears and colors[i].r>=.90
	pure_ears=pure_ears and ear_vertices>0
	print("CAT_EAR_PAINT_MASK ",pure_ears)
	var smooth:=smooth_profile(mesh_,cat.get_node("Visual/Head/RoundCatHead").scale)
	cat.free()
	quit(0 if open==0 and nonmanifold==0 and pure_ears and smooth else 1)
