extends RefCounted
## Rigid ornaments and embroidery for garments sold at the palace silk office.
const G = preload("res://scripts/geometry.gd")
const Shell = preload("res://scripts/appearance/winter_outfit.gd")

# A bevel catches the light around the silk board and the edge of the silver lock.
# Triangulating both faces keeps the lobed outline and its UVs intact on rotation.
static func plaque(parent: Node3D, center: Vector3, outline: PackedVector2Array, depth: float, material: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if Geometry2D.is_polygon_clockwise(outline):
		outline = outline.duplicate()
		outline.reverse()
	var triangles := Geometry2D.triangulate_polygon(outline)
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		bounds = bounds.expand(point)
	for side: float in [-1., 1.]:
		for i in range(0, triangles.size(), 3):
			var face := [triangles[i], triangles[i + 1], triangles[i + 2]]
			if side > 0.: face.reverse()
			for index: int in face:
				var p := outline[index]
				st.set_uv((p - bounds.position) / bounds.size)
				st.set_normal(Vector3.BACK * side)
				st.add_vertex(Vector3(p.x, p.y, side * depth))
		for i in outline.size():
			var a := outline[i]
			var b := outline[(i + 1) % outline.size()]
			var edge := (b - a).normalized()
			var normal := Vector3(edge.y, -edge.x, side * .4).normalized()
			var band := [Vector3(a.x,a.y,side*depth), Vector3(b.x,b.y,side*depth),
				Vector3(a.x*1.035,a.y*1.035,0), Vector3(b.x*1.035,b.y*1.035,0)]
			var indices := [0, 1, 2, 1, 3, 2]
			if side < 0.: indices.reverse()
			for index: int in indices:
				var v: Vector3 = band[index]
				st.set_uv((Vector2(v.x,v.y) - bounds.position) / bounds.size)
				st.set_normal(normal)
				st.add_vertex(v)
	st.index()
	return G.mesh(parent, st.commit(), center, material)

static func blossom(parent: Node3D, at: Vector3, radius: float, fabric: Material, center: Material) -> void:
	for tier in 2:
		var count_ := 8 if tier == 0 else 5
		var size_ := radius * (1. if tier == 0 else .60)
		for i in count_:
			var angle := TAU * i / count_ + tier * .31
			var offset := Vector3(cos(angle)*size_*.48, sin(angle)*size_*.48, tier*radius*.22)
			var petal := G.ball(parent, at + offset, Vector3(size_*.57,size_*.30,size_*.22), fabric)
			petal.rotation.z = angle
	G.ball(parent, at + Vector3.BACK * radius * .46, Vector3.ONE * radius * .19, center)

static func mian(parent: Node3D, silk: Material, jewel: Material) -> void:
	var gold := G.mat("e8b44f", .31)
	var bronze := G.mat("87552e", .43)
	var pearl := G.mat("f1d59b", .32)
	var front := .20
	G.mesh(parent, Shell.shell("mian-body",[Vector3(-.09,.34,.26),Vector3(-.035,.38,.29),Vector3(.29,.33,.26),Vector3(.34,.32,.245)]), Vector3(0,0,front), silk)
	for ends in [[-.055,-.012,.38,.294],[.265,.31,.34,.27]]:
		G.mesh(parent, Shell.shell("mian-band"+str(ends[0]),[Vector3(ends[0],ends[2],ends[3]),Vector3(ends[1],ends[2],ends[3])]),Vector3(0,0,front),bronze)
		for j in 15:
			var angle := j * TAU / 15.
			G.ball(parent,Vector3(sin(angle)*float(ends[2]),ends[1],front+cos(angle)*float(ends[3])),Vector3(.016,.015,.016),gold)
	# Shallow raised corners and a woven upper surface on the horizontal board.
	var outline := PackedVector2Array([Vector2(-.62,-.38),Vector2(-.57,-.425),Vector2(.57,-.425),Vector2(.62,-.38),Vector2(.62,.37),Vector2(.57,.42),Vector2(-.57,.42),Vector2(-.62,.37)])
	var board := plaque(parent,Vector3(0,.347,front),outline,.025,gold)
	board.rotation.x=PI*.5
	var panel := plaque(parent,Vector3(0,.366,front),outline,.012,silk)
	panel.rotation.x=PI*.5
	panel.scale=Vector3(.952,.932,1.)
	for end: float in [-1.,1.]:
		for j in range(-3,4):
			var x := j*.176
			var top := Vector3(x,.35,front+end*.402)
			var bottom := top+Vector3(x*.045,-.45-.19*absf(x)/.53,end*.023)
			G.capsule(parent,top,bottom,.0065,bronze)
			for k in range(1,8):
				var at := top.lerp(bottom,k/7.)
				var size_ := .025 if k==7 else .015
				G.ball(parent,at,Vector3(size_,size_*1.22,size_),pearl if k%3==0 else gold)
	G.ball(parent,Vector3(0,.133,front+.285),Vector3(.089,.104,.033),gold)
	G.ball(parent,Vector3(0,.134,front+.310),Vector3(.061,.074,.030),jewel)
	for side: float in [-1.,1.]:
		var pin := Vector3(side*.37,.035,front)
		G.ball(parent,pin,Vector3.ONE*.033,pearl)
		var end := pin+Vector3(side*.17,-.47,.10)
		G.capsule(parent,pin,end,.014,silk)

static func qitou(parent: Node3D, silk: Material, petals: Material) -> void:
	var gold := G.mat("c89b5c", .38)
	var pearl := G.mat("f8e9cb", .30)
	var jade := G.mat("508b80", .42)
	# One horizontal satin board with upturned, flared tips, mounted in front of the ears.
	var outline := PackedVector2Array([
		Vector2(-.85,.13),Vector2(-.74,.095),Vector2(-.42,.025),Vector2(-.22,-.015),
		Vector2(.22,-.015),Vector2(.42,.025),Vector2(.74,.095),Vector2(.85,.13),
		Vector2(.91,.38),Vector2(.88,.445),Vector2(.73,.43),Vector2(.39,.34),
		Vector2(0,.285),Vector2(-.39,.34),Vector2(-.73,.43),Vector2(-.88,.445),Vector2(-.91,.38)])
	var front := .225
	G.mesh(parent, Shell.shell("qitou-seat", [Vector3(-.08,.39,.32),Vector3(.015,.42,.33),Vector3(.14,.30,.25)]), Vector3.ZERO, silk)
	plaque(parent, Vector3(0,-.015,front-.075), outline, .075, silk)
	for side: float in [-1., 1.]:
		var stem := Vector3(side*.08,.11,front+.018)
		for i in range(1,9):
			var t := i/8.
			var next := Vector3(side*(.08+.74*t),.11+.14*t+.026*sin(t*TAU),front+.018)
			G.capsule(parent,stem,next,.010,gold)
			if i % 2 == 0:
				var leaf := G.ball(parent,next+Vector3(-side*.03,.031,0),Vector3(.052,.019,.013),jade)
				leaf.rotation.z = -side*.64
			stem = next
	blossom(parent,Vector3(-.36,.23,front+.05),.16,petals,gold)
	blossom(parent,Vector3(-.60,.19,front+.035),.087,pearl,gold)
	blossom(parent,Vector3(.59,.24,front+.04),.095,petals,gold)
	G.ball(parent,Vector3(.018,.14,front+.034),Vector3(.059,.074,.029),gold)
	G.ball(parent,Vector3(.018,.14,front+.056),Vector3(.039,.052,.022),jade)
	for strand in 3:
		var start := Vector3(.74 + strand*.051,.143 + strand*.012,front)
		var end := start + Vector3(.014,-.32+strand*.060,0)
		G.capsule(parent,start,end,.009,gold)
		for j in range(1,5):
			G.ball(parent,start.lerp(end,j/4.),Vector3.ONE*.019,pearl)
		G.ball(parent,end+Vector3.DOWN*.036,Vector3(.023,.046,.023),jade if strand == 0 else petals)

static func longevity_lock(parent: Node3D, rig: Resource, cord: Material, enamel: Material) -> void:
	var silver := G.mat("c9d1d1", .27)
	var bright := G.mat("f6ead3", .31)
	var dark := G.mat("687983", .42)
	var radii: Vector2 = rig.neck_radii
	var front: float = maxf(radii.y+.11,rig.body_radii.z*1.13+.085)
	var lock_at := Vector3(0,-.155,front)
	for side: float in [-1.,1.]:
		var last := lock_at + Vector3(side*.060,.080,0)
		for i in range(1,13):
			var a := PI*i/12.
			var point := Vector3(side*(sin(a)*(radii.x+.032)+.060*maxf(0.,cos(a))),.035-.11*maxf(cos(a),0.),cos(a)*front)
			G.capsule(parent,last,point,.019,cord)
			last = point
	# The shackle, shoulders and two lower bells give the pendant its lock silhouette.
	var last := lock_at + Vector3(-.080,.038,0)
	for i in range(1,13):
		var a := PI*i/12.
		var point := lock_at + Vector3(-.080*cos(a),.038+.083*sin(a),0)
		G.capsule(parent,last,point,.016,silver)
		last = point
	var outline := PackedVector2Array([
		Vector2(0,-.089),Vector2(.065,-.071),Vector2(.114,-.075),Vector2(.157,-.049),
		Vector2(.170,-.010),Vector2(.159,.029),Vector2(.125,.049),Vector2(.091,.046),
		Vector2(.070,.074),Vector2(.032,.092),Vector2(0,.085),Vector2(-.032,.092),
		Vector2(-.070,.074),Vector2(-.091,.046),Vector2(-.125,.049),Vector2(-.159,.029),
		Vector2(-.170,-.010),Vector2(-.157,-.049),Vector2(-.114,-.075),Vector2(-.065,-.071)])
	plaque(parent,lock_at,outline,.025,silver)
	var inset := plaque(parent,lock_at+Vector3.BACK*.026,outline,.008,enamel)
	inset.scale = Vector3(.83,.74,1)
	var brocade := plaque(parent,lock_at+Vector3.BACK*.036,outline,.005,cord)
	brocade.scale = Vector3(.56,.56,1)
	blossom(parent, lock_at+Vector3.BACK*.046, .042, bright, enamel)
	for side: float in [-1.,1.]:
		var eye := lock_at + Vector3(side*.107,-.066,0)
		var bell := eye + Vector3(0,-.061,0)
		G.capsule(parent,eye,bell,.010,silver)
		G.ball(parent,bell,Vector3(.030,.033,.026),silver)
		G.capsule(parent,bell+Vector3(0,-.019,.021),bell+Vector3(0,-.003,.027),.005,dark)

# A round embroidered taiji on the back of the robe, composed of two interlocking fish.
static func taiji(parent: Node3D, at: Vector3, radius: float, trim: Material) -> void:
	var ink := G.mat("293b51", .72)
	var ring := G.ball(parent,at,Vector3(radius*1.12,radius*1.12,.019),trim)
	var ground := G.ball(parent,at+Vector3.FORWARD*.016,Vector3(radius,radius,.016),ink)
	var outline := PackedVector2Array()
	for i in range(25):
		var a := PI*i/24.
		outline.append(radius*Vector2(sin(a),cos(a)))
	for i in range(1,13):
		var a := PI*i/12.
		outline.append(radius*.5*Vector2(sin(a),-1.-cos(a)))
	for i in range(1,12):
		var a := PI*i/12.
		outline.append(radius*.5*Vector2(-sin(a),1.-cos(a)))
	plaque(parent,ground.position+Vector3.FORWARD*.017,outline,.002,trim)
	for side: float in [-1.,1.]:
		G.ball(parent,ring.position+Vector3(0,side*radius*.5,-.039),Vector3(radius*.12,radius*.12,.006),ink if side>0 else trim)

static func robe_details(parent: Node3D, rig: Resource, hem: Vector3, trim: Material) -> void:
	var r: Vector3 = rig.body_radii
	var gold := G.mat("b99a61", .56)
	taiji(parent,Vector3(0,0,-r.z*1.12-.050),r.x*.39,trim)
	for side: float in [-1.,1.]:
		# A rising vapor scroll follows the skirt instead of projecting through its side.
		var last := Vector3.ZERO
		for i in range(27):
			var t := i/26.
			var a := side*(.08+t*.98)
			var wave := .018*sin(t*TAU*1.5)+.030*sin(t*PI)
			var p := Vector3(sin(a)*(hem.y+.003),hem.x+.065+wave,cos(a)*(hem.z+.003))
			if i>0: G.capsule(parent,last,p,.009,trim)
			last = p
	var knot := Vector3(r.x*.74,-r.y*.12,r.z*.81+.065)
	G.ball(parent,knot,Vector3(.046,.042,.025),gold)
	for i in 2:
		var end := knot+Vector3(.028+i*.044,-r.y*(.52-i*.12),.033)
		G.capsule(parent,knot,end,.017,trim)
		G.ball(parent,end,Vector3(.024,.031,.021),gold)

static func dragon_robe(parent: Node3D, rig: Resource, rows: Array, silk_thread: StandardMaterial3D) -> void:
	var r: Vector3 = rig.body_radii
	var dark := G.mat("354454",.58)
	var sea := G.mat("648e88",.55)
	var gold := G.mat("ddae61",.40)
	var key: String = "imperial"+rig.species_id
	G.mesh(parent,Shell.shell(key+"collar",[Vector3(r.y*.70,r.x*.88+.04,r.z*.85+.04),Vector3(r.y*.93,r.x*.56+.03,r.z*.61+.038)]),Vector3.ZERO,dark)
	var thread := silk_thread.duplicate() as StandardMaterial3D
	thread.albedo_texture=preload("res://assets/jade/dragon_roundel.svg")
	thread.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	thread.alpha_scissor_threshold=.4
	thread.cull_mode=BaseMaterial3D.CULL_DISABLED
	# Wrap the embroidery directly around the tapered coat at each height.
	for side: float in [-1.,1.]:
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in 10:
			for k in 12:
				for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
					var uv:=Vector2((k+corner.x)/12.,(j+corner.y)/10.)
					var y:=lerpf(r.y*.71,-r.y*.23,uv.y)
					var tier:=1 if y<=r.y*.24 else (2 if y<=r.y*.64 else 3)
					var low: Vector3=rows[tier];var high: Vector3=rows[tier+1]
					var radii:=low.lerp(high,inverse_lerp(low.x,high.x,y))
					var angle: float=(uv.x-.5)*1.60
					var normal:=Vector3(side*sin(angle),.12,side*cos(angle)).normalized()
					st.set_uv(uv);st.set_normal(normal)
					st.add_vertex(Vector3(side*sin(angle)*(radii.y+.008),y,side*cos(angle)*(radii.z+.010)))
		st.index();G.mesh(parent,st.commit(),Vector3.ZERO,thread)
	var hem: Vector3 = rows[0]
	var waist: Vector3 = rows[1]
	G.mesh(parent,Shell.shell(key+"sash",[waist+Vector3(-.035,.015,.014),waist+Vector3(.005,.007,.009)]),Vector3.ZERO,dark)
	for i in range(48):
		var a:=TAU*i/48.;var b:=TAU*(i+1)/48.
		var h:=.060+.028*cos(6.*a);var next:=.060+.028*cos(6.*b)
		G.capsule(parent,Vector3(sin(a)*hem.y*.995,hem.x+h,cos(a)*hem.z),Vector3(sin(b)*hem.y*.995,hem.x+next,cos(b)*hem.z),.012,sea)
		if i%2==0:
			G.capsule(parent,Vector3(sin(a)*hem.y*.99,hem.x+h+.025,cos(a)*hem.z),Vector3(sin(b)*hem.y*.985,hem.x+next+.060,cos(b)*hem.z*.99),.010,gold)
