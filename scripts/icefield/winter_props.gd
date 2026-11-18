extends RefCounted
## Reusable local-space modules. Collision, anchors and catalog IDs survive batching.
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
static var materials: Dictionary={}
static func mat(id: String) -> Material:
	if materials.has(id):return materials[id]
	var m: Material
	match id:
		"snow":
			m=ShaderMaterial.new();m.shader=load("res://assets/shaders/polar_snow.gdshader");m.set_shader_parameter("snow_texture",load("res://assets/terrain/winter/powder_snow_v1.png"));m.set_shader_parameter("rock_texture",load("res://assets/terrain/soft_moss_rock_v1.png"))
		"wood","darkwood":
			m=ShaderMaterial.new();m.shader=load("res://assets/shaders/home_surface.gdshader");m.set_shader_parameter("tint",Color("866147" if id=="wood" else "453d3a"));m.set_shader_parameter("pattern",1)
		"glass":m=G.mat("638c8b",.30,.10)
		"gold":m=G.mat("ffc76d",.3,2.2)
		"ice":m=G.mat("bbdfed",.18)
		"pine":m=G.mat("244541",.9)
		_:m=G.mat(id)
	materials[id]=m;return m
static func group(parent: Node3D,id: String,p:=Vector3.ZERO) -> Node3D:
	var n:=Node3D.new();n.name=id;n.position=p;parent.add_child(n);return n
static func module(id: String) -> Node3D:
	var n:=Node3D.new();n.name="Winter_"+id;n.set_meta("buildable_reference",true);n.set_meta("winter_asset_id",id);n.set_meta("module_schema",1)
	return n
static func box(n: Node3D,p: Vector3,s: Vector3,id: String) -> MeshInstance3D:return G.box(n,p,s,mat(id))
static func cap_roof(n: Node3D,width_: float,depth: float,eave: float,rise: float) -> void:
	var half:=width_*.5;var length_:=sqrt(half*half+rise*rise)
	for side in [-1,1]:
		var panel:=box(n,Vector3(side*half*.5,eave+rise*.5,0),Vector3(length_+.16,.24,depth),"snow");panel.rotation.z=-side*atan2(rise,half)
		for i in range(15):
			var z: float=-depth*.5+.25+i*(depth-.5)/14.
			var icicle:=G.cylinder(n,Vector3(side*half,eave-.16-float(i%4)*.065,z),.045,.22+float(i%4)*.13,mat("ice"),0.006);icicle.rotation.z=PI;icicle.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
static func window(n: Node3D,p: Vector3,width_: float=1.3,height_: float=1.5) -> void:
	box(n,p,Vector3(width_+.22,height_+.22,.15),"darkwood")
	box(n,p+Vector3(0,0,.09),Vector3(width_,height_,.035),"glass")
	box(n,p+Vector3(0,0,.13),Vector3(.075,height_,.06),"wood")
	box(n,p+Vector3(0,0,.13),Vector3(width_,.065,.06),"wood")
	box(n,p+Vector3(0,-height_*.5-.1,.14),Vector3(width_+.38,.16,.4),"snow")
