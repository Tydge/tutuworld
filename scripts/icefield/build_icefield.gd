extends SceneTree
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
const L=preload("res://scripts/icefield/icefield_layout.gd")
const Props=preload("res://scripts/icefield/winter_props.gd")
const DB=preload("res://scripts/services/game_data.gd")
var world: Node3D
var rng:=RandomNumberGenerator.new()
var alpine: PackedByteArray
var prototypes: Dictionary={}
func _initialize() -> void:call_deferred("build")
func build() -> void:
	if DisplayServer.get_name()=="headless":push_error("Build with graphical GL to preserve instance buffers.");quit(1);return
	rng.seed=941803
	alpine=FileAccess.get_file_as_bytes("res://assets/terrain/winter/alpine_relief.r16")
	world=Node3D.new();world.name="FrostlightIsland";root.add_child(world)
	world.set_meta("scenery_polished",true);world.set_meta("groundcover_revision",3);world.set_meta("terrain_material_revision",1)
	world.set_meta("winter_revision",1);world.set_meta("playable_bounds",L.RADII*2.)
	build_environment();build_terrain();build_mountains();build_town();build_forest();build_harbor();build_dressing()
	preload("res://scripts/city/water_materials.gd").apply(world)
	for id in prototypes:
		var n: Node3D=prototypes[id];own(n,n);var asset:=PackedScene.new();asset.pack(n)
		ResourceSaver.save(asset,"res://scenes/winter/"+id+".scn",ResourceSaver.FLAG_COMPRESS)
		n.free()
	own(world,world)
	var packed:=PackedScene.new();var error:=packed.pack(world)
	if error==OK:
		await process_frame;await RenderingServer.frame_post_draw
		error=ResourceSaver.save(packed,"res://scenes/icefield_map.scn",ResourceSaver.FLAG_COMPRESS)
	print("ICEFIELD_BUILT result=",error," trees=",world.get_meta("snow_pine_count",0)," resources=",DB.resources("icefield").size())
	world.free();packed=null;await process_frame;await process_frame;quit(0 if error==OK else 1)
func own(n: Node,owner_: Node) -> void:
	for child in n.get_children():child.owner=owner_;own(child,owner_)
func group(parent: Node3D,id: String,p:=Vector3.ZERO) -> Node3D:return Props.group(parent,id,p)
func place(id: String,p: Vector3,angle: float=0.) -> Node3D:
	if not prototypes.has(id):
		match id:
			"chalet":prototypes[id]=Props.chalet()
			"chapel":prototypes[id]=Props.chalet(true)
			"snow_pine":prototypes[id]=Props.pine()
			"snowman":prototypes[id]=Props.snowman()
			"sled":prototypes[id]=Props.sled()
			"snow_bench":prototypes[id]=Props.bench()
			_:prototypes[id]=preload("res://scripts/icefield/winter_decor.gd").make(id)
	var n: Node3D=prototypes[id].duplicate();n.position=p;n.rotation.y=angle;world.add_child(n);return n
