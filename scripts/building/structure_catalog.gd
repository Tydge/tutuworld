extends RefCounted
## Stable form IDs are additive to schema3; missing form always means the original model.
const STYLES:=["original","plaster","wood","brick","stone","herringbone","terrazzo","botanical","cottage_tile","glazed_tile","jade_frame","jade_post","jade_paving","jade_lacquer"]
const STYLE_NAMES:=["保留原样","灰泥 / 素色","木纹","砖石","石板","暖木人字拼","奶油水磨石","铃兰花纹","鼠尾草花砖","奶油青瓷釉砖","彩梁木构","朱木柱","青砖铺地","朱漆木壁"]
const PAVILION_WALLS := ["jade_pavilion_entry","jade_pavilion_screen"]
const TIMBER_WALLS := ["jade_frame","jade_eaves","jade_stage_back"]
const POST_WALLS := ["jade_post","jade_low_post"]
const GALLERY_WALLS := ["jade_colonnade","jade_balustrade","jade_eaves_bay"]
const WALL_FORMS := TIMBER_WALLS+POST_WALLS+GALLERY_WALLS+PAVILION_WALLS
static func supports_mounts(row: Dictionary) -> bool:
	var form: String=row.get("form","")
	return form=="" or form in TIMBER_WALLS
const FINISH_TOOLS := {
	"wall:jade_lime":{"name":"彩梁粉墙", "style":"jade_frame", "color":"e4d8bd"},
	"wall:jade_red":{"name":"朱漆殿墙", "style":"jade_lacquer", "form":"jade_frame", "color":"ab5945"},
	"wall:jade_eaves":{"name":"青瓦披檐墙", "style":"jade_frame", "color":"e4d8bd", "form":"jade_eaves"},
	"wall:jade_eaves_bay":{"name":"瓦檐戏廊", "style":"wood", "color":"a16850", "form":"jade_eaves_bay"},
	"wall:jade_stage_back":{"name":"彩绘戏屏墙", "style":"jade_lacquer", "color":"ab5945", "form":"jade_stage_back"},
	"wall:jade_pavilion_entry":{"name":"水榭敞口", "style":"wood", "color":"a16850", "form":"jade_pavilion_entry"},
	"wall:jade_pavilion_screen":{"name":"水榭槅扇栏", "style":"wood", "color":"a16850", "form":"jade_pavilion_screen"},
	"wall:jade_colonnade":{"name":"彩梁通廊", "style":"wood", "color":"a16850", "form":"jade_colonnade"},
	"wall:jade_balustrade":{"name":"槛栏廊墙", "style":"wood", "color":"a16850", "form":"jade_balustrade"},
	"wall:jade_low_post":{"name":"矮檐廊柱", "style":"jade_post", "color":"874e3c", "form":"jade_low_post"},
	"wall:jade_post":{"name":"朱木廊柱", "style":"jade_post", "color":"874e3c"},
	"floor:tile":{"name":"单格地板", "style":"wood", "color":"cda56e"},
	"floor:jade_paving":{"name":"青砖地坪", "style":"jade_paving", "color":"beab92"}
}
const FORMS:={
	"door":{"classic":"青藤镶板门","arch":"拱顶橡木门","glass":"花格玻璃门","jade_panel":"朱漆钉门"},
	"window":{"classic":"十字平开窗","arch":"拱顶花窗","round":"圆形舷窗","jade_lattice":"菱花槅窗","jade_shop_window":"南货陈列窗","jade_smith_window":"百炼铺窗"},
	"roof":{"classic":"双坡瓦屋顶","hip":"四坡檐屋顶","shed":"单坡采光屋顶","jade_tile":"青瓦飞檐","jade_double":"琉璃重檐","jade_pavilion":"八角攒尖顶","jade_bell":"悬钟楼顶","jade_glazed":"宫苑琉璃檐","jade_stage":"戏楼檐顶","jade_bridge":"过街廊顶","jade_walkway":"园林折廊顶","jade_veranda":"侧廊低檐"}}
static func form(row: Dictionary) -> String:return str(row.get("form","classic"))
static func label(row: Dictionary) -> String:return FORMS.get(row.get("type",""),{}).get(form(row),"")
static func pattern(style: String,floor_: bool=false) -> int:
	return {"wood":1,"brick":2 if floor_ else 3,"stone":3,"herringbone":4,"terrazzo":5,"botanical":6,"cottage_tile":7,"glazed_tile":8,"jade_frame":9,"jade_lacquer":11}.get(style,0)
static func surface(row: Dictionary,side: String="") -> Dictionary:
	return row.get("faces",{}).get(side,{"color":row.get("color","eadcc5"),"style":row.get("style","original"),"painted":row.get("painted",false)})
static func surface_key(row: Dictionary,side: String="") -> String:
	var face:=surface(row,side);return str(face.color)+":"+str(face.style)
static func normal(row: Dictionary) -> Vector2:return Vector2.DOWN if is_equal_approx(row.a[1],row.b[1]) else Vector2.RIGHT

static func default_color(type: String,form_: String="classic") -> String:
	match form_:
		"jade_double","jade_glazed": return "ebcd93"
		"jade_tile","jade_bell","jade_pavilion","jade_stage","jade_bridge","jade_walkway","jade_veranda": return "bdcfc4"
		"jade_panel": return "984c37"
		"jade_lattice","jade_shop_window","jade_smith_window": return "704c38"
	if type=="door" and form_=="arch":return "b58b62"
	return {"room":"eadcc5","floor":"cda56e","roof":"688d81","wall":"eadcc5","door":"739b8d","window":"eee2c6","stairs":"c6a373","railing":"a78358"}.get(type,"ffffff")
