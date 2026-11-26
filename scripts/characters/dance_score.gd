extends RefCounted
## Beats are local to a score. Paw offsets are in leg lengths in stage space.
## Each upper-body key gives the two arm shapes (upper elevation, elbow curl,
## sweep towards the audience), torso (pitch, roll, yaw) and gaze in degrees.
const BALLET := "dance_ballet"
const STREET := "dance_street"
const CLOUD := "dance_cloud"
const DURATIONS := {BALLET: 12.0, STREET: 40.0 / 3.0, CLOUD: 14.4}
const BEATS := {BALLET: 24.0, STREET: 32.0, CLOUD: 24.0}
const O := Vector3.ZERO
const LOW := Vector3(-65, 28, 24)
const OPEN := Vector3(-5, 16, 5)
const HIGH := Vector3(8, 57, 5)
const ROUND_ARM := Vector3(-26, 58, 55)

const BALLET_ARMS := [
	[0, LOW, LOW, O, O],
	# Plié, open second position, unfold the free leg into an arabesque.
	[1.2, ROUND_ARM, ROUND_ARM, Vector3(9,0,0), Vector3(8,0,0)],
	[3, OPEN, OPEN, Vector3(-5,3,-10), Vector3(-9,-3,-16)],
	[4.8, Vector3(22,33,26), Vector3(-8,12,-20), Vector3(15,10,-30), Vector3(-12,-7,-19)],
	[6, Vector3(24,38,31), OPEN, Vector3(17,10,-31), Vector3(-14,-8,-16)],
	# Gather the arms and spot the turn; open sharply as it resolves.
	[7.5, OPEN, ROUND_ARM, Vector3(2,-5,15), Vector3(-4,0,22)],
	[8.6, ROUND_ARM, ROUND_ARM, Vector3(-4,2,0), Vector3(-6,0,0)],
	[10.5, HIGH, HIGH, Vector3(-6,2,0), Vector3(-10,0,0)],
	[11.4, OPEN, HIGH, Vector3(-4,5,-14), Vector3(-8,-8,-18)],
	# Two travelling jumps, the second with an open diagonal.
	[12.8, LOW, LOW, Vector3(13,0,-12), Vector3(6,0,-7)],
	[13.6, OPEN, OPEN, Vector3(-6,-9,8), Vector3(-9,5,12)],
	[14.4, ROUND_ARM, LOW, Vector3(12,-3,12), Vector3(8,0,12)],
	[15.6, HIGH, OPEN, Vector3(-9,11,-21), Vector3(-14,-6,-14)],
	[16.5, OPEN, ROUND_ARM, Vector3(11,7,-10), Vector3(7,-4,-9)],
	# A sustained side extension, révérence and recover to the opening.
	[18.8, OPEN, HIGH, Vector3(-6,-13,18), Vector3(-12,10,23)],
	[20, OPEN, HIGH, Vector3(-6,-13,18), Vector3(-12,10,23)],
	[21.5, ROUND_ARM, OPEN, Vector3(17,-7,10), Vector3(12,7,12)],
	[22.4, ROUND_ARM, Vector3(-27,18,6), Vector3(23,-8,8), Vector3(15,8,10)],
	[24, LOW, LOW, O, O],
]

# Foot keys: beat, left/right stage offset, signed weight (+right),
# standing extension. Equal neighbouring targets are planted for the interval.
const BALLET_FEET := [
	[0,O,O,0,.97], [1.2,O,O,0,.62], [3,O,O,-.72,.96],
	[4.8,O,Vector3(.27,.70,-.78),-.95,.98], [6,O,Vector3(.27,.70,-.78),-.95,.98],
	[7.5,O,O,-.55,.63], [8.5,O,Vector3(-.20,.66,.13),-1,.97],
	[10.7,O,Vector3(-.20,.66,.13),-1,.97], [11.5,O,Vector3(.31,.16,.09),-.8,.92],
	[12.8,O,O,-.25,.61], [13.6,Vector3(.17,.14,-.30),Vector3(.50,.04,.13),.1,.93],
	[14.35,Vector3(.32,0,0),Vector3(.42,0,0),.68,.60],
	[15.6,Vector3(-.22,.22,.40),Vector3(.38,.37,-.46),.15,.92],
	[16.5,Vector3(-.14,0,.15),Vector3(.22,0,0),.6,.62],
	[18.8,Vector3(-.83,.88,.10),Vector3(.22,0,0),.94,.96],
	[20,Vector3(-.83,.88,.10),Vector3(.22,0,0),.94,.96],
	[21.5,Vector3(.14,0,-.32),Vector3(.22,0,0),.7,.72],
	[22.4,Vector3(.14,0,-.32),Vector3(.22,0,0),.7,.62], [23.2,O,Vector3(.22,0,0),-.65,.85], [24,O,O,0,.97],
]

