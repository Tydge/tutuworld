extends RefCounted
## The street uses the same room shells, joinery and ornaments as the build catalogue.
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
const JADE:="245c59"
const RED:="963f32"
const WOOD:="623f34"
const GOLD:="d8a85c"
const STONE:="c1b49d"
static var baked: Dictionary={}
static var silk: ShaderMaterial
static var paper: ShaderMaterial
static func shade(id: String) -> ShaderMaterial:
	if id=="silk":
		if silk==null:silk=ShaderMaterial.new();silk.shader=preload("res://assets/shaders/jade_silk_lantern.gdshader")
		return silk
	if paper==null:paper=ShaderMaterial.new();paper.shader=preload("res://assets/shaders/jade_window.gdshader")
	return paper
static var finishes: Dictionary={}
static func finish(id: String) -> StandardMaterial3D:
	if not finishes.has(id):
		var m:=StandardMaterial3D.new();m.albedo_texture=load("res://assets/jade/"+id+".png");m.roughness=.53 if id in ["tiles","amber_tiles"] else .85
		if id in ["masonry","lotus_marble","tiles","amber_tiles"]:
			m.normal_enabled=true;m.normal_texture=load("res://assets/jade/"+id+"_normal.png");m.normal_scale=.42 if id=="masonry" else .65
		match id:
			"tiles":m.albedo_color=Color("b4c4bd")
			"amber_tiles":m.albedo_color=Color("ecd1a0")
			"coffer":m.albedo_color=Color("c0b59c")
			"cloud_beam","polychrome":m.albedo_color=Color("b3a78c")
			"lacquer":m.albedo_color=Color("b8998b");m.roughness=.56
			"lime":m.albedo_color=Color("edeae0")
		m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.cull_mode=BaseMaterial3D.CULL_DISABLED;finishes[id]=m
	return finishes[id]
# Baked local light from the sill and overhanging eaves is kept on both levels of detail.
static func eave_tint(shape: PrimitiveMesh, height: float, width: float) -> ArrayMesh:
	var arrays:=shape.get_mesh_arrays()
	var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var colours:=PackedColorArray()
	colours.resize(verts.size())
	for i in range(verts.size()):
		var y:=verts[i].y/height+.5
		var overhang:=smoothstep(.63,1.,y)
		var base:=1.-smoothstep(0.,.23,y)
		var edge:=smoothstep(.68,1.,absf(verts[i].x)*2./width)
		var tint:=Color.WHITE.lerp(Color(.56,.63,.66),overhang*.86)
		tint=tint.lerp(Color(.77,.66,.51),base*.42)
		colours[i]=tint.darkened(edge*overhang*.075)
	arrays[Mesh.ARRAY_COLOR]=colours
	var mesh_:=ArrayMesh.new()
	mesh_.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh_
static var shaded_panels: Dictionary={}
static func wall_panel(n: Node3D,point: Vector3,size_: Vector3,skin: String) -> void:
	if not shaded_panels.has(skin):
		var wall:=finish(skin).duplicate() as StandardMaterial3D
		wall.vertex_color_use_as_albedo=true
		wall.uv1_scale=Vector3(3.,2.,1.);wall.ao_enabled=true;wall.ao_texture=preload("res://assets/jade/eave_occlusion.png");wall.ao_light_affect=.39
		shaded_panels[skin]=wall
	var shape:=BoxMesh.new()
	shape.size=size_;shape.subdivide_height=5;shape.subdivide_width=3
	G.mesh(n,eave_tint(shape,size_.y,size_.x),point,shaded_panels[skin])
static var carved_window: StandardMaterial3D
static var column_finishes: Dictionary={}
static func column(n: Node3D,p: Vector3,r: float,h: float,pigment: String="b4998b") -> void:
	if not column_finishes.has(pigment):
		var mat:=finish("lacquer").duplicate() as StandardMaterial3D
		mat.uv1_scale=Vector3(.45,.64,1.);mat.albedo_color=Color(pigment)
		mat.vertex_color_use_as_albedo=true
		column_finishes[pigment]=mat
	var shape:=CylinderMesh.new()
	shape.bottom_radius=r;shape.top_radius=r*.98;shape.height=h;shape.radial_segments=16;shape.rings=4
	G.mesh(n,eave_tint(shape,h,r*2.),p,column_finishes[pigment])
	var base:=p-Vector3.UP*h*.5
	var stone:=finish("lotus_marble")
	G.cylinder(n,base+Vector3.UP*.15,r*1.43,.28,stone,r*1.32)
	G.cylinder(n,base+Vector3.UP*.315,r*1.43,.075,stone,r*1.33)
	G.cylinder(n,base+Vector3.UP*.38,r*1.24,.060,stone)
