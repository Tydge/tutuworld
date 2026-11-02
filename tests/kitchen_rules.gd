extends SceneTree
const A=preload("res://scripts/services/local_authority.gd")
const DB=preload("res://scripts/services/game_data.gd")
var failures: Array[String]=[]
var checks:=0
func check(ok: bool,label_: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func _initialize() -> void:
	var a=A.new()
	check(DB.recipes_for_station("kitchen").size()==7,"Seven crop recipes")
	check(not a.execute({"verb":"craft","target":"kitchen","recipe":"carrot_soup"}).ok,"Cannot cook remotely")
	a.state.player_position=[21,.1,-20]
	check(not a.execute({"verb":"craft","target":"kitchen","recipe":"carrot_soup"}).ok,"Missing ingredients rejected")
	check(not a.execute({"verb":"craft","target":"kitchen","recipe":"fake"}).ok,"Unknown recipes rejected")
	a.state.skills.cooking=5;a.state.skill_experience.cooking=preload("res://scripts/services/character_stats.gd").skill_start(5)
	for id in DB.recipes_for_station("kitchen"):
		var r:=DB.recipe(id)
		for ingredient in r.ingredients: a.add(ingredient,20)
		var before: Dictionary=a.state.inventory.duplicate(true)
		var command: Dictionary={"verb":"craft","target":"kitchen","recipe":id,"id":"cook-"+id}
		check(a.execute(command).ok,"Start "+id)
		var duration: float=float(r.seconds)/1.05
		check(is_equal_approx(a.job.duration,duration),"Cooking duration includes level-five speed: "+id)
		a.tick(duration-.1)
		check(a.state.inventory==before,"No material charged before full duration: "+id)
		check(not a.execute({"verb":"eat","target":"dining","item":r.output}).ok,"Busy job excludes second action: "+id)
		a.execute({"verb":"cancel"})
		check(a.state.inventory==before,"Cancelled cooking preserves ingredients: "+id)
		a.execute({"verb":"craft","target":"kitchen","recipe":id})
		a.tick(duration+.01)
		var consumed:=true
		for ingredient in r.ingredients: consumed=consumed and a.count(ingredient)==int(before[ingredient])-int(r.ingredients[ingredient])
		check(consumed and a.count(r.output)==int(before.get(r.output,0))+1,"One completed dish consumes exact recipe: "+id)
		a.execute(command)
		check(a.job.is_empty(),"Repeated command cannot create a second dish: "+id)
		check(not a.execute({"verb":"eat","target":"dining","item":r.output}).ok,"Eating requires dining table: "+id)
		a.state.player_position=[27.8,.1,-18.2];a.state.stamina=40;a.state.stamina_recovery_elapsed=0
		var food_before: int=a.count(r.output)
		check(a.execute({"verb":"eat","target":"dining","item":r.output}).ok,"Begin meal: "+id)
		a.tick(5.9)
		check(a.count(r.output)==food_before,"Meal requires full duration: "+id)
		a.execute({"verb":"cancel"})
		check(a.count(r.output)==food_before,"Cancelled meal preserves food: "+id)
		a.execute({"verb":"eat","target":"dining","item":r.output})
		a.tick(6.01)
		check(a.count(r.output)==food_before-1,"Finished meal consumes exactly one dish: "+id)
		if r.effect.is_empty():
			check(a.state.stamina==70,"Recovery meal restores thirty stamina")
			a.state.player_position=[21,.1,-20]
			continue
		check(a.state.food_effect.item==r.output,"Meal grants matching effect: "+id)
		check(is_equal_approx(a.state.food_effect.expires_at-a.state.time,3600),"Food effect lasts one game day: "+id)
		for effect in r.effect:
			check(is_equal_approx(a.multiplier(effect),1+float(r.effect[effect])+(.01 if preload("res://scripts/services/character_stats.gd").attribute_skill(effect)!="" else 0)),"Correct nonstacking modifier: "+effect)
		if r.effect.has("water"): check(a.action_duration("water")<2,"Watering is faster")
		if r.effect.has("mining"): check(a.action_duration("gather","copper")<2 and a.action_duration("gather","limestone")<2 and a.action_duration("gather","branch")==2,"Mining affects both ore and stone, not branches")
		if r.effect.has("farm"): check(a.action_duration("plant")<2 and a.action_duration("weed")<2 and a.action_duration("harvest")<2,"Farm food speeds all three garden jobs")
		a.tick(3599)
		check(not a.state.food_effect.is_empty(),"Effect remains until a full day: "+id)
		a.tick(1.01)
		check(a.state.food_effect.is_empty() and is_equal_approx(a.multiplier("move"),1),"Effect expires automatically: "+id)
		a.state.player_position=[21,.1,-20]
	# Replacement and cancellation must not erase a previous effect.
	a.add("food_carrot_soup",2)
	a.add("food_garden_salad",2)
	a.state.player_position=[27.8,.1,-18.2]
	a.execute({"verb":"eat","target":"dining","item":"food_carrot_soup"}); a.tick(6)
	var old: Dictionary=a.state.food_effect.duplicate(true)
	a.execute({"verb":"eat","target":"dining","item":"food_garden_salad"}); a.tick(2); a.execute({"verb":"cancel"})
	check(a.state.food_effect==old,"Cancelling a new meal preserves the prior effect")
	a.execute({"verb":"eat","target":"dining","item":"food_garden_salad"}); a.tick(6)
	check(a.multiplier("move")==1 and a.multiplier("water")>1,"New meal replaces prior bonus instead of stacking")
	check(not a.execute({"verb":"eat","target":"dining","item":"carrot"}).ok,"Raw crop cannot impersonate a cooked meal")
	a.state.player_position=[DB.shops().farm.x,.18,DB.shops().farm.y+2.0]
	for id in ["sea_salt","olive_oil","cream","honey","egg"]: check(a.execute({"verb":"buy","shop":"farm","item":id,"quantity":5}).ok,"Seasoning shop sale: "+id)
	print("KITCHEN_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
