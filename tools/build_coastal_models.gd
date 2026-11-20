extends SceneTree
## Offline mesh bake. All coordinates are metres in the placement module's local space.
const OUT := "res://scenes/coastal/"
const Headlands := preload("res://tools/coastal_headlands.gd")
const Fountain := preload("res://tools/coastal_fountain_art.gd")
const Market := preload("res://tools/coastal_market_art.gd")
const Spurs := preload("res://scripts/city/coastal/fruit_spurs.gd")
const LIMESTONE := "edddbc"
const RECESS := "364c46"
const PATINA := "598a81"
const COPPER := "a9b5a1"
const BRASS := "d2a259"
var surface: SurfaceTool
var frame := Transform3D.IDENTITY
var paint := StandardMaterial3D.new()
var failed := false
var clock_marker := -1.0

func _initialize() -> void:
	paint.vertex_color_use_as_albedo = true
	paint.roughness = .78
	paint.resource_name = "Weathered stone, paint and metal"
	begin()
	lantern()
	save_mesh("lantern",preload("res://scenes/coastal/lantern_glass.tres"))
	begin()
	clock_marker = 0.
	clocktower()
	clock_marker = -1.
	save_mesh("clocktower", preload("res://scenes/coastal/clock_dial.tres"))
	begin()
	orange()
	save_mesh("orange",paint)
	begin()
	lighthouse()
	save_mesh("lighthouse", paint)
	begin()
	headland()
	save_mesh("headland", paint)
	begin()
	window_bracket()
	save_mesh("wall_bracket", paint)
	for part in [["hill",Headlands.hill],["mill",Headlands.mill],["sails",Headlands.sails],["skiff",Headlands.boat]]:
		begin()
		part[1].call(self)
		save_mesh(part[0],paint)
	for shop in range(3):
		for part in [["awning",Market.awning],["shutters",Market.shutters],["medallion",Market.medallion]]:
			begin()
			part[1].call(self,shop)
			save_mesh(part[0]+"_"+["farm","tools","clothes"][shop],paint)
	for part in [["pennants",Market.pennants],["flowers",Market.flowers]]:
		begin()
		part[1].call(self)
		save_mesh(part[0],paint)
	for part in [["stone",Fountain.stone,"d0d0b8",.84,0.],["trim",Fountain.trim,"e2d9bb",.65,0.],["tile",Fountain.tiles,"64a5a3",.35,.12],["metal",Fountain.bronze,"ffffff",.35,.42]]:
		begin()
		part[1].call(self)
		var finish:=StandardMaterial3D.new()
		finish.vertex_color_use_as_albedo=true
		finish.albedo_color=Color(part[2])
		finish.roughness=part[3]
		finish.metallic=part[4]
		if part[0] in ["stone","trim"]:finish.albedo_texture=preload("res://assets/terrain/soft_lime_plaster_v1.png")
		if part[0]=="metal":
			var bronze:=ShaderMaterial.new()
			bronze.shader=preload("res://assets/shaders/coastal_bronze.gdshader")
			bronze.set_shader_parameter("grain",preload("res://assets/terrain/soft_lime_plaster_v1.png"))
			save_mesh("fountain_metal",bronze)
		else:
			save_mesh("fountain_"+part[0],finish)
	for part in [["fountain_streams",Fountain.running_water],["fountain_pools",Fountain.pools]]:
		begin()
		part[1].call(self)
		save_mesh(part[0],paint)
	var foliage := preload("res://scenes/coastal/foliage.tres")
	begin()
	wisteria()
	save_mesh("wisteria",foliage)
	for kind in ["citrus","olive"]:
		begin()
		preload("res://tools/coastal_orchard_art.gd").new().build(self,kind=="citrus")
		save_mesh(kind,preload("res://scenes/coastal/orchard_material.tres"))
		begin()
		preload("res://tools/coastal_orchard_art.gd").new().build(self,kind=="citrus",true)
		save_mesh(kind+"_shadow",paint)
	var woodland: ShaderMaterial = foliage.duplicate()
	woodland.set_shader_parameter("branches",preload("res://assets/terrain/woodland/foliage_atlas_v1.png"))
	for species in ["pine","birch","oak"]:
		begin()
		woodland_crown(species)
		save_mesh(species,woodland)
	quit(1 if failed else 0)

func begin() -> void:
	frame = Transform3D.IDENTITY
	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

