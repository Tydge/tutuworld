extends Node
signal changed
signal event_received(event: Dictionary)
signal equipment_changed
signal characters_changed
signal time_adjusted
signal settings_changed(key: String)
signal online_message(message: Dictionary)
signal online_connection_changed(connected: bool)
signal online_update_required(version: String)
const Animals=preload("res://scripts/characters/animal_catalog.gd")
const Authority=preload("res://scripts/services/local_authority.gd")
const Stats=preload("res://scripts/services/character_stats.gd")
const DB=preload("res://scripts/services/game_data.gd")
const SAVE="user://island_city_v2.json"
const WORLD_KEYS=["world_id","time","plots","resources","build_layout"]
const CHARACTER_KEYS=["player_id","character_name","species","map_id","coins","inventory","equipment","experience","stamina","stamina_run_elapsed","stamina_recovery_elapsed","rest_mode","rest_bed","attributes","skills","skill_experience","skill_rules_version","food_effect","player_position","watering_water"]
var authority=Authority.new()
var active:=false
var test_mode:=false
var save_path:=SAVE
var sequence:=0
var save_timer:=0.0
var building_generation:=""
var ui_timer:=0.0
var settings:={"sound":true,"volume":.55,"fullscreen":true,"camera_speed":1.0,"reduce_motion":false,"player_species":"bunny","render_quality":"balanced","fps_limit_enabled":true,"fps_limit":60,"background_throttle":true,"auto_update":true,"interior_view_mode":2,"interior_view_hint_seen":false,"show_other_storey_objects":true}
var characters: Dictionary={}
var active_character_id:=""
var world: Dictionary={}
var player_started:=false
var legacy_source:=""
# Shared world and character records remain behind the same command boundary.
var transport_mode:="local_authority"
var protocol_version:=1
var server_endpoint:=""
var installed_build:=preload("res://scripts/services/release.gd").BUILD
var remote: Node
var online_joined:=false
var online_token:=""
var online_username:=""
var online_locks: Dictionary={}
var online_care: Dictionary={}
var online_doors: Dictionary={}
var offline_backup: Dictionary={}
var reconnecting:=false
var leaving_online:=false
func _ready() -> void:
	test_mode=OS.get_cmdline_user_args().has("--test")
	if test_mode and not OS.get_cmdline_user_args().has("--benchmark"): Engine.max_fps=45
	if not test_mode: load_save()
	if not test_mode and FileAccess.file_exists("user://preferences.json"):
		var preferences=JSON.parse_string(FileAccess.get_file_as_string("user://preferences.json"))
		if preferences is Dictionary:
			for key in settings:
				if preferences.has(key):settings[key]=preferences[key]
	normalize_view_settings()
	if not test_mode:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	get_tree().auto_accept_quit=false
	get_tree().root.close_requested.connect(func(): save_game(); get_tree().quit())
func snapshot() -> Dictionary: return authority.state.duplicate(true)
func state() -> Dictionary: return authority.state
func job() -> Dictionary: return authority.job
func can_adjust_time() -> bool:
	if transport_mode!="local_authority" or not server_endpoint.is_empty(): return false
	if not is_inside_tree(): return false
	var peer:=multiplayer.multiplayer_peer
	return peer==null or peer is OfflineMultiplayerPeer
func shift_effect_clock(record: Dictionary,old_time: float,new_time: float) -> void:
	var effect: Dictionary=record.get("food_effect",{})
	if effect.is_empty(): return
	var remaining: float=float(effect.get("expires_at",0))-old_time
	if remaining<=0: record.food_effect={}
	else: effect.expires_at=new_time+remaining
