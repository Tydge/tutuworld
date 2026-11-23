extends SceneTree
const J=preload("res://scripts/jade/layout.gd")
const Routes=preload("res://scripts/services/map_routes.gd")
const Land=preload("res://scripts/building/parcels.gd")
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,label_: String) -> void:
	print("PASS " if value else "FAIL ",label_)
	if not value:failures+=1
func check_lanterns(city: Node3D) -> void:
	var art:=preload("res://scripts/jade/architecture.gd")
	var sources: Dictionary={}
	for lamp: OmniLight3D in city.lantern_pools:
		sources[lamp.global_position.snapped(Vector3.ONE*.01)]=true
	var posts:=0
	for node in city.scenery.get_children():
		if node.get_meta("furniture_kind","")=="jade_lamp" and sources.has(node.to_global(art.POST_LANTERN).snapped(Vector3.ONE*.01)):
			posts+=1
	var facades:=0
	for house: Array in J.HOUSES:
		var room: Node3D=city.scenery.get_node(("Shop_" if J.shops().has(house[0]) else "Hall_")+house[0])
		var size:=J.dims(house[4])
		for side: float in [-1.,1.]:
			var wick:=room.to_global(art.facade_lantern(size.x,size.y,size.z,side))
			if sources.has(wick.snapped(Vector3.ONE*.01)):facades+=1
	check(posts==13 and facades==7 and sources.size()==24,"Lights aligned to street wicks and shop fronts (street=%d facades=%d total=%d)"%[posts,facades,sources.size()])
	for hour: float in [4.9,5.2,12.2,19.1]:
		city.update_lighting(hour/24.)
		var sky_colour: Color=city.atmosphere.sky.sky_material.get_shader_parameter("horizon_color")
		check(not city.atmosphere.fog_enabled and city.horizon.get_shader_parameter("air_horizon")==sky_colour and city.foothills.get_shader_parameter("air_horizon")==sky_colour,"Only the mountain materials follow the horizon colour at "+str(hour))
	city.update_lighting(.91)
	check(city.lantern_pools.all(func(lamp):return lamp.visible and lamp.light_energy>0 and not lamp.shadow_enabled),"The twenty-four night lights illuminate the city without additional shadow passes")
	check(city.sun.directional_shadow_max_distance>=120. and city.lantern_pools.all(func(lamp):return lamp.distance_fade_begin>=60. and lamp.distance_fade_begin+lamp.distance_fade_length>=100.),"Sun shadows and every street pool reach beyond the next block at night")
	city.update_lighting(.5)
	check(not city.atmosphere.fog_enabled and not city.atmosphere.glow_enabled and city.sun.directional_shadow_max_distance>=120.,"The midday city has clear air and long shadows")
	check(city.lantern_pools.all(func(lamp):return not lamp.visible),"Street lanterns switch off in daylight")
func check_court_steps(city: Node3D) -> void:
	var stairs:=0
	var samples:=0
	var clear:=0
	for stone in city.scenery.get_children():
		if not stone.has_node("FrontBalustrade"):continue
		stairs+=1
		var mesh_: Mesh=stone.get_node("Joinery").mesh
		var surfaces: Array[TriangleMesh]=[]
		var caps: Array[bool]=[]
		for i in range(mesh_.get_surface_count()):
			var surface:=ArrayMesh.new()
			surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh_.surface_get_arrays(i))
			var tree:=TriangleMesh.new()
			tree.create_from_faces(surface.get_faces())
			surfaces.append(tree)
			var mat:=mesh_.surface_get_material(i) as StandardMaterial3D
			caps.append(mat!=null and mat.albedo_texture==preload("res://assets/jade/lotus_marble.png"))
		for step in range(16):
			for along: float in [.18,.57,.88]:
				for z: float in [-2.08,-.31,1.75]:
					var probe:=Vector3(-5.8+(step+along)*5.8/16.,1.,z)
					var marble:=-INF
					var other:=-INF
					for i in range(surfaces.size()):
						var hit:=surfaces[i].intersect_segment(probe,probe-Vector3.UP*5.)
						if hit.is_empty():continue
						if caps[i]:marble=maxf(marble,hit.position.y)
						else:other=maxf(other,hit.position.y)
					samples+=1
					if is_finite(marble) and marble>other+.035:clear+=1
	print("COURT_TREADS clear=",clear," sampled=",samples)
	check(stairs==2 and samples==288 and clear==samples,"Both baked stair flights have one exposed marble tread at every sample")

