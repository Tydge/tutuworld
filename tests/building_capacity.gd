extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const Grid=preload("res://scripts/building/grid_layout.gd")
const Site=preload("res://scripts/building/site.gd")
var city: Node3D
var editor: Node
var rows: Array=[]
var forced:=0
var last_draw:=0
var watchdog: Node
func _initialize() -> void:call_deferred("run")
func push(data: Dictionary,row: Dictionary) -> void:
	row.id="build_%d"%data.next_id;data.next_id+=1;data.elements.append(row)
func floor_() -> Dictionary:return L.add(L.empty(),{"type":"floor","a":[61.,-7.],"b":[97.,27.],"color":"cda56e","style":"wood"})
func plants(count: int,lights: int=0) -> Dictionary:
	var data:=floor_()
	for i in range(count):push(data,{"type":"object","kind":"forest_planter","position":[61.75+(i%24)*1.5,-6.25+floori(i/24.)*1.5],"yaw":0.})
	if lights>0:
		data=L.add(data,{"type":"roof","a":[70.,0.],"b":[82.,12.]});var roof_id: String=data.elements[-1].id
		for i in range(lights):push(data,{"type":"object","kind":"pendant","position":[71.5+(i%6)*1.5,1.5+floori(i/6.)*1.5],"yaw":0.,"support":roof_id})
	return data
func record(name_: String,data: Dictionary,distance_: float=52.,night: bool=false) -> void:
	var begin:=Time.get_ticks_usec();var validated:=L.validate(data);var validation_ms: float=(Time.get_ticks_usec()-begin)/1000.
	if not validated.ok:print("FAIL capacity fixture ",name_,": ",validated.message);quit(1);return
	begin=Time.get_ticks_usec();var ok: bool=editor.commit(validated.layout);var initial_ms: float=(Time.get_ticks_usec()-begin)/1000.
	if not ok:print("FAIL capacity commit ",name_);quit(1);return
	editor.distance_=distance_;editor.focus=Site.CENTER;editor.update_camera();editor.ui.hide();editor.grid.hide();city.update_lighting(.92 if night else .5)
	for i in range(8):
		editor.yaw+=.0001;editor.update_camera();await process_frame;RenderingServer.force_draw()
	var samples: Array[float]=[];var draws:=0;var primitives:=0
	for i in range(30):
		editor.yaw+=.0001;editor.update_camera();await process_frame
		var draw_begin:=Time.get_ticks_usec();RenderingServer.force_draw();samples.append((Time.get_ticks_usec()-draw_begin)/1000.);draws=maxi(draws,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)));primitives=maxi(primitives,int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	samples.sort();var edit: Dictionary={}
	if name_ in ["full_floor","checkerboard_floor"]:
		var source: Dictionary=L.compiled(editor.layout).floors[Vector2i(146,8)];var original:=L.unit_at(editor.layout,source.id,Vector2(73.25,4.25));var painted:=original.duplicate(true);painted.color="ba8177";painted.style="plaster"
		begin=Time.get_ticks_usec();editor.commit(L.replace_unit(editor.layout,original,painted));edit={"cell_paint_ms":(Time.get_ticks_usec()-begin)/1000.,"sync":editor.room.last_sync.duplicate(true)}
	elif name_.begins_with("wall_") or name_=="fragmented_wall_limit":
		var edge: Vector3i=L.compiled(editor.layout).walls.keys()[0];begin=Time.get_ticks_usec();editor.commit(L.demolish(editor.layout,Rect2(),"wall",edge));edit={"wall_cut_ms":(Time.get_ticks_usec()-begin)/1000.,"sync":editor.room.last_sync.duplicate(true)}
	for row in editor.layout.elements:
		if row.type!="object" or row.kind!="forest_planter":continue
		var moved: Dictionary=row.duplicate(true);moved.position[0]+=.05;begin=Time.get_ticks_usec();editor.commit(L.replace(editor.layout,moved));edit={"move_ms":(Time.get_ticks_usec()-begin)/1000.,"sync":editor.room.last_sync.duplicate(true)};break
	var folder: String=ProjectSettings.globalize_path("res://.qa-artifacts/building-capacity-store");DirAccess.make_dir_recursive_absolute(folder);begin=Time.get_ticks_usec();var stored:=preload("res://scripts/building/layout_store.gd").write(folder+"/save.json","benchmark","local",editor.layout);var store_ms: float=(Time.get_ticks_usec()-begin)/1000.
	var result:={"name":name_,"usage":L.usage(validated.layout),"usage_after_edit":L.usage(editor.layout),"records":editor.layout.elements.size(),"modules":editor.room.render_cache.size(),"render_submit_median_ms":samples[15],"render_submit_p95_ms":samples[28],"render_submit_max_ms":samples[-1],"samples":samples.size(),"draw_calls":draws,"primitives":primitives,"cold_validation_ms":validation_ms,"initial_commit_ms":initial_ms,"edit":edit,"layout_checkpoint_ms":store_ms,"checkpoint_ok":stored,"static_memory_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC))}
	rows.append(result);print("BUILDING_CAPACITY ",JSON.stringify(result))
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("容量验收兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.7).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1920,1080);await create_timer(1.4).timeout
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);OS.low_processor_usage_mode=false;editor=city.build_mode;editor.open_editor();editor.set_process(false);editor.ui.hide();editor.grid.hide()
	await record("full_floor",floor_())
	var checker:=L.empty()
	for z in range(-14,54):
		for x in range(122,194):push(checker,{"type":"floor","a":[x*.5,z*.5],"b":[x*.5+.5,z*.5+.5],"color":"b8c4a3" if (x+z)%2 else "cda56e","style":"plaster"})
	await record("checkerboard_floor",checker)
	var walls:=floor_()
	for i in range(32):walls=L.add(walls,{"type":"wall","a":[62.,-5.+i],"b":[94.,-5.+i]})
	await record("wall_runs_2048_edges",walls)
	var fragments:=floor_()
	for i in range(mini(512,L.MAX_WALL_RUNS)):
		var x:=62.+(i%32);var z:=-5.+floori(i/32.)*1.5;fragments=L.add(fragments,{"type":"wall","a":[x,z],"b":[x+.5,z]})
	await record("fragmented_wall_limit",fragments)
	await record("plants_256",plants(mini(256,L.MAX_ELEMENTS)))
	if L.MAX_ELEMENTS>256:await record("plants_limit",plants(L.MAX_ELEMENTS))
	await record("lights_12",plants(0,mini(12,L.MAX_LIGHTS)),27.,true)
	await record("lights_limit",plants(0,L.MAX_LIGHTS),27.,true)
	await record("combined_limits",plants(L.MAX_ELEMENTS-L.MAX_LIGHTS,L.MAX_LIGHTS),48.,true)
	var out:=preload("res://tests/test_support.gd").output_dir().get_base_dir()+"/capacity.json";var file:=FileAccess.open(out,FileAccess.WRITE);file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"window":str(root.size),"scale":root.scaling_3d_scale,"msaa":root.msaa_3d,"forced_frames":forced,"metric":"synchronous force_draw CPU wall time; excludes GPU completion; no FPS claim","limits":{"objects":L.MAX_ELEMENTS,"lights":L.MAX_LIGHTS,"wall_edges":L.MAX_WALL_EDGES,"wall_runs":L.MAX_WALL_RUNS},"rows":rows},"  "));file.close()
	print("BUILDING_CAPACITY_RESULT PASS cases=",rows.size()," forced_frames=",forced," record=",out);quit()
