extends RefCounted
## Distant island in local coordinates, with the mill and skiff usable independently.
static func coast(angle: float) -> float:
	return 1.+.10*sin(3.*angle+.4)+.055*cos(5.*angle-.7)+.035*sin(9.*angle)

static func height(p: Vector2) -> float:
	var q:=p/Vector2(45.,22.)
	var r:=q.length()/coast(q.angle())
	var shoulder:=maxf(0.,1.-r*r)
	var ridge:=11.9+3.1*sin(p.x*.085)+1.5*cos(p.y*.17+p.x*.06)
	var bluff:=smoothstep(.48,.74,r)*(1.-smoothstep(.76,.91,r))
	return -1.65+pow(shoulder,1.27)*ridge+bluff*(1.8+.85*sin(q.angle()*4.))

static func point(x: float,z: float) -> Vector3:
	return Vector3(x,height(Vector2(x,z)),z)

static func hill(b) -> void:
	var rings:=[0.,.10,.20,.30,.40,.50,.59,.67,.72,.76,.80,.84,.89,.94,1.]
	var segments:=80
	for j in range(rings.size()-1):
		for k in range(segments):
			for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
				var r: float=rings[j+corner.y]
				var a: float=(k+corner.x)*TAU/segments
				var x:=cos(a)*45.*r*coast(a)
				var z:=sin(a)*22.*r*coast(a)
				var normal:=(point(x,z+.12)-point(x,z-.12)).cross(point(x+.12,z)-point(x-.12,z)).normalized()
				var meadow:=Color("627955").lerp(Color("97a46c"),.5+.35*sin(x*.22+z*.32)+.15*cos(z*.71))
				var stone:=Color("817e76").lerp(Color("b2a691"),.5+.42*sin(r*85.+cos(a*9.)))
				var exposed:=maxf(1.-smoothstep(.67,.90,normal.y),smoothstep(.73,.81,r)*(1.-smoothstep(.86,.94,r)))
				var tone:=meadow.lerp(stone,exposed).lerp(Color("c6b495"),smoothstep(.90,.97,r))
				b.surface.set_normal(normal)
				b.surface.set_color(tone.srgb_to_linear())
				b.surface.add_vertex(point(x,z))
	# A pale lane links the cottages; its edges follow the real slope.
	for i in range(72):
		var x:=-28.+i*.78
		var z:=9.+2.6*sin(x*.11)
		var nx:=x+.78
		var nz:=9.+2.6*sin(nx*.11)
		var lift:=Vector3.UP*.12
		b.panel(point(x,z-.38)+lift,point(nx,nz-.38)+lift,point(nx,nz+.38)+lift,point(x,z+.38)+lift,Vector3.UP,"b8aa87")
	for i in range(6):
		var x: float=[-22.,-16.8,-11.7,10.,15.1,21.5][i]
		var z:=9.+2.6*sin(x*.11)-2.3
		cottage(b,point(x,z),i)
	for row in range(4):
		for i in range(12):
			var x:=-9.+i*.82
			var z:=11.+row*.78+.9*sin(x*.19)
			var end_z:=11.+row*.78+.9*sin((x+.82)*.19)
			b.drum(point(x,z)+Vector3.UP*.16,point(x+.82,end_z)+Vector3.UP*.16,.17,.17,["899055","a18e58"][row%2],5)
	var rng:=RandomNumberGenerator.new()
	rng.seed=58125
	rocky_shore(b,rng)
	for i in range(92):
		var a:=rng.randf()*TAU
		var r:=sqrt(rng.randf_range(.07,.78))
		var p:=point(cos(a)*r*43.,sin(a)*r*20.)
		if Vector2(p.x-4.,p.z-1.).length()<6. or (p.z>4. and p.z<15. and absf(p.x)<28.):continue
		var n:=rng.randf_range(.70,1.32)
		var lean:=Vector3(.20*cos(a),0,.18*sin(a))*n
		b.drum(p-Vector3.UP*.28,p+Vector3.UP*2.2*n+lean,.24*n,.12*n,"696352",6)
		if i%3==0:
			for j in range(3):
				var foot:=p+Vector3.UP*(.75+j*.83)*n+lean
				b.drum(foot,foot+Vector3.UP*(1.9-.17*j)*n,(1.18-.24*j)*n,.06*n,["405c53","4c6759","60795d"][j],8)
		else:
			for j in range(3):
				var off:=Vector3(cos(a+j*2.2)*.70,1.70+.36*j,sin(a+j*2.2)*.59)*n
				var base:=p+off+lean
				b.ellipsoid(base,Vector3(1.02,.78+.14*j,.91)*n,["49654e","5c7653","708760"][j],.12*sin(a))
				if j==0:b.drum(p+Vector3.UP*n,base,.12*n,.07*n,"716852",6)

