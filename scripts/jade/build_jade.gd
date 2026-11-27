extends "res://scripts/icefield/build_icefield.gd"
const J=preload("res://scripts/jade/layout.gd")
const A=preload("res://scripts/jade/architecture.gd")
const FB=preload("res://scripts/building/furniture_builder.gd")
var furniture:=FB.new()
func build() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	rng.seed=62835
	world=Node3D.new();world.name="Yujing";root.add_child(world)
	world.set_meta("scenery_polished",true);world.set_meta("groundcover_revision",3);world.set_meta("terrain_material_revision",1)
	build_environment()
	var env: Environment=world.get_node("Atmosphere").environment
	env.fog_enabled=false
	env.fog_density=0.
	env.glow_bloom=0.
	env.sky.sky_material.shader=preload("res://assets/shaders/island_sky.gdshader")
	env.sky.sky_material.set_shader_parameter("star_focus",3.8);env.sky.sky_material.set_shader_parameter("cloud_detail",1.)
	var sea: ShaderMaterial=world.get_node("Island").get_meta("sea_material")
	sea.shader=preload("res://assets/shaders/island_ocean.gdshader")
	preload("res://scripts/city/water_materials.gd").apply(world)
	streets();preload("res://scripts/jade/garden.gd").dress(self)
	for h in J.HOUSES:house(h)
	shore_landmarks()
	gardens();preload("res://scripts/jade/streetscape.gd").build(self)
	preload("res://scripts/jade/landscaping.gd").quays(self)
	preload("res://scripts/jade/market_art.gd").dress(self)
	preload("res://scripts/jade/borders.gd").dress(self)
	preload("res://scripts/jade/shopfront.gd").dress(self)
	preload("res://scripts/jade/processional_court.gd").dress(self)
	for pos in [Vector2(-9.4,-141),Vector2(9.4,-141),Vector2(-13.,-158),Vector2(13.,-158),Vector2(123,-36),Vector2(-125,-53)]:
		fixture(world,"jade_crane",J.point(pos.x,pos.y),-.85 if pos.x>0 else .85)
	for berth in [Vector2(-88,6.2),Vector2(-128,-5.7),Vector2(20.,5.8),Vector2(69.,-6.7),Vector2(90.,6.5)]:
		var draft:=Vector3(berth.x,-.43,J.river_z(berth.x)+berth.y)
		fixture(world,"jade_sampan",draft,PI*.5+.13*sin(berth.x))
	var districts:=preload("res://scripts/jade/court_ground.gd").make(world)
	landscape(districts)
	var planting=preload("res://scripts/jade/landscaping.gd")
	var mask: Image=await planting.planting_mask(self)
	if mask==null or mask.is_empty():
		push_error("Could not bake the Jade planting mask")
		quit(1)
		return
	planting.planting(self,districts,mask)
	for h in J.HOUSES:
		var room:=world.get_node(("Shop_" if J.shops().has(h[0]) else "Hall_")+h[0]) as Node3D
		preload("res://scripts/jade/sight_geometry.gd").bake_room(room)
		preload("res://scripts/jade/distant_buildings.gd").bake(room)
	preload("res://scripts/jade/distant_buildings.gd").finish_textures()
	preload("res://scripts/jade/crowd_meshes.gd").bake(world)
	preload("res://scripts/jade/handwork.gd").bake_tools(world)
	preload("res://scripts/jade/static_colours.gd").bake(world)
	preload("res://scripts/jade/distant_buildings.gd").batch_fixtures(world)
	preload("res://scripts/jade/static_colours.gd").bake_fixed_shadows(world)
	preload("res://scripts/jade/static_colours.gd").bake_shadow_sections(world)
	var site:=group(world,"JadeBuildingSite");preload("res://scripts/building/site.gd").build_signs(site,"jade")
	if not await preload("res://scripts/jade/navigation_bake.gd").bake(self,world):push_error("Incomplete Jade navigation survey");quit(1);return
	if not await preload("res://scripts/jade/river_reflection.gd").bake(self,world,sea):
		push_error("Could not bake the riverbank reflections")
		quit(1)
		return
	own(world,world)
	var packed:=PackedScene.new();var error:=packed.pack(world)
	if error==OK:
		await process_frame;await RenderingServer.frame_post_draw
		error=ResourceSaver.save(packed,"res://scenes/jade_map.scn",ResourceSaver.FLAG_COMPRESS)
	print("JADE_CITY_BUILD ",error," houses ",J.HOUSES.size());world.free();quit(error)
