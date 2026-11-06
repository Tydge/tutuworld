extends RefCounted
## Exact coplanar sharing. World-plane coordinates make each face a window into
## one reflected view, rather than stretching the same image over every mirror.
static func describe(face: MeshInstance3D) -> Dictionary:
	var n:=face.global_basis.z.normalized();var up:=Vector3.UP-n*n.dot(Vector3.UP)
	if up.length_squared()<.001:up=Vector3.FORWARD-n*n.dot(Vector3.FORWARD)
	up=up.normalized();var right:=up.cross(n).normalized();var d:=n.dot(face.global_position)
	var extent: Vector2=face.mesh.size;var dx:=face.global_basis.x*extent.x;var dy:=face.global_basis.y*extent.y
	var top_left:=face.global_position-dx*.5+dy*.5
	var corners: Array[Vector3]=[top_left,top_left+dx,top_left+dx-dy,top_left-dy]
	var rect:=Rect2(Vector2(top_left.dot(right),top_left.dot(up)),Vector2.ZERO)
	for p in corners:rect=rect.expand(Vector2(p.dot(right),p.dot(up)))
	var key:="%d:%d:%d:%d"%[roundi(n.x*10000),roundi(n.y*10000),roundi(n.z*10000),roundi(d*10000)]
	return {"normal":n,"right":right,"up":up,"distance":d,"rect":rect,"corners":corners,"top_left":top_left,"dx":dx,"dy":dy,"key":key}
static func clipped_rect(geometry: Dictionary,planes: Array[Plane]) -> Rect2:
	var polygon: Array=geometry.corners
	for plane in planes:
		if polygon.is_empty():return Rect2()
		var clipped: Array=[];var previous: Vector3=polygon[-1];var previous_d:=plane.distance_to(previous)
		for point: Vector3 in polygon:
			var distance_:=plane.distance_to(point)
			if (previous_d<=0.)!=(distance_<=0.):clipped.append(previous.lerp(point,previous_d/(previous_d-distance_)))
			if distance_<=0.:clipped.append(point)
			previous=point;previous_d=distance_
		polygon=clipped
	if polygon.is_empty():return Rect2()
	var p: Vector3=polygon[0];var rect:=Rect2(Vector2(p.dot(geometry.right),p.dot(geometry.up)),Vector2.ZERO)
	for point: Vector3 in polygon:rect=rect.expand(Vector2(point.dot(geometry.right),point.dot(geometry.up)))
	# A small conservative guard includes the bilinear sampling footprint at edges.
	return rect.grow(.003).intersection(geometry.rect)
static func size_for(rect: Rect2,density: float) -> Vector2i:
	var lo:=Vector2(floorf(rect.position.x*density),floorf(rect.position.y*density));var hi:=Vector2(ceilf(rect.end.x*density),ceilf(rect.end.y*density));var required:=hi-lo+Vector2(2,2)
	return Vector2i(maxi(32,ceili(required.x/32.)*32),maxi(32,ceili(required.y/32.)*32))
static func capture_rect(rect: Rect2,size_: Vector2i,density: float) -> Rect2:
	# Pad the world rectangle to the allocated integer texture size. Pixel density
	# stays exact, while clipped borders can move without reallocating every frame.
	var extent:=Vector2(size_)/density
	var origin:=Vector2(floorf(rect.position.x*density),floorf(rect.position.y*density))/density
	return Rect2(origin,extent)
static func uv(geometry: Dictionary,rect: Rect2) -> Array[Vector3]:
	var right: Vector3=geometry.right;var up: Vector3=geometry.up;var corner: Vector3=geometry.top_left
	return [Vector3(-geometry.dx.dot(right)/rect.size.x,geometry.dy.dot(right)/rect.size.x,(rect.end.x-corner.dot(right))/rect.size.x),Vector3(-geometry.dx.dot(up)/rect.size.y,geometry.dy.dot(up)/rect.size.y,(rect.end.y-corner.dot(up))/rect.size.y)]
static func pose(camera_: Camera3D,eye: Vector3,geometry: Dictionary,rect: Rect2) -> bool:
	var n: Vector3=geometry.normal;var distance_: float=eye.dot(n)-geometry.distance
	if distance_<.025:return false
	var reflected:=eye-n*(2.*distance_)
	var transform_:=Transform3D(Basis(-geometry.right,geometry.up,-n),reflected)
	if camera_.global_transform!=transform_:camera_.global_transform=transform_
	var c:=rect.get_center();var center: Vector3=geometry.right*c.x+geometry.up*c.y+n*geometry.distance
	var point:=camera_.to_local(center);var near_:=distance_+.012;var factor:=near_/distance_
	camera_.keep_aspect=Camera3D.KEEP_HEIGHT
	camera_.set_frustum(rect.size.y*factor,Vector2(point.x,point.y)*factor,near_,distance_+55.)
	return true
