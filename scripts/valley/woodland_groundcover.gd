extends RefCounted
const L=preload("res://scripts/valley/valley_layout.gd")
static func blade_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(5):
		var angle: float=blade*2.399;var side:=Vector3(cos(angle),0,sin(angle));var bend:=Vector3(-side.z,0,side.x)
		var length_: float=.17+blade*.027;var origin:=side*.10
		for segment in range(2):
			var points: Array=[]
			for row in [segment,segment+1]:
				var u: float=row/2.;var center:=origin+Vector3.UP*u*length_+bend*u*u*.14
				var width: float=.015*(1.-u*.94)
				points.append([center-side*width,center+side*width,u])
			for pair in [[0,0],[0,1],[1,0],[0,1],[1,1],[1,0]]:
				st.set_color(Color.WHITE);st.set_uv(Vector2(pair[1],points[pair[0]][2]));st.add_vertex(points[pair[0]][pair[1]])
	st.generate_normals();st.index();return st.commit()
static func build(builder) -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=127517
	var root:=Node3D.new();root.name="LivingGroundcover";root.set_meta("buildable_reference",true);builder.world.add_child(root)
	var mesh:=blade_mesh();var material:=ShaderMaterial.new();material.shader=preload("res://assets/shaders/woodland_grass.gdshader")
	var count:=0
	for cz in range(-8,9):
		for cx in range(-9,9):
			var origin:=Vector3(cx*12,0,cz*12);var rows: Array=[]
			for k in range(340):
				var p:=origin+Vector3(rng.randf_range(0,12),0,rng.randf_range(0,12));p.y=L.height_at(p.x,p.z)+.012
				if not builder.nature_clear(p) or L.normal_at(p.x,p.z).y<.76:continue
				if sin(p.x*.19+sin(p.z*.11)*2.)+cos(p.z*.16)< -1.1:continue
				rows.append({"p":p-origin,"yaw":rng.randf()*TAU,"size":rng.randf_range(.65,1.35),"color":Color("819551").lerp(Color("a1ae67"),rng.randf()*.65)})
			if rows.is_empty():continue
			var center_y:=0.
			for row in rows:center_y+=row.p.y
			origin.y=center_y/rows.size()
			for row in rows:row.p.y-=origin.y
			var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=mesh;mm.instance_count=rows.size()
			for i in range(rows.size()):mm.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rows[i].yaw).scaled(Vector3.ONE*rows[i].size),rows[i].p));mm.set_instance_color(i,rows[i].color)
			var n:=MultiMeshInstance3D.new();n.name="GrassPatch";n.multimesh=mm;n.position=origin;n.material_override=material;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Cull only after even the closest blade has finished its vertex fade.
			var bounds:=mm.get_aabb();n.visibility_range_end=54.+bounds.size.length()*.5;n.visibility_range_end_margin=0.;root.add_child(n);count+=rows.size()
	builder.world.set_meta("grass_clump_count",count);builder.world.set_meta("grass_draw_distance",54.)
	print("WOODLAND_GRASS clumps=",count)
