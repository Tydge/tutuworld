extends RefCounted
const G=preload("res://scripts/geometry.gd")
const Shell=preload("res://scripts/appearance/winter_outfit.gd")
static func thread(n: Node3D,a: Vector3,b: Vector3,r: float,m: Material) -> void:G.capsule(n,a,b,r,m)
static func flower(n: Node3D,p: Vector3,rad: float,cloth: Material,heart: Material,petals: int=6) -> void:
	for i in range(petals):
		var a:=i*TAU/petals;var petal:=G.ball(n,p+Vector3(cos(a),sin(a),0)*rad*.53,Vector3(rad*.52,rad*.28,rad*.18),cloth)
		petal.rotation.z=a
	G.ball(n,p+Vector3.BACK*rad*.18,Vector3.ONE*rad*.23,heart)
static func fit(root: Node3D,rig: Resource,item: Dictionary,cloth: Material) -> void:
	if item.get("rank","") in ["folk","court"]:
		preload("res://scripts/jade/market_clothes.gd").fit(root,rig,item,cloth)
		return
	var trim:=G.mat(item.accent,.52);var gold:=G.mat("d8ac65",.34);var style: String=item.style
	if item.slot=="head":
		root.position=rig.hat_offset;root.scale=rig.headwear_scale
		match style:
			"night_moth":
				root.position=rig.bow_offset
				for side in [-1,1]:
					var wing:=G.ball(root,Vector3(side*.10,.07,.04),Vector3(.092,.185,.027),cloth);wing.rotation.z=-side*.66
					flower(root,Vector3(side*.12,.09,.074),.043,trim,gold,4)
			"star_circlet":
				G.mesh(root,Shell.shell(style,[Vector3(-.04,.41,.33),Vector3(.02,.45,.37),Vector3(.068,.43,.34)]),Vector3.ZERO,cloth)
				for j in range(7):
					var a:=TAU*j/7.;var p:=Vector3(sin(a)*.40,.10,cos(a)*.33)
					G.ball(root,p,Vector3(.035,.052,.032),trim)
				G.ball(root,Vector3(0,.07,.37),Vector3(.072,.088,.031),trim)
	elif item.slot=="neck":
		root.position=rig.neck_center;var r: Vector2=rig.neck_radii
		G.mesh(root,Shell.shell(style+rig.species_id,[Vector3(-.029,r.x+.025,r.y+.033),Vector3(0,r.x+.043,r.y+.039),Vector3(.036,r.x+.019,r.y+.025)]),Vector3.ZERO,cloth)
		var p:=Vector3(0,-.10,maxf(r.y+.065,rig.body_radii.z+.06))
		match style:
			"lace_ruff":
				for i in range(16):
					var a:=i*TAU/16.;var petal:=G.ball(root,Vector3(sin(a)*(r.x+.018),-.060,cos(a)*(r.y+.04)),Vector3(.068,.068,.045),cloth if i%2==0 else trim)
					petal.rotation.y=a;petal.rotation.x=-.31
			"constellation":
				for j in range(5):
					var t: float=(j-2)/2.;var star:=p+Vector3(t*.17,t*t*.13,0);G.ball(root,star,Vector3.ONE*(.032 if j==2 else .021),trim)
					if j>0:thread(root,star,p+Vector3((t-.5)*.17,(t-.5)*(t-.5)*.13,0),.009,gold)
	else:
		root.position=rig.body_center
		var r: Vector3=rig.body_radii
		var wide:=style in ["aurora_coat","tide_mantle"]
		var cape:=style=="tide_mantle";var length_:=.33 if cape else (.91 if wide else .67)
		var key: String=rig.species_id+style
		var rows: Array=[Vector3(-r.y*length_,r.x*(1.21 if wide else .91)+.02,r.z*(1.19 if wide else .91)+.02),Vector3(-r.y*.36,r.x*1.05+.02,r.z*1.05+.025),Vector3(0,r.x*1.07+.02,r.z*1.07+.03),Vector3(r.y*.42,r.x+.025,r.z+.033),Vector3(r.y*.74,r.x*.81+.02,r.z*.81+.03),Vector3(r.y*.93,r.x*.53+.02,r.z*.53+.03)]
		G.mesh(root,Shell.shell(key,rows),Vector3.ZERO,cloth,"CrossedRobe")
		var hem: Vector3=rows[0];G.mesh(root,Shell.shell(key+"hem",[hem+Vector3(-.007,.004,.004),hem+Vector3(.032,.007,.007)]),Vector3.ZERO,trim)
		for side in [-1,1]:
			var last:=Vector3(side*r.x*.40,r.y*.78,r.z*.67+.037)
			for i in range(1,9):
				var t:=i/8.;var x: float=side*r.x*(.40-.69*t)
				var y: float=r.y*(.78-.84*t)
				var z: float=r.z*sqrt(maxf(.15,1.-pow(x/(1.09*r.x),2)-pow(y/(r.y*1.13),2)))+.065
				var next:=Vector3(x,y,z);thread(root,last,next,.024 if wide else .016,trim);last=next
		var sash:=rows[2] as Vector3
		G.mesh(root,Shell.shell(key+"sash",[Vector3(-.065,sash.y+.012,sash.z+.008),Vector3(-.014,sash.y+.014,sash.z+.010)]),Vector3.ZERO,trim)
		if wide:
			for j in range(7):
				var a: float=(j-3)*.34
				var p:=Vector3(sin(a)*hem.y*.999,hem.x+.067,cos(a)*hem.z*1.02)
				if style=="aurora_coat":G.ball(root,p,Vector3.ONE*.023,gold)
				else:thread(root,p,p+Vector3(.054,.035,.008),.011,trim)

		extra_layers(root,rig,item,cloth,trim,gold)

static func pleated_overlay(root: Node3D,r: Vector3,cloth: Material) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(48):
		for k in range(4):
			for uv in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				var u: float=(j+uv.x)/48.;var v: float=(k+uv.y)/4.;var angle:=u*TAU
				var spread:=1.08+v*.18+cos(angle*12.)*.04*v
				var drop: float=.52+.10*cos(angle*6.)*v
				st.set_uv(Vector2(u,v));st.add_vertex(Vector3(sin(angle)*(r.x*spread+.03),r.y*(.01-drop*v),cos(angle)*(r.z*spread+.035)))
	st.index();st.generate_normals();G.mesh(root,st.commit(),Vector3.ZERO,cloth,"PleatedSilk")
static func extra_layers(root: Node3D,rig: Resource,item: Dictionary,cloth: Material,trim: Material,gold: Material) -> void:
	var r: Vector3=rig.body_radii;var style: String=item.style;var key: String=style+rig.species_id
	if style=="aurora_coat":pleated_overlay(root,r,cloth)
	if style in ["tide_mantle","aurora_coat"]:
		var length_:=.12 if style=="aurora_coat" else .38
		G.mesh(root,Shell.shell(key+"capelet",[Vector3(r.y*length_,r.x*1.30+.06,r.z*1.21+.045),Vector3(r.y*.57,r.x*1.06+.04,r.z*1.02+.05),Vector3(r.y*.86,r.x*.64+.026,r.z*.70+.03)]),Vector3.ZERO,cloth,"Mantle")
		for j in range(17):
			var angle:=j*TAU/17.
			var p:=Vector3(sin(angle)*(r.x*1.30+.06),r.y*length_,cos(angle)*(r.z*1.21+.045))
			var q:=p+Vector3(sin(angle)*.006,-.080-.040*cos(angle*3.),cos(angle)*.006)
			thread(root,p,q,.009,trim);G.ball(root,q,Vector3(.011,.018,.011),gold)
