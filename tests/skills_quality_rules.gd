extends SceneTree
const A=preload("res://scripts/services/local_authority.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Stats=preload("res://scripts/services/character_stats.gd")
const S=preload("res://scripts/services/session.gd")
class ControlledAuthority extends A:
	var forced_critical:=false
	var rolls:=0
	func roll_critical(_chance: float) -> bool:
		rolls+=1
		return forced_critical
var checks:=0
var failures: Array=[]
func check(condition: bool,label_: String) -> void:
	checks+=1
	if not condition: failures.append(label_);print("FAIL ",label_)
func set_level(a,skill: String,level: int) -> void:
	a.state.skill_experience[skill]=Stats.skill_start(level)
	a.state.skills[skill]=level
func finish(a) -> Dictionary:
	if a.job.is_empty(): return {}
	var events: Array=a.tick(float(a.job.duration)-float(a.job.elapsed)+.001)
	return events[-1] if not events.is_empty() else {}
func command(a,verb: String,target: String="",item: String="") -> Dictionary:
	return a.execute({"verb":verb,"target":target,"item":item,"recipe":item})
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for level in range(1,100):
		check(Stats.skill_required(level)==(level+1)*(level+4),"Quadratic XP level "+str(level))
		check(Stats.skill_progress(Stats.skill_start(level)).level==level,"Exact level boundary "+str(level))
	check(Stats.skill_progress(Stats.skill_start(100)).level==100 and Stats.skill_progress(2147483647).required==0,"Cap at 100 without XP overflow")
	var a=ControlledAuthority.new()
	check(is_equal_approx(a.bonus("plant"),.01) and is_equal_approx(a.action_duration("water"),2/1.01),"Lv.1 gives one percent speed")
	set_level(a,"woodcutting",5)
	a.state.food_effect={"item":"food_tomato_stew","expires_at":a.state.time+3600}
	check(is_equal_approx(a.bonus("wood"),.25),"Food twenty plus woodcutting five equals twenty five")
	check(a.bonus_sources("wood").size()==2 and a.bonus_sources("wood")[0].name=="番茄炖蔬菜","Attribute sources name real food and skill")
	set_level(a,"mining",6)
	check(is_equal_approx(a.critical_chance("mining",1,.05,.25),.15),"Gather critical linearly interpolates at plus five levels")
	set_level(a,"mining",11)
	check(is_equal_approx(a.critical_chance("mining",1,.05,.25),.25),"Gather cap at material requirement plus ten")
	set_level(a,"planting",6)
	check(is_equal_approx(a.critical_chance("planting",1,.1,.5),.3),"Crop critical linear midpoint")
	set_level(a,"planting",11)
	check(is_equal_approx(a.critical_chance("planting",1,.1,.5),.5),"Crop critical fifty percent cap")
	for resource in DB.all_resources():
		a=ControlledAuthority.new();a.state.map_id=resource.map;a.state.player_position=[resource.x,resource.get("y",0),resource.z]
		var item: String=resource.item
		var skill: String=Stats.work_skill("gather",item)
		var required:=3 if item in ["birch","iron","sandstone"] else 1
		var tool: String=DB.item(item).get("tool","")
		if tool!="": a.add(tool,1)
		if required==3:
			var rejected: Dictionary=command(a,"gather",resource.id)
			check(not rejected.ok and a.state.stamina==100 and a.job.is_empty(),"Level gate before reservation "+resource.id)
		set_level(a,skill,required)
		var before_xp: int=a.state.skill_experience[skill]
		check(command(a,"gather",resource.id).ok,"Unlock resource "+resource.id)
		check(a.state.stamina==100-Stats.work_tier(item),"Tiered stamina reservation "+resource.id)
		var result=finish(a)
		var amount:=3 if item=="orange" else 1
		check(a.count(item)==amount and result.amount==amount,"Exact base yield "+resource.id)
		check(str(result.message).contains(str(amount)),"Toast includes exact amount "+resource.id)
		check(a.state.skill_experience[skill]==before_xp+Stats.work_tier(item) and a.state.experience==Stats.work_tier(item),"Tiered skill and total XP "+resource.id)
		if item!="orange":
			a.state.resources[resource.id].available=true;a.forced_critical=true
			command(a,"gather",resource.id);result=finish(a)
			check(result.critical and result.amount==2 and a.count(item)==3,"Critical doubles one reward "+resource.id)
	for resource_id in ["valley_birch_0","valley_iron_0","valley_sandstone_0"]:
		var source:=DB.resource(resource_id)
		a=ControlledAuthority.new();a.state.map_id="valley";a.state.player_position=[source.x,source.y,source.z]
		set_level(a,Stats.work_skill("gather",source.item),3);a.add(DB.item(source.item).tool,1)
		a.state.stamina=1
		check(not command(a,"gather",resource_id).ok and a.job.is_empty() and a.state.stamina==1,"Tier-two requires two stamina before starting "+resource_id)
		a.state.stamina=2
		check(command(a,"gather",resource_id).ok and a.state.stamina==0,"Tier-two reserves exactly two "+resource_id)
		command(a,"cancel")
		check(a.state.stamina==2 and a.state.resources[resource_id].available,"Tier-two cancel refunds two "+resource_id)
		command(a,"gather",resource_id)
		var save_session=S.new();save_session.test_mode=true;save_session.authority=a;save_session.active_character_id="stamina_fixture";save_session.player_started=true
		save_session.sync_current()
		check(a.state.stamina==0 and save_session.characters.stamina_fixture.stamina==2,"Unfinished save refunds the actual two-point reservation "+resource_id)
		save_session.free()
		a.state.resources[resource_id].available=false
		a.state.resources[resource_id].respawn_at=a.state.time+3600
		finish(a)
		check(a.state.stamina==2 and a.count(source.item)==0,"Tier-two failed settlement refunds two without items "+resource_id)
	a=ControlledAuthority.new();a.state.player_position=[22,.1,-6];a.add("seed_pumpkin",1)
	check(not command(a,"plant","plot_00","seed_pumpkin").ok,"Pumpkin sowing locked at one")
	a.state.plots.plot_00={"crop":"pumpkin","growth":3600,"water_stage":-1,"weed_stage":-1,"quality":0}
	for verb in ["water","weed","harvest"]: check(not command(a,verb,"plot_00").ok,"Pumpkin care and harvest locked "+verb)
	a=ControlledAuthority.new();a.state.player_position=[22,.1,-6];a.add("seed_wheat",1)
	check(not command(a,"plant","plot_00","seed_wheat").ok,"Wheat requires level five")
	set_level(a,"planting",5);a.add("watering_can",1);a.add("herbicide",2);a.forced_critical=true
	check(command(a,"plant","plot_00","seed_wheat").ok,"Plant wheat at five")
	finish(a)
	for stage in range(4):
		var p: Dictionary=a.state.plots.plot_00
		check(a.needs(p).water,"Wheat water stage "+str(stage))
		check(a.needs(p).weed==(stage in [1,2]),"Wheat weeds only at twenty five and fifty percent "+str(stage))
		var growth: float=p.growth;a.tick(99999)
		check(is_equal_approx(growth,p.growth),"Large tick cannot cross care gate "+str(stage))
		check(command(a,"water","plot_00").ok,"Water wheat "+str(stage));finish(a)
		if stage in [1,2]: check(command(a,"weed","plot_00").ok,"Weed wheat "+str(stage));finish(a)
		a.tick(99999)
	check(DB.crop_quality_max("wheat")==7 and a.state.plots.plot_00.quality==7,"Wheat quality maximum derives from seven operations")
	check(a.needs(a.state.plots.plot_00).ready and a.crop_yield(a.state.plots.plot_00)==9,"Perfect wheat yields nine")
	var rolls_before: int=a.rolls
	command(a,"harvest","plot_00");var harvest=finish(a)
	check(a.count("wheat")==9 and harvest.amount==9 and a.rolls==rolls_before,"Harvest settles quality once without another roll")
	a=ControlledAuthority.new();a.state.player_position=[22,.1,-6];a.forced_critical=true
	var seed_before: int=a.count("seed_carrot");command(a,"plant","plot_00","seed_carrot");command(a,"cancel")
	check(a.rolls==0 and a.state.stamina==100 and a.count("seed_carrot")==seed_before,"Cancel never rolls or consumes seed or stamina")
	var fixture: Dictionary=DB.crop("carrot").duplicate(true);fixture["yield"]=3;fixture.care_stages=[]
	for i in range(5): fixture.care_stages.append({"water":true,"weed":i>0})
	DB.catalog().crops["quality_fixture"]=fixture
	check(DB.crop_quality_max("quality_fixture")==10 and a.crop_yield({"crop":"quality_fixture","quality":4})==4,"Future ten quality example rounds three times one point two to four")
	DB.catalog().crops.erase("quality_fixture")
	for map_id in ["city","valley"]:
		a=ControlledAuthority.new();a.state.map_id=map_id;a.state.stamina=90;a.add("orange",2)
		check(command(a,"snack","","orange").ok,"Eat orange on map "+map_id)
		a.tick(2.999);check(a.count("orange")==2 and a.state.stamina==90,"Orange waits three seconds "+map_id)
		command(a,"cancel");check(a.count("orange")==2,"Cancelled snack keeps orange "+map_id)
		command(a,"snack","","orange");finish(a)
		check(a.count("orange")==1 and a.state.stamina==93 and a.state.experience==0,"Orange restores three with no XP "+map_id)
		a.state.stamina=99;command(a,"snack","","orange");finish(a)
		check(a.state.stamina==100 and not command(a,"snack","","orange").ok,"Snack clamps to capacity "+map_id)
	for recipe_id in DB.catalog().recipes:
		a=ControlledAuthority.new();a.state.player_position=[21,.1,-20]
		var recipe:=DB.recipe(recipe_id)
		for item in recipe.ingredients: a.add(item,int(recipe.ingredients[item]))
		var required:=int(recipe.required_level)
		if required>1:
			var without_materials=ControlledAuthority.new();without_materials.state.player_position=[21,.1,-20]
			var locked: Dictionary=command(without_materials,"craft","kitchen",recipe_id)
			check(not locked.ok and str(locked.message).contains("需要烹饪") and without_materials.state.stamina==100,"Level error precedes missing ingredients "+recipe_id)
			check(not command(a,"craft","kitchen",recipe_id).ok,"Cooking recipe level locked "+recipe_id)
		set_level(a,"cooking",required)
		var before_xp: int=a.state.skill_experience.cooking
		check(command(a,"craft","kitchen",recipe_id).ok,"Cooking unlocked "+recipe_id)
		finish(a)
		check(a.count(recipe.output)==1 and a.state.skill_experience.cooking==before_xp+int(recipe.skill_experience),"Recipe XP and output "+recipe_id)
	a=ControlledAuthority.new();a.state.player_position=[27.8,.1,-18.5];a.state.stamina=40
	a.state.food_effect={"item":"food_rustic_wheat_bread","expires_at":a.state.time+3600};a.add("food_honey_wheat_cake",1)
	command(a,"eat","dining","food_honey_wheat_cake");finish(a)
	check(a.state.stamina==70 and a.state.food_effect.item=="food_rustic_wheat_bread","Recovery meal restores thirty and keeps active running buff")
	check(is_equal_approx(a.bonus("run_speed"),.2) and is_zero_approx(a.bonus("move")),"Run bonus is independent of walk speed")
	a.state.food_effect={"item":"food_vegetable_omelette","expires_at":a.state.time+3600}
	check(is_equal_approx(a.bonus("stone"),.26) and is_equal_approx(a.bonus("mining"),.01),"Quarry-only food does not affect mining")
	a.add("food_pumpkin_soup",1);command(a,"eat","dining","food_pumpkin_soup");finish(a)
	check(a.stamina_max()==120 and is_zero_approx(a.bonus("plant")-.01),"Pumpkin soup now increases capacity instead of farm speed")
	var session=S.new();session.test_mode=true
	a.state.stamina=115
	var capacity_save=session.restore_state(a.state)
	check(capacity_save.stamina_max()==120 and capacity_save.state.stamina==115,"Capacity meal restores before saved stamina is clamped")
	var legacy: Dictionary=a.state.duplicate(true);legacy.erase("skill_rules_version");legacy.skill_experience.planting=900;legacy.skills.planting=20;legacy.coins=827
	legacy.plots.plot_00={"crop":"wheat","growth":6000,"water_stage":2,"weed_stage":2,"quality":4}
	var migrated=session.restore_state(legacy)
	check(migrated.state.skills.values().all(func(x): return x==1) and migrated.state.skill_experience.values().all(func(x): return x==0),"All old skill progress resets once")
	check(migrated.state.coins==827 and migrated.state.plots.plot_00.quality==4 and migrated.state.inventory==legacy.inventory,"Reset preserves money inventory and crop quality")
	set_level(migrated,"planting",5)
	var reloaded=session.restore_state(migrated.state)
	check(reloaded.skill_level("planting")==5 and reloaded.state.skill_rules_version==Stats.PROGRESSION_VERSION,"New save marker prevents repeated reset")
	session.free()
	check(DB.starter_clothes().size()==9 and not DB.starter_clothes().has("bow_plaid_rose"),"New shop bows do not silently enlarge starter gifts")
	check(DB.catalog().recipes.size()==7 and DB.catalog().crops.size()==5,"Five crops and seven dishes available")
	print("SKILLS_QUALITY_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
