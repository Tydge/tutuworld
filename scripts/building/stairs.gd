extends RefCounted
## Shared authored paths drive geometry, smooth walk surfaces, openings and checks.
const Storeys=preload("res://scripts/building/storeys.gd")
const Grid=preload("res://scripts/building/grid_layout.gd")
const Site=preload("res://scripts/building/site.gd")
const Catalog=preload("res://scripts/building/catalog.gd")
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
const FORMS=Storeys.STAIR_FORMS
const WIDTH:=3.
static var part_cache: Dictionary={}
static func definition(form: String) -> Dictionary:
	var h:=Storeys.HEIGHT
	match form:
		"l":return {"flights":[[Vector3(-3.5,0,2),Vector3(-3.5,h*.5,-2)],[Vector3(-2,h*.5,-3.5),Vector3(2,h,-3.5)]],"platforms":[[Rect2(-5,-5,3,3),h*.5]],"bottom":Rect2(-5,2,3,3),"top":Rect2(2,-5,3,3)}
		"u":return {"flights":[[Vector3(-1.5,0,2),Vector3(-1.5,h*.5,-2)],[Vector3(1.5,h*.5,-2),Vector3(1.5,h,2)]],"platforms":[[Rect2(-3,-5,6,3),h*.5]],"bottom":Rect2(-3,2,3,3),"top":Rect2(0,2,3,3)}
	return {"flights":[[Vector3(0,0,4),Vector3(0,h,-4)]],"platforms":[],"bottom":Rect2(-1.5,4,3,3),"top":Rect2(-1.5,-7,3,3)}
static func flight_rect(flight: Array) -> Rect2:
	var a: Vector3=flight[0];var b: Vector3=flight[1];var pad:=Vector2(WIDTH*.5,0) if absf(a.z-b.z)>.1 else Vector2(0,WIDTH*.5)
	return Rect2(Vector2(a.x,a.z).min(Vector2(b.x,b.z))-pad,(Vector2(b.x,b.z)-Vector2(a.x,a.z)).abs()+pad*2.)
static func local_parts(row: Dictionary,landings: bool=true) -> Array:
	var key: String=str(row.form)+str(landings)
	if part_cache.has(key):return part_cache[key]
	var data:=definition(row.form);var result: Array=[]
	for flight in data.flights:result.append(flight_rect(flight))
	for platform in data.platforms:result.append(platform[0])
	if landings:result.append(data.bottom);result.append(data.top)
	part_cache[key]=result;return result
static func world_rect(row: Dictionary,rect_: Rect2) -> Rect2:
	return Catalog.bounds(row,rect_.size,rect_.get_center())
static func parts(row: Dictionary,landings: bool=true) -> Array:
	var result: Array=[]
	for area in local_parts(row,landings):result.append(world_rect(row,area))
	return result
static func bounds(row: Dictionary) -> Rect2:
	var result: Rect2=parts(row)[0]
	for area in parts(row):result=result.merge(area)
	return result
static func local_point(row: Dictionary,p: Vector2) -> Vector2:
	return Catalog.rotate_xz(p-Vector2(row.position[0],row.position[1]),-float(row.yaw))
static func is_hole(row: Dictionary,p: Vector2) -> bool:
	var local:=local_point(row,p)
	for area in local_parts(row,false):
		if area.grow(-.001).has_point(local):return true
	return false
static func route(row: Dictionary) -> PackedVector3Array:
	var data:=definition(row.form);var local: Array=[Vector3(data.bottom.get_center().x,0,data.bottom.get_center().y)]
	for i in range(data.flights.size()):
		var flight: Array=data.flights[i]
		if i>0:
			var platform: Rect2=data.platforms[i-1][0];var middle:=platform.get_center();var prev: Vector3=data.flights[i-1][1]
			if row.form=="u":local.append(Vector3(prev.x,prev.y,middle.y));local.append(Vector3(flight[0].x,flight[0].y,middle.y))
			else:local.append(Vector3(middle.x,flight[0].y,middle.y))
		local.append(flight[0]);local.append(flight[1])
	local.append(Vector3(data.top.get_center().x,Storeys.HEIGHT,data.top.get_center().y))
	var result:=PackedVector3Array()
	for point: Vector3 in local:
		var p:=Catalog.rotate_xz(Vector2(point.x,point.z),float(row.yaw))+Vector2(row.position[0],row.position[1]);result.append(Vector3(p.x,point.y+Storeys.elevation(row)+Storeys.FLOOR,p.y))
	return result
