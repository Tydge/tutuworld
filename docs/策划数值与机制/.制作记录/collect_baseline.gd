extends SceneTree
const DB=preload("res://scripts/services/game_data.gd")
const Stats=preload("res://scripts/services/character_stats.gd")
const Authority=preload("res://scripts/services/local_authority.gd")
const People=preload("res://scripts/city/npc_profiles.gd")
const Layout=preload("res://scripts/valley/valley_layout.gd")
const Fabric=preload("res://scripts/city/fabric_library.gd")
const OUT="/Users/wangtaizhi/兔兔的世界/docs/策划数值与机制/.核对基线/代码数据快照.json"
func _initialize() -> void:
	call_deferred("collect")
func clean(value: Variant) -> Variant:
	if value is Vector2: return [value.x,value.y]
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Dictionary:
		var out: Dictionary={}
		for key in value: out[key]=clean(value[key])
		return out
	if value is Array:
		var out: Array=[]
		for item in value: out.append(clean(item))
		return out
	return value
func position_in_map(node: Node,scene: Node) -> Vector3:
	var transform_=Transform3D.IDENTITY
	var current=node
	while current!=null:
		if current is Node3D: transform_=current.transform*transform_
		if current==scene: break
		current=current.get_parent()
	return transform_.origin
func collect() -> void:
	var data: Dictionary={"date":"2026-11-01","catalog":DB.catalog(),"plots":DB.plots(),"resources":DB.all_resources(),"facilities":DB.facilities(),"shops":DB.shops(),"starter_clothes":DB.starter_clothes(),"attributes":Stats.ROWS,"skills":Stats.SKILLS,"patterns":Fabric.PATTERNS,"initial_state":Authority.new().state,"people":People.PEOPLE,"cat":People.CAT_TEACHER,"youmu":People.PANDA_YOUMU,"panda":People.PANDA_VALLEY,"visitors":People.VALLEY_VISITORS,"levels":[],"scene_anchors":[]}
	for level in range(1,51): data.levels.append({"level":level,"required":Stats.skill_required(level),"total":Stats.skill_start(level)})
	for map_id in ["city","valley"]:
		var packed=load("res://scenes/city_map.tscn" if map_id=="city" else "res://scenes/valley_map.scn")
		var scene=packed.instantiate()
		var nodes: Array=scene.find_children("*","Node3D",true,false)
		for node in nodes:
			if str(node.name) in ["ActionAnchor","SeatAnchor","ExitAnchor","MerchantAnchor","MealAnchor","PotSteam","SleepExit"] or str(node.name).begins_with("Bench"):
				data.scene_anchors.append({"map":map_id,"path":str(scene.get_path_to(node)),"position":position_in_map(node,scene)})
		scene.free()
	var handle=FileAccess.open(OUT,FileAccess.WRITE)
	handle.store_string(JSON.stringify(clean(data),"\t",false))
	handle.close()
	print("BASELINE_COLLECTED items=",data.catalog.items.size()," resources=",data.resources.size()," anchors=",data.scene_anchors.size())
	quit()
