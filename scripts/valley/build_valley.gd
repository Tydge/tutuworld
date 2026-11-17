extends SceneTree
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Layout=preload("res://scripts/valley/valley_layout.gd")
const HomeBuilder=preload("res://scripts/city/home_builder.gd")
var world: Node3D
var rng:=RandomNumberGenerator.new()
var forest=preload("res://scripts/city/forest_builder.gd").new()
func _initialize() -> void:call_deferred("build")
func group(parent: Node3D,id: String,p:=Vector3.ZERO) -> Node3D:
	var n:=Node3D.new();n.name=id;n.position=p;parent.add_child(n);return n
func floor_box(parent: Node3D,p: Vector3,size_: Vector3) -> void:
	var body:=G.solid_box(parent,p,size_,"WalkFloor");body.collision_layer=8;body.collision_mask=0
func build() -> void:
	if DisplayServer.get_name()=="headless":push_error("Generate valley with graphical GL to preserve MultiMesh buffers");quit(1);return
	rng.seed=540203
	world=Node3D.new();world.name="MianfengForest";root.add_child(world)
	world.set_meta("scenery_polished",true);world.set_meta("landscape_revision",Layout.REVISION);world.set_meta("continuous_heightfield",true);world.set_meta("playable_area_scale",4.)
	forest.world=world;forest.rng.seed=45921
	build_environment();build_terrain();build_backing();build_stream();build_bridge();build_house();build_forest();build_harbor();build_flower_meadows();build_lamps()
	preload("res://scripts/valley/woodland_groundcover.gd").build(self)
	preload("res://scripts/valley/woodland_dressing.gd").build(self)
	preload("res://scripts/city/terrain_materials.gd").apply(world)
	preload("res://scripts/city/environment_materials.gd").apply(world)
	preload("res://scripts/city/water_materials.gd").apply(world)
	preload("res://scripts/city/static_batches.gd").bake(world)
	own_map(world,world)
	var packed:=PackedScene.new()
	if packed.pack(world)!=OK:push_error("Cannot pack valley");quit(1);return
	await process_frame;await RenderingServer.frame_post_draw
	var error:=ResourceSaver.save(packed,"res://scenes/valley_map.scn",ResourceSaver.FLAG_COMPRESS)
	print("VALLEY_BUILT result=",error," trees=",world.get_meta("ancient_tree_count")," resources=",DB.resources("valley").size())
	world.free();packed=null;await process_frame;await process_frame;quit(0 if error==OK else 1)
func build_environment() -> void:
	var town: Node3D=load("res://scenes/city_map.tscn").instantiate()
	var environment: WorldEnvironment=town.get_node("Atmosphere").duplicate();environment.environment=environment.environment.duplicate(true);world.add_child(environment)
	var sun: DirectionalLight3D=town.get_node("Sun").duplicate()
	sun.directional_shadow_max_distance=160.;sun.directional_shadow_fade_start=.70;sun.directional_shadow_blend_splits=true
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS;sun.directional_shadow_split_1=.22
	world.add_child(sun);town.free()
	var island:=group(world,"Island");var sea:=ShaderMaterial.new();sea.shader=load("res://assets/shaders/island_ocean.gdshader");sea.set_shader_parameter("valley_estuary",true);island.set_meta("sea_material",sea)
func build_terrain() -> void:
	var terrain:=group(world,"ForestTerrain")
	var material:=ShaderMaterial.new();material.shader=load("res://assets/shaders/forest_floor.gdshader")
	material.set_shader_parameter("lawn_texture",load("res://assets/terrain/woodland/forest_turf_v1.png"));material.set_shader_parameter("rock_texture",load("res://assets/terrain/soft_moss_rock_v1.png"))
	for cz in range(-96,160,16):
		for cx in range(-112,112,16):
			var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for z in range(cz,cz+16):
				for x in range(cx,cx+16):
					if not Layout.terrain_contains(x+.5,z+.5) and not Layout.terrain_contains(x,z) and not Layout.terrain_contains(x+1,z+1):continue
					for triangle in [[Vector2(x,z),Vector2(x+1,z),Vector2(x,z+1)],[Vector2(x+1,z),Vector2(x+1,z+1),Vector2(x,z+1)]]:append_terrain_triangle(st,triangle,Vector2(cx,cz))
			st.generate_normals();var mesh:=st.commit()
			if mesh.get_surface_count()==0:continue
			var node:=G.mesh(terrain,mesh,Vector3(cx,0,cz),material,"TerrainChunk")
			var body:=StaticBody3D.new();body.collision_layer=8;body.collision_mask=0
			var collision:=CollisionShape3D.new();collision.shape=mesh.create_trimesh_shape();body.add_child(collision);node.add_child(body)