const GUARD := Vector3(-35,98,14)
const JAB := Vector3(4,4,34)
const BOX := Vector3(-4,83,2)
const STREET_ARMS := [
	[0,LOW,LOW,O,O],
	# Down-rock and backbeat: a quick hit followed by a held silhouette.
	[1,GUARD,LOW,Vector3(18,-12,-18),Vector3(12,8,10)],
	[1.45,GUARD,JAB,Vector3(-10,15,-28),Vector3(-8,-9,20)],
	[2.05,GUARD,JAB,Vector3(-10,15,-28),Vector3(-8,-9,20)],
	[3,LOW,GUARD,Vector3(15,10,17),Vector3(10,-5,-13)],
	[3.5,JAB,GUARD,Vector3(-6,-17,29),Vector3(-8,11,-18)],
	[4.1,JAB,GUARD,Vector3(-6,-17,29),Vector3(-8,11,-18)],
	[5.5,BOX,BOX,Vector3(16,0,0),Vector3(11,0,0)],
	[6,OPEN,OPEN,Vector3(-15,0,0),Vector3(-10,0,0)],
	[6.6,OPEN,OPEN,Vector3(-15,0,0),Vector3(-10,0,0)],
	# Running-man switch, knee drive and two staccato elbows.
	[8,GUARD,Vector3(-65,15,-22),Vector3(18,-13,-32),Vector3(5,4,20)],
	[9,Vector3(-57,18,-22),GUARD,Vector3(14,12,26),Vector3(4,-6,-18)],
	[10,GUARD,LOW,Vector3(18,-14,-34),Vector3(9,8,18)],
	[11.4,BOX,Vector3(-16,68,16),Vector3(-11,16,16),Vector3(-6,-12,-11)],
	[12.2,LOW,GUARD,Vector3(15,7,24),Vector3(7,-4,-12)],
	[13,Vector3(22,68,3),JAB,Vector3(-8,-11,-26),Vector3(-10,6,18)],
	[13.6,Vector3(22,68,3),JAB,Vector3(-8,-11,-26),Vector3(-10,6,18)],
	# Low cross-step, heel kick and wide diagonal freeze.
	[15,ROUND_ARM,ROUND_ARM,Vector3(19,0,0),Vector3(15,0,0)],
	[16.5,LOW,BOX,Vector3(17,16,33),Vector3(9,-13,-24)],
	[17.2,JAB,HIGH,Vector3(-12,-18,-25),Vector3(-10,11,18)],
	[18.5,JAB,HIGH,Vector3(-12,-18,-25),Vector3(-10,11,18)],
	[20,BOX,LOW,Vector3(17,-14,-28),Vector3(9,8,19)],
	[21,OPEN,BOX,Vector3(-8,11,24),Vector3(-9,-5,-16)],
	# Body wave rolls from low chest to chin, then a jump and a final lock.
	[22.3,GUARD,GUARD,Vector3(23,0,-9),Vector3(15,-4,-9)],
	[23.1,ROUND_ARM,ROUND_ARM,Vector3(-19,0,0),Vector3(14,0,0)],
	[24,OPEN,OPEN,Vector3(-6,0,9),Vector3(-19,0,12)],
	[25.8,LOW,LOW,Vector3(22,3,0),Vector3(12,0,0)],
	[26.65,BOX,BOX,Vector3(-11,0,0),Vector3(-10,0,0)],
	[27.45,GUARD,GUARD,Vector3(22,0,0),Vector3(10,0,0)],
	[28.5,HIGH,Vector3(-29,4,4),Vector3(-7,-16,23),Vector3(-9,12,-12)],
	[30,HIGH,Vector3(-29,4,4),Vector3(-7,-16,23),Vector3(-9,12,-12)],
	[31,GUARD,LOW,Vector3(11,-4,6),Vector3(4,0,0)], [32,LOW,LOW,O,O],
]
const STREET_FEET := [
	[0,O,O,0,.96], [1,O,Vector3(.35,0,.16),-.6,.58], [1.45,O,Vector3(.35,0,.16),-.85,.84],
	[2.05,O,Vector3(.35,0,.16),-.85,.84], [3,Vector3(-.25,0,.22),Vector3(.35,0,.16),.70,.60],
	[3.5,Vector3(-.25,0,.22),Vector3(.35,0,.16),.80,.81], [4.1,Vector3(-.25,0,.22),Vector3(.35,0,.16),.80,.81],
	[5.5,O,Vector3(.35,0,.16),.40,.58], [6,O,O,0,.93], [6.6,O,O,0,.93],
	[8,O,Vector3(-.10,.75,.58),-.82,.75], [9,Vector3(.05,.65,.55),Vector3(0,0,-.24),.76,.79],
	[10,Vector3(0,0,-.20),Vector3(.04,.66,.50),-.77,.70],
	[11.4,Vector3(0,0,-.20),Vector3(.24,.55,.76),-.72,.88], [12.2,O,O,.50,.58],
	[13,Vector3(-.45,.55,.26),O,.90,.89], [13.6,Vector3(-.45,.55,.26),O,.90,.89],
	[15,O,O,0,.59], [16.5,Vector3(.44,0,.47),O,.78,.61],
	[17.2,Vector3(-.58,.78,-.43),O,.85,.86], [18.5,Vector3(-.58,.78,-.43),O,.85,.86],
	[20,Vector3(-.24,0,.13),O,-.65,.57], [21,Vector3(-.24,0,.13),Vector3(.27,.44,.54),-.80,.87],
	[22.3,Vector3(-.24,0,.13),O,.24,.54], [23.1,Vector3(-.24,0,.13),O,0,.70], [24,O,O,0,.94],
	[25.8,O,O,0,.53], [26.65,Vector3(-.31,.31,0),Vector3(.31,.31,0),0,.74],
	[27.45,Vector3(-.21,0,0),Vector3(.21,0,0),0,.56],
	[28.5,Vector3(-.21,0,0),Vector3(.21,0,0),-.80,.83], [30,Vector3(-.21,0,0),Vector3(.21,0,0),-.80,.83],
	[31,O,Vector3(.21,0,0),.5,.70], [32,O,O,0,.96],
]

