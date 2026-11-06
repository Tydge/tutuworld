extends Node3D
const G=preload("res://scripts/geometry.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Animals=preload("res://scripts/characters/animal_factory.gd")
const Outfit=preload("res://scripts/city/outfit.gd")
const WanderNavigation=preload("res://scripts/city/wander_navigation.gd")
const Driver=preload("res://scripts/city/npc_driver.gd")
const CropVisual=preload("res://scripts/city/crop_visual.gd")
const HUD=preload("res://scripts/ui/city_hud.gd")
const People=preload("res://scripts/city/npc_profiles.gd")
const SkyPalette=preload("res://scripts/city/sky_palette.gd")
const AmbientLife=preload("res://scripts/city/ambient_life.gd")
const Culinary=preload("res://scripts/city/culinary.gd")
const Props=preload("res://scripts/city/work_props.gd")
const FurnitureAccess=preload("res://scripts/city/furniture_access.gd")
const ConversationAccess=preload("res://scripts/city/conversation_access.gd")
@export var map_id:="city"
var preparing := false
var session: Node
var scenery: Node3D
var bunny: CharacterBody3D
var camera: Camera3D
var hud: CanvasLayer
var paused := false
var yaw := .20
var pitch := .35
var distance_ := 13.5
var camera_focus := Vector3.ZERO
var current_target := ""
var quick_action: Dictionary={}
var npc_neckwear: Dictionary={}
var talking_npc := ""
var dialogue_text := ""
var previous_dialogues: Dictionary={}
var targets: Dictionary={}
var crops: Dictionary={}
var resources: Dictionary={}
var navigation: Node
var npcs: Array[CharacterBody3D]=[]
var dining_active:=false
var dining_target:="dining"
var dining_chair: Node3D
var culinary: Node3D
var tools: Node3D
var marker: MeshInstance3D
var clock := 0.0
var update_timer := 0.0
var return_from_nap: Marker3D
var nap_exit := Vector3.ZERO
var nap_active := false
var ambience: AudioStreamPlayer
var sun: DirectionalLight3D
var atmosphere: Environment
var screenshot_busy := false
var job_start := Vector3.ZERO
var last_outfit: Dictionary={}
var occluders: Array=[]
var lamps: Array[Node]=[]
var night_windows: Array[StandardMaterial3D]=[]
var cloud_meshes: Array[GeometryInstance3D]=[]
var lamp_visuals: Array=[]
var lighting_timer := 1.0
var occlusion_timer := 0.0
var sky_drift_timer := 0.0
var cached_warmth := -1.0
var camera_query: PhysicsShapeQueryParameters3D
var life: Node3D
var home: Node3D
var interiors: Array[Node3D]=[]
var sleep_active:=false
var sleep_exit:=Vector3.ZERO
var ambient_day:=1.0
var fountain_glow: OmniLight3D
var online_view: Node
var network_action_pending:=false
var network_action_approved:=false
var network_interaction_pending:=false
var kitchen_target:="kitchen"
var build_mode: Node
func _ready() -> void:
	preload("res://scripts/city/render_budget.gd").ensure(self)
	session=get_node("/root/Session")
	session.player_started=true
	scenery=load("res://scenes/valley_map.scn" if map_id=="valley" else "res://scenes/city_map.tscn").instantiate()
	add_child(scenery)
	preload("res://scripts/city/scenery_polish.gd").apply(scenery)
	scenery.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	home=scenery.get_node_or_null("ValleyHome" if map_id=="valley" else "SeabreezeHome")
	if is_instance_valid(home): interiors.append(home)
	for id in ["farm","tools","clothes","workshop"]:
		var interior:=scenery.get_node_or_null("Workshop" if id=="workshop" else "Shop_"+id)
		if is_instance_valid(interior) and interior.get_script()==load("res://scripts/city/seabreeze_home.gd"): interiors.append(interior)
	prepare_scenery()
	if map_id=="city" and not session.is_online():
		preload("res://scripts/city/town_shore.gd").ensure(scenery)
		preload("res://scripts/building/site.gd").ensure(scenery)
		refresh_land_parcels();session.changed.connect(refresh_land_parcels)
	sun=scenery.get_node("Sun")
	fountain_glow=scenery.get_node_or_null("CentralPark/Fountain/FountainGlow")
	if fountain_glow==null:fountain_glow=scenery.get_node_or_null("CentralPark/FountainGlow")
	lamps=scenery.get_node("Streetlights").get_children()
	var window_copies: Dictionary={}
	var sea_original: ShaderMaterial=scenery.get_node("Island").get_meta("sea_material")
	var sea_copy: ShaderMaterial=sea_original.duplicate()
	for node in scenery.find_children("*","GeometryInstance3D",true,false):
		if node.material_override==sea_original:
			node.material_override=sea_copy
			# The ocean spans the map; distance to its batch origin is not distance to water.
			node.visibility_range_end=0.
			node.visibility_range_end_margin=0.
		if node.material_override is StandardMaterial3D and node.material_override.albedo_color.is_equal_approx(Color("638c8b")):
			var id: int=node.material_override.get_instance_id()
			if not window_copies.has(id):
				window_copies[id]=node.material_override.duplicate()
				night_windows.append(window_copies[id])
			node.material_override=window_copies[id]
	scenery.get_node("Island").set_meta("sea_material",sea_copy)
	for lamp_ in lamps:
		for part in ["GlowGlass","LanternHalo","WarmPool"]:
			var mesh_: MeshInstance3D=lamp_.get_node(part)
			mesh_.material_override=mesh_.material_override.duplicate()
		lamp_visuals.append({"light":lamp_.get_node("NightLight"),"glass":lamp_.get_node("GlowGlass").material_override,"halo":lamp_.get_node("LanternHalo").material_override,"pool":lamp_.get_node("WarmPool").material_override})
		var lamp_light: OmniLight3D=lamp_.get_node("NightLight")
		lamp_light.distance_fade_enabled=false
		lamp_light.shadow_enabled=absf(lamp_.position.x)<5 and absf(lamp_.position.z-5)<1
		lamp_light.shadow_blur=1.65
		lamp_light.shadow_bias=.06
		lamp_light.shadow_normal_bias=.70
	for node in scenery.get_children():
		if str(node.name).begins_with("Cloud"):
			for mesh_ in node.find_children("*","GeometryInstance3D",true,false): cloud_meshes.append(mesh_)
	atmosphere=scenery.get_node("Atmosphere").environment.duplicate(true)
	scenery.get_node("Atmosphere").environment=atmosphere
	if RenderingServer.get_current_rendering_method()=="gl_compatibility":
		atmosphere.tonemap_mode=Environment.TONE_MAPPER_FILMIC
		atmosphere.tonemap_exposure=.9
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		atmosphere.ssao_enabled=true
		atmosphere.ssao_radius=.65
		atmosphere.ssao_intensity=.85
		atmosphere.ssao_power=1.15
		atmosphere.ssao_detail=.6
		atmosphere.ssao_light_affect=.12
		sun.light_angular_distance=.35
	bunny=Animals.create(session.settings.get("player_species","bunny"))
	bunny.name="Player"
	add_child(bunny)
	var pos: Array=session.state().player_position
	bunny.position=Vector3(pos[0],maxf(.1,pos[1]),pos[2])
	bunny.world=self
	bunny.collision_mask=15
	# Clothing nodes are attached at runtime; bunny.tscn remains byte-for-byte intact.
	Outfit.apply(bunny,session.state().equipment)
	camera=Camera3D.new()
	camera.name="FollowCamera"
	camera.cull_mask &= ~preload("res://scripts/city/interior_view.gd").REFLECTION_LAYER
	camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.current=true
	camera.fov=48
	camera.near=.1
	camera.far=1200
	add_child(camera)
	camera_query=PhysicsShapeQueryParameters3D.new()
	var camera_body:=SphereShape3D.new();camera_body.radius=.24
	camera_query.shape=camera_body;camera_query.margin=.03
	camera_query.collision_mask=9
	camera_query.exclude=[bunny.get_rid()]
	camera_focus=bunny.position+Vector3(0,1.35,0)
	camera.position=camera_focus+Vector3(3,6,12)
	tools=Props.new()
	tools.bunny=bunny
	add_child(tools)
	hud=HUD.new()
	hud.city=self
	add_child(hud)
	marker=G.ball(self,Vector3.ZERO,Vector3.ONE*.09,G.mat("f1cc7b",.5,.15),"NearbyMarker")
	marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	setup_occluders()
	setup_targets()
	preload("res://scripts/valley/boat_travel.gd").attach(self)
	if map_id=="city":
		culinary=Culinary.new()
		culinary.city=self
		add_child(culinary)
	navigation=WanderNavigation.new()
	add_child(navigation)
	spawn_npcs()
	if session.is_online():
		online_view=preload("res://scripts/city/online_world.gd").new();online_view.city=self;add_child(online_view)
	life=AmbientLife.new()
	if map_id=="valley":
		life.origins.assign([Vector3(-15,1.8,20),Vector3(-8,1.8,6),Vector3(8,2,8),Vector3(-25,1.8,-17),Vector3(23,2,-19),Vector3(-20,2,-35),Vector3(18,1.9,-32),Vector3(33,2,18)])
		life.woodland=true
		life.height_sampler=preload("res://scripts/valley/valley_layout.gd").height_at
		for i in range(life.origins.size()): life.origins[i].y+=life.height_sampler.call(life.origins[i].x,life.origins[i].z)
	add_child(life)
	session.changed.connect(refresh_world)
	session.time_adjusted.connect(update_lighting)
	session.equipment_changed.connect(func(): Outfit.apply(bunny,session.state().equipment))
	session.event_received.connect(on_event)
	ambience=AudioStreamPlayer.new()
	ambience.stream=load("res://assets/garden_ambience.wav")
	ambience.volume_db=-24
	add_child(ambience)
	ambience.finished.connect(ambience.play)
	ambience.play()
	var spatial:=preload("res://scripts/city/spatial_ambience.gd").new();spatial.name="SpatialAmbience";spatial.city=self;add_child(spatial)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(.001,float(session.settings.volume))))
	AudioServer.set_bus_mute(0,not session.settings.sound)
	session.active=true
	refresh_world()
	if map_id=="city" and not session.is_online():
		build_mode=preload("res://scripts/building/editor.gd").new();build_mode.name="BuildingEditor";build_mode.city=self;add_child(build_mode)
	if session.state().get("rest_mode","")=="sleep": enter_sleep(true)
	if not session.test_mode or OS.get_cmdline_user_args().has("--warmup-test"):
		await preload("res://scripts/city/scene_preparation.gd").run(self)
