extends SceneTree
const Support:=preload("res://tests/test_support.gd")
const DB:=preload("res://scripts/services/game_data.gd")
const Spurs:=preload("res://scripts/city/coastal/fruit_spurs.gd")
const Layout:=preload("res://scripts/building/layout.gd")
const Wall:=preload("res://scripts/building/wall_mount.gd")
var failures: Array[String]=[]
var total:=0
var city: Node3D
var session: Node

func check(ok: bool,label_: String) -> void:
	total+=1
	if not ok:failures.append(label_)
	print("PASS " if ok else "FAIL ",label_)

func _initialize() -> void:
	call_deferred("run")

var last_draw_usec:=0

func frame() -> void:
	await process_frame
	var now:=Time.get_ticks_usec()
	var elapsed:=float(now-last_draw_usec)/1000000. if last_draw_usec!=0 else 1./60.
	last_draw_usec=now
	# The manual renderer advances shader TIME only when its frame step is supplied.
	RenderingServer.force_draw(true,elapsed)

func photo(name_: String) -> void:
	for i in range(8): await frame()
	var shot:=root.get_texture().get_image()
	shot.resize(1280,roundi(1280.*shot.get_height()/shot.get_width()),Image.INTERPOLATE_LANCZOS)
	shot.save_jpg(Support.output_dir().path_join(name_+".jpg"),.94)

func verify_fruit(id: String) -> Node3D:
	var cluster: Node3D=city.resources[id]
	var crown: Node3D=cluster.get_parent()
	var model: MeshInstance3D=crown.get_parent().get_node("OrchardTree/WoodAndLeaves")
	var inst: MultiMeshInstance3D=cluster.get_child(0)
	check(inst.material_override==model.material_override,id+" fruit and tree share the same camera fade")
	for i in range(Spurs.COUNT):
		var point:=inst.to_global(inst.multimesh.get_instance_transform(i)*Spurs.STEM_END)
		var joint:=model.to_global(Spurs.tip(i))
		check(point.distance_to(joint)<.001,id+" stem meets branch "+str(i))
	return crown.get_parent()

func cover_image() -> Image:
	for i in range(5):await frame()
	var shot:=root.get_texture().get_image()
	shot.resize(640,roundi(640.*shot.get_height()/shot.get_width()),Image.INTERPOLATE_BILINEAR)
	return shot

func check_leaf_shadow(tree: Node3D, crop: Node3D) -> void:
	var leaves:=tree.get_node("OrchardTree/WoodAndLeaves") as MeshInstance3D
	var shadow:=tree.get_node("OrchardTree/LeafShadows") as MeshInstance3D
	var down: Vector3=-city.sun.global_basis.z
	var ground:=tree.global_position
	var center:=ground+Vector3(down.x,0,down.z)*(3.15/maxf(.2,-down.y))
	city.camera.position=center+Vector3(.01,9.,.08)
	city.camera.look_at(center,Vector3.FORWARD)
	leaves.hide()
	crop.hide()
	var shaded:=await cover_image()
	shadow.hide()
	var open:=await cover_image()
	shaded.save_jpg(Support.output_dir().path_join("leaf-shade-on.jpg"),.94)
	open.save_jpg(Support.output_dir().path_join("leaf-shade-off.jpg"),.94)
	var darker:=0
	var n:=0
	for i in range(-10,11):
		for j in range(-10,11):
			var pixel: Vector2=city.camera.unproject_position(center+Vector3(.195*i,0,.195*j))
			var at:=Vector2i(pixel*Vector2(shaded.get_size())/city.camera.get_viewport().get_visible_rect().size)
			if not Rect2i(Vector2i.ZERO,shaded.get_size()).has_point(at):continue
			n+=1
			if open.get_pixelv(at).get_luminance()-shaded.get_pixelv(at).get_luminance()>.045:darker+=1
	shadow.show()
	leaves.show()
	crop.show()
	print("ORCHARD_GROUND_SHADOW covered=",darker," sampled=",n)
	check(n>300 and darker>n*.25,"The leaf canopy shades the ground well beyond the woody branches")

