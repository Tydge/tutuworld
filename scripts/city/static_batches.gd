extends RefCounted
const G=preload("res://scripts/geometry.gd")
static func bake(world: Node3D) -> void:
	var groups: Dictionary={}
	var detail_groups: Dictionary={}
	var nodes:=world.find_children("*","MeshInstance3D",true,false)
	for n in nodes:
		if n.get_child_count()>0: continue
		var parent: Node=world
		var ancestor: Node=n.get_parent()
		var skip:=false
		while ancestor!=world:
			if ancestor.has_meta("buildable_reference"): skip=true
			if str(ancestor.name)=="Streetlights": skip=true
			if str(ancestor.name).begins_with("Tree") or str(ancestor.name).begins_with("Cloud"): parent=ancestor
			ancestor=ancestor.get_parent()
		if skip: continue
		var shape: Mesh=n.mesh
		var kind: String=""
		var canonical: Mesh
		var transform_: Transform3D=parent.global_transform.affine_inverse()*n.global_transform
		if shape is BoxMesh:
			kind="box"
			canonical=BoxMesh.new()
			canonical.size=Vector3.ONE
			transform_.basis=transform_.basis.scaled_local(shape.size)
		elif shape is SphereMesh:
			kind="sphere"
			canonical=SphereMesh.new()
			canonical.radius=1
			canonical.height=2
			canonical.radial_segments=20
			canonical.rings=10
		elif shape is CylinderMesh:
			var ratio: float=shape.top_radius/maxf(.001,shape.bottom_radius)
			kind="cylinder%.3f"%ratio
			canonical=CylinderMesh.new()
			canonical.bottom_radius=1
			canonical.top_radius=ratio
			canonical.height=1
			canonical.radial_segments=16
			transform_.basis=transform_.basis.scaled_local(Vector3(shape.bottom_radius,shape.height,shape.bottom_radius))
		else:
			var detail_key: String=str(parent.get_instance_id())+":"+str(n.material_override.get_instance_id())+":%d:%d:%d"%[int(floor(n.global_position.x/12)),int(floor(n.global_position.z/12)),n.cast_shadow]
			if not detail_groups.has(detail_key): detail_groups[detail_key]={"parent":parent,"material":n.material_override,"surfaces":[],"shadow":n.cast_shadow}
			detail_groups[detail_key].surfaces.append({"mesh":shape,"transform":transform_})
			n.get_parent().remove_child(n)
			n.free()
			continue
		var key: String=str(parent.get_instance_id())+":"+kind+":"+str(n.material_override.get_instance_id())+":%d:%d:%d"%[int(floor(n.global_position.x/12)),int(floor(n.global_position.z/12)),n.cast_shadow]
		if not groups.has(key): groups[key]={"parent":parent,"shape":canonical,"material":n.material_override,"transforms":[],"shadow":n.cast_shadow}
		groups[key].transforms.append(transform_)
		n.get_parent().remove_child(n)
		n.free()
	for entry in groups.values():
		var mm:=MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=entry.shape
		mm.instance_count=entry.transforms.size()
		for i in range(mm.instance_count): mm.set_instance_transform(i,entry.transforms[i])
		var instance:=MultiMeshInstance3D.new()
		instance.name="CityBatch"
		instance.multimesh=mm
		instance.material_override=entry.material
		instance.cast_shadow=entry.shadow
		instance.visibility_range_end=145
		instance.visibility_range_end_margin=12
		entry.parent.add_child(instance)
	for entry in detail_groups.values():
		var surfaces:=SurfaceTool.new()
		surfaces.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in entry.surfaces:
			for surface in range(part.mesh.get_surface_count()): surfaces.append_from(part.mesh,surface,part.transform)
		var instance:=G.mesh(entry.parent,surfaces.commit(),Vector3.ZERO,entry.material,"SceneryDetailBatch")
		instance.cast_shadow=entry.shadow
		instance.visibility_range_end=145
		instance.visibility_range_end_margin=12
	print("CITY_BATCHES ",groups.size()," DETAILS ",detail_groups.size())
