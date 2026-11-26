extends RefCounted
## Independent player paths for regression runs. Search only legal actions on the presented board.
const Board=preload("res://scripts/jade/play_board.gd")
static func solution(board: RefCounted,side_goal:=false) -> Array:
	var r=board.rule;var d:Dictionary=r.data;var g:Array=r.goal
	var path:Array=[]
	match r.house:
		"weir":return canals(r,side_goal)
		"oil":
			for mask in range(1,32):
				var total:=0;path=[]
				for i in 5:
					if mask&(1<<i):path.append(i);total+=int(g[i])
				if total==d.mass:return path
		"basket","carver":
			for i in 9:
				var k:int=r.transformed(i) if r.house=="carver" else i
				if int(d.mask)&(1<<k):path.append(i)
		"weave":
			for i in 3:path.append(g[(g.size()+2+i+int(d.offset))%g.size()])
		"pastry":return tile_pan(r.data.block.duplicate(),[])
		"paper":return [9,12,0,10,13,4,11,14,8,15]
		"music":return [0,1,2,5,3,d.tonic,7]
		"pipa","duty","books":return g.duplicate()
		"stage":return g.duplicate()
		"dojo":return g.duplicate()
		"herbal":
			for n in g:
				path.append(2);path.append(d.samples.find(n)+3)
		"noodle":return [g[0]-1,g[0]+g[1]-1]
		"garden":
			if d.shadows.size()==2:return d.shadows.duplicate()
			return [0,4 if 4 in d.shadows else 5] if 1 in d.shadows and 2 in d.shadows else [3,1 if 1 in d.shadows else 2]
		"post":
			for entry in d.cards:path.append(entry[2])
		"archive":return g.duplicate()
		"chamber":return g.slice(1)
		"lacquer":
			for i in 3:
				for n in g[i]:path.append(i)
		"poetry":
			for c in str(d.verse):path.append(r.labels.find(c))
		"ledger":
			for c in str(g[0]):path.append(10 if c=="0" else int(c)-1)
			path.append(11)
		"kiln":
			var heat:int=d.heat
			for k in 4:path.append((g[k]-heat+int(d.draft[k]))/2);heat=g[k]
		"audience":return [0,2,3] if side_goal else [0,1,3]
		"hostel":
			for order in [[0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]]:
				if r.route_length(order,true)==d.limit:return order
		"fiddler":
			for j in 2:
				var diff:int=g[j]-r.v[j]
				for k in absi(diff):path.append(2 if diff>0 else 1)
		"tailorhome":
			while path.size()<5:
				for i in 5:
					if i not in path and d.above[i].all(func(n):return n in path):path.append(i)
		"baihe":
			var lineup:Array=r.v.duplicate()
			for i in 4:
				if lineup[i]!=g[i]:
					var j:=lineup.find(g[i]);r.swap(lineup,i,j);path.append_array([i,j])
		"academy":
			var duel:RefCounted=Board.new(board.house,board.serial,board.variant,board.deal_base)
			while not duel.rule.done:
				var moved:=false
				for i in d.takes.size():
					if duel.rule.enabled(i) and not r.winning(duel.rule.v[0]-d.takes[i]):
						duel.play(i);path.append(i);moved=true;break
				if not moved:return []
		_:return search(board)
	return path

static func canals(r: RefCounted,pond: bool) -> Array:
	var map:String=r.data.map
	var target:=(1<<map.find("R"))|(1<<map.find("M"))
	if pond:target|=1<<map.find("F")
	var start:=1<<map.find("S");var queue:Array=[start];var parent:Dictionary={start:-1};var n:=0
	var edges:Array=[]
	for i in 24:
		var mask:=0
		for j in r.neighbors(i,6,24):
			if map[j]!="#":mask|=1<<j
		edges.append(mask)
	while n<queue.size():
		var wet:int=queue[n];n+=1
		if (wet&target)==target:
			var path:Array=[24]
			while wet!=start:
				var prev:int=parent[wet];path.push_front(roundi(log(wet^prev)/log(2.)));wet=prev
			return path
		for i in 24:
			if (wet&(1<<i))!=0 or (int(edges[i])&wet)==0 or map[i]=="#":continue
			var next:=wet|(1<<i)
			if not parent.has(next):parent[next]=wet;queue.append(next)
	return []

static func search(board: RefCounted) -> Array:
	var r=Board.new(board.house,board.serial,board.variant,board.deal_base).rule
	var queue:Array=[[r.v.duplicate(true),r.picked,r.step,[]]]
	var seen:Dictionary={};var cursor:=0
	while cursor<queue.size() and cursor<6000:
		var row:Array=queue[cursor];cursor+=1
		for i in r.labels.size():
			r.v=row[0].duplicate(true);r.picked=row[1];r.step=row[2];r.done=false
			if r.house=="pastry":r.data.pairs=[]
			if r.house=="farmhouse" and r.step>=4:continue
			if not r.enabled(i):continue
			r.act(i)
			var key:=str([r.v,r.picked,r.step])
			if r.done:return row[3]+[i]
			if not seen.has(key):
				seen[key]=true;queue.append([r.v.duplicate(true),r.picked,r.step,row[3]+[i]])
	return []


static func tile_pan(occupied: Array, path: Array) -> Array:
	var first:=-1
	for i in 12:
		if i not in occupied:first=i;break
	if first<0:return path
	for j in [first+1,first+4]:
		if j>=12 or j in occupied or (j==first+1 and first%4==3):continue
		var found:=tile_pan(occupied+[first,j],path+[first,j])
		if not found.is_empty():return found
	return []