func water_motion(fountain: Node3D) -> void:
	var first:=await cover_image()
	var start:=Time.get_ticks_usec()
	while Time.get_ticks_usec()-start<570000:await frame()
	var second:=await cover_image()
	var changed:=0
	var count:=0
	for i in range(-12,13):
		for j in range(4,15):
			var p:=Vector3(i*.17,.445,j*.17)
			if p.length()>2.72 or p.length()<1.37:continue
			var screen: Vector2=city.camera.unproject_position(fountain.to_global(p))
			var at:=Vector2i(screen*Vector2(first.get_size())/city.camera.get_viewport().get_visible_rect().size)
			if not Rect2i(Vector2i.ZERO,first.get_size()).has_point(at):continue
			count+=1
			if absf(first.get_pixelv(at).get_luminance()-second.get_pixelv(at).get_luminance())>.009:changed+=1
	print("FOUNTAIN_MOTION changed=",changed," sampled=",count)
	check(count>100 and changed>count*.12,"Stationary-camera pool pixels change as water and ripples move")

func record_water() -> void:
	# Record presented game frames. Capture at video resolution so reading the image back
	# does not waste time downsampling a full desktop frame on each tick.
	var old_mode:=root.mode
	var old_size:=root.size
	var old_fps:=Engine.max_fps
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(960,600)
	Engine.max_fps=30
	RenderingServer.set_render_loop_enabled(true)
	for i in range(6):await RenderingServer.frame_post_draw
	var start:=Time.get_ticks_usec()
	var times: Array[float]=[]
	while Time.get_ticks_usec()-start<6200000:
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec()
		var still:=root.get_texture().get_image()
		still.save_jpg(Support.output_dir().path_join("flow-%03d.jpg"%times.size()),.93)
		times.append(float(now-start)/1000000.)
	var out:=FileAccess.open(Support.output_dir().path_join("flow-times.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify(times))
	out.close()
	RenderingServer.set_render_loop_enabled(false)
	last_draw_usec=Time.get_ticks_usec()
	root.size=old_size
	root.mode=old_mode
	Engine.max_fps=old_fps

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test"):
		quit(1)
		return
	RenderingServer.set_render_loop_enabled(false)
	session=preload("res://scripts/services/session.gd").new()
	session.name="Session"
	root.add_child(session)
	session.create_character("海岛花庭","bunny","scarf_green")
	city=preload("res://scenes/city.tscn").instantiate()
	root.add_child(city)
	current_scene=city
	while city.preparing or city.camera==null or not city.navigation.ready_for_paths: await frame()
	session.active=false
	for i in range(50): await frame()
	city.hud.hide()
	await photo("arrival")
	city.set_process(false)
	city.hud.hide()
	var selected: Node3D
	for source in DB.resources("city"):
		if source.item=="orange":selected=verify_fruit(source.id)
	city.bunny.hide()
	city.update_lighting(.43)
	var pivot:=selected.global_position+Vector3.UP*2.55
	for i in range(3):
		var a: float=[.28,2.37,-.72][i]
		city.camera.position=pivot+Vector3(sin(a)*7.7,1.18,cos(a)*7.7)
		city.camera.look_at(pivot)
		await photo("orchard-"+str(i))
	await check_leaf_shadow(selected,city.resources["city_orange_3"])
	var tree_center:=selected.global_position+Vector3.UP*1.45
	city.camera.position=tree_center+Vector3(5.2,4.7,6.7)
	city.camera.look_at(tree_center)
	await photo("orchard-shadow")
	var fountain: Node3D=city.scenery.get_node("CentralPark/Fountain")
	check(fountain.has_node("RunningWater") and fountain.has_node("PoolCollision/Basin"),"Working fountain and its collision occupy the same plaza module")
	city.camera.position=fountain.global_position+Vector3(2.15,2.67,7.20)
	city.camera.look_at(fountain.global_position+Vector3.UP*1.45)
	await photo("fountain")
	await water_motion(fountain)
	if OS.get_cmdline_user_args().has("--capture-fountain"):await record_water()
	var id:="city_orange_3"
	var res_: Dictionary=DB.resource(id)
	session.set_player_position(Vector3(res_.x,.1,res_.z+2.))
	check(session.authority.execute({"verb":"gather","target":id}).ok,"Pick the visible crop")
	session.authority.tick(3.)
	city.refresh_world()
	check(not city.resources[id].visible and selected.get_node("OrchardTree/WoodAndLeaves").is_visible_in_tree(),"Picking removes fruit and leaves the bearing branches")
	var saved: Dictionary=session.restore_state(session.state()).state
	check(not saved.resources[id].available,"Loading retains the harvested crop")
	city.bunny.show()
	city.bunny.position=Vector3(79,.12,7)
	session.set_player_position(city.bunny.position)
	check(session.buy_land("east_nw").ok and city.build_mode.open_nearby_parcel().ok,"Enter actual owned parcel")
	var layout:=Layout.add(Layout.empty(),{"type":"floor","a":[81.,-6.],"b":[91.,2.]})
	layout=Layout.add(layout,{"type":"wall","a":[81.,-6.],"b":[91.,-6.]})
	var flower:=Wall.attach(layout,{"type":"object","kind":"wisteria_box","position":[86.,-6.],"yaw":0.},Vector2(86,-6),Vector2(86,0))
	layout=Layout.add(layout,flower)
	layout=Layout.add(layout,{"type":"object","kind":"fountain","position":[96.,-7.],"yaw":90.})
	var committed: bool=city.build_mode.commit(layout)
	check(committed,"Commit the same public flower box on a player-built wall")
	if not committed:
		quit(1)
		return
	var item: Dictionary=city.build_mode.layout.elements.filter(func(row):return row.get("kind","")=="wisteria_box")[0]
	var restored:=Layout.validate(JSON.parse_string(JSON.stringify(city.build_mode.layout)))
	check(restored.ok and not Wall.support(restored.layout,item).is_empty(),"Box keeps its wall anchor through a save round-trip")
	var furnishing: Node3D=city.build_mode.room.get_node("Furnishing")
	var streams:=furnishing.find_children("RunningWater","MeshInstance3D",true,false)
	check(not streams.is_empty() and streams[0].mesh==fountain.get_node("RunningWater").mesh,"Player fountain uses the plaza water geometry after placement")
	var boxes:=furnishing.find_children("Racemes","MeshInstance3D",true,false)
	check(not boxes.is_empty() and boxes[0].mesh==preload("res://scenes/coastal/wisteria.res"),"Editor and shopfront use identical flower geometry")
	city.build_mode.set_roof_visible(true)
	city.build_mode.set_process(false)
	city.build_mode.ui.hide()
	city.camera.position=Vector3(88,3.9,.6)
	city.camera.look_at(Vector3(86,2.1,-5.8))
	await photo("built-wisteria")
	city.free()
	await process_frame
	session.state().map_id="valley"
	session.state().player_position=preload("res://scripts/valley/valley_layout.gd").arrival("valley")
	city=preload("res://scenes/valley.tscn").instantiate()
	root.add_child(city)
	current_scene=city
	while city.preparing or city.camera==null or not city.navigation.ready_for_paths:await frame()
	city.set_process(false)
	city.hud.hide()
	city.bunny.hide()
	var count:=0
	for source in DB.resources("valley"):
		if source.item!="orange":continue
		selected=verify_fruit(source.id)
		count+=1
	check(count==5,"Five harvestable valley trees use the bearing branches")
	check(DB.resources("icefield").filter(func(row):return row.item=="orange").is_empty(),"Icefield has no harvestable citrus")
	var p:=selected.global_position+Vector3.UP*2.55
	city.camera.position=p+Vector3(5.,2.3,7.)
	city.camera.look_at(p)
	city.update_lighting(.48)
	await photo("valley-orchard")
	city.free()
	session.free()
	for i in range(3):await frame()
	RenderingServer.set_render_loop_enabled(true)
	print("COASTAL_MODULES_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",total," failures=",failures)
	quit(0 if failures.is_empty() else 1)
