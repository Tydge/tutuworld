extends SceneTree
var rows: Array=[]
var out:="/Users/wangtaizhi/兔兔的世界/.qa-artifacts/environment-polish-local"
func _initialize() -> void:call_deferred("run")
func measure(id: String) -> void:
	for round_ in range(2):
		for i in range(60):await RenderingServer.frame_post_draw
		var samples: Array[float]=[];var start:=Time.get_ticks_usec();var previous:=start
		var draws:=0;var primitives:=0
		while Time.get_ticks_usec()-start<1500000:
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec();samples.append((now-previous)/1000.);previous=now
			draws=maxi(draws,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			primitives=maxi(primitives,int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		samples.sort();var row:={"view":id,"round":round_,"frames":samples.size(),"median_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*.95)],"draws":draws,"primitives":primitives};rows.append(row);print("BUILD_PERF ",JSON.stringify(row))
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("建造性能验收兔","bunny","bow_rose")
	root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(1920,1080);root.size=Vector2i(1920,1080);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	var city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.8).timeout;root.scaling_3d_scale=sqrt(2000000./(1920.*1080.))
	city.build_mode.open_editor();city.set_process(false);city.life.process_mode=Node.PROCESS_MODE_DISABLED
	var editor=city.build_mode;editor.ui.hide();editor.grid.hide();editor.set_process(false)
	await measure("empty_plot")
	if not editor.place_template():quit(1);return
	editor.ui.hide();editor.grid.hide();editor.room.set_process(false)
	await measure("sample_room")
	editor.ui.show();editor.grid.show();editor.set_process(true)
	await measure("editor_with_room")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/building-editor-1920.png")
	editor.set_roof_visible(true);editor.ui.hide();editor.grid.hide()
	for i in range(15):await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/building-exterior.png")
	var textures: Array=[]
	for id in ["spring_lawn_v1","packed_earth_path_v1","cultivated_soil_v1","village_stone_paving_v1","warm_tree_bark_v1","soft_lime_plaster_v1","fine_beach_sand_v1"]:
		var texture: Texture2D=load("res://assets/terrain/"+id+".png");var img:=texture.get_image()
		textures.append({"id":id,"width":img.get_width(),"height":img.get_height(),"format":img.get_format(),"compressed":img.is_compressed(),"mipmaps":img.has_mipmaps(),"bytes":img.get_data_size()})
	var f:=FileAccess.open(out+"/building-performance.json",FileAccess.WRITE);f.store_string(JSON.stringify({"driver":RenderingServer.get_current_rendering_driver_name(),"output_window":root.size,"output_texture":root.get_texture().get_size(),"scale":root.scaling_3d_scale,"rows":rows,"textures":textures},"  "));f.close()
	print("BUILDING_PERFORMANCE_RESULT PASS groups=",rows.size());quit()
