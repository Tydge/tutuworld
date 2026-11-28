extends RefCounted
## Purchased Yujing garments. Each rigid attachment is combined once per cut, species and dye.
const G=preload("res://scripts/geometry.gd")
const Shell=preload("res://scripts/appearance/winter_outfit.gd")
const Art=preload("res://scripts/jade/architecture.gd")
const Palace = preload("res://scripts/jade/palace_clothes.gd")
static var pieces: Dictionary={}
const GOLD="d5a856"
static func fit(root: Node3D,rig: Resource,item: Dictionary,cloth: Material) -> void:
	var style:=str(item.style)
	var key:=str([rig.species_id,style,item.color,item.accent,item.get("pattern","solid")])
	var trim:=G.mat(item.accent,.54)
	if item.slot=="head":
		root.position=rig.bow_offset if style=="peony_pin" else rig.hat_offset
		root.scale=rig.headwear_scale
		build_piece(root,key,head.bind(style,cloth,trim))
	elif item.slot=="neck":
		root.position=rig.neck_center
		build_piece(root,key,neck.bind(rig,style,cloth,trim))
	else:
		root.position=rig.body_center
		build_piece(root,key,robe.bind(rig,style,cloth,trim))
		for side in ["Left","Right"]:
			var arm:=root.get_parent().get_node_or_null(side+"Arm")
			if not arm:continue
			var cuff:=Node3D.new();cuff.name="Wardrobe_body_sleeve";arm.add_child(cuff)
			cuff.rotation.z=.12 if side=="Right" else -.12
			build_piece(cuff,key+"-sleeve",sleeve.bind(rig,style,cloth,trim))
static func build_piece(n: Node3D,key: String,draw: Callable) -> void:
	if not pieces.has(key):
		draw.call(n)
		var combine: Dictionary={}
		for obj in n.get_children():
			var mesh:=obj as MeshInstance3D
			if not mesh:continue
			var mat:=mesh.material_override
			if mesh.mesh is SphereMesh:mesh.mesh.radial_segments=12;mesh.mesh.rings=5
			if mesh.mesh is CapsuleMesh:mesh.mesh.radial_segments=8;mesh.mesh.rings=2
			if mesh.mesh is CylinderMesh:mesh.mesh.radial_segments=16;mesh.mesh.rings=0
			if not combine.has(mat):
				var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);combine[mat]=st
			G.append_indexed(combine[mat],mesh.mesh,0,mesh.transform)
			mesh.free()
		var merged:=ArrayMesh.new()
		for mat in combine:
			var st: SurfaceTool=combine[mat];st.set_material(mat);st.commit(merged)
		if pieces.size()>=112:pieces.erase(pieces.keys()[0])
		pieces[key]=merged
	G.mesh(n,pieces[key],Vector3.ZERO,null,"Tailoring")
static func line(n: Node3D,a: Vector3,b: Vector3,r: float,m: Material) -> void:G.capsule(n,a,b,r,m)
static func tassel(n: Node3D,p: Vector3,length_: float,m: Material) -> void:
	var gold:=G.mat(GOLD,.34)
	G.ball(n,p,Vector3(.023,.029,.023),gold)
	G.cylinder(n,p+Vector3.DOWN*length_*.54,.031,length_,m,.012)
static func petal(n: Node3D,p: Vector3,size_: Vector3,a: float,m: Material) -> void:
	var q:=G.ball(n,p,size_,m);q.rotation.z=a
