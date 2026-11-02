extends SceneTree
const Layout=preload("res://scripts/valley/valley_layout.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1
	if not ok: failures.append(label_);print("FAIL ",label_)
func run() -> void:
	root.size=Vector2i(1440,900)
	var s=load("res://scripts/services/session.gd").new();s.name="Session";root.add_child(s)
	s.state().map_id="valley";s.state().player_position=Layout.arrival("valley")
	var g=load("res://scenes/valley.tscn").instantiate();root.add_child(g);await create_timer(.8).timeout
	g.set_process(false);s.active=false;g.bunny.can_move=false
	var query:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=.20;query.shape=sphere;query.collision_mask=9;query.margin=.001
	for p in [Vector3(3.4,0,-8.78),Vector3(-40,0,22),Vector3(40,0,22),Vector3(-32,4,-33),Vector3(32,4,-33),Vector3(-13,0,47),Vector3(12,4,-36)]:
		g.bunny.position=p;g.bunny.velocity=Vector3.ZERO;g.bunny.reset_physics_interpolation();await physics_frame
		var pivot: Vector3=p+Vector3(0,1.35,0)
		for i in range(24):
			var angle: float=i*TAU/24
			var desired: Vector3=pivot+Vector3(sin(angle)*16,4,cos(angle)*16)
			var safe: Vector3=g.camera_safe_position(pivot,desired)
			query.transform=Transform3D(Basis.IDENTITY,safe)
			var overlaps: Array=g.get_world_3d().direct_space_state.intersect_shape(query)
			if not overlaps.is_empty(): print("CAMERA_HIT pivot=",pivot," safe=",safe," collider=",overlaps[0].collider.get_path())
			check(overlaps.is_empty(),"Camera clearance "+str(p)+" angle="+str(i))
	var space: PhysicsDirectSpaceState3D=g.get_world_3d().direct_space_state
	for i in range(64):
		var angle: float=i*TAU/64
		if sin(angle)>.70 and absf(cos(angle)*54)<36: continue
		var origin:=Vector3(0,5,0);var ray:=PhysicsRayQueryParameters3D.create(origin,origin+Vector3(cos(angle)*110,0,sin(angle)*110*.88),1)
		ray.hit_back_faces=true
		check(not space.intersect_ray(ray).is_empty(),"Continuous visible boundary angle "+str(i))
	print("VALLEY_CAMERA_REGRESSION_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
