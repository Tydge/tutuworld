extends SceneTree
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Layout=preload("res://scripts/valley/valley_layout.gd")
const HomeBuilder=preload("res://scripts/city/home_builder.gd")
const Polish=preload("res://scripts/city/scenery_polish.gd")
var world: Node3D
var rng:=RandomNumberGenerator.new()
var forest=preload("res://scripts/city/forest_builder.gd").new()
func _initialize() -> void: call_deferred("build")
func group(parent: Node3D,id: String,p:=Vector3.ZERO) -> Node3D:
	var n:=Node3D.new();n.name=id;n.position=p;parent.add_child(n);return n
func floor_box(parent: Node3D,p: Vector3,size_: Vector3) -> void:
	var body:=G.solid_box(parent,p,size_,"WalkFloor");body.collision_layer=8;body.collision_mask=0
func build() -> void:
	if DisplayServer.get_name()=="headless": push_error("Generate valley with graphical GL to preserve MultiMesh buffers");quit(1);return
	rng.seed=540203
	world=Node3D.new();world.name="MianfengForest";root.add_child(world)
	world.set_meta("scenery_polished",true)
	forest.world=world;forest.rng.seed=45921
	build_environment();build_terrain();build_backing();build_stream();build_bridge();build_steps();build_house();build_forest();build_details();build_flower_meadows();build_lamps()
	preload("res://scripts/city/static_batches.gd").bake(world)
	own_map(world,world)
	# Keep the reusable building referenced, not copied into the terrain file.
	var packed:=PackedScene.new()
	if packed.pack(world)!=OK: push_error("Cannot pack valley");quit(1);return
	await process_frame;await RenderingServer.frame_post_draw
	var error:=ResourceSaver.save(packed,"res://scenes/valley_map.scn",ResourceSaver.FLAG_COMPRESS)
	print("VALLEY_BUILT result=",error," trees=",forest.tree_index," resources=",DB.resources("valley").size())
	world.free();packed=null
	await process_frame;await process_frame
	quit(0 if error==OK else 1)