func set_testing_time(hour: int,minute: int) -> Dictionary:
	# Local debug clock only: never expose this through the future multiplayer command protocol.
	if not can_adjust_time(): return {"ok":false,"message":"多人模式不能调整时间。"}
	if hour<0 or hour>23 or minute<0 or minute>59: return {"ok":false,"message":"请选择有效的时分。"}
	var old_time: float=state().time
	var new_time: float=floor(old_time/Authority.DAY_SECONDS)*Authority.DAY_SECONDS+(hour*60+minute)*Authority.DAY_SECONDS/1440.0
	var backup_state:=snapshot()
	var backup_world:=world.duplicate(true)
	var backup_characters:=characters.duplicate(true)
	var old_revision: int=authority.revision
	var backup_id:=active_character_id
	sync_current()
	for id in characters:
		var record: Dictionary=characters[id]
		if id!=active_character_id:
			# Settle rest already earned before changing the clock, including a rewind to day-one midnight.
			var combined:=world.duplicate(true);combined.merge(record,true)
			var resting=restore_state(combined)
			resting.tick_stamina(maxf(0,real_time_now()-float(record.get("stamina_recorded_at",real_time_now()))))
			record.stamina=resting.state.stamina
			record.stamina_recovery_elapsed=resting.state.stamina_recovery_elapsed
			record.stamina_recorded_at=real_time_now()
		shift_effect_clock(record,old_time,new_time)
		record.last_seen=new_time
	shift_effect_clock(state(),old_time,new_time)
	for resource in state().resources.values():
		if not resource.available: resource.respawn_at=new_time+maxf(0,float(resource.respawn_at)-old_time)
	state().time=new_time
	authority.revision+=1;state().revision=authority.revision
	if not save_game():
		authority.state=backup_state;authority.revision=old_revision
		world=backup_world;characters=backup_characters;active_character_id=backup_id
		return {"ok":false,"message":"时间未能保存，请稍后重试。"}
	changed.emit();time_adjusted.emit()
	return {"ok":true,"message":"已调至当天 %02d:%02d。"%[hour,minute]}
func dispatch(verb: String,args: Dictionary={}) -> Dictionary:
	if is_online():
		dispatch_online(verb,args)
		return {"ok":true,"pending":true,"message":""}
	sequence+=1
	var command:=args.duplicate(true)
	command.merge({"id":"%s:%d:%d"%[state().player_id,Time.get_ticks_usec(),sequence],"player_id":state().player_id,"protocol":protocol_version,"verb":verb},true)
	var persist: bool=verb not in ["cancel","plant","water","weed","harvest","gather"]
	var backup: Dictionary={}
	if persist:backup={"state":snapshot(),"world":world.duplicate(true),"characters":characters.duplicate(true),"revision":authority.revision,"job":job().duplicate(true),"seen":authority.seen_commands.duplicate(true),"random":authority.reward_random.state,"sleeping":authority.sleeping,"running":authority.running}
	var result: Dictionary=authority.execute(command) if transport_mode=="local_authority" else {"ok":false,"message":"多人世界暂未开放。"}
	if result.ok and persist and not save_game():
		authority.state=backup.state;authority.revision=backup.revision;authority.job=backup.job;authority.seen_commands=backup.seen;authority.reward_random.state=backup.random;authority.sleeping=backup.sleeping;authority.running=backup.running
		world=backup.world;characters=backup.characters
		result=authority.fail("旅程还没有保存成功，请稍后再试。" if verb=="travel" else "进度未能保存，本次操作没有生效，请稍后重试。")
	if result.ok:
		changed.emit()
		if verb=="equip": equipment_changed.emit()
	event_received.emit({"type":"notice","message":result.message,"ok":result.ok})
	return result
func set_player_position(position: Vector3) -> void:
	if is_online():return
	if position.is_finite(): state().player_position=[position.x,position.y,position.z]
func real_time_now() -> float:
	# Local wall clock today; a remote authority supplies its trusted timestamp later.
	return Time.get_unix_time_from_system()
func _process(delta: float) -> void:
	if is_online():
		if online_joined:
			state().time+=delta
			if not job().is_empty():job().elapsed=minf(float(job().duration),float(job().elapsed)+delta)
		return
	var previous_stamina: float=state().stamina
	if active:
		var backup: Dictionary={}
		if not job().is_empty() and float(job().elapsed)+delta>=float(job().duration):
			backup={"state":snapshot(),"job":job().duplicate(true),"revision":authority.revision,"random":authority.reward_random.state,"world":world.duplicate(true),"characters":characters.duplicate(true)}
		var events: Array=authority.tick(delta)
		if events.any(func(event): return event.type=="completed") and not save_game():
			authority.state=backup.state;authority.job=backup.job;authority.revision=backup.revision;authority.reward_random.state=backup.random
			world=backup.world;characters=backup.characters
			authority.refund_work_stamina(authority.job);authority.job.clear()
			events=[{"type":"rejected","message":"进度未能保存，本次动作已取消，材料、水量和经验没有改变。"}]
		for event in events:
			event_received.emit(event);changed.emit()
	elif player_started:
		authority.running=false;authority.sleeping=state().get("rest_mode","")=="sleep"
		authority.tick_stamina(delta)
	else: return
	if state().stamina!=previous_stamina: changed.emit()
	save_timer+=delta
	ui_timer+=delta
	if ui_timer>=1:
		ui_timer=0
		changed.emit()
	if save_timer>=15:
		save_timer=0
		save_game()