static func validate(layout: Dictionary) -> Dictionary:
	var stairs: Array=layout.elements.filter(func(row):return row.type=="stairs")
	if stairs.is_empty():return {"ok":true}
	var floors_by_level: Dictionary={}
	for stair in stairs:
		for level in [Storeys.of(stair),Storeys.of(stair)+1]:
			if not floors_by_level.has(level):floors_by_level[level]=Grid.index(Storeys.subset(layout,level).elements).floors
	for stair in stairs:
		for cell in hole_cells(stair):floors_by_level[Storeys.of(stair)+1].erase(cell)
	if stairs.size()>16:return {"ok":false,"message":"同一地块最多16座楼梯。"}
	for stair in stairs:
		var level:=Storeys.of(stair);var data:=definition(stair.form)
		for area in parts(stair):
			if not Site.within(area.position) or not Site.within(area.end):return {"ok":false,"message":"楼梯连同休息平台需要留在建造地块内。"}
		for end in [[level,data.bottom],[level+1,data.top]]:
			var floors: Dictionary=floors_by_level[end[0]]
			if not Grid.covered(world_rect(stair,end[1]).grow(-.02),floors):return {"ok":false,"message":"请先在上下两层铺好3米宽的出入口地板；出入口不能落在另一座楼梯井里。"}
		for row in layout.elements:
			if row.id==stair.id or Storeys.of(row) not in [level,level+1]:continue
			var occupied: Array=[]
			if row.type in ["wall","railing"]:
				var a:=Vector2(row.a[0],row.a[1]);var b:=Vector2(row.b[0],row.b[1]);occupied=[Rect2(a.min(b),(b-a).abs()).grow(.13)]
			elif row.type=="roof" and Storeys.of(row)==level:
				var a:=Vector2(row.a[0],row.a[1]);var b:=Vector2(row.b[0],row.b[1]);occupied=[Rect2(a.min(b),(b-a).abs())]
			elif row.type=="object" and not Catalog.OBJECTS[row.kind].get("overlay",false):occupied=[Catalog.footprint(row)]
			elif row.type=="stairs" and Storeys.of(row)==level:occupied=parts(row)
			for obstacle: Rect2 in occupied:
				for area: Rect2 in parts(stair):
					if area.grow(-.18).intersects(obstacle.grow(-.01)):return {"ok":false,"message":"楼梯、平台和出入口需要净空；请移开墙壁、家具或下层旧屋顶。"}
	return {"ok":true}
static func floor_collision(parent: Node3D,points: PackedVector3Array) -> void:
	var body:=StaticBody3D.new();body.name="StairWalkSurface";body.collision_layer=8;body.collision_mask=0
	var shape:=ConvexPolygonShape3D.new();shape.points=points;var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);parent.add_child(body)
static func rail(builder: RefCounted,parent: Node3D,a: Vector3,b: Vector3,shared: RefCounted=null) -> void:
	var batch: RefCounted=shared if shared!=null else preload("res://scripts/building/stair_mesh.gd").new(builder)
	var wood: Material=builder.material("a78358",1);var cream: Material=builder.material("eee2c6")
	batch.capsule(a+Vector3.UP*1.1,b+Vector3.UP*1.1,.055,wood)
	var steps:=maxi(1,ceili(Vector2(a.x-b.x,a.z-b.z).length()/.65))
	for i in range(steps+1):
		var p:=a.lerp(b,float(i)/steps);batch.box(p+Vector3.UP*.54,Vector3(.075,1.12,.075),cream)
	# One continuous solid safety panel, rather than collisions for every baluster.
	var horizontal:=Vector3(b.x-a.x,0,b.z-a.z)
	var body:=StaticBody3D.new();body.name="RailCollision";body.collision_layer=4;body.collision_mask=0
	var points:=PackedVector3Array();var side:=horizontal.normalized().cross(Vector3.UP)*.055
	for point in [a,b]:
		for offset in [side,-side]:
			for y in [0.,1.15]:points.append(point+offset+Vector3.UP*y)
	var shape:=ConvexPolygonShape3D.new();shape.points=points;var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);parent.add_child(body)
	if shared==null:batch.finish(parent)