static func chalet(chapel: bool=false) -> Node3D:
	var n:=module("chapel" if chapel else "chalet")
	var width_:=10.8;var depth:=9.2;var eave:=5.5;var rise:=3.1
	box(n,Vector3(0,.35,0),Vector3(width_,.7,depth),"69757b")
	box(n,Vector3(0,2.9,0),Vector3(width_-.3,5.2,depth-.3),"wood")
	P.box(n,"BuildingShell",Vector3(0,3.1,0),Vector3(width_,6.2,depth))
	for y in [1.0,2.0,3.0,4.0,5.2]:box(n,Vector3(0,y,depth*.5),Vector3(width_,.10,.13),"darkwood")
	for x in [-4.8,0.,4.8]:box(n,Vector3(x,3.05,depth*.5+.08),Vector3(.20,4.8,.18),"darkwood")
	for x in [-3.3,3.3]:
		window(n,Vector3(x,2.1,depth*.5+.1));window(n,Vector3(x,4.25,depth*.5+.1),1.15,1.15)
	box(n,Vector3(0,1.6,depth*.5+.14),Vector3(1.6,2.5,.22),"darkwood")
	window(n,Vector3(0,2.05,depth*.5+.29),.75,.8)
	box(n,Vector3(0,.22,depth*.5+.8),Vector3(3.,.45,1.4),"69757b")
	box(n,Vector3(0,.48,depth*.5+.8),Vector3(3.1,.1,1.5),"snow")
	# Closed, correctly wound front/back triangular walls meet the roof underside.
	# The overhang extends the same slope outward, rather than lifting the whole
	# roof above the gable and leaving an open attic silhouette.
	var walls=preload("res://scripts/city/home_builder.gd").new()
	for side in [-1,1]:walls.triangle_prism(n,eave,side*depth*.5,width_,rise,.26,mat("wood"))
	var overhang:=.7
	cap_roof(n,width_+overhang*2.,depth+1.6,eave-overhang*rise/(width_*.5),rise*(width_+overhang*2.)/width_)
	window(n,Vector3(0,6.35,depth*.5+.06),1.3,1.15)
	for side in [-1,1]:
		var wall:=group(n,"SideWindows");wall.position=Vector3(side*width_*.5,0,0);wall.rotation.y=side*PI*.5
		for x in [-2.5,2.5]:window(wall,Vector3(x,2.35,.12),1.15,1.45);window(wall,Vector3(x,4.35,.12),.95,1.05)
		G.capsule(n,Vector3(side*(width_*.5+.62),eave+.1,-depth*.5-.7),Vector3(side*(width_*.5+.62),eave+.1,depth*.5+.7),.14,mat("snow"))
	# A snow-capped timber balcony breaks up the facade and catches warm window light.
	box(n,Vector3(0,3.29,5.1),Vector3(8.2,.18,1.2),"wood")
	box(n,Vector3(0,3.41,5.1),Vector3(8.25,.08,1.22),"snow")
	for x in [-3.8,-3.0,-2.2,-1.4,-.6,.6,1.4,2.2,3.0,3.8]:box(n,Vector3(x,3.8,5.65),Vector3(.08,.8,.1),"darkwood")
	box(n,Vector3(0,4.2,5.65),Vector3(8.2,.12,.16),"wood");box(n,Vector3(0,4.29,5.65),Vector3(8.25,.08,.23),"snow")
	box(n,Vector3(3.0,7.7,-2.2),Vector3(.9,2.3,1.0),"69757b")
	box(n,Vector3(3.0,8.9,-2.2),Vector3(1.15,.22,1.25),"snow")
	if chapel:
		box(n,Vector3(0,9.6,-1.7),Vector3(3.2,7.8,3.3),"69757b")
		for z in [-.02,-3.38]:
			var disc:=G.cylinder(n,Vector3(0,11.9,z),.87,.08,mat("glass"));disc.rotation.x=PI*.5
			box(n,Vector3(0,12.05,z+.07),Vector3(.055,.68,.08),"darkwood");box(n,Vector3(.2,11.9,z+.08),Vector3(.45,.055,.08),"darkwood")
		var spire:=G.cylinder(n,Vector3(0,15.5,-1.7),2.35,5.9,mat("snow"),.025);spire.mesh.radial_segments=4
		G.capsule(n,Vector3(0,18.3,-1.7),Vector3(0,19.6,-1.7),.055,mat("gold"))
		G.capsule(n,Vector3(-.38,19.2,-1.7),Vector3(.38,19.2,-1.7),.055,mat("gold"))
	merge(n);return n
static func pine() -> Node3D:
	var n:=module("snow_pine")
	var trunk:=G.cylinder(n,Vector3(0,3.5,0),.22,7.,mat("wood"),.09);trunk.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Lobed, drooping boughs with white upper faces; no alpha overdraw.
	var boughs:=SurfaceTool.new();boughs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier in range(11):
		var radius: float=3.0*pow(1.-tier/12.,.85);var y: float=1.1+tier*.73
		var branches:=8 if tier<7 else 6
		for j in range(branches):
			var angle: float=j*TAU/branches+tier*2.399
			var forward:=Vector3(cos(angle),0,sin(angle));var right:=Vector3(-sin(angle),0,cos(angle))
			var extent: float=radius*(1.+.13*sin(j*17.+tier*7.))
			var atlas: int=(j+tier)%4;var uv_origin:=Vector2(atlas%2,atlas/2)*.5
			for tilt in [-.52,.52]:
				for segment in range(3):
					for c in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
						var u: float=(segment+c.x)/3.;var v: float=c.y
						var p:=forward*(.05+u*extent)+right*(v-.5)*extent*.80
						p.y=y+.19-u*u*.64+(v-.5)*extent*tilt
						boughs.set_uv(uv_origin+Vector2(.012+u*.476,.015+v*.47));boughs.set_normal((Vector3.UP+forward*.15).normalized());boughs.add_vertex(p)
	var needles:=ShaderMaterial.new();needles.shader=load("res://assets/shaders/snow_fir.gdshader");needles.set_shader_parameter("bough_atlas",load("res://assets/terrain/winter/snow_fir_boughs_v1.png"))
	var foliage:=G.mesh(n,boughs.commit(),Vector3.ZERO,needles,"SnowNeedleBoughs");foliage.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shadow:=SurfaceTool.new();shadow.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier in range(7):
		var r: float=2.9*(1.-tier*.13);var y: float=1.0+tier*1.05
		for j in range(18):
			for c in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1)]:
				var a: float=(j+c.x)*TAU/18.+tier*.6;var radius: float=r*(1.+.13*sin(a*6.)) if c.y==0 else .015
				shadow.add_vertex(Vector3(cos(a)*radius,y+(1.9 if c.y==1 else 0.),sin(a)*radius))
	shadow.generate_normals();var proxy:=G.mesh(n,shadow.commit(),Vector3.ZERO,mat("pine"),"FixedFirShadow");proxy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	P.cylinder(n,"TrunkCollision",Vector3(0,2.5,0),.30,5.)
	merge(n);return n