static func head(n: Node3D,style: String,cloth: Material,trim: Material) -> void:
	var gold:=G.mat(GOLD,.34)
	match style:
		"peony_qitou":
			Palace.qitou(n,cloth,trim)
		"reed_hat":
			var brim: Array=[Vector3(-.12,.78,.68),Vector3(-.085,.80,.70),Vector3(.055,.57,.48),Vector3(.26,.27,.22),Vector3(.36,.085,.07),Vector3(.36,.001,.001)]
			G.mesh(n,Shell.shell("market-reed",brim),Vector3.ZERO,cloth)
			for j in 16:
				var a:=j*TAU/16.
				line(n,Vector3(sin(a)*.782,-.088,cos(a)*.683),Vector3(sin(a+.20)*.10,.35,cos(a+.20)*.08),.009,trim)
			for j in 3:
				var t: float=j*.18+.14
				G.mesh(n,Shell.shell("hat-weft"+str(j),[Vector3(-.09+t*.44,.80-.73*t,.70-.64*t),Vector3(-.077+t*.44,.79-.73*t,.69-.64*t)]),Vector3.ZERO,trim)
			tassel(n,Vector3(.55,-.055,.21),.18,trim)
		"indigo_wrap":
			G.mesh(n,Shell.shell("market-wrap",[Vector3(-.09,.46,.40),Vector3(.02,.52,.45),Vector3(.15,.46,.40),Vector3(.27,.24,.23),Vector3(.29,.001,.001)]),Vector3.ZERO,cloth)
			var band:=G.mesh(n,Shell.shell("kerchief-band",[Vector3(-.07,.51,.445),Vector3(.055,.516,.448)]),Vector3.ZERO,Art.finish("fish_resist"));band.rotation.z=.09
			for s in [-1,1]:
				petal(n,Vector3(.42+s*.082,.09,-.07),Vector3(.078,.18,.08),-s*.77,cloth)
				petal(n,Vector3(.46+s*.05,-.10,-.08),Vector3(.065,.18,.05),s*.25,trim)
		"peony_pin":
			line(n,Vector3(-.29,-.12,0),Vector3(.24,.20,0),.019,gold)
			for ring in 2:
				for j in (7 if ring==0 else 5):
					var a:=TAU*j/(7. if ring==0 else 5.)+ring*.23
					var radius:=.114 if ring==0 else .06
					petal(n,Vector3(cos(a)*radius,sin(a)*radius,.04+ring*.04),Vector3(.103-ring*.026,.064,.034),a,cloth if ring==0 else trim)
			G.ball(n,Vector3(0,0,.14),Vector3.ONE*.038,gold)
			for j in 3:
				var p:=Vector3(-.11+j*.065,-.17-j%2*.072,.055)
				line(n,Vector3(p.x,-.03,.055),p,.008,gold)
				tassel(n,p,.09,G.mat("78ae9f",.32))
		"lotus_crown":
			G.mesh(n,Shell.shell("lotus-seat",[Vector3(-.06,.41,.35),Vector3(.00,.47,.38),Vector3(.11,.38,.32)]),Vector3.ZERO,cloth)
			for j in 7:
				var a:=j*TAU/7.
				var p:=Vector3(sin(a)*.32,.04,cos(a)*.26)
				var height_:=.30+.09*cos(a)
				var leaf:=lotus_leaf(n,p,.121,height_,gold);leaf.rotation.y=a
				var inlay:=lotus_leaf(n,p+Vector3(sin(a)*.023,.019,cos(a)*.023),.067,height_*.74,trim);inlay.rotation.y=a
			G.ball(n,Vector3(0,.24,-.02),Vector3(.12,.19,.11),cloth)
			line(n,Vector3(-.52,.06,0),Vector3(.52,.06,0),.019,gold)
			tassel(n,Vector3(-.52,.06,0),.20,trim)
static func lotus_leaf(n: Node3D,p: Vector3,w: float,h: float,mat: Material) -> MeshInstance3D:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline: Array[Vector3]=[Vector3(0,0,0),Vector3(-w,.28*h,.035),Vector3(-w*.76,.69*h,.07),Vector3(0,h,.092),Vector3(w*.76,.69*h,.07),Vector3(w,.28*h,.035)]
	var ridge:=Vector3(0,h*.46,.10)
	for j in outline.size():
		for vertex in [outline[j],ridge,outline[(j+1)%outline.size()],outline[j],outline[(j+1)%outline.size()],ridge]:
			st.set_normal(Vector3.BACK);st.add_vertex(vertex)
	return G.mesh(n,st.commit(),p,mat)