static func guard_edge(edges: Dictionary,cell: Vector2i,direction: Vector2i) -> void:
	var e:=Vector3i(cell.x+(1 if direction==Vector2i.RIGHT else 0),cell.y+(1 if direction==Vector2i.DOWN else 0),1 if direction.x!=0 else 0);var ends:=Grid.ends(e)
	edges[e]={"id":"guard","type":"wall","a":[ends[0].x*.5,ends[0].y*.5],"b":[ends[1].x*.5,ends[1].y*.5]}
static func explicit_guard_edges(layout: Dictionary,level: int) -> Dictionary:
	var edges: Dictionary={}
	for row in layout.elements:
		if row.type in ["wall","railing"] and Storeys.of(row)==level:
			for edge in Grid.edges(row):edges[edge]=true
	return edges
static func upper_guard_edges(row: Dictionary,upper_floors: Variant=null,explicit_edges: Dictionary={}) -> Array:
	var holes: Dictionary={};var edges: Dictionary={};var data:=definition(row.form)
	var position_: Array=row.get("position",[0.,0.]);var origin:=Vector2(position_[0],position_[1]);var yaw: float=row.get("yaw",0.)
	for area: Rect2 in local_parts(row,false):
		for cell in Grid.coordinates({"a":[area.position.x,area.position.y],"b":[area.end.x,area.end.y]}):holes[cell]=true
	var top: Vector3=data.flights[-1][1];var end_dir: Vector3=top-data.flights[-1][0];end_dir.y=0;end_dir=end_dir.normalized()
	for cell in holes:
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if holes.has(cell+direction):continue
			var middle:=Grid.point(cell)+Vector2.ONE*.25+Vector2(direction)*.25;var diff:=Vector3(middle.x-top.x,0,middle.y-top.z)
			if absf(diff.dot(end_dir))<.05 and Vector2(diff.x,diff.z).length()<WIDTH*.5+.05:continue
			var neighbor:=Grid.point(cell+direction)+Vector2.ONE*.25
			var world:=origin+Catalog.rotate_xz(neighbor,yaw)
			if upper_floors!=null and not upper_floors.has(Grid.cell(world)):continue
			guard_edge(edges,cell,direction)
	if upper_floors!=null:
		# Protect exposed landing sides, leaving the stair mouth and floor connections open.
		var area: Rect2=data.top
		for cell in Grid.coordinates({"a":[area.position.x,area.position.y],"b":[area.end.x,area.end.y]}):
			var world:=origin+Catalog.rotate_xz(Grid.point(cell)+Vector2.ONE*.25,yaw)
			if not upper_floors.has(Grid.cell(world)):continue
			for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var neighbor: Vector2i=cell+direction
				if holes.has(neighbor):continue
				var other:=origin+Catalog.rotate_xz(Grid.point(neighbor)+Vector2.ONE*.25,yaw)
				if not upper_floors.has(Grid.cell(other)):guard_edge(edges,cell,direction)
	if not explicit_edges.is_empty():
		for edge in edges.keys():
			var ends:=Grid.ends(edge);var a:=origin+Catalog.rotate_xz(Grid.point(ends[0]),yaw);var b:=origin+Catalog.rotate_xz(Grid.point(ends[1]),yaw)
			var world_edges:=Grid.edges({"a":[a.x,a.y],"b":[b.x,b.y]})
			if not world_edges.is_empty() and explicit_edges.has(world_edges[0]):edges.erase(edge)
	return Grid.runs(edges)