func landmesh(st: SurfaceTool,pos: Vector3,material: Material,id: String,solid: bool) -> MeshInstance3D:
	st.index();st.generate_normals()
	var mesh_:=st.commit();var m:=G.mesh(world,mesh_,pos,material,id)
	if solid:
		var body:=StaticBody3D.new();body.collision_layer=8;body.collision_mask=0;m.add_child(body)
		var col:=CollisionShape3D.new();col.shape=mesh_.create_trimesh_shape();body.add_child(col)
	return m
func landscape(districts: Image) -> void:
	var grass:=ShaderMaterial.new();grass.shader=preload("res://assets/shaders/jade_ground.gdshader");grass.set_shader_parameter("stone",preload("res://assets/jade/masonry.png"));grass.set_shader_parameter("turf",preload("res://assets/terrain/woodland/forest_turf_v1.png"));grass.set_shader_parameter("paving",preload("res://assets/jade/courtyard_flags.png"));grass.set_shader_parameter("earth",preload("res://assets/terrain/packed_earth_path_v1.png"))
	grass.set_shader_parameter("courts",ImageTexture.create_from_image(districts))
	for z0 in range(-216,216,36):
		for x0 in range(-252,252,36):
			var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for z in range(0,36,2):
				for x in range(0,36,2):
					for v in [Vector2(0,0),Vector2(2,0),Vector2(0,2),Vector2(2,0),Vector2(2,2),Vector2(0,2)]:
						var px: float=x+v.x;var pz: float=z+v.y
						st.add_vertex(Vector3(px,J.height_at(x0+px,z0+pz),pz))
			var ground:=landmesh(st,Vector3(x0,0,z0),grass,"Terrace",true)
			preload("res://scripts/jade/processional_court.gd").trim_covered_earth(ground)
	preload("res://scripts/jade/hills.gd").build(self)
func fixture(parent: Node3D,kind: String,p: Vector3,angle:=0.,bay_width:=4.62) -> Node3D:
	var n:=group(parent,kind,p);n.rotation.y=angle
	if kind=="jade_gallery":
		preload("res://scripts/jade/garden.gd").make(n,kind,true,bay_width)
		n.set_meta("veranda_paving",Rect2(-bay_width*.5,-1.55,bay_width,3.1))
	else:A.prop(n,kind)
	n.set_meta("furniture_kind",kind)
	return n