func append_terrain_triangle(st: SurfaceTool,triangle: Array,origin: Vector2) -> void:
	var polygon: Array[Vector2]=[]
	for i in range(3):
		var a: Vector2=triangle[i];var b: Vector2=triangle[(i+1)%3];var inside:=Layout.terrain_contains(a.x,a.y);var next_inside:=Layout.terrain_contains(b.x,b.y)
		if inside:polygon.append(a)
		if inside!=next_inside:
			var lo:=a;var hi:=b
			for step in range(12):
				var p: Vector2=(lo+hi)*.5
				if Layout.terrain_contains(p.x,p.y)==inside:lo=p
				else:hi=p
			polygon.append((lo+hi)*.5)
	for i in range(1,polygon.size()-1):
		for p in [polygon[0],polygon[i],polygon[i+1]]:st.set_uv(p);st.add_vertex(Vector3(p.x-origin.x,Layout.height_at(p.x,p.y),p.y-origin.y))
func build_stream() -> void:
	var creek:=group(world,"Creek");creek.set_meta("unified_water",true)
	var island: Node3D=world.get_node("Island");var material: ShaderMaterial=island.get_meta("sea_material")
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array[float]=[-2000.]
	for row in range(423):rows.append(-94.+row*.5)
	rows.append(2000.)
	for row in range(rows.size()-1):
		for col in range(5):
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var z: float=rows[row+corner.y];var center: float=Layout.river_x(z);var width: float=Layout.river_half_width(z)
				var xs: Array=[-2000.,center-width-.02,center-width,center+width,center+width+.02,2000.]
				var column: int=col+corner.x;var level:=Layout.water_level(z) if column in [2,3] and z>= -94. and z<=117. else -1.55
				st.set_uv(Vector2(column/5.,z*.08));st.add_vertex(Vector3(xs[column],level,z))
	st.generate_normals();var water:=G.mesh(island,st.commit(),Vector3.ZERO,material,"ContinuousRiverAndSea");water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bed:=PlaneMesh.new();bed.size=Vector2(700,700)
	var bottom:=G.mesh(island,bed,Vector3(0,-12,180),G.mat("546c58"),"DeepBayBed");bottom.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var stones:=group(world,"RiverStones");stones.set_meta("buildable_reference",true)
	for z in range(-84,105,5):
		for side in [-1,1]:
			if absf(z-Layout.BRIDGE_Z)<4:continue
			var x: float=Layout.river_x(z)+side*(Layout.river_half_width(z)+rng.randf_range(.15,.75));var p:=Vector3(x,Layout.height_at(x,z)+.02,z)
			var size_:=Vector3(.4,.27,.48)*rng.randf_range(.6,1.5)
			var rock:=G.ball(stones,p,size_,G.mat("929d82" if z%3 else "a0a78b"),"WaterwornStone");rock.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func build_bridge() -> void:
	var bridge:=group(world,"CreekBridge",Vector3(0,0,Layout.BRIDGE_Z));var wood:=G.mat("b49365");var trim:=G.mat("967343")
	for k in range(61):
		var x: float=-12+k*.4;var y:=Layout.bridge_height(x)
		G.box(bridge,Vector3(x,y-.075,0),Vector3(.37,.15,3.9),wood,"Plank");floor_box(bridge,Vector3(x,y-.10,0),Vector3(.42,.20,3.9))
	for side in [-1,1]:
		for x in range(-11,12,2):
			var y:=Layout.bridge_height(x)
			G.capsule(bridge,Vector3(x,y,side*2.12),Vector3(x,y+1.1,side*2.12),.065,trim);P.cylinder(bridge,"RailPost",Vector3(x,y+.55,side*2.12),.12,1.1)
			if x<11:G.capsule(bridge,Vector3(x,y+.95,side*2.12),Vector3(x+2,Layout.bridge_height(x+2)+.95,side*2.12),.05,wood)
func build_house() -> void:
	var builder:=HomeBuilder.new();var definition: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/houses/mianfeng_cottage.json"));var house:=builder.construct(world,definition);house.name="ValleyHome"
	var door:=house.get_node("Door");house.remove_child(door);door.free();HomeBuilder.pack_module(world,house,"res://scenes/valley_home.scn")
func nature_clear(point: Vector3) -> bool:
	if not Layout.can_walk(point) or Layout.on_path(point.x,point.z):return false
	if Vector2(point.x-Layout.HOUSE.x,point.z-Layout.HOUSE.z).length()<13:return false
	if Layout.on_dock(point) or Vector2(point.x+21,point.z-91).length()<9:return false
	if Vector2(point.x+36,point.z-40).length()<3. or Vector2(point.x-44,point.z+32).length()<3.:return false
	for resource in DB.resources("valley"):
		if Vector2(point.x-resource.x,point.z-resource.z).length()<3.2:return false
	return true
func build_forest() -> void:
	for source in DB.resources("valley"):
		if source.item=="orange":forest.tree(Vector3(source.x,source.y,source.z),6.5,"8aab57",true)
	preload("res://scripts/valley/ancient_forest.gd").new().build(self)
