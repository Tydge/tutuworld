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
	check(a.state.experience==0 and a.state.stamina==100,"Fresh experience and full stamina")
	a.running=true
	a.tick(29.9)
	check(a.state.stamina==91,"Running consumes nine points in the first 29.9 seconds")
	a.tick(.1)
	check(a.state.stamina==91,"Thirty real seconds consume ten points and naturally recover one")
	a.running=false
	a.tick(15)
	check(a.state.stamina==91,"Fifteen real seconds preserve a partial recovery interval")
	a.tick(15)
	check(a.state.stamina==92,"Thirty real seconds recover one point")
	a.state.attributes.stamina_capacity=.5
	check(a.stamina_max()==150,"Capacity bonus applies independently")
	a.state.attributes.stamina_regen=1.0
	a.state.stamina=0
	a.state.stamina_recovery_elapsed=0
	a.tick(15)
	check(a.state.stamina==1,"Recovery +100% restores one point in fifteen seconds")
	a.state.attributes.move=1
	a.state.attributes.water=1
	check(a.multiplier("move")==2 and is_equal_approx(a.action_duration("water"),2.0/2.01),"Percent stats affect speed without UI formulas")
	a.state.food_effect={"item":"food_carrot_soup","expires_at":a.state.time+3600}
	check(is_equal_approx(a.multiplier("move"),2.15),"Food and attributes aggregate consistently")
	var clothes:=0
	for id in DB.catalog().items:
		if DB.item(id).kind=="clothing": clothes+=1
	check(clothes>=27 and not DB.item("vest_stripes_sage").is_empty() and not DB.item("apron_daisies_sage").is_empty(),"Shared catalog includes existing and newly registered clothes")
	for color in ["rose","sage","honey"]:
		check(DB.item("beret_plaid_"+color).pattern=="tartan" and DB.item("apron_"+color).pattern=="sprig","Pattern references are independent of color: "+color)
	# Every successful work completes once; aborted / rejected / duplicate requests do not grant XP.
	a=A.new()
	a.state.player_position=[22,.1,-6]
	var command: Dictionary={"id":"xp-seed","verb":"plant","target":"plot_00","item":"seed_carrot"}
	a.execute(command)
	a.tick(1)
	check(a.state.experience==0,"No XP before completion")
	a.execute({"verb":"cancel"})
	check(a.state.experience==0,"Cancelled work grants no XP")
	a.execute({"verb":"plant","target":"plot_00","item":"seed_carrot"})
	a.tick(2)
	check(a.state.experience==1,"Planting grants one XP")
	a.execute(command)
	check(a.state.experience==1 and a.job.is_empty(),"Repeated command cannot award twice")
	a.add("watering_can",1);a.state.watering_water.watering_can=6
	a.execute({"verb":"water","target":"plot_00"}); a.tick(2)
	check(a.state.experience==2,"Watering grants one XP")
	a.state.plots.plot_00.growth=1200
	a.state.plots.plot_00.water_stage=1
	a.add("herbicide",1)
	a.execute({"verb":"weed","target":"plot_00"}); a.tick(2)
	check(a.state.experience==3,"Weeding grants one XP")
	a.state.plots.plot_00.growth=3600
	a.execute({"verb":"harvest","target":"plot_00"}); a.tick(2)
	check(a.state.experience==4,"Harvest grants one XP")
	for r in DB.resources().slice(0,3):
		a.state.player_position=[r.x,.1,r.z]
		var tool: String=DB.item(r.item).get("tool","")
		if tool!="": a.add(tool,1)
		a.execute({"verb":"gather","target":r.id}); a.tick(2)
	check(a.state.experience==7,"Stone, ore and branch each grant one XP")
	a.state.player_position=[21,.1,-20]
	a.add("carrot",2); a.add("sea_salt",1)
	a.execute({"verb":"craft","target":"kitchen","recipe":"carrot_soup"}); a.tick(5)
	check(a.state.experience==10,"Cooking grants three XP")
	a.state.player_position=[27.8,.1,-18.5]
	a.execute({"verb":"eat","target":"dining","item":"food_carrot_soup"}); a.tick(6)
	check(a.state.experience==10,"Eating does not masquerade as work")
	check(a.state.skills.values().all(func(level): return level==1) and a.state.skill_experience.planting==4 and a.state.skill_experience.cooking==3,"Successful work accumulates corresponding skill XP")
	print("PROGRESSION_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
