extends "res://scripts/builders/scene_builder_base.gd"
const DB = preload("res://scripts/services/game_data.gd")
var lamps: Node3D
var meadow_material: ShaderMaterial
var paving_material: ShaderMaterial
var roof_materials: Dictionary={}
func _initialize() -> void:
	call_deferred("build")
func build() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Generate city_map with a rendering window: the headless GL dummy driver cannot serialize MultiMesh buffers.")
		quit(1)
		return
	for filename in ["res://scripts/city/seabreeze_home.gd","res://scripts/city/home_builder.gd","res://scripts/city/shop_builder.gd"]:
		var dependency: Script=load(filename)
		if dependency==null or not dependency.can_instantiate():
			push_error("Building generation stopped: invalid dependency "+filename);quit(1);return
	rng.seed=290107
	world=Node3D.new()
	world.name="CityMap"
	root.add_child(world)
	build_environment()
	var environment: Environment=world.get_node("Atmosphere").environment
	environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure=1.0
	environment.fog_density=.0009
	environment.ambient_light_energy=.53
	environment.ambient_light_color=Color("d5e9ef")
	var sky_material:=ShaderMaterial.new()
	sky_material.shader=load("res://assets/shaders/island_sky.gdshader")
	var sky_palette: Dictionary=preload("res://scripts/city/sky_palette.gd").at_time(.5)
	sky_material.set_shader_parameter("zenith_color",sky_palette.zenith)
	sky_material.set_shader_parameter("horizon_color",sky_palette.horizon)
	sky_material.set_shader_parameter("cloud_color",sky_palette.cloud)
	environment.sky.sky_material=sky_material
	environment.sky.radiance_size=Sky.RADIANCE_SIZE_64
	environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
	var sun_: DirectionalLight3D=world.get_node("Sun")
	sun_.directional_shadow_max_distance=48
	sun_.shadow_blur=1.85
	sun_.shadow_bias=.025
	sun_.shadow_normal_bias=.65
	sun_.shadow_opacity=.85
	sun_.light_energy=1.45
	sun_.light_color=Color("fff6e6")
	meadow_material=ShaderMaterial.new()
	meadow_material.shader=load("res://assets/shaders/meadow.gdshader")
	meadow_material.set_shader_parameter("lawn_texture",load("res://assets/terrain/spring_lawn_v1.png"))
	meadow_material.set_shader_parameter("meadow_color",Color("4b9853"))
	paving_material=ShaderMaterial.new()
	paving_material.shader=load("res://assets/shaders/paving.gdshader")
	paving_material.set_shader_parameter("stone_color",Color("87939e"))
	build_city_island()
	build_streets()
	build_plaza()
	build_districts()
	build_large_farm()
	build_beach()
	build_city_nature()
	preload("res://scripts/city/scenery_polish.gd").apply(world)
	preload("res://scripts/city/prop_collisions.gd").build(world)
	for required in ["Kitchen/PotSteam","DiningTable/SeatAnchor","SeabreezeHome/Furnishing/bed/SleepExit","Shop_farm/MerchantAnchor","Shop_tools/MerchantAnchor","Shop_clothes/MerchantAnchor"]:
		if not world.has_node(required):
			push_error("Building generation stopped: missing "+required);quit(1);return
	optimize_static_geometry()
	await process_frame
	await RenderingServer.frame_post_draw
	save_scene(world,"res://scenes/city_map.tscn")
	print("CITY_MAP_BUILT area_ratio=4.84 plots=48")
	quit()
func build_city_island() -> void:
	var terrain := group(world,"Island")
	var sea_mat:=ShaderMaterial.new()
	sea_mat.shader=load("res://assets/shaders/island_ocean.gdshader")
	terrain.set_meta("sea_material",sea_mat)
	var sea:=G.cylinder(terrain,Vector3(0,-1.5,0),4000,.1,sea_mat)
	sea.name="Sea"
	sea.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cliff := G.cylinder(terrain,Vector3(0,-.90,0),55,1.4,G.mat("c6aa7e"))
	cliff.scale.z=.88
	var shore := G.cylinder(terrain,Vector3(0,-.33,0),56,.3,G.mat("e7d19e"))
	shore.scale.z=.88
	var grass := G.cylinder(terrain,Vector3(0,-.18,0),55,.3,meadow_material)
	grass.scale.z=.88
	G.solid_box(terrain,Vector3(0,-.55,0),Vector3(114,1.05,106),"GroundCollision")
	var beach_top:=G.mesh(terrain,beach_top_mesh(),Vector3(0,.02,34),G.mat("ebd8a7"),"SouthBeach")
	beach_top.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(14):
		var a:=float(i)/14*TAU
		G.ball(terrain,Vector3(cos(a)*98,-3,sin(a)*110),Vector3(12,6,11),G.mat("a3bca8"))

func floor_box(parent: Node3D,p: Vector3,size_: Vector3) -> void:
	var floor_:=G.solid_box(parent,p,size_,"WalkFloor")
	floor_.collision_layer=8
	floor_.collision_mask=0
func road(a: Vector3,b: Vector3,width: float=5.0) -> void:
	var roads:=world.get_node("Streets")
	var n:=group(roads,"Lane",(a+b)*.5)
	n.rotation.y=atan2((b-a).x,(b-a).z)
	floor_box(n,Vector3(0,-.10,0),Vector3(width,.294,a.distance_to(b)))
	for side in [-1,1]: floor_box(n,Vector3(side*(width*.5+.34),-.10,0),Vector3(.65,.34,a.distance_to(b)))
	var length_:=a.distance_to(b)
	var count:=int(ceil(length_/7.0))
	var segment:=length_/count
	for k in range(count):
		var z: float=-length_*.5+(k+.5)*segment
		G.box(n,Vector3(0,.012,z),Vector3(width,.07,segment),paving_material)
		for side in [-1,1]:
			G.box(n,Vector3(side*(width*.5+.34),.025,z),Vector3(.65,.09,segment),G.mat("c2baa2"))
	for side in [-1,1]:
		for k in range(int(length_/2)):
			G.box(n,Vector3(side*(width*.5+.34),.076,-length_*.5+k*2),Vector3(.59,.008,.035),G.mat("c4baa0"))
