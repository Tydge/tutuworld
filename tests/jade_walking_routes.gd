extends SceneTree
## Walk the public doors and stairs with real character physics.
## For faster local simulation, launch headless with --fixed-fps 60.
const Gallery=preload("res://scripts/jade/street_gallery.gd")
const J=preload("res://scripts/jade/layout.gd")
var game: Node3D
var actor: CharacterBody3D
var failures: Array[String]=[]
var passed:=0

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var session=preload("res://scripts/services/session.gd").new()
	session.name="Session";root.add_child(session)
	session.create_character("玉京通行检查","bunny","bow_rose")
	session.state().map_id="jade";session.state().player_position=J.arrival()
	game=load("res://scenes/jade.tscn").instantiate();root.add_child(game)
	actor=game.bunny
	for i in range(12):await physics_frame
	# Keep the buildings, solids and player physics active while isolating public architecture from passing residents.
	game.set_process(false);session.active=false
	for npc in game.npcs:
		npc.set_physics_process(false)
		npc.collision_layer=0
		npc.collision_mask=0
	sculpture_clearance()
	for h in J.HOUSES:
		var room: Node3D=game.scenery.get_node(("Shop_" if J.shops().has(h[0]) else "Hall_")+h[0])
		await doorway(room,h[0])
		if h[4] in ["inn","loft","clocktower"]:await upper_floor(room,h[0])
		if h[4]=="theatre":await auditorium(room,h[1])
		if h[0] in ["drum","baihe"]:await processional_terrace(room,h[1])
	var galleries: Array=game.scenery.get_children().filter(func(node):return node.get_meta("furniture_kind","") in ["jade_street_gallery","jade_street_gallery_reverse"])
	check(galleries.size()==2,"两座跨街步廊")
	for gallery in galleries:await cross_gallery(gallery)
	for bridge_x in J.BRIDGES:await cross_river(bridge_x)
	await river_garden()
	await stand(J.point(0.,203.))
	await waypoint(J.point(0.,192.),"南码头步行入城")
	await stand(J.point(2.,-104.))
	await waypoint(J.point(2.,-155.),"宫阶北行")
	await waypoint(J.point(2.,-104.),"宫阶南行")
	print("JADE_WALKING_ROUTES passes=",passed," failures=",failures)
	game.free();session.free();quit(int(not failures.is_empty()))

func stand(point: Vector3) -> void:
	Input.action_release("move_up")
	actor.global_position=point+Vector3.UP*.085
	actor.velocity=Vector3.ZERO;actor.reset_physics_interpolation()
	for i in range(9):await physics_frame

func check(ok: bool,label_: String) -> void:
	if ok:
		passed+=1;print("PASS ",label_)
	else:
		failures.append(label_)
		print("FAIL ",label_," position=",actor.global_position," contacts=",contacts())

func contacts() -> Array:
	var results: Array=[]
	for i in actor.get_slide_collision_count():
		var hit:=actor.get_slide_collision(i)
		results.append([hit.get_collider().get_path(),hit.get_normal()])
	return results

func doorway(room: Node3D,id: String) -> void:
	var front: float=room.floor_size.y*.5
	game.yaw=room.rotation.y
	for x in [0.,.65,-.65,1.10,-1.10]:
		var start:=room.to_global(Vector3(x,0.,front+3.))
		if not J.can_walk(start):continue
		start.y=J.foot(start.x,start.z)
		await stand(start)
		Input.action_press("move_up")
		for i in range(88):await physics_frame
		Input.action_release("move_up")
		if room.contains_position(actor.global_position) and room.to_local(actor.global_position).z<front-.65:
			check(true,id+" 从街面进入");return
	check(false,id+" 从街面进入")

func waypoint(to: Vector3,label_: String) -> bool:
	var goal:=Vector2(to.x,to.z)
	var start:=Vector2(actor.position.x,actor.position.z)
	var limit:=ceili(start.distance_to(goal)*35.)+70
	Input.action_press("move_up")
	for i in range(limit):
		var direction:=goal-Vector2(actor.position.x,actor.position.z)
		if direction.length()<.18:break
		game.yaw=atan2(-direction.x,-direction.y)
		await physics_frame
	Input.action_release("move_up")
	for i in range(4):await physics_frame
	var arrived:=goal.distance_to(Vector2(actor.position.x,actor.position.z))<.42 and absf(actor.position.y-to.y)<.38
	check(arrived,label_)
	return arrived

func upper_floor(room: Node3D,id: String) -> void:
	var w: float=room.floor_size.x*.5
	var d: float=room.floor_size.y*.5
	var height: float=room.wall_height
	var start:=room.to_global(Vector3(w+1.86,0,-d-2.3))
	start.y=J.foot(start.x,start.z)
	var landing:=room.to_global(Vector3(w+1.86,height,d+.06))
	var cross:=room.to_global(Vector3(w-1.65,height,d+.12))
	var inside:=room.to_global(Vector3(w-1.65,height,d-1.65))
	await stand(start)
	for row in [[landing,"上楼"],[cross,"平台转向"],[inside,"走进上层"],[cross,"走出上层"],[landing,"回到梯口"],[start,"下至街面"]]:
		if not await waypoint(row[0],id+" "+row[1]):return

