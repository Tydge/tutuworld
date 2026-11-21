extends RefCounted
## A dye job changes rendering for one owned garment without changing its item ID.
const Materials=preload("res://scripts/appearance/material_catalog.gd")
const DB=preload("res://scripts/services/game_data.gd")

static func validate(raw: Variant) -> Dictionary:
	if not raw is Dictionary:return {}
	var pattern: Variant=raw.get("pattern")
	if not pattern is String or pattern not in Materials.choices("fabric","clothing"):return {}
	var result: Dictionary={"pattern":pattern}
	for key in ["color","accent"]:
		var dye: Variant=raw.get(key)
		if not dye is String or dye.length()!=6 or not Color.html_is_valid(dye):return {}
		result[key]=dye.to_lower()
	return result

static func normalize(raw: Variant,inventory: Dictionary) -> Dictionary:
	var clean: Dictionary={}
	if not raw is Dictionary:return clean
	for id in inventory:
		if int(inventory[id])<1 or DB.item(id).get("kind","")!="clothing" or not raw.has(id):continue
		var design:=validate(raw[id])
		if not design.is_empty():clean[id]=design
	return clean

static func worn(equipment: Dictionary,designs: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for id in equipment.values():
		if designs.has(id):result[id]=designs[id]
	return result
