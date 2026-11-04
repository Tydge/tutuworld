extends RefCounted
## Editable half-metre cells/edges, encoded as compact rectangles and collinear runs.
const STEP:=.5
const CHUNK:=8 # four metres
static func cell(p: Vector2) -> Vector2i:return Vector2i(floori(p.x/STEP),floori(p.y/STEP))
static func point(p: Vector2i) -> Vector2:return Vector2(p)*STEP
static func area(row: Dictionary) -> Rect2:
	var a:=Vector2(row.a[0],row.a[1]);var b:=Vector2(row.b[0],row.b[1]);return Rect2(a.min(b),(b-a).abs())
static func style_key(row: Dictionary) -> String:return str(row.get("color","eadcc5"))+":"+str(row.get("style","original"))+":"+str(row.get("painted",false))+(JSON.stringify(row.faces) if not row.get("faces",{}).is_empty() else "")
static func coordinates(row: Dictionary) -> Array[Vector2i]:
	var r:=area(row);var out: Array[Vector2i]=[]
	for z in range(roundi(r.position.y/STEP),roundi(r.end.y/STEP)):
		for x in range(roundi(r.position.x/STEP),roundi(r.end.x/STEP)):out.append(Vector2i(x,z))
	return out
static func edges(row: Dictionary) -> Array[Vector3i]:
	var a:=Vector2i(roundi(row.a[0]/STEP),roundi(row.a[1]/STEP));var b:=Vector2i(roundi(row.b[0]/STEP),roundi(row.b[1]/STEP));var out: Array[Vector3i]=[]
	if a.y==b.y:
		for x in range(mini(a.x,b.x),maxi(a.x,b.x)):out.append(Vector3i(x,a.y,0))
	elif a.x==b.x:
		for z in range(mini(a.y,b.y),maxi(a.y,b.y)):out.append(Vector3i(a.x,z,1))
	return out
static func ends(edge: Vector3i) -> Array[Vector2i]:
	var a:=Vector2i(edge.x,edge.y);return [a,a+(Vector2i.RIGHT if edge.z==0 else Vector2i.DOWN)]
static func index(elements: Array) -> Dictionary:
	var floors: Dictionary={};var walls: Dictionary={};var duplicate:=""
	for row in elements:
		if row.type=="floor":
			for c in coordinates(row):
				if floors.has(c):duplicate="同层地板不能重叠。"
				floors[c]=row
		elif row.type=="wall":
			for e in edges(row):
				if walls.has(e):duplicate="这段墙壁已经存在。"
				walls[e]=row
	return {"floors":floors,"walls":walls,"error":duplicate}
static func covered(bounds: Rect2,floors: Dictionary) -> bool:
	if bounds.size.x<=0 or bounds.size.y<=0:return false
	var start:=cell(bounds.position+Vector2.ONE*.0001);var last:=cell(bounds.end-Vector2.ONE*.0001)
	for z in range(start.y,last.y+1):
		for x in range(start.x,last.x+1):
			if not floors.has(Vector2i(x,z)):return false
	return true
static func rectangles(cells: Dictionary) -> Array:
	var pending:=cells.duplicate();var result: Array=[];var ordered: Array=pending.keys();ordered.sort_custom(func(a,b):return a.y<b.y or (a.y==b.y and a.x<b.x))
	for p in ordered:
		if not pending.has(p):continue
		var key: String=style_key(pending[p]);var width:=1;var height:=1
		while pending.has(p+Vector2i(width,0)) and style_key(pending[p+Vector2i(width,0)])==key:width+=1
		while true:
			var complete:=true
			for x in range(width):
				var next: Vector2i=p+Vector2i(x,height)
				if not pending.has(next) or style_key(pending[next])!=key:complete=false;break
			if not complete:break
			height+=1
		var row: Dictionary=pending[p].duplicate(true);row.a=[p.x*STEP,p.y*STEP];row.b=[(p.x+width)*STEP,(p.y+height)*STEP];result.append(row)
		for z in range(height):
			for x in range(width):pending.erase(p+Vector2i(x,z))
	return result
static func runs(walls: Dictionary) -> Array:
	var pending:=walls.duplicate();var result: Array=[];var ordered: Array=pending.keys();ordered.sort_custom(func(a,b):return a.z<b.z or (a.z==b.z and (a.y<b.y or (a.y==b.y and a.x<b.x))))
	for p in ordered:
		if not pending.has(p):continue
		var step:=Vector3i(1,0,0) if p.z==0 else Vector3i(0,1,0);var length_:=1;var key: String=style_key(pending[p])
		while pending.has(p+step*length_) and style_key(pending[p+step*length_])==key:length_+=1
		var row: Dictionary=pending[p].duplicate(true);var a:=Vector2(p.x,p.y)*STEP;var b:=a+Vector2(step.x,step.y)*length_*STEP
		var axis: int=p.z
		if row.a[axis]>row.b[axis]:row.a=[b.x,b.y];row.b=[a.x,a.y]
		else:row.a=[a.x,a.y];row.b=[b.x,b.y]
		result.append(row)
		for i in range(length_):pending.erase(p+step*i)
	return result