func build_environment() -> void:
	var town: Node3D=load("res://scenes/city_map.tscn").instantiate()
	var environment: WorldEnvironment=town.get_node("Atmosphere").duplicate()
	environment.environment=environment.environment.duplicate(true);environment.environment.fog_density=.0012
	world.add_child(environment)
	var sun: DirectionalLight3D=town.get_node("Sun").duplicate();world.add_child(sun);town.free()
	var island:=group(world,"Island")
	var sea:=ShaderMaterial.new();sea.shader=load("res://assets/shaders/island_ocean.gdshader");island.set_meta("sea_material",sea)
	var water:=G.cylinder(island,Vector3(0,-1.55,0),2000,.08,sea);water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func build_terrain() -> void:
	var terrain:=group(world,"ForestTerrain")
	var material:=ShaderMaterial.new();material.shader=load("res://assets/shaders/forest_floor.gdshader");material.set_shader_parameter("lawn_texture",load("res://assets/terrain/spring_lawn_v1.png"))
	var cliff_material:=ShaderMaterial.new();cliff_material.shader=load("res://assets/shaders/forest_cliff.gdshader")
	var ridge_material:=ShaderMaterial.new();ridge_material.shader=load("res://assets/shaders/forest_ridge.gdshader");ridge_material.set_shader_parameter("shape_wobble",false)
	for chunk_z in range(-48,72,12):
		for chunk_x in range(-60,60,12):
			var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for z in range(chunk_z,chunk_z+12):
				for x in range(chunk_x,chunk_x+12):
					if not Layout.terrain_contains(x+.5,z+.5) and not Layout.terrain_contains(x,z) and not Layout.terrain_contains(x+1,z+1): continue
					for triangle in [[Vector2(x,z),Vector2(x+1,z),Vector2(x,z+1)],[Vector2(x+1,z),Vector2(x+1,z+1),Vector2(x,z+1)]]:
						append_terrain_triangle(st,triangle)
			st.generate_normals();var mesh: ArrayMesh=st.commit()
			if mesh.get_surface_count()==0: continue
			var n:=G.mesh(terrain,mesh,Vector3.ZERO,material,"TerrainChunk")
			var body:=StaticBody3D.new();body.collision_layer=8;body.collision_mask=0
			var shape:=CollisionShape3D.new();shape.shape=mesh.create_trimesh_shape();body.add_child(shape);n.add_child(body)
	# Rounded rock faces and turf ledges define the terraces around the stair openings.
	for z in [-9.,-27.]:
		var high:=Layout.bank_height(z-.1)
		for x in range(-43,44,3):
			if Layout.stair_lane(x) or (z== -27. and absf(x-12)<3.6): continue
			if absf(x-Layout.river_x(z))<4.5 or Vector2(x,z/.88).length()>49: continue
			var cliff:=G.box(world,Vector3(x,high-1.03,z-.18),Vector3(3.15,1.94,.42),cliff_material,"TerraceCliff")
			var barrier:=G.solid_box(world,cliff.position,Vector3(3.15,1.94,.42),"CliffCollision");barrier.collision_layer=5;barrier.collision_mask=0
			G.capsule(world,Vector3(x-1.55,high-.06,z-.35),Vector3(x+1.55,high-.06,z-.35),.16,G.mat("6e9c62"))
			G.box(world,Vector3(x,high-1.35,z+.047),Vector3(3.10,.035,.045),G.mat("a78f71"))
	for i in range(27):
		var a: float=i*TAU/27;var pos:=Vector3(cos(a)*54,0,sin(a)*47.5)
		if pos.z>30 and absf(pos.x)<34: continue
		if Vector2(pos.x-Layout.HOUSE.x,pos.z-Layout.HOUSE.z).length()<14: continue
		var near_resource:=false
		for source in DB.resources("valley"):
			if Vector2(pos.x-source.x,pos.z-source.z).length()<9: near_resource=true;break
		if near_resource: continue
		var h:=Layout.bank_height(pos.z)
		var ridge:=G.ball(world,pos+Vector3(0,h+.8,0),Vector3(rng.randf_range(5,8),rng.randf_range(3.0,5.5),5.6),ridge_material,"ForestRidge")
		warp_ridge(ridge)
		ridge.create_trimesh_collision()
		for body in ridge.get_children():
			if body is StaticBody3D: body.collision_layer=5;body.collision_mask=0
		forest.tree(pos+Vector3(0,h+3.7,0),rng.randf_range(6.0,8.2),"547f58")
	var backdrop:=SurfaceTool.new();backdrop.begin(Mesh.PRIMITIVE_TRIANGLES)
	for entry in [[Vector3(-75,4,-25),Vector3(18,10,25)],[Vector3(-42,6,-84),Vector3(29,12,24)],[Vector3(10,6,-87),Vector3(34,13,25)],[Vector3(74,4,-52),Vector3(23,11,29)],[Vector3(84,2,6),Vector3(18,9,28)]]:
		var mountain:=G.ball(world,entry[0],entry[1],ridge_material,"FarForestMountain");warp_ridge(mountain);mountain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for k in range(24):
			var angle: float=k*2.399;var r: float=2+float(k%5)*1.5
			var offset:=Vector3(cos(angle)*r,0,sin(angle)*r)
			var rho: float=pow(offset.x/entry[1].x,2)+pow(offset.z/entry[1].z,2)
			var top: float=entry[0].y+entry[1].y*sqrt(maxf(0,1-rho))
			Polish.append_crown(backdrop,entry[0]+Vector3(offset.x,top-entry[0].y+1.2,offset.z),Vector3(.95,1.45,.95),Color("4f785b").lerp(Color("628367"),float(k%4)/4.))
	backdrop.generate_normals()
	var canopy_material:=G.mat("ffffff").duplicate() as StandardMaterial3D;canopy_material.vertex_color_use_as_albedo=true;canopy_material.vertex_color_is_srgb=true
	var distant_trees:=G.mesh(world,backdrop.commit(),Vector3.ZERO,canopy_material,"FarForestTreetops");distant_trees.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func append_terrain_triangle(st: SurfaceTool,triangle: Array) -> void:
	# Clip boundary triangles to the rounded shoreline, rather than deleting square cells.
	var polygon: Array[Vector2]=[]
	for i in range(3):
		var a: Vector2=triangle[i];var b: Vector2=triangle[(i+1)%3]
		var inside:=Layout.terrain_contains(a.x,a.y);var next_inside:=Layout.terrain_contains(b.x,b.y)
		if inside: polygon.append(a)
		if inside!=next_inside:
			var lo:=a;var hi:=b
			for step in range(12):
				var midpoint: Vector2=(lo+hi)*.5
				if Layout.terrain_contains(midpoint.x,midpoint.y)==inside: lo=midpoint
				else: hi=midpoint
			polygon.append((lo+hi)*.5)
	for i in range(1,polygon.size()-1):
		for p in [polygon[0],polygon[i],polygon[i+1]]:
			st.set_uv(p);st.add_vertex(Vector3(p.x,Layout.height_at(p.x,p.y),p.y))
