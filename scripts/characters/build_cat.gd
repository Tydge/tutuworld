extends "res://scripts/builders/scene_builder_base.gd"
var cat_head: Node3D
var cat_ink: Material
func _initialize() -> void: call_deferred("build_cat")
func cat_skin(region_: int) -> ShaderMaterial:
	var skin:=ShaderMaterial.new()
	skin.shader=load("res://scripts/characters/cat_coat.gdshader")
	skin.set_shader_parameter("region",region_)
	return skin
func shape(parent: Node3D,p: Vector3,size_: Vector3,material: Material,label_: String,outlined: bool=true) -> MeshInstance3D:
	var n:=G.ball(parent,p,size_,material,label_,outlined)
	n.mesh.radial_segments=48
	n.mesh.rings=24
	return n
func face_point(x: float,y: float,offset: float=.009) -> Vector3:
	return Vector3(x,y,.63*sqrt(maxf(.025,1-pow(x/.70,2)-pow(y/.56,2)))+offset)
func stroke(parent: Node3D,points: Array,radius: float,material: Material) -> void:
	for i in range(points.size()-1):
		var a: Vector2=points[i]
		var b: Vector2=points[i+1]
		var count:=maxi(2,int(a.distance_to(b)/.018))
		for k in range(count):
			var u:=float(k)/count
			var v:=float(k+1)/count
			var p: Vector2=a.lerp(b,u)
			var q: Vector2=a.lerp(b,v)
			G.capsule(parent,face_point(p.x,p.y)-parent.position,face_point(q.x,q.y)-parent.position,radius,material)
# A single closed surface avoids separate ear plates, exposed backfaces and seams.
func smooth_union(a: float,b: float,k: float) -> float:
	return preload("res://scripts/characters/cat_surface.gd").smooth_union(a,b,k)
func ear_distance(p: Vector3) -> float:
	return preload("res://scripts/characters/cat_surface.gd").ear_distance(p)
func skull_distance(p: Vector3) -> float:
	return preload("res://scripts/characters/cat_surface.gd").skull_distance(p)
func head_distance(p: Vector3) -> float:
	return preload("res://scripts/characters/cat_surface.gd").head_distance(p)
func head_normal(p: Vector3) -> Vector3:
	var h:=.001
	return Vector3(head_distance(p+Vector3(h,0,0))-head_distance(p-Vector3(h,0,0)),head_distance(p+Vector3(0,h,0))-head_distance(p-Vector3(0,h,0)),head_distance(p+Vector3(0,0,h))-head_distance(p-Vector3(0,0,h))).normalized()
func head_triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	a=a.snapped(Vector3.ONE*.000001)
	b=b.snapped(Vector3.ONE*.000001)
	c=c.snapped(Vector3.ONE*.000001)
	if (b-a).cross(c-a).length_squared()<1e-22: return
	var normal:=head_normal((a+b+c)/3)
	var points: Array=[a,c,b] if (b-a).cross(c-a).dot(normal)>0 else [a,b,c]
	var radii:=Vector3(.70,.56,.63)
	for point in points:
		st.set_normal((head_normal(point)*radii).normalized())
		var ear_weight:=smoothstep(-.035,.035,skull_distance(point)-ear_distance(point))
		st.set_color(Color(ear_weight,0,0,1))
		st.add_vertex(point/radii)
func surface_cross(a: Vector3,b: Vector3,da: float,db: float) -> Vector3:
	return a.lerp(b,da/(da-db))
