extends RefCounted
const G=preload("res://scripts/geometry.gd")
const Layout=preload("res://scripts/building/layout.gd")
const Catalog=preload("res://scripts/building/catalog.gd")
static func group(parent: Node3D,id: String) -> Node3D:
	var n:=Node3D.new();n.name=id;parent.add_child(n);return n
static func blueprint() -> Dictionary:
	return {"id":"player_built_home","name":"我的小屋","origin":[0,0,0],"size":[12,10],"floor_height":.18,"wall_height":4.4,"wall_thickness":.24,"roof_rise":1.8,"theme":"forest","chimney":false,"walls":[],"materials":{"plaster":"eadcc5","trim":"eee2c6","panel":"a1b2a0","roof":"688d81","oak":"b18b61"}}
static func builder(root: Node3D) -> RefCounted:
	var b:=preload("res://scripts/building/editable_builder.gd").new();b.blueprint=blueprint();b.floor_y=.18;b.height=4.4;b.thickness=.24;b.root=root
	if not root.has_meta("build_mesh_cache"):root.set_meta("build_mesh_cache",{});root.set_meta("build_material_cache",{})
	b.rounded_cache=root.get_meta("build_mesh_cache");return b
static func paint(module: Node3D,row: Dictionary,force: bool=false) -> void:
	legacy_paint(module,row,force)
	if row.has("kind"):preload("res://scripts/building/appearance.gd").apply(module,row)
static func legacy_paint(module: Node3D,row: Dictionary,force: bool=false) -> void:
	if not force and not row.get("painted",false):return
	for part in module.find_children("*","GeometryInstance3D",true,false):
		var original: Material=part.material_override
		if original is ShaderMaterial:
			var m: ShaderMaterial=original.duplicate()
			if m.shader==preload("res://assets/shaders/home_surface.gdshader"):
				m.set_shader_parameter("tint",Color(row.color));m.set_shader_parameter("vertex_tint",false)
				if row.style!="original":m.set_shader_parameter("pattern",{"plaster":0,"wood":1,"brick":3,"stone":3}.get(row.style,0))
			elif "uniform vec4 dye" in m.shader.code:m.set_shader_parameter("dye",Color(row.color))
			else:continue
			part.material_override=m
		elif original is StandardMaterial3D and original.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and not original.emission_enabled:
			var m: StandardMaterial3D=original.duplicate();m.albedo_color=Color(row.color);part.material_override=m
const Grid=preload("res://scripts/building/grid_layout.gd")
const Site=preload("res://scripts/building/site.gd")
static func make(layout: Dictionary,city: Node3D) -> Node3D:
	if layout.elements.is_empty():return null
	var root:=preload("res://scripts/building/building_world.gd").new();root.name="PlayerBuiltHome";root.city=city;root.assembling=true;root.position=Site.CENTER
	root.set_meta("buildable_reference",true);root.set_meta("module_type","player_building")
	city.scenery.add_child(root)
	var structure:=group(root,"Structure")
	for id in ["Floor","Walls","Roof"]:group(structure,id)
	for id in ["Furnishing","Doors","Lighting","Joints"]:group(root,id)
	sync(root,layout,city);root.assembling=false;return root
static func descriptor(path: String,row: Dictionary,geometry: Variant) -> Dictionary:
	return {"path":path,"row":row,"signature":JSON.stringify(geometry).sha256_text()}
