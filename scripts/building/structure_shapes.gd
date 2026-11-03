extends RefCounted
## Shared real geometry for placement, catalog and committed structures.
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
static func arch_points(width_: float,height_: float) -> Array[Vector2]:
	var points: Array[Vector2]=[Vector2(-width_*.5,0),Vector2(width_*.5,0)]
	for i in range(25):
		var a:=i*PI/24.;points.append(Vector2(cos(a)*width_*.5,height_-width_*.5+sin(a)*width_*.5))
	return points
static func prism(n: Node3D,points: Array[Vector2],depth: float,material: Material,id: String) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.,1.]:
		for i in range(1,points.size()-1):
			var triangle: Array=[points[0],points[i+1],points[i]] if side>0 else [points[0],points[i],points[i+1]]
			for p in triangle:st.set_normal(Vector3(0,0,side));st.add_vertex(Vector3(p.x,p.y,side*depth*.5))
	for i in range(points.size()):
		var a:=points[i];var c:=points[(i+1)%points.size()];var normal:=Vector3(c.y-a.y,a.x-c.x,0).normalized()
		for vertex in [Vector3(a.x,a.y,-depth*.5),Vector3(c.x,c.y,depth*.5),Vector3(c.x,c.y,-depth*.5),Vector3(a.x,a.y,-depth*.5),Vector3(a.x,a.y,depth*.5),Vector3(c.x,c.y,depth*.5)]:st.set_normal(normal);st.add_vertex(vertex)
	G.mesh(n,st.commit(),Vector3.ZERO,material,id)
static func opening(b: RefCounted,n: Node3D,x: float,data: Dictionary) -> void:
	var w: float=data.width;var h: float=data.height;var bottom: float=b.floor_y+data.bottom;var form: String=data.get("form","classic");var trim: Material=b.material(data.get("color",b.blueprint.materials.trim),1)
	if form=="round":
		var ring:=TorusMesh.new();ring.inner_radius=.93;ring.outer_radius=1.08;ring.rings=48;ring.ring_segments=8
		var rim:=G.mesh(n,ring,Vector3(x,bottom+h*.5,0),trim,"PortholeFrame");rim.rotation.x=PI*.5;rim.scale=Vector3(w/2.1,1.,h/2.1)
		var glass:=G.mat("a8d2c6",.28);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.albedo_color.a=.20
		var pane:=G.cylinder(n,Vector3(x,bottom+h*.5,0),.96,.025,glass);pane.name="WindowGlass";pane.rotation.x=PI*.5;pane.scale=Vector3(w/2.1,1.,h/2.1);pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		G.capsule(n,Vector3(x-w*.45,bottom+h*.5,.03),Vector3(x+w*.45,bottom+h*.5,.03),.025,trim,"BrassCrossbar")
		G.capsule(n,Vector3(x,bottom+h*.05,.03),Vector3(x,bottom+h*.95,.03),.025,trim,"BrassMullion")
		return
	if form=="arch":
		var spring:=bottom+h-w*.5
		for side in [-1,1]:b.rounded(n,Vector3(x+side*(w*.5+.025),(bottom+spring)*.5,0),Vector3(.15,maxf(.05,spring-bottom),.42),.025,trim,"ArchJamb")
		for i in range(24):
			var a:=i*PI/24.;var c:=(i+1)*PI/24.
			G.capsule(n,Vector3(x+cos(a)*(w*.5+.025),spring+sin(a)*(w*.5+.025),0),Vector3(x+cos(c)*(w*.5+.025),spring+sin(c)*(w*.5+.025),0),.085,trim,"ArchCrown")
		if data.type=="window":
			b.rounded(n,Vector3(x,bottom-.025,0),Vector3(w+.25,.14,.55),.03,trim,"ArchSill")
			var glass:=G.mat("a9cfc1",.30);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.albedo_color.a=.18
			var pane: Node3D=b.group(n,"WindowGlass",Vector3(x,bottom,0));prism(pane,arch_points(w-.15,h-.08),.02,glass,"WindowPane")
			G.capsule(n,Vector3(x,bottom,.08),Vector3(x,bottom+h-.10,.08),.035,trim,"ArchMullion")
			for side in [-1,1]:G.capsule(n,Vector3(x,bottom+h*.52,.08),Vector3(x+side*w*.34,bottom+h*.77,.08),.025,trim,"Fanlight")
		return
	# French glass door keeps a clean rectangular outer frame.
	for side in [-1,1]:b.rounded(n,Vector3(x+side*(w*.5+.035),bottom+h*.5,0),Vector3(.14,h+.12,.42),.025,trim,"GlassDoorJamb")
	b.rounded(n,Vector3(x,bottom+h+.03,0),Vector3(w+.22,.16,.44),.025,trim,"GlassDoorLintel")
