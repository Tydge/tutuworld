extends Node
const UI=preload("res://scripts/ui/ui_kit.gd")
const Animals=preload("res://scripts/characters/animal_factory.gd")
const Outfit=preload("res://scripts/city/outfit.gd")
const Props=preload("res://scripts/city/work_props.gd")
var city: Node3D
var session: Node
var replicas: Dictionary={}
var motion: Dictionary={}
var bubbles: Dictionary={}
var input_timer:=0.0
var prediction=preload("res://scripts/services/movement_prediction.gd").new()
var buffers: Dictionary={}
const Buffer=preload("res://scripts/services/motion_buffer.gd")
var chat_input: LineEdit
var chat_card: PanelContainer
var connection_card: PanelContainer
var changing_scene:=false
var remote_meal:=""
var metrics_timer:=0.0
func _ready() -> void:
	process_physics_priority=-10
	session=city.session
	city.bunny.network_client_prediction=true
	city.bunny.movement_predicted.connect(record_input)
	for npc in city.npcs:
		npc.network_replica=true;npc.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		for child in npc.get_children():
			if child.get_script() in [load("res://scripts/city/npc_driver.gd"),load("res://scripts/valley/panda_routine.gd"),load("res://scripts/valley/visitor_routine.gd")]:child.set_physics_process(false)
		npc.set_physics_process(true)
	session.online_message.connect(receive)
	session.changed.connect(apply_shared_state)
	session.online_connection_changed.connect(connection_changed)
	session.online_update_required.connect(version_changed)
	chat_card=UI.panel(UI.CREAM,19,13);chat_card.name="ChatInput";chat_card.anchor_left=.5;chat_card.anchor_right=.5;chat_card.anchor_top=1;chat_card.anchor_bottom=1
	chat_card.position=Vector2(-280,-153);chat_card.custom_minimum_size=Vector2(560,55);city.hud.root_ui.add_child(chat_card)
	chat_input=LineEdit.new();chat_input.placeholder_text="和身边的朋友说句话…  Enter发送 / Esc取消";chat_input.max_length=120
	chat_input.add_theme_stylebox_override("normal",StyleBoxEmpty.new());chat_input.add_theme_color_override("font_color",UI.INK);chat_card.add_child(chat_input)
	var emoji:=SystemFont.new();emoji.font_names=PackedStringArray(["Apple Color Emoji","Segoe UI Emoji","Noto Color Emoji"])
	var font: Font=load("res://assets/fonts/NotoSansSC.ttf").duplicate();font.fallbacks=[emoji]
	chat_input.add_theme_font_override("font",font);chat_input.text_submitted.connect(send_chat)
	chat_card.hide()
	connection_card=UI.panel(UI.CREAM,24,22);connection_card.anchor_left=.5;connection_card.anchor_right=.5;connection_card.anchor_top=.5;connection_card.anchor_bottom=.5
	connection_card.position=Vector2(-235,-45);connection_card.custom_minimum_size=Vector2(470,90);connection_card.add_child(UI.label("海风有点远，正在重新联系小岛…",19));city.hud.root_ui.add_child(connection_card);connection_card.hide()
	apply_shared_state()
func _input(event: InputEvent) -> void:
	if changing_scene:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE and chat_card.visible:
			close_chat();get_viewport().set_input_as_handled();return
		if event.keycode==KEY_ENTER and not chat_card.visible and not city.hud.overlay.visible and not city.preparing:
			chat_card.show();chat_input.grab_focus();city.paused=true;get_viewport().set_input_as_handled()
func send_chat(value: String) -> void:
	var text:=value.strip_edges()
	close_chat()
	if text!="":session.dispatch("chat",{"text":text})
func close_chat() -> void:
	chat_input.text="";chat_input.release_focus();chat_card.hide();city.paused=city.hud.overlay.visible
func connection_changed(connected: bool) -> void:
	connection_card.visible=not connected
	city.bunny.can_move=connected;city.paused=not connected or city.hud.overlay.visible or chat_card.visible
	if connected:
		prediction=preload("res://scripts/services/movement_prediction.gd").new()
		var p: Array=session.state().player_position
		city.bunny.stand_up(Vector3(float(p[0]),float(p[1]),float(p[2])));city.sleep_active=false;city.nap_active=false;city.dining_active=false
func version_changed(_version: String) -> void:
	if changing_scene:return
	changing_scene=true
	await session.leave_online()
	get_tree().change_scene_to_file("res://scenes/title.tscn")