static func structure_descriptors(layout: Dictionary,grid: Dictionary,previous: Dictionary={}) -> Dictionary:
	var result: Dictionary={};var chunks: Dictionary={}
	for c in grid.floors:
		var key:=Vector2i(floori(float(c.x)/Grid.CHUNK),floori(float(c.y)/Grid.CHUNK))
		if not chunks.has(key):chunks[key]={}
		chunks[key][c]=grid.floors[c]
	for key in chunks:
		var id:="floor_%d_%d"%[key.x,key.y];var ordered: Array=chunks[key].keys();ordered.sort();var fingerprint: Array=[]
		for c in ordered:fingerprint.append([c,Grid.style_key(chunks[key][c])])
		var signature:=JSON.stringify(fingerprint).sha256_text()
		if previous.has(id) and previous[id].signature==signature:result[id]=previous[id];continue
		var rows:=Grid.rectangles(chunks[key])
		result[id]={"path":"Structure/Floor","row":{"id":id,"type":"floor_chunk","rects":rows,"cells":chunks[key],"origin":Vector2(key)*Grid.CHUNK*.5},"signature":signature}
	for row in layout.elements:
		if row.type=="floor":continue
		if row.type=="object":continue
		elif row.type=="wall":result[row.id]=descriptor("Structure/Walls",row,[row,wall_data(layout,row,Vector2.ZERO)])
		elif row.type=="roof":result[row.id]=descriptor("Structure/Roof",row,row)
		elif row.type in ["door","window"]:result[row.id]=descriptor("Doors",row,[row.type,row.color,row.style,row.painted])
	var vertices:=Grid.vertex_degrees(grid.walls)
	for p in vertices:
		var connected: Array=vertices[p]
		if connected.size()!=1 and connected.size()!=2:continue
		if connected.size()==2 and connected[0].z==connected[1].z:continue
		var row: Dictionary=grid.walls[connected[0]];var id:="joint_%d_%d"%[p.x,p.y]
		result[id]=descriptor("Joints",{"id":id,"type":"joint","point":Grid.point(p),"corner":connected.size()==2,"wall":row.id,"color":row.color,"axis":connected[0].z},[p,connected.size(),row.color])
	return result
static func sync(root: Node3D,layout: Dictionary,city: Node3D) -> Dictionary:
	var started:=Time.get_ticks_usec();var grid:=Layout.compiled(layout);var structure_key: String=grid.signature+JSON.stringify(layout.elements.filter(func(row):return row.type in ["roof","door","window"]))
	if root.get_meta("structure_key","")!=structure_key:root.set_meta("structure_descriptors",structure_descriptors(layout,grid,root.get_meta("structure_descriptors",{})));root.set_meta("structure_key",structure_key)
	var desired: Dictionary=root.get_meta("structure_descriptors").duplicate()
	for row in layout.elements:
		if row.type=="object":desired[row.id]=descriptor("Furnishing",row,[row.kind,row.color,row.style,row.painted,row.get("appearance",{})])
	var created:=0;var removed:=0;var reused:=0;var moved:=0
	for id in root.render_cache.keys():
		if desired.has(id) and desired[id].signature==root.render_cache[id].signature:continue
		var module: Node3D=root.render_cache[id].node
		root.sections=root.sections.filter(func(section):return section.node!=module and section.get("parent_wall")!=module)
		mark_navigation(root,root.render_cache[id].get("row",{}))
		module.get_parent().remove_child(module);module.free();root.render_cache.erase(id);removed+=1
	for id in desired:
		var entry: Dictionary=desired[id];var row: Dictionary=entry.row;var module: Node3D
		if root.render_cache.has(id):module=root.render_cache[id].node;reused+=1
		else:
			module=build_module(root,layout,row,root.get_node(entry.path),city);root.render_cache[id]={"signature":entry.signature,"node":module};created+=1;mark_navigation(root,row)
		if row.type in ["door","window"]:
			module.position=Vector3(row.anchor[0]-Site.CENTER.x,.18 if row.type=="door" else 0.,row.anchor[1]-Site.CENTER.z);module.rotation.y=-(PI*.5 if row.axis==1 else 0.)+(PI if row.reverse else 0.);module.set_meta("outward",Vector3.BACK.rotated(Vector3.UP,module.rotation.y))
		if row.type=="object":
			var target:=Vector3(row.position[0]-Site.CENTER.x,.18+Layout.base_height(layout,row),row.position[1]-Site.CENTER.z)
			if module.position.distance_to(target)>.0001 or absf(module.rotation.y-deg_to_rad(row.yaw))>.0001:moved+=1;mark_navigation(root,root.render_cache[id].get("row",{}));mark_navigation(root,row)
			module.position=target;module.rotation.y=deg_to_rad(row.yaw)
		root.render_cache[id]["row"]=row.duplicate(true)
	root.configure(grid);root.blueprint=blueprint()
	for entry in root.render_cache.values():
		var row: Dictionary=entry.row
		if row.type in ["wall","door","window"]:entry.node.set_meta("view_face",root.wall_faces.get(row.id if row.type=="wall" else row.wall,row.id))
		elif row.type=="joint" and not row.corner:entry.node.set_meta("view_face",root.wall_faces.get(row.wall,row.id))
	root.set_meta("building_definition",root.blueprint);root.floor_size=Site.PLOT.size
	# Only new surfaces pass through the environment material binder.
	if created>0 or removed>0:root.view_dirty=true
	root.last_sync={"created":created,"removed":removed,"reused":reused,"moved":moved,"usec":Time.get_ticks_usec()-started,"modules":desired.size()}
	return root.last_sync
