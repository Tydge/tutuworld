extends SceneTree
const Authority=preload("res://scripts/services/local_authority.gd")
const DB=preload("res://scripts/services/game_data.gd")
var failures: Array[String]=[]
var checks := 0
func check(value: bool,label_: String) -> void:
	checks+=1
	if not value: failures.append(label_); push_error(label_)
	else: print("PASS ",label_)
func act(a,verb: String,target: String="",item: String="") -> Dictionary:
	return a.execute({"verb":verb,"target":target,"item":item})
func _initialize() -> void:
	var a=Authority.new()
	check(DB.catalog().crops.size()==5,"Five crop types")
	var clothes:=0
	for id in DB.catalog().items:
		if DB.item(id).kind=="clothing": clothes+=1
	check(clothes==27,"Twenty-seven clothing items across three slots")
	check(a.state.plots.size()==48,"48 independent plots")
	a.state.player_position=[22,.1,-6]
	var seed_before: int=a.count("seed_carrot")
	check(act(a,"plant","plot_00","seed_carrot").ok,"Plant starts")
	a.tick(1.9)
	check(a.state.plots.plot_00.crop=="" and a.count("seed_carrot")==seed_before,"Plant takes full two seconds before charging seed")
	check(not act(a,"gather","resource_02").ok,"Concurrent actions are blocked")
	act(a,"cancel")
	check(a.count("seed_carrot")==seed_before,"Cancelled planting consumes nothing")
	act(a,"plant","plot_00","seed_carrot")
	a.tick(2.01)
	check(a.count("seed_carrot")==seed_before-1,"Successful planting consumes exactly one seed")
	check(a.needs(a.state.plots.plot_00).water,"New crop needs water")
	a.tick(3600)
	check(a.state.plots.plot_00.growth==0,"Dry crop does not grow")
	check(not act(a,"water","plot_00").ok,"Watering requires permanent watering can")
	a.add("watering_can",1)
	check(act(a,"water","plot_00").ok,"Owned watering can enables action")
	a.tick(2.01)
	check(a.count("watering_can")==1,"Watering does not consume the tool")
	a.tick(1300)
	var p: Dictionary=a.state.plots.plot_00
	check(a.needs(p).water and a.needs(p).weed,"Care gates stop growth at one third")
	var growth: float=p.growth
	a.tick(10000)
	check(is_equal_approx(p.growth,growth),"Neglected crop remains paused")
	check(not act(a,"weed","plot_00").ok,"Weeding requires herbicide")
	a.add("herbicide",4)
	act(a,"weed","plot_00")
	a.tick(1)
	act(a,"cancel")
	check(a.count("herbicide")==4,"Cancelled weeding does not consume herbicide")
	act(a,"weed","plot_00")
	a.tick(2.01)
	check(a.count("herbicide")==3,"Successful weeding consumes one bottle")
	act(a,"water","plot_00")
	a.tick(2.01)
	a.tick(1201)
	check(a.needs(p).water and a.needs(p).weed,"Second care gate is reached")
	act(a,"weed","plot_00"); a.tick(2.01)
	act(a,"water","plot_00"); a.tick(2.01)
	a.tick(1201)
	check(a.needs(p).ready,"Crop matures after cumulative one game day of growth")
	var expected_yield: int=a.crop_yield(p)
	act(a,"harvest","plot_00")
	a.tick(1.95)
	check(a.count("carrot")==0,"Harvest requires two seconds")
	a.tick(.1)
	check(a.count("carrot")==expected_yield and a.state.plots.plot_00.crop=="","Harvest yields inventory and clears soil")
	a.state.player_position=[DB.resources()[0].x,.1,DB.resources()[0].z]
	check(not act(a,"gather","resource_00").ok,"Stone gathering requires stone hammer")
	a.state.player_position=[DB.resources()[1].x,.1,DB.resources()[1].z]
	check(not act(a,"gather","resource_01").ok,"Ore gathering requires mining pickaxe")
	for pair in [["resource_00","stone_hammer","limestone"],["resource_01","pickaxe","copper"],["resource_02","","branch"]]:
		for resource in DB.resources():
			if resource.id==pair[0]: a.state.player_position=[resource.x,.1,resource.z]
		if pair[1]!="": a.add(pair[1],1)
		check(act(a,"gather",pair[0]).ok,"Gather starts "+pair[2])
		a.tick(1.9)
		check(a.count(pair[2])==0,"Gather waits two seconds "+pair[2])
		a.tick(.11)
		check(a.count(pair[2])>0 and not a.state.resources[pair[0]].available,"Gather grants item and depletes resource "+pair[2])
		if pair[1]!="": check(a.count(pair[1])==1,"Gather tool remains in inventory "+pair[1])
	a.state.player_position=[DB.resources()[0].x,.1,DB.resources()[0].z]
	check(not act(a,"gather","resource_00").ok,"Depleted resource cannot be gathered twice")
	a.tick(maxf(0,float(a.state.resources.resource_00.respawn_at)-float(a.state.time))+.01)
	check(a.state.resources.resource_00.available,"Resources respawn after cooldown")
	a.state.player_position=[DB.shops().farm.x,.18,DB.shops().farm.y+2.0]
	var money: int=a.state.coins
	var buy: Dictionary={"id":"same-request","verb":"buy","item":"seed_carrot","shop":"farm"}
	check(a.execute(buy).ok,"Seed purchase")
	a.execute(buy)
	check(a.state.coins==money-10,"Repeated command ID cannot double-charge")
	a.state.player_position=[DB.shops().tools.x,.18,DB.shops().tools.y+2.0]
	check(not a.execute({"verb":"buy","item":"pickaxe","shop":"tools"}).ok,"Permanent tool cannot be bought twice")
	a.state.player_position=[DB.shops().farm.x,.18,DB.shops().farm.y+2.0]
	check(not a.execute({"verb":"sell","item":"pickaxe","shop":"farm"}).ok,"Permanent tool cannot be sold accidentally")
	check(not a.execute({"verb":"buy","item":"seed_carrot","shop":"farm","quantity":-10}).ok,"Negative purchase quantity is rejected")
	check(a.execute({"verb":"sell","item":"carrot","shop":"farm","quantity":a.count("carrot")}).ok and a.count("carrot")==0,"Harvest can be sold for coins")
	a.add("bow_rose",1); a.add("beret_sage",1); a.add("vest_sage",1)
	check(a.execute({"verb":"equip","item":"bow_rose","slot":"head"}).ok,"Head accessory can be equipped")
	a.execute({"verb":"equip","item":"beret_sage","slot":"head"})
	check(a.state.equipment.head=="beret_sage" and a.count("bow_rose")==1,"Same-slot clothing replaces prior item without losing it")
	check(not a.execute({"verb":"equip","item":"vest_sage","slot":"head"}).ok,"Clothing rejects wrong slot")
	a.execute({"verb":"equip","item":"vest_sage","slot":"body"})
	check(a.state.equipment.head=="beret_sage" and a.state.equipment.body=="vest_sage","Head and body slots are independent")
	for crop in DB.catalog().crops:
		check(float(DB.crop(crop).days)>=1 and float(DB.crop(crop).days)<=3,"Crop duration range "+crop)
	var before: float=a.state.time
	a.tick(3600)
	check(is_equal_approx(a.state.time-before,3600),"One real hour advances exactly one game day")
	a.state.player_position=[0,.1,9]
	check(not a.execute({"verb":"buy","item":"seed_carrot","shop":"farm"}).ok,"Cannot trade remotely outside a shop")
	check(not act(a,"plant","plot_01","seed_carrot").ok,"Cannot plant across the island")
	check(not a.execute({"verb":"cancel","protocol":99}).ok,"Incompatible command protocol is rejected")
	print("CITY_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