func prepare_scenery() -> void: pass
func setup_targets() -> void:
	if is_instance_valid(home):
		if home.has_node("Furnishing/bed/ActionAnchor"):
			var bed: Node3D=home.get_node("Furnishing/bed")
			targets["home_bed"]={"kind":"bed","node":bed,"position":bed.global_position,"radius":1.65}
		targets["home_door"]={"kind":"home_door","position":home.door_action_position(),"radius":4.6,"node":home}
		for id in ["home_sofa","home_desk"]:
			var seat: Node3D=home.seat_node(id)
			preload("res://scripts/city/seating.gd").ensure(seat,2 if id=="home_sofa" else 1)
			targets[id]={"kind":"bench","position":seat.get_node("ExitAnchor").global_position,"radius":1.65,"node":seat,"label":"坐在沙发上歇一会儿" if id=="home_sofa" else "坐到窗边，发会儿呆"}
	targets["kitchen"]={"kind":"kitchen","position":scenery.get_node("Kitchen/PotSteam").global_position,"radius":2.6}
	targets["dining"]={"kind":"dining","position":scenery.get_node("DiningTable/MealAnchor").global_position,"radius":2.8}
	for p in DB.plots():
		targets[p.id]={"kind":"plot","position":Vector3(p.x,0,p.z),"radius":2.1}
		var visual:=CropVisual.new()
		visual.position=Vector3(p.x,.17,p.z)
		add_child(visual)
		crops[p.id]=visual
	preload("res://scripts/city/production_facilities.gd").register(self)
	preload("res://scripts/city/production_facilities.gd").refresh(self,session.authority)
	setup_resources()
	preload("res://scripts/city/interaction_targets.gd").add_benches(self)
func setup_resources() -> void:
	for r in DB.resources(map_id):
		targets[r.id]={"kind":"resource","position":Vector3(r.x,r.get("y",0.0),r.z),"radius":1.95,"item":r.item}
		var visual: Node3D
		if r.item=="orange":
			var tree_: Node3D=preload("res://scripts/city/scenery_polish.gd").tree_at(scenery,Vector3(r.x,r.get("y",0.0),r.z))
			visual=preload("res://scripts/city/resource_visual.gd").fruit_cluster(tree_)
			targets[r.id].radius=3.3
		else:
			visual=preload("res://scripts/city/resource_visual.gd").make(r.item)
			add_child(visual);visual.position=Vector3(r.x,r.get("y",0.0)+.06,r.z)
		visual.name=r.id;resources[r.id]=visual
