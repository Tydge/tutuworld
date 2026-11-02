extends SceneTree
const G=preload("res://scripts/geometry.gd")
const RADII:=Vector3(.73,.61,.66)
func _initialize() -> void: call_deferred("build")
func group(parent: Node3D,id: String,p:=Vector3.ZERO) -> Node3D:
	var n:=Node3D.new();n.name=id;n.position=p;parent.add_child(n);return n
func skin(region: int) -> ShaderMaterial:
	var m:=ShaderMaterial.new();m.shader=load("res://scripts/characters/panda_coat.gdshader");m.set_shader_parameter("region",region);return m
func muzzle(x: float,y: float) -> float:
	return .035*exp(-pow(x/.36,4)-pow((y+.22)/.22,4))
func deform(p: Vector3) -> Vector3:
	var v:=p*RADII
	v.z+=muzzle(v.x,v.y)*smoothstep(.10,.60,p.z)
	return v
func face(x: float,y: float,extra: float=.008) -> Vector3:
	return Vector3(x,y,RADII.z*sqrt(maxf(.02,1-pow(x/RADII.x,2)-pow(y/RADII.y,2)))+muzzle(x,y)+extra)
func head_mesh() -> ArrayMesh:
	var sphere:=SphereMesh.new();sphere.radius=1;sphere.height=2;sphere.radial_segments=64;sphere.rings=40
	var arrays:=sphere.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	for i in range(vertices.size()):
		var p:=vertices[i].normalized()
		var tangent:=p.cross(Vector3.UP).normalized()
		if tangent.length_squared()<.01: tangent=Vector3.RIGHT
		var other:=p.cross(tangent).normalized()
		var a:=deform((p+tangent*.001).normalized())-deform((p-tangent*.001).normalized())
		var b:=deform((p+other*.001).normalized())-deform((p-other*.001).normalized())
		var n:=a.cross(b).normalized()
		if n.dot(p)<0: n=-n
		vertices[i]=deform(p);normals[i]=n
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TANGENT]=null
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
func ball(parent: Node3D,p: Vector3,r: Vector3,m: Material,id: String,outline: bool=false) -> MeshInstance3D:
	var n:=G.ball(parent,p,r,m,id,outline);n.mesh.radial_segments=40;n.mesh.rings=24;return n
func eye_patch(parent: Node3D,center: Vector2,radii: Vector2,offset: float,material: Material,label_: String) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(4):
		for segment in range(40):
			var a0: float=segment*TAU/40;var a1: float=(segment+1)*TAU/40
			var r0: float=ring/4.0;var r1: float=(ring+1)/4.0
			var points: Array[Vector2]=[Vector2(cos(a0),sin(a0))*r0,Vector2(cos(a1),sin(a1))*r1,Vector2(cos(a0),sin(a0))*r1]
			if ring>0: points.append_array([Vector2(cos(a0),sin(a0))*r0,Vector2(cos(a1),sin(a1))*r0,Vector2(cos(a1),sin(a1))*r1])
			for point in points:
				var p:=center+point*radii
				var dx: float=(face(p.x+.001,p.y).z-face(p.x-.001,p.y).z)/.002
				var dy: float=(face(p.x,p.y+.001).z-face(p.x,p.y-.001).z)/.002
				st.set_normal(Vector3(-dx,-dy,1).normalized());st.set_uv(point*.5+Vector2.ONE*.5)
				st.add_vertex(face(p.x,p.y,offset)-parent.position)
	var patch:=G.mesh(parent,st.commit(),Vector3.ZERO,material,label_);patch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func own(node: Node,owner_: Node) -> void:
	for child in node.get_children(): child.owner=owner_;own(child,owner_)
