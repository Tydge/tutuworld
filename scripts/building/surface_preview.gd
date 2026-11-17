extends RefCounted
## Local visual preview only: no layout writes, physics changes or undo entries.
const L=preload("res://scripts/building/layout.gd")
const G=preload("res://scripts/building/grid_layout.gd")
const C=preload("res://scripts/building/structure_catalog.gd")
const F=preload("res://scripts/building/module_factory.gd")
var holder: Node3D
var hidden: Array=[]
var key:=""
var materials: Array=[]
func clear() -> void:
	for entry in hidden:
		if is_instance_valid(entry[0]):entry[0].visible=entry[1]
	hidden.clear();materials.clear();key=""
	if is_instance_valid(holder):holder.free()
	holder=null
func show_layout(editor: Node,candidate: Dictionary,signature: String) -> void:
	clear();key=signature
	if not is_instance_valid(editor.room):return
	holder=Node3D.new();holder.name="WallFinishPreview";editor.city.add_child(holder)
	for level in range(4):
		if not editor.roof_view and level!=editor.editing_storey and not (editor.show_roof and level<editor.editing_storey):continue
		var before:=L.compiled(editor.layout,level);var after:=L.compiled(candidate,level);var changed: Dictionary={}
		for edge in before.walls:
			var old: Dictionary=before.walls[edge];var next: Dictionary=after.walls[edge]
			if C.surface_key(old,"positive")!=C.surface_key(next,"positive") or C.surface_key(old,"negative")!=C.surface_key(next,"negative"):changed[old.id]=true
		var walls: Dictionary={}
		for edge in before.walls:
			if changed.has(before.walls[edge].id):walls[edge]=after.walls[edge]
		var story:=Node3D.new();holder.add_child(story);story.position.y=level*4.7
		var builder:=F.builder(story)
		for row in G.runs(walls):
			builder.build_wall(story,F.wall_data(candidate,row,Vector2.ZERO))
			var node: Node3D=story.get_child(story.get_child_count()-1)
			node.visible=level<=editor.editing_storey or editor.roof_view
		for id in changed:
			if editor.room.render_cache.has(id):
				var node: Node3D=editor.room.render_cache[id].node;hidden.append([node,node.visible]);node.hide()
	for body in holder.find_children("*","CollisionObject3D",true,false):body.collision_layer=0;body.collision_mask=0

func bind_marker(marker: Color) -> void:
	if not is_instance_valid(holder):return
	for mesh in holder.find_children("*","MeshInstance3D",true,false):
		var material: Material=mesh.material_override
		if material is ShaderMaterial and material.get_shader_parameter("tint")==marker and material not in materials:materials.append(material)
func paint(color: Color,style: String) -> void:
	for material in materials:
		material.set_shader_parameter("tint",color);material.set_shader_parameter("pattern",C.pattern(style))