func spawn_npcs() -> void:
	var candidates: Array[String]=["Merchant_farm","Merchant_tools","Merchant_clothes","Passerby0","Passerby1","Passerby2","Passerby3"]
	var decoration_rng:=RandomNumberGenerator.new()
	decoration_rng.randomize()
	var neck_items: Array[String]=[]
	for id in DB.catalog().items:
		if DB.item(id).get("slot","")=="neck": neck_items.append(id)
	for i in range(2):
		var index:=decoration_rng.randi_range(0,candidates.size()-1)
		npc_neckwear[candidates.pop_at(index)]=neck_items[decoration_rng.randi_range(0,neck_items.size()-1)]
	npc_neckwear["CatTeacher"]="bell_red"
	var definitions := [["Merchant_farm","春芽","farm","beret_sage","apron_sage"],["Merchant_tools","木木","tools","beret_plaid_honey","vest_sage"],["Merchant_clothes","云朵","clothes","bow_rose","vest_rose"]]
	for d in definitions:
		var position_: Vector3=scenery.get_node("Shop_"+d[2]+"/MerchantAnchor").global_position
		var n:=spawn_npc(d[0],d[1],position_,{"head":d[3],"body":d[4]})
		targets[d[0]]={"kind":"shop","position":position_,"radius":3.3,"shop":d[2],"node":n,"name":d[1]}
	var random:=RandomNumberGenerator.new()
	random.seed=23093
	for i in range(4):
		var x: float=-16+i*8.0
		var z: float=16 if i%2 else -16
		var person: Dictionary=People.PEOPLE[i]
		var n:=spawn_npc("Passerby%d"%i,person.name,Vector3(x,.1,z),{"head":person.head,"body":person.body})
		var driver:=Driver.new()
		driver.bunny=n
		driver.city=self
		driver.speed=random.randf_range(1.15,1.7)
		n.add_child(driver)
		targets[str(n.name)]={"kind":"npc","position":n.position,"radius":2.6,"node":n,"name":person.name,"profile":i}
	var teacher:=spawn_npc("CatTeacher","猫咪老师",Vector3(-10,.1,17.7),{},"cat_teacher")
	var teacher_driver:=Driver.new()
	teacher_driver.bunny=teacher
	teacher_driver.city=self
	teacher_driver.speed=.9
	teacher.add_child(teacher_driver)
	targets["CatTeacher"]={"kind":"npc","position":teacher.position,"radius":3.0,"node":teacher,"name":"猫咪老师","profile":4}
	var panda:=spawn_npc("Youmu","又木",Vector3(16,.1,19.5),{"head":"beret_plaid_sage","neck":"scarf_red"},"panda")
	var panda_driver:=Driver.new();panda_driver.bunny=panda;panda_driver.city=self;panda.add_child(panda_driver)
	targets["Youmu"]={"kind":"npc","position":panda.position,"radius":3.0,"node":panda,"name":"又木","profile":5}
func spawn_npc(id: String,label_: String,p: Vector3,equipment: Dictionary,species: String="bunny") -> CharacterBody3D:
	var n: CharacterBody3D=Animals.create(species)
	n.name=id
	n.collision_layer=2
	n.collision_mask=15
	add_child(n)
	n.position=p
	n.world=null
	var worn:=equipment.duplicate()
	if npc_neckwear.has(id): worn.neck=npc_neckwear[id]
	n.set_meta("equipment",worn)
	Outfit.apply(n,worn)
	optimize_npc(n)
	var label:=G.text3d(n,label_,Vector3(0,n.rig_profile.name_height,0),23,Color("fff7dc"))
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size=6
	label.outline_modulate=Color("557963")
	npcs.append(n)
	return n
func _process(delta: float) -> void:
	if preparing: return
	if is_instance_valid(build_mode) and build_mode.active:return
	clock+=delta
	bunny.speed_multiplier=session.authority.multiplier("move")
	bunny.run_speed_multiplier=session.authority.multiplier("run_speed")
	bunny.stamina_fraction=float(session.state().stamina)/session.authority.stamina_max()
	session.authority.running=bunny.is_running and not paused and not preparing
	session.authority.sleeping=sleep_active
	if talking_npc!="" and (not targets.has(talking_npc) or not ConversationAccess.can_talk(self,bunny,targets[talking_npc])):
		end_dialogue()
	elif talking_npc!="" and targets[talking_npc].kind=="shop":
		var actor: Node3D=targets[talking_npc].node
		var face: Vector3=bunny.position-actor.position
		actor.visual.rotation.y=lerp_angle(actor.visual.rotation.y,atan2(face.x,face.z),1-exp(-delta*9))
	if nap_active and bunny.action=="":
		if not leave_seat():bunny.play_action("nap",1)
	update_camera(delta)
	update_ambient_lighting()
	update_occluders(delta)
	if not session.is_online() and not session.job().is_empty() and bunny.position.distance_to(job_start)>1.0: cancel_action()
	update_timer+=delta
	if update_timer>.13:
		update_timer=0
		update_target()
	lighting_timer+=delta
	if lighting_timer>=.5:
		lighting_timer=0
		update_lighting()
		for n in npcs: n.visible=float(n.get_meta("presence",1.0))>0 and n.position.distance_to(bunny.position)<65
	session.set_player_position(sleep_exit if sleep_active else bunny.position)
	marker.visible=current_target!="" and not paused and not sleep_active and session.job().is_empty() and not hud.photo_mode
	if marker.visible: marker.position=target_position(current_target)+Vector3(0,1.5+sin(clock*3)*.08,0)
	if update_timer==0:
		for node in crops.values():
			if is_instance_valid(node.marker): node.marker.visible=node.position.distance_to(bunny.position)<12

func update_camera(delta: float) -> void:
	camera_focus=camera_focus.lerp(bunny.get_global_transform_interpolated().origin+Vector3(0,.35, -.45) if sleep_active else bunny.get_global_transform_interpolated().origin+Vector3(0,1.35,0),1-exp(-delta*9))
	var room_weight: float=interior_weight()
	var view_pitch: float=lerpf(pitch,maxf(pitch,.65),room_weight) if preload("res://scripts/city/interior_view.gd").mode(self)==0 else pitch
	var offset:=Vector3(sin(yaw)*cos(view_pitch),sin(view_pitch),cos(yaw)*cos(view_pitch))*distance_
	var desired:=camera_focus+offset
	var candidate: Vector3=camera.position.lerp(desired,1-exp(-delta*8))
	var pivot: Vector3=bunny.get_global_transform_interpolated().origin+Vector3(0,1.35,0)
	camera.position=camera_safe_position(pivot,candidate)
	camera.position.y=maxf(1,camera.position.y)
	camera.look_at(camera_focus)
func camera_safe_position(pivot: Vector3,desired: Vector3) -> Vector3:
	var view=preload("res://scripts/city/interior_view.gd");var full: bool=view.mode(self)==view.FULL and view.indoors(self,pivot-Vector3.UP*1.35)
	camera_query.collision_mask=13 if full else 9
	camera_query.exclude=[]
	if is_instance_valid(build_mode) and is_instance_valid(build_mode.room):
		build_mode.room.apply_storey_visibility(bunny.global_position)
		camera_query.exclude=build_mode.room.hidden_camera_bodies
	var space:=get_world_3d().direct_space_state
	# A cliff can overlap the small camera pivot even when the avatar's feet are clear.
	# Resolve that overlap before sweeping; cast_motion intentionally ignores initial overlaps.
	camera_query.motion=Vector3.ZERO
	for attempt in range(5):
		camera_query.transform=Transform3D(Basis.IDENTITY,pivot)
		var contact:=space.get_rest_info(camera_query)
		if contact.is_empty(): break
		var normal: Vector3=contact.normal
		pivot+=normal*clampf(.29-(pivot-contact.point).dot(normal),.03,.4)
	camera_query.transform=Transform3D(Basis.IDENTITY,pivot);camera_query.motion=desired-pivot
	var fractions:=space.cast_motion(camera_query)
	var safe:=desired
	if fractions.size()==2 and fractions[0]<1:
		safe=pivot+(desired-pivot)*maxf(0,fractions[0]-.05/maxf(.1,pivot.distance_to(desired)))
	return view.roof_limit(self,pivot,safe) if full else safe