func streets() -> void:
	var dock:=group(world,"SouthPier",Vector3(0,J.DOCK_HEIGHT,206.5))
	preload("res://scripts/jade/wharf_field.gd").wharf(self,dock)
	G.solid_box(dock,Vector3(0,-.12,0),Vector3(7,.24,13)).collision_layer=8
	for bz in [194.,38.,J.PALACE_GATE_Z,-145.]:
		var gate:=fixture(world,"jade_gate",J.point(0,bz))
		if bz in [38.,-145.]:gate.scale=Vector3.ONE*.86
		if bz==J.PALACE_GATE_Z:
			gate.scale=Vector3.ONE*1.48
			for side in [-1.,1.]:
				var side_gate:=fixture(world,"jade_gate",J.point(side*13.2,bz))
				side_gate.scale=Vector3.ONE*.77
		var sign_:=G.text3d(gate,{194.:"南 津 渡",38.:"望 河 坊",J.PALACE_GATE_Z:"承 天 门",-145.:"丹 陛"}[bz],Vector3(0,6.4,.54),50,Color("f4cf88"));sign_.double_sided=false
	for bx in J.BRIDGES:
		var cz:=J.river_z(bx)
		for j in range(12):
			var z:=cz-18.+(j+.5)*3.;var y:=J.deck(z,bx)
			var deck_:=group(world,"BridgeSpan",Vector3(bx,y,z))
			deck_.add_to_group("jade_bridge_spans")
			deck_.rotation.x=-atan2(J.deck(z+1.5,bx)-J.deck(z-1.5,bx),3.)
			A.mesh_part(deck_,"bridge_flagstones",func(m):
				for k in range(5):
					for t in range(2):
						var x0: float=(k-2)*1.78;var z0: float=(t-.5)*1.5
						A.paint(m,Vector3(x0,-.19,z0),Vector3(1.779,.38,1.499),"masonry")
				for x in [-4.06,4.06]:
					A.paint(m,Vector3(x,.025,0),Vector3(.42,.05,2.999),"masonry"))
			G.solid_box(deck_,Vector3.DOWN*.19,Vector3(8.9,.38,3.04)).collision_layer=8
			for side in [-1,1]:
				var rail:=fixture(deck_,"jade_rail",Vector3(side*4.4,0,0),PI/2)
				rail.scale.x=.74
			if j in [0,11]:
				for side in [-1,1]:fixture(world,"jade_lamp",Vector3(bx+side*5.6,y,z))
		for side in [-1.,1.]:
			var arch:=group(world,"BridgeArcade",Vector3(bx+side*4.09,0,cz))
			A.mesh_part(arch,"bridge_arcade",func(m):
				for i in range(72):
					var z0: float=-18.+i*.50;var arc:=fposmod(z0+18.,12.)-6.
					var underside:=.46+4.95*sqrt(maxf(0.,1.-pow(arc/5.37,2.)))
					var top:=J.deck(z0,0.)-.21
					A.paint(m,Vector3(0,(top+underside)*.5,z0),Vector3(.51,top-underside,.50),"masonry")
					A.box(m,Vector3(0,underside+.10,z0),Vector3(.59,.22,.50),"8c8873"))
	for z in [-132.,-106.,-91.,-66.,-38.,25.,44.,67.,91.,117.,153.,168.,188.]:
		var side:=1. if int(z)%2==0 else -1.
		var post:=fixture(world,"jade_lamp",J.point(side*(7.5+.6*sin(z))+J.lane(z),z))
		preload("res://scripts/jade/streetscape.gd").lamplight(world,post.to_global(A.POST_LANTERN),Color("ffd098"),8.4)
	for z in [115.5,69.]:
		var walkway:=fixture(world,"jade_street_gallery_reverse" if z>100. else "jade_street_gallery",J.point(J.lane(z),z),.035*sin(z))
		for side in [-1.,1.]:
			preload("res://scripts/jade/streetscape.gd").lamplight(world,walkway.to_global(Vector3(side*3.35,3.5,1.3)),Color("ffb76a"),10.)
	for row in [[88.,-.18,1.04],[96.5,.25,1.23],[136.,.12,.98],[143.,-.26,1.18],[157.,-.10,1.03],[166.,.29,1.24],[184.,-.13,1.]]:
		var z: float=row[0]
		var line:=fixture(world,"jade_festoon",J.point(J.lane(z),z),row[1])
		line.scale=Vector3(1.04,row[2],1.)
		for side in [-1.,1.]:
			var p:=line.to_global(Vector3(side*7.55,2.96,0))
			A.column(world,p,.102,5.92*line.scale.y)
	for z in [J.PALACE_GATE_Z-1.,-146.]:
		for side in [-1,1]:
			for i in range(11):
				if z==J.PALACE_GATE_Z-1. and i<3:continue
				fixture(world,"jade_palace_wall",J.point(side*(8.+4.*i),z))
			if z==J.PALACE_GATE_Z-1.:
				for join in [[8.35,.65],[17.35,.40]]:
					var wall:=fixture(world,"jade_palace_wall",J.point(side*join[0],J.PALACE_GATE_Z))
					wall.scale.x=join[1]
	# Batch the fixed stone courses in short sections for independent frustum culling.
	for first_z in range(-156,-103,8):
		var flight:=group(world,"ProcessionalSteps",Vector3(0,0,first_z))
		A.mesh_part(flight,"ProcessionalSteps"+str(first_z),func(m):
			for z in range(first_z,mini(first_z+8,-103)):
				var h:=J.height_at(0,z)
				if absf(h-J.height_at(0,z+1))<.08:continue
				var step_y:=maxf(h,J.height_at(0,z-.55))+.11
				for i in range(6):
					A.paint(m,Vector3((i-2.5)*2.,step_y-.34,z-first_z),Vector3(1.993,.68,1.),"masonry"))
	preload("res://scripts/jade/wharf_field.gd").steps(self)
	preload("res://scripts/jade/wharf_field.gd").field(self)
	var well: Dictionary=preload("res://scripts/city/production_facilities.gd").object_definitions()[0].duplicate(true)
	well.id="jade_well";well.origin=[J.FIELD_WELL.x,J.foot(J.FIELD_WELL.x,J.FIELD_WELL.y),J.FIELD_WELL.y];well.yaw=0.
	preload("res://scripts/city/production_builder.gd").build_well(world,well)