static var box_finishes: Dictionary={}
static func paint(n: Node3D,p: Vector3,s: Vector3,id: String) -> MeshInstance3D:
	if not box_finishes.has(id):
		var face:=finish(id).duplicate() as StandardMaterial3D
		face.uv1_scale=Vector3(3.,2.,1.);box_finishes[id]=face
	var key:=id
	if id in ["polychrome","cloud_beam","stone_relief","wood_relief"] and s.x>1.5*s.y:
		var repeats:=clampi(roundi(s.x/maxf(2.1,s.y*4.0)),1,20);key=id+str(repeats)
		if not box_finishes.has(key):
			var trim:=box_finishes[id].duplicate() as StandardMaterial3D;trim.uv1_scale=Vector3(3.*repeats,2.,1.);box_finishes[key]=trim
	return G.box(n,p,s,box_finishes[key])
static func group(parent: Node3D,id: String,p:=Vector3.ZERO) -> Node3D:
	var n:=Node3D.new();n.name=id;n.position=p;parent.add_child(n);return n
static func box(n: Node3D,p: Vector3,s: Vector3,color_: String) -> MeshInstance3D:return G.box(n,p,s,G.mat(color_))
static func beam(n: Node3D,a: Vector3,b: Vector3,width: float,color_: String) -> void:
	var bar:=box(n,(a+b)*.5,Vector3(width,a.distance_to(b),width),color_)
	bar.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
static func mesh_part(parent: Node3D,key: String,create: Callable) -> void:
	if not baked.has(key):
		var raw:=group(parent,"Carpentry");create.call(raw)
		var pieces: Dictionary={}
		for m: MeshInstance3D in raw.find_children("*","MeshInstance3D",true,false):
			var mat:=m.material_override
			if m.mesh is CylinderMesh:
				m.mesh.rings=0
				if m.mesh.bottom_radius<.16:m.mesh.radial_segments=12
			elif m.mesh is SphereMesh and m.scale.length()<.72:
				m.mesh.radial_segments=14;m.mesh.rings=6
			if not pieces.has(mat):
				var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);pieces[mat]=st
			var t:=m.transform
			var ancestor:=m.get_parent() as Node3D
			while ancestor!=raw:
				t=ancestor.transform*t;ancestor=ancestor.get_parent() as Node3D
			G.append_indexed(pieces[mat],m.mesh,0,t)
		var combined:=ArrayMesh.new()
		for mat in pieces:
			var st: SurfaceTool=pieces[mat];st.set_material(mat);st.commit(combined)
		baked[key]=combined;raw.free()
	G.mesh(parent,baked[key],Vector3.ZERO,null,"Joinery")
static func roof_point(w: float,d: float,rise: float,t: float,u: float,side: int) -> Vector3:
	return Vector3(u*lerpf(w*.61,w,t),rise*pow(1.-t,1.65)+pow(absf(u),5)*pow(t,1.6)*.98,side*t*d)
