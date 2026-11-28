extends RefCounted
## The town's shells follow free terrain. Their player plans use the editor's
## half-metre grid and standard storey height, including real stair landings.
const City = preload("res://scripts/jade/layout.gd")
const ORIGIN := Vector2(139, 10)
var elements: Array = []
var level := 0
var wall_color := "e4d8bd"

static func make(kind: String) -> Dictionary:
	var plan := new()
	var shape := kind.trim_prefix("jade_")
	match shape:
		"street_gallery", "street_gallery_reverse":
			plan.bridge(shape == "street_gallery_reverse")
		"gallery":
			plan.veranda(Rect2(-2.5, -1.5, 5, 3))
		_:
			plan.house(shape)
	return {"schema":4, "next_id":plan.elements.size() + 1, "elements":plan.elements}

func point(p: Vector2) -> Array:
	return [ORIGIN.x + p.x, ORIGIN.y + p.y]

func add(part: Dictionary) -> String:
	part.id = "build_%d" % (elements.size() + 1)
	part.storey = level
	elements.append(part)
	return part.id

func floor_area(area: Rect2) -> void:
	add({"type":"floor", "a":point(area.position), "b":point(area.end),
		"color":"beab92" if level == 0 else "a77152", "style":"jade_paving" if level == 0 else "wood"})

func roof(area: Rect2, form: String = "jade_tile") -> void:
	add({"type":"roof", "a":point(area.position), "b":point(area.end), "form":form,
		"color":"ebcd93" if form in ["jade_double","jade_glazed"] else "bdcfc4"})

func wall(a: Vector2, b: Vector2, openings: Array = [], form_: String = "jade_frame") -> void:
	var id := add({"type":"wall", "a":point(a), "b":point(b), "style":"jade_lacquer" if wall_color=="ab5945" else "jade_frame", "form":form_, "color":wall_color})
	for opening in openings:
		var door: bool = opening[0] == "door"
		var form: String=opening[2] if opening.size()>2 else ("jade_panel" if door else "jade_lattice")
		add({"type":opening[0], "wall":id, "offset":opening[1], "form":form,
			"style":"wood", "color":"984c37" if door else "704c38"})

func post(x: float, z: float, low: bool=false) -> void:
	# A single half-metre wall edge also serves as a freestanding timber post.
	add({"type":"wall", "a":point(Vector2(x, z)), "b":point(Vector2(x + .5, z)),
		"color":"874e3c", "style":"jade_post", "form":"jade_low_post" if low else "jade_post"})

func colonnade(a: Vector2, b: Vector2, railing: bool = false, form_: String="jade_colonnade") -> void:
	add({"type":"wall", "a":point(a), "b":point(b), "color":"a16850", "style":"wood",
		"form":"jade_balustrade" if railing else form_})

func open_sides(area: Rect2, railing: bool) -> void:
	var a := area.position
	var b := area.end
	colonnade(a, Vector2(b.x,a.y), railing)
	colonnade(Vector2(b.x,a.y), b, railing)
	colonnade(b, Vector2(a.x,b.y))
	colonnade(Vector2(a.x,b.y), a, railing)

func stair(x: float, z: float, yaw: float) -> void:
	add({"type":"stairs", "form":"straight", "position":point(Vector2(x, z)), "yaw":yaw,
		"style":"wood", "color":"a26e4d"})

func veranda(area: Rect2) -> void:
	floor_area(area)
	roof(area,"jade_walkway")
	open_sides(area, false)