static func build(builder: RefCounted,parent: Node3D,row: Dictionary,upper_floors: Variant=null,explicit_edges: Dictionary={}) -> void:
	var batch:=preload("res://scripts/building/stair_mesh.gd").new(builder)
	var data:=definition(row.form);var oak: Material=builder.material(row.get("color","c6a373"),1);var cream: Material=builder.material("eee2c6")
	for flight: Array in data.flights:
		var a: Vector3=flight[0];var b: Vector3=flight[1];var along:=Vector3(b.x-a.x,0,b.z-a.z).normalized();var side:=along.cross(Vector3.UP)*WIDTH*.5
		var steps:=roundi((b.y-a.y)/Storeys.HEIGHT*24.)
		for i in range(steps):
			var start:=a.lerp(b,float(i)/steps);var end:=a.lerp(b,float(i+1)/steps);var center: Vector3=(start+end)*.5;center.y=end.y-.065
			var size_:=Vector3(WIDTH,.13,Vector2(b.x-a.x,b.z-a.z).length()/steps+.025) if absf(along.z)>.5 else Vector3(Vector2(b.x-a.x,b.z-a.z).length()/steps+.025,.13,WIDTH)
			batch.box(center,size_,oak,.025)
			var riser:=size_;riser.y=(end.y-start.y);riser.z=.045 if absf(along.z)>.5 else WIDTH
			if absf(along.x)>.5:riser.x=.045
			batch.box(Vector3(start.x,(start.y+end.y)*.5-.025,start.z),riser,cream)
		var points:=PackedVector3Array()
		for p: Vector3 in [a,b]:
			for offset: Vector3 in [side,-side]:
				points.append(p+offset);points.append(p+offset-Vector3.UP*.18)
		floor_collision(parent,points)
		for sign_ in [-1,1]:rail(builder,parent,a+side*sign_,b+side*sign_,batch)
	for platform: Array in data.platforms:
		var area: Rect2=platform[0];var mid:=area.get_center();batch.box(Vector3(mid.x,platform[1]-.10,mid.y),Vector3(area.size.x,.20,area.size.y),oak,.035)
		var points:=PackedVector3Array()
		for x in [area.position.x,area.end.x]:
			for z in [area.position.y,area.end.y]:
				for y in [float(platform[1])-.20,float(platform[1])]:points.append(Vector3(x,y,z))
		floor_collision(parent,points)
		# Outer platform edges; the stair mouths remain open.
		if row.form=="u":
			rail(builder,parent,Vector3(-3,platform[1],-2),Vector3(-3,platform[1],-5),batch);rail(builder,parent,Vector3(-3,platform[1],-5),Vector3(3,platform[1],-5),batch);rail(builder,parent,Vector3(3,platform[1],-5),Vector3(3,platform[1],-2),batch)
		else:
			rail(builder,parent,Vector3(-5,platform[1],-2),Vector3(-5,platform[1],-5),batch);rail(builder,parent,Vector3(-5,platform[1],-5),Vector3(-2,platform[1],-5),batch)
	# Guard supported well edges and the exposed upper landing.
	var guard:=Node3D.new();guard.name="UpperGuard";parent.add_child(guard)
	var guard_batch:=preload("res://scripts/building/stair_mesh.gd").new(builder)
	for edge in upper_guard_edges(row,upper_floors,explicit_edges):
		var a:=Vector3(edge.a[0],Storeys.HEIGHT,edge.a[1]);var b:=Vector3(edge.b[0],Storeys.HEIGHT,edge.b[1])
		rail(builder,guard,a,b,guard_batch)
	guard_batch.finish(guard)
	batch.finish(parent)

static func hole_cells(row: Dictionary) -> Array:
	var cells: Dictionary={}
	for area: Rect2 in parts(row,false):
		for cell in Grid.coordinates({"a":[area.position.x,area.position.y],"b":[area.end.x,area.end.y]}):cells[cell]=true
	return cells.keys()
static func preview(layout: Dictionary,row: Dictionary,moving: String="") -> Dictionary:
	if Storeys.of(row)<0 or Storeys.of(row)>=Storeys.MAX-1:return {"ok":false,"message":"4楼已达层数上限，请在较低楼层放置连接楼梯。"}
	var point:=Vector2(row.position[0],row.position[1]);var yaw: float=row.get("yaw",0.)
	if not point.is_finite() or absf(point.x*2.-roundf(point.x*2.))>.001 or absf(point.y*2.-roundf(point.y*2.))>.001 or not is_finite(yaw) or absf(yaw/90.-roundf(yaw/90.))>.001:return {"ok":false,"message":"楼梯须对齐半米网格，并按90度旋转。"}
	if not FORMS.has(row.get("form","")) or not Site.within(point):return {"ok":false,"message":"请选择有效的楼梯造型和位置。"}
	var candidate:=layout.duplicate(false);candidate.elements=layout.elements.filter(func(item):return item.id!=moving)
	var pending:=row.duplicate(true);pending.id=moving if moving!="" else "__stair_preview";candidate.elements.append(pending)
	return validate(candidate)