func extract(source: Dictionary,keys: Array) -> Dictionary:
	var out: Dictionary={}
	for key in keys:
		if source.has(key): out[key]=source[key]
	return out.duplicate(true)
func sync_current() -> void:
	if is_online():return
	world=extract(state(),WORLD_KEYS)
	if active_character_id=="" and player_started:
		active_character_id=state().player_id
	if active_character_id!="":
		state().player_id=active_character_id
		state()["species"]=settings.player_species
		var record:=extract(state(),CHARACTER_KEYS)
		# Unfinished jobs are not restored after loading: their reserved point is refunded in the saved snapshot.
		if job().get("stamina_reserved",false): record.stamina=minf(authority.stamina_max(),float(record.stamina)+authority.reserved_work_stamina(job()))
		record["last_seen"]=state().time
		record["stamina_recorded_at"]=real_time_now()
		characters[active_character_id]=record
func character_list() -> Array:
	if is_online():return characters.values().duplicate(true)
	sync_current()
	var out: Array=[]
	for id in characters:
		var entry: Dictionary=characters[id].duplicate(true)
		entry["id"]=id
		out.append(entry)
	return out
func valid_name(value: String) -> String:
	var name_:=value.strip_edges()
	if name_.length()<1 or name_.length()>12: return "名字要有 1～12 个字哦。"
	for character in name_:
		if character.unicode_at(0)<32 or character.unicode_at(0)==127: return "名字里不能有换行或控制字符。"
	return ""
func create_character(display_name: String,species_id: String,starter: String) -> Dictionary:
	var issue:=valid_name(display_name)
	if issue!="": return {"ok":false,"message":issue}
	if not Animals.supports(species_id): return {"ok":false,"message":"请选择一个角色外形。"}
	if starter not in DB.starter_clothes(): return {"ok":false,"message":"请选择一件初始服饰。"}
	if not job().is_empty(): return {"ok":false,"message":"先完成手上的事情吧。"}
	for entry in character_list():
		if str(entry.character_name).nocasecmp_to(display_name.strip_edges())==0: return {"ok":false,"message":"岛上已经有这个名字啦，换一个吧。"}
	var backup:=checkpoint()
	var id:="char_"+Crypto.new().generate_random_bytes(12).hex_encode()
	var fresh:=Authority.new()
	for key in world: fresh.state[key]=world[key].duplicate(true) if world[key] is Dictionary or world[key] is Array else world[key]
	fresh.state.player_id=id
	fresh.state.character_name=display_name.strip_edges()
	fresh.state.species=species_id
	fresh.add(starter,1)
	fresh.state.equipment[DB.item(starter).slot]=starter
	authority=fresh
	active_character_id=id
	settings.player_species=species_id
	player_started=true
	if not save_game():
		restore_checkpoint(backup)
		return {"ok":false,"message":"角色还没有保存成功，请检查存储空间后重试。"}
	characters_changed.emit()
	changed.emit()
	return {"ok":true,"id":id,"message":"准备出发啦。"}
func select_character(id: String) -> Dictionary:
	if not characters.has(id): return {"ok":false,"message":"这位小岛邻居还不存在。"}
	if not job().is_empty(): return {"ok":false,"message":"先完成手上的事情吧。"}
	sync_current()
	var backup:=checkpoint()
	activate_record(id)
	if not save_game():
		restore_checkpoint(backup)
		return {"ok":false,"message":"进度未能保存，请稍后重试。"}
	changed.emit()
	return {"ok":true,"id":id,"message":"出发吧。"}
func checkpoint() -> Dictionary:
	return {"authority":authority,"characters":characters.duplicate(true),"world":world.duplicate(true),"id":active_character_id,"settings":settings.duplicate(),"started":player_started}
func restore_checkpoint(backup: Dictionary) -> void:
	authority=backup.authority
	characters=backup.characters
	world=backup.world
	active_character_id=backup.id
	settings=backup.settings
	player_started=backup.started
