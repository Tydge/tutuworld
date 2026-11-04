extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const S=preload("res://scripts/building/storeys.gd")
const T=preload("res://scripts/building/templates.gd")
const Stairs=preload("res://scripts/building/stairs.gd")
const Safety=preload("res://scripts/building/build_safety.gd")
var city: Node3D
var editor: Node
var session: Node
var checks:=0
var failures: Array=[]
func check(value: bool,label_: String) -> void:
	checks+=1;print("PASS " if value else "FAIL ",label_)
	if not value:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func press_e() -> void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.keycode=KEY_E;event.physical_keycode=KEY_E;event.pressed=down;Input.parse_input_event(event);await process_frame
func approach(point: Vector3) -> void:
	city.bunny.stand_up(point);city.bunny.set_physics_process(false);session.set_player_position(point);await physics_frame;await physics_frame;city.update_target()
func run() -> void:
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("楼层交互兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.5).timeout;editor=city.build_mode;editor.open_editor();editor.set_process(false);check(editor.commit(T.two_storey()),"Fully furnished two-storey sample loads");editor.close_editor();session.active=false;city.set_process(false);city.bunny.set_physics_process(false);await physics_frame;await physics_frame
	var data: Dictionary=editor.layout
	var bed: Dictionary=data.elements.filter(func(row):return row.get("kind","")=="canopy_bed")[0];var bed_id:="build:"+str(bed.id)
	var point:=Vector3(bed.position[0]-2.45,4.90,bed.position[1]+.3)
	await approach(Vector3(point.x,.2,point.z));check(city.current_target!=bed_id and not session.dispatch("rest",{"target":bed_id}).ok,"Neither prompt nor authority permits sleeping through the upper slab")
	await approach(Vector3(point.x,3.7,point.z));check(city.current_target!=bed_id and not session.dispatch("rest",{"target":bed_id}).ok,"A partial stair height still cannot reach the next floor through its slab")
	await approach(point);check(city.current_target==bed_id and city.hud.prompt.text.contains("睡觉"),"Upper bedroom bed offers E at its physical side");await press_e();check(city.sleep_active and session.state().rest_bed==bed_id,"Actual E sleeps in upper bedroom")
	var restored=session.restore_state(session.snapshot());check(restored.state.rest_bed==bed_id and restored.state.player_position[1]>4.,"Save restores upper-floor sleeping bed and approach height")
	if city.sleep_active:await press_e()
	check(not city.sleep_active and city.bunny.position.distance_to(point)<.25 and city.bunny.position.y>4.7,"Waking stays beside the bed on 2F")
	var chair: Dictionary=data.elements.filter(func(row):return row.get("kind","")=="chair")[0];var seat: Node3D=editor.room.render_cache[chair.id].node;var seat_point: Vector3=seat.to_global(Vector3(1.55,.02,.1))
	await approach(seat_point);check(city.current_target=="build:"+str(chair.id),"Upper study chair offers E");await press_e();check(city.nap_active and city.bunny.seated,"Upper study chair can be sat on");if city.nap_active:await press_e()
	check(not city.nap_active and city.bunny.position.y>4.7,"Leaving upper study chair preserves floor")
	var counter: Dictionary=data.elements.filter(func(row):return row.get("kind","")=="cooking_counter")[0];var id:="build:"+str(counter.id);var node: Node3D=editor.room.render_cache[counter.id].node
	var work: Vector3=node.get_node("WorkAnchor").global_position
	await approach(work+Vector3.UP*4.7);check(not city.facility_access(id),"Cooking cannot reach a lower kitchen through the slab")
	session.authority.add("carrot",10);session.authority.add("sea_salt",10);check(not session.dispatch("craft",{"target":id,"recipe":"carrot_soup"}).ok,"Craft authority independently checks the selected counter's floor")
	await approach(work);check(city.current_target==id and city.hud.prompt.text.contains("料理台"),"Kitchen counter offers real E cooking prompt");await press_e();check(city.hud.overlay.visible and city.kitchen_target==id,"E opens existing recipe interface for this counter")
	var before: int=session.authority.count("food_carrot_soup");var ingredients: int=session.authority.count("carrot");var cooking: Dictionary=city.begin_cooking("carrot_soup");check(cooking.ok and session.job().get("target","")==id,"Recipe starts at this buildable counter");city.hud.close_panel()
	if not session.job().is_empty():session.authority.tick(float(session.job().duration)+.01)
	check(session.authority.count("food_carrot_soup")==before+1 and session.authority.count("carrot")<ingredients,"Completed cooking uses real ingredients and grants one dish")
	await approach(Vector3(139,.2,25));city.bunny.can_move=true
	var old:=T.cottage();var roof: Dictionary=old.elements.filter(func(row):return row.type=="roof")[0];var lamps: Array=old.elements.filter(func(row):return row.get("kind","")=="pendant")
	var expanded:=L.add(old,{"type":"floor","storey":1,"a":[73.,5.],"b":[85.,15.]});check(L.validate(expanded).ok and L.find(expanded,roof.id).is_empty() and not L.find(expanded,lamps[0].id).is_empty(),"Adding a complete upper slab replaces lower roof and retains its ceiling light")
	var stair: Dictionary=data.elements.filter(func(row):return row.type=="stairs")[0];check(Safety.has_exit(data,point),"Bedroom has a continuous floor/door/stair route downstairs")
	check(not Safety.safe(data,L.remove(data,stair.id),point),"Cannot demolish the only stair while player is upstairs")
	check(not Safety.safe(data,L.demolish(data,Rect2(point.x-.5,point.z-.5,1.,1.),"floor",null,1),point),"Cannot remove the floor under an upstairs player")
	check(Safety.safe(data,L.remove(data,stair.id),Vector3(139,.2,25)),"Leaving the house allows deliberate stair demolition")
	var four:=L.empty()
	for level in range(4):four=L.add(four,{"type":"floor","a":[110.,-6.],"b":[157.,26.],"storey":level})
	for level in range(3):four=L.add(four,{"type":"stairs","form":"u","position":[118.+level*13.,9.],"yaw":0.,"storey":level})
	var checked:=L.validate(four);check(checked.ok,"Four-storey building has three real floor connections")
	if checked.ok:
		check(Safety.has_exit(checked.layout,Vector3(145,14.3,17)),"4F has a connected route down to ground")
		var temp: Dictionary=session.snapshot();temp.build_layout=checked.layout;temp.player_position=[145.,14.3,17.];var state=session.restore_state(temp);check(state.state.player_position==temp.player_position and L.normalize(state.state.build_layout)==checked.layout,"Fourth-floor layout and player Y survive save migration")
	var gap: int=L.walkable_grid(data,1).floors.size();var moved:=stair.duplicate(true);moved.position[0]-=20.;var shifted:=L.validate(L.replace(data,moved));check(not shifted.ok,"Moving stairs away from actual supported landings is rejected")
	check(L.walkable_grid(data,1).floors.size()==gap,"Failed stair move cannot alter original opening")
	var grid:=L.compiled(data,0);check(grid.floors.values().any(func(row):return row.style=="cottage_tile") and grid.walls.values().any(func(row):return row.get("faces",{}).get("positive",{}).get("style","")=="glazed_tile"),"Kitchen uses new selectable floor and wall textures")
	for audio in city.find_children("*","AudioStreamPlayer",true,false)+city.find_children("*","AudioStreamPlayer3D",true,false):audio.stop()
	await create_timer(.15).timeout;city.free();await create_timer(.15).timeout;session.free();print("MULTISTOREY_INTERACTIONS_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);call_deferred("finish",0 if failures.is_empty() else 1)

func finish(code: int) -> void:quit(code)