func at(x: float,z: float) -> Vector3:return Vector3(x,L.height_at(x,z),z)
func build_environment() -> void:
	var atmosphere:=WorldEnvironment.new();atmosphere.name="Atmosphere"
	var env:=Environment.new();env.background_mode=Environment.BG_SKY
	env.sky=Sky.new();env.sky.radiance_size=Sky.RADIANCE_SIZE_256;env.sky.process_mode=Sky.PROCESS_MODE_INCREMENTAL
	var sky:=ShaderMaterial.new();sky.shader=load("res://assets/shaders/polar_sky.gdshader");sky.set_shader_parameter("mountain_panorama",load("res://assets/terrain/winter/distant_alpine_v1.png"));env.sky.sky_material=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_SKY;env.ambient_light_energy=.48
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.tonemap_exposure=1.0
	env.fog_enabled=true;env.fog_density=.00085;env.fog_sky_affect=.25;env.fog_light_color=Color("9fbad4")
	env.glow_enabled=true;env.glow_intensity=.28;env.glow_bloom=.035
	env.ssao_enabled=true;env.ssao_radius=.65;env.ssao_intensity=.7
	atmosphere.environment=env;world.add_child(atmosphere)
	var sun:=DirectionalLight3D.new();sun.name="Sun";sun.rotation_degrees=Vector3(-18,-65,0);sun.light_color=Color("ffe1b0");sun.light_energy=1.15;sun.shadow_enabled=true
	sun.shadow_bias=.10;sun.shadow_normal_bias=.65;sun.directional_shadow_max_distance=145.;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS;sun.directional_shadow_split_1=.24;sun.directional_shadow_blend_splits=true;sun.directional_shadow_fade_start=.8;world.add_child(sun)
	var island:=group(world,"Island");var sea:=ShaderMaterial.new();sea.shader=load("res://assets/shaders/polar_ocean.gdshader");sea.set_shader_parameter("sea_color",Color("284b69"));island.set_meta("sea_material",sea)
	var plane:=PlaneMesh.new();plane.size=Vector2(3000,3000)
	var ocean:=G.mesh(island,plane,Vector3(0,L.SEA_LEVEL,0),sea,"PolarSea");ocean.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	group(world,"Streetlights");group(world,"CentralPark")
func build_terrain() -> void:
	var terrain:=group(world,"SnowAndIceTerrain")
	var snow: ShaderMaterial=Props.mat("snow").duplicate();snow.set_shader_parameter("town_paths",true);snow.set_shader_parameter("coastal_ridges",true)
	var ice:=ShaderMaterial.new();ice.shader=load("res://assets/shaders/polar_ice.gdshader");world.set_meta("ice_material",ice)
	for cz in range(-176,176,24):
		for cx in range(-192,192,24):
			var surfaces: Array=[SurfaceTool.new(),SurfaceTool.new()];var counts: Array=[0,0]
			for st in surfaces:st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for z in range(cz,cz+24,2):
				for x in range(cx,cx+24,2):
					if L.ellipse(x+1,z+1)>1.075:continue
					for triangle in [[Vector2(x,z),Vector2(x+2,z),Vector2(x,z+2)],[Vector2(x+2,z),Vector2(x+2,z+2),Vector2(x,z+2)]]:
						var mid: Vector2=(triangle[0]+triangle[1]+triangle[2])/3.
						var kind:=int(mid.x>L.shore_x(mid.y)+5. and L.ellipse(mid.x,mid.y)<.915)
						for p: Vector2 in triangle:
							surfaces[kind].set_normal(L.normal_at(p.x,p.y));surfaces[kind].set_uv(p*.1);surfaces[kind].add_vertex(Vector3(p.x-cx,L.height_at(p.x,p.y),p.y-cz));counts[kind]+=1
			for k in range(2):
				if counts[k]==0:continue
				surfaces[k].index();surfaces[k].generate_tangents()
				var mesh: ArrayMesh=surfaces[k].commit();var n:=G.mesh(terrain,mesh,Vector3(cx,0,cz),ice if k==1 else snow,"BlueIce" if k==1 else "PowderSnow")
				var body:=StaticBody3D.new();body.collision_layer=8;body.collision_mask=0;var shape:=CollisionShape3D.new();shape.shape=mesh.create_trimesh_shape();body.add_child(shape);n.add_child(body)
func mountain_height(r: float,a: float) -> float:
	var x:=cos(a)*r;var z:=sin(a)*r*.89
	# True Alpine drainage/ridges replace synthetic cones. The playable island
	# remains fictional: only the background samples this cropped elevation grid.
	var u:=clampf(256.+z*.175,0.,510.);var v:=clampf(256.-x*.175,0.,510.)
	var ix:=floori(u);var iz:=floori(v);var fx:=u-ix;var fz:=v-iz
	var top:=lerpf(alpine.decode_u16((iz*512+ix)*2),alpine.decode_u16((iz*512+ix+1)*2),fx)
	var bottom:=lerpf(alpine.decode_u16(((iz+1)*512+ix)*2),alpine.decode_u16(((iz+1)*512+ix+1)*2),fx)
	var meters:=lerpf(top,bottom,fz)
	var envelope:=smoothstep(185.,365.,r)*(1.-smoothstep(1310.,1440.,r))
	var peak:=maxf(0.,meters-1450.)*.010*envelope
	var ramp:=smoothstep(177.,310.,r)
	var presence:=1.-smoothstep(.45,.82,sin(a))
	return lerpf(-4.,peak+L.height_at(cos(a)*177.,sin(a)*157.)*(1.-ramp),presence)
