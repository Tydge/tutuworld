extends RefCounted
const L=preload("res://scripts/building/layout.gd")
## An additive, once-per-world source migration. Player buildings and assets stay intact.
static func ensure(layout: Dictionary) -> Dictionary:
	if int(layout.get("multistorey_showcase",0))>=1 or layout.has("recovery_source"):return layout
	var source:=preload("res://scripts/building/templates.gd").two_storey()
	var candidate:=L.merge_template(layout,source,Vector2(139,10));candidate.multistorey_showcase=1
	var result:=L.validate(candidate)
	return result.layout if result.ok and result.layout.elements.size()>layout.elements.size() else layout
