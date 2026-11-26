extends RefCounted
const NATIVE := {"spice":"steamer","almond":"pastry_shop","cot":"lodging","duty":"chime","dye":"dye","reading":"read","tavern":"kitchen","farm":"seed_shop","clothes":"silk_shop","tools":"iron_shop","furniture":"carpentry_shop","workshop":"craft","tea":"tea","inn":"lodging","dojo":"footwork","music":"chime","scribe":"read","silk":"dye"}
# The workshop, field and kitchen accept these same goods from the player's bag.
const TAKE_HOME := {"weave":"ramie_cloth","pastry":"almond_biscuit","farmhouse":"seed_cotton","banquet":"sweet_osmanthus"}
const STATIONS := {
	"drum":{"game":"paired_dials","title":"校时鸣鼓","action":"校更鼓","prop":"jade_gong","decor":"clock"},
	"baihe":{"game":"procession","title":"鹤使排班","action":"排仪仗","prop":"jade_sandtray","decor":"seats"},
	"oil":{"game":"balance","title":"戥一壶杏油","action":"称杏油","prop":"jade_balance","decor":"weights"},
	"basket":{"game":"nonogram","title":"篾上藏花","action":"编竹席","prop":"jade_loom","decor":"weave"},
	"stitch":{"game":"seam_trail","title":"一线补燕尾","action":"补燕尾","prop":"jade_embroidery","decor":"stitch"},
	"lacquer":{"game":"mix","title":"旧匣试漆","action":"调漆","prop":"jade_brush","decor":"pigment"},
	"pipa":{"game":"echo","title":"听船歌","action":"试弦","prop":"jade_qin","decor":"melody"},
	"pickle":{"game":"decant","title":"分酱卤","action":"分卤","prop":"jade_vat","decor":"jugs"},
	"sail":{"game":"wind","title":"借风拾货","action":"试风帆","prop":"jade_sandtray","decor":"sail"},
	"weave":{"game":"loom","title":"续一段旧锦","action":"提花","prop":"jade_loom","decor":"weave"},
	"pastry":{"game":"tile_pan","title":"杏花排炉","action":"排饼模","prop":"jade_altar_table","decor":"press"},
	"caligraphy":{"game":"sliding_rubbing","title":"重拼残帖","action":"拼残帖","prop":"jade_brush","decor":"stitch"},
	"poetry":{"game":"inscription","title":"兰舟题画","action":"题画","prop":"jade_brush","decor":"verse"},
	"herbal":{"game":"botany","title":"闻香辨草","action":"辨药样","prop":"jade_balance","decor":"weights"},
	"weir":{"game":"canal","title":"分水入田","action":"开分水闸","prop":"jade_sandtray","decor":"sluice"},
	"books":{"game":"proof","title":"寻蠹补字","action":"校孤本","prop":"jade_brush","decor":"proof"},
	"silversmith":{"game":"inlay","title":"錾珠入钗","action":"錾银珠","prop":"jade_altar_table","decor":"forge"},
	"hostel":{"game":"itinerary","title":"旧渡排驿程","action":"排取信路线","prop":"jade_scrolls","decor":"courier"},
	"potter":{"game":"clay","title":"推泥成器","action":"拉碗坯","prop":"jade_wheel","decor":"wheel"},
	"ledger":{"game":"account","title":"合一笔米账","action":"合米账","prop":"jade_abacus","decor":"abacus"},
	"noodle":{"game":"cuts","title":"一绳三桌","action":"切面绳","prop":"jade_altar_table","decor":"divide"},
	"stage":{"game":"curtain","title":"幕后寻角","action":"看换幕","prop":"jade_gong","decor":"memory"},
	"post":{"game":"mail_sort","title":"桥头分信","action":"分驿袋","prop":"jade_scrolls","decor":"courier"},
	"carver":{"game":"engrave","title":"反刻印面","action":"刻印","prop":"jade_brush","decor":"mirror"},
	"fiddler":{"game":"intonation","title":"给老琴定弦","action":"调弦","prop":"jade_qin","decor":"tune"},
	"incense":{"game":"rings","title":"叠香篆","action":"叠香篆","prop":"jade_censer","decor":"tower"},
	"tailorhome":{"game":"unthread","title":"拆线解绷","action":"理绣线","prop":"jade_embroidery","decor":"mirror"},
	"ferry":{"game":"tides","title":"候潮排船","action":"排泊位","prop":"jade_clepsydra","decor":"clock"},
	"guild":{"game":"crossing","title":"渡船分舱","action":"排渡次","prop":"jade_sandtray","decor":"cross"},
	"kiln":{"game":"firing","title":"守一炉青瓷","action":"候窑火","prop":"jade_wheel","decor":"forge"},
	"academy":{"game":"stones","title":"弈石问学","action":"与先生弈石","prop":"jade_brush","decor":"verse"},
	"paper":{"game":"printmaking","title":"透光花笺","action":"套印花笺","prop":"jade_embroidery","decor":"press"},
	"garden":{"game":"prune","title":"剪枝借景","action":"剪花枝","prop":"jade_blossom","decor":"seats"},
	"farmhouse":{"game":"irrigation","title":"桑垄轮灌","action":"轮灌桑田","prop":"jade_sandtray","decor":"sluice"},
	"audience":{"game":"petitions","title":"含章殿听事","action":"批三坊用度","prop":"jade_abacus","decor":"allot"},
	"archive":{"game":"triangulate","title":"按碑寻仓","action":"校图签","prop":"jade_scrolls","decor":"proof"},
	"banquet":{"game":"sowing","title":"转席分糕","action":"转席点心","prop":"jade_altar_table","decor":"divide"},
	"chamber":{"game":"bearings","title":"栖梧认星","action":"连星图","prop":"jade_sandtray","decor":"stars"}}
const PERFORMANCES := {
	"dojo":{"game":"footwork","title":"鼓上梅花步","action":"踏梅花步"},
	"duty":{"game":"harbour_signals","title":"听磬传船令","action":"听磬传船令"},
	"music":{"game":"compose","title":"为听韶台谱曲","action":"自谱迎宾曲"}}
static func entry(house: String) -> Dictionary:
	return STATIONS.get(house,PERFORMANCES.get(house,{}))
static func type_for(house: String) -> String:
	return entry(house).get("game",NATIVE.get(house,""))
