extends RefCounted
## Reuse real floor and avatar clearance when leaving a movable seat or bed.
static func find(host: Node3D,desired: Vector3,actor: CharacterBody3D,search: bool=true) -> Dictionary:
	var space:=host.get_world_3d().direct_space_state;var floor_query:=PhysicsRayQueryParameters3D.new();floor_query.collision_mask=8
	var query:=PhysicsShapeQueryParameters3D.new();query.collision_mask=7;query.exclude=[actor.get_rid()]
	var body:=CylinderShape3D.new();body.radius=maxf(.36,actor.rig_profile.body_radii.x+.04);body.height=1.0
	var head:=SphereShape3D.new();head.radius=maxf(actor.rig_profile.head_collision_radius,actor.rig_profile.head_radii.x+.03)
	for ring in range(9 if search else 1):
		var count_: int=1 if ring==0 else 16
		for i in range(count_):
			var p:=desired+Vector3(cos(i*TAU/count_),0,sin(i*TAU/count_))*ring*.55
			if not host.can_walk(p):continue
			floor_query.from=p+Vector3.UP;floor_query.to=p-Vector3.UP*1.5;var hit:=space.intersect_ray(floor_query)
			if hit.is_empty() or hit.normal.y<.7:continue
			p.y=float(hit.position.y)+.025;query.shape=body;query.transform=Transform3D(Basis.IDENTITY,p+Vector3(0,.65,0))
			if not space.intersect_shape(query,1).is_empty():continue
			query.shape=head;query.transform=Transform3D(Basis.IDENTITY,p+actor.rig_profile.head_center)
			if space.intersect_shape(query,1).is_empty():return {"position":p}
	return {}