static func roof(n: Node3D,w: float,d: float,rise: float,h: float,royal: bool) -> void:
	var top:=group(n,"Eaves",Vector3.UP*h)
	preload("res://scripts/jade/eave_tiles.gd").trim(top,w,d,rise,royal)
	var tile:=finish("amber_tiles" if royal else "tiles")
	var sheet:=SurfaceTool.new();sheet.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1,1]:
		for iz in range(8):
			for ix in range(16):
				for c in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
					var u: float=(ix+c.x)/8.-1.;var t: float=(iz+c.y)/8.
					sheet.set_uv(Vector2(u*w*.30,t*d*.45));sheet.add_vertex(roof_point(w,d,rise,t,u,side))
		for rib in range(-int(w*2),int(w*2)+1):
			if rib%4!=0:continue
			var u:=float(rib)/int(w*2)
			for k in range(4):
				var a:=roof_point(w,d,rise,k*.25,u,side);var b:=roof_point(w,d,rise,(k+1)*.25,u,side)
				beam(top,a+Vector3.UP*.045,b+Vector3.UP*.045,.102,"bc9149" if royal else "496860")
		for ix in range(16):
			var a:=roof_point(w,d,rise,1.,ix/8.-1.,side);var b:=roof_point(w,d,rise,1.,(ix+1)/8.-1.,side)
			beam(top,a,b,.22,GOLD if royal else "8a7458")
		for edge in [-1,1]:
			var e:=roof_point(w,d,rise,1.,edge,side)
			crest(top,e,Vector3(edge*.65,.55,side*.24),royal)
	for edge in [-1,1]:
		var a:=Vector3(edge*w*.61,rise,0)
		for k in range(8):
			var b:=a.lerp(Vector3(edge*w,0,0),(k+1)/8.)
			var before:=a.lerp(Vector3(edge*w,0,0),k/8.)
			for c in [[before,roof_point(w,d,rise,k/8.,edge,1),roof_point(w,d,rise,(k+1)/8.,edge,1)],[before,roof_point(w,d,rise,(k+1)/8.,edge,1),b],[before,b,roof_point(w,d,rise,(k+1)/8.,edge,-1)],[before,roof_point(w,d,rise,(k+1)/8.,edge,-1),roof_point(w,d,rise,k/8.,edge,-1)]]:
				for v in c:sheet.set_uv(Vector2(v.z*.38,v.x*.35));sheet.add_vertex(v)
		crest(top,a,Vector3(edge*.68,.44,0),royal)
	beam(top,Vector3(-w*.61,rise+.04,0),Vector3(w*.61,rise+.04,0),.30,GOLD if royal else "798c7c")
	sheet.generate_normals();sheet.generate_tangents();var surface:=tile.duplicate() as StandardMaterial3D
	surface.cull_mode=BaseMaterial3D.CULL_DISABLED
	var roof_mesh:=sheet.commit()
	G.mesh(top,roof_mesh,Vector3.ZERO,surface,"GlazedTiles")
	var soffit:=finish("coffer" if royal or w>6. else "wood_relief").duplicate() as StandardMaterial3D
	soffit.uv1_scale=Vector3(1.15,.86,1.);soffit.albedo_color=Color("b1a383");soffit.cull_mode=BaseMaterial3D.CULL_DISABLED
	G.mesh(top,roof_mesh,Vector3.DOWN*.145,soffit,"RafterSoffit")
	for side in [-1,1]:
		for j in range(-int(w*2.2),int(w*2.2)+1):
			var u:=j/(w*2.2);var end:=roof_point(w,d,rise,1.,u,side)
			var inner:=roof_point(w,d,rise,.75,u,side)
			beam(top,inner+Vector3.DOWN*.21,end+Vector3.DOWN*.21,.102,"835f40")
static func crest(top: Node3D,p: Vector3,axis: Vector3,royal: bool) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sideways:=Vector3(-axis.z,0,axis.x).normalized()
	for i in range(7):
		for j in range(7):
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var t: float=(i+corner.x)/7.;var a: float=(j+corner.y)*TAU/7.
				var core:=p+axis*Vector3(1,0,1)*t+Vector3.UP*axis.y*t*t
				var radius:=.16*(1.-t*.98)
				st.add_vertex(core+radius*(sideways*cos(a)+Vector3.UP*sin(a)))
	st.generate_normals();G.mesh(top,st.commit(),Vector3.ZERO,G.mat("b68b4d" if royal else "737c6e"))
