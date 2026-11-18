extends Node3D
## Small fixed particle budgets; chimney haze is local, snowfall follows the player.
var city: Node3D
var snow: GPUParticles3D
static func sprite(color: Color) -> StandardMaterial3D:
	var ramp:=Gradient.new();ramp.colors=PackedColorArray([Color.WHITE,Color(1,1,1,0)]);ramp.offsets=PackedFloat32Array([0.,1.])
	var texture_:=GradientTexture2D.new();texture_.gradient=ramp;texture_.width=32;texture_.height=32;texture_.fill=GradientTexture2D.FILL_RADIAL;texture_.fill_from=Vector2(.5,.5);texture_.fill_to=Vector2(1.,.5)
	var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;m.billboard_keep_scale=true;m.albedo_color=color;m.albedo_texture=texture_;m.vertex_color_use_as_albedo=true;m.no_depth_test=false
	return m
func _ready() -> void:
	var smoke_mat:=sprite(Color(.40,.48,.55,.14))
	for building in city.scenery.get_children():
		if building.get_meta("winter_asset_id","") not in ["chalet","chapel"]:continue
		var plume:=GPUParticles3D.new();plume.name="ChimneyHaze";plume.amount=14;plume.lifetime=6.;plume.preprocess=3.;plume.fixed_fps=15;plume.visibility_aabb=AABB(Vector3(-4,-1,-4),Vector3(10,15,10));plume.position=building.position+Vector3(3,9.1,-2.2);plume.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var p:=ParticleProcessMaterial.new();p.direction=Vector3(.2,1,.04);p.spread=13.;p.initial_velocity_min=.45;p.initial_velocity_max=.85;p.gravity=Vector3(.1,.09,.015);p.scale_min=.55;p.scale_max=1.2
		var fade:=Gradient.new();fade.colors=PackedColorArray([Color(1,1,1,0),Color.WHITE,Color(1,1,1,0)]);fade.offsets=PackedFloat32Array([0.,.18,1.]);var ramp:=GradientTexture1D.new();ramp.gradient=fade;p.color_ramp=ramp;plume.process_material=p
		var quad:=QuadMesh.new();quad.size=Vector2(1.4,1.4);quad.material=smoke_mat;plume.draw_pass_1=quad;add_child(plume)
	for fire in city.scenery.get_children():
		if fire.get_meta("winter_asset_id","")!="campfire":continue
		var plume:=GPUParticles3D.new();plume.name="CampfireSmoke";plume.amount=10;plume.lifetime=3.6;plume.fixed_fps=20;plume.position=fire.position+Vector3(0,1.35,0);plume.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var p:=ParticleProcessMaterial.new();p.direction=Vector3(.08,1,.03);p.spread=15.;p.initial_velocity_min=.38;p.initial_velocity_max=.67;p.gravity=Vector3(.04,.08,.01);p.scale_min=.15;p.scale_max=.48;plume.process_material=p
		var quad:=QuadMesh.new();quad.size=Vector2.ONE;quad.material=smoke_mat;plume.draw_pass_1=quad;add_child(plume)
		var sparks:=GPUParticles3D.new();sparks.name="CampfireEmbers";sparks.amount=9;sparks.lifetime=1.8;sparks.fixed_fps=30;sparks.position=fire.position+Vector3(0,.65,0);sparks.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var motion:=ParticleProcessMaterial.new();motion.direction=Vector3.UP;motion.spread=23.;motion.initial_velocity_min=.65;motion.initial_velocity_max=1.2;motion.gravity=Vector3(.07,.06,.01);motion.scale_min=.008;motion.scale_max=.024;sparks.process_material=motion
		var ember:=QuadMesh.new();ember.size=Vector2.ONE;ember.material=sprite(Color(1.,.38,.055,.8));sparks.draw_pass_1=ember;add_child(sparks)
	snow=GPUParticles3D.new();snow.name="LocalSnowFlurries";snow.amount=64;snow.lifetime=9.;snow.preprocess=5.;snow.local_coords=false;snow.fixed_fps=30;snow.visibility_aabb=AABB(Vector3(-26,-8,-26),Vector3(52,30,52));snow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process:=ParticleProcessMaterial.new();process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX;process.emission_box_extents=Vector3(22,1,22);process.direction=Vector3(.18,-1,.06);process.spread=9.;process.initial_velocity_min=.7;process.initial_velocity_max=1.25;process.gravity=Vector3(.025,-.025,.01);process.scale_min=.7;process.scale_max=1.0;snow.process_material=process
	var flake:=QuadMesh.new();flake.size=Vector2.ONE
	var point_material:=ShaderMaterial.new();point_material.shader=load("res://assets/shaders/fine_snow.gdshader");flake.material=point_material;snow.draw_pass_1=flake;add_child(snow)
	for light in city.scenery.find_children("FireLight","OmniLight3D",true,false):preload("res://scripts/city/fire_flicker.gd").attach(light)
func _process(_delta: float) -> void:
	if not is_instance_valid(city.bunny):return
	snow.position=city.bunny.position+Vector3(0,11,0);snow.emitting=city.bunny.position.x< -15. and city.interior_weight()<.15