# Raycast the final visual ground, including the outer edges of each tread.
# A second set just outside each flight guards against cutting a hole in the street.
func check_stair_ground(city: Node3D) -> void:
	var ground: Dictionary={}
	var exposed:=0
	var apron:=0
	var samples:=0
	for row in J.FORECOURTS:
		var side:=signf(row[0])
		var curb: float=row[0]-side*9.7
		var origin:=Vector3(floorf(curb/36.)*36.,0.,floorf(row[1]/36.)*36.)
		if not ground.has(origin):
			for part in city.scenery.get_children():
				if not part is MeshInstance3D or part.position!=origin:continue
				var mat:=part.material_override as ShaderMaterial
				if not mat or mat.shader!=preload("res://assets/shaders/jade_ground.gdshader"):continue
				var tree:=TriangleMesh.new()
				tree.create_from_faces(part.mesh.get_faces())
				ground[origin]=tree
				break
		if not ground.has(origin):continue
		var earth: TriangleMesh=ground[origin]
		for i in range(16):
			var top: float=J.approach_height(row[1])+row[2]*(i+1)/16.+.045
			for along: float in [.02,.18,.4,.66,.88,.97]:
				var x: float=curb+side*(-5.8+(i+along)*5.8/16.)
				for across: float in [-2.30,-2.,-1.,0.,1.,2.,2.30]:
					var ray:=Vector3(x,top+2.,row[1]+across)-origin
					var hit:=earth.intersect_segment(ray,ray-Vector3.UP*8.)
					samples+=1
					if not hit.is_empty() and hit.position.y>top-.008:exposed+=1
			for across: float in [-2.85,2.85]:
				var x: float=curb+side*(-5.8+(i+.5)*5.8/16.)
				var ray:=Vector3(x,top+3.,row[1]+across)-origin
				if not earth.intersect_segment(ray,ray-Vector3.UP*9.).is_empty():apron+=1
	check(samples==1344 and exposed==0 and apron==64,"No earth intersects the marble at %d points, and all %d adjacent street points retain ground"%[samples,apron])

# Measure the real sun and street lamp on a receiver beyond both old cutoffs.
func check_distant_light(city: Node3D) -> void:
	var view:=SubViewport.new()
	view.size=Vector2i(320,200);view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var camera:=Camera3D.new()
	view.add_child(camera);camera.fov=12.
	camera.look_at_from_position(Vector3(0,54,72),Vector3.ZERO)
	var stage:=Node3D.new();view.add_child(stage)
	const Geo=preload("res://scripts/geometry.gd")
	Geo.box(stage,Vector3(0,-.1,0),Vector3(32.,.2,28.),Geo.mat("bcb5a6"))
	var obstacle:=Geo.box(stage,Vector3(-1,1.5,0),Vector3(2.,3.,2.),Geo.mat("8e8270"))
	city.update_lighting(.5)
	var sun:=city.sun.duplicate() as DirectionalLight3D
	view.add_child(sun);sun.rotation_degrees=Vector3(-42,-32,0)
	var shadowed:=await light_frame(view)
	obstacle.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var unshadowed:=await light_frame(view)
	var sun_pixels:=brighter_pixels(unshadowed,shadowed)
	obstacle.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sun.directional_shadow_max_distance=63.
	var old_range:=await light_frame(view)
	var old_shadow_pixels:=brighter_pixels(unshadowed,old_range)
	sun.hide();city.update_lighting(.91)
	var lamp:=city.lantern_pools[0].duplicate() as OmniLight3D
	view.add_child(lamp);lamp.position=Vector3(2,3,0)
	var lit:=await light_frame(view)
	lamp.distance_fade_begin=21.;lamp.distance_fade_length=19.
	var dark:=await light_frame(view)
	var lamp_pixels:=brighter_pixels(lit,dark)
	print("JADE_DISTANT_LIGHT at_90m shadow_pixels=",sun_pixels," lamp_pixels=",lamp_pixels," old_shadow_pixels=",old_shadow_pixels)
	check(sun_pixels>70 and old_shadow_pixels<10 and lamp_pixels>70,"Actual GPU shadow and lantern pool are visible from 90 metres")
	view.free();city.update_lighting(.5)

