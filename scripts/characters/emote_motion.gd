extends RefCounted

const Score := preload("res://scripts/characters/dance_score.gd")
const STAGE_KEYS := {KEY_F10: Score.BALLET, KEY_F11: Score.STREET, KEY_F12: Score.CLOUD}
const SHORT_TIME := 2.0
const KEY_ORDER := ["laugh", "angry", "sad", "think", "lie", "sit", "point", "dance_1", "dance_2", "dance_3"]
const DANCES := {"dance_1": 12.0, "dance_2": 12.8, "dance_3": 14.4}
const EXPRESSIONS := ["laugh", "angry", "sad", "think"]

class Pose:
	var left_arm := Vector3.ZERO
	var right_arm := Vector3.ZERO
	var left_leg := Vector3.ZERO
	var right_leg := Vector3.ZERO
	var shift := Vector2.ZERO
	var lift := 0.0
	var lean := 0.0
	var roll := 0.0
	var head_roll := 0.0
	var head_pitch := 0.0
	var ear_flick := 0.0
	var paw_to_cheek := 0.0
	var clap := 0.0
	var clap_height := 0.0
	var turn := 0.0
	var stretch := 0.0
	var grounded_pose := false

static func from_key(event: InputEventKey) -> String:
	if event.alt_pressed or event.ctrl_pressed or event.meta_pressed or event.shift_pressed:
		return ""
	var key := event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if STAGE_KEYS.has(key):
		return STAGE_KEYS[key]
	if key >= KEY_0 and key <= KEY_9:
		return KEY_ORDER[posmod(key - KEY_1, 10)]
	# Godot assigns the keypad digits a separate, contiguous range.
	if key >= KEY_KP_0 and key <= KEY_KP_9:
		return KEY_ORDER[posmod(key - KEY_KP_1, 10)]
	return ""

static func weight(id: String, age: float) -> float:
	var in_ := smoothstep(0.0, 0.30, age)
	if is_short(id):
		return in_ * (1.0 - smoothstep(1.67, SHORT_TIME, age))
	return in_

static func is_known(id: String) -> bool:
	return id in KEY_ORDER or Score.DURATIONS.has(id)

static func is_dance(id: String) -> bool:
	return DANCES.has(id) or Score.DURATIONS.has(id)

static func is_short(id: String) -> bool:
	return id in EXPRESSIONS or id == "point"

