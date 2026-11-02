extends Resource
## Shared animation and clothing measurements, in each species' local space.
@export var species_id := "bunny"
@export var head_center := Vector3(0,1.78,0)
@export var head_radii := Vector3(.84,.76,.79)
@export var head_collision_radius := .80
@export var step_probe_distance:=.39
@export var body_center := Vector3(0,.78,0)
@export var body_radii := Vector3(.30,.435,.265)
## Head-local position and outward normal of the complete ear-root accessory.
@export var bow_offset := Vector3(-.40,.615,.39)
@export var bow_normal := Vector3(-.42,.78,.46)
@export var bow_tilt := -.24
@export var neck_center := Vector3(0,1.025,0)
@export var neck_radii := Vector2(.275,.27)
@export var hat_offset := Vector3(.025,.735,-.025)
@export var headwear_scale := Vector3.ONE
@export var name_height := 3.35
@export var dialogue_height := 3.4
@export var mood_height := 3.55
@export var stride_scale := 1.0
@export var bob_scale := 1.0
@export var tilt_scale := 1.0
@export var ear_rest := Vector2(.14,-.08)
@export var ear_motion := 1.0
@export var leg_end:=Vector3(0,-.38,0)
@export var leg_radius:=.10
@export var sleeve_radius := .108
@export var sleeve_length := .21
@export var walk_speed_scale := 1.0
@export var tail_sway := 0.0
@export var grip_offset := Vector3(.075,-.54,.005)

@export var portrait_center_offset:=.24
@export var portrait_size:=2.20
