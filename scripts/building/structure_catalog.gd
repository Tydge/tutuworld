extends RefCounted
## Stable form IDs are additive to schema3; missing form always means the original model.
const STYLES:=["original","plaster","wood","brick","stone","herringbone","terrazzo","botanical","cottage_tile","glazed_tile"]
const STYLE_NAMES:=["保留原样","灰泥 / 素色","木纹","砖石","石板","暖木人字拼","奶油水磨石","铃兰花纹","鼠尾草花砖","奶油青瓷釉砖"]
const FORMS:={
	"door":{"classic":"青藤镶板门","arch":"拱顶橡木门","glass":"花格玻璃门"},
	"window":{"classic":"十字平开窗","arch":"拱顶花窗","round":"圆形舷窗"},
	"roof":{"classic":"双坡瓦屋顶","hip":"四坡檐屋顶","shed":"单坡采光屋顶"}}
static func form(row: Dictionary) -> String:return str(row.get("form","classic"))
static func label(row: Dictionary) -> String:return FORMS.get(row.get("type",""),{}).get(form(row),"")
static func pattern(style: String,floor_: bool=false) -> int:
	return {"wood":1,"brick":2 if floor_ else 3,"stone":3,"herringbone":4,"terrazzo":5,"botanical":6,"cottage_tile":7,"glazed_tile":8}.get(style,0)
static func surface(row: Dictionary,side: String="") -> Dictionary:
	return row.get("faces",{}).get(side,{"color":row.get("color","eadcc5"),"style":row.get("style","original"),"painted":row.get("painted",false)})
static func surface_key(row: Dictionary,side: String="") -> String:
	var face:=surface(row,side);return str(face.color)+":"+str(face.style)
static func normal(row: Dictionary) -> Vector2:return Vector2.DOWN if is_equal_approx(row.a[1],row.b[1]) else Vector2.RIGHT

static func default_color(type: String,form_: String="classic") -> String:
	if type=="door" and form_=="arch":return "b58b62"
	return {"room":"eadcc5","floor":"cda56e","roof":"688d81","wall":"eadcc5","door":"739b8d","window":"eee2c6","stairs":"c6a373","railing":"a78358"}.get(type,"ffffff")
