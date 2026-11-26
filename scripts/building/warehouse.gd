extends RefCounted
## Inventory only holds unplaced furniture. Publish the layout and its stock movement together.
const RECIPES={
	"jade_parasol":{"branch":4,"cotton_cloth":2,"ramie_cloth":1},
	"jade_ceramics":{"birch":3,"sandstone":4,"silver_ore":1},
	"jade_screen":{"birch":4,"ramie_cloth":1},
	"jade_lamp":{"branch":3,"copper":2,"cotton_cloth":1},
	"jade_basin":{"nephrite":3,"sandstone":2},
	"jade_chime":{"cedar":2,"silver_ore":3,"copper":2}}
static func stocked(id: String) -> bool:return id=="jade_flower_paper" or RECIPES.has(id)
static func count_in(layout: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for row in layout.get("elements",[]):
		if row.get("type")=="object" and stocked(str(row.get("kind",""))):result[row.kind]=int(result.get(row.kind,0))+1
	return result
static func balance(inventory: Dictionary,before: Dictionary,after: Dictionary) -> Dictionary:
	var was:=count_in(before);var now:=count_in(after);var changes: Dictionary={}
	for id in RECIPES.keys()+["jade_flower_paper"]:
		var delta:=int(was.get(id,0))-int(now.get(id,0))
		if int(inventory.get(id,0))+delta<0:return {"ok":false,"message":"仓库里没有足够的成品。"}
		if delta!=0:changes[id]=delta
	return {"ok":true,"changes":changes}
static func settle(authority: RefCounted,result: Dictionary) -> void:
	for id in result.changes:authority.add(id,result.changes[id])
static func make(authority: RefCounted,args: Dictionary) -> Dictionary:
	var id: String=str(args.get("item",""));var parcel: String=str(args.get("parcel_id",""))
	var land=preload("res://scripts/building/parcels.gd");var state: Dictionary=authority.state
	var pos: Array=state.player_position;var point:=Vector3(pos[0],pos[1],pos[2])
	var owned: bool=land.map_for(parcel)==state.map_id and land.owns(state,parcel) and land.distance_to(parcel,point)<=land.REACH
	if not owned or not RECIPES.has(id) or not authority.job.is_empty():return authority.fail("请在自己的地皮进入建造，再制作家具。")
	for material in RECIPES[id]:
		if authority.count(material)<RECIPES[id][material]:return authority.fail("还缺少"+preload("res://scripts/services/game_data.gd").item(material).name+"。")
	for material in RECIPES[id]:authority.add(material,-int(RECIPES[id][material]))
	authority.add(id,1)
	return {"ok":true,"message":preload("res://scripts/building/catalog.gd").OBJECTS[id].name+"已做好，收进仓库。"}
