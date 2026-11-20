extends RefCounted
## The crown is the original rig ellipsoid. The cheeks carry the drawn face,
## while the ears rise continuously out of the temples.
const RINGS=[
	Vector2(-.535,0.),Vector2(-.520,.175),Vector2(-.494,.31),
	Vector2(-.451,.435),Vector2(-.395,.528),Vector2(-.324,.603),
	Vector2(-.23,.656),Vector2(-.116,.685),Vector2(.015,.696),
	Vector2(.14,.685),Vector2(.28,.649),Vector2(.43,.592)]
static var radius_curve: Curve

static func radius_squared(y: float) -> float:
	if radius_curve==null:
		radius_curve=Curve.new()
		radius_curve.min_domain=-.536;radius_curve.max_domain=.801
		radius_curve.bake_resolution=512
		for i in range(RINGS.size()):
			var point: Vector2=RINGS[i]
			var left: Vector2=RINGS[maxi(i-1,0)];var right: Vector2=RINGS[mini(i+1,RINGS.size()-1)]
			var slope: float=(right.y*right.y-left.y*left.y)/(right.x-left.x)
			radius_curve.add_point(Vector2(point.x,point.y*point.y),slope,slope)
		radius_curve.bake()
	if y<-.535:return (y+.535)*1.98
	return radius_curve.sample_baked(y)

static func smooth_union(a: float,b: float,k: float) -> float:
	var h:=maxf(k-absf(a-b),0)/k
	return minf(a,b)-h*h*k*.25

static func ear_distance(p: Vector3) -> float:
	# A tapered volume with tangent round ends. Its lower end is buried inside
	# the skull, so there is no bottom edge on the side of the face.
	var base:=Vector3(.417,.235,-.045)
	var tip:=Vector3(.625,.822,-.075)
	var axis:=tip-base
	var length_:=axis.length()
	var direction:=axis/length_
	var q:=Vector3(absf(p.x),p.y,p.z)-base
	var along:=q.dot(direction)
	var across:=(q-direction*along).length()
	var slope:=(.237-.026)/length_
	var contact:=clampf(along-slope*across/sqrt(1.-slope*slope),0.,length_)
	return (q-direction*contact).length()-lerpf(.237,.026,contact/length_)

static func crown_distance(p: Vector3) -> float:
	var radii:=Vector3(.70,.56,.63)
	var k0: float=(p/radii).length()
	var k1: float=(p/(radii*radii)).length()
	return k0*(k0-1)/k1 if k1>.00001 else -.56

static func skull_distance(p: Vector3) -> float:
	if p.y>=.28:return crown_distance(p)
	var radial:=Vector2(p.x,p.z/.86).length()
	var cheek:=(radial*radial-radius_squared(p.y))/maxf(.76,2.*radial)
	return lerpf(cheek,crown_distance(p),smoothstep(.12,.28,p.y))

static func head_distance(p: Vector3) -> float:
	var skull:=skull_distance(p)
	var joined:=smooth_union(skull,ear_distance(p),.14)
	return lerpf(skull,joined,smoothstep(.045,.24,p.y))

static func face_point(p: Vector2) -> Vector3:
	# All face strokes lie below the join, on the forward cheek surface.
	return Vector3(p.x,p.y,sqrt(maxf(.0001,radius_squared(p.y)-p.x*p.x))*.86+.004)
