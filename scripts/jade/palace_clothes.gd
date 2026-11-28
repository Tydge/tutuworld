extends RefCounted
## Rigid ornaments and embroidery for the three pieces sold at the palace silk office.
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