static func floor_material(row: Dictionary) -> Material:
	var material:=ShaderMaterial.new()
	if row.style=="stone":material.shader=preload("res://assets/shaders/paving.gdshader");material.set_shader_parameter("paving_texture",preload("res://assets/terrain/village_stone_paving_v1.png"));material.set_shader_parameter("stone_color",Color(row.color))
	elif row.style in ["brick","plaster"]:material.shader=preload("res://assets/shaders/home_surface.gdshader");material.set_shader_parameter("tint",Color(row.color));material.set_shader_parameter("pattern",2 if row.style=="brick" else 0);material.set_shader_parameter("building_world_pattern",true)
	else:material.shader=preload("res://assets/shaders/home_floor.gdshader");material.set_shader_parameter("wood_color",Color(row.color));material.set_shader_parameter("world_aligned",true)
	return material
static func build_module(root: Node3D,layout: Dictionary,row: Dictionary,parent: Node3D,city: Node3D) -> Node3D:
	var b:=builder(root);var module: Node3D
	var prototype_key:=geometry_key(layout,row)
	if prototype_key!="" and root.module_prototypes.has(prototype_key):
		module=root.module_prototypes[prototype_key].duplicate();module.name=row.id;parent.add_child(module)
		if row.type=="wall":pose_wall(module,row)
		if row.type=="joint":module.position=Vector3(row.point.x-Site.CENTER.x,0,row.point.y-Site.CENTER.z)
		finish_module(root,module,row);return module
	match row.type:
		"floor_chunk":
			module=group(parent,row.id);module.position=Vector3(row.origin.x-Site.CENTER.x,0,row.origin.y-Site.CENTER.z);module.set_meta("build_grid_type","floor")
			build_floor_mesh(module,row)
			var solid: Dictionary={}
			for c in row.cells:solid[c]={"id":"floor","type":"floor","color":"ffffff","style":"original"}
			for part in Grid.rectangles(solid):
				var r:=Layout.rect(part);var mid: Vector2=r.get_center()-row.origin;b.floor_collision(module,Vector3(mid.x,.03,mid.y),Vector3(r.size.x,.30,r.size.y))
		"wall":
			b.blueprint.materials.plaster=row.color;b.build_wall(parent,wall_data(layout,row,Vector2(Site.CENTER.x,Site.CENTER.z)));module=parent.get_node(NodePath(row.id))
			if row.style in ["wood","brick","stone"]:
				for part in module.find_children("*","MeshInstance3D",true,false):
					if part.material_override is ShaderMaterial and part.material_override.get_shader_parameter("tint")==Color(row.color):part.material_override.set_shader_parameter("pattern",1 if row.style=="wood" else 3)
			b.bake_section(module)
		"roof":
			module=group(parent,row.id);var r:=Layout.rect(row);var mid:=r.get_center()-Vector2(Site.CENTER.x,Site.CENTER.z);module.position=Vector3(mid.x,0,mid.y)
			b.blueprint.size=[r.size.x,r.size.y];b.blueprint.materials.roof=row.color;b.build_roof(module);b.bake_section(module)
		"object":
			module=group(parent,row.id)
			b.build_item(module,row.kind)
			paint(module,row)
			var picker:=StaticBody3D.new();picker.name="BuildPicker";picker.collision_layer=16;picker.collision_mask=0
			var definition_: Dictionary=Catalog.OBJECTS[row.kind];var offset: Vector2=definition_.get("offset",Vector2.ZERO)
			var shape:=BoxShape3D.new();shape.size=Vector3(definition_.size.x,maxf(.05,definition_.height),definition_.size.y)
			var collision:=CollisionShape3D.new();collision.shape=shape;collision.position=Vector3(offset.x,shape.size.y*.5,offset.y);picker.add_child(collision)
			if row.kind=="bookshelf":
				picker.remove_child(collision);collision.free()
				var parts: Array=[]
				for x in [-.7,.7]:parts.append([Vector3(x,1.17,0),Vector3(.13,2.34,.6)])
				for y in [.12,.82,1.52,2.26]:parts.append([Vector3(0,y,0),Vector3(1.5,.12,.65)])
				parts.append([Vector3(0,1.15,-.28),Vector3(1.4,2.3,.07)])
				for part in parts:
					var pick_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=part[1];pick_shape.shape=box;pick_shape.position=part[0];picker.add_child(pick_shape)
			module.add_child(picker)
		"door","window":
			if row.type=="door":
				module=preload("res://scripts/building/room_door.gd").new();module.name=row.id;parent.add_child(module);b.root=module
			else:module=group(parent,row.id)
			var opening:={"id":row.id,"type":row.type,"offset":2.5,"width":2.86 if row.type=="door" else 2.2,"height":3.5 if row.type=="door" else 2.,"bottom":0. if row.type=="door" else 1.1,"color":row.color,"style":row.style}
			if row.type=="door":
				b.blueprint.walls=[{"a":[-2.5,0],"b":[2.5,0],"openings":[opening]}];b.build_door(module);b.bake_section(module.get_node("Hinge"));paint(module,row,true);module.configure(city)
			var frame:=group(module,"Frame");frame.position.y=-.18 if row.type=="door" else 0.;b.build_opening(frame,0,opening);b.bake_section(frame)
			if row.type=="window":
				var picker:=StaticBody3D.new();picker.collision_layer=16;picker.collision_mask=0;var shape:=BoxShape3D.new();shape.size=Vector3(2.2,2.,.10);var collision:=CollisionShape3D.new();collision.shape=shape;collision.position.y=2.28;picker.add_child(collision);module.add_child(picker)
		"joint":
			module=group(parent,row.id);module.position=Vector3(row.point.x-Site.CENTER.x,0,row.point.y-Site.CENTER.z)
			b.rounded(module,Vector3(0,2.38,0),Vector3(.30,4.4,.30) if row.corner else Vector3(.28,4.4,.28),.015,b.material("eee2c6"),"JunctionTrim");b.bake_section(module);module.set_meta("outward",Vector3.BACK if row.axis==0 else Vector3.RIGHT)
	if prototype_key!="" and root.module_prototypes.size()<128:root.module_prototypes[prototype_key]=module.duplicate()
	finish_module(root,module,row);return module