func build_mountains() -> void:
	var mountains:=group(world,"GlacialMountainRange");var m: ShaderMaterial=Props.mat("snow").duplicate();m.set_shader_parameter("mountains",true)
	for sector in range(24):
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);var count_:=0
		for slice in range(sector*16,sector*16+16):
			var middle: float=(slice+.5)*TAU/384.
			if sin(middle)>.86:continue
			for band in range(96):
				for c in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
					var a: float=(slice+c.x)*TAU/384.;var r: float=177.+(band+c.y)*12.5
					var p:=Vector3(cos(a)*r,mountain_height(r,a),sin(a)*r*.89)
					st.set_uv(Vector2(p.x,p.z)*.01);st.add_vertex(p);count_+=1
		if count_>0:
			st.index();st.generate_normals();st.generate_tangents();var mesh:=G.mesh(mountains,st.commit(),Vector3.ZERO,m,"SnowRidge");mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func build_town() -> void:
	var furnishings:=preload("res://scripts/icefield/winter_furnishing.gd").new()
	for b in L.BUILDINGS:
		var building: Node3D
		if b.kind=="shop":
			building=preload("res://scripts/city/shop_builder.gd").new().construct_shop(world,b.id,b.title,at(b.x,b.z),b.wall,"4d626b",true)
		else:
			building=place(b.kind,at(b.x,b.z))
			building.name="Room_"+b.id
			furnishings.arrange(building,b.room)
		building.set_meta("winter_asset_id",b.kind if b.kind!="shop" else "shop_"+b.id)
		if b.kind!="shop":
			var sign:=G.text3d(building,b.title,Vector3(0,3.79,5.78),34,Color("ffefc9"))
			sign.name="HouseName";sign.visibility_range_end=45.
		building.set_meta("placement_id",b.id)
	build_festival_tree()
	var lamps:=preload("res://scripts/city/lamp_builder.gd").new();lamps.lamps=world.get_node("Streetlights")
	for p in [Vector2(-89,99),Vector2(-72,76),Vector2(-86,49),Vector2(-71,27),Vector2(-38,12),Vector2(-21,15),Vector2(-112,7),Vector2(-103,-13),Vector2(-80,-13),Vector2(-57,-13),Vector2(-72,-49),Vector2(-85,-83)]:lamps.lamp(at(p.x,p.y))
func build_festival_tree() -> void:
	var tree:=place("snow_pine",at(-63,24));tree.name="FestivalFir";tree.scale=Vector3.ONE*1.55
	var lights:=group(tree,"FairyLights");var gold: Material=Props.mat("gold")
	for i in range(150):
		var u: float=i/149.;var a: float=u*TAU*8.;var r: float=2.7*(1.-u*.88)
		G.ball(lights,Vector3(cos(a)*r,1.5+u*6.6,sin(a)*r),Vector3.ONE*.045,gold)
	for i in range(28):
		var a: float=i*2.399;var y: float=2.0+(i%7)*.72;var r: float=2.5*(1.-(y-1.5)/8.)
		G.ball(lights,Vector3(cos(a)*r,y,sin(a)*r),Vector3.ONE*.11,Props.mat("b34f4b" if i%2 else "gold"))
	# A dimensional eight-point star crowns the square.
	for a in [0.,PI*.25,PI*.5,PI*.75]:
		var ray:=G.box(lights,Vector3(0,9.15,0),Vector3(.075,1.0,.075),gold);ray.rotation.z=a
	Props.merge(lights)
	var glow:=OmniLight3D.new();glow.name="FestivalGlow";glow.position=Vector3(0,4,0);glow.light_color=Color("ffd292");glow.light_energy=1.7;glow.omni_range=12.;glow.shadow_enabled=false;tree.add_child(glow)
	for p in [Vector2(-71,33),Vector2(-54,32),Vector2(-64,39),Vector2(-35,9)]:
		var bench:=place("snow_bench",at(p.x,p.y));bench.reparent(world.get_node("CentralPark"),true)
