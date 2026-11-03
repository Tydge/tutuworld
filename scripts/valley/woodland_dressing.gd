extends RefCounted
## Local-space landscape patches remain independent of houses and travel routes.
const G=preload("res://scripts/geometry.gd")
const Layout=preload("res://scripts/valley/valley_layout.gd")
const Blooms=preload("res://scripts/city/meadow_blossoms.gd")
static func leaf(st: SurfaceTool,p: Vector3,out: Vector3,length_: float,width_: float,color: Color) -> void:
	var side:=Vector3(-out.z,0,out.x).normalized()
	for k in range(5):
		var u: float=k/5.;var v: float=(k+1)/5.
		var a:=p+out*length_*u+Vector3.UP*sin(u*PI)*length_*.35
		var b:=p+out*length_*v+Vector3.UP*sin(v*PI)*length_*.35
		for sign_ in [-1,1]:
			for q in [a,a+side*sign_*sin(u*PI)*width_,b,b,a+side*sign_*sin(u*PI)*width_,b+side*sign_*sin(v*PI)*width_]:
				st.set_color(color.lightened(.045) if sign_>0 else color);st.set_uv(Vector2(0,clampf((q.y-p.y)*1.2,0,1)));st.add_vertex(q)
static func fern(st: SurfaceTool,p: Vector3,rng: RandomNumberGenerator) -> void:
	for frond in range(6):
		var a: float=frond*TAU/6+rng.randf_range(-.2,.2);var out:=Vector3(cos(a),0,sin(a));var side:=Vector3(-out.z,0,out.x)
		var length_: float=rng.randf_range(.48,.80)
		for k in range(1,7):
			var u: float=k/7.;var center:=p+out*u*length_+Vector3.UP*sin(u*PI*.85)*.48
			for sign_ in [-1,1]:leaf(st,center,(side*sign_*.8+out*.3).normalized(),sin(u*PI)*.15+.035,.028,Color("709c58").lerp(Color("94b96c"),u*.6))
static func rock(st: SurfaceTool,p: Vector3,size_: Vector3,color: Color) -> void:
	var shape:=SphereMesh.new();shape.radius=1;shape.height=2;shape.radial_segments=9;shape.rings=4
	var arrays:=shape.get_mesh_arrays();var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		var q: Vector3=points[index];var tone:=.92+q.y*.09
		st.set_color(color* tone);st.set_uv(Vector2.ZERO);st.add_vertex(p+q*size_)