func build_stream() -> void:
	var river:=group(world,"Creek")
	var stream:=ShaderMaterial.new();stream.shader=load("res://assets/shaders/forest_stream.gdshader");river.set_meta("stream_material",stream)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lines: Array[float]=[]
	for i in range(209):
		var z: float=-44+i*.5
		if (z> -27.28 and z< -26.62) or (z> -9.28 and z< -8.62): continue
		lines.append(z)
	for z in [-27.28,-26.62,-9.28,-8.62]: lines.append(z)
	lines.sort()
	for row in range(lines.size()-1):
		if lines[row+1]-lines[row]>.51: continue
		for c in range(10):
			for v in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var z: float=lines[row+v.y];var x: float=Layout.river_x(z)+(float(c+v.x)/5.-1)*Layout.river_half_width(z)
				st.set_uv(Vector2(float(c+v.x)/10.,z*.15));st.add_vertex(Vector3(x,Layout.water_level(z),z))
	st.generate_normals();var water:=G.mesh(river,st.commit(),Vector3.ZERO,stream,"FlowingCreek");water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var falls:=ShaderMaterial.new();falls.shader=load("res://assets/shaders/forest_falls.gdshader")
	var foam:=ShaderMaterial.new();foam.shader=load("res://assets/shaders/forest_foam.gdshader")
	for z in [-9.,-27.]:
		var curtain:=SurfaceTool.new();curtain.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row in range(14):
			for col in range(18):
				for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
					var u: float=(col+corner.x)/18.;var t: float=(row+corner.y)/14.
					var pz: float=z-.28+.66*t;var y: float=Layout.bank_height(z-.1)-.22-2*smoothstep(0.,1.,t)
					var x: float=Layout.river_x(pz)+(u*2-1)*2.99
					curtain.set_uv(Vector2(u,t));curtain.add_vertex(Vector3(x,y,pz))
		curtain.generate_normals();var mesh:=G.mesh(river,curtain.commit(),Vector3.ZERO,falls,"CurvedCascade");mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var patch:=PlaneMesh.new();patch.size=Vector2(6.9,1.65)
		var splash:=G.mesh(river,patch,Vector3(Layout.river_x(z),Layout.water_level(z+.4)+.022,z+.72),foam,"FoamPool");splash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		build_spray(river,Vector3(Layout.river_x(z),Layout.water_level(z+.4)+.10,z+.5))
		for side in [-1.,1.]:
			for k in range(3):
				var px: float=Layout.river_x(z)+side*(3.28+k*.18);var pz: float=z-.65+k*.63
				var py: float=Layout.height_at(px,pz)+.06
				G.ball(world,Vector3(px,py,pz),Vector3(.31+k*.045,.20,.39),G.mat("919e8d" if k%2 else "a3ad94"),"CascadeBankRock")
	for z in range(-40,57,3):
		for side in [-1,1]:
			var x: float=Layout.river_x(z)+side*(Layout.river_half_width(z)+rng.randf_range(.28,.65))
			var pos:=Vector3(x,Layout.height_at(x,z)+.10,z)
			if absf(z-5)<3 or z>43 and side<0: continue
			G.ball(world,pos,Vector3(.32,.22,.38)*rng.randf_range(.75,1.2),G.mat("a5ad95" if z%2 else "919e8d"),"CreekPebble")
