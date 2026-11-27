extends SceneTree
const J=preload("res://scripts/jade/layout.gd")
const Games=preload("res://scripts/jade/house_games.gd")
const Board=preload("res://scripts/jade/play_board.gd")
const People=preload("res://scripts/city/npc_profiles.gd")
const Residents=preload("res://scripts/jade/residents.gd")
const Solutions=preload("res://tests/jade_game_solutions.gd")
var city: Node3D
var session: Node
var failures: Array=[]
var out: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	if not ok:failures.append(label_);print("FAIL ",label_)
func stand(p: Vector3) -> void:
	city.bunny.position=p
	city.bunny.reset_physics_interpolation()
	city.bunny.velocity=Vector3.ZERO
	session.set_player_position(p)
func native_target(house: String,use: String) -> String:
	if J.shops().has(house):return "JadeVendor_"+house
	if house=="workshop":return "jade_workshop"
	if house=="tavern":return "jade_kitchen_tavern"
	var kind: String={"lodging":"bed","chime":"chime","read":"read","dye":"tailor","tea":"tea","footwork":"footwork"}.get(use,"")
	for id: String in city.targets:
		if id.begins_with("jade:"+house+":") and city.targets[id].kind==kind:return id
	return ""
func click_move(table: Node,choice: int) -> bool:
	while table.listening:await process_frame
	if table.house=="dojo":
		while not table.beat_open() or table.drum_cycle+int(table.phase>=.5)==table.last_beat:await process_frame
	var on_table:int=table.illustration.objects.size()
	var b:Button=table.illustration.objects[choice] if choice<on_table else table.controls.get_child(choice-on_table)
	if b.disabled or not b.is_visible_in_tree():return false
	var before:int=table.board.moves.size()
	var pos:=b.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=pos;root.push_input(motion,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=pos
		root.push_input(event,true)
	await process_frame
	return table.board.moves.size()==before+1
func drag_clay(surface: Control,from_band: int,to_band: int) -> void:
	var base:Vector2=surface.global_position+surface.origin()
	for edge in [[from_band,true],[to_band,false]]:
		var pos:=base+Vector2(114,52+46*int(edge[0]))*float(surface.local_scale())
		var motion:=InputEventMouseMotion.new();motion.position=pos;root.push_input(motion,true)
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=pos;event.pressed=edge[1];root.push_input(event,true)
	await process_frame
func tap_key(code:Key) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.pressed=down;root.push_input(event,true)
	await process_frame
func run() -> void:
	out=preload("res://tests/test_support.gd").output_dir()
	root.size=Vector2i(1440,900)
	session=preload("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.create_character("阿沅","bunny","bow_rose")
	session.state().map_id="jade";session.state().player_position=J.arrival()
	city=load("res://scenes/jade.tscn").instantiate();root.add_child(city);current_scene=city
	while city.preparing or not city.navigation.ready_for_paths:await process_frame
	session.active=false;city.bunny.set_physics_process(false)
	var nav: Node=city.navigation
	check(not is_finite(nav.surveyed_flat_floor(Vector2i(0,0))) and not is_finite(nav.surveyed_flat_floor(Vector2i(82,94))) and not is_finite(nav.surveyed_flat_floor(Vector2i(123,-45))),"Water, ponds and buildable plots keep their full support checks")
	var level_checks:=0
	for z in range(130,170,3):
		var cell:=Vector2i(roundi(J.lane(z)),z)
		var height_: float=nav.surveyed_flat_floor(cell)
		if not is_finite(height_):continue
		var start:=Vector3(cell.x,height_+.05,cell.y)
		for shift in [Vector3(.08,0,.08),Vector3(-.16,0,0)]:
			check(nav.can_step(start,start+shift,true)==nav.can_step(start,start+shift),"Survey matches physics on the open street")
			level_checks+=1
	check(level_checks>0,"Walked a surveyed level block")
	var walker: CharacterBody3D=city.targets.JadeCitizen_34.node
	var driver: Node=walker.get_node("NeighbourWalk")
	stand(walker.position+Vector3.BACK*1.45)
	city.bunny.velocity=Vector3.FORWARD*2.
	city.get_node("StreetLife").refresh_neighbours()
	check(absf(driver.give_way().x)>.9,"An approaching player has walking space")
	city.bunny.velocity=Vector3.ZERO
	var book: Dictionary=session.state().jade_visits
	var kinds: Dictionary={}
	var tables: Dictionary={}
	for h in J.HOUSES:
		var house:String=h[0]
		var type:=Games.type_for(house)
		kinds[type]=1+int(kinds.get(type,0))
		if Games.entry(house).is_empty():
			var native_id:=native_target(house,type)
			check(city.targets.has(native_id),"Missing working facility in "+house)
			continue
		check(not tables.has(type),"Duplicate tabletop rules "+type)
		tables[type]=house
		var id:="jade:%s:Trade"%house
		if Games.PERFORMANCES.has(house):
			for entry: String in city.targets:
				if entry.begins_with("jade:"+house+":") and city.targets[entry].kind=="jade_game":id=entry;break
		check(city.targets.has(id),"Missing "+id)
		if not city.targets.has(id):continue
		var station: Dictionary=city.targets[id]
		stand(station.position+Vector3.UP*.01)
		check(city.activity_access(id,"jade_game"),"Unreachable "+id)
		city.update_target();check(city.current_target==id,"Prompt "+id+" got "+city.current_target)
		var game:=Board.new(house)
		var moves:=Solutions.solution(game)
		city.current_target=id;city.interact()
		check(city.hud.mode=="jade_game","E opens "+house)
		var table:Node=city.hud.content.get_child(-1)
		check(table.has_method("press") and table.board.house==house,"Physical tabletop "+house)
		city.update_camera(3.)
		for frame in 2:await process_frame
		if house in ["weir","paper","potter","ferry","stage","audience","dojo","herbal"]:
			await create_timer(.25).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out+"/"+house+".png")
		if house=="potter":
			var shape:Array=table.board.rule.v.duplicate()
			await drag_clay(table.illustration,0,1)
			check(table.board.rule.v==[shape[0]-1,shape[1]+1,shape[2]],"Dragging from the rim to the belly physically transfers one part of clay")
			table.undo()
		if house=="music":
			await tap_key(KEY_3)
			check(table.board.rule.v==[2],"Physical number key strikes a note on the real music stand")
			table.undo()
		for move in moves:
			if not await click_move(table,int(move)):
				check(false,"Unreachable action %s / %s"%[house,move]);break
		check(table.received and int(book.rounds.get(house,0))==1,"Replay through controls "+house+" "+table.note.text)
		if house in ["weir","paper","potter","audience"]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out+"/"+house+"-finished.png")
		if house=="paper":
			table.show_keepsake()
			check(book.prints.size()==1 and book.prints[0]==table.board.rule.data.layers and table.illustration.album==book.prints[0] and session.authority.count("jade_flower_paper")==1,"Actual stamped sheet reaches both album and warehouse")
		if house=="music":
			check(book.song==table.board.rule.v and table.last_art.visible,"The player’s composition was saved")
			table.show_keepsake();check(table.listening,"Saved composition plays from the actual music stand")
		if house=="audience":
			check(book.decree=={"0":0,"1":0} and city.targets.has("court_order_0") and city.targets.has("court_order_1") and not city.targets.has("court_order_2"),"Two funded neighbourhoods receive a delivery")
			var delivery:Dictionary=city.targets.get("court_order_0",{})
			check(delivery.get("day_text","")=="渡口换上了新缆。" and city.has_node("CourtConsignments/court_order_0"),"Wharf receipt matches the actual court order")
		if house=="weir":
			table.next_round();check(table.board.serial==1 and table.board.rule.data.name!=game.rule.data.name,"New canal from receipt")
		city.hud.close_panel()
		var coins:int=session.state().coins
		check(not session.dispatch("jade_visit",{"target":id,"round":0,"moves":moves}).ok and coins==session.state().coins,"Stale receipt "+id)
	check(tables.size()==41,"41 unique playable systems")
	check(not session.dispatch("jade_visit",{"target":"jade:oil:Trade","round":1,"moves":[]}).ok,"Distance checked at settlement")
	for h in ["hostel","post"]:
		var key:="jade:%s:Trade"%h;stand(city.targets[key].position)
		var receipt:Dictionary=session.dispatch("jade_visit",{"target":key,"round":1,"moves":Solutions.solution(Board.new(h,1))})
		check(receipt.ok,"A second distinct postal job "+h)
	check(book.marks.size()==Games.STATIONS.size() and book.letter=="","All station seals and round trip")
	city.hud.open_panel("map")
	var atlas: Control=city.hud.map_draw
	var paper_click:=InputEventMouseButton.new()
	paper_click.button_index=MOUSE_BUTTON_LEFT;paper_click.pressed=true
	paper_click.position=Vector2(445,233)+Vector2(0,-164)*Vector2(1.45,1.06)
	var court: Array=J.HOUSES.filter(func(h):return h[0]=="oil")[0]
	var wing:=J.center(court)+Vector2(-J.dims("court").x-2.,-1.).rotated(-J.door_angle(court))
	var wing_click:=paper_click.duplicate() as InputEventMouseButton
	wing_click.position=Vector2(445,233)+wing*Vector2(1.45,1.06)
	atlas.gui_input.emit(wing_click)
	check(atlas.get_meta("selected_house","")=="oil","The visible courtyard wing is selectable")
	atlas.gui_input.emit(paper_click)
	check(atlas.get_meta("selected_house","")=="audience" and city.hud.content.find_children("*","Label",true,false).any(func(label):return "批三坊用度" in label.text and "已钤印" in label.text),"The atlas identifies the actual palace game and personal seal")
	city.hud.close_panel()
	city.hud.open_panel("map")
	check(city.hud.map_draw.get_meta("selected_house","")=="audience","Reopening the atlas retains the selected destination")
	city.hud.close_panel()
	check(session.authority.count("jade_lamp")==1 and session.authority.count("jade_screen")==1 and session.authority.count("jade_chime")==1,"Personal furnishing gifts")
	for item_id in Games.TAKE_HOME.values():
		check(session.authority.count(item_id)==1,"One usable take-home item "+item_id)
	var lines: Dictionary={}
	for npc in city.npcs:
		var id:=str(npc.name);var profile:=People.profile(id)
		check(profile.has("personality") and profile.lines.size()==4,"Personal voice "+id)
		for line in profile.lines:
			check(not lines.has(line.text),"Duplicate line "+line.text);lines[line.text]=true
		if id.begins_with("JadeCitizen_") and id.trim_prefix("JadeCitizen_").to_int()>=20:
			var idx:=id.trim_prefix("JadeCitizen_").to_int()
			var stops:=preload("res://scripts/jade/street_life.gd").walk_stops(idx,J.point(Residents.PEOPLE[idx][2],Residents.PEOPLE[idx][3]))
			for i in stops.size():
				check(city.navigation.path_between(stops[i],stops[(i+1)%stops.size()]).size()>=2,"Disconnected "+id+" stop "+str(i))
	for id in Residents.AFTER_WORK:
		var line: String=Residents.AFTER_WORK[id][1]
		check(not lines.has(line) and city.conversation_line(id)==line and city.conversation_line(id)!=line,"Neighbour remembers a completed errand "+id)
		lines[line]=true
	# Check the spoken text on the actual conversation path, including an index beyond the old town table.
	var speaker: Dictionary=city.targets.JadeCitizen_34
	stand(speaker.node.position+Vector3.BACK*1.35);city.current_target="JadeCitizen_34";city.interact()
	check(city.dialogue_text in People.available_lines("JadeCitizen_34",fposmod(session.state().time,3600.)/150.),"Court usher has his own bubble")
	city.end_dialogue()
	var ceremony: Node=city.get_node("StreetLife")
	var usher: CharacterBody3D=speaker.node
	usher.position=J.point(-3,-160)
	usher.action=""
	ceremony.update_market();ceremony.paid_respects.erase(34);ceremony.receive_court()
	check(usher.action=="bow" and ceremony.paid_respects.has(34),"The court usher bows on entering the morning audience")
	var bed: Node3D=city.targets["jade:cot:bed_0"].node
	stand(bed.to_global(Vector3(2.0,.02,0)))
	city.current_target="jade:cot:bed_0";city.interact()
	check(city.sleep_active and session.state().rest_bed=="jade:cot:bed_0","Sleep in the canopy bed")
	city.interact();check(not city.sleep_active,"Wake beside the canopy bed")
	var court_outfit:={"head":"lotus_crown","body":"crane_robe","neck":"jade_disc"}
	for slot in court_outfit:
		var item: String=court_outfit[slot]
		session.authority.add(item,1)
		check(session.dispatch("equip",{"item":item,"slot":slot}).ok,"Wear the court outfit "+item)
	var throne: Node3D=city.scenery.get_node("Hall_audience/Furnishing/jade_throne_1")
	stand(throne.to_global(Vector3(0,.02,1.65)));city.current_target="jade:audience:jade_throne_1";city.interact()
	check(city.nap_active and city.bunny.seated,"Sit on the lacquer throne")
	city.interact();check(not city.nap_active and city.bunny.mood_label.text.is_empty(),"Stand up at its foot")
	stand(throne.to_global(Vector3(-2.35,0,1.35)))
	city.bunny.set_visual_heading(.28)
	city.bunny.animate_pose(.8)
	city.set_process(false);city.hud.hide();city.update_lighting(.46)
	var room:=throne.get_parent().get_parent()
	city.camera.global_position=throne.global_position+Vector3(2.4,2.3,5.3)
	city.camera.look_at(throne.global_position+Vector3.UP*1.2);room._process(1.)
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/含章殿龙椅.png")
	print("JADE_NEIGHBOURHOOD houses=",J.HOUSES.size()," uses=",kinds.size()," seals=",book.marks.size()," voices=",city.npcs.size()," lines=",lines.size()," failures=",failures)
	city.free();session.free();quit(int(not failures.is_empty()))
