extends SceneTree
var session: Node
var game: Node3D
var output: String
var samples: Array=[]
var presets: Array=["baseline","agx","sky_reflection","ssil","glow","volumetric_fog","ssr","no_ssao"]
func _initialize() -> void: call_deferred("run")
func settings(id: String) -> void:
 var e: Environment=game.atmosphere
 e.tonemap_mode=Environment.TONE_MAPPER_LINEAR;e.tonemap_exposure=1.0
 e.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
 e.ssao_enabled=id!="no_ssao";e.ssil_enabled=id=="ssil";e.ssil_intensity=.6
 e.glow_enabled=id=="glow";e.glow_intensity=.4
 e.volumetric_fog_enabled=id=="volumetric_fog";e.volumetric_fog_density=.015
 e.ssr_enabled=id=="ssr"
 e.sdfgi_enabled=id=="sdfgi_low";e.sdfgi_cascades=2;e.sdfgi_min_cell_size=1.0;e.sdfgi_energy=.7
 if id=="agx": e.tonemap_mode=Environment.TONE_MAPPER_AGX
 if id=="sky_reflection": e.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
func measure(map_id: String,view_name: String,preset: String,round_: int) -> void:
 settings(preset)
 for warm in range(60 if preset!="sdfgi_low" else 180): await RenderingServer.frame_post_draw
 var times: Array[float]=[];var cpu: Array[float]=[];var draw_calls:=0
 var start:=Time.get_ticks_usec();var last:=start
 while Time.get_ticks_usec()-start<1400000:
  await RenderingServer.frame_post_draw
  var now:=Time.get_ticks_usec();times.append((now-last)/1000.);last=now
  cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
  draw_calls=maxi(draw_calls,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
 times.sort();cpu.sort()
 var median: float=times[times.size()/2]
 var row:={"map":map_id,"view":view_name,"preset":preset,"round":round_,"samples":times.size(),"median_ms":median,"p95_ms":times[mini(times.size()-1,int(times.size()*.95))],"cpu_process_median_ms":cpu[cpu.size()/2],"draw_calls":draw_calls,"render_memory_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0}
 samples.append(row);print("AB_SAMPLE ",JSON.stringify(row))
 if round_==0 and preset in ["baseline","agx","sky_reflection","ssil","volumetric_fog"]:
  root.get_texture().get_image().save_png(output+"/"+map_id+"-"+view_name+"-"+preset+".png")
 var f:=FileAccess.open(output+"/results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"samples":samples,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"output":root.size,"scale":root.scaling_3d_scale,"vsync":DisplayServer.window_get_vsync_mode(),"msaa":root.msaa_3d,"render_pixels":root.size.x*root.size.y*pow(root.scaling_3d_scale,2),"static_simulation":true},"  "));f.close()
func run() -> void:
 output=OS.get_environment("TUTU_GRAPHICS_RESEARCH_OUTPUT");DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(1920,1080)
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
 session.create_character("画面调研兔","bunny","bow_rose");session.settings.render_quality="balanced"
 Engine.max_fps=0
 for map_id in ["city","valley"]:
  session.state().map_id=map_id;session.state().time=1800;session.active=false
  game=load("res://scenes/"+map_id+".tscn").instantiate();root.add_child(game);current_scene=game
  while game.preparing or game.camera==null:await process_frame
  await create_timer(1).timeout
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
  await create_timer(.6).timeout
  root.size=Vector2i(1920,1080)
  await create_timer(.6).timeout
  root.scaling_3d_scale=minf(1.0,sqrt(2000000.0/(float(root.size.x)*root.size.y)))
  print("MEASURE_VIEWPORT ",root.size," scale=",root.scaling_3d_scale)
  game.hud.hide();game.process_mode=Node.PROCESS_MODE_DISABLED
  for n in game.scenery.find_children("*","GeometryInstance3D",true,false):n.gi_mode=GeometryInstance3D.GI_MODE_STATIC
  var views: Array=[]
  if map_id=="city": views=[["garden",Vector3(39,.2,5),Vector3(52,12,18),Vector3(32,1,-4),.5],["workshop_night",Vector3(32,.2,-27),Vector3(39,8,-16),Vector3(33,1,-27),.92]]
  else: views=[["bridge",Vector3(-7,.1,5),Vector3(6,9,20),Vector3(-6,1,4),.5]]
  for view in views:
   game.bunny.position=view[1];game.camera.position=view[2];game.camera.look_at(view[3]);session.state().time=view[4]*3600;game.update_lighting()
   for building in game.interiors:
    building._process(.5)
   for round_ in range(2):
    var order: Array=presets.duplicate()
    if round_==1:order.reverse()
    for preset in order:await measure(map_id,view[0],preset,round_)
  game.queue_free();current_scene=null;await process_frame;await process_frame
 print("GRAPHICS_RESEARCH_RESULT PASS samples=",samples.size())
 quit()