func light_frame(view: SubViewport) -> Image:
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	return view.get_texture().get_image()

func brighter_pixels(bright: Image,dark: Image) -> int:
	var count:=0
	for y in range(bright.get_height()):
		for x in range(bright.get_width()):
			if bright.get_pixel(x,y).r-dark.get_pixel(x,y).r>.06:count+=1
	return count

func check_river_banks(city: Node3D) -> void:
	var water: ShaderMaterial=city.scenery.get_node("Island").get_meta("sea_material")
	var atlas: Texture2D=water.get_shader_parameter("river_banks")
	check(water.shader==preload("res://assets/shaders/jade_water.gdshader") and atlas!=null,"Use the baked city banks in the actual water material")
	if atlas==null:return
	var pixels:=atlas.get_image()
	for side in range(2):
		var sky:=0
		var buildings: Dictionary={}
		var middle:=pixels.get_height()/2
		for y in range(4,middle,8):
			for x in range(4,pixels.get_width(),32):
				var tint:=pixels.get_pixel(x,y+side*middle)
				if tint.a<.5:sky+=1
				else:buildings[tint.to_rgba32()]=true
		check(sky>100 and buildings.size()>100,"Skyline and distinct bank colours on side "+str(side))

func run() -> void:
	var dir:=preload("res://tests/test_support.gd").output_dir()
	var session:=preload("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.create_character("玉京游记","bunny","bell_red");session.state().time=1800.
	session.authority.add("ferry_coat",1);session.dispatch("equip",{"slot":"body","item":"ferry_coat"})
	session.state().player_position=[Routes.dock("city").x,.15,Routes.dock("city").y]
	var coins: int=session.state().coins
	check(session.dispatch("travel",{"destination":"jade"}).ok and session.state().coins==coins-10,"Ferry charges ten shells")
	var city=load(Routes.scene("jade")).instantiate();root.add_child(city);current_scene=city
	for i in range(15):await physics_frame
	check_river_banks(city)
	check_court_steps(city)
	check_stair_ground(city)
	check_lanterns(city)
	await check_distant_light(city)
	check(city.npcs.size()==20+J.shops().size() and city.interiors.size()==J.HOUSES.size(),"Twenty residents, all shopkeepers and all interiors")
	var street: Node=city.get_node("StreetLife")
	session.state().time=8.*150.
	street.update_market()
	for index: int in [0,3]:
		var courier: Node3D=city.targets["JadeCitizen_"+str(index)].node
		var delivery: Array=courier.get_node("NeighbourWalk").route
		check(courier.find_child("Cargo",true,false)!=null and delivery.size()==5 and absf(delivery[2].z-146.)<=9.1,"Working market delivery "+str(index))
	session.state().time=1800.
	street.update_market()
	check(city.crops.size()==32 and city.targets.has("jade_well"),"Shared field and well")
	check(city.targets.has("jade_workshop") and city.targets.has("jade:tea:tea_service_1"),"Workshop and tea room activities")
	for h in J.HOUSES:
		var room: Node3D=city.scenery.get_node(("Shop_" if J.shops().has(h[0]) else "Hall_")+h[0])
		var signs:=preload("res://scripts/jade/shop_signs.gd")
		if signs.FRONTAGES.has(h[0]):
			var wanted: String=signs.FRONTAGES[h[0]]
			check(room.get_node("Front").get_children().any(func(node):return node.get_meta("furniture_kind","")==wanted and node.has_node("TimberPost")),"Street trade sign on "+str(h[1]))
		var z: float=room.floor_size.y*.5
		var start:=room.to_global(Vector3(0,1.,z+1.));var end:=room.to_global(Vector3(0,1.,z-1.))
		check(city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,end,5)).is_empty(),"Open entrance "+str(h[1]))
	var shortcuts: HBoxContainer=city.hud.build_button.get_parent()
	var bar: PanelContainer=shortcuts.get_parent()
	check(shortcuts.get_child_count()==6 and bar.size.x<=550. and bar.get_rect().end.x<=city.hud.root_ui.size.x,"All six one-click shortcuts fit into the lower-right travel strip")
	var map_button: Button=shortcuts.get_children().filter(func(item):return item.text.begins_with("地图"))[0]
	map_button.pressed.emit()
	for i in range(4):await process_frame
	check(is_instance_valid(city.hud.map_draw) and city.hud.map_draw.is_visible_in_tree(),"Open the street map from the game HUD")
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(dir+"/玉京坊图.png")
	city.hud.close_panel()
	# The city footprint was surveyed at 181,836 m². The connected-ground
	# comparison with the current snow shoreline lives in jade_area_rules.
	var cells:=0
	for x in range(-240,241,2):
		for z in range(-214,215,2):
			cells+=int(J.can_walk(Vector3(x,1,z)))
	check(cells*4>=181836,"Jade retains its surveyed city footprint (%d square metres)"%(cells*4))
	for id in J.LOTS:
		var p:=Land.sign_position(id);session.set_player_position(p)
		check(session.buy_land(id).ok,"Purchase "+str(id))
	city.set_process(false);city.hud.hide();session.active=false;city.bunny.set_physics_process(false);session.settings.interior_view_mode=1
	for frame in [
		["河上望阙",Vector3(48,32,61),Vector3(-2,11,-85),.48,Vector2(0,14)],
		["南津灯市",Vector3(J.lane(144)+1.3,4.7,144),Vector3(J.lane(110),6.2,110),.813,Vector2(J.lane(136)-1.15,136)],
		["丹陛宫阙",Vector3(-12.0,24.2,-143),Vector3(.5,32,-164),.50,Vector2(2,-143)],
		["曲廊听荷",Vector3(127.2,8.7,-44.0),Vector3(109,8.4,-36),.48,Vector2(119,-43)],
		["桥头晨市",Vector3(J.lane(100),5.3,100),Vector3(J.lane(123)-4,5.1,123),.38,Vector2(J.lane(110),110)],
		["临川书院",Vector3(-122,8.75,-33),Vector3(-106,8.6,-43),.47,Vector2(-114,-37)]]:
		city.bunny.position=J.point(frame[4].x,frame[4].y)+Vector3.UP*.08;city.bunny.velocity=Vector3.ZERO;city.bunny.reset_physics_interpolation()
		city.bunny.set_physics_process(true)
		for tick in range(22):await physics_frame
		city.bunny.set_physics_process(false);city.bunny.visual.rotation.y=atan2(frame[2].x-city.bunny.position.x,frame[2].z-city.bunny.position.z)
		city.bunny.reset_physics_interpolation()
		city.update_lighting(frame[3]);city.camera.position=frame[1];city.camera.look_at(frame[2]);city.camera.reset_physics_interpolation()
		for i in range(4):await process_frame
		RenderingServer.force_draw();root.get_texture().get_image().save_png(dir+"/"+str(frame[0])+".png")
	session.set_player_position(Vector3(0,2.1,209))
	check(session.dispatch("travel",{"destination":"city"}).ok and session.state().coins==coins-610,"Return after six purchases is free")
	print("JADE_CITY_FLOW failures=",failures);city.free();session.free();quit(1 if failures else 0)