func build_streets() -> void:
	group(world,"Streets")
	road(Vector3(0,0,-40),Vector3(0,0,33),6)
	road(Vector3(-43,0,13),Vector3(43,0,13),5)
	road(Vector3(-43,0,-13),Vector3(43,0,-13),5)
	road(Vector3(-30,0,-19),Vector3(29,0,-19),4)
	road(Vector3(-25,0,-26),Vector3(-25,0,27),4)
	road(Vector3(17,0,-26),Vector3(17,0,24),4)
	lamps=group(world,"Streetlights")
	for z in range(-31,30,9):
		for x in [-4.6,4.6]: lamp(Vector3(x,0,z))
	for x in [-38,-29,-18,18,29,40]:
		lamp(Vector3(x,0,16.7))
		lamp(Vector3(x,0,-16.7))
func lamp(p: Vector3) -> void:
	if p.distance_to(Vector3(-4.6,0,-22))<.1: p=Vector3(-10.0,0,-20.2)
	var n:=group(lamps,"Lamp",p)
	var iron:=G.mat("526f67")
	G.cylinder(n,Vector3(0,1.5,0),.075,3,iron)
	G.cylinder(n,Vector3(0,.14,0),.20,.28,iron)
	G.box(n,Vector3(0,3.0,0),Vector3(.42,.65,.42),G.mat("ffe3a1",.7,.16),"GlowGlass")
	for x in [-.23,.23]:
		for z in [-.23,.23]: G.box(n,Vector3(x,3.0,z),Vector3(.045,.70,.045),iron)
	G.box(n,Vector3(0,2.65,0),Vector3(.54,.08,.54),iron)
	G.cylinder(n,Vector3(0,3.39,0),.38,.20,iron,.025)
	var light:=OmniLight3D.new()
	light.name="NightLight"
	light.position.y=2.8
	light.light_color=Color("ffd491")
	light.light_energy=3.2
	light.omni_range=10.5
	light.omni_attenuation=1.25
	light.shadow_enabled=false
	light.visible=false
	light.distance_fade_enabled=false
	n.add_child(light)
	var halo:=ShaderMaterial.new()
	halo.shader=load("res://assets/shaders/lamp_glow.gdshader")
	halo.set_shader_parameter("billboard",true)
	var disc:=QuadMesh.new()
	disc.size=Vector2(1.8,1.8)
	var glow:=G.mesh(n,disc,Vector3(0,3.05,0),halo,"LanternHalo")
	glow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pool_material:=ShaderMaterial.new()
	pool_material.shader=load("res://assets/shaders/lamp_glow.gdshader")
	var plane:=PlaneMesh.new()
	plane.size=Vector2(8.8,8.8)
	var pool:=G.mesh(n,plane,Vector3(0,.15,0),pool_material,"WarmPool")
	pool.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var frame:=SurfaceTool.new()
	frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in n.get_children():
		if part is MeshInstance3D and part.material_override==iron:
			frame.append_from(part.mesh,0,part.transform)
			n.remove_child(part)
			part.free()
	G.mesh(n,frame.commit(),Vector3.ZERO,iron,"LanternFrame")