func respawn_position() -> Vector3: return Vector3(0,1,7)
func navigation_bounds() -> Rect2i:
	return Rect2i(-52,-46,215,93) if session.has_method("is_online") and not session.is_online() else Rect2i(-52,-46,105,93)
func can_navigate(p: Vector3) -> bool: return can_walk(p)
func can_walk(p: Vector3) -> bool:
	for building_ in interiors:
		if building_.contains_position(p): return true
	if session.has_method("is_online") and not session.is_online():
		return preload("res://scripts/city/town_shore.gd").can_walk(p) or preload("res://scripts/building/site.gd").contains(p)
	return Vector2(p.x,p.z/.88).length()<52
func update_target() -> void:
	preload("res://scripts/city/production_facilities.gd").refresh(self,session.authority)
	if sleep_active:
		current_target=str(session.state().get("rest_bed","home_bed"));quick_action.clear();hud.set_prompt("E   起床，伸个懒腰     ·     睡眠中 · 耐力恢复 +100%")
		return
	if nap_active:
		quick_action.clear();hud.set_prompt("E   起身，继续散步")
		return
	if talking_npc!="":
		quick_action.clear()
		hud.set_prompt("E   看看商品     Esc 离开" if targets.get(talking_npc,{}).get("kind","")=="shop" else "E   结束聊天，继续散步")
		return
	if paused or not session.job().is_empty(): quick_action.clear(); hud.set_prompt(""); return
	var nearest:=999.0
	current_target=""
	for id in targets:
		var t: Dictionary=targets[id]
		if t.kind=="land" and preload("res://scripts/building/parcels.gd").owner(session.state(),t.parcel_id)!="":continue
		if t.kind=="resource" and not session.state().resources[id].available: continue
		if t.kind=="npc" and not t.node.get_meta("interaction_available",true): continue
		if t.has("node") and t.kind=="npc": t.position=t.node.position
		var distance: float=Vector2(bunny.position.x-t.position.x,bunny.position.z-t.position.z).length()
		if t.kind not in ["bed","bench","npc","shop"] and absf(bunny.position.y-t.position.y)>1.7:continue
		if t.kind=="dining" and t.has("node"):
			distance=preload("res://scripts/city/dining_service.gd").proximity(self,id)
		if t.kind=="kitchen" and t.has("node") and not facility_access(id):continue
		if t.kind in ["shop","npc"] and distance<float(t.radius) and not ConversationAccess.can_talk(self,bunny,t):continue
		if t.kind in ["bed","bench"] and t.has("node"):
			distance=FurnitureAccess.distance(t.node,bunny.global_position)
			if distance>=FurnitureAccess.REACH or not FurnitureAccess.reachable(self,t.node,bunny):continue
		if distance<float(t.radius) and distance<nearest:
			nearest=distance
			current_target=id
	var text: String=""
	if current_target!="":
		var t: Dictionary=targets[current_target]
		match t.kind:
			"plot":
				var p: Dictionary=session.state().plots[current_target]
				text="E   选择种子，播种" if p.crop=="" else "E   照料 %s · %d%%"%[DB.crop(p.crop).name,int(float(p.growth)/(float(DB.crop(p.crop).days)*3600)*100)]
			"land": text="E   查看"+preload("res://scripts/building/parcels.gd").title(t.parcel_id)+" · 100贝壳币"
			"home_door": text="E   "+("轻轻关上门" if t.get("node",home).door_open else "推开门，走进"+t.get("name","海风小屋"))
			"well": text="E   打水 · 2 秒 · 水量 %d/%d"%[session.authority.water_left(),DB.water_capacity(session.authority.watering_can_id())]
			"workshop": text="E   制造工作台 · 制造道具"
			"kitchen": text="E   "+t.get("name","海风小厨房")+" · 烹饪料理"
			"dining": text="E   入座用餐 · 选择料理"
			"boat": text="E   坐船回海岛城 · 免费" if map_id=="valley" else "E   坐船去眠风山谷 · 10 贝壳币"
			"resource":
				var locked: String=session.authority.resource_lock_reason(t.item)
				text="E   %s · %s"%[DB.item(t.item).name,locked] if locked!="" else "E   %s %s · %s 秒 · %d 耐力"%["采摘" if t.item=="orange" else "采集",DB.item(t.item).name,str(snappedf(session.authority.action_duration("gather",t.item),.1)),preload("res://scripts/services/character_stats.gd").work_tier(t.item)]
			"shop": text="E   和%s聊聊"%t.name
			"npc": text=("E   轻声看看%s · 熟睡中" if t.node.sleeping else "E   和%s聊聊天")%t.name
			"bench": text="E   "+t.get("label","坐下来发会儿呆")
			"bed": text="E   躺下来睡觉 · 耐力恢复 +100%"
	quick_action=find_quick_action()
	if not quick_action.is_empty():
		text+=("\n" if text!="" else "")+"F   "+quick_action.label+" · %.1f 秒"%session.authority.action_duration(quick_action.verb)
	if session.is_online() and current_target!="":
		var occupied: Dictionary=session.online_locks.get(map_id+":"+current_target,{})
		var selected_target: Dictionary=targets[current_target]
		if selected_target.kind=="bench" and selected_target.has("node"):
			var seats=preload("res://scripts/city/seating.gd");var free:=0
			for slot in range(seats.capacity(selected_target.node)):
				if not session.online_locks.has(map_id+":"+seats.lock_target(current_target,slot)):free+=1
			if seats.capacity(selected_target.node)>1:text+=" · 空位 %d/%d"%[free,seats.capacity(selected_target.node)]
			if free==0:text="座位已坐满"
		elif not occupied.is_empty() and occupied.owner!=session.active_character_id:text=str(occupied.name)+"正在使用"
	hud.set_prompt(text)
func find_quick_action() -> Dictionary:
	# E, F and the floating selection marker always share this one target.
	if not targets.has(current_target) or targets[current_target].kind!="plot": return {}
	if bunny.position.distance_to(target_position(current_target))>3.3: return {}
	var p: Dictionary=session.state().plots[current_target]
	if p.crop=="": return {}
	if session.authority.crop_lock_reason(p.crop)!="": return {}
	var need: Dictionary=session.authority.needs(p)
	var verb: String=""
	if need.ready: verb="harvest"
	elif need.water and session.authority.watering_can_id()!="": verb="water"
	elif need.weed and session.authority.count("herbicide")>0: verb="weed"
	elif need.water: verb="water"
	elif need.weed: verb="weed"
	if verb=="": return {}
	return {"target":current_target,"verb":verb,"label":{"water":"浇水","weed":"除草","harvest":"收获"}[verb]+" · "+DB.crop(p.crop).name}
func quick_interact() -> Dictionary:
	if paused or preparing or talking_npc!="" or bunny.action!="" or not session.job().is_empty(): return {"ok":false,"message":"先完成当前互动吧。"}
	quick_action=find_quick_action()
	if quick_action.is_empty(): return {"ok":false,"message":"选中的这块地暂时没有可快捷完成的照料。"}
	return begin_action(quick_action.verb,quick_action.target)
