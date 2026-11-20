extends RefCounted
const G=preload("res://scripts/geometry.gd")
static var shells: Dictionary={}

# Closed rows revolve around the body with one shared mesh per species and cut.
# Profile entries give height above the garment origin, X radius and Z radius.
static func shell(key: String,rows: Array) -> ArrayMesh:
	if shells.has(key):return shells[key]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS:=40
	for i in range(rows.size()-1):
		for j in range(SEGMENTS):
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1)]:
				var k: int=i+corner.x;var row: Vector3=rows[k]
				var t: float=(j+corner.y)*TAU/SEGMENTS
				var tangent: Vector3=rows[mini(k+1,rows.size()-1)]-rows[maxi(k-1,0)]
				st.set_normal(Vector3(sin(t)*tangent.x/maxf(.01,row.y),-(sin(t)*sin(t)*tangent.y/maxf(.01,row.y)+cos(t)*cos(t)*tangent.z/maxf(.01,row.z)),cos(t)*tangent.x/maxf(.01,row.z)).normalized())
				st.set_uv(Vector2((j+corner.y)/float(SEGMENTS),k/float(rows.size()-1)))
				st.add_vertex(Vector3(sin(t)*row.y,row.x,cos(t)*row.z))
	st.index();shells[key]=st.commit();return shells[key]

static func build(root: Node3D,rig: Resource,item: Dictionary,cloth: Material) -> void:
	var trim:=G.mat(item.accent)
	match item.style:
		"pompom_cap":
			root.position=rig.hat_offset-Vector3(0,.065,0)
			root.scale=rig.headwear_scale
			G.mesh(root,shell("cap",[Vector3(-.09,.46,.40),Vector3(0,.53,.46),Vector3(.14,.5,.44),Vector3(.25,.36,.32),Vector3(.32,.15,.14),Vector3(.33,.01,.01)]),Vector3.ZERO,cloth,"KnitCrown")
			G.mesh(root,shell("turnup",[Vector3(-.09,.46,.40),Vector3(-.07,.52,.46),Vector3(.035,.54,.47),Vector3(.052,.51,.44)]),Vector3.ZERO,trim,"TurnedHem")
			G.ball(root,Vector3(0,.39,-.025),Vector3.ONE*.114,trim,"Pom")
		"winter_rosette":
			var normal: Vector3=rig.bow_normal.normalized()
			var right:=Vector3.UP.cross(normal).normalized()
			root.basis=Basis(right,normal.cross(right),normal).scaled_local(rig.headwear_scale)
			root.position=rig.bow_offset
			for i in range(5):
				var a:=TAU*i/5.
				var petal:=G.ball(root,Vector3(-sin(a),cos(a),.20)*.095,Vector3(.071,.115,.037),cloth,"FeltPetal")
				petal.rotation.z=a
			for i in range(3):
				var a:=TAU*i/3.
				G.ball(root,Vector3(.043*cos(a),.043*sin(a),.066),Vector3.ONE*.051,trim,"Berry")
		"loop_cowl","kerchief":
			root.position=rig.neck_center
			var r: Vector2=rig.neck_radii
			G.mesh(root,shell(rig.species_id+item.style,[Vector3(-.073,r.x+.05,r.y+.055),Vector3(-.038,r.x+.075,r.y+.073),Vector3(.046,r.x+.04,r.y+.044),Vector3(.070,r.x,r.y)]),Vector3.ZERO,cloth,"NeckWrap")
			if item.style=="loop_cowl":
				var fold:=G.mesh(root,shell(rig.species_id+"fold",[Vector3(-.048,r.x+.072,r.y+.065),Vector3(-.017,r.x+.09,r.y+.086),Vector3(.018,r.x+.07,r.y+.066)]),Vector3(0,-.048,0),cloth,"SecondLoop")
				fold.rotation.z=.055
			else:
				var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
				for i in range(16):
					for c in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
						var u: float=(i+c.x)/8.-1.;var y: float=-.045-c.y*(1.-absf(u))*.27
						var z: float=maxf(r.y+.055,rig.body_radii.z+.045)-u*u*.07-c.y*y*.08
						st.set_uv(Vector2(u,c.y));st.set_normal(Vector3.BACK);st.add_vertex(Vector3(u*r.x*.82,y,z))
				G.mesh(root,st.commit(),Vector3.ZERO,cloth,"TriangularFold")
		"duffle","capelet":
			root.position=rig.body_center
			var r: Vector3=rig.body_radii
			var rows: Array=[]
			var profile: Array=[[-.83,.67],[-.72,.82],[-.42,.995],[0.,1.07],[.43,.99],[.72,.78],[.90,.53]] if item.style=="duffle" else [[-.37,1.20],[-.29,1.19],[.16,1.12],[.48,1.00],[.72,.84],[.9,.59]]
			for row in profile:rows.append(Vector3(r.y*row[0],r.x*row[1]+.018,r.z*row[1]+.02))
			var key: String=rig.species_id+item.style
			G.mesh(root,shell(key,rows),Vector3.ZERO,cloth,"WoolCoat")
			var bottom: Vector3=rows[0]
			G.mesh(root,shell(key+"hem",[bottom+Vector3(-.012,0,0),bottom+Vector3(.005,.014,.014),rows[1]+Vector3(0,.008,.008)]),Vector3.ZERO,trim,"LinedHem")
			if item.style=="duffle":
				for y in [-.26,.10,.42]:
					var z: float=r.z*(1.07-.42*y*y)+.034
					G.capsule(root,Vector3(-.074,r.y*y,z),Vector3(.074,r.y*y+.009,z),.018,trim,"Toggle")
			else:
				G.ball(root,Vector3(0,r.y*.46,r.z+.039),Vector3(.052,.053,.028),trim,"Clasp")