static func snowman() -> Node3D:
	var n:=module("snowman")
	for row in [[.65,.68],[1.53,.49],[2.18,.35]]:G.ball(n,Vector3(0,row[0],0),Vector3.ONE*row[1],mat("snow"))
	for x in [-.12,.12]:G.ball(n,Vector3(x,2.24,.31),Vector3.ONE*.045,mat("darkwood"))
	var nose:=G.cylinder(n,Vector3(0,2.16,.43),.075,.31,mat("d98f48"),.008);nose.rotation.x=PI*.5
	G.cylinder(n,Vector3(0,2.49,0),.40,.07,mat("darkwood"));G.cylinder(n,Vector3(0,2.67,0),.27,.34,mat("darkwood"))
	for y in [1.4,1.65]:G.ball(n,Vector3(0,y,.46),Vector3.ONE*.045,mat("darkwood"))
	G.cylinder(n,Vector3(0,1.92,0),.39,.18,mat("a14c4b"));box(n,Vector3(.21,1.63,.44),Vector3(.18,.58,.08),"a14c4b")
	for side in [-1,1]:G.capsule(n,Vector3(side*.4,1.5,0),Vector3(side*1.0,1.9,.03),.035,mat("wood"))
	P.cylinder(n,"BodyCollision",Vector3(0,1.2,0),.68,2.4);merge(n);return n
static func sled() -> Node3D:
	var n:=module("sled")
	for x in [-.53,.53]:
		G.capsule(n,Vector3(x,.15,-1.1),Vector3(x,.15,.8),.045,mat("darkwood"))
		G.capsule(n,Vector3(x,.15,.8),Vector3(x,.48,1.15),.045,mat("darkwood"))
		for z in [-.6,.5]:G.capsule(n,Vector3(x,.18,z),Vector3(x,.56,z),.04,mat("darkwood"))
	for x in [-.4,-.2,0.,.2,.4]:box(n,Vector3(x,.58,0),Vector3(.17,.10,1.65),"wood")
	P.box(n,"SledCollision",Vector3(0,.32,0),Vector3(1.2,.65,2.3));merge(n);return n
static func bench() -> Node3D:
	var n:=module("snow_bench")
	for x in [-1.05,1.05]:
		for z in [-.32,.32]:box(n,Vector3(x,.4,z),Vector3(.13,.8,.13),"darkwood")
	for z in [-.32,-.11,.11,.32]:box(n,Vector3(0,.8,z),Vector3(2.7,.12,.19),"wood")
	for y in [1.16,1.42]:box(n,Vector3(0,y,-.43),Vector3(2.7,.20,.1),"wood")
	box(n,Vector3(0,1.57,-.43),Vector3(2.75,.09,.18),"snow")
	P.box(n,"BenchCollision",Vector3(0,.42,0),Vector3(2.75,.84,.92))
	group(n,"SeatAnchor",Vector3(0,.89,0));group(n,"ExitAnchor",Vector3(0,0,1.45));merge(n);return n
static func merge(n: Node3D) -> void:
	var groups: Dictionary={}
	for mesh_ in n.find_children("*","MeshInstance3D",true,false):
		if mesh_.get_child_count()>0:continue
		var m: Material=mesh_.material_override;var key: String=str(m.get_instance_id())+":"+str(mesh_.cast_shadow)
		if not groups.has(key):groups[key]={"st":SurfaceTool.new(),"material":m,"shadow":mesh_.cast_shadow};groups[key].st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var placement: Transform3D=mesh_.transform;var ancestor:=mesh_.get_parent()
		while ancestor!=n:placement=ancestor.transform*placement;ancestor=ancestor.get_parent()
		G.append_indexed(groups[key].st,mesh_.mesh,0,placement)
		mesh_.get_parent().remove_child(mesh_);mesh_.free()
	for entry in groups.values():
		entry.st.index()
		var mesh_:=G.mesh(n,entry.st.commit(),Vector3.ZERO,entry.material,"ModuleSurface");mesh_.cast_shadow=entry.shadow