func target_position(id: String) -> Vector3:
	var target: Dictionary=targets.get(id,{})
	if target.get("kind","")=="dining" and target.has("node"):
		var seats:=preload("res://scripts/city/dining_service.gd").candidates(self,id)
		if not seats.is_empty():return FurnitureAccess.closest(seats[0],bunny.global_position)
	if target.get("kind","") in ["bed","bench"] and target.has("node"):return FurnitureAccess.closest(target.node,bunny.global_position)
	return target.get("position",bunny.position)
func is_text_entry_active() -> bool:
	if is_instance_valid(online_view) and is_instance_valid(online_view.chat_card) and online_view.chat_card.visible:return true
	var focus:=get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit
func _unhandled_input(event: InputEvent) -> void:
	if preparing:return
	if is_instance_valid(build_mode) and build_mode.active:return
	if is_instance_valid(online_view) and is_instance_valid(online_view.chat_card) and online_view.chat_card.visible:return
	if event.is_action_pressed("pause"):
		if sleep_active and not hud.overlay.visible: wake_from_bed()
		elif talking_npc!="": end_dialogue()
		elif not session.job().is_empty(): cancel_action()
		elif hud.overlay.visible: hud.close_panel()
		else: hud.open_panel("settings")
		get_viewport().set_input_as_handled()
		return
	if is_text_entry_active():return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_V and not paused and hud.camera_control.visible:hud.camera_control.cycle();get_viewport().set_input_as_handled();return
		if event.keycode==KEY_F6:open_build_mode();get_viewport().set_input_as_handled();return
		if event.keycode==KEY_C: toggle_panel("profile"); return
		if event.keycode in [KEY_I,KEY_B]: toggle_panel("bag"); return
		if event.keycode==KEY_TAB: toggle_panel("wardrobe"); return
		if event.keycode==KEY_M: toggle_panel("map"); return
	if event.is_action_pressed("photo"):
		hud.toggle_photo()
	if event.is_action_pressed("screenshot"): take_photo()
	if paused: return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw-=event.relative.x*.006*float(session.settings.camera_speed)
		pitch=clampf(pitch+event.relative.y*.004,.12,1.1)
	if preload("res://scripts/services/camera_zoom.gd").accepts(event):
		distance_=preload("res://scripts/services/camera_zoom.gd").distance_for(event,distance_,.75,4.5,22.)
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("quick_interact") and not event.is_echo():
		quick_interact()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("interact") and (bunny.action=="" or sleep_active or nap_active): interact()
	if event.is_action_pressed("daydream") and bunny.action=="": bunny.play_action("confused",2.5,"?")
func toggle_panel(kind: String) -> void:
	if hud.overlay.visible and hud.mode==kind: hud.close_panel()
	else: hud.open_panel(kind)
func refresh_land_parcels() -> void:
	if not is_instance_valid(scenery):return
	preload("res://scripts/building/site.gd").update_ownership(scenery,session.state())
	var land=preload("res://scripts/building/parcels.gd")
	for id in land.IDS:
		targets["land:"+id]={"kind":"land","parcel_id":id,"position":land.sign_position(id),"radius":land.SIGN_REACH}

func open_build_mode() -> void:
	if not is_instance_valid(build_mode):hud.notify("建造园目前只在单人城镇开放。");return
	var result: Dictionary=build_mode.open_nearby_parcel()
	if not result.ok:hud.notify(result.message)
func interact() -> void:
	if sleep_active: wake_from_bed();return
	if session.is_online() and nap_active:online_stand();return
	if nap_active:leave_seat();return
	if talking_npc!="":
		if not targets.has(talking_npc) or not ConversationAccess.can_talk(self,bunny,targets[talking_npc]):end_dialogue();update_target();return
		if targets.get(talking_npc,{}).get("kind","")=="shop":
			hud.shop=targets[talking_npc].shop;hud.shop_tab="buy"
			end_dialogue();hud.open_panel("shop")
			return
		end_dialogue()
		return
	if current_target=="": return
	var t: Dictionary=targets[current_target]
	if t.kind in ["shop","npc"] and not ConversationAccess.can_talk(self,bunny,t):update_target();return
	if t.kind in ["bed","bench"] and t.has("node") and not FurnitureAccess.reachable(self,t.node,bunny):update_target();return
	if session.is_online() and t.kind in ["npc","bench","bed","home_door"]:
		online_interact(current_target);return
	match t.kind:
		"home_door":
			var result: Dictionary=t.get("node",home).toggle_door(bunny)
			if result.message!="": hud.notify(result.message)
			update_target()
		"land":
			if not preload("res://scripts/building/parcels.gd").at_sign(bunny.global_position,t.parcel_id):update_target();return
			hud.land_parcel_id=t.parcel_id;hud.open_panel("land")
		"plot": hud.open_panel("plot")
		"kitchen":
			if t.has("node") and not facility_access(current_target):update_target();return
			kitchen_target=current_target;hud.open_panel("kitchen")
		"workshop": hud.open_panel("workshop")
		"well": begin_action("refill",current_target)
		"dining":
			dining_target=current_target;hud.open_panel("dining")
		"bed": enter_sleep()
		"boat": preload("res://scripts/valley/boat_travel.gd").go(self)
		"resource": begin_action("gather",current_target)
		"shop":
			talking_npc=current_target
			var hour:=fposmod(float(session.state().time)/3600*24,24)
			dialogue_text=People.line_for_npc(current_target,previous_dialogues.get(current_target,""),hour)
			previous_dialogues[current_target]=dialogue_text
			hud.show_dialogue(t.node,t.name,dialogue_text,"E · 看看商品   Esc 离开")
		"npc":
			if not t.node.get_meta("interaction_available",true): return
			talking_npc=current_target
			dialogue_text=People.line_for(int(t.profile),previous_dialogues.get(current_target,""),fposmod(float(session.state().time)/3600*24,24))
			previous_dialogues[current_target]=dialogue_text
			hud.show_dialogue(t.node,t.name,dialogue_text)
		"bench":
			var seats=preload("res://scripts/city/seating.gd");var slot: int=seats.local_slot(self,t.node,bunny)
			if slot<0:hud.notify("座位已坐满，稍等一下吧。");return
			var landing:=FurnitureAccess.landing(self,t.node,bunny,bunny.global_position)
			if landing.is_empty():hud.notify("座位旁暂时没有起身的位置，请先留出通道。");return
			nap_exit=landing.position;set_meta("resting_furniture",t.node);bunny.sit_on_surface(seats.seat(t.node,slot));nap_active=true;bunny.play_action("nap",6,"z z Z");update_target()
func leave_seat() -> bool:
	var seat: Node3D=get_meta("resting_furniture",null)
	var landing:=FurnitureAccess.landing(self,seat,bunny,nap_exit) if is_instance_valid(seat) else {}
	if landing.is_empty():hud.notify("座位旁暂时没有空位，请稍后起身。");return false
	bunny.stand_up(landing.position);nap_active=false;set_meta("resting_furniture",null);session.set_player_position(landing.position);update_target();return true