static func finish_module(root: Node3D,module: Node3D,row: Dictionary) -> void:
	module.set_meta("module_type",row.type);module.set_meta("module_id",row.id)
	if row.type not in ["floor_chunk","joint"]:module.set_meta("build_element_id",row.id)
	if row.type in ["wall","roof","joint","door","window"]:root.register_cutaway(module,row.type=="roof")
	preload("res://scripts/city/environment_materials.gd").apply(module)
static func geometry_key(layout: Dictionary,row: Dictionary) -> String:
	match row.type:
		"object":
			if row.kind in ["flowerbed","fountain"]:return ""
			return "object:"+JSON.stringify([row.kind,row.color,row.style,row.painted,row.get("appearance",{})])
		"wall":
			var data:=wall_data(layout,row,Vector2.ZERO)
			for opening in data.openings:opening.erase("id")
			return "wall:"+JSON.stringify([Layout.rect(row).size.length(),row.color,row.style,data.openings])
		"joint":return "joint:"+JSON.stringify([row.corner,row.color,row.axis])
	return ""
static func pose_wall(module: Node3D,row: Dictionary) -> void:
	var a:=Vector2(row.a[0],row.a[1]);var b:=Vector2(row.b[0],row.b[1]);var direction: Vector2=(b-a).normalized()
	module.position=Vector3((a.x+b.x)*.5-Site.CENTER.x,0,(a.y+b.y)*.5-Site.CENTER.z);module.rotation.y=-atan2(direction.y,direction.x);module.set_meta("outward",Vector3(-direction.y,0,direction.x))
