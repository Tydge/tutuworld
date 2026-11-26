extends RefCounted
## One oval runs through the forehead, cheeks and chin. Its sagittal section
## is an ellipse at every height, so rotating the head cannot expose a join.
const CENTER_Y:=.027
const HEIGHT_RADIUS:=.619
const DEPTH_RADIUS:=.622
const INK_OFFSET:=.004

static func drawing_point(x: float,y: float) -> Vector2:
	return Vector2((x-179.)*.0041,(269.-y)*.0041-.09)

static func eye_corner(outer: bool) -> Vector2:
	return drawing_point(296,273) if outer else drawing_point(216,284)

static func half_width(latitude: float) -> float:
	# A little fullness below the eyes and a gradual taper towards the temples.
	var lower:=maxf(-latitude,0.)
	return .685*(1.-.082*latitude+.15*lower*lower)

static func skull_distance(p: Vector3) -> float:
	var h: float=(p.y-CENTER_Y)/HEIGHT_RADIUS
	var w:=half_width(clampf(h,-1.,1.))
	var q:=Vector3(p.x/w,h,p.z/DEPTH_RADIUS)
	# The first-order distance keeps the ear blend the same size around the oval.
	var gradient:=Vector3(q.x/w,q.y/HEIGHT_RADIUS,q.z/DEPTH_RADIUS)
	return (q.length_squared()-1.)/maxf(1.5,2.*gradient.length())

static func ear_distance(p: Vector3) -> float:
	# Start the taper inside the cheek. The small round tip and the broad
	# base are one volume, with no lower face to show through the white fur.
	var base:=Vector3(.350,.254,-.05)
	var tip:=Vector3(.526,.773 if p.x<0. else .802,-.092)
	var axis:=tip-base
	var length_:=axis.length()
	var direction:=axis/length_
	var q:=Vector3(absf(p.x),p.y,p.z)-base
	var along:=q.dot(direction)
	var across:=(q-direction*along).length()
	var slope:=(.245-.031)/length_
	var contact:=clampf(along-slope*across/sqrt(1.-slope*slope),0.,length_)
	return (q-direction*contact).length()-lerpf(.245,.031,contact/length_)

static func head_distance(p: Vector3) -> float:
	var skull:=skull_distance(p)
	var ear:=ear_distance(p)
	const ROOT_BLEND:=.145
	var blend:=maxf(ROOT_BLEND-absf(skull-ear),0.)/ROOT_BLEND
	return minf(skull,ear)-blend*blend*ROOT_BLEND*.25

static func face_point(p: Vector2) -> Vector3:
	var h: float=(p.y-CENTER_Y)/HEIGHT_RADIUS
	var u:=p.x/half_width(h)
	return Vector3(p.x,p.y,DEPTH_RADIUS*sqrt(maxf(.0001,1.-h*h-u*u))+INK_OFFSET)
