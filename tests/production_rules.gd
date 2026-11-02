extends SceneTree
const A=preload("res://scripts/services/local_authority.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Stats=preload("res://scripts/services/character_stats.gd")
const S=preload("res://scripts/services/session.gd")
class FailingSession extends S:
	var fail_write:=false
	func save_game() -> bool: return false if fail_write else super.save_game()
var checks:=0
var failures: Array=[]
func check(ok: bool,label_: String) -> void:
	checks+=1
	if not ok: failures.append(label_);print("FAIL ",label_)
func command(a,verb: String,target: String="",recipe: String="",id: String="") -> Dictionary:
	return a.execute({"verb":verb,"target":target,"recipe":recipe,"id":id})
func place(a,target: String) -> void:
	var point: Vector2=a.facility_position(target);a.state.player_position=[point.x,.2,point.y]
func finish(a) -> Dictionary:
	if a.job.is_empty(): return {}
	var events: Array=a.tick(float(a.job.duration)-float(a.job.elapsed)+.00001)
	return events[-1] if not events.is_empty() else {}
func water_crop(a,index: int) -> Dictionary:
	var plot: Dictionary=DB.plots()[index]
	a.state.player_position=[plot.x,.2,plot.z]
	a.state.plots[plot.id]=a.empty_plot();a.state.plots[plot.id].crop="carrot"
	return command(a,"water",plot.id)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var a=A.new()
	check(a.skill_level("manufacturing")==1 and a.state.skill_experience.manufacturing==0 and is_equal_approx(a.multiplier("manufacture"),1.01),"Manufacturing begins at Lv.1, zero XP, one percent speed")
	check(DB.water_capacity("watering_can")==6 and DB.water_capacity("copper_watering_can")==12,"Wood and copper capacities are six and twelve")
	check(DB.recipes_for_station("workshop").size()==2 and DB.recipes_for_station("kitchen").size()==7,"Two manufacturing recipes leave seven cooking recipes intact")
	check(not command(a,"refill","garden_well").ok and a.job.is_empty(),"No remote refill")
	place(a,"garden_well")
	check(not command(a,"refill","garden_well").ok,"Cannot refill without a can")
	a.add("watering_can",1)
	check(a.water_left()==0 and not water_crop(a,0).ok and a.state.stamina==100,"A newly owned empty can cannot water or spend stamina")
	place(a,"garden_well");a.state.attributes.water=5
	check(command(a,"refill","garden_well").ok and a.job.duration==2.0 and a.state.stamina==100,"Refill is exactly two real seconds, unmodified by watering speed and free of production stamina")
	a.tick(1.99);check(a.water_left()==0,"Partial refill does not grant water")
	command(a,"cancel");check(a.water_left()==0 and a.state.experience==0,"Cancelled refill grants no water or XP")
	command(a,"refill","garden_well");finish(a)
	check(a.water_left()==6 and a.state.experience==0 and a.state.stamina==100,"Completed refill fills six without XP or stamina charge")
	check(not command(a,"refill","garden_well").ok,"Full can rejects another refill")
	check(water_crop(a,0).ok and a.water_left()==6,"Water is charged only at successful completion")
	command(a,"cancel");check(a.water_left()==6 and a.state.stamina==100,"Water cancellation refunds stamina and preserves water")
	for index in range(6):
		check(water_crop(a,index).ok,"One wooden fill permits watering "+str(index+1))
		finish(a)
		check(a.water_left()==5-index,"Each successful watering consumes exactly one charge")
	var stamina: float=a.state.stamina
	check(not water_crop(a,6).ok and a.state.stamina==stamina and a.count("watering_can")==1,"Seventh watering fails without consuming tool or stamina")
	a=A.new();a.add("copper",30);a.add("branch",20)
	place(a,"kitchen")
	check(not command(a,"craft","kitchen","copper_watering_can").ok,"Manufacturing cannot run at the kitchen")
	place(a,"workshop_bench")
	check(not command(a,"craft","workshop_bench","carrot_soup").ok,"Cooking cannot run at the workshop")
	var recipe: Dictionary=DB.recipe("copper_watering_can");recipe.required_level=2
	check(not command(a,"craft","workshop_bench","copper_watering_can").ok and a.state.stamina==100,"Recipe level unlock checked before reserving stamina")
	recipe.required_level=1
	check(command(a,"craft","workshop_bench","copper_watering_can").ok and is_equal_approx(a.job.duration,10/1.01),"Copper can uses base ten seconds and manufacturing speed")
	a.tick(4);check(a.count("copper")==30 and a.count("copper_watering_can")==0,"Manufacturing charges no materials before completion")
	command(a,"cancel");check(a.count("copper")==30 and a.state.stamina==100 and a.state.skill_experience.manufacturing==0,"Manufacturing cancellation refunds stamina without materials or XP")
	command(a,"craft","workshop_bench","copper_watering_can","make-can");var event:=finish(a)
	check(a.count("copper")==20 and a.count("copper_watering_can")==1 and event.amount==1,"Copper can consumes exactly ten copper and yields one tool")
	check(a.state.skill_experience.manufacturing==5 and a.state.skill_experience.cooking==0 and a.state.experience==5,"Can grants five manufacturing and total XP, no cooking XP")
	check(a.watering_can_id()=="copper_watering_can" and a.water_left()==0,"Copper upgrade is selected automatically and starts empty")
	command(a,"craft","workshop_bench","copper_watering_can","make-can")
	check(a.job.is_empty() and a.count("copper")==20,"Retrying the same request does not duplicate manufacturing")
	check(not command(a,"craft","workshop_bench","copper_watering_can").ok,"Unique tool cannot be manufactured twice")
	place(a,"garden_well");command(a,"refill","garden_well");finish(a)
	check(a.water_left()==12,"Copper refill fills twelve charges")
	for index in range(12):
		check(water_crop(a,index).ok,"Copper charge "+str(index+1));finish(a)
	check(a.water_left()==0 and not water_crop(a,12).ok,"Exactly twelve successful copper waterings, then empty")
	place(a,"workshop_bench")
	check(command(a,"craft","workshop_bench","copper_axe").ok,"Lv.1 can manufacture copper axe")
	event=finish(a)
	check(a.count("copper")==12 and a.count("branch")==12 and a.count("copper_axe")==1 and event.skill_experience==5,"Copper axe consumes eight copper and eight branches, gives five XP")
	check(a.skill_level("manufacturing")==2 and is_equal_approx(a.multiplier("manufacture"),1.02),"Ten manufacturing XP unlocks Lv.2 and two percent speed")
	check(a.resource_lock_reason("birch")!="","Manufacturing axe does not bypass its existing woodcutting use requirement")
	a=A.new();place(a,"workshop_bench");a.add("copper",10)
	command(a,"craft","workshop_bench","copper_watering_can");a.add("copper",-1);event=finish(a)
	check(event.type=="rejected" and a.count("copper")==9 and a.count("copper_watering_can")==0 and a.state.stamina==100,"Changed ingredients reject completion, refund stamina and give no tool")
	a.add("copper",1);command(a,"craft","workshop_bench","copper_watering_can");a.facility_positions.workshop_bench=Vector2(10,10);event=finish(a)
	check(event.type=="rejected" and a.count("copper")==10 and a.state.experience==0,"Moving the workbench away rejects completion without cost")
	check(not command(a,"craft","workshop_bench","copper_watering_can").ok,"Old position cannot use moved workbench")
	place(a,"workshop_bench");check(command(a,"craft","workshop_bench","copper_watering_can").ok,"Moved workbench uses its new authoritative anchor")
	command(a,"cancel")
	a.add("watering_can",1);place(a,"garden_well");command(a,"refill","garden_well");a.state.player_position=[0,.1,9];event=finish(a)
	check(event.type=="rejected" and a.water_left()==0,"Leaving the well before completion gives no water")
	a.state.map_id="valley";place(a,"garden_well")
	check(not command(a,"refill","garden_well").ok and not command(a,"craft","workshop_bench","copper_watering_can").ok,"City stations cannot be used from the valley")
	var session=S.new();session.test_mode=true
	var raw: Dictionary=A.new().state.duplicate(true);raw.skill_experience.mining=35;raw.inventory.watering_can=1;raw.erase("watering_water");raw.skill_experience.erase("manufacturing");raw.skills.erase("manufacturing")
	var restored=session.restore_state(raw)
	check(restored.skill_level("mining")==3 and restored.skill_level("manufacturing")==1 and restored.water_left()==0,"Old saves preserve earned skills and gain empty can / new Lv.1 skill")
	raw.watering_water={"watering_can":999,"copper_watering_can":12};restored=session.restore_state(raw)
	check(restored.water_left()==6 and not restored.state.watering_water.has("copper_watering_can"),"Loaded water is clamped and unowned cans cannot store water")
	session.create_character("水量测试兔","bunny","bow_rose");var first: String=session.active_character_id
	session.authority.add("watering_can",1);session.state().watering_water.watering_can=4;session.state().skill_experience.manufacturing=5
	session.create_character("水量测试猫","cat_teacher","bow_rose")
	check(session.authority.water_left()==0 and session.state().skill_experience.manufacturing==0,"Water and manufacturing XP are per character")
	session.select_character(first)
	check(session.authority.water_left()==4 and session.state().skill_experience.manufacturing==5,"Character switch preserves exact water and manufacturing XP")
	var local_save:=ProjectSettings.globalize_path("res://.qa-artifacts/production-save/progress.json")
	DirAccess.make_dir_recursive_absolute(local_save.get_base_dir());session.save_path=local_save;session.test_mode=false
	check(session.save_game(),"Local production fields save to isolated disk state")
	var disk=S.new();disk.save_path=local_save;disk.load_save()
	check(disk.authority.water_left()==4 and disk.state().skill_experience.manufacturing==5,"Disk restart preserves exact local water and manufacturing XP")
	disk.free();session.test_mode=true;session.free()
	for verb in ["refill","water","craft"]:
		var failing=FailingSession.new();failing.test_mode=true;failing.create_character("写入测试","bunny","bow_rose");failing.active=true
		var actor=failing.authority;actor.add("watering_can",1);actor.state.watering_water.watering_can=3
		if verb=="craft": actor.add("copper",10);place(actor,"workshop_bench");command(actor,verb,"workshop_bench","copper_watering_can")
		elif verb=="refill": place(actor,"garden_well");command(actor,verb,"garden_well")
		else: water_crop(actor,0)
		failing.fail_write=true;failing._process(actor.job.duration+.01)
		check(actor.job.is_empty() and actor.state.stamina==100 and actor.water_left()==3 and actor.state.experience==0 and actor.count("copper_watering_can")==0,"Failed local completion save rolls back water, materials, XP and stamina: "+verb)
		if verb=="craft": check(actor.count("copper")==10,"Failed craft commit preserves all ten copper")
		failing.free()
	print("PRODUCTION_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
