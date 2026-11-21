extends RefCounted
## Marks are per traveler, and the cartographer pays for the first full rubbing.
const STAMPS:={
	"harbor":{"name":"小船","place":Vector2(-100,113),"clue":"回城的小船还没靠岸，第一枚印章在码头北边，能听见浪拍木梁的地方。","color":"548c99"},
	"bell":{"name":"铃铛","place":Vector2(-101,-94),"clue":"沿雪镇的路一直往北。钟楼前那枚印章，刻的是替整座岛报时的铃铛。","color":"b88350"},
	"ice":{"name":"冰花","place":Vector2(48,65),"clue":"从雪镇滑到东边，在蓝冰原南边找一堆篝火。火星旁能拓到一朵冰花。","color":"756fa3"}
}
const REWARD_COINS:=36
const LOAF:="food_snow_loaf"
const TEA:="food_pine_tea"
const LODGE_BEDS:=["winter_bed:lodge:bed_0","winter_bed:lodge:bed_1","winter_bed:home_i:bed_0","winter_bed:home_i:bed_1"]
static func normalize(raw: Variant) -> Dictionary:
	if not raw is Dictionary:return {"stamps":[],"claimed":false}
	var marks: Array=[]
	if raw.get("stamps") is Array:
		for id in STAMPS:
			if id in raw.stamps:marks.append(id)
	return {"stamps":marks,"claimed":marks.size()==STAMPS.size() and raw.get("claimed",false)==true}
static func place(host: Node3D) -> void:
	var layout=preload("res://scripts/icefield/icefield_layout.gd")
	var builder=preload("res://scripts/building/furniture_builder.gd").new()
	var root:=Node3D.new();root.name="SnowTrail";host.scenery.add_child(root)
	for id in STAMPS:
		var stamp: Dictionary=STAMPS[id]
		var p: Vector2=stamp.place
		var post:=Node3D.new();post.name=id;post.position=Vector3(p.x,layout.height_at(p.x,p.y),p.y);root.add_child(post)
		builder.build_item(post,"post_stamp")
		var label:=preload("res://scripts/geometry.gd").text3d(post,stamp.name+"印章",Vector3(0,1.29,.22),25,Color("734c47"))
		label.visibility_range_end=20.
		preload("res://scripts/city/room_activities.gd").register(host,"snow_stamp:"+id,post)
