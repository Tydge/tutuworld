extends SceneTree
## Interactive, isolated local preview. Never reads or writes the player's real progress.
const L=preload("res://scripts/valley/valley_layout.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
 if not OS.get_cmdline_user_args().has("--test"):
  push_error("This preview requires --test to protect real player progress.");quit(1);return
 var s=load("res://scripts/services/session.gd").new();s.name="Session";root.add_child(s);s.create_character("山谷散步","panda","scarf_green")
 s.state().map_id="valley";s.state().time=1800;s.settings.fps_limit=60;Engine.max_fps=60
 var harbor:=OS.get_cmdline_user_args().has("--harbor")
 var x:=-24.4 if harbor else -40.;var z: float=L.DOCK.y if harbor else L.ascent_path_z(x);s.state().player_position=[x,L.walk_height(x,z)+.035,z]
 for tool in ["copper_axe","copper_pickaxe","copper_shovel"]:
  if not preload("res://scripts/services/game_data.gd").item(tool).is_empty():s.authority.add(tool,1)
 var g=load("res://scenes/valley.tscn").instantiate();root.add_child(g);current_scene=g
 while g.preparing or g.camera==null or not g.navigation.ready_for_paths:await process_frame
 g.pitch=.18
 if harbor:g.yaw=-1.;g.distance_=7.5
 g.hud.notify("本地山谷预览：沿山路可登高，过桥可探索对岸。使用独立测试角色。")
 print("LOCAL_VALLEY_PREVIEW_READY isolated=true position=",g.bunny.position," trees=",g.scenery.get_meta("ancient_tree_count")," ridge_trees=",g.scenery.get_meta("ridge_tree_count")," grass=",g.scenery.get_meta("grass_clump_count"))
 for frame in range(15):await process_frame
 await RenderingServer.frame_post_draw
 var folder:=ProjectSettings.globalize_path("res://.qa-artifacts/local-valley-preview");DirAccess.make_dir_recursive_absolute(folder)
 root.get_texture().get_image().save_png(folder+"/ready.png")
