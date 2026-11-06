extends SceneTree
var checks:=0
var failures: Array=[]
var city: Node3D
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func motion(point_: Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.position=root.get_final_transform()*point_;Input.parse_input_event(event);await process_frame
func pan(point_: Vector2,amount: float) -> void:
	await motion(point_);var event:=InputEventPanGesture.new();event.position=root.get_final_transform()*point_;event.delta=Vector2(0,amount);Input.parse_input_event(event);await process_frame;await process_frame
func wheel(point_: Vector2,down: bool,factor: float=1.) -> void:
	await motion(point_)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=root.get_final_transform()*point_;event.button_index=MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP;event.factor=factor;event.pressed=pressed;Input.parse_input_event(event);await process_frame
func magnify(point_: Vector2) -> void:
	await motion(point_);var event:=InputEventMagnifyGesture.new();event.position=root.get_final_transform()*point_;event.factor=1.12;Input.parse_input_event(event);await process_frame
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("触摸板目录测试","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.6).timeout
	var editor=city.build_mode;editor.open_editor();editor.ui.show_category("装饰");await create_timer(.2).timeout
	var scroll: ScrollContainer=editor.ui.catalog_area;var point_: Vector2=scroll.get_global_rect().get_center();var before: float=editor.distance_
	scroll.scroll_vertical=0;await pan(point_,2.3)
	check(scroll.scroll_vertical>0 and editor.distance_==before,"Trackpad pan over catalog scrolls next row without camera zoom")
	var down: int=scroll.scroll_vertical;await pan(point_,-.6);check(scroll.scroll_vertical<down and editor.distance_==before,"Reverse trackpad motion scrolls upward without camera zoom")
	scroll.scroll_vertical=0
	for i in range(20):await pan(point_,.001)
	check(scroll.scroll_vertical>0 and editor.distance_==before,"Subpixel trackpad deltas accumulate for smooth slow scrolling")
	scroll.scroll_vertical=0;await wheel(point_,true,.5);check(scroll.scroll_vertical>0 and editor.distance_==before,"Continuous wheel factors scroll catalog without zoom")
	await magnify(point_);check(editor.distance_==before,"Pinch inside catalog leaves camera distance unchanged")
	var dock: Control=editor.ui.root_ui.get_node("BuildDock");var blank:=dock.get_global_rect().position+Vector2(20,12);await pan(blank,2.);check(editor.distance_==before,"Scrolling a non-scrollable part of the dock never reaches the camera")
	scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value);await pan(point_,4.);check(editor.distance_==before,"At the end of the catalog, extra scroll does not leak to camera zoom")
	var scene:=Vector2(200,180);await pan(scene,1.);check(editor.distance_>before,"Trackpad pan over the scene still zooms the camera")
	var scene_distance: float=editor.distance_;await wheel(scene,false);check(editor.distance_<scene_distance,"Mouse wheel over scene keeps camera zoom")
	before=editor.distance_;await magnify(scene);check(editor.distance_<before,"Pinch over scene still zooms")
	# Gesture coordinates are authoritative even if native GUI hover still points
	# at the previous panel after a focus/Retina transition.
	await motion(point_);before=editor.distance_
	var event:=InputEventPanGesture.new();event.position=root.get_final_transform()*scene;event.delta=Vector2(0,.5);Input.parse_input_event(event);await process_frame
	check(editor.distance_>before,"Scene gesture uses its own position despite a previous UI pointer")
	await motion(scene);before=editor.distance_;scroll.scroll_vertical=0
	event=InputEventPanGesture.new();event.position=root.get_final_transform()*point_;event.delta=Vector2(0,.5);Input.parse_input_event(event);await process_frame
	check(scroll.scroll_vertical>0 and editor.distance_==before,"Catalog gesture stays in the UI despite a previous scene pointer")
	city.queue_free();await create_timer(.15).timeout
	print("BUILDING_UI_SCROLL_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
