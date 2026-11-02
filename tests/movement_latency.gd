extends SceneTree
const Session=preload("res://scripts/services/session.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1
	if not ok:failures.append(label_);print("FAIL ",label_)
func run() -> void:
	var session=Session.new();session.name="Session";root.add_child(session)
	var endpoint:=OS.get_environment("TUTU_TEST_ENDPOINT")
	if endpoint=="":endpoint="ws://127.0.0.1:18894"
	var suffix:=Crypto.new().generate_random_bytes(4).hex_encode()
	var result: Dictionary=await session.login_online("register",{"username":"motion_"+suffix,"password":"test-motion-123"},endpoint)
	check(result.get("ok",false),"Connect through delayed TCP transport")
	if not result.get("ok",false):print(result);quit(1);return
	result=await session.create_online_character("试跑"+suffix,"bunny","bow_rose")
	check(result.get("ok",false),"Create isolated movement character")
	var game=load("res://scenes/city.tscn").instantiate();root.add_child(game);game.yaw=0
	await create_timer(1.3).timeout
	var actor=game.bunny;var view=game.online_view
	var original: Vector3=actor.position
	Input.action_press("move_right");actor.run_enabled=true
	await physics_frame;await physics_frame
	check(actor.position.x>original.x,"Movement starts within two local physics ticks")
	var previous: Vector3=actor.position
	var reversed:=0;var horizontal_spike:=0.0;var vertical_spike:=0.0
	var jump_start:=0.0;var peak:=0.0;var ascent_reversals:=0;var jumps:=0
	for frame in range(240):
		if frame in [24,114,204]:
			jump_start=actor.position.y;peak=0;jumps+=1;Input.action_press("jump")
		if frame in [26,116,206]:Input.action_release("jump")
		await physics_frame
		var current: Vector3=actor.position;var dx:=current.x-previous.x;var dy:=current.y-previous.y
		if dx<-.025:reversed+=1
		horizontal_spike=maxf(horizontal_spike,absf(dx));vertical_spike=maxf(vertical_spike,absf(dy))
		if jumps>0:peak=maxf(peak,current.y-jump_start)
		if frame in [26,116,206]:check(current.y>jump_start+.06,"Jump begins locally before a network round trip")
		if frame in [66,156,239]:check(peak>1.0,"Predicted jump reaches normal height")
		previous=current
	Input.action_release("move_right");Input.action_release("jump")
	await create_timer(1.4).timeout
	var p: Array=session.state().player_position
	var convergence: float=actor.position.distance_to(Vector3(p[0],p[1],p[2]))
	check(reversed==0,"No backward pulls while running under latency and jitter")
	check(horizontal_spike<.18,"No visible horizontal correction spikes")
	check(vertical_spike<.22,"Jump remains continuous through server acknowledgements")
	check(convergence<.25,"Stopped prediction converges to server")
	check(view.prediction.hard_corrections==0,"No normal-movement hard corrections")
	actor.position.x+=.65;actor.reset_physics_interpolation()
	await create_timer(1).timeout
	p=session.state().player_position
	check(view.prediction.corrections>0 and actor.position.distance_to(Vector3(p[0],p[1],p[2]))<.08,"Authoritative correction recovers an injected prediction error")
	var before: Vector3=actor.position
	var stale: Dictionary=view.motion[session.active_character_id].duplicate(true);stale.position=[999,999,999]
	view.prediction.receive(stale);view.prediction.reconcile(actor)
	check(actor.position.distance_to(before)<.01,"An already acknowledged packet cannot repeatedly pull the player")
	print("MOVEMENT_METRICS endpoint=",endpoint," reversed=",reversed," max_dx=",horizontal_spike," max_dy=",vertical_spike," convergence=",convergence," corrections=",view.prediction.corrections," historical_error=",view.prediction.max_error)
	game.queue_free();await process_frame;await session.leave_online()
	print("MOVEMENT_LATENCY_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
