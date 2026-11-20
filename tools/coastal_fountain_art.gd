extends RefCounted
## Dimensions in metres, measured from the plaza or furniture ground pivot.
const SEGMENTS := 96
const OUTLETS := 6
const POOL_Y := .445

static func point(radius: float, height: float, angle: float) -> Vector3:
	return Vector3(cos(angle)*radius,height,sin(angle)*radius)

static func mould(b, profile: Array, flutes := 0, relief := 0.) -> void:
	for row in range(profile.size()-1):
		for j in range(SEGMENTS):
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var k: int=row+corner.y
				var a: float=(j+corner.x)*TAU/SEGMENTS
				var r: float=profile[k][0]
				var z: float=profile[k][1]
				var prev: Array=profile[maxi(k-1,0)]
				var next: Array=profile[mini(k+1,profile.size()-1)]
				var slope:=Vector2(next[0]-prev[0],next[1]-prev[1]).normalized()
				var groove:=cos(a*flutes)
				var normal:=point(slope.y,-slope.x,a)
				normal+=Vector3(-sin(a),0,cos(a))*relief*flutes*sin(a*flutes)/maxf(r,.1)*slope.y
				b.surface.set_normal(normal.normalized())
				b.surface.set_color(Color.WHITE*(.96+.04*groove))
				b.surface.set_uv(Vector2(a*r,z)*.82 if absf(slope.y)>.45 else Vector2(cos(a),sin(a))*r*.82)
				b.surface.add_vertex(point(r+relief*groove,z,a))

static func stone(b) -> void:
	mould(b,[[.01,.04],[3.06,.04],[3.14,.09],[3.14,.15],[3.09,.19],[3.00,.21]],8,.020)
	mould(b,[[2.97,.17],[3.00,.22],[2.97,.29],[2.95,.44],[3.00,.49]],8,.032)
	mould(b,[[.68,.32],[.79,.38],[.80,.46],[.72,.52],[.60,.53],[.55,.60],[.53,.69],[.43,.74]],12,.028)

static func trim(b) -> void:
	# Individually cut coping stones. Each wedge has bevelled outer and inner edges and a real joint.
	var cross_section: Array=[[2.80,.426],[2.79,.494],[2.825,.548],[2.88,.568],[3.028,.555],[3.066,.520],[3.055,.464],[3.00,.435]]
	for i in range(32):
		var dye:=Color("fffdfa").darkened(.012*(i%4)).srgb_to_linear()
		for k in range(cross_section.size()):
			var next: int=(k+1)%cross_section.size()
			for j in range(4):
				for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
					var a: float=(i+lerpf(.009,.991,(j+corner.x)*.25))*TAU/32.
					var entry: Array=cross_section[k if corner.y==0 else next]
					var p:=point(entry[0]+.031*cos(8.*a),entry[1],a)
					var edge:=Vector2(cross_section[next][0]-cross_section[k][0],cross_section[next][1]-cross_section[k][1]).normalized()
					b.surface.set_normal(point(-edge.y,edge.x,a).normalized())
					b.surface.set_uv(Vector2(a*2.9,p.y+(p.x*p.x+p.z*p.z)*.17))
					b.surface.set_color(dye)
					b.surface.add_vertex(p)

static func tiles(b) -> void:
	mould(b,[[2.944,.251],[2.990,.270],[2.991,.408],[2.965,.440]],8,.032)
	for i in range(160):
		var a:=TAU*i/160.
		var radius:=2.993+.032*cos(8.*a)
		b.frame=Transform3D(Basis(Vector3.UP,-a),point(radius,.334,a))
		var tint: String=["d1e5d8","91c4c4","aacdbb","e4d7a6","8ab2b3"][i%5]
		b.box(Vector3.ZERO,Vector3(.019,.078,.099),tint)
	b.frame=Transform3D.IDENTITY