func build_plaza() -> void:
	var park:=group(world,"CentralPark")
	G.cylinder(park,Vector3(0,.05,0),10,.12,paving_material)
	var floor_body:=StaticBody3D.new()
	floor_body.name="PlazaFloor"
	floor_body.collision_layer=8
	floor_body.collision_mask=0
	floor_body.position.y=-.10
	var floor_shape:=CollisionShape3D.new()
	var floor_cylinder:=CylinderShape3D.new()
	floor_cylinder.radius=10
	floor_cylinder.height=.42
	floor_shape.shape=floor_cylinder
	floor_body.add_child(floor_shape)
	park.add_child(floor_body)
	var stone:=G.mat("d9d4ba")
	var porcelain:=G.mat("83aaa4")
	G.cylinder(park,Vector3(0,.13,0),3.22,.20,stone)
	G.cylinder(park,Vector3(0,.28,0),3.02,.28,porcelain)
	var rim:=TorusMesh.new()
	rim.inner_radius=2.65
	rim.outer_radius=3.07
	rim.rings=48
	rim.ring_segments=10
	G.mesh(park,rim,Vector3(0,.53,0),stone,"RoundedFountainRim")
	G.solid_cylinder(park,Vector3(0,.4,0),3.05,.8)
	var water:=ShaderMaterial.new()
	water.shader=load("res://assets/shaders/fountain_water.gdshader")
	G.cylinder(park,Vector3(0,.48,0),2.67,.025,water,-1,"FountainWater")
	G.cylinder(park,Vector3(0,.92,0),.30,1.10,stone,.25)
	G.cylinder(park,Vector3(0,1.44,0),.90,.15,porcelain,1.06)
	var upper_rim:=TorusMesh.new()
	upper_rim.inner_radius=.86
	upper_rim.outer_radius=1.08
	upper_rim.rings=40
	upper_rim.ring_segments=8
	G.mesh(park,upper_rim,Vector3(0,1.55,0),stone,"UpperBowlRim")
	G.cylinder(park,Vector3(0,1.55,0),.88,.02,water)
	G.cylinder(park,Vector3(0,1.78,0),.13,.48,stone,.09)
	G.ball(park,Vector3(0,2.02,0),Vector3.ONE*.20,stone)
	var jet_material:=water.duplicate() as ShaderMaterial
	jet_material.set_shader_parameter("jet",true)
	G.mesh(park,fountain_jets(),Vector3.ZERO,jet_material,"FlowingWaterArcs")
	for i in range(12):
		var a:=i*TAU/12
		G.ball(park,Vector3(cos(a)*2.85,.32,sin(a)*2.85),Vector3(.11,.14,.07),G.mat("b6c6b3"))
	var fountain_light:=OmniLight3D.new()
	fountain_light.name="FountainGlow"
	fountain_light.position=Vector3(0,.9,0)
	fountain_light.light_color=Color("9dd9d2")
	fountain_light.light_energy=0
	fountain_light.omni_range=7
	fountain_light.shadow_enabled=false
	park.add_child(fountain_light)
	for i in range(4):
		var p:=Vector3(-8 if i%2==0 else 8,0,-7 if i<2 else 7)
		G.cylinder(park,p+Vector3(0,.18,0),1.6,.4,G.mat("c7b48a"))
		G.cylinder(park,p+Vector3(0,.39,0),1.45,.07,G.mat("75985b"))
		for k in range(12): flower(park,p+Vector3(cos(k)*1.15,.46,sin(k)*1.15),G.mat("e9b6a6" if i%2 else "f3df9f"),.18)
	for x in [-7.5,7.5]:
		for z in [-3.5,3.5]: bench(park,Vector3(x,0,z),PI*.5 if x>0 else -PI*.5)
	var sign:=group(park,"WelcomeSign",Vector3(-5.8,0,10))
	G.box(sign,Vector3(0,1.15,0),Vector3(3.6,1.1,.18),G.mat("f0dfb5"))
	for x in [-1.3,1.3]: G.cylinder(sign,Vector3(x,.6,0),.065,1.2,wood)
	G.text3d(sign,"慢慢来海岛城",Vector3(0,1.28,.12),40,Color("426e5c"))
	G.text3d(sign,"公园 · 商业街 · 菜园 · 海滩",Vector3(0,.94,.12),19,Color("668067"))
func bench(parent: Node3D,p: Vector3,angle: float) -> void:
	var n:=group(parent,"Bench",p)
	n.rotation.y=angle
	for i in range(4): G.box(n,Vector3(0,.68,-.3+i*.2),Vector3(2.4,.12,.16),pale_wood)
	for i in range(3): G.box(n,Vector3(0,1.0+i*.20,-.5),Vector3(2.4,.13,.12),pale_wood)
	for x in [-.9,.9]: G.box(n,Vector3(x,.32,0),Vector3(.13,.64,.7),wood)
	group(n,"SeatAnchor",Vector3(0,.74,.24))
	group(n,"ExitAnchor",Vector3(0,.1,1.4))
	G.solid_box(n,Vector3(0,.6,0),Vector3(2.4,1,.9))
func roof_material(color: String) -> ShaderMaterial:
	if not roof_materials.has(color):
		var m:=ShaderMaterial.new();m.shader=load("res://assets/shaders/town_roof.gdshader")
		m.set_shader_parameter("tile_color",Color(color));roof_materials[color]=m
	return roof_materials[color]