func build_harbor() -> void:
	var dock:=group(world,"ValleyHarbor")
	for i in range(28):G.box(dock,Vector3(Layout.DOCK_DECK.position.x+(i+.5)*.4,Layout.DOCK_HEIGHT-.09,Layout.DOCK.y),Vector3(.37,.18,Layout.DOCK_DECK.size.y),G.mat("b99a6a" if i%3 else "ad8c60"),"PierPlank")
	floor_box(dock,Vector3(Layout.DOCK_DECK.get_center().x,Layout.DOCK_HEIGHT-.15,Layout.DOCK.y),Vector3(Layout.DOCK_DECK.size.x,.30,Layout.DOCK_DECK.size.y))
	for x in [-21.9,-18.9,-15.9,-12.9]:
		for side in [-1,1]:
			var z: float=Layout.DOCK.y+side*1.95
			G.capsule(dock,Vector3(x,-1.5,z),Vector3(x,1.08,z),.10,G.mat("997951"),"PierPost");P.cylinder(dock,"PostCollision",Vector3(x,.50,z),.16,1.3)
			if x< -12.9:G.capsule(dock,Vector3(x,.90,z),Vector3(x+3,.90,z),.035,G.mat("d7c9a5"),"MooringRope")
	world.set_meta("harbor_opening",true)
func build_lamps() -> void:
	var builder=preload("res://scripts/city/lamp_builder.gd").new();builder.lamps=group(world,"Streetlights")
	for point in [Vector2(-20,58),Vector2(16,16),Vector2(36,-56)]:builder.lamp(Vector3(point.x,Layout.height_at(point.x,point.y),point.y))
	for lamp in builder.lamps.get_children():P.cylinder(lamp,"PoleCollision",Vector3(0,1.4,0),.23,2.8)
func build_backing() -> void:
	var rim:=group(world,"ValleyRim");rim.set_meta("buildable_reference",true)
	var material:=ShaderMaterial.new();material.shader=load("res://assets/shaders/forest_ridge.gdshader");material.set_shader_parameter("shape_wobble",false)
	var radii: Array=[103.,109.,122.,140.,160.,185.]
	for sector in range(24):
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for slice in range(sector*8,sector*8+8):
			var middle: float=(slice+.5)*TAU/192.
			if sin(middle)>.72 and absf(cos(middle)*106)<65:continue
			for band in range(radii.size()-1):
				for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
					var a: float=(slice+corner.x)*TAU/192.;var radius: float=radii[band+corner.y]
					st.set_uv(Vector2(a,radius*.1));st.add_vertex(Vector3(cos(a)*radius,Layout.backdrop_height(radius,a),sin(a)*radius*.88))
		st.generate_normals();var mesh:=G.mesh(rim,st.commit(),Vector3.ZERO,material,"RoundedRidge");mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var body:=StaticBody3D.new();body.collision_layer=8;body.collision_mask=0;mesh.add_child(body)
		var collision:=CollisionShape3D.new();collision.shape=mesh.mesh.create_trimesh_shape();body.add_child(collision)
func own_map(node: Node,owner_: Node) -> void:
	for child in node.get_children():
		child.owner=owner_
		if child.scene_file_path=="":own_map(child,owner_)
func petal(st: SurfaceTool,origin: Vector3,axis: Vector3,side: Vector3,length_: float,width_: float,color: Color) -> void:
	for i in range(8):
		for j in [-1,i,i+1]:
			var a: float=j*TAU/8
			var point:=origin if j<0 else origin+axis*cos(a)*length_+side*sin(a)*width_+Vector3.UP*pow(absf(sin(a)),2)*.025
			st.set_color(color);st.set_uv(Vector2(0,1));st.add_vertex(point)
func build_flower_meadows() -> void:
	var shader:=ShaderMaterial.new();shader.shader=load("res://assets/shaders/forest_blossoms.gdshader")
	shader.set_shader_parameter("plant_fade",Vector2(58,86))
	var count:=0
	var patches: Array[Vector2]=[Vector2(-12,9),Vector2(-15,12),Vector2(10,12),Vector2(18,8),Vector2(-22,-14),Vector2(26,-20),Vector2(-24,-32),Vector2(22,-34),Vector2(-25,25),Vector2(10,27),Vector2(5,-18),Vector2(-30,2)]
	patches.assign(patches.map(func(p):return p*2.))
	for index in range(patches.size()):
		var holder:=group(world,"WildflowerGlade%02d"%index,Vector3(patches[index].x,Layout.height_at(patches[index].x,patches[index].y),patches[index].y));holder.set_meta("buildable_reference",true)
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in range(48):
			var point:=Vector3(patches[index].x+rng.randfn(0,2.4),0,patches[index].y+rng.randfn(0,2.0))
			point.y=Layout.height_at(point.x,point.z)+.025
			if not nature_clear(point): continue
			point-=holder.position
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
			var node:=G.mesh(holder,mesh,Vector3.ZERO,shader,"FlowerMeadow%02d"%index);node.visibility_range_end=100.;node.visibility_range_end_margin=0.
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.set_meta("meadow_flower_count",count)
	print("VALLEY_FLOWER_MEADOWS blooms=",count)