const CLOUD_ARMS := [
	[0, LOW, LOW, O, O],
	# One paw traces an outward cloud; the other follows under it.
	[1.8, Vector3(-42,58,55), ROUND_ARM, Vector3(6,-5,14), Vector3(4,7,23)],
	[3.5, HIGH, Vector3(-36,26,39), Vector3(-5,-12,28), Vector3(-11,9,26)],
	[5.2, Vector3(9,26,-8), Vector3(7,67,55), Vector3(5,3,-12), Vector3(-5,-4,-24)],
	[7, Vector3(-33,29,26), HIGH, Vector3(-8,15,-31), Vector3(-15,-11,-25)],
	# Brush low, look back across the shoulder, spiral up on one foot.
	[8.5, Vector3(-39,13,5), ROUND_ARM, Vector3(20,16,-23), Vector3(10,-11,-18)],
	[10, OPEN, Vector3(15,62,22), Vector3(7,7,29), Vector3(-12,-7,35)],
	[11.8, Vector3(-20,61,46), HIGH, Vector3(-7,-5,0), Vector3(-13,7,-16)],
	[13.1, HIGH, OPEN, Vector3(-8,-9,0), Vector3(-12,9,16)],
	# Settle the turn into a long diagonal, then reverse the cloud-hands.
	[14.7, Vector3(19,54,4), Vector3(-45,9,5), Vector3(12,-21,23), Vector3(-9,16,18)],
	[16, Vector3(21,57,7), Vector3(-43,13,6), Vector3(10,-20,24), Vector3(-10,16,18)],
	[17.5, ROUND_ARM, Vector3(-23,62,51), Vector3(13,-2,8), Vector3(7,2,-8)],
	[19, Vector3(-14,12,-11), HIGH, Vector3(-9,14,-22), Vector3(-14,-10,-29)],
	[20.5, Vector3(8,53,13), Vector3(22,38,16), Vector3(-10,2,7), Vector3(-17,-4,13)],
	# Gather at the chest and bow, then release to the first breath.
	[22.2, ROUND_ARM, Vector3(-23,65,64), Vector3(17,-8,14), Vector3(13,7,12)],
	[23, ROUND_ARM, Vector3(-27,57,60), Vector3(20,-8,14), Vector3(15,7,12)],
	[24, LOW, LOW, O, O],
]
const CLOUD_FEET := [
	[0,O,O,0,.96], [1.8,O,Vector3(.36,0,.18),-.60,.74], [3.5,O,Vector3(.36,0,.18),.77,.90],
	[5.2,Vector3(-.26,0,.28),Vector3(.36,0,.18),.66,.72],
	[7,Vector3(-.26,0,.28),Vector3(.23,.35,-.29),-.8,.92],
	[8.5,Vector3(-.26,0,.28),Vector3(.31,0,-.12),-.68,.67],
	[10,Vector3(-.13,.24,.38),Vector3(.31,0,-.12),.85,.78],
	[11.4,Vector3(.02,.56,-.35),Vector3(.31,0,-.12),1,.92],
	[13.2,Vector3(.02,.56,-.35),Vector3(.31,0,-.12),1,.92],
	[14.7,Vector3(-.51,0,.38),Vector3(.31,0,-.12),.68,.70],
	[16,Vector3(-.51,0,.38),Vector3(.31,0,-.12),.67,.74],
	[17.5,Vector3(-.51,0,.38),O,-.60,.68], [19,Vector3(-.51,0,.38),Vector3(.23,.35,.16),-.83,.89],
	[20.5,O,Vector3(.20,0,.12),.54,.92], [22.2,Vector3(.26,0,-.35),Vector3(.20,0,.12),.72,.70],
	[23,Vector3(.26,0,-.35),Vector3(.20,0,.12),.72,.67], [23.5,O,Vector3(.20,0,.12),-.48,.80], [24,O,O,0,.96],
]
const UPPER := {BALLET:BALLET_ARMS, STREET:STREET_ARMS, CLOUD:CLOUD_ARMS}
const FEET := {BALLET:BALLET_FEET, STREET:STREET_FEET, CLOUD:CLOUD_FEET}