func building(id: String,title: String,p: Vector3,color: String,roof_color: String,width: float=8,height: float=4.5,depth: float=6) -> Node3D:
	var n:=group(world,id,p)
	G.box(n,Vector3(0,.13,0),Vector3(width+.5,.26,depth+.5),G.mat("cbb897"))
	floor_box(n,Vector3(0,.13,0),Vector3(width+.5,.26,depth+.5))
	G.box(n,Vector3(0,height*.5,0),Vector3(width,height,depth),G.mat(color),"Walls")
	G.solid_box(n,Vector3(0,height*.5,0),Vector3(width,height,depth))
	G.box(n,Vector3(0,height,0),Vector3(width+.65,.26,depth+.6),G.mat(roof_color))
	for side in [-1,1]:
		var roof:=G.box(n,Vector3(side*width*.25,height+.85,0),Vector3(width*.57,.20,depth+.8),roof_material(roof_color))
		roof.rotation.z=-side*.38
	G.box(n,Vector3(0,height+1.65,0),Vector3(.28,.22,depth+.9),G.mat(roof_color))
	for side in [-1,1]:
		for j in range(1,6):
			var seam:=G.box(n,Vector3(side*width*.5*j/6.0,height+1.75-1.65*j/6.0,0),Vector3(.045,.05,depth+.82),G.mat(Color(roof_color).darkened(.12).to_html(false)))
			seam.rotation.z=-side*.38
	for side in [-1,1]:
		var surface:=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.add_vertex(Vector3(-width*.5,height,side*depth*.5))
		surface.add_vertex(Vector3(0,height+1.65,side*depth*.5))
		surface.add_vertex(Vector3(width*.5,height,side*depth*.5))
		surface.generate_normals()
		var facade:=G.mat(color).duplicate() as StandardMaterial3D
		facade.cull_mode=BaseMaterial3D.CULL_DISABLED
		G.mesh(n,surface.commit(),Vector3.ZERO,facade,"Gable")
	# Matching fascia closes both eaves; warm trim and a chimney give the roof weight.
	for side in [-1,1]:
		G.box(n,Vector3(side*(width*.5+.16),height+.05,0),Vector3(.16,.22,depth+.9),G.mat(roof_color))
	G.box(n,Vector3(width*.28,height+1.42,-depth*.25),Vector3(.55,1.5,.6),G.mat("ba8a69"))
	G.box(n,Vector3(width*.28,height+2.2,-depth*.25),Vector3(.7,.16,.75),G.mat("e6c398"))
	for side in [-1,1]:
		G.box(n,Vector3(side*(width*.5-.10),height*.5,depth*.5+.05),Vector3(.18,height,.15),pale_wood)
	G.box(n,Vector3(0,.42,depth*.5+.08),Vector3(width,.17,.16),pale_wood)
	G.ball(n,Vector3(0,height+.65,depth*.5+.035),Vector3(.30,.30,.035),G.mat(roof_color))
	G.capsule(n,Vector3(-.22,height+.65,depth*.5+.08),Vector3(.22,height+.65,depth*.5+.08),.025,pale_wood)
	G.capsule(n,Vector3(0,height+.43,depth*.5+.08),Vector3(0,height+.87,depth*.5+.08),.025,pale_wood)

	G.box(n,Vector3(0,1.25,depth*.5+.05),Vector3(1.30,2.45,.12),G.mat("7f6955"))
	G.ball(n,Vector3(.4,1.2,depth*.5+.14),Vector3.ONE*.055,G.mat("e2c579",.3))
	for x in [-width*.32,width*.32]:
		for y in [1.7,height-1.0]:
			if y>2.1 and height<5: continue
			G.box(n,Vector3(x,y,depth*.5+.05),Vector3(1.5,1.4,.12),wood)
			G.box(n,Vector3(x,y,depth*.5+.12),Vector3(1.28,1.18,.04),G.mat("638c8b",.4,.025),"NightWindow")
			G.box(n,Vector3(x,y,depth*.5+.15),Vector3(.055,1.19,.025),pale_wood)
			G.box(n,Vector3(x,y,depth*.5+.15),Vector3(1.28,.055,.025),pale_wood)
			G.box(n,Vector3(x,y-.78,depth*.5+.25),Vector3(1.8,.18,.5),pale_wood)
			for k in range(4):
				G.ball(n,Vector3(x-.55+k*.36,y-.65,depth*.5+.25),Vector3(.25,.20,.22),G.mat("57935b"))
				flower(n,Vector3(x-.55+k*.36,y-.43,depth*.5+.3),G.mat("f6d17d" if k%2 else "e68b7e"),.11)
	var awning:=G.box(n,Vector3(0,3.1,depth*.5+.65),Vector3(width*.84,.14,1.5),G.mat(roof_color))
	awning.rotation.x=.14
	for stripe in range(8):
		var trim:=G.box(n,Vector3(-width*.37+stripe*width*.105,3.115,depth*.5+.65),Vector3(width*.052,.02,1.52),G.mat("f6e4ba"))
		trim.rotation.x=.14
		G.box(n,Vector3(-width*.37+stripe*width*.105,2.93,depth*.5+1.38),Vector3(width*.052,.3,.07),G.mat("f6e4ba"))
	G.box(n,Vector3(0,3.8,depth*.5+.16),Vector3(width*.68,.72,.16),G.mat("f4e9c9"))
	G.text3d(n,title,Vector3(0,3.82,depth*.5+.26),36,Color("416856"))
	if id.begins_with("Shop_") or id=="Cafe" or id=="Kitchen":
		var board:=group(n,"SidewalkBoard",Vector3(width*.42,0,depth*.5+2.1))
		board.rotation.y=-.22
		G.box(board,Vector3(0,.72,0),Vector3(1.0,1.25,.14),pale_wood)
		G.box(board,Vector3(0,.76,.08),Vector3(.80,1.02,.03),G.mat("365b50"))
		G.text3d(board,"今日菜谱" if id=="Kitchen" else "今日好物",Vector3(0,1.0,.11),17,Color("fff0c9"))
		G.text3d(board,"新鲜烹饪" if id=="Kitchen" else "慢慢逛逛",Vector3(0,.65,.11),14,Color("d8dba7"))
		for x in [-.36,.36]: G.box(board,Vector3(x,.25,0),Vector3(.12,.5,.5),wood)
	group(n,"MerchantAnchor",Vector3(-2,0,depth*.5+1.25))
	group(n,"Entrance",Vector3(0,.1,depth*.5+2.8))
	return n
func build_districts() -> void:
	var shops:=[["Shop_farm","春芽种子商店",Vector3(-18,0,-26),"e5b66e","287cab"],["Shop_tools","木木工具铺",Vector3(-5,0,-26),"e0ad78","b85f39"],["Shop_clothes","云朵服装店",Vector3(8,0,-26),"e9b4a6","318d78"],["Kitchen","海风小厨房",Vector3(21,0,-26),"e8c388","b9614b"],["PostOffice","海岛邮局",Vector3(-31,0,-26),"d4ddc0","5b8d76"]]
	for row in shops:
		var n: Node3D
		if str(row[0]).begins_with("Shop_"): n=preload("res://scripts/city/shop_builder.gd").build_shop(world,str(row[0]).trim_prefix("Shop_"),row[1],row[2],row[3],row[4])
		else: n=building(row[0],row[1],row[2],row[3],row[4])
		if row[0]=="Kitchen": preload("res://scripts/city/kitchen_scenery.gd").build(world,n)
		if str(row[0]).begins_with("Shop_"): n.set_meta("shop",str(row[0]).trim_prefix("Shop_"))
		for side in ([] if str(row[0]).begins_with("Shop_") else [-1,1]):
			G.box(n,Vector3(side*3.0,.35,3.7),Vector3(.9,.7,.8),pale_wood)
			for k in range(4): G.ball(n,Vector3(side*3+sin(k*2)*.25,.84,3.7+cos(k*2)*.22),Vector3(.18,.18,.18),G.mat("e5ab6c" if row[0]=="Shop_farm" else "8eaf71"))
	building("TownHall","慢慢来市民中心",Vector3(0,0,-39),"e5d7ba","688d85",12,6,7)
	for row in range(3):
		for col in range(2):
			if col==0 and row in [0,1]: continue
			var p:=Vector3(-34-col*11,0,-4+row*13)
			var n:=building("Residence%d%d"%[row,col],"海风公寓" if col==0 else "花园小屋",p,"ddc6ab" if row%2==0 else "d5d8bb","8d9f8c" if col==0 else "a88a75",7,7.5 if col==0 else 4.6,7)
			for i in range(3):
				G.box(n,Vector3(-2+i*2,.15,5),Vector3(1.4,.25,1),G.mat("d3c6a8"))
				floor_box(n,Vector3(-2+i*2,.15,5),Vector3(1.4,.25,1))
	preload("res://scripts/city/home_builder.gd").build(world,JSON.parse_string(FileAccess.get_file_as_string("res://data/houses/seabreeze_cottage.json")))
	building("Cafe","海风咖啡",Vector3(-15,0,24),"e4cfad","7fa69a",7,4.1,6)