static func compress(layout: Dictionary,grid: Dictionary,level: int=0) -> Dictionary:
	var Storeys=preload("res://scripts/building/storeys.gd")
	var other: Array=layout.elements.filter(func(row):return Storeys.of(row)!=level)
	layout=Storeys.subset(layout,level)
	var next:=layout.duplicate(true);var generated: Array=[]
	if not grid.has("compressed_floor"):grid["compressed_floor"]=rectangles(grid.floors);grid["compressed_wall"]=runs(grid.walls)
	for row in grid.compressed_floor+grid.compressed_wall:generated.append(row.duplicate(true))
	var used: Dictionary={};var retained: Array=[];var openings: Array=[];var old_walls: Dictionary={}
	for row in layout.elements:
		if row.type=="wall":old_walls[row.id]=row
		elif row.type!="floor":retained.append(row);used[row.id]=true
	for row in retained:
		if row.type not in ["door","window"]:continue
		if row.has("anchor"):openings.append({"row":row,"p":Vector2(row.anchor[0],row.anchor[1]),"axis":row.axis});continue
		if not old_walls.has(row.wall):continue
		var wall: Dictionary=old_walls[row.wall];var a:=Vector2(wall.a[0],wall.a[1]);var b:=Vector2(wall.b[0],wall.b[1]);var p:=a+(b-a).normalized()*float(row.offset);var axis:=0 if is_equal_approx(a.y,b.y) else 1
		row.anchor=[p.x,p.y];row.axis=axis;row.reverse=wall.a[axis]>wall.b[axis];openings.append({"row":row,"p":p,"axis":axis})
	for row in generated:
		if used.has(row.id):
			while used.has("build_%d"%next.next_id):next.next_id+=1
			row.id="build_%d"%next.next_id;next.next_id+=1
		used[row.id]=true
	for opening in openings:
		for row in generated:
			if row.type!="wall":continue
			var r:=area(row);var axis: int=opening.axis
			if (0 if is_equal_approx(row.a[1],row.b[1]) else 1)!=axis:continue
			if absf(float(row.a[1-axis])-opening.p[1-axis])>.001:continue
			if opening.p[axis]<r.position[axis]-.001 or opening.p[axis]>r.end[axis]+.001:continue
			opening.row.wall=row.id;opening.row.offset=Vector2(row.a[0],row.a[1]).distance_to(opening.p);break
	next.elements=generated+retained+other;next.schema=4;return next
static func vertex_degrees(walls: Dictionary) -> Dictionary:
	var vertices: Dictionary={}
	for e in walls:
		for p in ends(e):
			if not vertices.has(p):vertices[p]=[]
			vertices[p].append(e)
	return vertices
static func cut(layout: Dictionary,bounds: Rect2,filter: String="all",only_edge: Variant=null,level: int=0) -> Dictionary:
	var Storeys=preload("res://scripts/building/storeys.gd")
	var other: Array=layout.elements.filter(func(row):return Storeys.of(row)!=level)
	var next:=Storeys.subset(layout,level).duplicate(true);var grid:=index(next.elements);var selected: Dictionary={};var old_walls: Dictionary={}
	for row in next.elements:
		if row.type=="wall":old_walls[row.id]=row
	if filter in ["all","floor"]:
		for c in grid.floors.keys():
			if bounds.has_point(point(c)+Vector2.ONE*STEP*.5):grid.floors.erase(c)
	if filter in ["all","wall"]:
		for e in grid.walls.keys():
			var pair:=ends(e);var middle: Vector2=(point(pair[0])+point(pair[1]))*.5
			if (only_edge!=null and e==only_edge) or (only_edge==null and bounds.grow(.001).has_point(middle)):grid.walls.erase(e)
	for row in next.elements:
		if row.type=="object" and filter in ["all","object"] and bounds.has_point(Vector2(row.position[0],row.position[1])):selected[row.id]=true
	# Mark removed door/window support before runs are compressed and remapped.
	for row in next.elements:
		if row.type not in ["door","window"] or not old_walls.has(row.wall):continue
		var wall: Dictionary=old_walls[row.wall];var a:=Vector2(wall.a[0],wall.a[1]);var b:=Vector2(wall.b[0],wall.b[1]);var dir: Vector2=(b-a).normalized();var center:=Vector2(row.anchor[0],row.anchor[1]) if row.has("anchor") else a+dir*float(row.offset)
		var axis: int=int(row.get("axis",0 if is_equal_approx(a.y,b.y) else 1));var half:=1.43 if row.type=="door" else 1.1
		var first:=floori((center[axis]-half-.15)/STEP);var last:=ceili((center[axis]+half+.15)/STEP);var plane_:=roundi(center[1-axis]/STEP)
		for i in range(first,last):
			var e:=Vector3i(i,plane_,0) if axis==0 else Vector3i(plane_,i,1)
			if not grid.walls.has(e):selected[row.id]=true;break
	next.elements=next.elements.filter(func(row):return not selected.has(row.id));next=compress(next,grid,level);next.elements.append_array(other)
	return next