func nature_clear(p: Vector3) -> bool:
	if not L.Plots.clear(Vector2(p.x,p.z),2.5):return false
	for stamp in preload("res://scripts/icefield/snow_trail.gd").STAMPS.values():
		if Vector2(p.x,p.z).distance_to(stamp.place)<4.:return false
	if not L.can_walk(p) or p.x>L.shore_x(p.z)-8. or L.path_distance(p.x,p.z)<4.5:return false
	for fire: Vector2 in L.CAMPFIRES:
		if Vector2(p.x,p.z).distance_to(fire)<8.5:return false
	if p.x> -125. and p.x< -39. and p.z> -23. and p.z<9.:return false
	for b in L.BUILDINGS:
		if absf(p.x-b.x)<10. and absf(p.z-b.z)<10.:return false
	if Vector2(p.x+63.,p.z-25.).length()<17. or p.distance_to(Vector3(-104,0,119))<12.:return false
	for resource in DB.resources("icefield"):
		if Vector2(p.x-resource.x,p.z-resource.z).length()<3.2:return false
	return true
func build_forest() -> void:
	if not prototypes.has("snow_pine"):prototypes.snow_pine=Props.pine()
	var prototype: Node3D=prototypes.snow_pine
	var patches: Dictionary={};var tree_count:=0
	for z in range(-144,143,8):
		for x in range(-166,-15,8):
			var p:=at(x+rng.randf_range(-2.9,2.9),z+rng.randf_range(-2.9,2.9))
			if not nature_clear(p) or rng.randf()<.44:continue
			var key:=Vector2i(floori(p.x/32.),floori(p.z/32.))
			if not patches.has(key):patches[key]=[]
			var scale_:=rng.randf_range(.72,1.48);patches[key].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_),p));tree_count+=1
			P.cylinder(world,"SnowPineTrunk",p+Vector3(0,2.*scale_,0),.27*scale_,4.*scale_)
	var forest:=group(world,"SnowPineGroves")
	for key in patches:
		var transforms: Array=patches[key];var origin:=Vector3((key.x+.5)*32.,0,(key.y+.5)*32.)
		for source: MeshInstance3D in prototype.find_children("*","MeshInstance3D",true,false):
			var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=source.mesh;mm.instance_count=transforms.size()
			for i in range(mm.instance_count):var t: Transform3D=transforms[i];t.origin-=origin;mm.set_instance_transform(i,t)
			var draw:=MultiMeshInstance3D.new();draw.name="PinePatch";draw.position=origin;draw.multimesh=mm;draw.material_override=source.material_override;draw.cast_shadow=source.cast_shadow;draw.visibility_range_end=260.;draw.visibility_range_end_margin=0.;forest.add_child(draw)
	world.set_meta("snow_pine_count",tree_count)
	# A second, shadowless belt gives the mountains real forested foothills.
	var distant: Array[Transform3D]=[]
	for i in range(470):
		var a:=rng.randf_range(PI*.92,TAU+PI*.15);var r:=rng.randf_range(200.,390.)
		if sin(a)>.55:continue
		var p:=Vector3(cos(a)*r,mountain_height(r,a),sin(a)*r*.89)
		var s:=rng.randf_range(.67,1.2);distant.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*s),p))
	for source: MeshInstance3D in prototype.find_children("*","MeshInstance3D",true,false):
		if source.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:continue
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=source.mesh;mm.instance_count=distant.size()
		for i in range(distant.size()):mm.set_instance_transform(i,distant[i])
		var draw:=MultiMeshInstance3D.new();draw.name="DistantSnowForest";draw.multimesh=mm;draw.material_override=source.material_override;draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;forest.add_child(draw)
	world.set_meta("foothill_tree_count",distant.size())