func build_spray(parent: Node3D,point: Vector3) -> void:
	# One GPU vertex-animated batch per fall; no per-frame CPU particle simulation.
	var shape:=SphereMesh.new();shape.radius=.018;shape.height=.036;shape.radial_segments=8;shape.rings=4
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=shape;mm.instance_count=32
	for i in range(32):
		mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(-2.7+i*.175,.02,sin(i*3.1)*.12)))
		mm.set_instance_custom_data(i,Color(fposmod(i*.618,1.),fposmod(i*.39,1.),fposmod(i*.73,1.),fposmod(i*.27,1.)))
	mm.custom_aabb=AABB(Vector3(-3.5,-.5,-1),Vector3(7,2,3))
	var spray:=MultiMeshInstance3D.new();spray.name="CascadeSpray";spray.multimesh=mm;spray.position=point
	var material:=ShaderMaterial.new();material.shader=load("res://assets/shaders/cascade_spray.gdshader");spray.material_override=material
	spray.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(spray)
func build_bridge() -> void:
	var bridge:=group(world,"CreekBridge",Vector3(0,0,5))
	var wood:=G.mat("c29b67");var trim:=G.mat("a98051")
	for k in range(31):
		var x: float=-6+k*.4;var y:=Layout.walk_height(x,5)
		G.box(bridge,Vector3(x,y-.075,0),Vector3(.37,.15,3.9),wood,"Plank")
		floor_box(bridge,Vector3(x,y-.10,0),Vector3(.42,.20,3.9))
	for side in [-1,1]:
		for x in [-5.,-3.,-1.,1.,3.,5.]:
			var y:=Layout.walk_height(x,5)
			G.capsule(bridge,Vector3(x,y,side*2.12),Vector3(x,y+1.1,side*2.12),.075,trim)
			P.cylinder(bridge,"RailPost",Vector3(x,y+.55,side*2.12),.13,1.1)
			if x<5:
				G.capsule(bridge,Vector3(x,y+.95,side*2.12),Vector3(x+2,Layout.walk_height(x+2,5)+.95,side*2.12),.065,wood)
func build_steps() -> void:
	var stairs:=group(world,"WoodlandSteps")
	for entry in Layout.STAIRS:
		var x: float=entry.x;var z: float=entry.y
		var lower: float=2.0 if z== -24 else Layout.bank_height(z+3.1)
		for step in range(10):
			var top: float=lower+(step+1)*.2
			var pos:=Vector3(x,top-.11,z+3-(step+.5)*.6)
			G.box(stairs,pos,Vector3(6.4,.22,.59),G.mat("c7b48b" if step%2 else "d0bf96"),"StoneStep")

			G.capsule(stairs,pos+Vector3(-3.16,.11,.26),pos+Vector3(3.16,.11,.26),.035,G.mat("ab9877"))
		var body:=StaticBody3D.new();body.name="SmoothStairRamp";body.collision_layer=8;body.collision_mask=0
		body.position=Vector3(x,lower,z);stairs.add_child(body)
		var shape:=ConvexPolygonShape3D.new();var points:=PackedVector3Array()
		for side in [-1.,1.]:
			for point in [Vector3(side*3.2,-.35,3.6),Vector3(side*3.2,-.35,-3.05),Vector3(side*3.2,0,3.6),Vector3(side*3.2,2,-2.4),Vector3(side*3.2,2,-3.05)]: points.append(point)
		shape.points=points;var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
		var apron:=SurfaceTool.new();apron.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in [Vector3(-3.2,0,3.6),Vector3(3.2,0,3.6),Vector3(-3.2,.2,3),Vector3(3.2,0,3.6),Vector3(3.2,.2,3),Vector3(-3.2,.2,3)]: apron.add_vertex(p)
		apron.generate_normals();G.mesh(stairs,apron.commit(),Vector3(x,lower,z),G.mat("c7b48b"),"StepApproachBevel")
		for side in [-1,1]:
			for k in range(4):
				var point:=Vector3(x+side*3.5,lower+k*.64,z+2.6-k*1.9)
				G.capsule(stairs,point,point+Vector3(0,1.0,0),.08,G.mat("a1845b"))
				P.cylinder(stairs,"StairPost",point+Vector3(0,.5,0),.12,1.)
				if k<3: G.capsule(stairs,point+Vector3(0,.87,0),point+Vector3(0,1.51,-1.9),.045,G.mat("b49566"))
