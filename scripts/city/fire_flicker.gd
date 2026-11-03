extends Node
## One existing light, no particles/shadow map/moving transform; energy at 20 Hz.
var light: Light3D
var base_energy:=1.0
var elapsed:=0.
var clock:=0.
var phase:=0.
var updates:=0
var reduced:=false
func _ready() -> void:
	light=get_parent() as Light3D
	if light==null:set_process(false);return
	base_energy=light.light_energy;phase=fposmod(light.global_position.dot(Vector3(.37,.19,.61)),TAU)
	var session:=get_node_or_null("/root/Session")
	if session!=null:
		reduced=bool(session.settings.get("reduce_motion",false));session.settings_changed.connect(func(key):
			if key=="reduce_motion":reduced=bool(session.settings.reduce_motion);light.light_energy=base_energy)
func _process(delta: float) -> void:
	clock+=delta;elapsed+=delta
	if elapsed<.05:return
	elapsed=fmod(elapsed,.05)
	if reduced or not light.is_visible_in_tree():return
	var camera:=get_viewport().get_camera_3d()
	if camera!=null and camera.global_position.distance_squared_to(light.global_position)>1600.:return
	light.light_energy=base_energy*(1.+.045*sin(clock*4.1+phase)+.025*sin(clock*7.7+phase*1.7))
	updates+=1
static func attach(light_: Light3D) -> void:
	if light_.has_node("FireFlicker"):return
	var motion: Node=load("res://scripts/city/fire_flicker.gd").new();motion.name="FireFlicker";light_.add_child(motion)