func house(h: Array) -> void:
	var shop:=str(h[0]) in J.shops();var d:=A.dims(h[4])
	var n:=group(world,("Shop_" if shop else "Hall_")+h[0],J.point(J.center(h).x,h[3]));n.rotation.y=J.door_angle(h)
	n.set_script(preload("res://scripts/jade/room.gd"));n.shell_kind=h[4];n.floor_size=Vector2(d.x*2.,d.z*2.);n.wall_height=d.y;n.set_meta("building_definition",h[0])
	A.shell(n,h[4],true)
	n.get_node("Front").set_meta("shell_children",n.get_node("Front").get_child_count())
	var nameplate:=G.text3d(n,h[1],Vector3(0,d.y-.60,d.z+.62),52,Color("ffdfa0"));nameplate.name="HouseName";nameplate.double_sided=false
	var base:=Vector3(d.x*2+.65,.46,d.z*2+.75)
	A.mesh_part(n,"RoomFloor"+h[4],func(m):
		var nx:=ceili(base.x/2.);var nz:=ceili(base.z/1.4)
		for j in range(nz):
			for k in range(nx):
				var x: float=((k+.5)/nx-.5)*base.x;var z: float=((j+.5)/nz-.5)*base.z
				A.paint(m,Vector3(x,-.15,z),Vector3(base.x/nx-.004,base.y,base.z/nz-.004),"masonry"))
	G.solid_box(n,Vector3(0,-.15,0),base).collision_layer=8
	var furnishing:=group(n,"Furnishing",Vector3.UP*.08)
	var plan:=preload("res://scripts/jade/room_plan.gd")
	var rows:=plan.ground(h[0])
	for i in rows.size():
		var obj:=place_furniture(furnishing,rows[i],i)
		if i==0 and plan.Games.STATIONS.has(h[0]):
			obj.name="Trade"
			obj.set_meta("jade_house",h[0])
			A.group(obj,"ActivityAnchor",Vector3(0,.07,float(prop_depth(rows[i][0]))*.5+.45))
		if h[0] in ["dye","silk"] and i==0:mark_dye(obj)
		if h[0] in ["cot","inn"] and i==0:obj.name="bed_0"
		if h[0] in ["spice","tavern"] and i==0:
			preload("res://scripts/jade/trades.gd").cook_station(obj)
			obj.set_meta("facility_id","jade_kitchen_"+str(h[0]))
	if h[0]=="workshop":
		var station:=group(furnishing,"Bench",Vector3(0,0,-2.7))
		preload("res://scripts/city/production_builder.gd").build_workbench(furniture,station)
		preload("res://scripts/city/production_facilities.gd").configure(station,{"id":"jade_workshop","name":h[1],"kind":"workshop","anchors":{"ActionAnchor":[0,.05,1.7],"WorkAnchor":[0,.05,1.7],"EffectAnchor":[0,1.2,.2]}})
	if h[4] in ["loft","inn","clocktower","theatre"]:
		var upper:=plan.gallery(h[0])
		for i in upper.size():
			var obj:=place_furniture(furnishing,upper[i],i,d.y)
			if h[0]=="silk" and i==0:mark_dye(obj)
	var lamp:=OmniLight3D.new();lamp.name="RoomLight";lamp.position=Vector3.UP*3.;lamp.light_color=Color("ffdfa0");lamp.omni_range=8.;lamp.distance_fade_enabled=true;lamp.distance_fade_begin=28.;lamp.distance_fade_length=15.;furnishing.add_child(lamp)
func prop_depth(kind: String) -> float:
	return preload("res://scripts/building/catalog.gd").OBJECTS[kind].size.y
func mark_dye(obj: Node3D) -> void:
	obj.set_meta("dye_station",true)
	A.group(obj,"ActivityAnchor",Vector3(0,.07,1.15))
func place_furniture(parent: Node3D,row: Array,index: int,height:=0.) -> Node3D:
	var kind:=str(row[0])
	var obj:=group(parent,kind)
	if kind.begins_with("jade_"):
		A.prop(obj,kind)
		obj.set_meta("furniture_kind",kind)
	else:
		furniture.build_item(obj,kind)
	obj.name=("Gallery_" if height>0. else "")+kind+"_"+str(index)
	obj.position=Vector3(row[1],height+(float(row[3]) if row.size()>3 else 0.),row[2])
	return obj
