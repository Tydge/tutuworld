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
 for code in [KEY_I,KEY_B,KEY_C,KEY_TAB,KEY_M,KEY_E,KEY_F,KEY_R,KEY_F2]:
  var event:=key(code);game._unhandled_input(event);key(code,false)
 check(not game.hud.overlay.visible and not game.hud.photo_mode,"Chat isolates inventory, profile, clothing, map, interaction and photo hotkeys")
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
 var benches:=0
 for target_id in game.targets:
  if not str(target_id).begins_with("bench:"):continue
  benches+=1;var target: Dictionary=game.targets[target_id];var remote: Dictionary=server.maps.city.targets.get(target_id,{})
  check(not remote.is_empty() and target.position.is_equal_approx(remote.position),"Client and server agree on the exact seat: "+target_id)
  var pawn=server.pawns[id];pawn.position=remote.node.get_node("ExitAnchor").global_position;pawn.velocity=Vector3.ZERO;pawn.reset_network_motion()
  await create_timer(.25).timeout
  game.current_target=target_id;game.interact();await create_timer(.35).timeout
  check(game.nap_active and pawn.seated and server.locks.has("city:"+target_id),"E sits on nearby seat: "+target_id)
  result=await session.request_online("stand");await create_timer(.2).timeout
  check(result.get("ok",false) and not pawn.seated and not server.locks.has("city:"+target_id),"Standing releases seat: "+target_id)
 check(benches==5,"All same-name park/beach seats exercised")
 game.queue_free();await process_frame;await session.leave_online();server.listener.stop();server.queue_free();await process_frame
 print("CHAT_SEAT_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures.is_empty() else 1)