func build_house() -> void:
	var builder:=HomeBuilder.new()
	var definition: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/houses/mianfeng_cottage.json"))
	var house:=builder.construct(world,definition);house.name="ValleyHome"
	# Open doorway lets the resident return on the same continuous navigation grid.
	var door:=house.get_node("Door");house.remove_child(door);door.free()
	HomeBuilder.pack_module(world,house,"res://scenes/valley_home.scn")
func nature_clear(point: Vector3) -> bool:
	if not Layout.can_walk(point) or Layout.on_path(point.x,point.z): return false
	if point.distance_to(Layout.HOUSE)<10: return false
	if point.x>4 and point.x<20 and point.z< -26: return false
	for resource in DB.resources("valley"):
		if Vector2(point.x-resource.x,point.z-resource.z).length()<2.8: return false
	return true
func build_forest() -> void:
	var planted: Array[Vector3]=[]
	for source in DB.resources("valley"):
		if source.item!="orange": continue
		var point:=Vector3(source.x,source.y,source.z);planted.append(point)
		forest.tree(point,5.2,"78ae4d",true)
	for i in range(360):
		var point:=Vector3(rng.randf_range(-48,48),0,rng.randf_range(-41,39));point.y=Layout.height_at(point.x,point.z)
		if not nature_clear(point): continue
		var clear:=true
		for other in planted:
			if Vector2(point.x-other.x,point.z-other.z).length()<5.5: clear=false;break
		if not clear: continue
		planted.append(point);forest.tree(point,rng.randf_range(4.7,6.8),["55934b","6ca34b","81b154"][i%3])
func build_details() -> void:
	# The lawn is a textured surface, with no scattered grass geometry.
	build_shrub_groves()
	build_harbor()
func build_lamps() -> void:
	var builder=preload("res://scripts/city/lamp_builder.gd").new();builder.lamps=group(world,"Streetlights")
	for point in [Vector2(-10,29),Vector2(8,8),Vector2(18,-28)]:
		builder.lamp(Vector3(point.x,Layout.height_at(point.x,point.y),point.y))
	for lamp in builder.lamps.get_children(): P.cylinder(lamp,"PoleCollision",Vector3(0,1.4,0),.23,2.8)

func own_map(node: Node,owner_: Node) -> void:
	for child in node.get_children():
		child.owner=owner_
		if child.scene_file_path=="": own_map(child,owner_)

func petal(st: SurfaceTool,origin: Vector3,axis: Vector3,side: Vector3,length_: float,width_: float,color: Color) -> void:
	for i in range(8):
		for j in [-1,i,i+1]:
			var a: float=j*TAU/8
			var point:=origin if j<0 else origin+axis*cos(a)*length_+side*sin(a)*width_+Vector3.UP*pow(absf(sin(a)),2)*.025
			st.set_color(color);st.set_uv(Vector2(0,1));st.add_vertex(point)