func cross_gallery(gallery: Node3D) -> void:
	var label_:="跨街廊 z=%d "%roundi(gallery.position.z)
	var handedness: float=-1. if gallery.get_meta("furniture_kind")=="jade_street_gallery_reverse" else 1.
	for side: float in [-1.,1.]:
		var start:=gallery.to_global(Vector3(side*Gallery.HALF,0.,handedness*side*(Gallery.RUN+2.5)))
		var landing:=gallery.to_global(Vector3(side*Gallery.HALF,Gallery.HEIGHT,0.))
		var across:=gallery.to_global(Vector3(-side*Gallery.HALF,Gallery.HEIGHT,0.))
		var end:=gallery.to_global(Vector3(-side*Gallery.HALF,0.,-handedness*side*(Gallery.RUN+2.5)))
		start.y=J.foot(start.x,start.z);end.y=J.foot(end.x,end.z)
		await stand(start)
		if not await waypoint(landing,label_+"登廊"):continue
		if not await waypoint(across,label_+"过街"):continue
		await waypoint(end,label_+"走下对侧")
	var south:=gallery.to_global(Vector3(0.,0.,5.));south.y=J.foot(south.x,south.z)
	var north:=gallery.to_global(Vector3(0.,0.,-5.));north.y=J.foot(north.x,north.z)
	await stand(south)
	await waypoint(north,label_+"桥底步行")

func auditorium(room: Node3D,sign_: String) -> void:
	var w: float=room.floor_size.x*.5
	var d: float=room.floor_size.y*.5
	var h: float=room.wall_height
	var start:=room.to_global(Vector3(w+1.39,0.,-d-2.25))
	start.y=J.foot(start.x,start.z)
	var landing:=room.to_global(Vector3(w+1.39,h,d+.02))
	var flank:=room.to_global(Vector3(w+.05,h,d-.32))
	var entrance:=room.to_global(Vector3(w+.05,h,-d*.58))
	var balcony:=room.to_global(Vector3(w-2.,h,-d*.58))
	await stand(start)
	for row in [[landing,"上梯"],[flank,"到侧廊"],[entrance,"到栏杆开口"],[balcony,"进上层看台"],[entrance,"离开看台"],[flank,"沿廊返回"],[landing,"转回梯口"],[start,"下至街面"]]:
		if not await waypoint(row[0],sign_+" "+row[1]):return

func cross_river(x: float) -> void:
	var center:=J.river_z(x)
	var south:=J.point(x,center+22.)
	var north:=J.point(x,center-22.)
	await stand(south)
	if not await waypoint(north,"玉带河 "+str(x)+" 向北过桥"):return
	await waypoint(south,"玉带河 "+str(x)+" 向南过桥")

func river_garden() -> void:
	# Enter from the towpath, follow the axis of the folded gallery, and reach the pond edge.
	var path: Array[Vector2]=[
		Vector2(106,-16),Vector2(106,-22),Vector2(111,-23),Vector2(114,-26),
		Vector2(117,-29),Vector2(118.55,-30.35),Vector2(119,-33),Vector2(119,-37),Vector2(122,-40)]
	await stand(J.point(path[0].x,path[0].y))
	for point in path.slice(1):
		if not await waypoint(J.point(point.x,point.y),"藕香水榭 入园 "+str(point)):return
	path.reverse()
	for point in path.slice(1):
		if not await waypoint(J.point(point.x,point.y),"藕香水榭 返程 "+str(point)):return

func sculpture_clearance() -> void:
	var probe:=PhysicsShapeQueryParameters3D.new()
	var footprint:=BoxShape3D.new()
	footprint.size=Vector3(1.72,.68,1.64)
	probe.shape=footprint
	probe.collision_mask=0xffffffff
	for fixture in game.scenery.get_children():
		if fixture.get_meta("furniture_kind","")!="jade_crane":continue
		probe.transform=fixture.global_transform.translated(Vector3.UP*.62)
		var hits:=actor.get_world_3d().direct_space_state.intersect_shape(probe)
		var walls:=hits.filter(func(hit):return str(hit.collider.name)=="PalaceWall")
		check(walls.is_empty(),"铜鹤基座露出宫墙 "+str(fixture.global_position))

func processional_terrace(room: Node3D,sign_: String) -> void:
	var side:=signf(room.global_position.x)
	var middle:=J.point(side*2.2,room.global_position.z)
	var curb:=J.point(room.global_position.x-side*9.7,room.global_position.z)
	var d: float=room.floor_size.y*.5
	var outer: Vector3=room.to_global(Vector3(0,0,d+.9))
	var inner: Vector3=room.to_global(Vector3(0,room.floor_level,d-1.5))
	await stand(middle)
	for entry in [[curb,"从御道上台基"],[outer,"从台基到门前"],[inner,"迈过门槛"],[outer,"出门"],[curb,"回到台基前沿"],[middle,"下台基回御道"]]:
		if not await waypoint(entry[0],sign_+" "+entry[1]):return