static func shore_point(angle: float,r: float,y: float) -> Vector3:
	return Vector3(cos(angle)*45.*coast(angle)*r,y,sin(angle)*22.*coast(angle)*r)

static func rocky_shore(b,rng: RandomNumberGenerator) -> void:
	# Two headlands frame a pocket beach. A broken cap and tilted ledges read at play distance.
	for span: Vector2 in [Vector2(.05,1.14),Vector2(1.95,2.87),Vector2(3.51,4.35)]:
		var previous:=PackedVector3Array()
		for k in range(28):
			var t:=k/27.
			var a:=lerpf(span.x,span.y,t)
			var bluff:=pow(maxf(0.,sin(t*PI)),.58)
			var protrusion:=.024*sin(a*27.)+.016*cos(a*61.)
			var base:=shore_point(a,1.035+protrusion,-1.8)
			var lip:=shore_point(a,.955+protrusion,1.+bluff*(2.2+.6*sin(a*18.)))
			var cap:=shore_point(a,.83,lip.y+.32)
			var slope:=shore_point(a,.74,0.)
			slope.y=height(Vector2(slope.x,slope.z))+.14
			var seam:=base.lerp(lip,.59+.06*sin(a*21.))+Vector3(cos(a),0,sin(a))*.27
			var ledge:=seam+Vector3.UP*.27
			var ring:=PackedVector3Array([base,seam,ledge,lip,cap,slope])
			if k>0:
				var out:=Vector3(cos(a),.12,sin(a))
				for j in range(5):
					var tone:=Color(["777a74","c1ad8e","9a917e","aea589","7f8c64"][j]).darkened(.085*(1.+sin(a*34.)))
					b.panel(previous[j],ring[j],ring[j+1],previous[j+1],Vector3.UP if j>=3 else out,tone.to_html(false))
			previous=ring
		for i in range(16):
			var a:=rng.randf_range(span.x,span.y)
			var p:=shore_point(a,rng.randf_range(1.00,1.13),-.28)
			var n:=rng.randf_range(.52,1.48)
			b.ellipsoid(p,Vector3(1.48,.62,.91)*n,["84857b","9c9582","abaa97"][i%3],.20*sin(a*19.))

static func cottage(b,p: Vector3,i: int) -> void:
	var wall: String=["d6c49d","d0c6ae","d6b898"][i%3]
	var tile: String=["a35743","516e70","ad7251"][i%3]
	b.frame=Transform3D(Basis(Vector3.UP,[-.35,.20,.45,-.13,.26,-.48][i]),p)
	b.box(Vector3(0,-.34,0),Vector3(3.56,1.9,2.64),"938674")
	b.box(Vector3(0,1.,0),Vector3(3.38,1.9,2.42),wall)
	for side in [-1.,1.]:
		b.facet(Vector3(-1.69,1.92,side*1.21),Vector3(1.69,1.92,side*1.21),Vector3(0,3.09,side*1.21),Vector3.BACK*side,wall)
		b.box(Vector3(side*.94,2.49,0),Vector3(2.27,.21,2.93),tile,-side*.56)
	b.drum(Vector3(0,3.13,-1.48),Vector3(0,3.13,1.48),.105,.105,tile,8)
	b.box(Vector3(.93,2.95,-.45),Vector3(.42,1.35,.48),"956654")
	b.box(Vector3(.93,3.60,-.45),Vector3(.54,.15,.59),"765b4f")
	for x in [-.86,.88]:
		b.box(Vector3(x,1.24,1.24),Vector3(.53,.64,.07),"536e70")
		for side in [-1.,1.]:b.box(Vector3(x+side*.38,1.24,1.26),Vector3(.19,.69,.11),"728c7e")
		b.box(Vector3(x,.88,1.29),Vector3(.72,.10,.18),"b99d76")
	b.box(Vector3(0,.77,1.23),Vector3(.50,1.25,.09),"7b6956")
	b.frame=Transform3D.IDENTITY

