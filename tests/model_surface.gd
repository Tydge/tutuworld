extends SceneTree
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
	for i in range(vertices.size()):
		if vertices[i].y>1.14: pure_ears=pure_ears and colors[i].r>=.90
	print("CAT_EAR_PAINT_MASK ",pure_ears)
	cat.free()
	quit(0 if open==0 and nonmanifold==0 and pure_ears else 1)
