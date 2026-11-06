extends RefCounted
## Wall objects keep a spatial anchor, so wall splitting/material edits can rebind IDs.
const C=preload("res://scripts/building/catalog.gd")
const S=preload("res://scripts/building/storeys.gd")
const G=preload("res://scripts/building/grid_layout.gd")
const FACE_OFFSET:=.14
static func normal(row: Dictionary) -> Vector2:return C.rotate_xz(Vector2.DOWN,float(row.get("yaw",0.)))
static func height(row: Dictionary) -> float:return float(row.get("mount_height",C.OBJECTS[row.kind].get("mount_height",1.6)))
static func anchor(row: Dictionary) -> Vector2:return Vector2(row.position[0],row.position[1])-normal(row)*FACE_OFFSET
static func support(layout: Dictionary,row: Dictionary,walls: Dictionary={}) -> Dictionary:
	if walls.is_empty():walls=G.index(S.subset(layout,S.of(row)).elements).walls
	var p:=anchor(row);var n:=normal(row);var axis:=0 if absf(n.y)>.5 else 1;var across:=1-axis
	if absf(p[across]*2.-roundf(p[across]*2.))>.003:return {}
	var width: float=C.OBJECTS[row.kind].size.x;var first:=floori((p[axis]-width*.5-.015)*2.);var last:=ceili((p[axis]+width*.5+.015)*2.);var plane_:=roundi(p[across]*2.);var wall: Dictionary={}
	for i in range(first,last):
		var edge:=Vector3i(i,plane_,0) if axis==0 else Vector3i(plane_,i,1)
		if not walls.has(edge):return {}
		wall=walls[edge]
	if height(row)<.15 or height(row)+float(C.OBJECTS[row.kind].height)>4.35:return {}
	for hole in layout.elements:
		if hole.type not in ["door","window"] or S.of(hole)!=S.of(row):continue
		var point_: Vector2;var hole_axis: int
		if hole.has("anchor"):point_=Vector2(hole.anchor[0],hole.anchor[1]);hole_axis=hole.axis
		else:
			var parent: Dictionary={}
			for item in layout.elements:
				if item.id==hole.wall:parent=item;break
			if parent.is_empty():continue
			var a:=Vector2(parent.a[0],parent.a[1]);var b:=Vector2(parent.b[0],parent.b[1]);point_=a+(b-a).normalized()*float(hole.offset);hole_axis=0 if is_equal_approx(a.y,b.y) else 1
		if hole_axis!=axis or absf(point_[across]-p[across])>.01:continue
		var bottom:=0. if hole.type=="door" else 1.1;var top:=3.5 if hole.type=="door" else 3.1
		if height(row)>=top+.04 or height(row)+float(C.OBJECTS[row.kind].height)<=bottom-.04:continue
		if absf(point_[axis]-p[axis])<(width+(2.86 if hole.type=="door" else 2.2))*.5+.04:return {}
	return wall
static func attach(layout: Dictionary,row: Dictionary,p: Vector2,viewer: Vector2=Vector2.INF,base: float=-1.) -> Dictionary:
	var out:=row.duplicate(true);out.position=[p.x,p.y];out.support="";out.mount_height=snappedf(clampf(base if base>=0. else height(row),.15,4.35-float(C.OBJECTS[row.kind].height)),.05)
	var best:=2.5;var chosen: Dictionary={};var point_:=p
	for wall in layout.elements:
		if wall.type!="wall" or S.of(wall)!=S.of(row):continue
		var a:=Vector2(wall.a[0],wall.a[1]);var b:=Vector2(wall.b[0],wall.b[1]);var q:=Geometry2D.get_closest_point_to_segment(p,a,b);var distance:=p.distance_to(q)
		if distance<best:best=distance;chosen=wall;point_=q
	if chosen.is_empty():return out
	var along:=0 if is_equal_approx(chosen.a[1],chosen.b[1]) else 1;point_[along]=snappedf(point_[along],.1)
	var n:=Vector2.DOWN if along==0 else Vector2.RIGHT;var side: float=(viewer-point_).dot(n) if viewer.is_finite() else (p-point_).dot(n)
	if side<0.:n=-n
	out.yaw=fposmod(rad_to_deg(atan2(n.x,n.y)),360.);var placed:=point_+n*FACE_OFFSET;out.position=[snappedf(placed.x,.001),snappedf(placed.y,.001)];out.support=chosen.id
	return out
