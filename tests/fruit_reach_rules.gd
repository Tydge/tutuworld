extends SceneTree
const Animals=preload("res://scripts/characters/animal_factory.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for species in ["bunny","cat_teacher","panda"]:
		var actor:=Animals.create(species);root.add_child(actor);actor.set_physics_process(false)
		actor.play_action("harvest_tree",4.0)
		var minimum:=999.0
		for frame in range(180):
			actor.animate_pose(1.0/60)
			for side in [-1,1]:
				var limb: Node3D=actor.left_arm if side<0 else actor.right_arm
				var grip: Vector3=actor.rig_profile.grip_offset
				if side<0: grip.x=-grip.x
				var radii: Vector3=actor.rig_profile.head_radii+Vector3.ONE*actor.rig_profile.sleeve_radius
				for step in range(2,11):
					var point: Vector3=actor.head.to_local(limb.to_global(grip*step/10.0))
					var clearance:=Vector3(point.x/radii.x,point.y/radii.y,point.z/radii.z).length_squared()
					minimum=minf(minimum,clearance);checks+=1
		if minimum<1.0: failures.append(species+" minimum="+str(minimum))
		print("REACH_CLEARANCE ",species," minimum=",minimum)
		var tools:=preload("res://scripts/city/work_props.gd").new();tools.bunny=actor;root.add_child(tools)
		actor.play_action("snack",4.0);tools.show_tool("snack")
		var snack_minimum:=999.0
		var minimum_frame:=0
		for frame in range(180):
			actor.animate_pose(1.0/60);tools._physics_process(1.0/60)
			var radii: Vector3=actor.rig_profile.head_radii+Vector3.ONE*actor.rig_profile.sleeve_radius
			for step in range(2,11):
				var point: Vector3=actor.head.to_local(actor.right_arm.to_global(actor.rig_profile.grip_offset*step/10.0))
				var clearance:=Vector3(point.x/radii.x,point.y/radii.y,point.z/radii.z).length_squared()
				if clearance<snack_minimum: snack_minimum=clearance;minimum_frame=frame
				checks+=1
		if snack_minimum<1: failures.append("Snack "+species+" minimum="+str(snack_minimum))
		print("SNACK_CLEARANCE ",species," minimum=",snack_minimum," frame=",minimum_frame)
		tools.hide_tool();tools.free()
		actor.action="";actor.animate_pose(.016)
		checks+=1
		if not actor.left_arm.position.is_equal_approx(actor.arm_rest_left): failures.append("Shoulder reset "+species)
		actor.free()
	print("FRUIT_REACH_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