func save_mesh(id: String, material: Material) -> void:
	surface.index()
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	if id in ["citrus","olive","citrus_shadow","olive_shadow","hill","flowers"]:
		var levels:=ImporterMesh.new()
		levels.add_surface(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0),[],{},material)
		levels.generate_lods(55.,80.,[])
		mesh=levels.get_mesh()
		print("Baked mesh LODs ",id," ",levels.get_surface_lod_count(0))
	mesh.resource_name = id
	var err := ResourceSaver.save(mesh, OUT + id + ".res", ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("Could not save " + id + ": " + error_string(err))
		failed = true

func stamp(shape: PrimitiveMesh, pose: Transform3D, color: String) -> void:
	var arrays := shape.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tint := Color(color).srgb_to_linear()
	if clock_marker >= 0.: tint.a = clock_marker
	var transform_ := frame * pose
	var normal_basis := transform_.basis.inverse().transposed()
	for i in arrays[Mesh.ARRAY_INDEX]:
		surface.set_color(tint)
		surface.set_normal((normal_basis * normals[i]).normalized())
		surface.add_vertex(transform_ * vertices[i])

func box(p: Vector3, size_: Vector3, color: String, rotation_z := 0.) -> void:
	var shape := BoxMesh.new()
	shape.size = size_
	stamp(shape, Transform3D(Basis(Vector3.BACK, rotation_z), p), color)

func drum(a: Vector3, b: Vector3, base: float, top: float, color: String, sides := 20) -> void:
	var shape := CylinderMesh.new()
	shape.height = a.distance_to(b)
	shape.bottom_radius = base
	shape.top_radius = top
	shape.radial_segments = sides
	shape.rings = 0
	var rotation_ := Basis(Quaternion(Vector3.UP, (b-a).normalized()))
	stamp(shape, Transform3D(rotation_, (a+b)*.5), color)

func tier(low: float, high: float, base: float, top: float, color: String, sides := 24) -> void:
	drum(Vector3.UP*low, Vector3.UP*high, base, top, color, sides)

func square(y: float, width: float, height: float, color: String) -> void:
	box(Vector3.UP*y, Vector3(width,height,width), color)

func ellipsoid(p: Vector3,radii: Vector3,color: String,tilt:=0.) -> void:
	var shape := SphereMesh.new()
	shape.radius=1.
	shape.height=2.
	shape.radial_segments=14
	shape.rings=6
	stamp(shape,Transform3D(Basis(Vector3.BACK,tilt).scaled_local(radii),p),color)

func facet(a: Vector3,b: Vector3,c: Vector3,out: Vector3,color: String) -> void:
	if (b-a).cross(c-a).dot(out)>0.: triangle(a,b,c,Color(color).srgb_to_linear())
	else: triangle(a,c,b,Color(color).srgb_to_linear())

func panel(a: Vector3,b: Vector3,c: Vector3,d: Vector3,out: Vector3,color: String) -> void:
	facet(a,b,c,out,color)
	facet(a,c,d,out,color)

func clocktower() -> void:
	square(.35, 4.20, .70, "ae9473")
	square(.73, 4.46, .20, LIMESTONE)
	square(2.35, 3.80, 3.15, "d7c29f")
	for i in range(4):
		frame = Transform3D(Basis(Vector3.UP, i*PI/2.), Vector3.ZERO)
		for side in [-1., 1.]:
			box(Vector3(side*1.78,2.28,1.91),Vector3(.26,3.08,.21),LIMESTONE)
			for k in range(6):
				box(Vector3(side*1.78,1.03+k*.49,2.02),Vector3(.32,.11,.09),"c2ae89")
		var center := Vector3(0,2.47,1.93)
		drum(center,center+Vector3.BACK*.16,1.33,1.30,RECESS,48)
		drum(center+Vector3.BACK*.15,center+Vector3.BACK*.24,1.26,1.21,BRASS,48)
		clock_marker = 1./3.
		drum(center+Vector3.BACK*.23,center+Vector3.BACK*.26,1.14,1.14,"f4e9ce",48)
		clock_marker = 0.
		for k in range(12):
			var angle := k*TAU/12.
			box(center+Vector3(sin(angle),cos(angle),.30),Vector3(.045 if k%3 else .082,.15,.045),RECESS,-angle)
		for hand in [[2./3.,.62],[1.,.88]]:
			clock_marker = hand[0]
			var tip := center + Vector3.UP*float(hand[1])
			drum(center+Vector3.BACK*.32,tip+Vector3.BACK*.32,.069,.034,RECESS,6)
		clock_marker = 0.
		drum(center+Vector3.BACK*.32,center+Vector3.BACK*.39,.10,.08,BRASS)
	frame = Transform3D.IDENTITY
	square(3.96,4.27,.18,RECESS)
	square(4.14,4.46,.24,LIMESTONE)
	# Bell behind an open four-sided arcade.
	tier(4.55,4.80,.72,.52,"9d7544")
	tier(4.80,5.38,.52,.30,"a68655")
	for x in [-1.27,1.27]:
		for z in [-1.27,1.27]:
			var p := Vector3(x,4.23,z)
			box(p+Vector3.UP*.10,Vector3(.46,.20,.46),LIMESTONE)
			drum(p+Vector3.UP*.15,p+Vector3.UP*1.71,.18,.15,LIMESTONE,12)
			box(p+Vector3.UP*1.67,Vector3(.45,.18,.45),LIMESTONE)
	square(6.03,3.74,.31,"dac8a7")
	square(6.23,4.08,.16,PATINA)
	# Stepped, ribbed copper ogee dome with a weathervane.
	var profile := [[6.3,2.48],[6.50,2.22],[6.86,1.91],[7.25,1.67],[7.74,1.36],[8.13,.87],[8.42,.37],[8.72,.16]]
	for j in range(profile.size()-1):
		var low: Array=profile[j]
		var high: Array=profile[j+1]
		tier(low[0],high[0],low[1],high[1],PATINA,8)
		for k in range(8):
			var radial := Vector3(sin(k*TAU/8.),0,cos(k*TAU/8.))
			drum(Vector3.UP*float(low[0])+radial*float(low[1]),Vector3.UP*float(high[0])+radial*float(high[1]),.035,.030,COPPER,6)
	tier(8.58,9.68,.058,.03,BRASS,10)
	drum(Vector3(-.77,9.26,0),Vector3(.71,9.26,0),.034,.034,BRASS,6)
	drum(Vector3(.46,9.26,0),Vector3(.89,9.26,0),.16,0.,BRASS,4)
	box(Vector3(-.56,9.31,0),Vector3(.33,.23,.04),BRASS,-.20)

func lantern() -> void:
	var iron := "42665d00"
	var foot := "384e4800"
	var gold := "b69d7000"
	tier(0.,.09,.28,.28,foot,12)
	tier(.09,.18,.27,.19,iron,12)
	tier(.18,.54,.18,.14,iron,12)
	tier(.54,.61,.17,.13,gold,12)
	tier(.61,.74,.14,.088,iron,12)
	tier(.74,2.54,.088,.065,iron,12)
	tier(2.47,2.54,.10,.11,gold,12)
	tier(2.54,2.66,.12,.21,iron,8)
	tier(2.66,2.71,.22,.24,foot,6)
	tier(2.71,3.21,.207,.303,"ccd5b9ff",6)
	for i in range(6):
		var axis := Vector3(sin(i*TAU/6.),0,cos(i*TAU/6.))
		drum(axis*.215+Vector3.UP*2.68,axis*.316+Vector3.UP*3.24,.019,.024,foot,6)
	tier(3.21,3.28,.34,.36,iron,6)
	tier(3.28,3.32,.37,.36,gold,6)
	tier(3.32,3.46,.38,.18,iron,6)
	tier(3.46,3.54,.17,.091,iron,8)
	tier(3.54,3.68,.068,.014,gold,8)

func lighthouse() -> void:
	tier(0.,.48,3.55,3.5,"9b9786")
	tier(.48,.90,3.33,3.13,LIMESTONE)
	var bands := [[.9,2.94,"e9debd"],[5.1,2.55,"ab513e"],[8.,2.28,"f3e7cb"],[11.7,2.00,"ad5140"],[14.15,1.85,"f3e6ca"],[15.63,1.76,"e1d3b4"]]
	for j in range(bands.size()-1):
		tier(bands[j][0],bands[j+1][0],bands[j][1],bands[j+1][1],bands[j][2],32)
	for i in range(4):
		frame = Transform3D(Basis(Vector3.UP,i*PI*.60),Vector3.ZERO)
		var y := 2.+i*3.3
		var r := lerpf(2.94,1.76,(y-.9)/14.73)
		box(Vector3(0,y,r-.03),Vector3(.55,.99,.20),LIMESTONE)
		box(Vector3(0,y,r+.09),Vector3(.36,.74,.07),RECESS)
		box(Vector3(0,y-.43,r+.11),Vector3(.63,.10,.22),"aeb8a4")
	frame = Transform3D.IDENTITY
	tier(15.6,16.22,1.78,2.42,LIMESTONE)
	tier(16.22,16.45,2.55,2.55,RECESS)
	for i in range(20):
		var p := Vector3(sin(i*TAU/20.),0,cos(i*TAU/20.))*2.35
		var q := p.rotated(Vector3.UP,TAU/20.)
		drum(p+Vector3.UP*16.43,p+Vector3.UP*17.33,.047,.037,RECESS,6)
		for y in [16.87,17.32]:
			drum(p+Vector3.UP*y,q+Vector3.UP*y,.045,.045,RECESS,6)
	tier(16.40,16.72,1.47,1.47,"455857",12)
	for i in range(10):
		var p := Vector3(sin(i*TAU/10.),0,cos(i*TAU/10.))*1.42
		drum(p+Vector3.UP*16.65,p+Vector3.UP*18.59,.07,.055,RECESS,8)
	tier(18.48,18.76,1.72,1.78,RECESS,12)
	tier(18.76,19.97,1.83,.28,PATINA,12)
	tier(19.97,20.83,.15,.018,BRASS,8)

func headland() -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=48151
	var rings: Array[PackedVector3Array]=[]
	var sizes := [1.0,.91,.82,.73,.65,.47,.17]
	var heights := [-2.1,.85,1.35,3.65,4.15,5.30,5.65]
	for j in range(sizes.size()):
		var ring:=PackedVector3Array()
		for i in range(56):
			var a:=i*TAU/56.
			var shore:=1.+.12*sin(3.*a+.3)+.14*cos(5.*a-.7)+.047*sin(13.*a)
			var waviness:=sin(3.*a+.65)+.35*cos(8.*a)
			var center:=Vector3(-1.1*j,0,-.38*j)
			ring.append(center+Vector3(cos(a)*32.*sizes[j]*shore,heights[j]+waviness*(.35 if j<3 else .85),sin(a)*15.*sizes[j]*shore))
		rings.append(ring)
	var colors:=["827e70","c3bc9f","948978","dcd1b0","858862","78825e"]
	for j in range(rings.size()-1):
		for i in range(56):
			var k:=(i+1)%56
			var tint:=Color(colors[j]).darkened(rng.randf_range(0.,.12)).srgb_to_linear()
			triangle(rings[j][i],rings[j+1][i],rings[j][k],tint)
			triangle(rings[j][k],rings[j+1][i],rings[j+1][k],tint)
	for i in range(56):
		triangle(rings[-1][i],Vector3(-6.5,5.75,-2.4),rings[-1][(i+1)%56],Color("74805a").srgb_to_linear())
	# Low salt-tolerant scrub on the rocky shoulder, all part of the same draw.
	for i in range(30):
		var a:=rng.randf()*TAU
		var p:=Vector3(-4.+cos(a)*rng.randf_range(5.,14.),4.7,sin(a)*rng.randf_range(2.2,5.2))
		if Vector2(p.x+4.,p.z+2.).length()<4.: continue
		var radius:=rng.randf_range(.65,1.62)
		drum(p,p+Vector3.UP*rng.randf_range(.85,1.50),radius,radius*.50,["717f5d","596c56","87906e"][i%3],7)

func triangle(a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	# Godot front faces wind clockwise.
	var normal:=(b-a).cross(c-a).normalized()
	for p in [a,c,b]:
		surface.set_color(color)
		surface.set_normal(normal)
		surface.add_vertex(p)

func orange() -> void:
	for row in range(12):
		for side in range(20):
			for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
				var t: float=(row+corner.y)*PI/12.
				var a: float=(side+corner.x)*TAU/20.
				var normal:=Vector3(sin(t)*cos(a),cos(t),sin(t)*sin(a))
				var p:=normal*Vector3(.157,.150,.157)
				p.y-=.012*pow(maxf(0.,normal.y),12.)
				var tone:=Color("db7d24").lerp(Color("ffb23f"),.48+.36*normal.y+.12*normal.z).srgb_to_linear()
				tone.a=.34
				surface.set_color(tone)
				surface.set_normal(normal)
				surface.add_vertex(p)
	for i in range(5):
		var a:=i*TAU/5.
		var top:=Vector3(0,.145,0)
		var radial:=Vector3(cos(a),0,sin(a))
		var across:=Vector3(-radial.z,0,radial.x)
		facet(top+across*.014,top+radial*.038-Vector3.UP*.002,top-across*.014,Vector3.UP,"77914848")
	drum(Vector3(0,.135,0),Spurs.STEM_END,.020,.016,"775e3848",8)
	for side in [-1.,1.]:
		var leaf := SphereMesh.new()
		leaf.radius=.13
		leaf.height=.065
		leaf.radial_segments=8
		leaf.rings=3
		var basis:=Basis(Vector3.BACK,side*.27).scaled_local(Vector3(1.,.63,.53))
		stamp(leaf,Transform3D(basis,Vector3(side*.073,.193,-.009)), "58834b48")

func window_bracket() -> void:
	for x in [-.77,.77]:
		box(Vector3(x,0,.055),Vector3(.095,.56,.10),RECESS)
		drum(Vector3(x,-.21,.09),Vector3(x,.06,.43),.048,.04,RECESS,8)
	box(Vector3(0,.11,.29),Vector3(1.94,.30,.49),"956e4f")
	box(Vector3(0,.255,.29),Vector3(2.0,.08,.55),"c89666")
	box(Vector3(0,.299,.28),Vector3(1.87,.018,.42),"534b3a")
	for x in [-.75,.75]:
		box(Vector3(x,.10,.54),Vector3(.07,.34,.04),"62695b")

func woodland_crown(species: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11407
	if species != "pine":
		var rect := Rect2(.51,.51 if species=="birch" else .01,.48,.48)
		for i in range(37):
			var a := i*2.39996
			var radial := Vector3(cos(a),0,sin(a))
			var right := Vector3(-sin(a),0,cos(a))
			var h := rng.randf_range(-.64,.55)
			var radius := (1.-absf(h)*.72)*rng.randf_range(.45,.88)
			card(radial*radius+Vector3.UP*h,right*rng.randf_range(.75,1.20),Vector3.UP*.67+radial*.22,radial,rect,rng.randf_range(.82,1.10),true)
		return
	for level in range(7):
		var y := -1.+level*.28
		var length_ := (1.-level*.137)
		for i in range(8):
			var a := i*TAU/8.+level*1.3
			var out := Vector3(cos(a),0,sin(a))
			var side := Vector3(-sin(a),.6 if i%2==0 else -.6,cos(a)).normalized()
			for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
				var u: float=corner.x
				var v: float=corner.y
				surface.set_color(Color.WHITE*(.83+float(level)*.024))
				surface.set_normal((Vector3.UP*.7+out*.36).normalized())
				surface.set_uv(Vector2(.005+u*.485,.008+v*.48))
				surface.add_vertex(Vector3.UP*(y+.13-u*.24)+out*(.025+length_*u)+side*(v-.5)*length_*1.05)

func wisteria() -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=8813
	for i in range(12):
		var foot:=Vector3(-.87+(i%6)*.35,.31+rng.randf_range(-.03,.06),.32+float(i/6)*.18)
		var a:=rng.randf_range(-.75,.75)
		var right:=Vector3(cos(a),0,sin(a))*rng.randf_range(.46,.78)
		var down:=Vector3(rng.randf_range(-.14,.14),-rng.randf_range(.45,.91),rng.randf_range(.08,.32))
		var uv:=Rect2(.501 if i%4==0 else .002,(.414*1254.-515.)/739.,.495,.523*1254./739.)
		card(foot,right,down,Vector3.BACK,uv,rng.randf_range(.9,1.1),false)

func card(foot: Vector3, span: Vector3, axis: Vector3, radial: Vector3, uv: Rect2, brightness: float, grows_up: bool) -> void:
	for half in range(2):
		for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
			var u: float=(half+corner.x)*.5
			var v: float=corner.y
			var bend: float=(1.-absf(2.*u-1.))*.11*v
			var normal: Vector3=(Vector3.UP*(.67 if grows_up else .42)+radial*.52+span.normalized()*(u-.5)*.45).normalized()
			var tint: float=brightness*(lerpf(.64,1.03,v) if grows_up else lerpf(1.,.89,v))
			surface.set_color(Color(tint,tint,tint))
			surface.set_normal(normal)
			surface.set_uv(uv.position+uv.size*Vector2(u,1.-v if grows_up else v))
			surface.add_vertex(foot+span*(u-.5)+axis*v+radial*bend)