func build_large_farm() -> void:
	var farm:=group(world,"EastFarm")
	var soil:=ShaderMaterial.new()
	soil.shader=load("res://assets/shaders/farm_soil.gdshader")
	soil.set_shader_parameter("soil_color",Color("a87549"))
	# The field ends before the sidewalk. No coplanar grass/road/soil overlap.
	G.box(farm,Vector3(30,.005,.1),Vector3(20,.08,19.4),soil,"ContinuousEarth")
	floor_box(farm,Vector3(30,-.10,.1),Vector3(20,.29,19.4))
	var dark_soil:=G.mat("805330").duplicate() as StandardMaterial3D
	dark_soil.vertex_color_use_as_albedo=true
	dark_soil.vertex_color_is_srgb=true
	for plot in DB.plots():
		var mound:=soil_mound(rng.randf()*100)
		G.mesh(farm,mound,Vector3(plot.x,.060,plot.z),dark_soil,plot.id)
		var soil_floor:=StaticBody3D.new()
		soil_floor.name="PlotFloor"
		soil_floor.collision_layer=8
		soil_floor.collision_mask=0
		soil_floor.position=Vector3(plot.x,.060,plot.z)
		var soil_shape:=CollisionShape3D.new()
		soil_shape.shape=mound.create_trimesh_shape()
		soil_floor.add_child(soil_shape)
		farm.add_child(soil_floor)
		# A few sunken-looking clods make worked earth read as earth up close.
		for i in range(5):
			var p:=Vector3(plot.x+rng.randf_range(-.78,.78),.095,plot.z+rng.randf_range(-.77,.77))
			G.ball(farm,p,Vector3(.045,.022,.035)*rng.randf_range(.7,1.3),G.mat("92613a"),"SoilClod")
	for z in [-9.6,9.9]:
		for x in range(20,40,2):
			if z>0 and x in [28,30]: continue
			G.cylinder(farm,Vector3(x,.58,z),.075,1.18,pale_wood,.06)
			G.ball(farm,Vector3(x,1.18,z),Vector3(.085,.06,.085),pale_wood)
			for y in [.43,.82]: G.box(farm,Vector3(x+.95,y,z),Vector3(1.9,.12,.12),pale_wood)
	for x in [20.0,40.0]:
		for z in range(-9,9,2):
			G.cylinder(farm,Vector3(x,.58,z),.075,1.18,pale_wood,.06)
			for y in [.43,.82]: G.box(farm,Vector3(x,y,z+.94),Vector3(.12,.12,1.88),pale_wood)
	# Loose flat stepping stones lead in from the front gate.
	for z in [8.4,9.25,10.10]:
		G.ball(farm,Vector3(29,.075,z),Vector3(.57,.055,.36),G.mat("b8aa86"),"GardenStep")
	building("FarmBarn","东边的大菜园",Vector3(35,0,-17),"d6ac71","986449",8,4.5,5)
	var sign:=group(farm,"GardenSign",Vector3(26.3,0,9.95))
	G.cylinder(sign,Vector3(0,.55,0),.07,1.1,wood)
	G.box(sign,Vector3(0,1.15,0),Vector3(2.3,.72,.15),pale_wood)
	G.text3d(sign,"小苗慢慢长",Vector3(0,1.17,.09),27,Color("42654a"))
	for i in range(3):
		G.cylinder(farm,Vector3(41+i*.65,.38,-10),.27,.74,wood)
		G.cylinder(farm,Vector3(41+i*.65,.76,-10),.25,.05,G.mat("6f9a99"))
	var shed:=group(farm,"PottingCorner",Vector3(21.8,0,-8.0))
	G.box(shed,Vector3(0,.76,0),Vector3(2.2,.15,.85),pale_wood)
	for x in [-.85,.85]:
		for z in [-.28,.28]: G.box(shed,Vector3(x,.36,z),Vector3(.09,.72,.09),wood)
	for i in range(3):
		G.cylinder(shed,Vector3(-.65+i*.55,.98,0),.16,.30,G.mat("b57955"),.20)
		G.cylinder(shed,Vector3(-.65+i*.55,1.14,0),.17,.03,G.mat("65472d"))
		for k in range(3): G.ball(shed,Vector3(-.65+i*.55+sin(k*2)*.07,1.25,cos(k*2)*.07),Vector3(.12,.12,.065),G.mat("6b9a54"))
	var scarecrow:=group(farm,"Scarecrow",Vector3(39.1,0,7.8))
	G.cylinder(scarecrow,Vector3(0,.85,0),.055,1.7,wood)
	G.capsule(scarecrow,Vector3(-.55,1.30,0),Vector3(.55,1.30,0),.055,wood)
	G.ball(scarecrow,Vector3(0,1.75,0),Vector3.ONE*.27,G.mat("d7bb7e"))
	G.cylinder(scarecrow,Vector3(0,1.98,0),.43,.06,G.mat("bd9459"))
	G.cylinder(scarecrow,Vector3(0,2.08,0),.24,.20,G.mat("bd9459"),.19)
	G.box(scarecrow,Vector3(0,1.35,0),Vector3(.48,.48,.20),G.mat("8da084"))

