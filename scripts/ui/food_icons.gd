extends RefCounted
## Baked once by tools/render_food_icons.gd from the exact in-world dish models.
const TEXTURES:={
	"food_carrot_soup":preload("res://assets/ui/food/food_carrot_soup.png"),
	"food_garden_salad":preload("res://assets/ui/food/food_garden_salad.png"),
	"food_tomato_stew":preload("res://assets/ui/food/food_tomato_stew.png"),
	"food_pumpkin_soup":preload("res://assets/ui/food/food_pumpkin_soup.png"),
	"food_honey_wheat_cake":preload("res://assets/ui/food/food_honey_wheat_cake.png"),
	"food_rustic_wheat_bread":preload("res://assets/ui/food/food_rustic_wheat_bread.png"),
	"food_vegetable_omelette":preload("res://assets/ui/food/food_vegetable_omelette.png"),
	"food_snow_loaf":preload("res://assets/ui/food/food_snow_loaf.png"),
	"food_pine_tea":preload("res://assets/ui/food/food_pine_tea.png"),
	"sweet_osmanthus":preload("res://assets/ui/food/sweet_osmanthus.png"),
	"almond_biscuit":preload("res://assets/ui/food/almond_biscuit.png")
}
static func texture(id: String) -> Texture2D:return TEXTURES.get(id)