func build_flower_meadows() -> void:
	var shader:=ShaderMaterial.new();shader.shader=load("res://assets/shaders/forest_blossoms.gdshader")
	var count:=0
	var patches: Array[Vector2]=[Vector2(-12,9),Vector2(-15,12),Vector2(10,12),Vector2(18,8),Vector2(-22,-14),Vector2(26,-20),Vector2(-24,-32),Vector2(22,-34),Vector2(-25,25),Vector2(10,27),Vector2(5,-18),Vector2(-30,2)]
	for index in range(patches.size()):
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in range(28):
			var point:=Vector3(patches[index].x+rng.randfn(0,1.2),0,patches[index].y+rng.randfn(0,1.0))
			point.y=Layout.height_at(point.x,point.z)+.025
			if not nature_clear(point): continue
			var tall:=rng.randf_range(.24,.49);var tip:=point+Vector3(rng.randf_range(-.05,.05),tall,0)
			var bloom: Color=[Color("fff1c3"),Color("f2ba63"),Color("ce98cc"),Color("f0a2a0")][(index+k/9)%4]
			for axis in [Vector3.RIGHT,Vector3.BACK]:
				for p in [point-axis*.012,point+axis*.012,tip-axis*.010,point+axis*.012,tip+axis*.010,tip-axis*.010]:
					st.set_color(Color("518347"));st.set_uv(Vector2(0,0));st.add_vertex(p)
			for side in [-1,1]: petal(st,point+Vector3(side*.055,tall*.40,0),Vector3(side*.12,.07,.02).normalized(),Vector3.BACK,.13,.045,Color("68a34f"))
			for i in range(6):
				var angle: float=i*TAU/6+k*.7
				var axis:=Vector3(cos(angle),.12,sin(angle));var side:=Vector3(-sin(angle),0,cos(angle))
				petal(st,tip+axis*.09,axis,side,.12,.073,bloom)
			for i in range(10):
				for p in [tip+Vector3(0,.033,0),tip+Vector3(cos(i*TAU/10)*.065,.018,sin(i*TAU/10)*.065),tip+Vector3(cos((i+1)*TAU/10)*.065,.018,sin((i+1)*TAU/10)*.065)]:
					st.set_color(Color("d59b3d"));st.set_uv(Vector2(0,1));st.add_vertex(p)
			count+=1
		st.generate_normals();var mesh:=st.commit()
		if mesh.get_surface_count()>0:
			var node:=G.mesh(world,mesh,Vector3.ZERO,shader,"FlowerMeadow%02d"%index)
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.set_meta("meadow_flower_count",count)
	print("VALLEY_FLOWER_MEADOWS blooms=",count)

func build_shrub_groves() -> void:
	var patches: Array[Vector2]=[Vector2(-12,13),Vector2(17,13),Vector2(-31,22),Vector2(29,23),Vector2(-28,-16),Vector2(31,-17),Vector2(-25,-34),Vector2(29,-34),Vector2(-33,0)]
	var fern_material:=ShaderMaterial.new();fern_material.shader=load("res://assets/shaders/forest_blossoms.gdshader")
	var total:=0
	for index in range(patches.size()):
		for j in range(6):
			var a: float=j*2.399;var point:=Vector3(patches[index].x+cos(a)*rng.randf_range(.4,1.5),0,patches[index].y+sin(a)*rng.randf_range(.4,1.0))
			point.y=Layout.height_at(point.x,point.z)
			if not nature_clear(point): continue
			var radius:=rng.randf_range(.56,.87);var tall:=rng.randf_range(.36,.64)
			G.ball(world,point+Vector3(0,tall*.70,0),Vector3(radius,tall,radius*.85),G.mat(["579447","6caa53","4c8948"][j%3]),"WoodlandShrub")
			for leaf in range(3):
				var angle: float=leaf*TAU/3+index
				var node:=G.ball(world,point+Vector3(cos(angle)*radius*.48,tall*1.22,sin(angle)*radius*.48),Vector3(radius*.42,tall*.33,radius*.38),G.mat("7db75b" if j%2 else "66a452"),"ShrubNewGrowth")
				node.rotation.y=angle
			total+=1
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for fern in range(2):
			var point:=Vector3(patches[index].x+(.8 if fern else -.8),0,patches[index].y+1.3)
			point.y=Layout.height_at(point.x,point.z)+.035
			if not nature_clear(point): continue
			for frond in range(5):
				var a: float=frond*TAU/5+index*.7;var forward:=Vector3(cos(a),0,sin(a));var side:=Vector3(-sin(a),0,cos(a))
				for step in range(1,7):
					var u: float=step/7.;var center: Vector3=point+forward*u*.70+Vector3(0,sin(u*PI*.85)*.48,0)
					for sign_ in [-1,1]:
						var axis: Vector3=(side*sign_*.85+forward*.35).normalized();var length_: float=.10*sin(u*PI)+.025
						petal(st,center+axis*length_*.65,axis,forward,length_,.026,Color("74ad59" if step%2 else "609a4c"))
		st.generate_normals();var shape:=st.commit()
		if shape.get_surface_count()>0:
			var n:=G.mesh(world,shape,Vector3.ZERO,fern_material,"FernGrove%02d"%index);n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.set_meta("shrub_count",total);world.set_meta("groundcover_style","textured_lawn_with_shrub_groves")