func house(shape: String) -> void:
	var dims := City.dims(shape)
	if shape == "palace": dims *= .77
	var w := snappedf(dims.x, .5)
	var d := snappedf(dims.z, .5)
	var main := Rect2(-w, -d, 2*w, 2*d)
	var upper := shape in ["loft", "inn", "clocktower", "theatre"]
	if shape in ["court", "palace"]: wall_color = "ab5945"
	floor_area(main)
	if shape == "pavilion":
		var corners := [Vector2(-w,-d),Vector2(w,-d),Vector2(w,d),Vector2(-w,d)]
		for i in 4:
			add({"type":"wall","a":point(corners[i]),"b":point(corners[(i+1)%4]),"color":"a16850","style":"wood",
				"form":"jade_pavilion_entry" if i==2 else "jade_pavilion_screen"})
		roof(main, "jade_pavilion")
		return

	var front: Array = [["door", w]]
	if w >= 4.5:
		front.append_array([["window", maxf(1.4,w*.36)], ["window", 2.*w-maxf(1.4,w*.36)]])
	if shape in ["store","forge"]:front[1].append("jade_smith_window" if shape=="forge" else "jade_shop_window")
	if shape == "theatre":
		colonnade(Vector2(-w,d),Vector2(w,d),false,"jade_eaves_bay")
		colonnade(Vector2(w,d),Vector2(w,-d),false,"jade_eaves_bay")
		colonnade(Vector2(-w,-d),Vector2(-w,d),false,"jade_eaves_bay")
		wall(Vector2(w,-d),Vector2(-w,-d),[],"jade_stage_back")
	else:
		wall(Vector2(-w,d), Vector2(w,d), front,"jade_eaves" if upper else "jade_frame")
		wall(Vector2(w,-d), Vector2(w,d), [["window",d*.42],["window",d*1.58]])
		wall(Vector2(-w,-d), Vector2(-w,d), [["door",d-1.5]] if shape == "court" else [["window",d*.42],["window",d*1.58]])
		wall(Vector2(w,-d), Vector2(-w,-d), [["window",w*.36],["window",w*1.64]],"jade_eaves" if upper else "jade_frame")
	match shape:
		"cottage", "forge", "cloister":
			# Outer supports only along the shared wall.
			var porch := Rect2(-w-3., -d, 3., 2*d+2.)
			floor_area(porch)
			roof(porch,"jade_veranda")
			for z in [-d, 0., d+2.]: post(-w-3., z,true)
		"store":
			var porch := Rect2(-w, d, 2*w, 2.)
			floor_area(porch)
			roof(porch,"jade_veranda")
			elements.back().yaw=90.
			for x in [-w, w-.5]: post(x, d+2.,true)
		"court":
			var wing := Rect2(-w-3., -d, 3., d+1.)
			floor_area(wing)
			roof(wing,"jade_glazed")
			wall(wing.position, Vector2(-w,-d))
			wall(wing.position, Vector2(-w-3.,1.), [["window",3.]])
			wall(Vector2(-w-3.,1.), Vector2(-w,1.))
	if not upper:
		roof(main, {"palace":"jade_double","court":"jade_glazed"}.get(shape,"jade_tile"))
		return

	# The flight is outside the wall. Its top landing joins the open front gallery.
	var stair_x := w + 1.5
	floor_area(Rect2(w, -7., 3., 3.))
	stair(stair_x, 0., 180.)
	level = 1
	floor_area(main)
	floor_area(Rect2(w, 4., 3., 3.))
	if d < 7.:
		floor_area(Rect2(w-1.5, d, 1.5, 7.-d))
	if shape == "theatre":
		colonnade(Vector2(-w,-d), Vector2(w,-d), true)
		colonnade(Vector2(-w,d), Vector2(-w,-d), true)
		colonnade(Vector2(w,-d),Vector2(w,2.), true)
	else:
		wall(Vector2(-w,-d), Vector2(w,-d), [["window",w*.5],["window",w*1.5]])
		wall(Vector2(-w,-d), Vector2(-w,d), [["window",d]])
		wall(Vector2(w,-d), Vector2(w,2.), [["window",3.]])
	colonnade(Vector2(w,2.),Vector2(w,d))
	colonnade(Vector2(w,d),Vector2(-w,d), true)
	roof(main, {"clocktower":"jade_bell", "theatre":"jade_stage"}.get(shape, "jade_tile"))

func bridge(mirrored: bool) -> void:
	var deck := Rect2(-4.5, -1.5, 9., 3.)
	floor_area(deck) # The paved passage supports the open span when its facade is dragged.
	var hand := -1. if mirrored else 1.
	for side in [-1., 1.]:
		var sign_: float = hand * side
		var x: float = side * 6.
		var bottom_z: float = 7.5 * sign_
		floor_area(Rect2(x-1.5, bottom_z-1.5, 3., 3.))
		stair(x, 2.*sign_, 0. if sign_ > 0. else 180.)
		for z in [-1.5, 1.5]: post(side*3.5, z)
	level = 1
	floor_area(deck)
	for side in [-1., 1.]:
		var sign_: float = hand * side
		floor_area(Rect2(4.5 if side > 0. else -7.5, -5. if sign_ > 0. else -1.5, 3., 6.5))
	for z in [-1.5, 1.5]:colonnade(Vector2(-4.5,z),Vector2(4.5,z),true)
	for x in [-4.5, 4.5]:colonnade(Vector2(x,-1.5),Vector2(x,1.5))
	roof(deck,"jade_bridge")
