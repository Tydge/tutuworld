extends Node3D
const G=preload("res://scripts/geometry.gd")
const Meal=preload("res://scripts/city/meal_timeline.gd")
const Food=preload("res://scripts/city/food_visual.gd")
const Models=preload("res://scripts/city/tool_models.gd")
var bunny: CharacterBody3D
var verb:=""
var prop: Node3D
var clock:=0.0
var target_point:=Vector3.ZERO
var effects: Node3D
var spray: MultiMeshInstance3D
var streams: Array[MeshInstance3D]=[]
var splash: MeshInstance3D
var warming:=false
var strike_phase:=0.0
func _ready() -> void:
	effects=Node3D.new();effects.name="WorkEffects";effects.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;add_child(effects)
	var tube:=CylinderMesh.new();tube.top_radius=1;tube.bottom_radius=1;tube.height=1;tube.radial_segments=8;tube.rings=18;tube.cap_top=false;tube.cap_bottom=false
	for i in range(5):
		var m:=ShaderMaterial.new();m.shader=load("res://assets/shaders/watering_stream.gdshader")
		m.set_shader_parameter("radius",.029 if i==0 else .016)
		var mesh:=G.mesh(effects,tube,Vector3.ZERO,m,"WaterStream");mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh.extra_cull_margin=3.0;streams.append(mesh)
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true
	var quad:=QuadMesh.new();quad.size=Vector2.ONE;mm.mesh=quad;mm.instance_count=96
	for i in range(96): mm.set_instance_transform(i,Transform3D.IDENTITY);mm.set_instance_custom_data(i,Color(float(i)/96,fmod(i*.6180339,1.0),0,1))
	spray=MultiMeshInstance3D.new();spray.name="WorkParticles";spray.multimesh=mm
	var mist:=ShaderMaterial.new();mist.shader=load("res://assets/shaders/work_particles.gdshader");spray.material_override=mist;spray.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;spray.extra_cull_margin=3.0;effects.add_child(spray)
	var plane:=PlaneMesh.new();plane.size=Vector2(.85,.85)
	var ripple:=ShaderMaterial.new();ripple.shader=load("res://assets/shaders/water_splash.gdshader")
	splash=G.mesh(effects,plane,Vector3.ZERO,ripple,"WaterLanding");splash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effects.hide()
func show_tool(kind: String,water_id: String="") -> void:
	verb=kind;clock=0
	if is_instance_valid(prop): remove_child(prop);prop.queue_free()
	if kind in ["water","weed","gather_stone","gather_copper","gather_wood"]: prop=Models.make(kind,water_id)
	elif kind=="refill": prop=Models.make("water",water_id)
	elif kind=="eat":prop=eating_prop()
	else:
		prop=Node3D.new()
		var wood:=G.mat("bb905c")
		if kind=="cook":
			var end:=Vector3(0,.23,.63)
			G.capsule(prop,Vector3.ZERO,end,.018,wood,"SpoonHandle");G.ball(prop,end,Vector3(.060,.018,.085),wood,"SpoonBowl")
		elif kind=="plant": G.box(prop,Vector3.ZERO,Vector3(.18,.23,.045),G.mat("e3b773"))
		elif kind=="snack":
			G.ball(prop,Vector3.ZERO,Vector3(.115,.11,.115),G.mat("ed9f39"),"Orange")
			G.ball(prop,Vector3(-.024,.024,.078),Vector3(.064,.064,.036),G.mat("f7c06a"),"OrangeFlesh")
			var leaf:=G.ball(prop,Vector3(.025,.105,.005),Vector3(.047,.009,.024),G.mat("649357"),"OrangeLeaf")
			leaf.rotation.z=-.35
	add_child(prop)
func hide_tool() -> void:
	verb=""
	if is_instance_valid(prop): prop.hide()
	if is_instance_valid(effects): effects.hide()
	if is_instance_valid(bunny): bunny.left_arm.scale=Vector3.ONE;bunny.right_arm.scale=Vector3.ONE