func seamless_head_mesh() -> ArrayMesh:
	# Surface nets share one vertex per crossed cell. Every crossed grid edge
	# owns one quad, so the smooth ear roots cannot leave tiny triangle holes.
	var step:=.03
	var lower:=Vector3(-.843,-.637,-.739)
	var counts:=Vector3i(57,53,50)
	var nx:=counts.x+1
	var ny:=counts.y+1
	var values:=PackedFloat32Array()
	values.resize(nx*ny*(counts.z+1))
	for z in range(counts.z+1):
		for y in range(ny):
			for x in range(nx): values[x+nx*(y+ny*z)]=head_distance(lower+Vector3(x,y,z)*step)
	var offsets: Array[Vector3i]=[Vector3i(0,0,0),Vector3i(1,0,0),Vector3i(1,1,0),Vector3i(0,1,0),Vector3i(0,0,1),Vector3i(1,0,1),Vector3i(1,1,1),Vector3i(0,1,1)]
	var edges: Array=[[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]]
	var cells: Dictionary={}
	for z in range(counts.z):
		for y in range(counts.y):
			for x in range(counts.x):
				var distances: Array[float]=[]
				for offset in offsets:
					var q:=Vector3i(x,y,z)+offset
					distances.append(values[q.x+nx*(q.y+ny*q.z)])
				if distances.min()>0 or distances.max()<0: continue
				var average:=Vector3.ZERO
				var crossings:=0
				for edge in edges:
					if (distances[edge[0]]<0)==(distances[edge[1]]<0): continue
					var a:=lower+Vector3(Vector3i(x,y,z)+offsets[edge[0]])*step
					var b:=lower+Vector3(Vector3i(x,y,z)+offsets[edge[1]])*step
					average+=surface_cross(a,b,distances[edge[0]],distances[edge[1]])
					crossings+=1
				if crossings>0: cells[Vector3i(x,y,z)]=average/crossings
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(1,counts.z):
		for y in range(1,counts.y):
			for x in range(1,counts.x):
				var q:=Vector3i(x,y,z)
				var value: float=values[x+nx*(y+ny*z)]
				for axis in range(3):
					var offset: Vector3i=[Vector3i(1,0,0),Vector3i(0,1,0),Vector3i(0,0,1)][axis]
					var next:=q+offset
					if (value<0)==(values[next.x+nx*(next.y+ny*next.z)]<0): continue
					var neighbors: Array
					if axis==0: neighbors=[q+Vector3i(0,-1,-1),q+Vector3i(0,0,-1),q,q+Vector3i(0,-1,0)]
					elif axis==1: neighbors=[q+Vector3i(-1,0,-1),q+Vector3i(-1,0,0),q,q+Vector3i(0,0,-1)]
					else: neighbors=[q+Vector3i(-1,-1,0),q+Vector3i(0,-1,0),q,q+Vector3i(-1,0,0)]
					head_triangle(st,cells[neighbors[0]],cells[neighbors[1]],cells[neighbors[2]])
					head_triangle(st,cells[neighbors[0]],cells[neighbors[2]],cells[neighbors[3]])
	st.index()
	return st.commit()