func soil_mound(seed_: float) -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var divisions:=20
	for z in range(divisions+1):
		for x in range(divisions+1):
			var u:=float(x)/divisions
			var v:=float(z)/divisions
			var edge:=smoothstep(0,.15,minf(minf(u,1-u),minf(v,1-v)))
			var ridge: float=.035+.025*cos(u*TAU*4)
			var height: float=edge*ridge+sin(u*41+seed_)*sin(v*37+seed_)*.004*edge
			var corner: float=1.0-smoothstep(.75,1.0,absf(u-.5)*2)*smoothstep(.75,1.0,absf(v-.5)*2)*.07
			var border_noise: float=sin(u*41+v*27+seed_)*.018
			st.set_color(Color.WHITE*(.94+sin(u*TAU*4)*.04+sin(v*24+seed_)*.02))
			st.set_uv(Vector2(u,v))
			st.add_vertex(Vector3((u-.5)*1.83*corner+border_noise*(1-edge),height,(v-.5)*1.90*corner+border_noise*(1-edge)))
	for z in range(divisions):
		for x in range(divisions):
			var i:=z*(divisions+1)+x
			for index in [i,i+1,i+divisions+1,i+1,i+divisions+2,i+divisions+1]: st.add_index(index)
	st.generate_normals()
	return st.commit()

func build_beach() -> void:
	var beach:=group(world,"SouthBeach")
	var sand:=ShaderMaterial.new()
	sand.shader=load("res://assets/shaders/beach_sand.gdshader")
	world.get_node("Island/SouthBeach").material_override=sand
	G.mesh(beach,shore_mesh(false),Vector3.ZERO,sand,"SlopingSandCoast")
	var foam:=ShaderMaterial.new()
	foam.shader=load("res://assets/shaders/shore_foam.gdshader")
	var surf:=G.mesh(beach,shore_mesh(true),Vector3.ZERO,foam,"RollingShoreFoam")
	surf.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	floor_box(beach,Vector3(-.4,-.10,32),Vector3(24,.41,3.0))
	floor_box(beach,Vector3(13,-.10,37.95),Vector3(2.8,.41,12.55))
	for i in range(30): G.box(beach,Vector3(-12+i*.8,.055,32),Vector3(.74,.10,3.0),pale_wood)
	for i in range(18): G.box(beach,Vector3(13,.055,32+i*.70),Vector3(2.8,.10,.65),pale_wood)
	for z in [33.0,36.5,40.0,43.5]:
		for x in [11.4,14.6]:
			G.cylinder(beach,Vector3(x,.6,z),.11,1.2,wood,.09)
			G.ball(beach,Vector3(x,1.23,z),Vector3.ONE*.13,pale_wood)
			if z<43:
				G.capsule(beach,Vector3(x,1.0,z),Vector3(x,.85,z+1.75),.035,G.mat("c9b88d"))
				G.capsule(beach,Vector3(x,.85,z+1.75),Vector3(x,1.0,z+3.5),.035,G.mat("c9b88d"))
	for index in range(3):
		var x: float=[-12,2,26][index]
		var n:=group(beach,"Parasol",Vector3(x,0,36+sin(x)*1.4))
		G.cylinder(n,Vector3(0,1.32,0),.045,2.65,wood)
		var fabric:=G.mat(["de927d","7caeae","dbbd73"][index])
		fabric.cull_mode=BaseMaterial3D.CULL_DISABLED
		G.mesh(n,parasol_mesh(),Vector3(0,2.65,0),fabric,"ScallopedCanopy")
		G.ball(n,Vector3(0,2.83,0),Vector3.ONE*.10,pale_wood)
		for side in [-1,1]:
			var chair:=group(n,"LoungeChair",Vector3(side*1.55,0,.7))
			chair.rotation.y=side*-.15
			for k in range(7): G.box(chair,Vector3(0,.33,-.55+k*.19),Vector3(.83,.09,.15),pale_wood)
			for k in range(4):
				var slat:=G.box(chair,Vector3(0,.42+k*.14,-.70-k*.10),Vector3(.83,.10,.15),pale_wood)
				slat.rotation.x=.45
			for leg_x in [-.34,.34]:
				for leg_z in [-.48,.53]: G.box(chair,Vector3(leg_x,.16,leg_z),Vector3(.08,.32,.10),wood)
			G.box(chair,Vector3(0,.41,.18),Vector3(.74,.05,1.1),fabric)
		G.cylinder(n,Vector3(0,.55,1.5),.42,.10,pale_wood)
		G.cylinder(n,Vector3(0,.28,1.5),.07,.55,wood)
		G.cylinder(n,Vector3(.15,.69,1.5),.07,.20,G.mat("e8c45f"),.09)
		G.capsule(n,Vector3(.15,.78,1.5),Vector3(.18,.94,1.5),.009,G.mat("fff3cd"))
	# Small seaside objects stay off the main walking route.
	for i in range(38):
		var p:=Vector3(rng.randf_range(-30,32),.065,rng.randf_range(35,43))
		if i%4==0:
			for arm in range(5):
				var a:=arm*TAU/5
				G.capsule(beach,p,p+Vector3(cos(a)*.17,.01,sin(a)*.17),.04,G.mat("d88f76"),"Starfish")
		else:
			var shell:=G.ball(beach,p,Vector3(.16,.07,.12),G.mat("e6b79c" if i%2 else "f2e3c6"),"Shell")
			shell.rotation.y=rng.randf()*TAU
	for p in [Vector3(-23,0,33),Vector3(30,0,32),Vector3(-30,0,36),Vector3(34,0,37)]:
		for i in range(9):
			var a:=rng.randf()*TAU
			G.capsule(beach,p+Vector3(cos(a)*.4,.02,sin(a)*.4),p+Vector3(cos(a)*.65,rng.randf_range(.35,.72),sin(a)*.65),.02,G.mat("9ca873"))
	var castle:=group(beach,"SandCastle",Vector3(21,0,39))
	G.cylinder(castle,Vector3(0,.22,0),.55,.44,G.mat("d9bc84"))
	for i in range(4):
		var a:=i*TAU/4
		G.cylinder(castle,Vector3(cos(a)*.45,.40,sin(a)*.45),.15,.8,G.mat("dfc58e"),.13)
	G.capsule(castle,Vector3(0,.5,0),Vector3(0,1.18,0),.018,wood)
	G.box(castle,Vector3(.18,1.10,0),Vector3(.35,.20,.025),G.mat("d98d78"))
	var ring:=TorusMesh.new()
	ring.inner_radius=.34
	ring.outer_radius=.53
	ring.rings=32
	ring.ring_segments=10
	var lifesaver:=G.mesh(beach,ring,Vector3(14.6,.85,33.12),G.mat("eac5a1"),"Lifebuoy")
	lifesaver.rotation.x=PI*.5
	G.capsule(beach,Vector3(14.6,1.20,33.12),Vector3(14.6,1.38,33.12),.018,G.mat("c9b88d"))
	bench(beach,Vector3(4,0,29),0)

