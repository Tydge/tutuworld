extends Node
## Conservative boxes inside actual opaque wall/slab solids, shared by reflection
## views. Windows, stair holes, cutaway/faded walls and shadow-only shells stay open.
const View=preload("res://scripts/city/interior_view.gd")
var city: Node3D
var signature:=""
var boxes: Array=[]
func sync() -> bool:
	var editor: Node=city.build_mode;var room: Node3D=editor.room
	if not is_instance_valid(room):return false
	var key:=str(room.get_instance_id())+str(room.get_meta("structure_key",""))
	if signature!=key:
		for entry in boxes:entry.occluder.hide();entry.occluder.queue_free()
		boxes.clear();signature=key
		for entry in room.render_cache.values():
			if entry.row.type not in ["wall","floor_chunk"]:continue
			for shape in entry.node.find_children("*","CollisionShape3D",true,false):
				if not shape.shape is BoxShape3D or shape.disabled:continue
				var extent: Vector3=shape.shape.size-Vector3.ONE*.02
				if minf(extent.x,minf(extent.y,extent.z))<.01:continue
				var occluder:=OccluderInstance3D.new();var box:=BoxOccluder3D.new();box.size=extent;occluder.occluder=box;add_child(occluder);occluder.global_transform=shape.global_transform
				boxes.append({"occluder":occluder,"node":entry.node,"visuals":entry.get("visuals",[]),"wall":entry.row.type=="wall"})
	var full: bool=room.editor_roof if room.editor_active else View.mode(city)==View.FULL
	var auto_cut: bool=(room.editor_active and not room.editor_roof) or (not room.editor_active and View.mode(city)==View.AUTO)
	var enabled:=false
	for entry in boxes:
		var visible_: bool=is_instance_valid(entry.node) and entry.node.is_visible_in_tree() and not entry.node.get_meta("storey_cut",false)
		visible_=visible_ and entry.visuals.any(func(mesh):return is_instance_valid(mesh) and mesh.is_visible_in_tree() and mesh.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
		if entry.wall:
			if auto_cut:visible_=false
			elif not full:
				for section in room.sections:
					if section.node==entry.node and section.get("alpha",1.)<.99999:visible_=false;break
		entry.occluder.visible=visible_;enabled=enabled or visible_
	return enabled