static func neck(n: Node3D,rig: Resource,style: String,cloth: Material,trim: Material) -> void:
	var r: Vector2=rig.neck_radii
	var gold:=G.mat(GOLD,.32)
	var front:=maxf(r.y+.07,rig.body_radii.z+.08)
	var p:=Vector3(0,-.10,front)
	if style=="ruyi_lock":
		Palace.longevity_lock(n,rig,cloth,trim)
		return
	if style=="cloud_collar":
		var brocatelle:=cloth.duplicate() as ShaderMaterial
		brocatelle.shader=preload("res://assets/shaders/fabric_double_sided.gdshader")
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var edge: Array[Vector3]=[]
		for j in 65:
			var a:=j*TAU/64.
			var lobe:=pow(.5+.5*cos(4.*a),1.6)
			var x: float=sin(a)*(rig.body_radii.x*1.06+.05+.09*lobe)
			var z: float=cos(a)*(rig.body_radii.z*1.11+.08+.055*lobe)
			edge.append(Vector3(x,-.038-.19*lobe,z))
			if j==0:continue
			for c in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var idx: int=j-1+c.x;var ang:=idx*TAU/64.
				var v:=Vector3(sin(ang)*r.x,.073,cos(ang)*r.y) if c.y==0 else edge[idx]
				st.set_uv(Vector2(idx/64.,c.y));st.set_normal(Vector3(sin(ang),.6,cos(ang)).normalized());st.add_vertex(v)
		st.index();G.mesh(n,st.commit(),Vector3.ZERO,brocatelle)
		for j in range(0,64,2):line(n,edge[j],edge[j+2],.010,gold)
		for j in 4:
			var q:=edge[j*16]
			tassel(n,q,.092,trim)

		return
	for side in [-1,1]:
		var last:=p
		for j in range(1,8):
			var a: float=j*PI/7.
			var q:=Vector3(side*sin(a)*(r.x+.035),-.14+.15*sin(a*.56),cos(a)*front)
			line(n,last,q,.014,trim);last=q
	match style:
		"knot_cord":
			for j in 4:
				var a:=j*PI/2
				var last:=p
				for k in range(1,9):
					var t:=k*TAU/8.;var q:=p+Vector3(cos(a)*(.054-.054*cos(t))-sin(a)*.036*sin(t),sin(a)*(.054-.054*cos(t))+cos(a)*.036*sin(t),.018*sin(2.*t))
					line(n,last,q,.016,cloth);last=q
			for side in [-1,1]:tassel(n,p+Vector3(side*.048,-.077,.008),.12,cloth)
		"herb_pouch":
			var purse:=G.ball(n,p,Vector3(.141,.133,.06),cloth);purse.rotation.z=.13
			G.ball(n,p+Vector3(0,.10,0),Vector3(.094,.036,.049),trim)
			for j in 5:
				var a:=j*TAU/5.;petal(n,p+Vector3(cos(a)*.04,sin(a)*.04,.057),Vector3(.045,.024,.012),a,trim)
			tassel(n,p+Vector3.DOWN*.117,.073,gold)
		"jade_disc":
			var ring:=TorusMesh.new();ring.inner_radius=.055;ring.outer_radius=.137;ring.rings=24;ring.ring_segments=8
			G.mesh(n,ring,p,cloth).rotation.x=PI/2
			for side in [-1,1]:
				var q:=p+Vector3(side*.056,-.12,.016)
				line(n,q,p+Vector3(side*.073,-.18,.02),.009,gold)
				tassel(n,p+Vector3(side*.073,-.18,.02),.087,trim)
static func sleeve(n: Node3D,rig: Resource,style: String,cloth: Material,trim: Material) -> void:
	var court:=style in ["crane_robe","vermilion_skirt","cloud_dao_robe"]
	var w: float=rig.sleeve_radius*(1.92 if court else 1.20)+.025
	var end: float=absf(rig.grip_offset.y)*(.92 if court else .67)
	G.mesh(n,Shell.shell(style+rig.species_id+"market-sleeve",[Vector3(-end,w,w*.83),Vector3(-end*.61,w*.89,w*.86),Vector3(-.06,w*.79,w*.72),Vector3(.055,w*.65,w*.63)]),Vector3.ZERO,cloth)
	G.mesh(n,Shell.shell(style+rig.species_id+"market-cuff",[Vector3(-end-.006,w+.005,w*.83+.005),Vector3(-end+.047,w+.003,w*.84+.003)]),Vector3.ZERO,trim)
	if court:
		var lining:=G.mat("f1dec0",.74)
		G.mesh(n,Shell.shell(style+rig.species_id+"turned-lining",[Vector3(-end-.02,w*.91,w*.75),Vector3(-end-.005,w+.003,w*.83+.005)]),Vector3.ZERO,lining)
# A fitted strip follows the chest and skirt instead of cutting a flat badge into the belly.
static func panel(n: Node3D,rows: Array,material: Material) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(rows.size()-1):
		for k in 8:
			for c in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var row: Vector4=rows[j+c.y]
				var u: float=(k+c.x)/8.;var lateral: float=u*2.-1.
				st.set_uv(Vector2(u,(j+c.y)/float(rows.size()-1)));st.set_normal(Vector3.BACK)
				st.add_vertex(Vector3(row.x+lateral*row.z,row.y,row.w-.032*lateral*lateral))
	st.index();G.mesh(n,st.commit(),Vector3.ZERO,material)
