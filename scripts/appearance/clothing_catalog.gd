extends RefCounted
## Expand defaults -> clothing style -> item override without enumerating variants in code.
const Catalog=preload("res://scripts/appearance/material_catalog.gd")
const DATA="res://data/appearance/clothing.json"
static var _data: Dictionary={}
static var _items: Dictionary={}

static func data() -> Dictionary:
	if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return _data

static func items() -> Dictionary:
	if _items.is_empty():
		var content:=data()
		for id in content.items:
			var row: Dictionary=content.defaults.duplicate(true)
			row.merge(content.styles.get(content.items[id].get("style",""),{}),true)
			row.merge(content.items[id],true)
			_items[id]=row
	return _items

static func starters() -> Array[String]:
	var result: Array[String]=[];result.assign(data().starters);return result

static func errors() -> Array[String]:
	var result: Array[String]=[]
	if data().get("schema",0)!=1:result.append("Unsupported clothing catalog schema")
	for id in items():
		var row: Dictionary=items()[id]
		if not data().styles.has(row.get("style","")):result.append(id+": unknown clothing style")
		if row.get("pattern","") not in Catalog.choices("fabric","clothing"):result.append(id+": unknown clothing pattern")
		if row.get("slot","") not in ["head","body","neck"] or int(row.get("price",-1))<0:result.append(id+": invalid slot or price")
		for channel in ["color","accent"]:
			if channel=="accent" and not row.has(channel):continue
			var color_:=str(row.get(channel,""))
			if color_.length()!=6 or not Color.html_is_valid(color_):result.append(id+": invalid "+channel)
	for id in starters():
		if not items().has(id):result.append(id+": unknown starter clothing ID")
	return result
