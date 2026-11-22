extends RefCounted
## Timber lean-tos extend the usable shop threshold. Wool or silk hangs from bound rafter ends.
const G=preload("res://scripts/geometry.gd")
const J=preload("res://scripts/jade/layout.gd")
static var fabrics: Dictionary={}
static func canvas(m: Node3D,width: float,depth: float,y: float,blue: bool) -> void:
	var sheet:=SurfaceTool.new();sheet.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hem:=SurfaceTool.new();hem.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(16):
		for j in range(5):
			for uv in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var u: float=(i+uv.x)/16.;var v: float=(j+uv.y)/5.
				var sag: float=sin(PI*u)*.11+sin(v*PI)*.083+v*(.048*cos(u*TAU*5.))
				sheet.set_uv(Vector2(u*1.55,v*.75));sheet.add_vertex(Vector3((u-.5)*width,y-.30*v-sag,(v-.5)*depth))
		for uv in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
			var u: float=(i+uv.x)/16.;var v: float=uv.y
			var drop:=.19+.10*sin(u*TAU*4.)*sin(u*TAU*4.)
			hem.set_uv(Vector2(u*3.,v*.13));hem.add_vertex(Vector3((u-.5)*width,y-.30-.11*sin(PI*u)-.048*cos(u*TAU*5.)-drop*v,depth*.5+.028*v))
	if not fabrics.has(blue):
		var mat:=StandardMaterial3D.new();mat.albedo_texture=preload("res://assets/jade/swallows.png") if blue else preload("res://assets/jade/brocade.png");mat.albedo_color=Color("c9c4ac") if blue else Color("ecba8f");mat.roughness=.94;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;fabrics[blue]=mat
	for st in [sheet,hem]:
		st.index();st.generate_normals();G.mesh(m,st.commit(),Vector3.ZERO,fabrics[blue])
static func make(n: Node3D) -> void:
	var a=load("res://scripts/jade/architecture.gd")
	a.mesh_part(n,"ShopVeranda",func(m):
		for side in [-1.,1.]:
			var x: float=side*2.68
			a.column(m,Vector3(x,1.55,1.36),.102,3.1)
			a.paint(m,Vector3(x,.13,1.36),Vector3(.34,.26,.34),"masonry")
			a.beam(m,Vector3(x,3.11,1.54),Vector3(x,3.62,-1.58),.14,"614c39")
			a.beam(m,Vector3(x,2.57,1.36),Vector3(x,3.12,.73),.10,"886544")
			a.beam(m,Vector3(x,2.71,1.36),Vector3(x-side*.64,3.11,1.36),.09,"765b40")
		a.paint(m,Vector3(0,3.12,1.36),Vector3(5.67,.21,.23),"lacquer")
		canvas(m,5.93,3.28,3.57,true))
	for side in [-1.,1.]:preload("res://scripts/city/prop_collisions.gd").cylinder(n,"VerandaPost",Vector3(side*2.68,1.55,1.36),.11,3.1)
static func dress(builder: SceneTree) -> void:
	for h in J.HOUSES:
		if h[3]<43 or h[3]>190 or absf(h[2])>23 or h[4]=="theatre":continue
		var room:=builder.world.get_node(("Shop_" if J.shops().has(h[0]) else "Hall_")+h[0]) as Node3D
		var face:=room.get_node("Front") as Node3D;var d:=J.dims(h[4])
		var x: float=(d.x-3.17)*(-1 if int(h[3])%2 else 1)
		if h[4]!="forge":builder.fixture(face,"jade_shop_veranda",Vector3(x,0,d.z+1.36))
		var wares: String={"tea":"jade_ceramics","incense":"jade_ceramics","spice":"jade_steam_table","almond":"jade_pastry_board","tools":"jade_smith_rack","clothes":"jade_silk_rack","furniture":"jade_screen","farm":"jade_seed_bins","oil":"jade_goods","basket":"jade_goods","stitch":"jade_silk_rack"}.get(h[0],"")
		if wares!="":
			var display_x:=maxf(3.85,d.x*.67)*signf(-x)
			builder.fixture(face,wares,Vector3(display_x,0,d.z+1.04))

static func display_bay(m: Node3D,center: Vector3,w: float,h: float,forge: bool) -> void:
	var a=load("res://scripts/jade/architecture.gd")
	var n: Node3D=a.group(m,"TradeWindow",center)
	a.box(n,Vector3(0,0,.06),Vector3(w,h,.15),"4e3f32")
	for j in range(5):
		var slat:=a.paint(n,Vector3((j-2)*w*.18,0,.16),Vector3(w*.171,h*.91,.055),"wood_relief") as MeshInstance3D
		slat.scale.z=.85
	for k in [-1,1]:
		var side:=a.group(n,"OpenShutter",Vector3(k*w*.50,0,.38)) as Node3D
		side.rotation.y=-k*.89
		a.paint(side,Vector3(k*w*.13,0,0),Vector3(w*.26,h*.93,.115),"lacquer")
		for j in range(6):
			a.box(side,Vector3(k*w*.13,(j-2.5)*h*.13,.078),Vector3(w*.24,.045,.073),"a18a61")
		a.box(n,Vector3(k*w*.53,0,.34),Vector3(.13,h+.22,.55),"78523b")
	a.paint(n,Vector3(0,-h*.50,.38),Vector3(w+.42,.14,.95),"wood_relief")
	a.paint(n,Vector3(0,.03,.34),Vector3(w,.10,.60),"lacquer")
	for j in range(4):
		var x: float=(j-1.5)*w*.23
		if forge:
			a.box(n,Vector3(x,-h*.32,.48),Vector3(w*.15,.14,.32),"888e80")
			a.box(n,Vector3(x,.16,.43),Vector3(w*.12,.21,.27),"a68356")
		else:
			var ceramic:=G.mat("78a099" if j%2 else "dbccb0",.45)
			G.cylinder(n,Vector3(x,-h*.33,.52),.16,.21,ceramic,.22)
			G.cylinder(n,Vector3(x,.22,.43),.112,.29,G.mat("84977d",.52),.082)