func activate_record(id: String,recover_rest: bool=true) -> void:
	var record: Dictionary=characters[id]
	var combined:=world.duplicate(true)
	combined.merge(record,true)
	combined.player_id=id
	authority=restore_state(combined)
	active_character_id=id
	settings.player_species=state().species
	player_started=true
	if recover_rest:
		var rest: float=maxf(0,real_time_now()-float(record.get("stamina_recorded_at",real_time_now())))
		authority.tick_stamina(rest)
func save_game() -> bool:
	if is_online():return save_online_login()
	sync_current()
	if test_mode: return true
	var next_generation:=Crypto.new().generate_random_bytes(8).hex_encode()
	var data:={"schema":3,"building_generation":next_generation,"saved_at":Time.get_unix_time_from_system(),"world":world,"characters":characters,"active_character":active_character_id,"settings":settings}
	var writer=preload("res://scripts/services/atomic_file.gd")
	if legacy_source!="" and FileAccess.file_exists(legacy_source) and not FileAccess.file_exists(save_path+".v2.bak"):
		if not writer.copy_verified(legacy_source,save_path+".v2.bak"):return false
	# A corrupt primary recovered from .bak must never replace that healthy backup.
	var backup_valid:=FileAccess.file_exists(save_path) and valid_save(JSON.parse_string(FileAccess.get_file_as_string(save_path)))
	var saved: bool=writer.write(save_path,JSON.stringify(data),backup_valid)
	if saved:
		legacy_source="";building_generation=next_generation;preload("res://scripts/building/layout_store.gd").consolidate(save_path)
	return saved
func set_build_layout(candidate: Dictionary) -> Dictionary:
	if is_online():return {"ok":false,"message":"建造园目前只在单人模式开放。"}
	if not job().is_empty():return {"ok":false,"message":"请先完成手上的工作。"}
	var checked: Dictionary=preload("res://scripts/building/layout.gd").validate(candidate)
	if not checked.ok:return checked
	if state().build_layout==checked.layout:return checked
	var previous: Dictionary=state().build_layout;var revision_before: int=authority.revision;var state_revision_before: int=int(state().revision)
	state()["build_layout"]=checked.layout
	authority.revision+=1;state().revision=authority.revision
	if not test_mode and not preload("res://scripts/building/layout_store.gd").write(save_path,building_generation,str(state().get("world_id","local")),checked.layout):
		state().build_layout=previous;authority.revision=revision_before;state().revision=state_revision_before
		return {"ok":false,"message":"布局保存失败，已保留修改前的房间。"}
	changed.emit()
	return checked
func valid_save(data: Variant) -> bool:
	if not data is Dictionary: return false
	if data.get("schema",0)==2: return data.get("state") is Dictionary
	return data.get("schema",0)==3 and data.get("world") is Dictionary and data.get("characters") is Dictionary
func load_save() -> void:
	var data: Variant=null
	var loaded:=""
	for filename in [save_path,save_path+".bak"]:
		if not FileAccess.file_exists(filename): continue
		var candidate: Variant=JSON.parse_string(FileAccess.get_file_as_string(filename))
		if valid_save(candidate): data=candidate; loaded=filename; break
	if data==null: return
	building_generation=str(data.get("building_generation",""))
	preload("res://scripts/building/layout_store.gd").replay(save_path,data,building_generation)
	for key in settings:
		if data.get("settings",{}) is Dictionary and data.get("settings",{}).has(key): settings[key]=data.settings[key]
	normalize_view_settings()
	if not Animals.supports(settings.player_species): settings.player_species="bunny"
	if settings.render_quality not in ["balanced","native"]: settings.render_quality="balanced"
	if int(settings.get("fps_limit",60)) not in [60,90,120]: settings.fps_limit=60
	characters.clear()
	active_character_id=""
	if data.schema==2:
		var raw: Dictionary=data.state.duplicate(true)
		raw["species"]=settings.player_species
		if not raw.has("character_name"): raw["character_name"]=Animals.display_name(settings.player_species)
		authority=restore_state(raw)
		world=extract(state(),WORLD_KEYS)
		active_character_id=state().player_id
		characters[active_character_id]=extract(state(),CHARACTER_KEYS)
		player_started=true
		legacy_source=loaded
	else:
		authority=restore_state(data.world)
		world=extract(state(),WORLD_KEYS)
		for id in data.characters:
			if not data.characters[id] is Dictionary: continue
			var combined:=world.duplicate(true)
			combined.merge(data.characters[id],true)
			combined.player_id=str(id)
			var clean=restore_state(combined)
			characters[str(id)]=extract(clean.state,CHARACTER_KEYS)
			characters[str(id)]["last_seen"]=maxf(0,float(data.characters[id].get("last_seen",world.time)))
			characters[str(id)]["stamina_recorded_at"]=clampf(float(data.characters[id].get("stamina_recorded_at",data.get("saved_at",real_time_now()))),0,real_time_now())
		var selected: String=str(data.get("active_character",""))
		if not characters.has(selected) and not characters.is_empty(): selected=characters.keys()[0]
		if characters.has(selected): activate_record(selected,false)
		else: player_started=false
	# One world clock advances once; inactive inventories and experience are untouched.
	authority.running=false
	authority.tick(clampf(Time.get_unix_time_from_system()-float(data.get("saved_at",Time.get_unix_time_from_system())),0,7*86400))
	sync_current()