func receive(data: Dictionary) -> void:
	if data.get("type","")=="snapshot":
		if data.get("movement") is Dictionary:
			var row: Dictionary=data.movement;motion[str(row.id)]=row;prediction.receive(row)
	elif data.get("type","")=="motion":
		var seen: Dictionary={}
		for row in data.get("actors",[]):
			var id: String=row.id;motion[id]=row;seen[id]=true
			if id==session.active_character_id:prediction.receive(row)
			else:
				if not buffers.has(id):buffers[id]=Buffer.new()
				buffers[id].push(row,int(data.get("tick",0)),float(Time.get_ticks_msec())/1000)
			if row.get("npc",false):continue
			if id==session.active_character_id:continue
			if not replicas.has(id):make_replica(row)
		for id in replicas.keys():
			if not seen.has(id):replicas[id].actor.queue_free();replicas[id].props.queue_free();replicas.erase(id);motion.erase(id);buffers.erase(id)
	elif data.get("type","")=="chat":show_chat(data)
func make_replica(row: Dictionary) -> void:
	var actor=Animals.create(row.species);actor.network_replica=true;actor.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;actor.world=city;actor.name="Online_"+str(row.id);city.add_child(actor)
	actor.position=from_array(row.position);Outfit.apply(actor,row.equipment)
	var props:=Props.new();props.bunny=actor;city.add_child(props)
	var label:=preload("res://scripts/geometry.gd").text3d(actor,row.name,Vector3(0,actor.rig_profile.name_height,0),22,UI.CREAM)
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.outline_size=6;label.outline_modulate=UI.INK
	replicas[row.id]={"actor":actor,"props":props,"equipment":row.equipment.duplicate(),"action":""}
func record_input(direction: Vector3,jump: bool,running: bool) -> void:
	if session.online_joined and not city.preparing:prediction.record(city.bunny,direction,jump,running)
func _physics_process(_delta: float) -> void:
	if not city.preparing and is_instance_valid(city.bunny):prediction.reconcile(city.bunny)
func _process(delta: float) -> void:
	if not is_instance_valid(city.bunny):return
	metrics_timer+=delta
	if metrics_timer>=30:
		metrics_timer=0
		print("NET_CLIENT fps=",Engine.get_frames_per_second()," rtt_ms=",snappedf(session.remote.round_trip_ms,1)," unacked=",prediction.history.size()," corrections=",prediction.corrections," hard=",prediction.hard_corrections," max_error=",snappedf(prediction.max_error,.001))
	input_timer+=delta
	if input_timer>=.05 and session.online_joined:
		input_timer=0
		var packet: Dictionary=prediction.take_packet()
		if not packet.is_empty():session.remote.send(packet)
	if not city.preparing:
		for id in motion:
			var row: Dictionary=motion[id]
			if buffers.has(id):row=buffers[id].sample(float(Time.get_ticks_msec())/1000)
			if id==session.active_character_id:apply_local(row,delta)
			elif row.get("npc",false):
				if city.targets.has(id):apply_actor(city.targets[id].node,row,delta)
			elif replicas.has(id):
				var replica: Dictionary=replicas[id];apply_actor(replica.actor,row,delta)
				if replica.equipment!=row.equipment:replica.equipment=row.equipment.duplicate();Outfit.apply(replica.actor,row.equipment)
				if replica.action!=str(row.get("action","")):
					replica.action=str(row.get("action",""));replica.props.hide_tool()
					if replica.action!="":replica.props.show_tool(replica.action)
				var target: String=row.get("job",{}).get("target","")
				if city.targets.has(target):replica.props.target_point=city.target_position(target)+Vector3(0,.6,0)
	if city.map_id=="city" and is_instance_valid(city.culinary):
		var meal:=""
		for id in replicas:
			var row: Dictionary=motion.get(id,{})
			if row.get("pose",{}).get("kind","")=="eat":meal=str(row.get("job",{}).get("item",""))
		if meal!=remote_meal:
			remote_meal=meal
			if meal!="":city.culinary.serve(meal)
			elif not city.dining_active:city.culinary.clear_meal()
	for id in bubbles.keys():
		var bubble: Dictionary=bubbles[id];bubble.remaining-=delta
		var actor=actor_for(id)
		if bubble.remaining<=0 or not is_instance_valid(actor):bubble.panel.queue_free();bubbles.erase(id);continue
		var p: Vector3=actor.global_position+Vector3(0,actor.rig_profile.dialogue_height+.35,0)
		bubble.panel.visible=not city.camera.is_position_behind(p) and actor.visible and actor.position.distance_to(city.bunny.position)<30
		bubble.panel.position=city.camera.unproject_position(p)-Vector2(bubble.panel.size.x*.5,bubble.panel.size.y)