func end_dialogue() -> void:
	if session.is_online() and talking_npc!="" and targets.get(talking_npc,{}).get("kind","")=="npc":session.dispatch("end_talk")
	talking_npc=""
	hud.hide_dialogue()
func enter_sleep(restoring: bool=false) -> void:
	var id: String=str(session.state().get("rest_bed","home_bed")) if restoring else current_target
	var bed: Node3D=targets.get(id,{}).get("node")
	if id=="home_bed" and is_instance_valid(home):bed=home.get_node_or_null("Furnishing/bed")
	if not is_instance_valid(bed) or not bed.has_node("SleepExit"):return
	var exit_: Vector3=bed.get_node("SleepExit").global_position
	if not restoring:
		var landing:=FurnitureAccess.landing(self,bed,bunny,bunny.global_position)
		if landing.is_empty():hud.notify("床边暂时没有起身的位置，请先留出通道。");return
		exit_=landing.position
		session.set_player_position(bunny.global_position)
		var result: Dictionary=session.dispatch("rest",{"target":id})
		if not result.ok:return
	else:
		var saved: Array=session.state().get("net_pose",{}).get("exit",session.state().player_position) if session.is_online() else session.state().player_position
		exit_=Vector3(saved[0],saved[1],saved[2])
	sleep_exit=exit_;set_meta("sleeping_bed",bed)
	nap_active=false;sleep_active=true;bunny.lie_in_bed(bed)
	session.authority.sleeping=true;session.set_player_position(sleep_exit);update_target()
func wake_from_bed() -> void:
	if session.is_online():online_stand();return
	var bed: Node3D=get_meta("sleeping_bed",null)
	var landing:=FurnitureAccess.landing(self,bed,bunny,sleep_exit) if is_instance_valid(bed) else {}
	if landing.is_empty():hud.notify("床边暂时有人或有家具，请稍后起身。");return
	var previous: Array=session.state().player_position.duplicate()
	session.set_player_position(landing.position)
	var result: Dictionary=session.dispatch("wake")
	if not result.ok:session.state().player_position=previous;return
	sleep_active=false;set_meta("sleeping_bed",null);bunny.stand_up(landing.position);session.set_player_position(landing.position);update_target()

func begin_cooking(recipe: String) -> Dictionary: return begin_action("craft",kitchen_target,recipe)
func begin_manufacturing(recipe: String) -> Dictionary: return begin_action("craft",current_target,recipe)
func begin_dining(item: String) -> Dictionary:
	var result:=begin_action("eat",dining_target,item)
	if not result.get("ok",false):hud.notify(result.get("message","暂时无法入座。"))
	return result
func begin_snack(item: String) -> Dictionary: return begin_action("snack","",item)
func begin_action(verb: String,target: String,item: String="") -> Dictionary:
	if session.is_online() and not network_action_approved:
		if network_action_pending:return {"ok":false,"message":""}
		online_begin_action(verb,target,item)
		return {"ok":true,"pending":true,"message":""}
	preload("res://scripts/city/production_facilities.gd").refresh(self,session.authority)
	if sleep_active: return {"ok":false,"message":"先起床，伸个懒腰吧。"}
	if verb!="snack" and bunny.position.distance_to(target_position(target))>3.3: return {"ok":false,"message":"再靠近一点吧。"}
	if verb=="gather" and targets[target].item!="orange" and bunny.position.distance_to(target_position(target))>2.0: return {"ok":false,"message":"再靠近一点，让工具够得着吧。"}
	if targets.get(target,{}).get("kind","")=="kitchen" and targets[target].has("node") and not facility_access(target):return {"ok":false,"message":"料理台前需要留出安全的操作空间。"}
	if targets.get(target,{}).get("kind","")=="workshop" and not targets[target].building.contains_position(bunny.global_position): return {"ok":false,"message":"先走进工坊，再使用工作台吧。"}
	var dining_seat: Dictionary={}
	if verb=="eat" and target!="dining":
		dining_seat=preload("res://scripts/city/dining_service.gd").choose(self,target)
		if dining_seat.is_empty():return {"ok":false,"message":"餐桌旁需要一张朝向餐桌、未被占用且通道畅通的餐椅。"}
	var result: Dictionary={"ok":true} if network_action_approved else session.dispatch(verb,{"target":target,"item":item,"recipe":item,"seat":dining_seat.get("seat","")})
	if result.ok:
		if verb=="eat":
			dining_chair=dining_seat.get("node")
			var seat: Transform3D=preload("res://scripts/city/seating.gd").seat(dining_chair) if is_instance_valid(dining_chair) else scenery.get_node("DiningTable/SeatAnchor").global_transform
			if is_instance_valid(dining_chair):nap_exit=dining_seat.exit
			bunny.sit_on_surface(seat)
			dining_active=true
			culinary.serve(item,preload("res://scripts/city/dining_service.gd").meal_position(self,target,dining_chair) if is_instance_valid(dining_chair) else Vector3.INF)
			bunny.meal_item=item;bunny.meal_origin=culinary.meal.global_position;bunny.meal_elapsed=0.;bunny.meal_duration=float(session.job().duration)
		elif verb=="refill":
			bunny.position=targets[target].work_anchor.global_position;bunny.velocity=Vector3.ZERO;bunny.reset_physics_interpolation()
		elif verb=="craft":
			bunny.position=targets[target].work_anchor.global_position if targets[target].has("work_anchor") else scenery.get_node("Kitchen/CookAnchor").global_position
			bunny.velocity=Vector3.ZERO
			bunny.reset_physics_interpolation()
		session.set_player_position(bunny.position)
		job_start=bunny.position
		bunny.can_move=false
		var animation: String=("gather_stone" if DB.recipe(item).get("station","")=="workshop" else "cook") if verb=="craft" else verb
		if verb=="gather": animation={"limestone":"gather_stone","copper":"gather_copper","branch":"gather_branch","orange":"harvest_tree","birch":"gather_wood","iron":"gather_copper","sandstone":"gather_stone"}.get(targets[target].item,"gather_branch")
		if verb=="craft" and targets[target].has("work_anchor"): bunny.visual.rotation.y=targets[target].work_anchor.global_rotation.y+PI
		elif verb=="eat":bunny.visual.rotation.y=preload("res://scripts/city/seating.gd").seat(dining_chair).basis.get_euler().y if is_instance_valid(dining_chair) else PI
		elif verb=="craft":bunny.visual.rotation.y=PI
		elif verb!="snack": bunny.visual.rotation.y=atan2(target_position(target).x-bunny.position.x,target_position(target).z-bunny.position.z)
		bunny.play_action(animation,float(session.job().duration)+.25,"")
		if verb in ["water","weed","gather"] and animation!="harvest_tree":
			bunny.align_work(target_position(target),1.30 if verb=="gather" else 1.45)
		session.authority.running=false
		tools.target_point=target_position(target)+Vector3(0,(.38 if targets.get(target,{}).get("item","")=="birch" else .65) if verb=="gather" else .18,0)
		if targets.get(target,{}).has("effect_anchor"): tools.target_point=targets[target].effect_anchor.global_position
		tools.show_tool(animation,session.authority.watering_can_id())
	return result