class Frame:
	var left_arm: Vector3
	var right_arm: Vector3
	var torso: Vector3
	var gaze: Vector3
	var left_step: Vector3
	var right_step: Vector3
	var weight: float
	var extension: float
	var spin: float
	var flight: float
	var ear: float

static func interval(track: Array, beat: float) -> int:
	for i in range(1,track.size()):
		if beat <= float(track[i][0]):
			return i-1
	return track.size()-2

static func progress(a: Array,b: Array,beat: float) -> float:
	return clampf((beat-float(a[0])) / (float(b[0])-float(a[0])),0.,1.)

static func step_between(a: Vector3,b: Vector3,t: float) -> Vector3:
	var foot := a.lerp(b,smoothstep(0.,1.,t))
	# A planted paw only travels by lifting. Include clearance on switches
	# between two elevated poses as well, especially the running-man sequence.
	var travel := Vector2(b.x-a.x,b.z-a.z).length()
	foot.y += sin(PI*t) * minf(.36,travel*.55)
	return foot

static func arc(beat: float, start: float, end: float, height: float) -> float:
	var t := clampf((beat-start)/(end-start),0.,1.)
	return 4.*t*(1.-t)*height

static func sample(id: String, age: float) -> Frame:
	var beats: float = BEATS[id]
	var beat := fposmod(age / float(DURATIONS[id])*beats,beats)
	var upper: Array = UPPER[id]
	var feet: Array = FEET[id]
	var i := interval(upper,beat)
	var a: Array = upper[i]
	var b: Array = upper[i+1]
	var t := progress(a,b,beat)
	var eased := smoothstep(0.,1.,t)
	var p := Frame.new()
	# Give the two cloud-hands different arrival times within the same arc.
	var lead := .24 if id == CLOUD else .08
	p.left_arm = a[1].lerp(b[1],smoothstep(0.,1.,t+lead*sin(PI*t)))
	p.right_arm = a[2].lerp(b[2],smoothstep(0.,1.,t-lead*sin(PI*t)))
	p.torso = a[3].lerp(b[3],eased)
	p.gaze = a[4].lerp(b[4],smoothstep(0.,1.,t-.10*sin(PI*t)))
	i = interval(feet,beat)
	a = feet[i]
	b = feet[i+1]
	t = progress(a,b,beat)
	eased = smoothstep(0.,1.,t)
	p.left_step = step_between(a[1],b[1],t)
	p.right_step = step_between(a[2],b[2],t)
	p.weight = lerpf(a[3],b[3],eased)
	p.extension = lerpf(a[4],b[4],eased)
	match id:
		BALLET:
			p.spin = TAU*smoothstep(8.7,10.6,beat)
			p.gaze.z -= 45.*sin(p.spin)
			p.flight = arc(beat,13.1,14.02,.28) + arc(beat,15.05,16.15,.43)
		STREET:
			p.flight = arc(beat,26.1,27.2,.35)
		CLOUD:
			p.spin = -TAU*smoothstep(11.45,13.15,beat)
	p.ear = deg_to_rad(.50*p.gaze.x - 13.*(1.-p.extension)) - p.flight*.32
	return p
