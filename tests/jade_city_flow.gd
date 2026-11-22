extends SceneTree
const J=preload("res://scripts/jade/layout.gd")
const Routes=preload("res://scripts/services/map_routes.gd")
const Land=preload("res://scripts/building/parcels.gd")
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,label_: String) -> void:
	print("PASS " if value else "FAIL ",label_)
	if not value:failures+=1
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
		var z: float=room.floor_size.y*.5
		var start:=room.to_global(Vector3(0,1.,z+1.));var end:=room.to_global(Vector3(0,1.,z-1.))
		check(city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,end,5)).is_empty(),"Open entrance "+str(h[1]))
	city.hud.open_panel("map")
	for i in range(4):await process_frame
	check(is_instance_valid(city.hud.map_draw) and city.hud.map_draw.is_visible_in_tree(),"Open the street map from the game HUD")
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(dir+"/玉京坊图.png")
	city.hud.close_panel()
	var reachable:=0;var ice:=0
	for x in range(-240,241,2):
		for z in range(-214,215,2):
			var p:=Vector3(x,1,z)
			reachable+=int(J.can_walk(p));ice+=int(preload("res://scripts/icefield/icefield_layout.gd").can_walk(p))
	check(reachable>2*ice,"Walkable footprint ratio %.2f"%(float(reachable)/ice))
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