static func build(builder) -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=823911
	var material:=ShaderMaterial.new();material.shader=preload("res://assets/shaders/forest_blossoms.gdshader")
	var count:=0;var river_count:=0
	var anchors: Array[Vector2]=[Vector2(-12,18),Vector2(-27,26),Vector2(17,20),Vector2(30,15),Vector2(-29,0),Vector2(29,-1),Vector2(-27,-18),Vector2(29,-20),Vector2(-30,-35),Vector2(27,-35),Vector2(-8,-36),Vector2(7,30)]
	for index in range(anchors.size()):
		var root:=Node3D.new();root.name="WoodlandPatch%02d"%index;root.position=Vector3(anchors[index].x,0,anchors[index].y);builder.world.add_child(root)
		root.set_meta("buildable_reference",true);root.set_meta("module_id","woodland_patch_%02d"%index);root.set_meta("module_type","landscape_patch")
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in range(44):
			var point:=root.position+Vector3(rng.randfn(0,2.3),0,rng.randfn(0,2.0));point.y=Layout.height_at(point.x,point.z)+.035
			if not builder.nature_clear(point) or absf(point.z+9)<1.2 or absf(point.z+27)<1.2:continue
			var p: Vector3=point-root.position
			if k%4==0:fern(st,p,rng)
			elif k%4==1:
				for j in range(5):leaf(st,p,Vector3(cos(j*TAU/5+k),.12,sin(j*TAU/5+k)).normalized(),rng.randf_range(.28,.54),.085,Color("5b8c59").lerp(Color("a1b971"),rng.randf()*.5))
			elif k%4==2:
				rock(st,p+Vector3(0,.10,0),Vector3(.27,.17,.32)*rng.randf_range(.8,1.5),Color("879982"))
				for j in range(3):leaf(st,p+Vector3(j*.08,.04,0),Vector3(cos(j+k),.1,sin(j+k)),.22,.07,Color("8aa362"))
			else:
				for j in range(3):
					var q:=p+Vector3(j*.12,.015,sin(j*2)*.1)
					rock(st,q+Vector3(0,.11,0),Vector3(.035,.12,.035),Color("d6c6a0"));rock(st,q+Vector3(0,.23,0),Vector3(.12,.055,.11),Color("c09564" if index%2 else "c2ac7b"))
			count+=1
		st.generate_normals();var mesh:=st.commit()
		if mesh.get_surface_count()>0:
			var node:=G.mesh(root,mesh,Vector3.ZERO,material,"UnderstoryAndMoss");node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.visibility_range_end=65;node.visibility_range_end_margin=10
	# Bank irises, reed fans and stones frame water, leaving bridges and landings clear.
	for sector in range(6):
		var root:=Node3D.new();root.name="RiverbankPatch%02d"%sector;builder.world.add_child(root);root.position.z=-39+sector*14
		root.set_meta("buildable_reference",true);root.set_meta("module_type","riverbank_patch");root.set_meta("module_id","riverbank_%02d"%sector)
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in range(9):
			var z: float=root.position.z+rng.randf_range(-4,4)
			if absf(z-5)<3.1 or absf(z+9)<1.0 or absf(z+27)<1.0 or z>40:continue
			var side: float=-1. if k%2 else 1.
			var x: float=Layout.river_x(z)+side*(Layout.river_half_width(z)+rng.randf_range(.30,.7))
			var point:=Vector3(x,Layout.height_at(x,z)+.03,z)
			if not builder.nature_clear(point):continue
			var p: Vector3=point-root.position
			for j in range(6):
				var angle: float=j*TAU/6;leaf(st,p,Vector3(cos(angle)*.36,.95,sin(angle)*.36).normalized(),rng.randf_range(.45,.80),.028,Color("769352").lerp(Color("b0b97b"),float(j)/9))
			if k%3==0:Blooms.bloom(st,p,Color("b9b7dc"),rng,1.25)
			river_count+=1
		st.generate_normals();var mesh:=st.commit()
		if mesh.get_surface_count()>0:
			var node:=G.mesh(root,mesh,Vector3.ZERO,material,"ReedsAndIrises");node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.visibility_range_end=70;node.visibility_range_end_margin=8
	# Independent fallen logs; placement keeps them outside paths and resource access.
	for index in range(4):
		var p: Vector3=[Vector3(-30,0,18),Vector3(28,0,25),Vector3(-29,2,-17),Vector3(30,4,-33)][index];p.y=Layout.height_at(p.x,p.z)
		if not builder.nature_clear(p):continue
		var root:=Node3D.new();root.name="FallenLog%d"%index;root.position=p;root.rotation.y=index*1.73;builder.world.add_child(root)
		root.set_meta("buildable_reference",true);root.set_meta("module_id","fallen_log_%d"%index);root.set_meta("module_type","fallen_log")
		var bark:=preload("res://scripts/city/environment_materials.gd").bark(Color("94714d"))
		G.capsule(root,Vector3(-.9,.24,0),Vector3(.9,.24,0),.24,bark,"Bark")
		var ring:=ShaderMaterial.new();ring.shader=preload("res://assets/shaders/log_rings.gdshader")
		for side in [-1,1]:
			var end:=G.cylinder(root,Vector3(side*1.13,.24,0),.205,.015,ring);end.rotation.z=PI/2
		preload("res://scripts/city/prop_collisions.gd").box(root,"LogCollision",Vector3(0,.20,0),Vector3(2.0,.40,.43))
	builder.world.set_meta("woodland_detail_count",count);builder.world.set_meta("riverbank_plant_count",river_count);builder.world.set_meta("woodland_dressing_revision",1)
	print("WOODLAND_DRESSING understory=",count," riverbank=",river_count)