static func sample(id: String, age: float) -> Pose:
	var p := Pose.new()
	if DANCES.has(id):
		var bar := fposmod(age, DANCES[id]) * TAU / float(DANCES[id])
		match id:
			"dance_1": sway_and_hop(p, bar)
			"dance_2": step_and_clap(p, bar)
			"dance_3": shuffle_and_punch(p, bar)
		return p

	var t := minf(age, SHORT_TIME)
	match id:
		"laugh":
			var chuckle := sin(t * TAU * 3.0)
			p.right_arm = Vector3(-.88 + chuckle * .14, -.70, .30)
			p.left_arm = Vector3(-1.15 - chuckle * .33, .12, -.86)
			p.left_leg.x = .19 + .27 * maxf(0.0, chuckle)
			p.right_leg.x = -.19 - .22 * maxf(0.0, chuckle)
			p.lift = .15 * pow(maxf(0.0, chuckle), 1.7)
			p.lean = -.22 + chuckle * .13
			p.roll = .09 * sin(t * 5.8)
			p.head_pitch = -.21 + .13 * chuckle
			p.ear_flick = .19 * chuckle
			p.stretch = .055 * chuckle
		"angry":
			var stamp := pow(maxf(0.0, sin(t * TAU * 2.5)), 4.)
			p.left_arm = Vector3(-.82 - .54 * stamp, -.16, -.42)
			p.right_arm = Vector3(-.78 - .82 * (1.0 - stamp), -.58, .45)
			p.left_leg.x = -.57 * stamp
			p.right_leg.x = -.25 * (1.0 - stamp)
			p.lift = .10 * stamp
			p.lean = .20 + .08 * stamp
			p.roll = .065 * sin(t * 19.)
			p.head_pitch = .20
			p.ear_flick = -.26 + .08 * sin(t * 16.)
			p.stretch = -.045 + .105 * stamp
		"sad":
			var heave := sin(t * TAU * 1.6)
			p.left_arm = Vector3(-.30 + .11 * heave, .12, -.24)
			p.right_arm = Vector3(-.34 - .10 * heave, -.12, .20)
			p.left_leg = Vector3(-.32, 0., .11)
			p.right_leg = Vector3(.24, 0., -.10)
			p.shift.x = .035 * sin(t * 3.8)
			p.lift = -.11 + .027 * heave
			p.lean = .34 + .06 * heave
			p.head_pitch = .33 + .045 * heave
			p.head_roll = -.17
			p.ear_flick = -.32
			p.stretch = -.07 + .029 * heave
		"think":
			var ponder := sin(t * TAU * 1.2)
			p.left_arm = Vector3(-1.12, .40, .27)
			p.right_arm = Vector3(-1.97, -.40, .34)
			p.right_leg = Vector3(-.28, -.24, .09)
			p.shift.x = .05
			p.lean = -.075
			p.roll = -.10
			p.head_roll = .28 + .06 * ponder
			p.head_pitch = .10 + .05 * ponder
			p.paw_to_cheek = .95
			p.ear_flick = .10 * ponder
		"lie":
			var breath := sin(age * 2.5)
			p.grounded_pose = true
			p.lean = -PI * .5 + .026 * breath
			p.head_pitch = -.10
			p.left_arm = Vector3(-.13, .08, -.39)
			p.right_arm = Vector3(-.15, -.08, .39)
			p.left_leg = Vector3(-.12, .19, -.15)
			p.right_leg = Vector3(-.04, -.12, .13)
			p.ear_flick = .07 * breath
		"sit":
			var breath := sin(age * 2.9)
			p.grounded_pose = true
			p.lean = .09 + .02 * breath
			p.left_leg = Vector3(-1.42, .14, -.22)
			p.right_leg = Vector3(-1.42, -.14, .22)
			p.left_arm = Vector3(-.39, .15, -.28)
			p.right_arm = Vector3(-.43, -.14, .26)
			p.head_pitch = -.09
			p.head_roll = -.09 + .025 * breath
			p.ear_flick = .045 * breath
		"point":
			var cue := smoothstep(.20, .42, t) + .18 * exp(-pow((t - .47) * 13., 2))
			p.right_arm = Vector3(lerpf(-.30, -1.64, cue), -.16, .12)
			p.left_arm = Vector3(-.39, .13, -.36)
			p.right_leg = Vector3(-.32, -.11, .10)
			p.left_leg = Vector3(.27, .05, -.10)
			p.lean = .18 * cue
			p.roll = -.12 * cue
			p.shift.y = .095 * cue
			p.head_pitch = -.14 * cue
			p.head_roll = .10 * cue
			p.ear_flick = .2 * cue
	return p

# Use overlapping eases for the different phrases. Every offset returns to
# the opening pose and the pirouette ends one full revolution from its start.
static func sway_and_hop(p: Pose, bar: float) -> void:
	var fraction := bar / TAU
	var swing := sin(bar * 8.)
	var step := cos(bar * 8.)
	var twirl := smoothstep(.41,.57,fraction)
	var spinning := smoothstep(.38,.45,fraction) * (1.-smoothstep(.55,.62,fraction))
	var bow := smoothstep(.79,.86,fraction) * (1.-smoothstep(.88,.98,fraction))
	var overhead := (.5 - .5 * cos(bar)) * (1.-bow)
	var hop := pow(maxf(0., sin(bar * 16.)), 2.) * (1.-bow)
	p.turn = twirl * TAU + (.33 * swing) * (1.-.78*spinning)
	p.shift = Vector2(.24 * step * (1.-.52*bow), .077 * sin(bar * 4.) * (1.-bow))
	p.lift = (.085 + .15 * overhead) * hop - .085 * bow
	p.left_arm = Vector3(-.35 - overhead * 1.27 - swing * .48, .22 * swing, -.66 - .89 * overhead)
	p.right_arm = Vector3(-.35 - overhead * 1.27 + swing * .48, .22 * swing, .66 + .89 * overhead)
	p.left_arm = p.left_arm.lerp(Vector3(-.55,.12,-1.13),bow)
	p.right_arm = p.right_arm.lerp(Vector3(-1.12,-.48,-.23),bow)
	p.left_leg = Vector3(-swing * .57, .12, -.24 - .19 * step) * (1.-.67*bow)
	p.right_leg = Vector3(swing * .57, -.12, .24 - .19 * step) * (1.-.67*bow)
	p.roll = -.22 * step * (1.-.77*bow)
	p.lean = -.10 * overhead + .52 * bow
	p.head_pitch = .30 * bow
	p.head_roll = .17 * step * (1.-bow)
	p.ear_flick = .18 * hop + .19*spinning
	p.stretch = .065 * hop - .071 * bow