static func build_floor_mesh(module: Node3D,row: Dictionary) -> void:
	# Emit boxes directly into one mesh per material, without temporary nodes or surfaces per cell.
	var groups: Dictionary={}
	var unit:=BoxMesh.new();unit.size=Vector3.ONE;var base:=unit.surface_get_arrays(0)
	for part in row.rects:
		var key:=Grid.style_key(part)
		if not groups.has(key):groups[key]={"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"uv":PackedVector2Array(),"indices":PackedInt32Array(),"material":floor_material(part)}
		var entry: Dictionary=groups[key];var r:=Layout.rect(part);var mid: Vector2=r.get_center()-row.origin;var size_:=Vector3(r.size.x,.30,r.size.y);var offset: int=entry.vertices.size()
		for vertex in base[Mesh.ARRAY_VERTEX]:entry.vertices.append(vertex*size_+Vector3(mid.x,.03,mid.y))
		entry.normals.append_array(base[Mesh.ARRAY_NORMAL]);entry.uv.append_array(base[Mesh.ARRAY_TEX_UV])
		for index_ in base[Mesh.ARRAY_INDEX]:entry.indices.append(index_+offset)
	for entry in groups.values():
		var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=entry.vertices;arrays[Mesh.ARRAY_NORMAL]=entry.normals;arrays[Mesh.ARRAY_TEX_UV]=entry.uv;arrays[Mesh.ARRAY_INDEX]=entry.indices
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);G.mesh(module,mesh,Vector3.ZERO,entry.material,"FloorBatch")

static func wall_data(layout: Dictionary,row: Dictionary,center: Vector2) -> Dictionary:
	var openings: Array=[];var axis:=0 if is_equal_approx(row.a[1],row.b[1]) else 1;var first:=minf(row.a[axis],row.b[axis]);var last:=maxf(row.a[axis],row.b[axis]);var plane_: float=row.a[1-axis]
	for item in layout.elements:
		if item.type not in ["door","window"]:continue
		var p: Vector2
		if item.has("anchor"):
			if item.axis!=axis:continue
			p=Vector2(item.anchor[0],item.anchor[1])
		else:
			if item.get("wall","")!=row.id:continue
			p=Vector2(row.a[0],row.a[1])+(Vector2(row.b[0],row.b[1])-Vector2(row.a[0],row.a[1])).normalized()*float(item.offset)
		if absf(p[1-axis]-plane_)>.001:continue
		var width:=2.86 if item.type=="door" else 2.2;var left:=maxf(first,p[axis]-width*.5);var right:=minf(last,p[axis]+width*.5)
		if right-left<.001:continue
		var mid:=(left+right)*.5;var offset:=absf(mid-float(row.a[axis]))
		openings.append({"id":item.id,"type":item.type,"offset":offset,"color":item.color,"style":item.style,"width":right-left,"height":3.5 if item.type=="door" else 2.,"bottom":0. if item.type=="door" else 1.1,"geometry_only":true})
	return {"id":row.id,"a":[row.a[0]-center.x,row.a[1]-center.y],"b":[row.b[0]-center.x,row.b[1]-center.y],"openings":openings}

static func mark_navigation(root: Node3D,row: Dictionary) -> void:
	if row.is_empty():return
	var bounds:=Rect2()
	if row.type=="object":bounds=Catalog.footprint(row)
	elif row.type in ["wall","roof"]:bounds=Layout.rect(row).grow(.4)
	elif row.type=="floor_chunk":bounds=Rect2(row.origin,Vector2.ONE*4.)
	elif row.type in ["door","window"]:bounds=Rect2(Vector2(row.anchor[0],row.anchor[1])-Vector2.ONE*2.,Vector2.ONE*4.)
	if bounds.size==Vector2.ZERO:return
	root.pending_navigation=bounds if root.pending_navigation.size==Vector2.ZERO else root.pending_navigation.merge(bounds)
