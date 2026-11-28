extends RefCounted
## Plan a facade change across aligned storeys, then validate the final structure.
const L=preload("res://scripts/building/layout.gd")
const G=preload("res://scripts/building/grid_layout.gd")
const E=preload("res://scripts/building/room_edit.gd")
const R=preload("res://scripts/building/room_plan.gd")
const S=preload("res://scripts/building/storeys.gd")
static func edge_at(ctx: Dictionary,i: int) -> Vector3i:
	return Vector3i(i,ctx.plane,0) if ctx.axis==1 else Vector3i(ctx.plane,i,1)
static func clip(ctx: Dictionary,lo: int,hi: int) -> Dictionary:
	ctx=ctx.duplicate(false);ctx.lo=maxi(lo,ctx.lo);ctx.hi=mini(hi,ctx.hi);ctx.edges={}
	for i in range(ctx.lo,ctx.hi):ctx.edges[edge_at(ctx,i)]=ctx.base.grid.walls[edge_at(ctx,i)]
	ctx.follow=ctx.follow.duplicate()
	for info in ctx.base.objects:
		if not ctx.follow.has(info.row.id):continue
		var foot: Rect2=info.wall_foot
		if foot.position[ctx.along]<ctx.lo*.5-.001 or foot.end[ctx.along]>ctx.hi*.5+.001:ctx.follow.erase(info.row.id)
	return ctx
static func layer_contexts(source: Dictionary,level: int,reference: Dictionary) -> Array:
	var base:=E.prepare(source,level);var contexts: Array=[];var done: Dictionary={}
	for i in range(reference.lo,reference.hi):
		if done.has(i):continue
		var edge:=edge_at(reference,i)
		if not base.grid.walls.has(edge):continue
		var sides:=E.adjacent(edge);var inside: Vector2i=sides[0] if reference.outward<0 else sides[1]
		var outside: Vector2i=sides[1] if reference.outward<0 else sides[0]
		if not base.plan.cell_rooms.has(inside) or base.plan.cell_rooms.has(outside):continue
		var ends:=G.ends(edge);var unit:=L.unit_at(source,base.grid.walls[edge].id,(G.point(ends[0])+G.point(ends[1]))*.5)
		var ctx:=E.wall_context(base,unit,G.point(inside)+Vector2.ONE*.25)
		if ctx.is_empty() or ctx.outward!=reference.outward:continue
		ctx=clip(ctx,reference.lo,reference.hi);contexts.append(ctx)
		for n in range(ctx.lo,ctx.hi):done[n]=true
	# An unfinished upper storey may have only its slab. Carry an aligned slab
	# boundary too, while preserving wider terraces and deliberate setbacks.
	var open_run: Array=[]
	for i in range(reference.lo,reference.hi+1):
		var follows:=false
		if i<reference.hi and not done.has(i):
			var sides:=E.adjacent(edge_at(reference,i));var inside: Vector2i=sides[0] if reference.outward<0 else sides[1];var outside: Vector2i=sides[1] if reference.outward<0 else sides[0]
			follows=base.grid.floors.has(inside) and not base.grid.floors.has(outside) and not base.plan.cell_rooms.has(inside)
		if follows:open_run.append(i)
		elif not open_run.is_empty():
			contexts.append({"floor_only":true,"base":base,"lo":open_run[0],"hi":open_run[-1]+1,"axis":reference.axis,"along":reference.along,"plane":reference.plane,"outward":reference.outward});open_run=[]
	return contexts
static func slab_plan(ctx: Dictionary,delta: int) -> Dictionary:
	var grid:={"floors":ctx.base.grid.floors.duplicate(),"walls":ctx.base.grid.walls.duplicate()}
	var target: int=ctx.plane+delta;var lo:=mini(target,ctx.plane);var hi:=maxi(target,ctx.plane);var grow: bool=delta*ctx.outward>0
	for i in range(ctx.lo,ctx.hi):
		var nearest:=Vector2i(i,ctx.plane-(1 if ctx.outward>0 else 0)) if ctx.axis==1 else Vector2i(ctx.plane-(1 if ctx.outward>0 else 0),i)
		for n in range(lo,hi):
			var cell:=Vector2i(i,n) if ctx.axis==1 else Vector2i(n,i)
			if grow:
				var p:=G.point(cell);var site=preload("res://scripts/building/site.gd")
				var map_id: String = ctx.base.source.get("map_id", "city")
				if not site.within(p,map_id) or not site.within(p+Vector2.ONE*.5,map_id):return L.fail("楼板扩建超出了建造地块。")
				if not grid.floors.has(cell):grid.floors[cell]=ctx.base.grid.floors[nearest]
			else:grid.floors.erase(cell)
	var a:=Vector2(ctx.lo*.5,lo*.5) if ctx.axis==1 else Vector2(lo*.5,ctx.lo*.5)
	var size_:=Vector2((ctx.hi-ctx.lo)*.5,maxf(.01,(hi-lo)*.5)) if ctx.axis==1 else Vector2(maxf(.01,(hi-lo)*.5),(ctx.hi-ctx.lo)*.5)
	return {"ok":true,"grid":grid,"moves":{},"openings":{},"roofs":{},"region":Rect2(a,size_),"exterior_expansion":grow}