static func step_and_clap(p: Pose, bar: float) -> void:
	var step := sin(bar * 8.)
	var phrase := sin(bar)
	var double_step := sin(bar * 16.) * pow(maxf(0., -phrase), 2.)
	var bounce := .5 - .5 * cos(bar * 16.)
	var clap := pow(maxf(0., cos(bar * 8.)), 7.)
	var high := .5 + .5 * sin(bar * 3.)
	var reach := lerpf(-.91, -1.86, high)
	p.turn = .51 * step * (.5 + .5 * cos(bar))
	p.shift = Vector2(.32 * step, .14 * sin(bar * 4.))
	p.lift = (.08 + .075 * high) * bounce - .047 * clap
	p.left_arm = Vector3(lerpf(-.55 + .42 * step, reach, clap), lerpf(.12, .67, clap), lerpf(-.95, .36, clap))
	p.right_arm = Vector3(lerpf(-.55 - .42 * step, reach, clap), lerpf(-.12, -.67, clap), lerpf(.95, -.36, clap))
	p.clap = clap
	p.clap_height = high
	p.left_leg = Vector3(-.93 * maxf(0., step) - .36*maxf(0., double_step),.19,-.30*maxf(0., -step))
	p.right_leg = Vector3(-.93 * maxf(0., -step) - .36*maxf(0., -double_step),-.19,.30*maxf(0., step))
	p.lean = .22 * clap - .11 * bounce
	p.roll = .19 * step
	p.head_pitch = .14 * clap
	p.head_roll = -.12 * step
	p.ear_flick = .24 * bounce
	p.stretch = .055 * bounce - .075 * clap

static func shuffle_and_punch(p: Pose, bar: float) -> void:
	var fraction := bar / TAU
	var shuffle := sin(bar * 12.)
	var transfer := cos(bar * 6.)
	var cross := sin(bar * 4.)
	var big_jump := smoothstep(.21,.27,fraction) * (1.0-smoothstep(.32,.40,fraction))
	big_jump += smoothstep(.67,.73,fraction) * (1.0-smoothstep(.78,.86,fraction))
	var accent := pow(maxf(0., sin(bar * 6.)), 4.)
	var jump := maxf(big_jump * .88, accent * .55)
	var windup := pow(maxf(0., -sin(bar * 6.)), 4.)
	p.turn = .66 * cross * (1.-big_jump)
	p.shift = Vector2(.27 * transfer, .14 * cross) * (1.-.50*big_jump)
	p.lift = .036 + .33*jump - .073*windup
	p.left_arm = Vector3(-.89 - 1.03 * cross, .39 + .42 * cross, -.53 + .40 * shuffle).lerp(Vector3(-1.05,.22,-2.12),big_jump)
	p.right_arm = Vector3(-.89 + 1.03 * cross, -.39 + .42 * cross, .53 + .40 * shuffle).lerp(Vector3(-1.05,-.22,2.12),big_jump)
	p.left_leg = Vector3(-.34 - .53 * shuffle, .35 * transfer, .26 * cross - .23).lerp(Vector3(-.45,.27,-.72),big_jump)
	p.right_leg = Vector3(-.34 + .53 * shuffle, .35 * transfer, .26 * cross + .23).lerp(Vector3(-.52,-.27,.72),big_jump)
	p.lean = .20 * windup - .21 * jump
	p.roll = .25 * transfer * (1.-.68*big_jump)
	p.head_pitch = -.24 * jump
	p.head_roll = -.20 * transfer * (1.-.65*big_jump)
	p.ear_flick = .21 * shuffle + .19 * jump
	p.stretch = .095*jump - .095*windup
