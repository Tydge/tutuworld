extends Node
## Shared by solo play and the authoritative town. Online visitors see the resulting actor poses.
const J=preload("res://scripts/jade/layout.gd")
const TRADES={"spice":"cook","almond":"cook","tools":"forge_strike","farm":"sort_seed","furniture":"plane_wood","clothes":"draw_thread","silk":"draw_thread"}
const STOPS={
	1:[Vector2(-6,146),Vector2(-7,130),Vector2(2,139),Vector2(2,154),Vector2(-6,165)],
	2:[Vector2(-5,128),Vector2(2,124),Vector2(5,111),Vector2(-2,116),Vector2(4,134)],
	3:[Vector2(5,91),Vector2(-2,95),Vector2(-7,106),Vector2(2,103),Vector2(2,114)],
	7:[Vector2(-2,47),Vector2(3,38),Vector2(8,31),Vector2(8,47),Vector2(3,54)],
	8:[Vector2(-2,166),Vector2(-7,156),Vector2(3,148),Vector2(4,156),Vector2(3,173)]
}
const DISTRICT_ROUTES={
	20:[Vector2(-143,89),Vector2(-150,85),Vector2(-153,94),Vector2(-145,99),Vector2(-139,94)],
	21:[Vector2(-125,65),Vector2(-119,63),Vector2(-117,72),Vector2(-124,76),Vector2(-130,72)],
	22:[Vector2(-147,24),Vector2(-154,20),Vector2(-163,19),Vector2(-158,27),Vector2(-149,30)],
	23:[Vector2(-164,118),Vector2(-172,111),Vector2(-168,105),Vector2(-156,110),Vector2(-155,118)],
	24:[Vector2(-135,144),Vector2(-129,151),Vector2(-120,149),Vector2(-126,139),Vector2(-136,136)],
	25:[Vector2(153,-20),Vector2(147,-17),Vector2(139,-20),Vector2(145,-27),Vector2(154,-28)],
	26:[Vector2(152,-58),Vector2(143,-61),Vector2(139,-54),Vector2(147,-48),Vector2(157,-52)],
	27:[Vector2(160,55),Vector2(167,61),Vector2(157,65),Vector2(151,58),Vector2(153,49)],
	28:[Vector2(142,25),Vector2(147,21),Vector2(157,23),Vector2(152,31),Vector2(142,33)],
	29:[Vector2(164,-90),Vector2(171,-86),Vector2(177,-92),Vector2(169,-100),Vector2(160,-97)],
	30:[Vector2(39,81),Vector2(43,76),Vector2(52,78),Vector2(55,89),Vector2(41,93)],
	31:[Vector2(-33,137),Vector2(-35,126),Vector2(-26,120),Vector2(-27,134),Vector2(-37,143)],
	32:[Vector2(34,22),Vector2(29,17),Vector2(21,20),Vector2(26,24),Vector2(36,30)],
	33:[Vector2(32,94),Vector2(37,95),Vector2(43,99),Vector2(40,107),Vector2(32,105)],
	34:[Vector2(-4,-150),Vector2(-6,-158),Vector2(-4,-163),Vector2(0,-158),Vector2(3,-152)],
	35:[Vector2(-20,-114),Vector2(-24,-110),Vector2(-24,-100),Vector2(-17,-96),Vector2(-14,-108)],
	36:[Vector2(12,-132),Vector2(8,-137),Vector2(15,-143),Vector2(22,-133),Vector2(20,-125)],
	37:[Vector2(3,-163),Vector2(5,-166),Vector2(6,-161),Vector2(2,-158),Vector2(-1,-165)],
	38:[Vector2(45,-124),Vector2(41,-128),Vector2(37,-130),Vector2(36,-135),Vector2(42,-139)],
	39:[Vector2(60,-150),Vector2(55,-142),Vector2(61,-137),Vector2(68,-141),Vector2(68,-153)]}