func set_outlines(node: Node,material: Material) -> void:
	for mesh in node.find_children("InkOutline","MeshInstance3D",true,false):
		mesh.material_override=material
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func build() -> void:
	var panda:=CharacterBody3D.new();panda.name="Panda";panda.set_script(load("res://scripts/characters/animal_actor.gd"))
	panda.rig_profile=load("res://config/animals/panda.tres");panda.floor_snap_length=.35
	panda.collision_layer=2;panda.collision_mask=15
	var collision:=CollisionShape3D.new();collision.name="BodyCollision"
	var box:=BoxShape3D.new();box.size=Vector3(.76,1.90,.64);collision.shape=box;collision.position.y=.965;panda.add_child(collision)
	var visual:=group(panda,"Visual")
	var white:=skin(0);var black:=skin(3)
	ball(visual,Vector3(0,.82,0),Vector3(.42,.54,.33),skin(2),"Torso",true)
	var tail:=group(visual,"Tail",Vector3(0,.54,-.30));ball(tail,Vector3(0,0,-.045),Vector3.ONE*.12,white,"RoundTail",true)
	for side in [-1,1]:
		var arm:=group(visual,"LeftArm" if side<0 else "RightArm",Vector3(side*.445,1.09,0))
		G.capsule(arm,Vector3.ZERO,Vector3(side*.045,-.50,.04),.118,black,"StraightArm",true)
		var leg:=group(visual,"LeftLeg" if side<0 else "RightLeg",Vector3(side*.235,.43,0))
		G.capsule(leg,Vector3.ZERO,Vector3(0,-.29,.03),.14,black,"StraightLeg",true)
		if side>0: group(arm,"Cup").hide()
	var head:=group(visual,"Head",Vector3(0,1.74,0))
	var skull:=G.mesh(head,head_mesh(),Vector3.ZERO,skin(1),"PlushHead")
	var outline:=G.mesh(skull,skull.mesh,Vector3.ZERO,G.outline_mat(),"InkOutline");outline.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side in [-1,1]:
		var ear:=group(head,"LeftEar" if side<0 else "RightEar",Vector3(side*.60,.45,-.075));ear.rotation.z=side*.12
		ball(ear,Vector3(0,.045,0),Vector3(.19,.225,.135),black,"RoundEar",true)
	var eyes:=group(head,"Eyes",Vector3(0,.025,0))
	for side in [-1,1]:
		var x: float=side*.279
		eye_patch(eyes,Vector2(x,.025),Vector2(.071,.082),.002,G.mat("c8ccc8",.48),"EyeRim")
		eye_patch(eyes,Vector2(x+side*.006,.025),Vector2(.057,.071),.004,G.mat("11171d",.22),"Pupil")
		eye_patch(eyes,Vector2(x-.014,.050),Vector2(.010,.011),.006,G.mat("eceee4",.32),"Catchlight")
	ball(head,face(0,-.215,.012),Vector3(.105,.060,.032),G.mat("171d23",.43),"SoftNose")
	var mouth:=group(head,"Mouth",face(0,-.32,.012))
	var ink:=G.mat("3a3838")
	var points: Array[Vector3]=[Vector3(-.10,.005,0),Vector3(-.055,-.012,.006),Vector3(0,.003,.008),Vector3(.055,-.012,.006),Vector3(.10,.005,0)]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()-1):
		var line:=G.capsule(mouth,points[i],points[i+1],.009,ink)
		st.append_from(line.mesh,0,line.transform);mouth.remove_child(line);line.free()
	G.mesh(mouth,st.commit(),Vector3.ZERO,ink,"EmbroideredMouth")
	var mood:=G.text3d(panda,"",Vector3(0,3.25,0),80,Color("f2cc7d"));mood.name="Mood";mood.billboard=BaseMaterial3D.BILLBOARD_ENABLED;mood.no_depth_test=true
	var contour:=ShaderMaterial.new();contour.shader=load("res://scripts/characters/animal_outline.gdshader");set_outlines(panda,contour)
	own(panda,panda)
	var scene:=PackedScene.new();var error:=scene.pack(panda)
	if error!=OK: push_error("Panda packing failed");quit(1);return
	error=ResourceSaver.save(scene,"res://scenes/panda.tscn")
	panda.free()
	print("PANDA_MODEL_BUILT shared_controller=true clothing_baked=false status=",error);quit(0 if error==OK else 1)
