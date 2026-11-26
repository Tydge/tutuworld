extends "res://scripts/builders/scene_builder_base.gd"
var cat_head: Node3D
const Surface=preload("res://scripts/characters/cat_surface.gd")
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
# Ink is drawn just above the skin. Bake its outward normals from the same
# surface as the head so pigment follows the cheek when a light moves past.
func ink_triangle(st: SurfaceTool,pivot: Vector3,a: Vector2,b: Vector2,c: Vector2) -> void:
	var points: Array=[a,c,b] if (b-a).cross(c-a)>0. else [a,b,c]
	for point: Vector2 in points:
		var skin:=Surface.face_point(point)
		st.set_normal(head_normal(skin-Vector3.BACK*Surface.INK_OFFSET))
		st.add_vertex(skin-pivot)

func ribbon(st: SurfaceTool,pivot: Vector3,a: Vector2,b: Vector2,c: Vector2,width: float,edge_width: float=0.) -> void:
	var previous: Array[Vector2]=[]
	for i in range(25):
		var t:=i/24.
		var center:=a.lerp(b,t).lerp(b.lerp(c,t),t)
		var tangent: Vector2=(b-a).lerp(c-b,t).normalized()
		var normal:=Vector2(-tangent.y,tangent.x)
		var radius:=lerpf(edge_width,width,pow(maxf(0.,sin(t*PI)),.65))
		var pair: Array[Vector2]=[center-normal*radius,center+normal*radius]
		if not previous.is_empty():
			ink_triangle(st,pivot,previous[0],previous[1],pair[0])
			ink_triangle(st,pivot,pair[0],previous[1],pair[1])
		previous=pair

func ink_draw(parent: Node3D,st: SurfaceTool,color_: String) -> void:
	st.index()
	var ink:=G.mat(color_,.94).duplicate() as StandardMaterial3D
	ink.metallic_specular=.18
	var draw:=G.mesh(parent,st.commit(),Vector3.ZERO,ink,"Brushwork")
	draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# Use one drawing plane for the entire expression. The outlines, pupils and
# pigment share the same projection onto the cheeks, even at a grazing angle.
func eye_edge(t: float,side: float,upper: bool) -> Vector2:
	var a:=Surface.eye_corner(false);var b:=Surface.eye_corner(true)
	var ctrl:=Surface.drawing_point(245,226) if upper else Surface.drawing_point(255,278)
	var point:=a.lerp(ctrl,t).lerp(ctrl.lerp(b,t),t)
	point.x*=side
	return point

func face() -> void:
	var eyes:=group(cat_head,"Eyes",Vector3(0,-.118,0))
	var mouth:=group(cat_head,"Mouth",Surface.face_point(Surface.drawing_point(180,332)))
	var cheeks:=group(cat_head,"CheekMarkings")
	var eyes_st:=SurfaceTool.new();eyes_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mouth_st:=SurfaceTool.new();mouth_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lip_st:=SurfaceTool.new();lip_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var red_st:=SurfaceTool.new();red_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.,1.]:
		var a:=eye_edge(0,side,true);var b:=eye_edge(1,side,true)
		var upper:=Surface.drawing_point(245,226);upper.x*=side
		var lower:=Surface.drawing_point(255,278);lower.x*=side
		ribbon(eyes_st,eyes.position,a,upper,b,.009,.001)
		ribbon(eyes_st,eyes.position,a,lower,b,.004,.0006)
		for i in range(8):
			var t0:=.35+i*.038;var t1:=t0+.038
			var upper0:=eye_edge(t0,side,true);var lower0:=eye_edge(t0,side,false)
			var upper1:=eye_edge(t1,side,true);var lower1:=eye_edge(t1,side,false)
			ink_triangle(eyes_st,eyes.position,upper0,lower0,upper1)
			ink_triangle(eyes_st,eyes.position,upper1,lower0,lower1)
		# Five tapered strokes: three at the temple, two following the cheek.
		for mark in [[308,241,309,230,316,221, .011],[311,250,321,245,326,236,.013],[312,258,324,259,329,251,.013],[270,303,283,306,297,298,.013],[274,325,288,328,297,317,.012]]:
			var start:=Surface.drawing_point(mark[0],mark[1]);start.x*=side
			var mid:=Surface.drawing_point(mark[2],mark[3]);mid.x*=side
			var end:=Surface.drawing_point(mark[4],mark[5]);end.x*=side
			ribbon(red_st,Vector3.ZERO,start,mid,end,mark[6])
	# The lip and its outline share the same curved projection and bite pivot.
	var left:=Surface.drawing_point(165,328);var right:=Surface.drawing_point(200,327)
	var top:=Surface.drawing_point(181,318);var chin:=Surface.drawing_point(185,351)
	var fill_pivot:=mouth.position+Vector3.BACK*.0008
	for i in range(16):
		var t0:=i/16.;var t1:=(i+1)/16.
		var upper0:=left.lerp(top,t0).lerp(top.lerp(right,t0),t0)
		var upper1:=left.lerp(top,t1).lerp(top.lerp(right,t1),t1)
		var lower0:=left.lerp(chin,t0).lerp(chin.lerp(right,t0),t0)
		var lower1:=left.lerp(chin,t1).lerp(chin.lerp(right,t1),t1)
		ink_triangle(lip_st,fill_pivot,upper0,lower0,upper1)
		ink_triangle(lip_st,fill_pivot,upper1,lower0,lower1)
	ribbon(mouth_st,mouth.position,left,top,right,.004)
	ribbon(mouth_st,mouth.position,left,chin,right,.004)
	ink_draw(eyes,eyes_st,"3f3937")
	ink_draw(mouth,lip_st,"bc9486");ink_draw(mouth,mouth_st,"756561")
	ink_draw(cheeks,red_st,"ad7461")
	var nose:=group(cat_head,"Nose")
	var nose_st:=SurfaceTool.new();nose_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.,1.]:
		var start:=Surface.drawing_point(167,302);start.x*=side
		var mid:=Surface.drawing_point(173,305);mid.x*=side
		ribbon(nose_st,Vector3.ZERO,start,mid,Vector2(side*.002,Surface.drawing_point(179,312).y),.0048)
	ink_draw(nose,nose_st,"8e7871")