func cancel_action() -> void:
	if session.is_online():
		var result: Dictionary=await session.request_online("cancel")
		if result.get("ok",false):finish_action()
		return
	session.dispatch("cancel")
	finish_action()
func finish_action() -> void:
	bunny.meal_item="";bunny.meal_origin=Vector3.INF;bunny.meal_elapsed=-1.
	bunny.work_align_active=false
	if session.is_online() and session.state().get("net_pose",{}).get("kind","")=="waiting_exit":
		dining_active=false;nap_active=true;bunny.seated=true;bunny.can_move=false;bunny.play_action("nap",INF);tools.hide_tool()
		if is_instance_valid(culinary):culinary.clear_meal()
		return
	if dining_active and is_instance_valid(dining_chair):
		var landing:=FurnitureAccess.landing(self,dining_chair,bunny,nap_exit)
		dining_active=false;culinary.clear_meal()
		if landing.is_empty():
			set_meta("resting_furniture",dining_chair);dining_chair=null;nap_active=true;bunny.play_action("nap",INF);tools.hide_tool();return
		bunny.stand_up(landing.position);session.set_player_position(landing.position);dining_chair=null
	if dining_active:
		var p: Array=session.state().player_position
		bunny.stand_up(Vector3(float(p[0]),float(p[1]),float(p[2])) if session.is_online() else scenery.get_node("DiningTable/ExitAnchor").global_position)
		dining_active=false
		culinary.clear_meal()
	bunny.action=""
	bunny.action_time=0
	bunny.can_move=true
	bunny.mood_label.text=""
	tools.hide_tool()
func on_event(event: Dictionary) -> void:
	if int(event.get("experience",0))>0: hud.gain_experience(int(event.experience))
	if event.get("message","")!="": hud.notify(event.message)
	if event.get("critical",false) or event.get("quality_increased",false):
		var sparkle:=preload("res://scripts/city/reward_sparkle.gd").new()
		add_child(sparkle)
		sparkle.position=target_position(str(event.get("target","")))+Vector3(0,.75,0)
	if event.type in ["completed","rejected"]: finish_action(); refresh_world(); play_tone(620,.12,.10)
func refresh_world() -> void:
	if not session.is_online():session.authority.trade_access=Callable(self,"trade_access");session.authority.facility_access=Callable(self,"facility_access");session.authority.dining_access=Callable(self,"dining_access")
	for id in crops:
		var p: Dictionary=session.state().plots[id]
		crops[id].refresh(p,session.authority.needs(p))
	for id in resources: resources[id].visible=session.state().resources[id].available
func trade_access(shop: String) -> bool:return ConversationAccess.can_trade(self,bunny,shop)
func interior_weight() -> float:
	var weight:=0.0
	for building_ in interiors: weight=maxf(weight,building_.interior_weight)
	return weight
func update_ambient_lighting() -> void:
	# Both room blending and the half-second clock refresh must write the same value.
	var indoors: float=interior_weight()
	atmosphere.ambient_light_energy=lerpf(lerpf(.28,.53,ambient_day),lerpf(.26,.34,ambient_day),indoors)
	atmosphere.ambient_light_color=Color("7894b8").lerp(Color("d5e9ef"),ambient_day).lerp(Color("d9c6a5"),indoors*.60)
func update_lighting(override_time: float=-1) -> void:
	var t:=override_time if override_time>=0 else fmod(float(session.state().time)/3600,1)
	var palette: Dictionary=SkyPalette.at_time(t)
	var day: float=palette.day
	var night: float=palette.night
	ambient_day=day
	sun.light_energy=lerpf(.075,1.45,day)
	sun.light_color=Color("91afe8").lerp(Color("fff6e6"),day)
	sun.shadow_opacity=lerpf(.62,.86,day)
	sun.shadow_blur=1.85
	sun.shadow_bias=.025
	sun.shadow_normal_bias=.65
	sun.rotation_degrees=Vector3(-maxf(22,palette.height*70),-80+t*160,0)
	update_ambient_lighting()
	for building_ in interiors: building_.update_lighting(day)
	atmosphere.fog_light_color=palette.horizon
	atmosphere.fog_density=lerpf(.00055,.0009,day)
	var sky: ShaderMaterial=atmosphere.sky.sky_material
	sky.set_shader_parameter("zenith_color",palette.zenith)
	sky.set_shader_parameter("horizon_color",palette.horizon)
	sky.set_shader_parameter("cloud_color",palette.cloud)
	sky.set_shader_parameter("daylight",day)
	sky.set_shader_parameter("night_amount",night)
	# Night clouds do not need to invalidate a radiance cubemap every few frames.
	if day>.05: sky.set_shader_parameter("drift",clock)
	var sea: ShaderMaterial=scenery.get_node("Island").get_meta("sea_material",null)
	if sea!=null:
		sea.set_shader_parameter("sea_color",palette.sea)
		sea.set_shader_parameter("horizon_color",palette.horizon)
		sea.set_shader_parameter("daylight",day)
	# All street lights follow the day/night cycle, independent of player or camera position.
	var warmth:=1.0-smoothstep(.20,.65,day)
	if absf(warmth-cached_warmth)>.001:
		cached_warmth=warmth
		if is_instance_valid(fountain_glow): fountain_glow.light_energy=.95*warmth
		for entry in lamp_visuals:
			entry.light.visible=warmth>.001
			entry.light.light_energy=2.7*warmth
			entry.glass.emission_energy_multiplier=lerpf(.04,.82,warmth)
			entry.glass.emission=Color("ffd18b")
			entry.halo.set_shader_parameter("strength",.30*warmth)
			entry.pool.set_shader_parameter("strength",.16*warmth)
		for window in night_windows:
			window.albedo_color=Color("638c8b").lerp(Color("f8c775"),warmth)
			window.emission_enabled=true
			window.emission=Color("ffd691")
			window.emission_energy_multiplier=.55*warmth
	if is_instance_valid(life): life.daylight=day
	for mesh_ in cloud_meshes: mesh_.visible=day>.45
func footstep(_p: Vector3) -> void: pass
func play_tone(frequency: float,length: float=.12,volume: float=.1) -> void:
	if not session.settings.sound: return
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=22050
	var data:=PackedByteArray()
	data.resize(int(length*22050)*2)
	for i in range(data.size()/2): data.encode_s16(i*2,int(sin(float(i)/22050*frequency*TAU)*exp(-float(i)/22050*24)*12000))
	stream.data=data
	var player:=AudioStreamPlayer.new()
	player.stream=stream
	player.volume_db=linear_to_db(volume)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
func take_photo() -> void:
	if screenshot_busy: return
	screenshot_busy=true
	var previous:=hud.visible
	hud.visible=false
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://photos")
	var path:="user://photos/海岛城_"+Time.get_datetime_string_from_system().replace(":","-")+".png"
	get_viewport().get_texture().get_image().save_png(path)
	hud.visible=previous
	screenshot_busy=false
	hud.notify("照片已保存："+ProjectSettings.globalize_path(path))
