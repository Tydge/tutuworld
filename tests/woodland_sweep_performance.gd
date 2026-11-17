extends SceneTree
const L=preload("res://scripts/valley/valley_layout.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var s=load("res://scripts/services/session.gd").new();s.name="Session";root.add_child(s);s.create_character("林间行走性能","panda","scarf_green");s.state().map_id="valley";s.state().player_position=L.arrival("valley");s.state().time=1800
 var g=load("res://scenes/valley.tscn").instantiate();root.add_child(g)
 while g.preparing or g.camera==null or not g.navigation.ready_for_paths:await process_frame
 s.active=false;g.bunny.can_move=false;Engine.max_fps=60
 await create_timer(1.).timeout
 var samples: Array[float]=[];var started:=Time.get_ticks_usec();var previous:=started;var draws:=0;var primitives:=0
 while Time.get_ticks_usec()-started<12000000:
  var elapsed: float=(Time.get_ticks_usec()-started)/1000000.
  # Faster than normal walking: cross spatial batches and LOD thresholds repeatedly.
  var z: float=lerpf(86.,-65.,clampf(elapsed/12.,0,1));var x:=L.west_path(z)
  g.bunny.position=Vector3(x,L.walk_height(x,z)+.035,z);g.bunny.velocity=Vector3.ZERO;g.bunny.reset_physics_interpolation();g.yaw=.4+sin(elapsed*.9)*.9
  await RenderingServer.frame_post_draw
  var now:=Time.get_ticks_usec();samples.append((now-previous)/1000.);previous=now
  draws=maxi(draws,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)));primitives=maxi(primitives,int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
 samples.sort();var p95: float=samples[int(samples.size()*.95)];var slow: int=samples.filter(func(v):return v>50.).size()
 print("WOODLAND_SWEEP output=",root.size," scale=",root.scaling_3d_scale," method=",RenderingServer.get_current_rendering_method()," fps=",samples.size()/12.," p95_ms=",p95," max_ms=",samples[-1]," over50=",slow," draws=",draws," primitives=",primitives," vram_mb=",Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.)
 var okay:=p95<34. and slow==0
 print("WOODLAND_SWEEP_PERFORMANCE_RESULT ","PASS" if okay else "FAIL");quit(0 if okay else 1)