static func lattice(n: Node3D,p: Vector3,w: float,h: float) -> void:
	G.box(n,p,Vector3(w,h,.12),shade("paper"))
	if carved_window==null:
		carved_window=finish("casement")
		carved_window.albedo_color=Color("c9bba1")
	for side in [-1,1]:
		G.box(n,p+Vector3(side*w*.42,0,.077),Vector3(w*.15,h*.91,.033),carved_window)
	for side in [-1,1]:
		box(n,p+Vector3(side*w*.5,0,.11),Vector3(.105,h+.14,.18),WOOD)
		box(n,p+Vector3(0,side*h*.5,.11),Vector3(w+.14,.105,.18),WOOD)
	for k in range(1,8):
		var x: float=(k/8.-.5)*w
		box(n,p+Vector3(x,0,.105),Vector3(.042,h,.075),WOOD)
	for k in range(1,6):
		var y: float=(k/6.-.5)*h
		box(n,p+Vector3(0,y,.115),Vector3(w,.044,.085),WOOD)
	for k in range(4):
		for row in range(3):
			var mid:=p+Vector3((k/4.-.375)*w,(row/3.-.333)*h,.16)
			var dx:=w*.117;var dy:=h*.153
			for sx in [-1,1]:
				for sy in [-1,1]:beam(n,mid+Vector3(sx*dx,0,0),mid+Vector3(0,sy*dy,0),.038,"845c3f")
	box(n,p-Vector3.UP*(h*.5+.10)+Vector3.BACK*.12,Vector3(w+.28,.14,.44),WOOD)
static func lantern(n: Node3D,p: Vector3,r: float=1.) -> void:
	var base:=group(n,"SilkLantern",p);base.scale=Vector3.ONE*r
	G.ball(base,Vector3.ZERO,Vector3(.46,.54,.46),shade("silk"),"Silk")
	for y in [-.46,.46]:G.cylinder(base,Vector3.UP*y,.30,.10,G.mat(GOLD))
	for k in range(8):
		var v:=Vector3(sin(k*PI/4),0,cos(k*PI/4))
		beam(base,v*.28+Vector3.UP*.47,v*.46,.024,GOLD);beam(base,v*.46,v*.28-Vector3.UP*.47,.024,GOLD)
	G.cylinder(base,Vector3.DOWN*.56,.09,.13,G.mat("8d4b35"),.14)
	for k in range(7):
		var a:=k*TAU/7.;var p0:=Vector3(cos(a)*.058,-.59,sin(a)*.058)
		beam(base,p0,p0+Vector3(.021,-.27+.025*cos(a),.012),.023,"b84229")
