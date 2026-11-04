extends RefCounted
const AUTO:=0
const FULL:=1
const OCCLUSION:=2
const NAMES:=["自动俯视","自由完整","自由避挡"]
static func mode(city: Node) -> int:
	if not is_instance_valid(city):return AUTO
	var session: Variant=city.get("session")
	if not is_instance_valid(session):return AUTO
	return clampi(int(session.settings.get("interior_view_mode",OCCLUSION)),0,2)
static func indoors(city: Node,point: Vector3) -> bool:
	for room in city.interiors:
		if is_instance_valid(room) and room.contains_position(point):return true
	return false
static func face(section: Dictionary) -> String:
	return str(section.node.get_meta("view_face",section.node.get_instance_id()))
static func probes(camera: Vector3,actor: Vector3) -> PackedVector3Array:
	var toward:=camera-actor;var right:=Vector3(toward.z,0,-toward.x).normalized();var result:=PackedVector3Array()
	for height in [.45,1.15,1.85]:
		for side in [-.32,0.,.32]:result.append(actor+Vector3.UP*height+right*side)
	return result
static func obstructs(section: Dictionary,camera: Vector3,actor: Vector3,ends: PackedVector3Array=PackedVector3Array()) -> bool:
	var node: Node3D=section.node
	if node.get_meta("module_type","")=="window":return false
	var leaf: Node3D=node.get_node_or_null("Hinge/LeafCollision")
	if leaf==null:leaf=node.get_node_or_null("LeafCollision")
	if ends.is_empty():ends=probes(camera,actor)
	var inverse:=node.global_transform.affine_inverse();var start:=inverse*camera;var bounds: AABB=section.get("bounds",AABB()).grow(.08 if node.has_meta("length") else .04)
	if leaf!=null and leaf.get_child_count()>0:
		var shape: CollisionShape3D=leaf.get_child(0);inverse=shape.global_transform.affine_inverse();start=inverse*camera;bounds=AABB(-shape.shape.size*.5,shape.shape.size)
	for point in ends:
		var end:=inverse*point
		if leaf!=null:
			if bounds.intersects_segment(start,end)!=null:return true
			continue
		if node.has_meta("length"):
			var hit: Variant=Plane(Vector3.BACK,0.).intersects_segment(start,end)
			if hit==null or not bounds.has_point(hit):continue
			var in_opening:=false
			for opening in node.get_meta("view_openings",[]):
				var along: float=hit.x+float(node.get_meta("length"))*.5;var bottom: float=float(node.get_meta("view_floor",.18))+float(opening.bottom)
				if absf(along-float(opening.offset))<float(opening.width)*.5-.04 and hit.y>bottom+.04 and hit.y<bottom+float(opening.height)-.04:in_opening=true;break
			if not in_opening:return true
		elif bounds.intersects_segment(start,end)!=null:return true
	return false
static func targets(sections: Array,camera: Vector3,actor: Vector3) -> Dictionary:
	var hidden: Dictionary={}
	var ends:=probes(camera,actor)
	for section in sections:
		var id:=face(section)
		if not hidden.has(id) and obstructs(section,camera,actor,ends):hidden[id]=true
	return hidden
static func sample_targets(sections: Array,camera: Vector3,actor: Vector3,cache: Dictionary,force: bool=false) -> Dictionary:
	var now:=Time.get_ticks_usec()
	if not force and cache.has("at") and now-int(cache.at)<33333 and camera.distance_squared_to(cache.camera)<.16 and actor.distance_squared_to(cache.actor)<.04:return cache.targets
	cache.at=now;cache.camera=camera;cache.actor=actor;cache.targets=targets(sections,camera,actor);cache.scans=int(cache.get("scans",0))+1
	return cache.targets
static func fade(section: Dictionary,blocked: bool,delta: float) -> float:
	section["occlusion_hold"]=.18 if blocked else maxf(0.,float(section.get("occlusion_hold",0.))-delta)
	section.target=0. if blocked or section.occlusion_hold>0 else 1.
	section.alpha=move_toward(float(section.alpha),float(section.target),delta*7.)
	return section.alpha
static func wall_faces(walls: Dictionary) -> Dictionary:
	# Appearance runs on one connected straight wall share one visibility decision.
	var rows: Dictionary={};var lines: Dictionary={};var result: Dictionary={}
	for row in walls.values():rows[row.id]=row
	for row in rows.values():
		var axis:=0 if is_equal_approx(row.a[1],row.b[1]) else 1;var key:=str(axis)+":"+str(row.a[1-axis])
		if not lines.has(key):lines[key]=[]
		lines[key].append({"id":row.id,"start":minf(row.a[axis],row.b[axis]),"end":maxf(row.a[axis],row.b[axis])})
	for key in lines:
		var line: Array=lines[key];line.sort_custom(func(a,b):return a.start<b.start);var end:=-INF;var id:=""
		for row in line:
			if row.start>end+.001:id=key+":"+str(row.start)
			result[row.id]=id;end=maxf(end,row.end)
	return result
static func roof_limit(city: Node,pivot: Vector3,desired: Vector3) -> Vector3:
	if desired.y<=pivot.y:return desired
	var result:=desired
	for room in city.interiors:
		if not is_instance_valid(room) or not room.contains_position(pivot-Vector3.UP*1.35):continue
		var top: float=room.global_position.y+room.floor_level+room.wall_height-.22
		var hit: Variant=Plane(Vector3.UP,top).intersects_segment(pivot,result)
		if hit==null:continue
		var covered:=false
		if room.has_method("has_roof_at"):covered=room.has_roof_at(Vector2(hit.x,hit.z))
		else:
			var local: Vector3=room.to_local(hit);covered=Rect2(-room.floor_size*.5-Vector2.ONE*.6,room.floor_size+Vector2.ONE*1.2).has_point(Vector2(local.x,local.z))
		if covered:result=pivot+(hit-pivot)*.97
	return result
