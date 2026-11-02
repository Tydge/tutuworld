extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func run() -> void:
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	preload("res://scripts/city/frame_pacer.gd").ensure(session);await process_frame
	var policy:=root.get_node("FramePacer")
	for fps in [60,90,120]:
		session.set_setting("fps_limit",fps)
		policy.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		check(Engine.max_fps==fps,"Focus-in restores "+str(fps))
		policy.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(Engine.max_fps==20,"Focus-out throttles "+str(fps))
	session.set_setting("fps_limit_enabled",false)
	check(Engine.max_fps==20,"Uncapped foreground still throttles in background")
	policy.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(Engine.max_fps==0,"Uncapped foreground restores")
	policy.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);session.set_setting("background_throttle",false)
	check(Engine.max_fps==0,"Background toggle can disable throttle")
	session.set_setting("background_throttle",true);session.active=true
	var before: float=session.state().time
	await create_timer(.24).timeout
	check(session.state().time-before>=.19,"World clock continues in background")
	session.set_setting("fps_limit_enabled",true);session.set_setting("fps_limit",60)
	policy.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(Engine.max_fps==60,"Restored default policy")
	print("FRAME_POLICY_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
