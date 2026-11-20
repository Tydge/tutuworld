extends RefCounted
## A pair of cast-bronze bottlenose dolphins. Each section follows the spine, including the melon and beak.
static func sample(rows: Array,t: float) -> Vector3:
	var n:=rows.size()-1
	var step_:=clampf(t,0.,1.)*n
	var i:=mini(floori(step_),n-1)
	var a: Vector3=rows[i]
	return a.cubic_interpolate(rows[i+1],rows[maxi(0,i-1)],rows[mini(n,i+2)],step_-i)

static func vertex(rows: Array, widths: Array, t: float, angle: float, across: Vector3) -> Vector3:
	var center:=sample(rows,t)
	var tangent:=(sample(rows,t+.001)-sample(rows,t-.001)).normalized()
	var side:=(across-across.dot(tangent)*tangent).normalized()
	var up:=side.cross(tangent).normalized()
	var radii:=sample(widths,t)
	return center+side*maxf(.004,radii.x)*cos(angle)+up*maxf(.004,radii.y)*sin(angle)

static func loft(b, pose: Transform3D, rows: Array, widths: Array, across: Vector3, body: bool=false) -> void:
	var length_steps: int=(rows.size()-1)*3
	var sides:=24 if body else 14
	for j in range(length_steps):
		for k in range(sides):
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var t: float=(j+corner.y)/length_steps
				var a: float=(k+corner.x)*TAU/sides
				var p:=vertex(rows,widths,t,a,across)
				var dt:=vertex(rows,widths,minf(1.,t+.001),a,across)-vertex(rows,widths,maxf(0.,t-.001),a,across)
				var da:=vertex(rows,widths,t,a+.005,across)-vertex(rows,widths,t,a-.005,across)
				var normal:=dt.cross(da).normalized()
				var belly:=smoothstep(-.28,.79,-sin(a)) if body else .20
				var patina:=.5+.5*sin(p.x*9.+3.*sin(p.y*4.)+p.z*7.)
				var tint:=Color("527969").lerp(Color("c6ae81"),belly*.72).lerp(Color("729f94"),patina*.24).srgb_to_linear()
				b.surface.set_normal((pose.basis*normal).normalized())
				b.surface.set_color(tint)
				b.surface.set_uv(Vector2(t,a/TAU))
				b.surface.add_vertex(pose*p)

static func sizes(pairs: Array) -> Array:
	var result: Array=[]
	for pair in pairs:result.append(Vector3(pair[0],pair[1],0.))
	return result

static func animal(b, pose: Transform3D) -> void:
	var spine: Array=[Vector3(-.73,-.04,0),Vector3(-.94,.16,.05),Vector3(-.98,.48,.08),Vector3(-.85,.84,.09),Vector3(-.61,1.13,.055),Vector3(-.27,1.35,0),Vector3(.12,1.43,-.025),Vector3(.42,1.41,-.028),Vector3(.69,1.33,-.02),Vector3(.84,1.21,0),Vector3(.94,1.165,0),Vector3(1.13,1.152,0),Vector3(1.27,1.136,0)]
	loft(b,pose,spine,sizes([[.045,.06],[.083,.103],[.105,.135],[.153,.186],[.22,.255],[.282,.316],[.307,.332],[.288,.304],[.24,.246],[.175,.15],[.116,.078],[.103,.068],[.012,.020]]),Vector3.BACK,true)
	# Dorsal fin sweeps back behind the shoulder.
	loft(b,pose,[Vector3(-.08,1.65,0),Vector3(-.08,1.77,0),Vector3(-.17,1.92,.012),Vector3(-.32,2.055,.022),Vector3(-.39,2.08,.028)],sizes([[.22,.082],[.197,.065],[.125,.050],[.050,.024],[.006,.005]]),Vector3.RIGHT)
	for sign_ in [-1.,1.]:
		loft(b,pose,[Vector3(.33,1.32,sign_*.21),Vector3(.29,1.23,sign_*.34),Vector3(.16,1.11,sign_*.49),Vector3(-.02,1.03,sign_*.64),Vector3(-.14,1.00,sign_*.71)],sizes([[.14,.074],[.14,.069],[.105,.048],[.052,.024],[.005,.005]]),Vector3.RIGHT)
		loft(b,pose,[Vector3(-.77,.010,sign_*.02),Vector3(-.77,.032,sign_*.21),Vector3(-.83,.092,sign_*.41),Vector3(-.93,.132,sign_*.56),Vector3(-1.03,.144,sign_*.64)],sizes([[.125,.050],[.146,.06],[.124,.047],[.06,.026],[.006,.005]]),Vector3.RIGHT)
		b.frame=pose
		b.ellipsoid(Vector3(.655,1.337,sign_*.226),Vector3(.035,.030,.016),"253e3a")
		b.ellipsoid(Vector3(.662,1.347,sign_*.237),Vector3(.009,.008,.007),"d8cba8")
		for j in range(5):
			var x:=.87+j*.072
			var z: float=sign_*(.108-j*.008)
			b.drum(Vector3(x,1.137+j*.001,z),Vector3(x+.074,1.138+j*.001,z-sign_*.007),.008,.007,"415d53",5)
		b.frame=Transform3D.IDENTITY

static func sculpture(b) -> void:
	animal(b,Transform3D(Basis(Vector3.UP,-.27).scaled_local(Vector3.ONE*1.15),Vector3(-.03,.95,-.20)))
	animal(b,Transform3D(Basis(Vector3.UP,2.78).scaled_local(Vector3.ONE*.69),Vector3(.33,.78,.47)))
	# Modelled strands of the supporting wave connect the tails to the pedestal.
	for i in range(5):
		var z: float=-.19+i*.105
		var s: float=i*.035
		loft(b,Transform3D.IDENTITY,[Vector3(.34,.63,z),Vector3(.04,.72,z),Vector3(-.36,.80+s,z),Vector3(-.65,.97+s,z-.035),Vector3(-.86,1.15+s,z-.08)],sizes([[.13,.06],[.15,.09],[.12,.10],[.08,.07],[.01,.02]]),Vector3.BACK)