func apply_local(row: Dictionary,delta: float) -> void:
	var actor=city.bunny;var pose: Dictionary=row.get("pose",{});var kind: String=pose.get("kind","")
	if kind=="sleep":
		if not city.sleep_active:city.enter_sleep(true)
		return
	if kind=="sit":
		if not city.nap_active and city.targets.has(pose.target):
			actor.sit_on_surface(city.targets[pose.target].node.get_node("SeatAnchor").global_transform);actor.play_action("nap",INF);city.nap_active=true
		return
	if kind not in ["sleep","sit","waiting_exit"] and (city.sleep_active or city.nap_active):
		actor.stand_up(from_array(row.position));city.sleep_active=false;city.nap_active=false
	if kind=="eat":return
	if kind=="waiting_exit":city.nap_active=true;actor.seated=true;actor.play_action("nap",INF);return

func apply_actor(actor: CharacterBody3D,row: Dictionary,delta: float) -> void:
	var target:=from_array(row.position)
	actor.position=target
	actor.velocity=from_array(row.get("velocity",[0,0,0]));actor.walking=row.get("walking",false);actor.network_grounded=row.get("grounded",true)
	if str(row.get("id",""))!=city.talking_npc or city.targets.get(city.talking_npc,{}).get("kind","")!="shop":actor.visual.rotation.y=lerp_angle(actor.visual.rotation.y,float(row.get("yaw",0)),1-exp(-delta*18))
	actor.step_phase+=delta*minf(13,Vector2(actor.velocity.x,actor.velocity.z).length()*3)
	var sleeping: bool=row.get("sleeping",false) or row.get("pose",{}).get("kind","")=="sleep"
	if sleeping:
		if not actor.sleeping:actor.lie_in_bed(city.home.get_node("Furnishing/bed"))
		city.home.bed_occupant=actor
	elif actor.sleeping:actor.stand_up(target);city.home.bed_occupant=null
	var seated: bool=row.get("pose",{}).get("kind","") in ["sit","eat","waiting_exit"]
	actor.seated=seated or sleeping
	var action: String=row.get("action","")
	if actor.action!=action:
		if action!="":actor.play_action(action,INF)
		else:actor.action="";actor.action_time=0
	if row.get("npc",false):
		var presence: float=row.get("presence",1)
		actor.set_meta("presence",presence);actor.set_meta("interaction_available",presence>.999 and not sleeping)
		actor.visible=presence>0 and actor.position.distance_to(city.bunny.position)<65;actor.collision_layer=2 if presence>.999 and not sleeping else 0
		if actor.get_meta("equipment",{})!=row.get("equipment",{}):actor.set_meta("equipment",row.equipment);Outfit.apply(actor,row.equipment)
		if not is_equal_approx(float(actor.get_meta("last_online_presence",-1)),presence):
			actor.set_meta("last_online_presence",presence)
			for part in actor.find_children("*","GeometryInstance3D",true,false):
				if not part is Label3D:part.transparency=1-presence
		for label in actor.find_children("*","Label3D",true,false):label.visible=presence>.999 and not sleeping
		city.targets[str(row.id)].position=actor.position
func actor_for(id: String):
	if id==session.active_character_id:return city.bunny
	return replicas.get(id,{}).get("actor")
func show_chat(data: Dictionary) -> void:
	if bubbles.has(data.id):bubbles[data.id].panel.queue_free();bubbles.erase(data.id)
	var panel:=UI.panel(UI.CREAM,18,13);panel.custom_minimum_size=Vector2(180,0);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var col:=UI.column(4);panel.add_child(col);col.add_child(UI.label(str(data.name),12,UI.MUTED))
	var label:=UI.label(str(data.text),18);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size=Vector2(280,0)
	var emoji:=SystemFont.new();emoji.font_names=PackedStringArray(["Apple Color Emoji","Segoe UI Emoji","Noto Color Emoji"])
	var font: Font=load("res://assets/fonts/NotoSansSC.ttf").duplicate();font.fallbacks=[emoji];label.add_theme_font_override("font",font)
	col.add_child(label);city.hud.root_ui.add_child(panel)
	bubbles[data.id]={"panel":panel,"remaining":clampf(3+str(data.text).length()*.08,4,10)}
func apply_shared_state() -> void:
	var value=session.online_doors.get(city.map_id)
	if value is Dictionary and is_instance_valid(city.home):
		city.home.door_open=value.get("open",false);city.home.door_target=float(value.get("target",0));city.home.door_tweening=absf(city.home.door_angle-city.home.door_target)>.001
func from_array(p: Array) -> Vector3:return Vector3(float(p[0]),float(p[1]),float(p[2]))
