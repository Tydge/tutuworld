extends SceneTree
var checks:=0
var failures: Array=[]
var game: Node3D
var session: Node
var OUT=preload("res://tests/test_support.gd").output_dir()+"/"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func edge_points(center: Vector3,width_: float,depth: float,base: float,rise: float) -> Array[Vector3]:
	var points: Array[Vector3]=[]
	var span: float=width_*.5+.5
	for side in [-1.,1.]:
		for i in range(25):
			var u: float=(i+.2)/25.
			points.append(center+Vector3(side*span*u,base+rise*(1-u)+.10,depth*.5+.65))
			points.append(center+Vector3(side*span,base+.06,lerpf(-depth*.5-.4,depth*.5+.4,u)))
	return points
func run() -> void:
	root.size=Vector2i(2400,1440)
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);Engine.max_fps=30
	game=load("res://scenes/city.tscn").instantiate();root.add_child(game);await create_timer(1).timeout
	game.set_process(false);session.active=false;game.bunny.can_move=false;game.hud.visible=false
	game.update_lighting(.5)
	var cases: Array=[
		[game.home,12.0,10.0,4.58,1.8,"小屋"],
		[game.scenery.get_node("Shop_tools"),9.6,8.0,4.58,1.65,"工具店"],
		[game.scenery.get_node("TownHall"),12.0,7.0,6.0,1.65,"市民中心"]]
	for quality in ["balanced","native"]:
		session.settings.render_quality=quality;root.get_node("RenderBudget").apply();await process_frame
		for case in cases:
			var building: Node3D=case[0];var center: Vector3=building.global_position
			game.bunny.position=center+Vector3(0,.2,12);game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation()
			var pose: Vector3=center+Vector3(10.5,11.5,19)
			game.camera.position=pose;game.camera.look_at(center+Vector3(0,3.7,0))
			await create_timer(.7).timeout;await RenderingServer.frame_post_draw
			var first: Image=root.get_texture().get_image()
			var ratio: Vector2=Vector2(first.get_size())/root.get_visible_rect().size
			var samples: Array[Vector2i]=[]
			for point in edge_points(center,case[1],case[2],case[3],case[4]):
				var pixel: Vector2=game.camera.unproject_position(point)*ratio
				for offset in [Vector2i.ZERO,Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
					var p: Vector2i=Vector2i(pixel)+offset
					if p.x>1 and p.y>1 and p.x<first.get_width()-2 and p.y<first.get_height()-2: samples.append(p)
			var max_jump:=0.0;var worst_changed:=0;var last:=first
			for frame in range(12):
				await create_timer(.12).timeout;await RenderingServer.frame_post_draw
				var next: Image=root.get_texture().get_image();var changed:=0
				for point in samples:
					var a:=last.get_pixelv(point);var b:=next.get_pixelv(point)
					var jump: float=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
					max_jump=maxf(max_jump,jump)
					if jump>.08: changed+=1
				worst_changed=maxi(worst_changed,changed);last=next
			var label_: String=case[5]+" "+quality
			print("ROOF_EDGE_STATIC ",label_," samples=",samples.size()," jump=",max_jump," changed_over_8percent=",worst_changed)
			check(samples.size()>=400 and worst_changed<=2,"Exterior edge has no periodic flashing "+label_)
			if building.get_script()==load("res://scripts/city/seabreeze_home.gd"):
				check(building.sections[0].alpha>.999,"Exterior roof remains fully visible "+label_)
				var toggles:=0;var previous: bool=building.roof_hidden
				for i in range(24):
					game.camera.position=pose+Vector3(sin(i*1.7)*.018,0,cos(i*1.3)*.018);game.camera.look_at(center+Vector3(0,3.7,0))
					await process_frame
					if building.roof_hidden!=previous: toggles+=1
					previous=building.roof_hidden
				check(toggles==0 and building.sections[0].alpha>.999,"Micro orbit does not toggle exterior cutaway "+label_)
			first.save_png(OUT+"屋檐终审-"+case[5]+"-"+quality+".png")
	print("ROOF_EDGE_AUDIT_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
