extends RefCounted
## Distant island in local coordinates, with the mill and skiff usable independently.
static func height(p: Vector2) -> float:
	var q:=p/Vector2(45.,22.)
	var shape:=maxf(0.,1.-q.length_squared())
	return -1.65+pow(shape,1.32)*(12.7+3.1*sin(p.x*.09)+1.2*cos(p.y*.19+p.x*.066))

static func point(x: float,z: float) -> Vector3:
	return Vector3(x,height(Vector2(x,z)),z)

static func hill(b) -> void:
	var rows:=15
	var segments:=80
	for j in range(rows):
		for k in range(segments):
			for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
				var r: float=(j+corner.y)/rows
				var a: float=(k+corner.x)*TAU/segments
				var x:=cos(a)*45.*r
				var z:=sin(a)*22.*r
				var p:=point(x,z)
				var normal:=(point(x,z+.2)-point(x,z-.2)).cross(point(x+.2,z)-point(x-.2,z)).normalized()
				var tone:=Color("87bc80").lerp(Color("bdd88a"),clampf(.5+.5*sin(x*.12+z*.14),0.,1.)*.52)
				if r>.91:tone=tone.lerp(Color("bdaf85"),smoothstep(.91,1.,r))
				b.surface.set_normal(normal)
				b.surface.set_color(tone.srgb_to_linear())
				b.surface.add_vertex(p)
	var rng:=RandomNumberGenerator.new()
	rng.seed=58125
	for i in range(55):
		var a:=rng.randf()*TAU
		var r:=sqrt(rng.randf_range(.15,.92))
		var p:=point(cos(a)*r*43.,sin(a)*r*20.)
		if Vector2(p.x-4.,p.z-1.).length()<7.:continue
		var n:=rng.randf_range(.65,1.32)
		if i%4:
			b.drum(p,p+Vector3.UP*2.0*n,.21*n,.14*n,"9d9673",7)
			for j in range(3):
				var angle:=a+j*TAU/3.
				b.ellipsoid(p+Vector3(cos(angle)*.60,2.02+.32*j,sin(angle)*.50)*n,Vector3(1.16,1.48,1.13)*n,["72a776","80af79","82b87f"][i%3])
		else:
			b.ellipsoid(p+Vector3.UP*2.05*n,Vector3(.81,2.21,.83)*n,"609b7b")
	for i in range(5):
		var x: float=[-17.,-11.,13.,19.,24.][i]
		var z: float=[10.,11.2,9.,7.5,5.6][i]
		var p:=point(x,z)
		b.box(p+Vector3.UP*.69,Vector3(2.75,1.60,2.03),"f5ddb1")
		for side in [-1.,1.]:
			b.box(p+Vector3(side*.73,1.79,0),Vector3(1.76,.15,2.33),["e59a72","89b6ac","baa0ac"][i%3],-side*.44)
		b.box(p+Vector3(.51,.83,1.05),Vector3(.46,.66,.06),"77a89b")

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