func shore_landmarks() -> void:
	for id in J.LANDMARKS:
		var mark: Dictionary=J.LANDMARKS[id]
		var site:=group(world,"Shore_"+id,J.point(mark.at.x,mark.at.y))
		match id:
			"tide_stone":
				A.paint(site,Vector3(0,.16,-.9),Vector3(2.8,.32,1.8),"masonry")
				A.paint(site,Vector3(0,1.66,-.9),Vector3(1.7,2.8,.67),"stone_relief")
				for i in range(3):
					A.box(site,Vector3(-.48,1.+i*.39,-.55),Vector3(.42-i*.08,.045,.05),"694f42")
				G.text3d(site,"水\n则",Vector3(.24,1.95,-.54),58,Color("362d28"))
				G.solid_box(site,Vector3(0,1.45,-.9),Vector3(1.7,2.9,.67))
			"beacon":
				fixture(world,"jade_gallery",site.position)
				for x in [-1.88,1.88]:fixture(site,"jade_lamp",Vector3(x,0,-1.9))
				G.text3d(site,"听 潮",Vector3(0,2.73,1.46),51,Color("e0bf7f"))
			"east_fork":
				A.box(site,Vector3(.9,1.2,0),Vector3(.18,2.4,.18),"6c523e")
				for i in range(2):
					var y:=2.16-i*.49
					A.paint(site,Vector3(.9,y,0),Vector3(3.05,.44,.15),"lacquer")
					var sign_:=G.text3d(site,["六里宅地　南","东野采场　东"][i],Vector3(.9,y,.09),41,Color("f5e2b4"))
					sign_.double_sided=false
					var reverse:=G.text3d(site,sign_.text,Vector3(.9,y,-.09),41,Color("f5e2b4"))
					reverse.rotation.y=PI
func gardens() -> void:
	# Asymmetrical group planting draws the edge of each walled court and its river garden.
	for p in [Vector2(-85,-151),Vector2(-76,-144),Vector2(-64,-149),Vector2(-53,-143),Vector2(-45,-155),Vector2(-40,-161),Vector2(44,-157),Vector2(53,-146),Vector2(65,-152),Vector2(71,-145),Vector2(79,-150),Vector2(-56,-110),Vector2(-51,-103),Vector2(-36,-112),Vector2(41,-111),Vector2(55,-107),Vector2(66,-97),Vector2(-80,-84),Vector2(86,-82),Vector2(123,-30),Vector2(133,-48),Vector2(127,-58),Vector2(117,-56),Vector2(96,-51),Vector2(92,-31),Vector2(90,-20),Vector2(-133,-60),Vector2(-136,-29),Vector2(-120,-58),Vector2(-92,-47),Vector2(-129,-25),Vector2(67,22),Vector2(-61,17),Vector2(-86,21),Vector2(132,23)]:
		tree_at_jade(p.x,p.y,4)
	for i in range(460):
		var x:=rng.randf_range(-228,228);var z:=rng.randf_range(-197,196)
		if absf(x)<23. or (absf(z-J.river_z(x))<23.) or (absf(x)<78 and z< -73.) or (x< -145 and x> -182 and z>108 and z<135):continue
		if J.HOUSES.any(func(h):return absf(x-J.center(h).x)<16. and absf(z-h[3])<10.):continue
		if J.LOT_ORIGINS.any(func(p):return Rect2(p,Vector2(24,20)).grow(3.).has_point(Vector2(x,z))):continue
		tree_at_jade(x,z,i%4)
	for z in [-177.,-150.,-124.,-94.,-66.,32.,63.,92.,120.,151.,177.]:
		for side in [-1,1]:
			tree_at_jade(side*(18. if z<0 else 28.),z,1 if z<0 else 2)
func tree_at_jade(x: float,z: float,variant: int) -> void:
	var p:=Vector2(x,z)
	for landmark in J.LANDMARKS.values():
		if p.distance_to(landmark.at)<7.:return
	for path in preload("res://scripts/jade/court_ground.gd").FIELD_PATHS:
		for i in range(1,path.size()):
			if Geometry2D.get_closest_point_to_segment(p,path[i-1],path[i]).distance_to(p)<3.6:return
	if Rect2(-130,-55,18,18).has_point(p) or J.near_entrance(x,z):return
	var angle := rng.randf_range(0,TAU)
	var size_factor := rng.randf_range(.79,1.23)
	if J.FIELD_BOUNDS.grow(3.).has_point(p) or p.distance_to(J.FIELD_WELL)<5.:return
	var t:=group(world,"Grove",J.point(x,z));t.set_meta("grove",true);t.rotation.y=angle;t.scale=Vector3.ONE*size_factor
	preload("res://scripts/jade/grove.gd").place(t,variant,true)
