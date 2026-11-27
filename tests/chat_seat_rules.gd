extends SceneTree
const Server=preload("res://server/world_server.gd")
const Session=preload("res://scripts/services/session.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
 checks+=1
 if not ok:failures.append(label_);print("FAIL ",label_)
func key(code: int,pressed: bool=true) -> InputEventKey:
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
 Input.parse_input_event(event)
 return event
func run() -> void:
 OS.set_environment("TUTU_GAME_PORT","18902")
 OS.set_environment("TUTU_STATE_DIR",ProjectSettings.globalize_path("res://.qa-artifacts/0.3.2/chat-"+str(Time.get_ticks_usec())))
 var server=Server.new();root.add_child(server)
 while not server.ready_for_players:await process_frame
 var session=Session.new();session.name="Session";root.add_child(session)
 var suffix:=Crypto.new().generate_random_bytes(4).hex_encode()
 var result: Dictionary=await session.login_online("register",{"username":"chat_"+suffix,"password":"test-chat-123"},"ws://127.0.0.1:18902")
 check(result.get("ok",false),"Real account connection")
 if not result.get("ok",false):quit(1);return
 result=await session.create_online_character("输入测试"+suffix.left(4),"cat_teacher","vest_sage")
 check(result.get("ok",false),"Create isolated online cat")
 var game=load("res://scenes/city.tscn").instantiate();root.add_child(game);await create_timer(.6).timeout
 var view=game.online_view;var actor=game.bunny;var id: String=session.active_character_id
 key(KEY_W);await create_timer(.3).timeout
 view.open_chat();await create_timer(.5).timeout
 var start: Vector3=actor.position;var running: bool=actor.run_enabled
 for code in [KEY_I,KEY_B,KEY_C,KEY_TAB,KEY_M,KEY_E,KEY_F,KEY_R,KEY_F2,KEY_F6,KEY_F9]:
  var event:=key(code);game._unhandled_input(event);key(code,false)
 check(game.bunny.emote.is_empty() and not game.build_mode.active and not game.hud.overlay.visible and not game.hud.photo_mode,"Chat isolates panel, interaction and social hotkeys")
 check(view.chat_card.visible and game.is_text_entry_active(),"Text mode remains active after Tab/focus changes")
 key(KEY_SHIFT);key(KEY_W);view.chat_input.text="中文聊天测试 🍊"
 await create_timer(.4).timeout
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/聊天时快捷键与中文输入.png")
 check(Vector2(actor.position.x-start.x,actor.position.z-start.z).length()<.08 and actor.run_enabled==running and view.chat_input.has_focus(),"IME modifier keys do not move the avatar, toggle running or move focus away")
 view.send_chat(view.chat_input.text)
 await physics_frame
 check(not view.chat_card.visible and not Input.is_action_pressed("move_up") and not Input.is_physical_key_pressed(KEY_W) and not Input.is_action_pressed("sprint"),"Closing chat releases actions and physical keys even if key-up was swallowed")
 start=actor.position;await create_timer(.7).timeout
 check(Vector2(actor.position.x-start.x,actor.position.z-start.z).length()<.08,"No stuck movement after submitting Chinese text")
 check(view.chat.feed.visible and view.chat.lines.get_child_count()==1 and view.chat.lines.get_child(0).get_parsed_text().ends_with("中文聊天测试 🍊"),"Own server echo appears once in the world feed")
 var away := {"type":"chat","id":"traveller","name":"阿棠","text":"山谷的橘子熟了 🍊 [b]","map":"valley"}
 session.remote.message_received.emit(away)
 check(view.chat.lines.get_child(1).get_parsed_text()=="阿棠　山谷的橘子熟了 🍊 [b]" and not view.bubbles.has("traveller"),"Away-map text and emoji stay literal and do not create a local bubble")
 var restored=preload("res://scripts/ui/world_chat.gd").new()
 game.hud.root_ui.add_child(restored);restored.setup(session)
 check(restored.lines.get_child_count()==2,"Changing the HUD during travel restores unexpired messages")
 restored.free()
 if DisplayServer.get_name()!="headless":
  await create_timer(.2).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/世界聊天.png")
 for i in 6:session.remote.message_received.emit(away.merged({"text":"第%d条"%i},true))
 check(view.chat.lines.get_child_count()==5 and session.recent_chat.size()==5 and view.chat.lines.get_child(0).get_parsed_text().ends_with("第1条"),"Burst traffic keeps only the five newest messages")
 var long_line: String="田边见".repeat(40)
 session.remote.message_received.emit(away.merged({"text":long_line},true))
 for i in 3:await process_frame
 var latest: RichTextLabel=view.chat.lines.get_child(-1)
 check(latest.visible and latest.get_parsed_text().ends_with(long_line) and latest.get_content_height()>40,"A full 120-character message wraps and stays readable")
 await create_timer(13.6).timeout
 check(view.chat.feed.visible and view.chat.feed.modulate.a<1.,"Chat fades before expiry")
 await create_timer(1.7).timeout
 check(not view.chat.feed.visible and session.recent_chat.is_empty(),"Expired chat disappears from the HUD and session memory")
 key(KEY_D);await create_timer(.3).timeout;key(KEY_D,false)
 check(Vector2(actor.position.x-start.x,actor.position.z-start.z).length()>.15,"Fresh movement press works after chat")
 view.open_chat();key(KEY_A);key(KEY_ESCAPE);await create_timer(.1).timeout;key(KEY_ESCAPE,false)
 check(not view.chat_card.visible and not game.hud.overlay.visible and not Input.is_action_pressed("move_left"),"Escape cancels chat without opening settings and clears held direction")
 key(KEY_W);view._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(not Input.is_action_pressed("move_up") and not Input.is_physical_key_pressed(KEY_W),"Focus loss clears movement state")
 view.open_chat();game.hud.open_panel("bag")
 check(not view.chat_card.visible and game.hud.overlay.visible,"Mouse panel action switches away from chat cleanly")
 game.hud.close_panel()
 for npc in server.maps.city.npcs:npc.process_mode=Node.PROCESS_MODE_DISABLED;npc.collision_layer=0;npc.hide()
 var seat_counts := {}
 for target_id in game.targets:
  if not str(target_id).begins_with("bench:"):continue
  var area := str(target_id).get_slice(":",1)
  seat_counts[area] = int(seat_counts.get(area,0))+1
  var target: Dictionary=game.targets[target_id];var remote: Dictionary=server.maps.city.targets.get(target_id,{})
  check(not remote.is_empty() and target.position.is_equal_approx(remote.position),"Client and server agree on the exact seat: "+target_id)
  var pawn=server.pawns[id];pawn.position=remote.node.get_node("ExitAnchor").global_position;pawn.velocity=Vector3.ZERO;pawn.reset_network_motion()
  await create_timer(.25).timeout
  game.current_target=target_id;game.interact();await create_timer(.35).timeout
  check(game.nap_active and pawn.seated and server.locks.has("city:"+target_id),"E sits on nearby seat: "+target_id)
  result=await session.request_online("stand");await create_timer(.2).timeout
  check(result.get("ok",false) and not pawn.seated and not server.locks.has("city:"+target_id),"Standing releases seat: "+target_id)
 check(seat_counts=={"CentralPark":4,"SouthBeach":1,"EastBuildingSite/GardenCommons":4},"Exercise park, beach and garden seats")
 game.queue_free();await process_frame;await session.leave_online();server.listener.stop();server.queue_free();await process_frame
 print("CHAT_SEAT_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures.is_empty() else 1)