static func plan(context: Dictionary,delta: int) -> Dictionary:
	var source: Dictionary=context.base.source;var groups: Dictionary={context.base.level:[context]}
	if not context.has("linked_storeys"):
		var linked: Dictionary={}
		for direction in [-1,1]:
			for step in range(1,S.MAX):
				var level: int=context.base.level+direction*step
				if level<0 or level>=S.MAX:break
				var contexts:=layer_contexts(source,level,context)
				if contexts.is_empty():break
				linked[level]=contexts
		context.linked_storeys=linked
	groups.merge(context.linked_storeys)
	if groups.size()==1:return E.resize_layer(context,delta)
	var combined: Dictionary={};var primary: Dictionary={}
	for level in groups:
		var base:=E.prepare(source,level);var merged:={"ok":true,"grid":{"floors":base.grid.floors.duplicate(),"walls":base.grid.walls.duplicate()},"moves":{},"openings":{},"roofs":{},"region":Rect2(),"exterior_expansion":false}
		for ctx in groups[level]:
			var result:=slab_plan(ctx,delta) if ctx.get("floor_only",false) else E.resize_layer(ctx,delta,true)
			if not result.ok:return result
			if level==context.base.level:primary=result
			for type in ["floors","walls"]:
				for key in base.grid[type]:
					if not result.grid[type].has(key):merged.grid[type].erase(key)
				for key in result.grid[type]:
					if not base.grid[type].has(key) or result.grid[type][key]!=base.grid[type][key]:merged.grid[type][key]=result.grid[type][key]
			merged.moves.merge(result.moves);merged.openings.merge(result.openings)
			merged.region=result.region if merged.region.size==Vector2.ZERO else merged.region.merge(result.region)
			merged.exterior_expansion=merged.exterior_expansion or result.exterior_expansion
		combined[level]=merged
	var next:=source
	for level in combined:
		var base:=E.prepare(next,level);next=E.materialize(base,combined[level])
	# Roofs follow the completed footprint. Split only when a setback changes part
	# of a rectangular roof edge; unchanged wings keep their original extent.
	for roof in source.elements:
		if roof.type!="roof" or not combined.has(S.of(roof)):continue
		var area:=L.rect(roof);var plane: float=context.plane*.5
		if not is_equal_approx(area.position[context.axis],plane) and not is_equal_approx(area.end[context.axis],plane):continue
		var lo:=maxf(area.position[context.along],context.lo*.5);var hi:=minf(area.end[context.along],context.hi*.5)
		if hi<=lo:continue
		var pieces: Array=[]
		for band in [[area.position[context.along],lo,false],[lo,hi,true],[hi,area.end[context.along],false]]:
			if band[1]-band[0]<.001:continue
			var row: Dictionary=roof.duplicate(true);row.a[context.along]=band[0];row.b[context.along]=band[1]
			if band[2]:
				for field in ["a","b"]:
					if is_equal_approx(row[field][context.axis],plane):row[field][context.axis]+=delta*.5
			if minf(L.rect(row).size.x,L.rect(row).size.y)<.5:return L.fail("缩建后屋顶太窄，请缩小拖动距离。")
			pieces.append(row)
		for index in range(pieces.size()):
			if index==0:next=L.replace(next,pieces[index])
			else:next=L.add(next,pieces[index])
	for level in combined:
		var old:=E.prepare(source,level);var final:=E.prepare(next,level);var result: Dictionary=combined[level]
		var added: Dictionary={};var removed: Dictionary={}
		for c in result.grid.floors:
			if not old.grid.floors.has(c):added[c]=true
		for c in old.grid.floors:
			if not result.grid.floors.has(c):removed[c]=true
		# Validate against final neighboring slabs, never a half-applied storey.
		old.below=final.below;old.above=final.above;old.lower_ceiling=final.lower_ceiling;old.lower_roofs=final.lower_roofs;old.roofs=final.roofs;old.source=next
		var checked:=E.support(old,added,removed)
		if not checked.ok:return checked
		checked=E.check_geometry(old,result)
		if not checked.ok:return checked
	primary.layout=next;primary.storeys=groups.keys()
	return primary
