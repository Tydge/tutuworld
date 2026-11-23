extends RefCounted
## An activity belongs to its physical model and uses the same access check in both worlds.
const Access=preload("res://scripts/city/furniture_access.gd")
const KINDS:={
	"jade_practice":["footwork","踏梅花步 · 合着鼓声按 E"],
	"jade_chime":["chime","依次轻叩五音编磬"],
	"field_journal":["read","翻开手记，读一段见闻"],
	"clothing_rack":["tailor","在衣架前试染衣服"],
	"atlas_stand":["atlas","翻开踏雪图册"],
	"tile_stove":["hearth","伸爪烤火 · 恢复耐力"],
	"bread_oven":["bakery","烤雪绒路粮 · 1 小麦 + 1 树枝"],
	"tea_service":["tea","煮松针茶 · 1 树枝 · 耐力恢复加快"],
	"post_stamp":["stamp","在图册上盖印"]
}
static func register(host: Node3D,id: String,node: Node3D) -> void:
	var kind: String=str(node.get_meta("furniture_kind",""))
	var row: Array=KINDS.get(kind,[])
	if node.has_meta("jade_house"):
		var house: String=node.get_meta("jade_house")
		row=["jade_game",preload("res://scripts/jade/house_games.gd").STATIONS[house].action]
	elif node.has_meta("dye_station"):row=KINDS.clothing_rack
	if row.is_empty():return
	var anchor:=node.get_node_or_null("ActivityAnchor") as Node3D if kind!="tea_service" else null
	host.targets[id]={"kind":row[0],"label":row[1],"node":node,"position":anchor.global_position if anchor else node.global_position,"radius":2.35}
	if anchor:host.targets[id].anchor=anchor
static func reachable(host: Node3D,pawn: CharacterBody3D,id: String,kind: String) -> bool:
	var row: Dictionary=host.targets.get(id,{})
	if row.get("kind","")!=kind or not is_instance_valid(row.get("node")):return false
	var prop: Node3D=row.node
	var p:=pawn.global_position
	var anchor: Vector3=row.position
	if absf(p.y-anchor.y)>1.35 or p.distance_to(anchor)>2.45:return false
	if not Access.same_room(host,prop,p):return false
	return Access.clear_segment(host,prop,pawn,p+Vector3.UP*.95,anchor+Vector3.UP*.65)
static func outfit_shop(host: Node3D) -> void:
	var furnishing: Node3D=host.scenery.get_node_or_null("Shop_clothes/Furnishing")
	if furnishing==null:return
	var forms: Array[Node]=furnishing.find_children("DressForm*","Node3D",false,false)
	if forms.is_empty():return
	var original:=forms[0] as Node3D
	var rack:=Node3D.new();rack.name="TailoringForm";rack.position=original.position;rack.rotation.y=PI*.5
	original.free();furnishing.add_child(rack)
	preload("res://scripts/building/furniture_builder.gd").new().build_item(rack,"clothing_rack")
	register(host,"shop_clothing_rack",rack)
