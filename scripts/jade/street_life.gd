extends Node
## Shared by solo play and the authoritative town. Online visitors see the resulting actor poses.
const J=preload("res://scripts/jade/layout.gd")
const TRADES={"spice":"cook","almond":"cook","tools":"forge_strike","farm":"sort_seed","furniture":"plane_wood","clothes":"draw_thread"}
const REST=["refill","tea","draw_thread","plane_wood","sort_seed","tea","forge_strike","bell","tea","read_scroll","bell","warm","read_scroll","draw_thread","bow","read_scroll","bell","draw_thread","tea","bow"]
const STOPS={
	1:[Vector2(-6,146),Vector2(-7,130),Vector2(2,139),Vector2(2,154),Vector2(-6,165)],
	2:[Vector2(-5,128),Vector2(2,124),Vector2(5,111),Vector2(-2,116),Vector2(4,134)],
	3:[Vector2(5,91),Vector2(-2,95),Vector2(-7,106),Vector2(2,103),Vector2(2,114)],
	7:[Vector2(-2,47),Vector2(3,38),Vector2(8,31),Vector2(8,47),Vector2(3,54)],
	8:[Vector2(-2,166),Vector2(-7,156),Vector2(3,148),Vector2(4,156),Vector2(3,173)]
}
var city: Node3D
var next_turn: Dictionary={}
var elapsed:=0.
var tick:=0.
static func walk_stops(index: int,origin: Vector3) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	if STOPS.has(index):
		for p: Vector2 in STOPS[index]:result.append(J.point(p.x+J.lane(p.y),p.y))
	else:
		for offset in [Vector2.ZERO,Vector2(-3,4),Vector2(2,8),Vector2(5,6),Vector2(4,-3)]:
			result.append(J.point(origin.x+offset.x,origin.z+offset.y))
	return result
func _ready() -> void:
	for actor in city.npcs:next_turn[actor.name]=1.+posmod(str(actor.name).hash(),97)*.105
func _physics_process(delta: float) -> void:
	elapsed+=delta
	tick+=delta
	if tick<.40:return
	tick=0.
	for actor in city.npcs:
		var id:=str(actor.name)
		if elapsed<next_turn.get(id,INF) or actor.walking or not actor.action.is_empty():continue
		if city.talking_npc==id or (city.has_method("chatting_with") and is_instance_valid(city.chatting_with(id))):continue
		var driver: Node=actor.get_node_or_null("NeighbourWalk")
		var pose: String
		var duration:=2.6
		if driver:
			if not driver.path.is_empty():continue
			var index:=int(id.trim_prefix("JadeCitizen_"))
			pose=REST[index]
			duration=3.6 if pose=="tea" or pose=="read_scroll" else 2.4
			driver.wait=maxf(driver.wait,duration+.3)
		else:
			pose=TRADES.get(id.trim_prefix("JadeVendor_"),"")
		if pose.is_empty():continue
		actor.play_action(pose,duration)
		next_turn[id]=elapsed+duration+3.75+float(posmod(id.hash()+int(elapsed),7))*.52
