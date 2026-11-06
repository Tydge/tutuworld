extends SceneTree
const Food=preload("res://scripts/city/food_visual.gd")
const Meal=preload("res://scripts/city/meal_timeline.gd")
const A=preload("res://scripts/services/local_authority.gd")
const DB=preload("res://scripts/services/game_data.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func bounds(node: Node3D) -> AABB:
	var box:=AABB();var first:=true
	for mesh in node.get_children():
		if mesh is MeshInstance3D:box=mesh.get_aabb() if first else box.merge(mesh.get_aabb());first=false
	return box
func run() -> void:
	check(Meal.utensil("food_pumpkin_soup")=="spoon" and Meal.utensil("food_garden_salad")=="fork" and Meal.utensil("food_rustic_wheat_bread")=="hand","Soup, fork food and handheld food have distinct eating modes")
	for index in range(4):
		var elapsed: float=[0.,1.21,2.86,4.51][index]
		check(Meal.sample(elapsed).bites==index,"Swallow advances exactly one visual portion: "+str(index))
	check(Meal.sample(1.10).lift>.98 and Meal.sample(1.10).loaded and not Meal.sample(1.21).loaded,"Bite remains on the utensil until it reaches the mouth")
	check(Meal.sample(5.9).bites==3 and Meal.sample(5.9).lift==0.,"Empty dish and resting hand finish before job settlement")
	for id in Food.IDS:
		var model:=Food.make(id);var copy:=Food.make(id);var dish: MeshInstance3D=model.get_child(0);var dish_mesh: Mesh=dish.mesh
		check(model.get_node("Food/Portion0").get_child_count()>0 and model.get_node("Food/Portion3").get_child_count()==0,"Complete model and truly empty final dish: "+id)
		var box0:=bounds(model.get_node("Food/Portion0"));var box1:=bounds(model.get_node("Food/Portion1"));var box2:=bounds(model.get_node("Food/Portion2"))
		if Food.soup(id):check(box0.end.y>box1.end.y and box1.end.y>box2.end.y,"Soup liquid and garnish physically lower each bite: "+id)
		if id=="food_rustic_wheat_bread":check(box0.size.x>box1.size.x and box1.size.x>box2.size.x,"Bread portions expose actual cut geometry")
		for bites in range(4):
			Food.set_portion(model,bites)
			check(model.get_node("Food").get_children().filter(func(n):return n.visible).size()==1 and model.get_node("Food/Portion%d"%bites).visible and model.get_node("Food").scale==Vector3.ONE,"Only the appropriate prebuilt portion is visible; no whole-food scaling: "+id+" "+str(bites))
		check(dish.mesh==dish_mesh and dish.visible and model.get_child(0).mesh==copy.get_child(0).mesh,"Plate remains unchanged and cached mesh resources are shared: "+id)
		model.free();copy.free()
		var a:=A.new();a.state.player_position=[27.8,.1,-18.5];a.state.stamina=40.;a.add(id,2)
		check(a.execute({"verb":"eat","target":"dining","item":id}).ok,"Existing six-second authority starts this dish: "+id)
		a.tick(3.);a.execute({"verb":"cancel"})
		check(a.count(id)==2,"Cancelling after visual bites preserves food: "+id)
		a.execute({"verb":"eat","target":"dining","item":id});a.tick(6.)
		check(a.count(id)==1 and (a.state.food_effect.get("item","")==id if not DB.item(id).get("effect",{}).is_empty() else a.state.stamina>=70.),"Existing completion consumes once and applies the original effect: "+id)
	var icons: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/food/manifest.json"))
	check(icons.source_sha256==FileAccess.get_file_as_string("res://scripts/city/food_visual.gd").sha256_text() and icons.shader_sha256==FileAccess.get_file_as_string("res://assets/shaders/food_surface.gdshader").sha256_text(),"Baked menu thumbnails were generated from the current meal models and shader")
	for id in Food.IDS:check(icons.icons.get(id,"")==FileAccess.get_sha256("res://assets/ui/food/"+id+".png"),"Menu thumbnail exists with matching provenance: "+id)
	print("MEAL_PRESENTATION_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