static func dims(kind: String) -> Vector3:return preload("res://scripts/jade/layout.gd").dims(kind)
static func shell(n: Node3D,kind: String) -> void:
	var d:=dims(kind);var w:=d.x;var h:=d.y;var z:=d.z;var royal:=kind in ["palace","court"]
	var wood:=RED if royal or kind=="loft" else WOOD
	var pigment: String={"store":"ac8c63","forge":"736959","cloister":"718c83","inn":"a1846b","cottage":"ae9169","clocktower":"8d7066","court":"d1a085","palace":"db9880"}.get(kind,"ba9686")
	if kind=="theatre":
		preload("res://scripts/jade/theatre.gd").build(n,w,h,z);return
	if kind=="pavilion":
		preload("res://scripts/jade/pavilions.gd").octagon(n,w,h,z);return
	var exterior:=group(n,"Exterior")
	mesh_part(exterior,"roof_"+kind,func(m):
		if kind not in ["loft","inn","clocktower"]:roof(m,w+1.35,z+1.65,3.6 if royal else 2.5,h,royal)
		if kind=="palace":
			box(m,Vector3(0,h+1.85,0),Vector3(w*1.36,3.3,z*1.2),wood)
			for i in range(-2,3):lattice(m,Vector3(i*w*.245,h+2.88,z*.61),w*.18,.9)
			roof(m,w*.81,z*.81,3.1,h+3.6,royal))
	for face in ["Front","Rear","West","East"]:
		var section:=group(n,face);section.rotation.y={"Front":0.,"Rear":PI,"West":-PI/2,"East":PI/2}[face]
		var front: bool=face=="Front";var span:=w if face in ["Front","Rear"] else z
		var depth:=z if face in ["Front","Rear"] else w
		mesh_part(section,kind+face,func(m):
			for side in [-1,1]:
				var gap:=1.65 if front or (kind=="court" and face=="West") else 0.
				wall_panel(m,Vector3(side*(span+gap)*.5,h*.45,depth),Vector3(span-gap,h*.9,.26),"lacquer" if royal else ("plaster" if kind in ["store","forge","inn","cloister","loft"] else "lime"))
				paint(m,Vector3(side*(span+gap)*.5,.40,depth+.03),Vector3(span-gap,.80,.32),"masonry")
				var window:=Vector3(side*span*.64,h*.51,depth+.17)
				if front and kind in ["store","forge"] and side<0:
					preload("res://scripts/jade/shopfront.gd").display_bay(m,window,span*.47,h*.43,kind=="forge")
				else:lattice(m,window,span*.47,h*.43)
				var interior:=group(m,"InteriorCasement",Vector3(side*span*.64,h*.53,depth-.17));interior.rotation.y=PI
				paint(interior,Vector3.ZERO,Vector3(span*.48,h*.41,.095),"casement")
				for j in [-1,1]:
					box(interior,Vector3(j*span*.25,0,.08),Vector3(.095,h*.43,.10),WOOD)
					box(interior,Vector3(0,j*h*.215,.08),Vector3(span*.52,.095,.12),WOOD)
				paint(m,Vector3(side*(span+gap)*.5,.42,depth-.175),Vector3(span-gap,.76,.083),"lacquer")
				paint(m,Vector3(side*(span+gap)*.5,h*.85,depth-.174),Vector3(span-gap,.42,.11),"cloud_beam")
				for k in [-1,1]:
					box(m,Vector3(side*(span*.73+k*span*.154),h*.44,depth-.21),Vector3(.125,h*.86,.15),WOOD)
			for field in range(4):
				paint(m,Vector3((field-1.5)*span*.5,h*.91,depth),Vector3(span*.5+.025,.64,.48),"cloud_beam" if royal or kind in ["theatre","loft","clocktower"] else "wood_relief")
			box(m,Vector3(0,h-.07,depth+.05),Vector3(span*2+.75,.16,.72),GOLD)
			for j in range(-int(span*2),int(span*2)+1):
				if j%2==0:
					var rafter:=box(m,Vector3(j*.49,h+.012,depth+.68),Vector3(.125,.15,1.56),"79553c")
					rafter.rotation.x=.095
			for j in [-1.,-.32,.32,1.]:
				var x: float=span*j
				column(m,Vector3(x,h*.46,depth+.24),.20,h*.93,pigment)

				for side in [-1,1]:
					beam(m,Vector3(x,h-.72,depth+.23),Vector3(x+side*.61,h-.28,depth+.34),.16,wood)
				preload("res://scripts/jade/brackets.gd").place(m,Vector3(x,h-.68,depth+.37),finish("wood_relief"))
				paint(m,Vector3(x,h-.45,depth+.45),Vector3(.65,.30,.63),"polychrome")
				paint(m,Vector3(x,h-.21,depth+.55),Vector3(1.04,.20,.69),"polychrome")
			if front:
				for side in [-1.,1.]:
					var leaf:=group(m,"OpenDoor",Vector3(side*1.57,0,depth-.14))
					leaf.rotation.y=side*(.43 if royal else .25)
					var span_z:=1.35;var tall:=minf(4.5,h*.78)
					paint(leaf,Vector3(0,tall*.5,-span_z*.5),Vector3(.125,tall,span_z),"lacquer")
					for q in [.09,.53,.88]:
						box(leaf,Vector3(-side*.085,tall*q,-span_z*.5),Vector3(.095,.10,span_z+.035),"6b4d31")
					for j in range(3):
						for k in range(4):
							var nail:=G.cylinder(leaf,Vector3(-side*.078,.61+j*.65,-.17-.31*k),.043,.033,G.mat(GOLD));nail.rotation.z=PI/2
			if royal and front:
				for side in [-1,1]:
					paint(m,Vector3(side*2.18,2.16,depth+.24),Vector3(.85,3.6,.09),"crane_panel")
					paint(m,Vector3(side*span*.63,.39,depth+.20),Vector3(span*.53,.58,.08),"stone_relief")
			if front:
				box(m,Vector3(0,h-.6,depth+.43),Vector3(3.45,.91,.18),GOLD)
				box(m,Vector3(0,h-.6,depth+.54),Vector3(3.30,.76,.10),"274f50")
				for side in [-1,1]:lantern(m,Vector3(side*(span-.5),h-1.28,depth+.74),1.05))
		for side in [-1,1]:
			var gap:=1.72 if front or (kind=="court" and face=="West") else 0.
			P.box(section,"Wall",Vector3(side*(span+gap)*.5,h*.5,depth),Vector3(span-gap,h,.30))
	if kind=="court":preload("res://scripts/jade/pavilions.gd").side_wing(n,w,h,z)
	if kind in ["loft","inn","clocktower"]:preload("res://scripts/jade/joinery.gd").upper_floor(n,w,h,z)
	if kind=="clocktower":
		mesh_part(exterior,"bell_turret",func(m):
			var top:=h+4.5
			# Open lantern drum rises above the balcony roof, ringed by eight glazed gables.
			for i in range(8):
				var angle:=i*TAU/8.;var a:=Vector3(cos(angle)*2.48,top+1.85,sin(angle)*2.48)
				var b:=Vector3(cos(angle+TAU/8.)*2.48,a.y,sin(angle+TAU/8.)*2.48)
				column(m,a,.155,3.7);beam(m,a+Vector3.UP*1.68,b+Vector3.UP*1.68,.26,JADE)
				beam(m,a+Vector3.UP*1.35,b+Vector3.UP*1.35,.14,GOLD)
			var bell:=G.mat("8b6842",.43);bell.metallic=.38
			G.cylinder(m,Vector3(0,top+1.6,0),.82,2.4,bell,.55)
			for j in range(3):G.cylinder(m,Vector3(0,top+.48+j*.26,0),.94-j*.08,.11,bell)
			roof(m,3.64,3.65,2.4,top+3.6,false)
			G.cylinder(m,Vector3.UP*(top+6.3),.21,.68,G.mat(GOLD),.06))
	if kind in ["forge","cloister","pavilion","store","cottage"]:preload("res://scripts/jade/joinery.gd").veranda(n,kind,w,h,z)
