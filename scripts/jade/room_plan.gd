extends RefCounted
const Games=preload("res://scripts/jade/house_games.gd")
# First item at each trade is its working model. Keep the aisle from the threshold to its south face clear.
const SIDES={
	"clock":["jade_gong","jade_scrolls"],"seats":["jade_curio","jade_blossom"],"weights":["jade_vat","jade_apothecary"],
	"weave":["jade_silk_rack","jade_embroidery"],"stitch":["jade_dress","jade_scrolls"],"pigment":["jade_curio","jade_vat"],
	"melody":["jade_censer","jade_moon_chair"],"jugs":["jade_vat","jade_vat"],"sail":["jade_loom","jade_scrolls"],
	"press":["jade_curio","jade_pastry_board"],"verse":["jade_scrolls","jade_blossom"],"sluice":["jade_clepsydra","jade_vat"],
	"proof":["jade_curio","jade_scrolls"],"forge":["jade_smith_rack","jade_curio"],"courier":["jade_scrolls","jade_moon_chair"],
	"wheel":["jade_vat","jade_ceramics"],"abacus":["jade_seed_bins","jade_scrolls"],"divide":["jade_steam_table","jade_vat"],
	"memory":["jade_dress","jade_qin"],"mirror":["jade_curio","jade_screen"],"tune":["jade_scrolls","jade_censer"],
	"tower":["jade_apothecary","jade_censer"],"cross":["jade_balance","jade_scrolls"],"allot":["jade_throne","jade_scrolls"],
	"stars":["jade_screen","jade_clepsydra"]}
static func ground(id: String) -> Array:
	if Games.STATIONS.has(id):
		var job: Dictionary=Games.STATIONS[id]
		var sides: Array=SIDES[job.decor]
		if id=="audience":return [[job.prop,-3.6,-1.4],["jade_throne",0,-4.0],["jade_screen",0,-5.6],["jade_censer",2.8,-3.5],["jade_censer",-2.8,-3.5],["jade_court_carpet",0.,-.65],["jade_gong",7.8,-4.5],["jade_curio",-7.4,-4.6],["jade_blossom",6.7,1.8],["jade_blossom",-6.7,1.8]]
		if id=="herbal":sides=["jade_apothecary","jade_blossom"]
		if id=="garden":sides=["jade_basin","jade_tea_desk"]
		if id=="paper":sides=["jade_brush","jade_screen"]
		if id=="kiln":sides=["jade_ceramics","jade_vat"]
		return [[job.prop,0.,-1.7],[sides[0],-2.9,-2.45],[sides[1],2.85,-1.65]]
	match id:
		"cot","inn":return [["jade_alcove_bed",1.9,-1.8],["jade_screen",-.5,-2.3],["jade_tea_desk",-3.0,.1],["jade_moon_chair",-3.,1.6]]
		"tea":return [["jade_tea_desk",-2.,-.6],["tea_service",-2.,-.6,.76],["jade_moon_chair",-2.,1.2],["jade_basin",2.8,-1.7]]
		"spice","tavern":return [["jade_steam_table",-2.6,-2.0],["jade_tea_desk",2.5,-1.4],["jade_vat",3.0,1.42]]
		"almond":return [["jade_pastry_board",-2.65,-2.0],["jade_curio",2.55,-2.1]]
		"furniture":return [["jade_moon_chair",-2.95,-.8],["jade_altar_table",2.7,-1.85],["jade_blossom",2.7,-1.85,1.14]]
		"tools":return [["jade_smith_rack",2.75,-1.6],["jade_balance",-2.65,-1.7]]
		"farm":return [["jade_seed_bins",2.55,-1.9],["jade_vat",-2.7,-1.75]]
		"clothes":return [["jade_dress",2.65,-2.2],["jade_embroidery",-2.7,-1.8]]
		"workshop":return [["jade_loom",-3.55,.8],["jade_curio",3.45,-2.15]]
		"dye","silk":return [["jade_dress",-2.6,-1.5],["jade_screen",2.8,-2.1],["jade_vat",2.7,1.1]]
		"dojo":return [["jade_practice",0.,.1],["jade_moon_chair",-3.,1.],["jade_screen",3.,-2.]]
		"duty","music":return [["jade_chime",0.,-1.],["jade_qin",2.9,-2.2],["jade_moon_chair",-2.6,-1.6]]
		"reading","scribe":return [["jade_curio",-2.6,-2.],["jade_altar_table",2.1,-2.1],["field_journal",2.1,-2.1,1.14],["jade_moon_chair",2.1,-.45]]
	return []
static func gallery(id: String) -> Array:
	match id:
		"scribe":return [["jade_curio",-2.6,-2.6],["jade_altar_table",.65,-1.42],["field_journal",.65,-1.42,1.14],["jade_scrolls",-2.7,1.]]
		"silk":return [["jade_dress",-2.7,-2.1],["jade_screen",1.4,-2.1],["jade_embroidery",2.7,.55]]
		"duty","music":return [["jade_chime",0.,-2.],["jade_moon_chair",-.3,2.1]]
		"inn","cot":return [["jade_alcove_bed",1.8,-1.65],["jade_screen",-.45,-2.],["jade_tea_desk",-3.,-.6]]
		"stage","drum","baihe":return [["jade_gong",-2.3,-2.1],["jade_dress",2.1,-2.],["jade_censer",-2.4,1.2]]
		_:return [["jade_tea_desk",-2.,-1.],["jade_moon_chair",-2.,.69],["jade_curio",2.5,-2.]]