static func robe(n: Node3D,rig: Resource,style: String,cloth: Material,trim: Material) -> void:
	var r: Vector3=rig.body_radii;var key: String=style+rig.species_id
	var court:=style in ["crane_robe","vermilion_skirt","cloud_dao_robe"]
	var skirt:=style=="vermilion_skirt"
	var length_: float=r.y*(.93 if court else .58)
	var flare := 1.31 if court else 1.07
	if style=="cloud_dao_robe":
		length_ = r.y*1.10
		flare = 1.18
	var rows: Array=[Vector3(-length_,r.x*flare+.04,r.z*(1.21 if court else 1.05)+.035),Vector3(-r.y*.26,r.x*1.11+.03,r.z*1.10+.04),Vector3(r.y*.24,r.x*1.06+.036,r.z*1.05+.04),Vector3(r.y*.64,r.x*.92+.033,r.z*.94+.03),Vector3(r.y*.91,r.x*.56+.02,r.z*.61+.03)]
	G.mesh(n,Shell.shell(key+"market",rows),Vector3.ZERO,cloth)
	var hem: Vector3=rows[0]
	G.mesh(n,Shell.shell(key+"market-hem",[hem+Vector3(-.005,.005,.005),hem+Vector3(.045,.009,.009)]),Vector3.ZERO,trim)
	# Right-closing lapel: one continuous diagonal over a short glimpse of the undercollar.
	panel(n,[Vector4(-r.x*.45,r.y*.77,.046,r.z*.81+.07),Vector4(-r.x*.22,r.y*.48,.054,r.z*1.03+.045),Vector4(r.x*.20,r.y*.16,.053,r.z*1.08+.065),Vector4(r.x*.61,-r.y*.07,.050,r.z*.98+.055)],trim)
	panel(n,[Vector4(r.x*.40,r.y*.77,.033,r.z*.82+.07),Vector4(.0,r.y*.32,.04,r.z*1.06+.055)],trim)
	var waist:=r.y*(.21 if skirt else -.13)
	G.mesh(n,Shell.shell(key+"market-belt",[Vector3(waist-.04,r.x*1.12+.039,r.z*1.11+.044),Vector3(waist+.033,r.x*1.12+.04,r.z*1.11+.046)]),Vector3.ZERO,trim)
	match style:
		"cloud_dao_robe":
			Palace.robe_details(n,rig,hem,trim)
		"crane_robe":
			panel(n,[Vector4(0,r.y*.22,r.x*.64,r.z*1.11+.075),Vector4(0,-r.y*.23,r.x*.64,r.z*1.14+.083),Vector4(0,-r.y*.70,r.x*.64,r.z*1.21+.082)],Art.finish("crane_badge"))
		"vermilion_skirt":
			var pleats:=SurfaceTool.new();pleats.begin(Mesh.PRIMITIVE_TRIANGLES)
			for j in 48:
				for c in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
					var idx: int=j+c.x;var ang:=idx*TAU/48.;var bottom: bool=c.y==1
					var width: float=(1.025+.084*(idx%2)) if bottom else 1.
					var radius_x: float=hem.y*width if bottom else r.x*1.13+.038
					var radius_z: float=hem.z*width if bottom else r.z*1.13+.045
					pleats.set_normal(Vector3(sin(ang+.24*(1 if idx%2==0 else -1)),.12,cos(ang+.24*(1 if idx%2==0 else -1))).normalized())
					pleats.set_uv(Vector2(idx/48.,c.y))
					pleats.add_vertex(Vector3(sin(ang)*radius_x,-length_+.016 if bottom else waist-.035,cos(ang)*radius_z))
			pleats.index();G.mesh(n,pleats.commit(),Vector3.ZERO,cloth)
			for j in range(13):
				var a:=j*TAU/13.;var q:=Vector3(sin(a)*hem.y,-length_+.035,cos(a)*hem.z)
				line(n,q,Vector3(sin(a)*(r.x*1.13+.04),waist-.03,cos(a)*(r.z*1.13+.04)),.012,trim)
			panel(n,[Vector4(0,waist-.035,r.x*.57,r.z*1.12+.08),Vector4(0,-r.y*.42,r.x*.62,r.z*1.20+.10),Vector4(0,-length_+.05,r.x*.68,hem.z*1.12+.036)],Art.finish("peony_apron"))
		"ferry_coat":
			panel(n,[Vector4(-r.x*.22,-r.y*.17,r.x*.39,r.z*1.13+.064),Vector4(-r.x*.24,-length_+.04,r.x*.40,r.z*1.13+.065)],Art.finish("fish_resist"))
			for j in 2:tassel(n,Vector3(r.x*.75,-r.y*.18,r.z*.96),.13+j*.045,trim)
		"field_jacket":
			for j in 3:
				var p:=Vector3(r.x*(.58-j*.10),r.y*(.06-j*.17),r.z*1.04+.057)
				line(n,p-Vector3.RIGHT*.04,p+Vector3.RIGHT*.042,.012,trim)
				G.ball(n,p+Vector3.RIGHT*.048,Vector3.ONE*.021,trim)