func _physics_process(delta: float) -> void:
	if verb=="" or not is_instance_valid(bunny) or not is_instance_valid(prop): return
	clock+=delta
	if warming:
		prop.global_transform=Transform3D(Basis.IDENTITY,bunny.global_position+Vector3(.35,1.0,.50));return
	var hand: Vector3=bunny.right_arm.to_global(bunny.rig_profile.grip_offset)
	if verb in ["gather_stone","gather_copper","gather_wood"]:
		var center: Vector3=(bunny.left_arm.position+bunny.right_arm.position)*.5+Vector3(-.10,-.05,minf(.70,bunny.rig_profile.grip_offset.length()*1.20-maxf(0,bunny.rig_profile.body_radii.x-.30)*.25))
		var local_target: Vector3=bunny.visual.to_local(target_point)
		var reach: Vector3=local_target-center
		var impact: Vector3=prop.get_node("Impact").position
		var scale_: float=clampf(reach.length()/impact.length(),.55,1.55)
		strike_phase=fposmod(maxf(0,bunny.action_time-.18),.92)/.92
		var strike: float=1.0-smoothstep(0.0,.34,strike_phase) if strike_phase<.34 else smoothstep(.34,.56,strike_phase)
		var axis:=Vector3(0,.65,.76).normalized().slerp(reach.normalized(),strike).normalized()
		var z_axis:=Vector3.RIGHT.cross(axis).normalized();var x_axis:=axis.cross(z_axis).normalized()
		var tip_angle: float=-atan2(impact.z,impact.y)
		var basis:=Basis(x_axis,axis,z_axis)*Basis(Vector3.RIGHT,tip_angle)
		prop.global_transform=Transform3D(bunny.visual.global_basis*basis.scaled_local(Vector3.ONE*scale_),bunny.visual.to_global(center))
		bunny.aim_hand(bunny.right_arm,prop.get_node("GripR").global_position)
		bunny.aim_hand(bunny.left_arm,prop.get_node("GripL").global_position,true)
	elif verb=="snack":
		var bite:=smoothstep(.15,.8,.5+.5*sin(bunny.action_time*4.8))*smoothstep(0,.45,bunny.action_time)
		bunny.right_arm.position=bunny.arm_rest_right+Vector3(-.10,-.17,.30)
		var mouth: Vector3=bunny.mouth.global_position+bunny.visual.global_basis*Vector3(.12,-.035,.22)
		var rest: Vector3=bunny.visual.to_global(bunny.right_arm.position+Vector3(-.02,-.16,.35))
		var target: Vector3=rest.lerp(mouth,bite)
		bunny.aim_hand(bunny.right_arm,target-bunny.visual.global_basis*Vector3(0,.015,0))
		prop.global_transform=Transform3D(bunny.visual.global_basis,target)
		var portion:=lerpf(1.0,.78,clampf(bunny.action_time/3.0,0,1))
		prop.scale=Vector3.ONE*portion
	elif verb=="eat":
		pose_meal()
	elif verb=="refill":
		var basis: Basis=bunny.visual.global_basis
		prop.global_transform=Transform3D(basis,hand-basis*prop.get_node("GripR").position)
	elif verb in ["water","weed"]:
		hand+=bunny.visual.global_basis*Vector3(.27,.12,.10) if verb=="water" else bunny.visual.global_basis*Vector3(.18,.06,.08)
		bunny.aim_hand(bunny.right_arm,hand)
		var basis: Basis=bunny.visual.global_basis*Basis(Vector3.RIGHT,-.03 if verb=="water" else .25)
		var grip: Vector3=prop.get_node("GripR").position
		prop.global_transform=Transform3D(basis,hand-basis*grip)
	else: prop.global_transform=Transform3D(bunny.visual.global_basis,hand+bunny.visual.global_basis*Vector3(.10,0,.10))
func eating_prop() -> Node3D:
	var root:=Node3D.new();root.name="EatingProp";var kind:=Meal.utensil(bunny.meal_item);root.set_meta("utensil",kind);root.set_meta("item",bunny.meal_item)
	var tip:=Vector3(-.19,.07,-.02) if kind=="hand" else Vector3.ZERO
	if kind!="hand":
		tip=Vector3(0,0,.30)
		G.capsule(root,Vector3.ZERO,tip-Vector3(0,0,.035),.010,G.mat("9f7e55"),"Handle")
		if kind=="spoon":G.ball(root,tip,Vector3(.052,.013,.069),G.mat("bdc3b5",.35),"SpoonBowl")
		else:
			G.box(root,tip-Vector3(0,0,.035),Vector3(.065,.014,.035),G.mat("bdc3b5",.35),"ForkHead")
			for i in range(3):G.capsule(root,tip+Vector3((i-1)*.025,0,-.025),tip+Vector3((i-1)*.025,0,.045),.005,G.mat("bdc3b5",.35),"ForkTine")
	var contact:=Marker3D.new();contact.name="FoodContact";contact.position=tip;root.add_child(contact)
	var mouthful:=Food.bite_model(bunny.meal_item);root.add_child(mouthful);mouthful.position=tip+Vector3(0,.013,0);mouthful.hide()
	return root
