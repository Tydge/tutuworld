extends RefCounted
## X/Z offsets follow Godot's positive Y rotation (opposite Vector2 rotation).
const CATEGORIES:=["结构","床","座椅","桌柜","照明","装饰","庭院"]
const OBJECTS:={
	"bed":{"name":"木床","size":Vector2(2.7,4.5),"height":1.8,"category":"床"},
	"bedside":{"name":"床头柜","size":Vector2(.8,.8),"height":.8,"surface":Vector2(.74,.70),"surface_height":.8,"category":"桌柜"},
	"sofa":{"name":"双人沙发","size":Vector2(3.5,1.6),"height":1.7,"category":"座椅"},
	"chair":{"name":"木椅","size":Vector2(1.06,1.04),"height":1.45,"category":"座椅"},
	"tea_table":{"name":"木茶几","size":Vector2(2.45,1.35),"height":.74,"surface":Vector2(2.35,1.22),"surface_height":.735,"category":"桌柜"},
	"desk":{"name":"木书桌","size":Vector2(2.85,1.18),"height":1.14,"surface":Vector2(2.65,1.10),"surface_height":1.14,"category":"桌柜"},
	"bookshelf":{"name":"书架","size":Vector2(1.7,.8),"wall_size":Vector2(1.6,.7),"height":2.34,"surface":Vector2(1.22,.53),"surface_offset":Vector2(0,.015),"surface_height":2.32,"surface_levels":[2.32,1.58,.88,.18],"category":"桌柜"},
	"hearth":{"name":"壁炉","size":Vector2(3.,1.45),"height":1.82,"surface":Vector2(2.85,.88),"surface_offset":Vector2(0,.04),"surface_height":1.82,"category":"桌柜"},
	"forest_cabinet":{"name":"木质收纳柜","size":Vector2(1.75,.9),"wall_size":Vector2(1.6,.75),"height":1.84,"surface":Vector2(1.55,.67),"surface_height":1.84,"category":"桌柜"},
	"table_lamp":{"name":"暖光台灯","size":Vector2(.62,.62),"height":.72,"mount":"surface","category":"照明"},
	"pendant":{"name":"暖光吊灯","size":Vector2(1.,1.),"height":.85,"mount":"ceiling","category":"照明"},
	"book":{"name":"小书本","size":Vector2(.66,.43),"height":.10,"mount":"surface","category":"装饰"},
	"standing_book":{"name":"竖放书籍","size":Vector2(.17,.42),"height":.52,"mount":"surface","category":"装饰"},
	"cup":{"name":"陶瓷杯","size":Vector2(.43,.34),"height":.18,"offset":Vector2(.055,0),"mount":"surface","category":"装饰"},
	"letter":{"name":"信纸","size":Vector2(.74,.52),"height":.035,"mount":"surface","category":"装饰"},
	"small_plant":{"name":"桌面盆栽","size":Vector2(.52,.52),"height":.82,"mount":"surface","category":"装饰"},
	"clock":{"name":"座钟","size":Vector2(.56,.22),"height":.57,"mount":"surface","category":"装饰"},
	"forest_settee":{"name":"藤木长椅","size":Vector2(3.5,1.6),"height":1.6,"category":"座椅"},
	"forest_rug":{"name":"圆形编织地毯","size":Vector2(4.75,4.75),"height":.06,"overlay":true,"category":"装饰"},
	"forest_planter":{"name":"陶盆绿植","size":Vector2(1.,1.),"height":1.6,"outdoor":true,"category":"庭院"},
	"flowerbed":{"name":"石砌花坛","size":Vector2(3.3,3.3),"height":1.,"outdoor":true,"category":"庭院"},
	"fountain":{"name":"花苞喷泉","size":Vector2(6.4,6.4),"height":3.,"outdoor":true,"category":"庭院"}}
static func rotate_xz(point: Vector2,yaw: float) -> Vector2:return point.rotated(-deg_to_rad(yaw))
static func bounds(item: Dictionary,size_: Vector2,offset:=Vector2.ZERO) -> Rect2:
	var p:=Vector2(item.position[0],item.position[1]);var rect:=Rect2(p+rotate_xz(offset,float(item.get("yaw",0))),Vector2.ZERO)
	for x in [-.5,.5]:
		for z in [-.5,.5]:rect=rect.expand(p+rotate_xz(offset+size_*Vector2(x,z),float(item.get("yaw",0))))
	return rect
static func footprint(item: Dictionary) -> Rect2:
	var row: Dictionary=OBJECTS.get(item.get("kind",""),{})
	return bounds(item,row.get("size",Vector2.ONE),row.get("offset",Vector2.ZERO))
static func wall_footprint(item: Dictionary) -> Rect2:
	var row: Dictionary=OBJECTS[item.kind]
	return bounds(item,row.get("wall_size",row.size),row.get("offset",Vector2.ZERO))
static func mount(item: Dictionary) -> String:return str(OBJECTS.get(item.get("kind",""),{}).get("mount","floor"))
static func name_for(row: Dictionary) -> String:
	if row.get("type","")=="object":return OBJECTS.get(row.get("kind",""),{}).get("name","物件")
	return {"template":"整栋样板房","floor":"地板","wall":"墙壁","window":"窗户","door":"门","roof":"屋顶"}.get(row.get("type",""),"物件")