func head_normal(p: Vector3) -> Vector3:
	var h:=.001
	return Vector3(Surface.head_distance(p+Vector3(h,0,0))-Surface.head_distance(p-Vector3(h,0,0)),Surface.head_distance(p+Vector3(0,h,0))-Surface.head_distance(p-Vector3(0,h,0)),Surface.head_distance(p+Vector3(0,0,h))-Surface.head_distance(p-Vector3(0,0,h))).normalized()
# Only the tips need extra geometry for the thick outline in close-ups.
# Split an edge based on its endpoints so adjacent triangles always agree.
func tip_surface(p: Vector3) -> Vector3:
	return p-head_normal(p)*Surface.head_distance(p)

func head_triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	const TIP_LEVEL:=.70
	var high:=int(a.y>TIP_LEVEL)+int(b.y>TIP_LEVEL)+int(c.y>TIP_LEVEL)
	if high<2:
		emit_triangle(st,a,b,c)
		return
	if high==2:
		var corners: Array[Vector3]=[a,b,c]
		var low:=0 if a.y<=TIP_LEVEL else (1 if b.y<=TIP_LEVEL else 2)
		var edge_a:=corners[(low+1)%3]
		var edge_b:=corners[(low+2)%3]
		var midpoint:=tip_surface((edge_a+edge_b)*.5)
		emit_triangle(st,edge_a,midpoint,corners[low])
		emit_triangle(st,midpoint,edge_b,corners[low])
		return
	var ab:=tip_surface((a+b)*.5)
	var bc:=tip_surface((b+c)*.5)
	var ca:=tip_surface((c+a)*.5)
	emit_triangle(st,a,ab,ca)
	emit_triangle(st,b,bc,ab)
	emit_triangle(st,c,ca,bc)
	emit_triangle(st,ab,bc,ca)

func emit_triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	a=a.snapped(Vector3.ONE*.000001)
	b=b.snapped(Vector3.ONE*.000001)
	c=c.snapped(Vector3.ONE*.000001)
	if (b-a).cross(c-a).length_squared()<1e-22: return
	var normal:=head_normal((a+b+c)/3)
	var points: Array=[a,c,b] if (b-a).cross(c-a).dot(normal)>0 else [a,b,c]
	var radii:=Vector3(.70,.56,.63)
	for point in points:
		var normal_: Vector3=head_normal(point)
		# Continue the crown lighting across the ear root, as on a single fur surface.
		var root_weight:=smoothstep(.21,.34,point.y)*(1.-smoothstep(.44,.73,point.y))
		root_weight*=smoothstep(-.14,.035,Surface.skull_distance(point)-Surface.ear_distance(point))
		var h: float=(point.y-Surface.CENTER_Y)/Surface.HEIGHT_RADIUS
		var w:=Surface.half_width(h)
		var crown_normal:=Vector3(point.x/(w*w),h/Surface.HEIGHT_RADIUS,point.z/(Surface.DEPTH_RADIUS*Surface.DEPTH_RADIUS)).normalized()
		st.set_normal((normal_.lerp(crown_normal,root_weight).normalized()*radii).normalized())
		var ear_weight:=smoothstep(-.035,.035,Surface.skull_distance(point)-Surface.ear_distance(point))
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
			for x in range(nx): values[x+nx*(y+ny*z)]=Surface.head_distance(lower+Vector3(x,y,z)*step)
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
				if crossings>0:
					var point:=average/crossings
					cells[Vector3i(x,y,z)]=tip_surface(point) if point.y>.685 else point
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
	var coat:=ShaderMaterial.new();coat.shader=preload("res://scripts/characters/cat_head.gdshader")
	var head_surface:=G.mesh(cat_head,head_mesh,Vector3.ZERO,coat,"RoundCatHead")
	head_surface.scale=Vector3(.70,.56,.63)
	var hull:=G.mesh(head_surface,head_mesh,Vector3.ZERO,G.outline_mat(),"InkOutline")
	hull.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Keep semantic ear anchors for shared rig / clothing extensions.
	for side in [-1,1]: group(cat_head,"LeftEar" if side<0 else "RightEar",Vector3(side*.48,.60,-.04))
	face()
	var mood:=G.text3d(cat,"",Vector3(0,3.0,0),80,Color("f2cc7d"))
	mood.name="Mood"
	mood.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	mood.no_depth_test=true
	save_scene(cat,"res://scenes/cat_teacher.tscn")
	print("CAT_MODEL_BUILT shared_controller=true base_model_has_clothing=false")
	quit()