static func prop(n: Node3D,kind: String) -> void:
	if kind in preload("res://scripts/jade/trades.gd").KINDS:preload("res://scripts/jade/trades.gd").make(n,kind);return
	if kind=="jade_court_terrace":preload("res://scripts/jade/processional_court.gd").make_plot_terrace(n);return
	if kind=="jade_crane":preload("res://scripts/jade/crane.gd").make(n);return
	if kind=="jade_shop_veranda":preload("res://scripts/jade/shopfront.gd").make(n);return
	if kind=="jade_sampan":preload("res://scripts/jade/sampan.gd").make(n);return
	if kind in ["jade_peony","jade_iris"]:preload("res://scripts/jade/borders.gd").make(n,kind=="jade_iris");return
	if preload("res://scripts/jade/market_art.gd").NAMES.has(kind):preload("res://scripts/jade/market_art.gd").make(n,kind);return
	if kind in ["jade_street_gallery","jade_street_gallery_reverse"]:preload("res://scripts/jade/street_gallery.gd").make(n,kind=="jade_street_gallery_reverse");return
	if preload("res://scripts/jade/civic_props.gd").NAMES.has(kind):
		preload("res://scripts/jade/civic_props.gd").make(n,kind);return
	if preload("res://scripts/jade/garden.gd").NAMES.has(kind):
		preload("res://scripts/jade/garden.gd").make(n,kind);return
	match kind:
		"jade_theatre","jade_clocktower","jade_hall","jade_loft","jade_court","jade_palace","jade_store","jade_inn","jade_forge","jade_cloister","jade_pavilion","jade_cottage":shell(n,kind.trim_prefix("jade_"))
		"jade_gate":
			n.set_script(preload("res://scripts/jade/gate_view.gd"));n.set_process(false)
			mesh_part(n,"GateMasonry",func(m):
				for x in [-4.9,4.9]:
					paint(m,Vector3(x,.35,0),Vector3(1.27,.70,1.35),"lotus_marble")
					G.cylinder(m,Vector3(x,.90,0),.51,.46,G.mat(STONE),.42)
					column(m,Vector3(x,3.68,0),.34,5.42))
			var crown:=group(n,"GateCrown")
			mesh_part(crown,"PorticoCrown",func(m):
				for x in [-4.9,4.9]:
					lantern(m,Vector3(x*.68,5.2,0),1.35)
					for side in [-1,1]:beam(m,Vector3(x,5.80,0),Vector3(x+side*.91,6.5,0),.19,WOOD)
				paint(m,Vector3(0,6.35,0),Vector3(10.8,1.18,.70),"lacquer")
				paint(m,Vector3(0,6.88,.13),Vector3(11.2,.25,.93),"cloud_beam")
				box(m,Vector3(0,6.38,.42),Vector3(3.85,.86,.15),JADE)
				roof(m,6.55,1.65,1.9,7.1,false))
			for x in [-4.9,4.9]:P.cylinder(n,"Pillar",Vector3(x,3.5,0),.52,7.)
		"jade_lamp":
			mesh_part(n,kind,func(m):
				box(m,Vector3.UP*.26,Vector3(.84,.52,.84),STONE)
				box(m,Vector3.UP*2.,Vector3(.23,3.6,.23),RED)
				box(m,Vector3(.38,3.82,0),Vector3(1.22,.15,.18),GOLD)
				lantern(m,Vector3(.79,3.08,0)))
			P.box(n,"Post",Vector3.UP*1.8,Vector3(.45,3.6,.45))
		"jade_screen":
			mesh_part(n,kind,func(m):
				for j in [-1,0,1]:
					var wing:=group(m,"Leaf",Vector3(j*.88,1.22,.14*absi(j)));wing.rotation.y=-j*.22
					lattice(wing,Vector3.ZERO,.92,1.94)
					paint(wing,Vector3(0,0,.17),Vector3(.78,1.7,.04),"egret" if j==0 else "brocade")
					box(wing,Vector3(0,-1.05,0),Vector3(1.,.18,.5),WOOD))
			P.box(n,"Screen",Vector3.UP*1.05,Vector3(2.72,2.1,.53))
		"jade_chime":
			mesh_part(n,kind,func(m):
				for x in [-.85,.85]:box(m,Vector3(x,.95,0),Vector3(.13,1.9,.2),RED)
				box(m,Vector3.UP*1.9,Vector3(2.1,.14,.26),GOLD)
				for j in range(5):
					var x: float=(j-2)*.3;var y:=1.42-.07*j
					beam(m,Vector3(x,1.84,0),Vector3(x,y,0),.025,WOOD)
					G.cylinder(m,Vector3(x,y-.15,0),.14,.34,G.mat("ac8e53"),.09))
			P.box(n,"Chimes",Vector3.UP*.85,Vector3(1.9,1.7,.32))
		"jade_basin":
			mesh_part(n,kind,func(m):
				G.cylinder(m,Vector3.UP*.23,.62,.46,G.mat(STONE),.43)
				G.cylinder(m,Vector3.UP*.58,.43,.30,G.mat("668d83"),.92)
				G.cylinder(m,Vector3.UP*.74,.85,.015,G.mat("79b0a2"))
				for i in range(3):
					var p:=Vector3(cos(2.1*i)*.43,.76,sin(2.1*i)*.43);G.ball(m,p,Vector3(.29,.025,.23),G.mat("78965d"))
					for j in range(6):G.ball(m,p+Vector3(.085*cos(j),.05,.085*sin(j)),Vector3(.09,.06,.07),G.mat("ecc6b9")))
			P.cylinder(n,"Basin",Vector3.UP*.38,.85,.76)
		"jade_rail":
			mesh_part(n,kind,func(m):
				for x in [-1.9,1.9]:
					paint(m,Vector3(x,.65,0),Vector3(.46,1.3,.46),"masonry");G.cylinder(m,Vector3(x,1.34,0),.23,.17,G.mat("958671"),.155)
				for y in [.28,1.06]:paint(m,Vector3(0,y,0),Vector3(3.8,.20,.22),"masonry")
				for j in [-1,0,1]:paint(m,Vector3(j*1.18,.64,0),Vector3(1.13,.64,.17),"lotus_marble"))
			P.box(n,"Balustrade",Vector3.UP*.57,Vector3(4.2,1.14,.42))
