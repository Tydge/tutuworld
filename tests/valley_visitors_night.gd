extends SceneTree
var checks:=0
var failures: Array=[]
var OUT=preload("res://tests/test_support.gd").output_dir()+"/"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func run() -> void:
	root.size=Vector2i(1440,900)
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.state().map_id="valley";session.state().time=21.5*150;session.state().player_position=[-18,.1,22]
	var game=load("res://scenes/valley.tscn").instantiate();root.add_child(game);await create_timer(2).timeout
	Engine.max_fps=30;session.active=false;game.bunny.can_move=false
	while not game.navigation.ready_for_paths: await physics_frame
	check(game.npcs.size()==3,"Exactly Panda plus two rabbit visitors")
	var visitors: Array=[]
	for id in ["ValleyVisitor0","ValleyVisitor1"]:
		var n: CharacterBody3D=game.targets[id].node;visitors.append(n)
		check(n.rig_profile.species_id=="bunny" and n.get_meta("equipment").size()==3,"Random outfit, shared rabbit actor "+id)
		check(n.get_meta("interaction_available") and n.visible,"21:30 visitor still present "+id)
	game.bunny.position=visitors[0].position+Vector3(1.7,0,0);game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation()
	game.current_target="ValleyVisitor0";game.interact()
	check(game.talking_npc=="ValleyVisitor0" and game.hud.bubble.visible,"Visitor supports normal dialogue")
	session.state().time=22*150;await create_timer(.25).timeout
	check(game.talking_npc=="" and not game.hud.bubble.visible,"22:00 fade cancels active conversation")
	for n in visitors:
		var r: Node=n.get_node("VisitorRoutine")
		check(r.presence>0 and r.presence<1 and n.visible and n.collision_layer==0,"Smooth partial fade and no ghost collision "+str(n.name))
		check(not n.get_meta("interaction_available") and r.parts.all(func(p):return is_equal_approx(p.transparency,1-r.presence)),"All body and clothes fade together; unavailable "+str(n.name))
	game.update_target();check(game.current_target!="ValleyVisitor0","Selection skips fading visitor")
	game.current_target="ValleyVisitor0";game.interact();check(game.talking_npc=="","Stale selection cannot start dialogue")
	await create_timer(1.3).timeout
	for n in visitors:
		check(not n.visible and n.get_meta("presence")==0 and not n.is_physics_processing(),"Fully hidden and idle overnight "+str(n.name))
	session.state().time=5.99*150;await create_timer(.6).timeout
	check(visitors.all(func(n): return not n.visible),"Still absent before 06:00, including world culling updates")
	session.state().time=6*150;await create_timer(.25).timeout
	check(visitors.all(func(n):return n.visible and n.get_meta("presence")>0 and n.get_meta("presence")<1 and not n.get_meta("interaction_available")),"06:00 smooth fade in blocks interaction")
	await create_timer(1.0).timeout
	for n in visitors: check(n.get_meta("interaction_available") and n.collision_layer==2 and n.is_physics_processing(),"After fade restores walk, collision and dialogue "+str(n.name))
	var initial: Array=[visitors[0].position,visitors[1].position]
	Engine.time_scale=3;await create_timer(9).timeout;Engine.time_scale=1
	for i in range(2): check(visitors[i].position.distance_to(initial[i])>1.5,"Visitor roams connected forest "+str(i))
	session.state().time=3300;game.update_lighting();await create_timer(1.3).timeout
	check(game.lamps.size()==3 and game.sun.light_energy>=.29,"Forest uses moonlight and only three trail lamps")
	check(game.life.motes.visible and game.life.mote_count==24 and game.life.halos.visible and game.life.glow_lights.all(func(l): return l.visible and l.light_energy>0 and not l.shadow_enabled),"Night-only fireflies have halos and three cheap real lights")
	check(game.life.butterflies.all(func(b):return not b.node.visible),"Butterflies absent at night")
	game.set_process(false);game.hud.visible=false;game.bunny.position=Vector3(-6,.2,5);game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation()
	game.camera.position=Vector3(-12,8,18);game.camera.look_at(Vector3(0,1.2,5))
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"山谷-月光萤火.png")
	session.state().time=1800;game.update_lighting();await create_timer(.2).timeout
	check(not game.life.motes.visible and not game.life.halos.visible and game.life.glow_lights.all(func(l):return not l.visible),"Firefly lights disappear in daylight")
	print("VALLEY_VISITORS_NIGHT_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