# One post per officer. The usher at the steps keeps the central threshold clear.
const MORNING_COURT={12:Vector2(-6,-150),14:Vector2(4,-164),34:Vector2(-3,-160),
	35:Vector2(5,-161),36:Vector2(-5,-165),38:Vector2(3,-167)}
var city: Node3D
var next_turn: Dictionary={}
var elapsed:=0.
var tick:=0.
var market_period:=-1
var paid_respects: Dictionary={}
var imperial_court:=preload("res://scripts/jade/imperial_court.gd").new()
const COURT_DUTIES={14:"bow",34:"bow",35:"read_scroll",36:"bell",38:"bow"}
const CUSTOMERS=[1,2,8]
# The boat hand and carpenter pass the market while the three regulars stop at its counters.
const DELIVERIES=[0,3]
# During the two busiest stretches, neighbours have common destinations along the same frontage.
const MARKET_CALLS=[Vector2(-6.5,-3.3),Vector2(-3.8,-.6),Vector2(-4.4,2.3),Vector2(-6.1,5.3),Vector2(-4.0,8.6)]
static func walk_stops(index: int,origin: Vector3) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	if DISTRICT_ROUTES.has(index):
		for p: Vector2 in DISTRICT_ROUTES[index]:result.append(J.point(p.x,p.y))
	elif STOPS.has(index):
		for p: Vector2 in STOPS[index]:result.append(J.point(p.x+J.lane(p.y),p.y))
	else:
		for offset in [Vector2.ZERO,Vector2(-3,4),Vector2(2,8),Vector2(5,6),Vector2(4,-3)]:
			result.append(J.point(origin.x+offset.x,origin.z+offset.y))
	return result
func _ready() -> void:
	for actor in city.npcs:next_turn[actor.name]=1.+posmod(str(actor.name).hash(),97)*.105
func refresh_neighbours() -> void:
	# In 0.4s even two oncoming residents travel less than 1.4m between samples.
	var players: Array=city.online_players() if city.has_method("online_players") else [city.bunny]
	var cells: Dictionary={}
	for actor in city.npcs:
		var cell:=Vector2i(floori(actor.position.x/6.),floori(actor.position.z/6.))
		if not cells.has(cell):cells[cell]=[]
		cells[cell].append(actor)
	for actor in city.npcs:
		var driver: Node=actor.get_node_or_null("NeighbourWalk")
		if not driver:continue
		var cell:=Vector2i(floori(actor.position.x/6.),floori(actor.position.z/6.))
		driver.local_neighbours.clear()
		driver.nearby_players.clear()
		for player: CharacterBody3D in players:
			if is_instance_valid(player) and player.position.distance_squared_to(actor.position)<81.:driver.nearby_players.append(player)
		for x in range(-1,2):
			for z in range(-1,2):
				var key:=cell+Vector2i(x,z)
				if cells.has(key):driver.local_neighbours.append_array(cells[key])
		driver.use_local_neighbours=true
