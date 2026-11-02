extends RefCounted
const G=preload("res://scripts/geometry.gd")
const Layout=preload("res://scripts/valley/valley_layout.gd")
const UI=preload("res://scripts/ui/ui_kit.gd")
static func attach(city: Node3D) -> void:
	var dock:=Layout.dock(city.map_id)
	city.targets["boat"]={"kind":"boat","position":Vector3(dock.x,.1,dock.y),"radius":3.1}
	var boat:=Node3D.new();boat.name="TravelBoat";city.scenery.add_child(boat)
	boat.position=Vector3(16.3,-1.25,50) if city.map_id=="city" else Vector3(-1.5,Layout.water_level(48.2)-.12,48.2)
	if city.map_id=="valley": boat.rotation.y=.08
	var wood:=G.mat("c29b65");var trim:=G.mat("eee0ba")
	var hull:=G.ball(boat,Vector3(0,.15,0),Vector3(1.05,.38,2.1),G.mat("598e88"),"Hull")
	G.ball(boat,Vector3(0,.37,0),Vector3(.91,.13,1.87),G.mat("6c6b50"),"Inside")
	for z in [-1.,0.,1.]: G.box(boat,Vector3(0,.47,z),Vector3(1.75,.12,.24),wood)
	for x in [-.82,.82]: G.capsule(boat,Vector3(x,.48,-1.3),Vector3(x,.48,1.3),.055,trim)
	G.capsule(boat,Vector3(-.8,.65,-.6),Vector3(1.3,.65,1.3),.035,wood)
	G.ball(boat,Vector3(1.3,.65,1.3),Vector3(.18,.045,.45),wood)
	var life_ring:=TorusMesh.new();life_ring.inner_radius=.23;life_ring.outer_radius=.36
	var ring:=G.mesh(boat,life_ring,Vector3(.98,.3,.25),trim,"LifeRing");ring.rotation.z=PI*.5
	var sign:=Node3D.new();sign.name="BoatSign";city.scenery.add_child(sign);sign.position=Vector3(dock.x+1.6,.1,dock.y-1);sign.rotation.y=PI
	G.capsule(sign,Vector3.ZERO,Vector3(0,1.65,0),.045,wood)
	G.box(sign,Vector3(0,1.30,0),Vector3(1.8,.64,.12),G.mat("e8d5a4"))
	G.text3d(sign,"回城 · 免费" if city.map_id=="valley" else "眠风山谷\n船票 10",Vector3(0,1.3,.075),20,Color("426d63"))
	preload("res://scripts/city/prop_collisions.gd").cylinder(sign,"SignCollision",Vector3(0,.7,0),.15,1.4)
	preload("res://scripts/city/prop_collisions.gd").box(sign,"SignBoardCollision",Vector3(0,1.3,0),Vector3(1.8,.64,.16))
static func go(city: Node3D) -> void:
	if city.preparing or not city.session.job().is_empty(): return
	var session: Node=city.session
	if city.map_id=="city" and session.state().coins<10: city.hud.notify("船票需要 10 贝壳币。");return
	city.preparing=true;city.paused=true;city.bunny.can_move=false;city.bunny.velocity=Vector3.ZERO
	session.set_player_position(city.bunny.position);session.active=false
	var destination: String="city" if city.map_id=="valley" else "valley"
	var cover:=CanvasLayer.new();cover.layer=100;city.add_child(cover)
	var veil:=ColorRect.new();veil.color=Color("f5f0df");cover.add_child(veil);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label:=UI.label("小船摇呀摇，山谷快到啦…" if destination=="valley" else "顺着海风，回家啦…",27,UI.GREEN)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	veil.add_child(label);label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await city.get_tree().process_frame
	var path: String="res://scenes/valley_map.scn" if destination=="valley" else "res://scenes/city_map.tscn"
	var error:=ResourceLoader.load_threaded_request(path,"PackedScene")
	if error==OK:
		while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS: await city.get_tree().process_frame
	if error!=OK or ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED:
		cover.queue_free();city.preparing=false;city.paused=false;city.bunny.can_move=true;session.active=true
		city.hud.notify("小船还没准备好，请稍后再来。");return
	var prepared: PackedScene=ResourceLoader.load_threaded_get(path)
	var result: Dictionary
	if session.is_online():result=await session.request_online("travel",{"destination":destination})
	else:result=session.dispatch("travel",{"destination":destination})
	if not result.ok:
		cover.queue_free();city.preparing=false;city.paused=false;city.bunny.can_move=true;session.active=true;return
	session.set_meta("preloaded_map",prepared)
	city.get_tree().change_scene_to_file.call_deferred(session.scene_path())
