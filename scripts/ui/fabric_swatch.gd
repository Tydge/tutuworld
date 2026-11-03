extends RefCounted
## Small cached two-color previews. Uses the same pattern mask as the 3D shader.
const Fabric = preload("res://scripts/appearance/fabric_material.gd")
const Catalog = preload("res://scripts/appearance/material_catalog.gd")
static var _cache: Dictionary = {}

static func texture(item: Dictionary) -> Texture2D:
	var id := str(item.get("pattern", "solid"))
	if not Catalog.is_pattern(id):
		return null
	var dye := Color(item.get("color", "629184"))
	var accent := Color(item.get("accent", "f7e5bc"))
	var strength := float(item.get("pattern_strength", 0.78))
	var key := id + dye.to_html() + accent.to_html() + str(strength)
	if _cache.has(key):
		return _cache[key]
	var image := Fabric.texture(id).get_image()
	image.clear_mipmaps()
	image.resize(80, 80, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			image.set_pixel(x, y, dye.lerp(accent, image.get_pixel(x, y).r * strength))
	if _cache.size() >= 64:
		_cache.erase(_cache.keys()[0])
	_cache[key] = ImageTexture.create_from_image(image)
	return _cache[key]