static func mill(b) -> void:
	b.tier(0.,.35,2.55,2.48,"c2ac84")
	b.tier(.35,1.15,2.29,2.18,"d6b689")
	b.tier(1.15,6.35,2.18,1.69,"f6e6be",24)
	b.tier(6.35,6.66,1.82,1.92,"ae7d62")
	b.tier(6.66,7.32,2.06,1.58,"db886f")
	b.tier(7.32,7.87,1.58,.87,"dc9276")
	b.tier(7.87,8.17,.87,.15,"df9878")
	b.box(Vector3(0,1.05,2.14),Vector3(.98,2.03,.12),"7aa58d")
	for i in range(3):
		var x:=cos(i*2.2)
		b.box(Vector3(x,3.15+i*.91,1.57),Vector3(.51,.75,.37),"b69570")
		b.box(Vector3(x,3.15+i*.91,1.78),Vector3(.35,.58,.07),"6c978c")

static func sails(b) -> void:
	for i in range(4):
		b.frame=Transform3D(Basis(Vector3.BACK,i*PI/2.),Vector3.ZERO)
		b.drum(Vector3(0,0,0),Vector3(.02,4.53,0),.074,.055,"b38158",8)
		for j in range(5):
			var low:=1.16+j*.64
			var wide:=.63+j*.097
			b.panel(Vector3(.01,low,.035),Vector3(wide-.07,low+.05,.13),Vector3(wide,low+.63,.10),Vector3(.01,low+.61,.035),Vector3.BACK,"fff1cc" if j%2==0 else "f8e1b2")
			b.drum(Vector3(-.07,low,.09),Vector3(wide+.08,low+.04,.16),.021,.017,"c49465",6)
	b.frame=Transform3D.IDENTITY
	b.drum(Vector3(0,0,-.12),Vector3(0,0,.24),.27,.18,"c59361",16)

static func boat(b) -> void:
	for i in range(14):
		var a:=i/14.
		var t:=(i+1)/14.
		for side in [-1.,1.]:
			var pa:=Vector3(sin(a*PI)*.88*side,.59+pow(absf(a-.5)*2.,2.)*.32,(a-.5)*4.8)
			var pb:=Vector3(sin(t*PI)*.88*side,.59+pow(absf(t-.5)*2.,2.)*.32,(t-.5)*4.8)
			var qa:=Vector3(pa.x*.47,.08,pa.z*.91)
			var qb:=Vector3(pb.x*.47,.08,pb.z*.91)
			b.panel(pa,pb,qb,qa,Vector3.RIGHT*side,"429a9d")
			b.panel(pa,pb,pb.lerp(qb,.16),pa.lerp(qa,.16),Vector3.RIGHT*side,"ffdfab")
			b.panel(pa,pb,Vector3(0,pb.y,pb.z),Vector3(0,pa.y,pa.z),Vector3.UP,"bf9770")
	b.drum(Vector3(0,.59,-.27),Vector3(0,5.35,-.27),.054,.030,"ba8459",8)
	for i in range(6):
		var a:=i/6.
		var c:=(i+1)/6.
		var bottom:=Vector3(.08,1.16,-.24)
		var head:=Vector3(.05,5.10,-.24)
		var foot:=Vector3(.45,1.34,1.66)
		var a0:=bottom.lerp(head,a)
		var b0:=foot.lerp(head,a)+Vector3.RIGHT*sin(PI*a)*.15
		var a1:=bottom.lerp(head,c)
		var b1:=foot.lerp(head,c)+Vector3.RIGHT*sin(PI*c)*.15
		var tint: String="f18c72" if i in [1,2] else "fff0cf"
		b.panel(a0,b0,b1,a1,Vector3.RIGHT,tint)
		b.panel(a0,b0,b1,a1,Vector3.LEFT,tint)
	for normal in [Vector3.RIGHT,Vector3.LEFT]:
		b.facet(Vector3(0,4.87,-.31),Vector3(-.17,1.22,-1.98),Vector3(.22,1.08,-.45),normal,"ffe3ae")