static func bronze(b) -> void:
	preload("res://tools/coastal_dolphins.gd").sculpture(b)
	# Small scallop escutcheons sit on the mosaic frieze between the cut-stone joints.
	for i in range(8):
		var a:=TAU*i/8.+PI*.5
		var face:=Transform3D(Basis(Vector3.UP,PI*.5-a),point(3.037,.34,a))
		b.frame=face
		b.ellipsoid(Vector3(0,-.019,.008),Vector3(.145,.082,.024),"b19865")
		for j in range(9):
			var f: float=(j-4)/4.
			var tip:=Vector3(f*.157,.066-.053*f*f,.041)
			b.drum(Vector3(f*.026,-.072,.036),tip,.008,.012,"ccb487",6)
		b.frame=Transform3D.IDENTITY
	for i in range(8):
		var a:=i*TAU/8.+.18
		b.drum(point(.73,.41,a),point(.75,.55,a),.063,.045,"ae915e",12)

static func particle(b,rng: RandomNumberGenerator, kind: float, angle: float, launch: float, height: float, width: float) -> void:
	# UV2 encodes the ballistic reach and height. Mesh vertices share a local emitter origin.
	var origin:=point(launch,.51,angle)
	var phase:=rng.randf()
	var seed_:=rng.randf()
	for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
		b.surface.set_color(Color(kind,phase,seed_,width/.13))
		b.surface.set_uv(corner)
		b.surface.set_uv2(Vector2(angle,height))
		b.surface.set_normal(Vector3.UP)
		b.surface.add_vertex(origin)

static func stream(b, a: float) -> void:
	const STEPS:=28
	const SIDES:=6
	var away:=point(1.,0.,a)
	var side:=away.cross(Vector3.UP)
	for j in range(STEPS):
		for k in range(SIDES):
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var t: float=(j+corner.y)/STEPS
				var q: float=(k+corner.x)*TAU/SIDES
				var center:=point(.75+1.27*t,.53-.085*t+3.62*t*(1.-t),a)
				var tangent: Vector3=(away*1.27+Vector3.UP*(3.62*(1.-2.*t)-.085)).normalized()
				var normal:=side*cos(q)+tangent.cross(side)*sin(q)
				skin(b,center+normal*lerpf(.017,.009,t),normal,Vector2((k+corner.x)/SIDES,t),.025,.35+.27*sin(3.*a))

static func running_water(b) -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=778455
	# Aerated water at the foot of the sculpture, slim sprays and soft impacts share one submission.
	for i in range(8):
		var a:=i*TAU/8.+.18
		stream(b,a)
		for j in range(100):
			particle(b,rng,.18,a+rng.randf_range(-.021,.021),.75,rng.randf_range(.866,.95),rng.randf_range(.005,.013))
	for j in range(430):
		var a:=rng.randf()*TAU
		particle(b,rng,.48,a,.48,rng.randf_range(.32,1.70),rng.randf_range(.009,.026))
	for j in range(310):
		var a: float=(j%8)*TAU/8.+.18+rng.randf_range(-.08,.08)
		particle(b,rng,.84,a,rng.randf_range(1.89,2.06),rng.randf_range(.06,.29),rng.randf_range(.006,.021))

static func skin(b, p: Vector3, n: Vector3, uv: Vector2, kind: float, seed_: float) -> void:
	b.surface.set_color(Color(kind,seed_,.5))
	b.surface.set_uv(uv)
	b.surface.set_uv2(Vector2.ZERO)
	b.surface.set_normal(n)
	b.surface.add_vertex(p)

static func disc(b, radius: float, height: float) -> void:
	for j in range(SEGMENTS):
		for p in [Vector3.UP*height,point(radius,height,TAU*j/SEGMENTS),point(radius,height,TAU*(j+1)/SEGMENTS)]:
			skin(b,p,Vector3.UP,Vector2(p.x,p.z),0.,0.)

static func pools(b) -> void:
	disc(b,2.82,POOL_Y)
