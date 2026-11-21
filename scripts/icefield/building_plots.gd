extends RefCounted
## Two snowy terraces and two rows of lots along the icefield coast.
const SIZE:=Vector2(24,20)
const LEVEL:=.8
const IDS:=["snow_birch","snow_hearth","ice_south_1","ice_south_2","ice_south_3","ice_north_1","ice_north_2","ice_north_3"]
const ORIGINS:=[Vector2(-68,-51),Vector2(-69,84),Vector2(4,109),Vector2(34,106),Vector2(69,94),Vector2(-2,-116),Vector2(41,-128),Vector2(88,-113)]
const NAMES:=["雪桦坡","白雪炉边","海雾湾","浮冰湾","听海角","松岭脚","霜峰下","望雪岭"]

static func bounds(index: int) -> Rect2:return Rect2(ORIGINS[index],SIZE)
static func distance(point: Vector2,rect: Rect2) -> float:return point.distance_to(point.clamp(rect.position,rect.end))
static func grade(point: Vector2,ground: float) -> float:
	for index in range(IDS.size()):
		var edge:=distance(point,bounds(index))
		if edge<9.:return lerpf(LEVEL,ground,smoothstep(1.8,9.,edge))
	return ground
static func clear(point: Vector2,margin: float) -> bool:
	for index in range(IDS.size()):
		if bounds(index).grow(margin).has_point(point):return false
	return true