func restore_state(raw: Dictionary):
	var restored:=Authority.new()
	var s: Dictionary=restored.state
	s["build_layout"]=preload("res://scripts/building/layout.gd").normalize(raw.get("build_layout",{}))
	s.player_id=str(raw.get("player_id","local_bunny")).left(80)
	s.character_name=str(raw.get("character_name","")).strip_edges().left(12)
	if valid_name(s.character_name)!="": s.character_name=Animals.display_name(str(raw.get("species","bunny")))
	s.map_id="valley" if raw.get("map_id","city")=="valley" else "city"
	if s.map_id=="valley": s.player_position=preload("res://scripts/valley/valley_layout.gd").arrival("valley")
	s.species=str(raw.get("species","bunny"))
	if not Animals.supports(s.species): s.species="bunny"
	s.coins=clampi(int(raw.get("coins",650)),0,99999999)
	s.time=maxf(0,float(raw.get("time",1200)))
	s.inventory.clear()
	var inventory: Dictionary=raw.get("inventory",{})
	for id in inventory:
		if not DB.item(id).is_empty() and int(inventory[id])>0: s.inventory[id]=clampi(int(inventory[id]),1,1 if DB.item(id).kind in ["tool","clothing"] else 99999)
	for slot in ["head","body","neck"]:
		s.equipment[slot]=""
		var id: String=raw.get("equipment",{}).get(slot,"")
		if s.inventory.has(id) and DB.item(id).get("slot","")==slot: s.equipment[slot]=id
	s.watering_water=raw.get("watering_water",{}).duplicate() if raw.get("watering_water",{}) is Dictionary else {}
	s.experience=clampi(int(raw.get("experience",0)),0,2147483647)
	s.attributes=Stats.defaults()
	for key in s.attributes: s.attributes[key]=clampf(float(raw.get("attributes",{}).get(key,0)),-.8,10.0)
	s.skills=Stats.skill_defaults()
	s.skill_experience=Stats.skill_xp_defaults()
	# This requested reset is applied once per character, not on every game load.
	s.skill_rules_version=Stats.PROGRESSION_VERSION
	if int(raw.get("skill_rules_version",0))>=Stats.PROGRESSION_VERSION:
		for key in s.skills:
			s.skill_experience[key]=clampi(int(raw.get("skill_experience",{}).get(key,0)),0,Stats.skill_start(Stats.MAX_LEVEL))
			s.skills[key]=Stats.skill_progress(s.skill_experience[key]).level
	s.stamina_run_elapsed=clampf(float(raw.get("stamina_run_elapsed",0)),0,2.999999)
	s.stamina_recovery_elapsed=clampf(float(raw.get("stamina_recovery_elapsed",0)),0,29.999999)
	var bed_id:=str(raw.get("rest_bed",""));var bed_valid:=bed_id=="home_bed"
	if bed_id.begins_with("build:") and s.map_id=="city":
		var bed:=preload("res://scripts/building/layout.gd").find(s.build_layout,bed_id.trim_prefix("build:"))
		bed_valid=bed.get("type","")=="object" and preload("res://scripts/building/catalog.gd").OBJECTS[bed.kind].get("bed",false)
	s.rest_mode="sleep" if raw.get("rest_mode","")=="sleep" and bed_valid else ""
	s.rest_bed=bed_id if s.rest_mode=="sleep" else ""
	restored.sleeping=s.rest_mode=="sleep"
	s.food_effect={}
	var food_effect: Dictionary=raw.get("food_effect",{})
	var food_id: String=food_effect.get("item","")
	if DB.item(food_id).get("kind","")=="food":
		var expires:=clampf(float(food_effect.get("expires_at",0)),0,float(s.time)+Authority.DAY_SECONDS)
		if expires>float(s.time): s.food_effect={"item":food_id,"expires_at":expires}
	# Capacity food must be restored before clamping saved stamina above the base 100.
	s.stamina=clampf(floor(float(raw.get("stamina",restored.stamina_max()))+.000001),0,restored.stamina_max())
	for id in s.plots:
		var p: Dictionary=raw.get("plots",{}).get(id,{})
		if not DB.crop(p.get("crop","")).is_empty(): s.plots[id]={"crop":p.crop,"growth":clampf(float(p.get("growth",0)),0,float(DB.crop(p.crop).days)*Authority.DAY_SECONDS),"water_stage":clampi(int(p.get("water_stage",-1)),-1,DB.care_stages(p.crop).size()-1),"weed_stage":clampi(int(p.get("weed_stage",-1)),-1,DB.care_stages(p.crop).size()-1),"quality":clampi(int(p.get("quality",0)),0,DB.crop_quality_max(p.crop))}
	for id in s.resources:
		var r: Dictionary=raw.get("resources",{}).get(id,{})
		if not r.is_empty(): s.resources[id]={"available":bool(r.get("available",true)),"respawn_at":maxf(0,float(r.get("respawn_at",0))),"generation":maxi(0,int(r.get("generation",0)))}
	var pos: Variant=raw.get("player_position",s.player_position)
	if pos is Array and pos.size()==3 and preload("res://scripts/valley/valley_layout.gd").valid_saved_position(s.map_id,Vector3(float(pos[0]),float(pos[1]),float(pos[2]))): s.player_position=pos.duplicate()
	restored.normalize_production_state()
	return restored