func pose_meal() -> void:
	var phase:=Meal.sample(bunny.meal_elapsed if bunny.meal_elapsed>=0 else bunny.action_time,bunny.meal_duration)
	var kind: String=prop.get_meta("utensil")
	var basis: Basis=bunny.visual.global_basis
	var mouth: Vector3=bunny.mouth.global_position+basis*Vector3(0,-.012,.045)
	var plate: Vector3=bunny.meal_origin+Vector3(0,.17,0) if bunny.meal_origin.is_finite() else target_point
	var rest: Vector3=plate+basis*Vector3(.22,.065,-.045)
	var near_mouth: Vector3=mouth+basis*Vector3(.23,-.15,.03) if kind!="hand" else mouth-basis*Vector3(-.19,.07,-.02)
	var goal: Vector3=rest.lerp(near_mouth,phase.lift)+Vector3.UP*sin(phase.lift*PI)*.09+basis*Vector3(.04*sin(phase.lift*PI),0,0)
	bunny.aim_hand(bunny.right_arm,goal)
	var hand: Vector3=bunny.right_arm.to_global(bunny.rig_profile.grip_offset)
	if kind=="hand":prop.global_transform=Transform3D(basis,hand)
	else:
		var target: Vector3=plate.lerp(mouth,phase.lift)
		var forward: Vector3=(target-hand).normalized();var right:=Vector3.UP.cross(forward).normalized()
		if right.length_squared()<.01:right=basis.x
		prop.global_transform=Transform3D(Basis(right,forward.cross(right),forward),hand)
		prop.scale=Vector3(1,1,clampf(hand.distance_to(target)/.30,.55,1.65))
	prop.get_node("Mouthful").visible=phase.loaded
func _process(_delta: float) -> void:
	if verb=="" or not is_instance_valid(prop): return
	var time: float=clock if warming else bunny.action_time
	var allowed: bool=warming or time>.18
	var fluid: bool=verb in ["water","weed"]
	var mining: bool=verb in ["gather_stone","gather_copper","gather_wood"]
	effects.visible=allowed and (fluid or mining)
	if not effects.visible: return
	var endpoint:=target_point
	if warming: endpoint=bunny.global_position+Vector3(0,.18,1.35)
	effects.global_position=endpoint
	var nozzle:=prop.get_node_or_null("Outlet")
	var start: Vector3=nozzle.get_global_transform_interpolated().origin if is_instance_valid(nozzle) else endpoint
	var day: float=bunny.world.ambient_day if bunny.world!=null else 1.0
	for i in range(streams.size()):
		var stream: MeshInstance3D=streams[i];stream.visible=verb=="water"
		if stream.visible:
			var offset:=Vector3(sin(i*2.4)*.12,0,cos(i*2.4)*.12) if i>0 else Vector3.ZERO
			stream.material_override.set_shader_parameter("start",start+offset*.28)
			stream.material_override.set_shader_parameter("finish",endpoint+offset)
			stream.material_override.set_shader_parameter("clock",time)
	spray.visible=fluid or (mining and strike_phase>=.53 and strike_phase<.86)
	spray.material_override.set_shader_parameter("start",start)
	spray.material_override.set_shader_parameter("finish",endpoint)
	spray.material_override.set_shader_parameter("kind",0 if verb=="water" else (1 if verb=="weed" else 2))
	spray.material_override.set_shader_parameter("clock",time)
	spray.material_override.set_shader_parameter("daylight",day)
	splash.visible=verb=="water";splash.global_position=endpoint+Vector3(0,.008,0)
	splash.material_override.set_shader_parameter("clock",time);splash.material_override.set_shader_parameter("daylight",day)
func warm_variants() -> void:
	warming=true
	for kind in ["water","weed","gather_stone","gather_copper","gather_wood"]:
		show_tool(kind)
		for frame in range(2): await get_tree().process_frame;await RenderingServer.frame_post_draw
	hide_tool();warming=false
