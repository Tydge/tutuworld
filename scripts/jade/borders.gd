extends RefCounted
## Peony borders and iris leaves share one baked mesh per species and retain sculpted flower silhouettes.
const G=preload("res://scripts/geometry.gd")
const Grove=preload("res://scripts/jade/grove.gd")
const J=preload("res://scripts/jade/layout.gd")
static var plants: Dictionary={}
static func petal(st: SurfaceTool,p: Vector3,angle: float,long: float,wide: float,tint: Color,cup: float) -> void:
	var stem:=Vector3(cos(angle),0,sin(angle));var side:=Vector3(-stem.z,0,stem.x)
	var spine:=p+stem*long*.55+Vector3.UP*(cup*.35)
	var outline: Array=[p,p+stem*long*.42+side*wide*.78,p+stem*long*.89+side*wide*.72+Vector3.UP*cup,p+stem*long+Vector3.UP*cup*.96,p+stem*long*.91-side*wide*.69+Vector3.UP*cup,p+stem*long*.43-side*wide*.68]
	for k in range(6):
		for v in [spine,outline[k],outline[(k+1)%6]]:
			st.set_color((tint.lightened(.10) if v.y>p.y+cup*.8 else tint).srgb_to_linear())
			st.set_normal((Vector3.UP-stem*.31).normalized());st.add_vertex(v)
static func flower_mesh(iris: bool) -> ArrayMesh:
	if plants.has(iris):return plants[iris]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng:=RandomNumberGenerator.new();rng.seed=59012+int(iris)
	for i in range(33):
		var root:=Vector3(rng.randf_range(-1.96,1.96),0,rng.randf_range(-.61,.61))
		var h:=rng.randf_range(.37,.83)
		for j in range(6 if iris else 8):
			var a:=j*2.4+rng.randf();var direction:=Vector3(cos(a)*.4,h*rng.randf_range(.6,1.27),sin(a)*.4)
			Grove.blade(st,root,direction,.038 if iris else .092,Color("345438").lerp(Color("7d9854"),rng.randf()),false)
		if i%2!=0:continue
		var tip:=root+Vector3(.07,h,.04)
		Grove.blade(st,root,tip-root,.014,Color("5f793c"),false)
		if iris:
			for j in range(3):
				petal(st,tip,j*TAU/3.+i,.115,.048,Color("66599f"),-.055)
				petal(st,tip,j*TAU/3.+i+.36,.069,.031,Color("c2a9df"),.095)
		else:
			var tint:=Color("a74458").lerp(Color("edb7ab") if i%3 else Color("e8d7ad"),rng.randf())
			for tier in range(3):
				for j in range(7-tier):
					petal(st,tip+Vector3.UP*tier*.024,j*TAU/(7-tier)+tier*.52+i,.169-tier*.043,.078-tier*.012,tint.lightened(tier*.06),.064-tier*.009)
	st.index()
	var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=.94;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	st.set_material(mat);plants[iris]=st.commit();return plants[iris]
static func make(n: Node3D,iris: bool) -> void:
	var art=load("res://scripts/jade/architecture.gd")
	art.mesh_part(n,"IrisBed" if iris else "PeonyBed",func(m):
		art.paint(m,Vector3.UP*.14,Vector3(4.58,.28,1.75),"masonry")
		art.box(m,Vector3.UP*.30,Vector3(4.36,.12,1.51),"625544")
		for side in [-1,1]:
			art.paint(m,Vector3(0,.34,side*.86),Vector3(4.61,.14,.12),"lotus_marble")
			art.paint(m,Vector3(side*2.25,.34,0),Vector3(.12,.14,1.60),"lotus_marble"))
	G.mesh(n,flower_mesh(iris),Vector3.UP*.33,null,"SeasonalFlowers")
	preload("res://scripts/city/prop_collisions.gd").box(n,"Planter",Vector3.UP*.20,Vector3(4.5,.4,1.7))
static func dress(builder: SceneTree) -> void:
	for p in [Vector2(-30,-93),Vector2(30,-92),Vector2(-12,-110),Vector2(12,-110),Vector2(-12,-130),Vector2(12,-130),Vector2(-18,-150),Vector2(18,-150),Vector2(49,-147),Vector2(-48,-147),Vector2(125,-28),Vector2(127,-43),Vector2(-94,-40),Vector2(-119,-32),Vector2(-29,57),Vector2(52,57)]:
		builder.fixture(builder.world,"jade_peony",J.point(p.x,p.y),.17*sin(p.x))
	for p in [Vector2(-27,-16),Vector2(25,-15),Vector2(77,-17),Vector2(134,-14),Vector2(-76,-26),Vector2(-85,-16),Vector2(120,-52),Vector2(-121,-52),Vector2(-44,120),Vector2(30,72),Vector2(-32,157),Vector2(29,157)]:
		builder.fixture(builder.world,"jade_iris",J.point(p.x,p.y),.38*sin(p.x))