func normalize_view_settings() -> void:
	if not settings.get("interior_view_mode") is int and not settings.get("interior_view_mode") is float:settings.interior_view_mode=2
	settings.interior_view_mode=clampi(int(settings.interior_view_mode),0,2)
	settings.interior_view_hint_seen=bool(settings.get("interior_view_hint_seen",false))
	settings.show_other_storey_objects=bool(settings.get("show_other_storey_objects",true))
func set_setting(key: String,value: Variant) -> void:
	if not settings.has(key): return
	if key=="interior_view_mode" and (not value is int or value<0 or value>2):return
	if key=="fps_limit" and int(value) not in [60,90,120]: return
	settings[key]=value
	settings_changed.emit(key)
	if key=="volume": AudioServer.set_bus_volume_db(0,linear_to_db(maxf(.001,float(value))))
	if key=="sound": AudioServer.set_bus_mute(0,not bool(value))
	if key=="fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
	if not test_mode:
		var preferences:=FileAccess.open("user://preferences.json.tmp",FileAccess.WRITE)
		if preferences!=null:preferences.store_string(JSON.stringify(settings));preferences.close();DirAccess.rename_absolute("user://preferences.json.tmp","user://preferences.json")
	save_game()

func scene_path() -> String: return preload("res://scripts/valley/valley_layout.gd").scene_path(str(state().get("map_id","city")))

func is_online() -> bool:return transport_mode=="remote_authority"
func ensure_remote() -> void:
	if is_instance_valid(remote):return
	remote=preload("res://scripts/services/remote_transport.gd").new()
	remote.set_meta("build",installed_build)
	add_child(remote)
	remote.snapshot_received.connect(receive_online_snapshot)
	remote.message_received.connect(func(message: Dictionary):
		if message.get("type","")=="event":event_received.emit(message.event)
		online_message.emit(message))
	remote.connection_lost.connect(on_connection_lost)
	remote.update_required.connect(func(version: String):
		reconnecting=false;online_joined=false;online_update_required.emit(version))
	if not test_mode and FileAccess.file_exists("user://online_login.json"):
		var data=JSON.parse_string(FileAccess.get_file_as_string("user://online_login.json"))
		if data is Dictionary:online_token=str(data.get("token",""));online_username=str(data.get("username",""))