func return_to_title() -> void:
	if session.is_online():await session.leave_online()
	session.active=false
	get_tree().change_scene_to_file("res://scenes/title.tscn")
func _exit_tree() -> void:
	if is_instance_valid(session): session.authority.running=false
	if is_instance_valid(session): session.active=false

func online_begin_action(verb: String,target: String,item: String) -> void:
	network_action_pending=true
	var result: Dictionary=await session.request_online(verb,{"target":target,"item":item,"recipe":item})
	network_action_pending=false
	if not result.get("ok",false):hud.notify(str(result.get("message","暂时不能操作。")));return
	if session.job().is_empty():return
	network_action_approved=true;begin_action(verb,target,item);network_action_approved=false
func online_stand() -> void:
	if network_interaction_pending:return
	network_interaction_pending=true
	var result: Dictionary=await session.request_online("wake" if sleep_active else "stand")
	network_interaction_pending=false
	if not result.get("ok",false):hud.notify(str(result.get("message","稍等一下再起身吧。")));return
	var p: Array=session.state().player_position
	bunny.stand_up(Vector3(float(p[0]),float(p[1]),float(p[2])));sleep_active=false;nap_active=false;home.bed_occupant=null
func online_interact(id: String) -> void:
	if network_interaction_pending:return
	var t: Dictionary=targets[id]
	var verb: String={"npc":"talk","bench":"sit","bed":"rest","home_door":"door"}[t.kind]
	network_interaction_pending=true
	var result: Dictionary=await session.request_online(verb,{"target":id})
	network_interaction_pending=false
	if not result.get("ok",false):hud.notify(str(result.get("message","稍等一下吧。")));return
	if t.kind=="bed":enter_sleep(true)
	elif t.kind=="bench":
		var seats=preload("res://scripts/city/seating.gd");var slot:=int(session.state().get("net_pose",{}).get("slot",0));bunny.sit_on_surface(seats.seat(t.node,slot));nap_exit=seats.exit_position(t.node,slot);nap_active=true;bunny.play_action("nap",INF)
	elif t.kind=="npc":
		talking_npc=id
		dialogue_text=People.line_for(int(t.profile),previous_dialogues.get(id,""),fposmod(float(session.state().time)/3600*24,24))
		previous_dialogues[id]=dialogue_text;hud.show_dialogue(t.node,t.name,dialogue_text)

func optimize_npc(n: CharacterBody3D) -> void:
	var brows: Node3D=n.get_node_or_null("Visual/Head/FixedEyebrows")
	if brows==null: return
	var surfaces:=SurfaceTool.new()
	surfaces.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material: Material
	for part in brows.get_children():
		if part is MeshInstance3D:
			surfaces.append_from(part.mesh,0,part.transform)
			material=part.material_override
			brows.remove_child(part)
			part.queue_free()
	var combined:=MeshInstance3D.new()
	combined.mesh=surfaces.commit()
	combined.material_override=material
	combined.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	brows.add_child(combined)
func setup_occluders() -> void:
	var fade_shader: Shader=load("res://assets/shaders/occlusion_fade.gdshader")
	var trees: Array=scenery.get_children()+scenery.find_children("PublicTree*","Node3D",true,false)
	for tree_ in trees:
		if not str(tree_.name).begins_with("Tree") and not str(tree_.name).begins_with("PublicTree"):continue
		var materials: Array[ShaderMaterial]=[]
		var copies: Dictionary={}
		for mesh_ in tree_.find_children("*","GeometryInstance3D",true,false):
			if mesh_.material_override is ShaderMaterial and mesh_.material_override.shader in [fade_shader,preload("res://assets/shaders/tree_bark.gdshader")]:
				var copy: ShaderMaterial=mesh_.material_override.duplicate()
				mesh_.material_override=copy;materials.append(copy)
				continue
			if not mesh_.material_override is StandardMaterial3D: continue
			var old: StandardMaterial3D=mesh_.material_override
			var id:=old.get_instance_id()
			if not copies.has(id):
				var material:=ShaderMaterial.new()
				material.shader=fade_shader
				material.set_shader_parameter("tint",old.albedo_color)
				material.set_shader_parameter("vertex_tint",old.vertex_color_use_as_albedo)
				copies[id]=material
				materials.append(material)
			mesh_.material_override=copies[id]
		occluders.append({"point":tree_.get_node("Crown").global_position,"materials":materials,"alpha":1.0,"target":1.0})
	# Small placeable roofs use their own material copies and moving local center.
	for fixture in scenery.get_children():
		if not fixture.has_meta("occlusion_section"): continue
		var section: Node3D=fixture.get_node(fixture.get_meta("occlusion_section"))
		var materials: Array[ShaderMaterial]=[]
		for mesh_ in section.find_children("*","MeshInstance3D",true,false):
			if not mesh_.material_override is ShaderMaterial: continue
			var material: ShaderMaterial=mesh_.material_override.duplicate()
			mesh_.material_override=material;materials.append(material)
		occluders.append({"anchor":fixture,"local_point":fixture.get_meta("occlusion_center"),"point":Vector3.ZERO,"radius_squared":2.89,"materials":materials,"alpha":1.0,"target":1.0})
func update_occluders(delta: float) -> void:
	occlusion_timer+=delta
	var check_overlap:=occlusion_timer>=.06
	if check_overlap: occlusion_timer=0
	var start:=bunny.get_global_transform_interpolated().origin+Vector3(0,1.7,0)
	var ray:=camera.position-start
	var ray_length:=maxf(.01,ray.length_squared())
	for tree_ in occluders:
		if check_overlap:
			if tree_.has("anchor"): tree_.point=tree_.anchor.to_global(tree_.local_point)
			var u:=clampf((tree_.point-start).dot(ray)/ray_length,0,1)
			var obscures: bool=u>.05 and tree_.point.distance_squared_to(start+ray*u)<float(tree_.get("radius_squared",7.29))
			tree_.target=0.0 if obscures else 1.0
		var alpha: float=move_toward(tree_.alpha,tree_.target,delta*3.2)
		if is_equal_approx(alpha,tree_.alpha): continue
		tree_.alpha=alpha
		for material in tree_.materials: material.set_shader_parameter("opacity",alpha)

func facility_access(id: String) -> bool:
	var target: Dictionary=targets.get(id,{})
	if target.get("kind","")!="kitchen" or not target.has("node"):return id=="kitchen"
	var node: Node3D=target.node
	if not is_instance_valid(node) or bunny.global_position.distance_to(target.position)>3.3:return false
	if node.has_meta("storey") and preload("res://scripts/building/storeys.gd").at_height(bunny.position.y)!=int(node.get_meta("storey")):return false
	if absf(bunny.position.y-node.global_position.y)>1.25:return false
	if not FurnitureAccess.clear_segment(self,node,bunny,bunny.global_position+Vector3.UP,target.position+Vector3.UP):return false
	return not preload("res://scripts/city/local_landing.gd").find(self,node.get_node("WorkAnchor").global_position,bunny,false).is_empty()

func dining_access(id: String,chair: String) -> bool:
	return preload("res://scripts/city/dining_service.gd").accessible(self,id,chair)