static func door(b: RefCounted,n: Node3D,form: String) -> void:
	b.root=n
	var opening: Dictionary=b.blueprint.walls[0].openings[0];var w: float=opening.width-.14;var h: float=opening.height-.05
	n.position.y=b.floor_y;var hinge: Node3D=b.group(n,"Hinge",Vector3(-w*.5,0,0));b.root.door_width=w;b.root.door_height=h
	var oak: Material=b.material("b58b62",1);var brass: Material=b.material("c6aa6a");var cream: Material=b.material("ece1c8")
	if form=="arch":
		var leaf: Node3D=b.group(hinge,"ArchedLeaf",Vector3(w*.5,0,0));prism(leaf,arch_points(w,h),.16,oak,"OakArch")
		for side in [-1,1]:
			for i in range(6):b.rounded(hinge,Vector3(.24+i*(w-.48)/5.,(h-w*.5)*.5,side*.09),Vector3(.025,h-w*.5-.24,.018),.005,brass,"FlutedDoor")
			var ring:=TorusMesh.new();ring.inner_radius=.22;ring.outer_radius=.27;ring.rings=24;ring.ring_segments=6
			var rose:=G.mesh(hinge,ring,Vector3(w*.5,h-.70,side*.10),cream,"CrownRosette");rose.rotation.x=PI*.5
	else:
		for x in [.10,w-.10]:b.rounded(hinge,Vector3(x,h*.5,0),Vector3(.20,h,.18),.035,oak,"FrenchStile")
		for y in [.10,h-.10,h*.34]:b.rounded(hinge,Vector3(w*.5,y,0),Vector3(w-.20,.20,.18),.035,oak,"FrenchRail")
		b.rounded(hinge,Vector3(w*.5,h*.18,0),Vector3(w-.30,h*.27,.14),.045,b.material("78988a"),"LowerPanel")
		var glass:=G.mat("b7d5c9",.26);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.albedo_color.a=.32
		b.block(hinge,Vector3(w*.5,h*.66,0),Vector3(w-.35,h*.58,.025),glass,"DoorGlass")
		for side in [-1,1]:
			b.block(hinge,Vector3(w*.5,h*.66,side*.055),Vector3(.045,h*.58,.035),cream,"GlazingBar")
			for y in [.52,.71,.88]:b.block(hinge,Vector3(w*.5,h*y,side*.055),Vector3(w-.30,.045,.035),cream,"GlazingBar")
	for side in [-1,1]:G.ball(hinge,Vector3(w-.36,h*.43,side*.17),Vector3.ONE*.075,brass,"DoorHandle")
	P.box(hinge,"LeafCollision",Vector3(w*.5,h*.5,0),Vector3(w,h,.20));P.box(n,"PortalCollision",Vector3(0,h*.5,0),Vector3(w,h,.24));b.group(n,"ActionAnchor",Vector3(0,.02,.15))
static func roof(b: RefCounted,n: Node3D,form: String) -> void:
	var w: float=b.blueprint.size[0];var d: float=b.blueprint.size[1];var y: float=b.floor_y+b.height;var roof: Material=b.material(b.blueprint.materials.roof,2);var trim: Material=b.material("e6dcc5");var rise:=1.8
	b.block(n,Vector3(0,y-.03,0),Vector3(w+.3,.16,d+.3),b.material("f0e4cf"),"Ceiling");P.box(n,"CeilingCollision",Vector3(0,y+.02,0),Vector3(w+.3,.14,d+.3))
	var a:=Vector3(-w*.5-.5,y,-d*.5-.5);var c:=Vector3(w*.5+.5,y,d*.5+.5);var faces: Array=[]
	if form=="hip":
		var ridge:=maxf(0.,(d-w)*.5);var front:=Vector3(0,y+rise,-ridge);var back:=Vector3(0,y+rise,ridge)
		faces=[[a,Vector3(c.x,y,a.z),front],[Vector3(c.x,y,a.z),c,back,front],[c,Vector3(a.x,y,c.z),back],[Vector3(a.x,y,c.z),a,front,back]]
		G.capsule(n,front,back+Vector3(0,0,.001),.10,trim,"HipRidge")
		for point in [a,Vector3(c.x,y,a.z)]:G.capsule(n,point,front,.07,trim,"HipSeam")
		for point in [c,Vector3(a.x,y,c.z)]:G.capsule(n,point,back,.07,trim,"HipSeam")
	else:
		var high:=1.5;var left:=Vector3(a.x,y+high,a.z);var left_back:=Vector3(a.x,y+high,c.z)
		faces=[[left,Vector3(c.x,y,a.z),c,left_back]]
		b.block(n,Vector3(a.x+.35,y+.65,0),Vector3(.22,1.30,d+.35),b.material("e6dcc5"),"HighFascia")
		for z in [a.z,c.z]:G.capsule(n,Vector3(a.x,y+high,z),Vector3(c.x,y,z),.10,trim,"MonoFascia")
		var glass:=G.mat("8bb8b3",.24);var skylight: MeshInstance3D=b.block(n,Vector3(0,y+.82,0),Vector3(w*.28,.07,d*.44),glass,"Skylight");skylight.rotation.z=-atan2(high,c.x-a.x)
		for z in [-d*.22,d*.22]:var rail: MeshInstance3D=b.block(n,Vector3(0,y+.88,z),Vector3(w*.28+.15,.08,.08),trim,"SkylightFrame");rail.rotation.z=skylight.rotation.z
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		for i in range(1,face.size()-1):
			for point in [face[0],face[i],face[i+1]]:st.add_vertex(point)
	st.generate_normals();var mesh:=G.mesh(n,st.commit(),Vector3.ZERO,roof,"FormRoof");mesh.material_override=roof
	for x in [a.x,c.x]:b.rounded(n,Vector3(x,y-.03,0),Vector3(.18,.24,d+1.15),.035,trim,"Eave")
