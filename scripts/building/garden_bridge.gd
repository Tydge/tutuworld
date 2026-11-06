extends RefCounted
## Curved stone arch, timber walking deck and continuous physical railings.
const G=preload("res://scripts/geometry.gd")
const BASE:=.047
const RISE:=1.05
static func height_at(x: float,span: Rect2) -> float:return BASE+sin(clampf((x-span.position.x)/span.size.x,0.,1.)*PI)*RISE
static func quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	for p in [a,b,c,a,c,d]:st.set_uv(Vector2(p.x,p.z));st.add_vertex(p)
static func append_box(st: SurfaceTool,p: Vector3,size_: Vector3,tilt: float=0.) -> void:
	var box:=BoxMesh.new();box.size=size_;st.append_from(box,0,Transform3D(Basis(Vector3.BACK,tilt),p))
static func append_rod(st: SurfaceTool,a: Vector3,b: Vector3,radius: float) -> void:
	var cylinder:=CylinderMesh.new();cylinder.top_radius=radius;cylinder.bottom_radius=radius;cylinder.height=a.distance_to(b);cylinder.radial_segments=10
	var axis: Vector3=(b-a).normalized();var right:=axis.cross(Vector3.FORWARD).normalized()
	st.append_from(cylinder,0,Transform3D(Basis(right,axis,right.cross(axis)),(a+b)*.5))
static func finish(root: Node3D,st: SurfaceTool,material: Material,name_: String) -> ArrayMesh:
	var mesh:=st.commit();G.mesh(root,mesh,Vector3.ZERO,material,name_);return mesh
static func collision(root: Node3D,mesh: ArrayMesh,name_: String,layer: int,two_sided: bool=false) -> void:
	var body:=StaticBody3D.new();body.name=name_;body.collision_layer=layer;body.collision_mask=0;root.add_child(body)
	var shape:=ConcavePolygonShape3D.new();shape.set_faces(mesh.get_faces());shape.backface_collision=two_sided
	var part:=CollisionShape3D.new();part.shape=shape;body.add_child(part)
static func build(parent: Node3D,span: Rect2) -> Node3D:
	var root:=Node3D.new();root.name="GardenBridge";root.set_meta("module_type","public_bridge");parent.add_child(root)
	var top:=SurfaceTool.new();top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arch:=SurfaceTool.new();arch.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rails:=SurfaceTool.new();rails.begin(Mesh.PRIMITIVE_TRIANGLES)
	var timber:=SurfaceTool.new();timber.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone:=SurfaceTool.new();stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var metal:=SurfaceTool.new();metal.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass:=SurfaceTool.new();glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z: float=span.get_center().y;var half: float=span.size.y*.5
	var segments:=72
	for i in range(segments):
		var u: float=i/float(segments);var v: float=(i+1)/float(segments)
		var x0: float=span.position.x+span.size.x*u;var x1: float=span.position.x+span.size.x*v
		var y0:=height_at(x0,span);var y1:=height_at(x1,span)
		quad(top,Vector3(x0,y0,z-half),Vector3(x1,y1,z-half),Vector3(x1,y1,z+half),Vector3(x0,y0,z+half))
		var lower0: float=-1.45+sin(u*PI)*1.80;var lower1: float=-1.45+sin(v*PI)*1.80
		for side in [-1,1]:
			var edge: float=z+side*half
			quad(arch,Vector3(x0,y0-.11,edge),Vector3(x0,lower0,edge),Vector3(x1,lower1,edge),Vector3(x1,y1-.11,edge))
			quad(rails,Vector3(x0,y0,edge-side*.14),Vector3(x0,y0+1.15,edge-side*.14),Vector3(x1,y1+1.15,edge-side*.14),Vector3(x1,y1,edge-side*.14))
		quad(arch,Vector3(x0,lower0,z-half),Vector3(x1,lower1,z-half),Vector3(x1,lower1,z+half),Vector3(x0,lower0,z+half))
		var mid: float=(x0+x1)*.5;var h:=height_at(mid,span);var tilt:=atan2(y1-y0,x1-x0)
		append_box(timber,Vector3(mid,h-.075,z),Vector3((x1-x0)-.012,.15,span.size.y-.64),tilt)
		for side in [-1,1]:append_box(stone,Vector3(mid,h-.035,z+side*(half-.18)),Vector3(x1-x0+.012,.16,.36),tilt)
	for side in [-1,1]:
		var edge: float=z+side*(half-.20)
		for i in range(10):
			var x: float=span.position.x+.35+i*(span.size.x-.7)/9.;var h:=height_at(x,span)
			append_box(stone,Vector3(x,h+.45,edge),Vector3(.30,.90,.30))
			append_box(stone,Vector3(x,h+.96,edge),Vector3(.44,.14,.44))
		for i in range(24):
			var x0: float=span.position.x+i*span.size.x/24.;var x1: float=span.position.x+(i+1)*span.size.x/24.
			for offset in [.49,1.02]:append_rod(metal,Vector3(x0,height_at(x0,span)+offset,edge),Vector3(x1,height_at(x1,span)+offset,edge),.055 if offset>1. else .032)
		for x in [span.position.x+1.4,span.end.x-1.4]:
			var h:=height_at(x,span)
			append_box(metal,Vector3(x,h+1.22,edge),Vector3(.08,.55,.08))
			append_box(metal,Vector3(x,h+1.66,edge),Vector3(.36,.10,.36))
			append_box(metal,Vector3(x,h+1.42,edge),Vector3(.30,.07,.30))
			append_box(glass,Vector3(x,h+1.54,edge),Vector3(.23,.22,.23))
			var light:=OmniLight3D.new();light.name="BridgeLantern";light.position=Vector3(x,h+1.5,edge);light.light_color=Color("ffd39a");light.light_energy=.45;light.omni_range=4.;light.shadow_enabled=false;light.distance_fade_enabled=true;light.distance_fade_begin=28.;light.distance_fade_length=8.;root.add_child(light)
	top.generate_normals();var walking:=top.commit();collision(root,walking,"ConnectionCollision",8)
	arch.generate_normals();var arch_material:=G.mat("c4b69b").duplicate();arch_material.cull_mode=BaseMaterial3D.CULL_DISABLED;finish(root,arch,arch_material,"StoneArch")
	rails.generate_normals();collision(root,rails.commit(),"ContinuousRailCollision",4,true)
	finish(root,timber,G.mat("b58d62"),"TimberDeck");finish(root,stone,G.mat("eadcc0"),"StoneCopingAndPosts");finish(root,metal,G.mat("527767",.45),"ArchedHandrails");finish(root,glass,G.mat("ffe3a4",.4,.5),"WarmLanternGlass")
	return root