func merge_marks(parent: Node3D) -> void:
	var groups: Dictionary={}
	for node in parent.get_children():
		if node is MeshInstance3D:
			var key: int=node.material_override.get_instance_id()
			if not groups.has(key): groups[key]={"material":node.material_override,"parts":[]}
			groups[key].parts.append({"mesh":node.mesh,"transform":node.transform})
			parent.remove_child(node)
			node.free()
	for entry in groups.values():
		var st:=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in entry.parts: st.append_from(part.mesh,0,part.transform)
		var combined:=G.mesh(parent,st.commit(),Vector3.ZERO,entry.material,"FaceMarks")
		combined.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func build_cat() -> void:
	var cat:=CharacterBody3D.new()
	cat.name="CatTeacher"
	cat.set_script(load("res://scripts/characters/animal_actor.gd"))
	cat.rig_profile=load("res://config/animals/cat_teacher.tres")
	cat.floor_snap_length=.35
	cat.collision_layer=2
	cat.collision_mask=5
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(.94,1.92,.86)
	collision.shape=box
	collision.position=Vector3(0,.975,0)
	cat.add_child(collision)
	var visual:=group(cat,"Visual")
	var white:=cat_skin(0)
	shape(visual,Vector3(0,.77,0),Vector3(.54,.57,.39),cat_skin(2),"Torso")
	var tail:=group(visual,"Tail",Vector3(0,.58,-.36))
	shape(tail,Vector3(0,0,-.055),Vector3.ONE*.14,white,"RoundTail",true)
	for side in [-1,1]:
		var arm:=group(visual,"LeftArm" if side<0 else "RightArm",Vector3(side*.53,1.03,0))
		G.capsule(arm,Vector3.ZERO,Vector3(side*.045,-.46,.025),.115,white,"Arm",true)
		var leg:=group(visual,"LeftLeg" if side<0 else "RightLeg",Vector3(side*.25,.40,0))
		G.capsule(leg,Vector3.ZERO,Vector3(0,-.24,.025),.14,white,"Leg",true)
		if side>0: group(arm,"Cup").hide()
	cat_head=group(visual,"Head",Vector3(0,1.62,.02))
	var head_mesh:=seamless_head_mesh()
	var head_surface:=G.mesh(cat_head,head_mesh,Vector3.ZERO,cat_skin(1),"RoundCatHead")
	head_surface.scale=Vector3(.70,.56,.63)
	var hull:=G.mesh(head_surface,head_mesh,Vector3.ZERO,G.outline_mat(),"InkOutline")
	hull.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Keep semantic ear anchors for shared rig / clothing extensions.
	for side in [-1,1]: group(cat_head,"LeftEar" if side<0 else "RightEar",Vector3(side*.48,.38,-.04))
	cat_ink=G.mat("383634")
	cat_ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var red:=G.mat("a36955")
	red.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var eyes:=group(cat_head,"Eyes")
	for side in [-1,1]:
		var x: float=side*.29
		var upper: Array=[]
		var lower: Array=[]
		for i in range(17):
			var t:=float(i)/16
			upper.append(Vector2(x-.18+t*.36,-.01+sin(t*PI)*.077))
			lower.append(Vector2(x-.18+t*.36,-.014-sin(t*PI)*.015))
		stroke(eyes,upper,.008,cat_ink)
		stroke(eyes,lower,.005,cat_ink)
		var pupil:=G.box(eyes,face_point(x,.025,.015),Vector3(.072,.080,.012),cat_ink,"NarrowPupil")
		pupil.rotation.y=side*.13
	merge_marks(eyes)
	var nose:=group(cat_head,"Nose")
	shape(nose,face_point(0,-.14),Vector3(.026,.020,.012),G.mat("a4827b"),"SmallNose",false)
	var mouth:=group(cat_head,"Mouth",face_point(0,-.205))
	stroke(mouth,[Vector2(0,-.17),Vector2(-.045,-.22),Vector2(-.095,-.235),Vector2(-.14,-.22)],.008,cat_ink)
	stroke(mouth,[Vector2(0,-.17),Vector2(.045,-.22),Vector2(.095,-.235),Vector2(.14,-.22)],.008,cat_ink)
	merge_marks(mouth)
	var markings:=group(cat_head,"CheekMarkings")
	for side in [-1,1]:
		for row in range(3):
			var x: float=side*(.43-row*.008)
			var y: float=-.12-row*.072
			stroke(markings,[Vector2(x-side*.025,y+.006),Vector2(x+side*.020,y-.003),Vector2(x+side*.057,y+.004)],.007,red)
		for i in range(3):
			var x: float=side*(.47+i*.035)
			stroke(markings,[Vector2(x,.105+i*.025),Vector2(x+side*.012,.13+i*.025)],.006,red)
	merge_marks(markings)
	var mood:=G.text3d(cat,"",Vector3(0,3.0,0),80,Color("f2cc7d"))
	mood.name="Mood"
	mood.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	mood.no_depth_test=true
	save_scene(cat,"res://scenes/cat_teacher.tscn")
	print("CAT_MODEL_BUILT shared_controller=true base_model_has_clothing=false")
	quit()
