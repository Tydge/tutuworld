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
		"clear_glass":
			m=StandardMaterial3D.new();m.albedo_color=Color("b3d6cf",.12)
			m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness=.28
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
	var sections:=group(n,"Sections")
	var front:=group(sections,"Front")
	var back:=group(sections,"Back")
	var roof:=group(sections,"Roof")
	var floor_mesh:=box(n,Vector3(0,.03,0),Vector3(width_,.18,depth),"wood")
	var floor_body:=G.solid_box(n,floor_mesh.position,Vector3(width_,.18,depth),"WalkFloor")
	floor_body.collision_layer=8;floor_body.collision_mask=0
	for side in [-1.,1.]:
		var wall:=group(sections,"West" if side<0 else "East")

		panel(front,Vector3(side*3.50,2.75,4.50),Vector3(3.80,5.5,.22))
		for y in [1.,2.,3.,4.,5.2]:
			box(front,Vector3(side*3.5,y,4.64),Vector3(3.8,.09,.12),"darkwood")
		box(front,Vector3(side*1.64,1.74,4.67),Vector3(.16,3.48,.30),"darkwood")
		window(front,Vector3(side*3.65,2.16,4.69))
		window(front,Vector3(side*3.65,4.3,4.69),1.15,1.05)
		var windows:=group(wall,"Windows",Vector3(side*5.28,0,0))
		windows.rotation.y=side*PI*.5
		# Openings match the buildable windows. Shared timber and a single clear
		# pane per opening keep the whole village inexpensive from the frozen lake.
		panel(windows,Vector3(0,.72,0),Vector3(depth,1.44,.24))
		panel(windows,Vector3(0,4.37,0),Vector3(depth,2.26,.24))
		for span in [[-3.98,1.24],[0.,3.28],[3.98,1.24]]:
			panel(windows,Vector3(span[0],2.34,0),Vector3(span[1],1.8,.24))
		for x in [-2.50,2.50]:
			for jamb in [-.86,.86]:
				box(windows,Vector3(x+jamb,2.34,0),Vector3(.13,1.90,.34),"wood")
			box(windows,Vector3(x,3.24,0),Vector3(1.92,.15,.36),"wood")
			box(windows,Vector3(x,1.44,0),Vector3(2.04,.14,.50),"wood")
			box(windows,Vector3(x,2.34,0),Vector3(.065,1.8,.14),"wood")
			box(windows,Vector3(x,2.43,0),Vector3(1.72,.065,.14),"wood")
			var pane:=box(windows,Vector3(x,2.34,0),Vector3(1.66,1.74,.012),"clear_glass")
			pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel(front,Vector3(0,4.50,4.50),Vector3(3.2,2.,.22))
	panel(back,Vector3(0,2.75,-4.50),Vector3(width_,5.5,.22))
	box(back,Vector3(0,3.22,-4.37),Vector3(10.48,4.36,.05),"ece0c7")
	for y in [.26,1.13,4.94]:
		box(back,Vector3(0,y,-4.31),Vector3(10.6,.14,.14),"wood")
	for x in [-5.09,-1.75,1.75,5.09]:
		box(back,Vector3(x,3.12,-4.32),Vector3(.13,3.74,.14),"wood")
	box(front,Vector3(0,3.79,5.69),Vector3(3.4,.52,.14),"darkwood")
	box(front,Vector3(0,3.55,4.67),Vector3(3.44,.18,.32),"darkwood")
	group(n,"Entrance",Vector3(0,.12,5.35))
	# Closed, correctly wound front/back triangular walls meet the roof underside.
	# The overhang extends the same slope outward, rather than lifting the whole
	# roof above the gable and leaving an open attic silhouette.
	var walls=preload("res://scripts/city/home_builder.gd").new()
	for side in [-1,1]:walls.triangle_prism(roof,eave,side*depth*.5,width_,rise,.26,mat("wood"))
	var overhang:=.7
	cap_roof(roof,width_+overhang*2.,depth+1.6,eave-overhang*rise/(width_*.5),rise*(width_+overhang*2.)/width_)
	window(roof,Vector3(0,6.35,depth*.5+.06),1.3,1.15)
	# A snow-capped timber balcony breaks up the facade and catches warm window light.
	box(front,Vector3(0,3.29,5.1),Vector3(8.2,.18,1.2),"wood")
	box(front,Vector3(0,3.41,5.1),Vector3(8.25,.08,1.22),"snow")
	for x in [-3.8,-3.0,-2.2,-1.4,-.6,.6,1.4,2.2,3.0,3.8]:box(front,Vector3(x,3.8,5.65),Vector3(.08,.8,.1),"darkwood")
	box(front,Vector3(0,4.2,5.65),Vector3(8.2,.12,.16),"wood");box(front,Vector3(0,4.29,5.65),Vector3(8.25,.08,.23),"snow")
	box(roof,Vector3(3.0,7.7,-2.2),Vector3(.9,2.3,1.0),"69757b")
	box(roof,Vector3(3.0,8.9,-2.2),Vector3(1.15,.22,1.25),"snow")
	if chapel:
		box(roof,Vector3(0,9.6,-1.7),Vector3(3.2,7.8,3.3),"69757b")
		for z in [-.02,-3.38]:
			var disc:=G.cylinder(roof,Vector3(0,11.9,z),.87,.08,mat("glass"));disc.rotation.x=PI*.5
			box(roof,Vector3(0,12.05,z+.07),Vector3(.055,.68,.08),"darkwood");box(roof,Vector3(.2,11.9,z+.08),Vector3(.45,.055,.08),"darkwood")
		var spire:=G.cylinder(roof,Vector3(0,15.5,-1.7),2.35,5.9,mat("snow"),.025);spire.mesh.radial_segments=4
		G.capsule(roof,Vector3(0,18.3,-1.7),Vector3(0,19.6,-1.7),.055,mat("gold"))
		G.capsule(roof,Vector3(-.38,19.2,-1.7),Vector3(.38,19.2,-1.7),.055,mat("gold"))
	# One exterior batch per material at street distance. The alternate faces
	# reuse the same resources across houses and only draw for a cutaway.
	for section in sections.get_children():merge(section)
	var skin:=group(n,"Exterior")
	for part in sections.find_children("*","MeshInstance3D",true,false):
		var copy:=G.mesh(skin,part.mesh,part.position,part.material_override)
		copy.cast_shadow=part.cast_shadow
		part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	merge(skin)
	sections.hide()
	group(n,"Furnishing").hide()
	n.set_script(preload("res://scripts/icefield/winter_room.gd"))
	return n

static func panel(parent: Node3D,p: Vector3,size_: Vector3) -> void:
	box(parent,p,size_,"wood")
	P.box(parent,"TimberWall",p,size_)
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