func update_market() -> void:
	var seconds: float=city.manager.world.state.time if city.has_method("chatting_with") else city.session.state().time
	var hour:=fposmod(seconds,3600.)/150.
	var period:=1 if hour>=7. and hour<11. else (2 if hour>=17. and hour<22. else 0)
	if period==market_period:return
	market_period=period
	paid_respects.clear()
	for i in MORNING_COURT:
		var actor: CharacterBody3D=city.targets["JadeCitizen_"+str(i)].node
		var driver: Node=actor.get_node("NeighbourWalk")
		var home: Array=preload("res://scripts/jade/residents.gd").PEOPLE[i]
		var route:=walk_stops(i,J.point(home[2],home[3]))
		if period==1:
			route.clear()
			var spot: Vector2=MORNING_COURT[i]
			route.append(J.point(spot.x,spot.y))
		driver.route=route;driver.recent.clear();driver.path.clear()
		driver.wait=(int(i)%7)*.72
	for i in CUSTOMERS+DELIVERIES:
		var actor: CharacterBody3D=city.targets["JadeCitizen_"+str(i)].node
		var driver: Node=actor.get_node("NeighbourWalk")
		if period==0:
			var home: Array=preload("res://scripts/jade/residents.gd").PEOPLE[i]
			driver.route=walk_stops(i,J.point(home[2],home[3]))
		elif i in DELIVERIES:
			var stops: Array[Vector3]=[]
			var shop_z:=146. if period==1 else 127.
			var direction:=1. if i==0 else -1.
			for leg: float in [27.,18.,9.,15.,22.]:
				var z:=shop_z+leg*direction
				stops.append(J.point(J.lane(z)+direction*(2.5+1.8*sin(leg)),z))
			driver.route=stops
		else:
			var stops: Array[Vector3]=[]
			for spot: Vector2 in MARKET_CALLS:
				var z: float=float(146 if period==1 else 127)+spot.y+(i%3-1)*1.1
				stops.append(J.point(J.lane(z)+spot.x,z))
			driver.route=stops
		driver.recent.clear()
# Each official stops before the throne once per morning audience, even if their route continues.
func receive_court() -> void:
	if market_period!=1:return
	for index in COURT_DUTIES:
		if paid_respects.has(index):continue
		var id:="JadeCitizen_"+str(index)
		var actor: CharacterBody3D=city.targets[id].node
		if actor.position.z> -159. or actor.position.z< -168. or absf(actor.position.x)>6. or absf(actor.position.x)<2. or not actor.action.is_empty():continue
		if city.talking_npc==id or (city.has_method("chatting_with") and is_instance_valid(city.chatting_with(id))):continue
		var driver: Node=actor.get_node("NeighbourWalk")
		driver.wait=3.7
		actor.velocity.x=0.;actor.velocity.z=0.
		var throne: Vector3=city.targets["jade:audience:jade_throne_1"].position
		actor.set_visual_heading(atan2(throne.x-actor.position.x,throne.z-actor.position.z))
		actor.play_action(COURT_DUTIES[index],3.4)
		paid_respects[index]=true
func _physics_process(delta: float) -> void:
	elapsed+=delta
	imperial_court.walk(city,delta)
	tick+=delta
	if tick<.40:return
	tick=0.
	refresh_neighbours()
	update_market()
	imperial_court.update(city,market_period==1)
	receive_court()
	for actor in city.npcs:
		var id:=str(actor.name)
		if elapsed<next_turn.get(id,INF) or actor.walking or not actor.action.is_empty():continue
		if city.talking_npc==id or (city.has_method("chatting_with") and is_instance_valid(city.chatting_with(id))):continue
		var driver: Node=actor.get_node_or_null("NeighbourWalk")
		var pose: String
		var duration:=2.6
		if driver:
			if not driver.path.is_empty():continue
			var index:=int(id.trim_prefix("JadeCitizen_"))
			pose=preload("res://scripts/jade/residents.gd").PEOPLE[index][4]
			if market_period>0 and index in CUSTOMERS:
				var center_z:=146. if market_period==1 else 127.
				if absf(actor.position.z-center_z)<11.:
					pose="sort_seed" if market_period==1 else "tea"
					var stall:=J.point(J.lane(center_z)-13.,center_z)
					actor.visual.rotation.y=atan2(stall.x-actor.position.x,stall.z-actor.position.z)
			duration=3.6 if pose=="tea" or pose=="read_scroll" else 2.4
			driver.wait=maxf(driver.wait,duration+.3)
		elif id=="JadeEmperor":pose="read_scroll"
		else:
			pose=TRADES.get(id.trim_prefix("JadeVendor_"),"")
		if pose.is_empty():continue
		actor.play_action(pose,duration)
		next_turn[id]=elapsed+duration+3.75+float(posmod(id.hash()+int(elapsed),7))*.52
