extends RefCounted
## Shared surface math of the approved seamless cat head and its clothing fit.
static func smooth_union(a: float,b: float,k: float) -> float:
	var h:=maxf(k-absf(a-b),0)/k
	return minf(a,b)-h*h*k*.25
static func ear_distance(p: Vector3) -> float:
	var q:=Vector2(-absf(p.x),p.y)
	var polygon: Array[Vector2]=[Vector2(-.655,.10),Vector2(-.32,.26),Vector2(-.39,.52),Vector2(-.55,.76),Vector2(-.64,.84),Vector2(-.665,.78),Vector2(-.68,.59),Vector2(-.67,.32)]
	var distance_:=100.0
	var inside:=true
	for i in range(polygon.size()):
		var a: Vector2=polygon[i]
		var edge: Vector2=polygon[(i+1)%polygon.size()]-a
		var to_point:=q-a
		distance_=minf(distance_,(to_point-edge*clampf(to_point.dot(edge)/edge.length_squared(),0,1)).length())
		if edge.cross(to_point)<0: inside=false
	var plane:=(-distance_ if inside else distance_)-.018
	var depth:=lerpf(.245,.048,clampf((p.y-.25)/.56,0,1))
	var slab:=absf(p.z+.055)-depth
	return -smooth_union(-plane,-slab,.035)
static func skull_distance(p: Vector3) -> float:
	var radii:=Vector3(.70,.56,.63)
	var k0: float=(p/radii).length()
	var k1: float=(p/(radii*radii)).length()
	return k0*(k0-1)/k1 if k1>.00001 else -.56
static func head_distance(p: Vector3) -> float:
	return smooth_union(skull_distance(p),ear_distance(p),.085)