func build_harbor() -> void:
	var dock:=group(world,"WinterHarbor");dock.set_meta("buildable_reference",true);dock.set_meta("winter_asset_id","winter_pier")
	for i in range(35):
		var x: float=-108.+i*.4
		G.box(dock,Vector3(x,L.DOCK_HEIGHT-.09,121),Vector3(.38,.18,3.9),Props.mat("wood"))
	var floor_:=G.solid_box(dock,Vector3(-101,L.DOCK_HEIGHT-.13,121),Vector3(14.,.26,3.9));floor_.collision_layer=8;floor_.collision_mask=0
	for x in [-106.,-102.,-98.,-94.5]:
		for side in [-1,1]:
			G.cylinder(dock,Vector3(x,.25,121+side*2.1),.14,3.3,Props.mat("darkwood"));G.ball(dock,Vector3(x,1.92,121+side*2.1),Vector3(.22,.12,.22),Props.mat("snow"))
	Props.merge(dock)
func build_dressing() -> void:
	for p in [Vector2(-53,39),Vector2(-108,47),Vector2(-44,-13)]:place("snowman",at(p.x,p.y),rng.randf_range(-.5,.5))
	for p in [Vector2(-106,70),Vector2(-112,25),Vector2(-54,59)]:place("sled",at(p.x,p.y),rng.randf()*TAU)
	var stones:=group(world,"FrostBoulders");stones.set_meta("buildable_reference",true);stones.set_meta("winter_asset_id","frost_boulder_cluster")
	for i in range(75):
		var z:=rng.randf_range(-135.,130.);var x:=L.shore_x(z)+rng.randf_range(-4.,5.)
		if absf(z-16.)<6.:continue
		var p:=at(x,z);var size_:=Vector3(rng.randf_range(.35,1.15),rng.randf_range(.25,.55),rng.randf_range(.4,.95))
		G.ball(stones,p,size_,Props.mat("697d88"));G.ball(stones,p+Vector3(0,size_.y*.57,0),size_*Vector3(.95,.47,.95),Props.mat("snow"))
	Props.merge(stones)
	# Thin snow rafts along the southern sea, outside the walkable island.
	var floes:=group(world,"SeaIceFloes");floes.set_meta("buildable_reference",true);floes.set_meta("winter_asset_id","sea_ice_floe")
	for i in range(35):
		var p:=Vector3(rng.randf_range(-90.,180.),-.42,rng.randf_range(162.,243.));var size_:=Vector3(rng.randf_range(1.,4.5),.15,rng.randf_range(1.,3.))
		G.ball(floes,p,size_,Props.mat("snow"))
	Props.merge(floes)
	for p: Vector2 in L.CAMPFIRES:
		place("campfire",at(p.x,p.y));place("log_stack",at(p.x-4.2,p.y-3.1),.4)
		for side in [-1,1]:
			var bench:=place("snow_bench",at(p.x+side*2.6,p.y),side*PI*.5);bench.reparent(world.get_node("CentralPark"),true)
	for b in L.BUILDINGS:
		if b.kind=="shop":continue
		place("log_stack",at(b.x+6.4,b.z+1.7))
		for side in [-1,1]:place("winter_lantern",at(b.x+side*2.,b.z+6.))
	for p: Vector2 in L.FENCES:place("snow_fence",at(p.x,p.y),PI*.5 if p.x< -120 else 0.)
	for p in [Vector2(20,32),Vector2(82,-33),Vector2(45,66)]:place("ice_fishing",at(p.x,p.y),rng.randf()*TAU)
	for p in [Vector2(-27,21),Vector2(-79,102),Vector2(-79,-89)]:place("trail_sign",at(p.x,p.y))
	for p in [Vector2(123,-67),Vector2(113,77),Vector2(-7,-112),Vector2(134,14)]:place("ice_crystal",at(p.x,p.y))
	for p in [Vector2(-91,36),Vector2(-108,77)]:place("picnic_table",at(p.x,p.y),.25)
	for p in [Vector2(23,35),Vector2(80,-36),Vector2(39,65),Vector2(-41,29)]:place("sled",at(p.x,p.y),rng.randf()*TAU)
