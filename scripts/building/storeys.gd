extends RefCounted
## One height convention for layouts, physics, picking and the follow camera.
const STAIR_FORMS:={"straight":"直线木楼梯","l":"L形平台楼梯","u":"U形折返楼梯"}
const HEIGHT:=4.7
const FLOOR:=.18
const MAX:=4
static func of(row: Dictionary) -> int:return int(row.get("storey",0))
static func elevation(row: Dictionary) -> float:return of(row)*HEIGHT
static func at_height(y: float) -> int:return clampi(floori((y-FLOOR+.35)/HEIGHT),0,MAX-1)
static func subset(layout: Dictionary,level: int) -> Dictionary:
	var result:=layout.duplicate(false);result.elements=layout.elements.filter(func(row):return of(row)==level);return result
static func highest(layout: Dictionary) -> int:
	var result:=0
	for row in layout.elements:result=maxi(result,of(row)+(1 if row.type=="stairs" else 0))
	return result

static func levels(layout: Dictionary) -> Array:
	var found: Dictionary={0:true}
	for row in layout.elements:found[of(row)]=true
	var result:=found.keys();result.sort();return result