func fountain_jets() -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for arc in range(8):
		var angle:=arc*TAU/8
		var outward:=Vector3(cos(angle),0,sin(angle))
		var start:=outward*.16+Vector3(0,1.98,0)
		var end:=outward*2.12+Vector3(0,.49,0)
		var offset:=arc*21*7
		for step in range(21):
			var t:=float(step)/20
			var center:=start.lerp(end,t)+Vector3(0,sin(t*PI)*.52,0)
			var tangent: Vector3=(end-start+Vector3(0,cos(t*PI)*PI*.52,0)).normalized()
			var right:=tangent.cross(Vector3.UP).normalized()
			var up:=right.cross(tangent).normalized()
			for side in range(7):
				var a:=side*TAU/6
				st.set_uv(Vector2(float(side)/6,t))
				st.add_vertex(center+(cos(a)*right+sin(a)*up)*lerpf(.036,.024,t))
		for step in range(20):
			for side in range(6):
				var i:=offset+step*7+side
				for index in [i,i+7,i+1,i+1,i+7,i+8]: st.add_index(index)
	st.generate_normals()
	return st.commit()

func beach_top_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.add_vertex(Vector3.ZERO)
	for i in range(65):
		var a:=i*TAU/64
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(cos(a)*38,0,sin(a)*15))
	for i in range(64):
		for index in [0,i+1,i+2]: st.add_index(index)
	return st.commit()

func shore_mesh(foam: bool) -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(9):
		var v:=float(row)/8
		for col in range(65):
			var u:=float(col)/64
			var angle:=lerpf(.14*PI,.86*PI,u)
			var radius:=lerpf(58.0,63.0,v) if foam else lerpf(51.0,61.2,v)
			var y: float=-1.425 if foam else lerpf(.01,-1.58,smoothstep(.0,1.0,v))
			st.set_uv(Vector2(u,v))
			st.add_vertex(Vector3(cos(angle)*radius,y,sin(angle)*radius*.88))
	for row in range(8):
		for col in range(64):
			var i:=row*65+col
			for index in [i,i+65,i+1,i+1,i+65,i+66]: st.add_index(index)
	st.generate_normals()
	return st.commit()

func parasol_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(5):
		var r:=float(ring)/4
		for side in range(49):
			var angle:=side*TAU/48
			var radius:=r*1.85
			var scallop: float=.09*cos(angle*8)*pow(r,5)
			st.set_uv(Vector2(float(side)/48,r))
			st.add_vertex(Vector3(cos(angle)*radius,.13-r*r*.56+scallop,sin(angle)*radius))
	for ring in range(4):
		for side in range(48):
			var i:=ring*49+side
			for index in [i,i+49,i+1,i+1,i+49,i+50]: st.add_index(index)
	st.generate_normals()
	return st.commit()

func city_clear(p: Vector3) -> bool:
	if Vector2(p.x,p.z/.88).length()>51 or p.z>29: return false
	if absf(p.x)<5 or absf(p.z-13)<4 or absf(p.z+13)<4 or absf(p.z+26)<4 or absf(p.z+19)<3: return false
	if absf(p.x+25)<3.5 or absf(p.x-17)<3.5: return false
	if absf(p.x)<12 and absf(p.z)<12: return false
	if p.x>19 and p.x<43 and p.z>-21 and p.z<15: return false
	if p.x<-28 and p.z>-10 and p.z<29: return false
	if p.z<-20 and absf(p.x)<36: return false
	if p.x>-20 and p.x<-10 and p.z>19 and p.z<29: return false
	return true
func build_city_nature() -> void:
	for i in range(130):
		var p:=Vector3(rng.randf_range(-49,49),0,rng.randf_range(-40,28))
		if city_clear(p): tree(p,rng.randf_range(4.4,6.2),"4f9857" if i%3 else "79b85c")
	for p in [Vector3(-12,0,-7),Vector3(12,0,-7),Vector3(-12,0,6),Vector3(12,0,6),Vector3(-19,0,16),Vector3(11,0,17)]: tree(p,5.0,"64a85d")
	var plants:=group(world,"Meadow")
	preload("res://scripts/city/town_gardens.gd").build(self)

