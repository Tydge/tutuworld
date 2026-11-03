extends RefCounted
## Shared material IDs, eligibility and display order. No rendering or game state.
const DATA = "res://data/appearance/materials.json"
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return _data

static func definition(id: String) -> Dictionary:
	return data().materials.get(id, {})

static func label(id: String) -> String:
	return str(definition(id).get("name", id))

static func choices(family: String, use: String = "furniture", only: Array = []) -> Array[String]:
	var result: Array[String] = []
	for id in data().materials:
		var row := definition(id)
		if use not in row.uses or (family not in row.families and "*" not in row.families):
			continue
		if not only.is_empty() and id not in only:
			continue
		result.append(id)
	result.sort_custom(func(a, b): return definition(a).order < definition(b).order)
	return result

static func is_pattern(id: String) -> bool:
	return definition(id).get("renderer", "") == "fabric"

static func scale_for(id: String, use: String) -> float:
	return float(definition(id).get("scale", {}).get(use, 1.0))

static func errors() -> Array[String]:
	var result: Array[String] = []
	var content := data()
	if content.get("schema", 0) != 1:
		result.append("Unsupported material catalog schema")
	for id in content.materials:
		var row := definition(id)
		if str(row.get("name", "")).is_empty() or row.get("renderer", "") not in ["original", "solid", "surface", "fabric"]:
			result.append(id + ": missing name or unknown renderer")
		for family in row.get("families", []):
			if family != "*" and not content.families.has(family):
				result.append(id + ": unknown family " + str(family))
		if row.get("families", []).is_empty() or row.get("uses", []).is_empty() or not row.has("order"):
			result.append(id + ": missing eligibility or order")
		for use in row.get("uses", []):
			if use not in ["furniture", "clothing"]:
				result.append(id + ": unknown use " + str(use))
		if row.get("renderer", "") == "fabric":
			if not FileAccess.file_exists(row.get("texture", "")):
				result.append(id + ": missing pattern image")
			for use in ["clothing", "furniture", "quilt"]:
				if scale_for(id, use) <= 0.0:
					result.append(id + ": invalid pattern scale")
		if row.get("renderer", "") == "surface" and int(row.get("surface_pattern", -1)) not in [0, 1, 2, 3]:
			result.append(id + ": unsupported surface pattern")
	return result