func build_backing() -> void:
	# A continuous, closed valley backdrop replaces gaps between isolated ridge meshes.
	var ring:=group(world,"ValleyRim")
	var material:=ShaderMaterial.new();material.shader=load("res://assets/shaders/forest_ridge.gdshader");material.set_shader_parameter("shape_wobble",false)
	var radii: Array[float]=[52.,55.,61.,70.,83.,96.]
	for sector in range(16):
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(sector*8,sector*8+8):
			var middle: float=(i+.5)*TAU/128.
			if sin(middle)>.70 and absf(cos(middle)*54)<36: continue
			for band in range(radii.size()-1):
				for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
					var a: float=(i+corner.x)*TAU/128.;var k: int=band+corner.y
					var base: float=Layout.bank_height(sin(a)*46.)
					var h: float=[-.08,1.7,5.5,8.5,7.0,-2.0][k]
					var variation: float=1.+.16*sin(a*5+.8)+.08*sin(a*11)
					st.set_uv(Vector2(a,radii[k]*.1));st.add_vertex(Vector3(cos(a)*radii[k],base+h*variation,sin(a)*radii[k]*.88))
		st.generate_normals();var shape:=st.commit()
		if shape.get_surface_count()==0: continue
		var mesh:=G.mesh(ring,shape,Vector3.ZERO,material,"RidgeSection");mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;mesh.add_child(body)
		var collision:=CollisionShape3D.new();collision.shape=shape.create_trimesh_shape();body.add_child(collision)
func build_harbor() -> void:
	var dock:=group(world,"ValleyHarbor")
	for i in range(28):
		var x: float=-14+(i+.5)*.4
		G.box(dock,Vector3(x,.09,47.2),Vector3(.37,.18,3.7),G.mat("c5a372" if i%3 else "ba9767"),"PierPlank")
	floor_box(dock,Vector3(-8.4,.03,47.2),Vector3(11.2,.30,3.7))
	for x in [-13.5,-10.5,-7.5,-4.5]:
		for side in [-1,1]:
			var z: float=47.2+side*1.95
			G.capsule(dock,Vector3(x,-.75,z),Vector3(x,1.08,z),.10,G.mat("9e7b51"),"PierPost")
			G.cylinder(dock,Vector3(x,1.11,z),.14,.06,G.mat("dbc39a"))
			P.cylinder(dock,"PostCollision",Vector3(x,.50,z),.16,1.3)
			if x< -4.5:
				G.capsule(dock,Vector3(x,.90,z),Vector3(x+1.5,.73,z),.032,G.mat("dbcc9f"),"MooringRope")
				G.capsule(dock,Vector3(x+1.5,.73,z),Vector3(x+3,.90,z),.032,G.mat("dbcc9f"),"MooringRope")
	# Low bank rocks frame the departure view without closing the waterway.
	for i in range(7):
		var p:=Vector3(-20+sin(i*2.4)*1.5,Layout.height_at(-20,38+i*2)+.1,38+i*2)
		G.ball(world,p,Vector3(.55,.40,.65),G.mat("9ca68d"),"HarborBankRock")
	world.set_meta("harbor_opening",true)

func warp_ridge(node: MeshInstance3D) -> void:
	# Bake the old shader silhouette into the mesh so its physical shape is identical.
	var mesh:=ArrayMesh.new()
	for surface in range(node.mesh.get_surface_count()):
		var arrays: Array=node.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		for i in range(vertices.size()):
			var v: Vector3=vertices[i]
			vertices[i]=v*(1.+sin(v.x*7.+v.z*4.)*.045+sin(v.y*8.-v.x*2.)*.035)
		arrays[Mesh.ARRAY_VERTEX]=vertices;mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	node.mesh=mesh
