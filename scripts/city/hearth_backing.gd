extends RefCounted
## Repair the prepacked hearth too, without regenerating a town/map resource.
static func repair_legacy(model: Node3D) -> void:
	if model.get_meta("backing_version",0)>=1:return
	var black:=Color("4d5148").srgb_to_linear()
	for visual in model.find_children("*","MeshInstance3D",true,false):
		var original: Mesh=visual.mesh;var surfaces: Array=[];var changed:=false
		var local: Transform3D=model.global_transform.affine_inverse()*visual.global_transform;var inverse:=local.affine_inverse()
		for surface in range(original.get_surface_count()):
			var arrays: Array=original.surface_get_arrays(surface).duplicate(true);var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray();var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			for i in range(points.size()):
				if colors.size()!=points.size():continue
				# Packed mesh vertex colors are quantized; compare in linear space.
				if Vector3(colors[i].r-black.r,colors[i].g-black.g,colors[i].b-black.b).length()>.01:continue
				var p: Vector3=local*points[i]
				if absf(p.x)>.801 or p.y<.249 or p.y>1.411:continue
				if is_equal_approx(p.z,-.31):p.z=-.27
				elif is_equal_approx(p.z,-.21):p.z=-.19
				else:continue
				points[i]=inverse*p;changed=true
			arrays[Mesh.ARRAY_VERTEX]=points;surfaces.append(arrays)
		if changed:
			var mesh:=ArrayMesh.new()
			for arrays in surfaces:mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			visual.mesh=mesh
	model.set_meta("backing_version",1)