func tree(pos: Vector3, height: float, color: String = "64a85d") -> void:
	var t:=group(world,"Tree%02d"%tree_index,pos)
	tree_index+=1
	var archetype:=rng.randi_range(0,4)
	if preload("res://scripts/city/scenery_polish.gd").priority(pos)>0: archetype=3
	height*=rng.randf_range(.88,1.12)
	var trunk_height:=height*rng.randf_range(.48,.60)
	var trunk_radius:=rng.randf_range(.25,.38)
	var bark:=G.mat(["ad7c4d","b38a55","94714d","be925e"][rng.randi_range(0,3)])
	var lean:=Vector3(rng.randf_range(-.15,.15),0,rng.randf_range(-.15,.15))
	G.capsule(t,Vector3(0,.08,0),Vector3(lean.x,trunk_height,lean.z),trunk_radius,bark,"Trunk")
	G.solid_cylinder(t,Vector3(0,trunk_height*.5,0),trunk_radius,trunk_height)
	for i in range(rng.randi_range(3,5)):
		var a:=rng.randf()*TAU
		G.capsule(t,Vector3(cos(a)*rng.randf_range(.4,.7),.06,sin(a)*.55),Vector3(0,.55,0),trunk_radius*.42,bark)
	var crown:=group(t,"Crown",Vector3(lean.x,height*.74,lean.z))
	var foliage:=ShaderMaterial.new()
	foliage.shader=load("res://assets/shaders/occlusion_fade.gdshader")
	foliage.set_shader_parameter("vertex_tint",true)
	var leaf_color:=Color(color).lerp(Color(["3d8057","76a553","5a9950","83ad5a"][rng.randi_range(0,3)]),.35)
	var seed_:=rng.randf()*100
	if archetype==4:
		crown.position.y=height*.46
		for tier in range(4):
			var u:=float(tier)/3
			var bough:=G.mesh(crown,canopy_mesh(seed_+tier,leaf_color,true),Vector3(rng.randf_range(-.08,.08),u*height*.40,0),foliage,"EvergreenCrown")
			bough.scale=Vector3(lerpf(height*.31,.35,u),height*.27,lerpf(height*.31,.35,u))
	else:
		var width:=height*rng.randf_range(.29,.35)*(1.10 if archetype==0 else .95)
		var tall:=height*(.34 if archetype==2 else rng.randf_range(.25,.30))
		var body:=G.mesh(crown,canopy_mesh(seed_,leaf_color),Vector3.ZERO,foliage,"SoftCrown")
		body.scale=Vector3(width,tall,width*rng.randf_range(.88,1.06))
		body.rotation.y=rng.randf()*TAU
		for i in range(3):
			var a:=i*TAU/3+seed_
			G.capsule(t,Vector3(0,trunk_height*.88,0),crown.position+Vector3(cos(a)*width*.25,-tall*.05,sin(a)*width*.25),.10,bark,"Branch")
		if archetype==3:
			var fruit_material:=G.mat(["eaa34a","dc6655","c8cb6b"][rng.randi_range(0,2)])
			for i in range(rng.randi_range(3,5)):
				var a:=rng.randf()*TAU
				var point:=Vector3(cos(a)*width*.86,-tall*.35,sin(a)*width*.86)
				G.ball(crown,point,Vector3.ONE*rng.randf_range(.17,.22),fruit_material,"Fruit")
				G.capsule(crown,point,point+Vector3(0,.20,0),.025,bark)

func canopy_mesh(seed_: float, color: Color, evergreen: bool=false) -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings:=20
	var segments:=36
	for ring in range(rings+1):
		var v:=float(ring)/rings
		var theta:=v*PI
		for segment in range(segments+1):
			var phi:=float(segment)/segments*TAU
			var lobes: float=1+.075*sin(phi*3+seed_)*sin(theta)*sin(theta)+.045*cos(phi*5-seed_)*sin(theta*2)
			var p:=Vector3(cos(phi)*sin(theta)*lobes,cos(theta),sin(phi)*sin(theta)*lobes)
			if evergreen:
				var radius:=pow(v,.8)*(1+.035*sin(phi*7+seed_))
				p=Vector3(cos(phi)*radius,.7-v,sin(phi)*radius)
			var tone: float=.94+(.5+.5*cos(theta))*.08+sin(phi*4+seed_)*sin(theta*3)*.018
			st.set_color(color*tone)
			st.set_uv(Vector2(float(segment)/segments,v))
			st.add_vertex(p)
	for ring in range(rings):
		for segment in range(segments):
			var i:=ring*(segments+1)+segment
			for index in [i,i+segments+1,i+1,i+1,i+segments+1,i+segments+2]: st.add_index(index)
	if evergreen:
		st.set_color(color*.90)
		st.add_vertex(Vector3(0,-.3,0))
		var center: int=(rings+1)*(segments+1)
		for segment in range(segments):
			for index in [rings*(segments+1)+segment,center,rings*(segments+1)+segment+1]: st.add_index(index)
	st.generate_normals()
	return st.commit()

func optimize_static_geometry() -> void:
	var groups: Dictionary={}
	var detail_groups: Dictionary={}
	var nodes:=world.find_children("*","MeshInstance3D",true,false)
	for n in nodes:
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

func own_children(n: Node,scene: Node) -> void:
	for child in n.get_children():
		child.owner=scene
		# Keep reusable house geometry in its compressed resource, rather than
		# flattening the complete template into every generated city map.
		if child.scene_file_path!="": continue
		own_children(child,scene)
