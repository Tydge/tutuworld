extends RefCounted
const J=preload("res://scripts/jade/layout.gd")
const KINDS=["jade_hall","jade_loft","jade_store","jade_court","jade_palace","jade_forge","jade_cloister","jade_pavilion","jade_theatre","jade_inn","jade_clocktower","jade_cottage"]
static func contains_piece(shell: Dictionary,item: Dictionary,footprint: Rect2) -> bool:
	if shell.kind not in KINDS or item.kind in KINDS or shell.get("storey",0)!=item.get("storey",0):return false
	var kind:=str(shell.kind).trim_prefix("jade_");var d:=J.dims(kind)
	var half:=Vector2(d.x,d.z)*(.77 if kind=="palace" else 1.)-Vector2(.43,.43)
	var center:=Vector2(shell.position[0],shell.position[1]);var angle:=deg_to_rad(float(shell.get("yaw",0)))
	for corner in [footprint.position,footprint.end,Vector2(footprint.position.x,footprint.end.y),Vector2(footprint.end.x,footprint.position.y)]:
		var local_: Vector2=(corner-center).rotated(angle).abs()
		if local_.x>half.x or local_.y>half.y:return false
		if kind=="pavilion" and local_.x/half.x+local_.y/half.y>1.58:return false
	return true
static func prepare(n: Node3D,kind: String) -> void:
	var shape:=kind.trim_prefix("jade_");var d:=J.dims(shape)
	n.set_script(preload("res://scripts/jade/room.gd"));n.set("shell_kind",shape);n.set("floor_size",Vector2(d.x,d.z)*2.);n.set("wall_height",d.y);n.set_process(false)
	var contents:=Node3D.new();contents.name="Furnishing";n.add_child(contents)
	var plaque:=Node3D.new();plaque.name="HouseName";n.add_child(plaque)
	var art=load("res://scripts/jade/architecture.gd")
	art.mesh_part(n,"kit_floor"+shape,func(m):
		for j in range(6):
			for k in range(6):
				art.paint(m,Vector3((k-2.5)*d.x/3.,-.087,(j-2.5)*d.z/3.),Vector3(d.x/3.-.003,.17,d.z/3.-.003),"masonry"))
	var ground:=preload("res://scripts/geometry.gd").solid_box(n,Vector3.DOWN*.09,Vector3(d.x*2.,.18,d.z*2.));ground.collision_layer=8