func login_online(action: String,args: Dictionary,endpoint: String=preload("res://scripts/services/release.gd").WORLD_URL) -> Dictionary:
	ensure_remote()
	if not await remote.ensure_connected(endpoint):
		return {"ok":false,"message":"请先更新到%s再进入多人世界。"%remote.required_version if remote.required_version!="" else "暂时联系不到小岛，检查网络后再试吧。"}
	var result: Dictionary=await remote.request(action,args)
	if not result.get("ok",false):return result
	if not is_online():
		save_game();offline_backup=checkpoint()
		authority=Authority.new();characters={};world={};active_character_id="";player_started=false
		transport_mode="remote_authority";server_endpoint=endpoint
	if args.has("username"):online_username=str(args.username)
	online_token=str(result.get("token",online_token))
	set_online_roster(result.get("characters",[]));save_online_login()
	return result
func set_online_roster(roster: Array) -> void:
	characters.clear()
	for record in roster:characters[str(record.id)]=record
	characters_changed.emit()
func create_online_character(display_name: String,species: String,starter: String) -> Dictionary:
	var result: Dictionary=await remote.request("create_character",{"name":display_name,"species":species,"starter":starter})
	if not result.get("ok",false):return result
	set_online_roster(result.characters)
	return await select_online_character(str(result.character))
func select_online_character(id: String) -> Dictionary:
	active_character_id=id
	var result: Dictionary=await remote.request("join",{"character":id})
	if result.get("ok",false):
		online_joined=true;player_started=true;settings.player_species=state().species
		result.id=id;online_connection_changed.emit(true)
	return result
func receive_online_snapshot(data: Dictionary) -> void:
	if not is_online():return
	var previous: Dictionary=authority.state.get("equipment",{}).duplicate()
	authority.state=data.state
	authority.job=data.get("job",{}).duplicate(true)
	online_locks=data.get("locks",{});online_care=data.get("care_history",{});online_doors=data.get("doors",{})
	active_character_id=str(state().player_id)
	changed.emit()
	if previous!=state().equipment:equipment_changed.emit()
func request_online(verb: String,args: Dictionary={}) -> Dictionary:
	if not is_online() or not online_joined:return {"ok":false,"message":"正在重新联系小岛，请稍等。"}
	return await remote.request(verb,args)
func dispatch_online(verb: String,args: Dictionary={}) -> void:
	var result: Dictionary=await request_online(verb,args)
	if str(result.get("message",""))!="":event_received.emit({"type":"notice","message":result.message,"ok":result.get("ok",false)})
func save_online_login() -> bool:
	if test_mode:return true
	var file:=FileAccess.open("user://online_login.json.tmp",FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify({"token":online_token,"username":online_username}));file.close()
	if OS.get_name()!="Windows":FileAccess.set_unix_permissions("user://online_login.json.tmp",384)
	return DirAccess.rename_absolute("user://online_login.json.tmp","user://online_login.json")==OK
func leave_online() -> void:
	if not is_online():return
	leaving_online=true;reconnecting=false
	if is_instance_valid(remote) and remote.connected and online_joined:await remote.request("leave")
	if is_instance_valid(remote):remote.close()
	online_joined=false;transport_mode="local_authority";server_endpoint=""
	var preferences:=settings.duplicate()
	if not offline_backup.is_empty():restore_checkpoint(offline_backup)
	settings=preferences;offline_backup={};leaving_online=false;active=false
	save_game()
func on_connection_lost() -> void:
	if not is_online() or leaving_online or reconnecting:return
	online_joined=false;online_connection_changed.emit(false)
	reconnect_online()
func logout_online() -> void:
	if is_online() and is_instance_valid(remote) and remote.connected:
		await remote.request("logout",{"token":online_token})
		online_joined=false
	await leave_online()
	online_token="";save_online_login()
func reconnect_online() -> void:
	reconnecting=true
	var id:=active_character_id
	while reconnecting and is_online() and not leaving_online:
		await get_tree().create_timer(2).timeout
		if not reconnecting or leaving_online:break
		if not await remote.ensure_connected(server_endpoint):
			if remote.required_version!="":break
			continue
		var result: Dictionary=await remote.request("resume",{"token":online_token})
		if not result.get("ok",false):online_update_required.emit("");break
		result=await remote.request("join",{"character":id})
		if result.get("ok",false):online_joined=true;reconnecting=false;online_connection_changed.emit(true);return
	reconnecting=false
