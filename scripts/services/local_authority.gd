extends RefCounted
const Animals=preload("res://scripts/characters/animal_catalog.gd")
## All economic and world mutations live behind execute(). Remote authority can
## use the same command / snapshot schema without giving UI write access.
const Stats=preload("res://scripts/services/character_stats.gd")
const Valley=preload("res://scripts/valley/valley_layout.gd")
const DB = preload("res://scripts/services/game_data.gd")
const DAY_SECONDS := 3600.0
const ACTION_SECONDS := 2.0
var state: Dictionary
var job: Dictionary = {}
var seen_commands: Dictionary = {}
var revision := 0
var running:=false
var sleeping:=false
var reward_random := RandomNumberGenerator.new()
const RUN_POINT_SECONDS:=3.0
const RECOVERY_POINT_SECONDS:=30.0

func _init() -> void:
	reward_random.randomize()
	state = {"schema":2,"player_id":"local_bunny","character_name":"兔兔","species":"bunny","map_id":"city","world_id":"peace_island_v1","time":DAY_SECONDS/3,"coins":650,"inventory":{"seed_carrot":3,"seed_lettuce":3,"seed_tomato":2,"seed_pumpkin":2},"equipment":{"head":"","body":"","neck":""},"plots":{},"resources":{},"player_position":[0,.1,9],"revision":0,"food_effect":{},"experience":0,"stamina":100.0,"attributes":Stats.defaults(),"skills":Stats.skill_defaults(),"skill_experience":Stats.skill_xp_defaults()}
	for p in DB.plots(): state.plots[p.id] = empty_plot()
	for r in DB.all_resources(): state.resources[r.id] = {"available":true,"respawn_at":0.0,"generation":0}
	state.stamina_run_elapsed=0.0
	state.stamina_recovery_elapsed=0.0
	state.rest_mode=""
	state.rest_bed=""
	state.skill_rules_version=Stats.PROGRESSION_VERSION

func empty_plot() -> Dictionary:
	return {"crop":"","growth":0.0,"water_stage":-1,"weed_stage":-1,"quality":0}
func actor_name() -> String:
	var name_: String=str(state.get("character_name","")).strip_edges()
	return name_ if name_!="" else Animals.display_name(str(state.get("species","bunny")))
func count(id: String) -> int: return int(state.inventory.get(id,0))
func add(id: String, amount: int) -> void:
	state.inventory[id] = maxi(0,count(id)+amount)
	if state.inventory[id]==0: state.inventory.erase(id)
func needs(plot: Dictionary) -> Dictionary:
	if plot.crop=="": return {"water":false,"weed":false,"ready":false}
	var ratio := float(plot.growth)/(float(DB.crop(plot.crop).days)*DAY_SECONDS)
	var stages := DB.care_stages(plot.crop)
	var index := mini(stages.size()-1,int(floor(ratio*stages.size()+.00001)))
	return {"water":ratio<1 and stages[index].get("water",false) and int(plot.water_stage)<index,"weed":ratio<1 and stages[index].get("weed",false) and int(plot.weed_stage)<index,"ready":ratio>=1}
func skill_level(id: String) -> int:
	return int(Stats.skill_progress(int(state.get("skill_experience",{}).get(id,0))).level)
func bonus_sources(kind: String) -> Array:
	var sources: Array=[]
	var base := float(state.get("attributes",{}).get(kind,0))
	if not is_zero_approx(base): sources.append({"name":"基础属性","value":base})
	for id in state.equipment.values():
		var value := float(DB.item(id).get("attributes",{}).get(kind,0))
		if not is_zero_approx(value): sources.append({"name":DB.item(id).name,"value":value})
	var effect: Dictionary=state.get("food_effect",{})
	if not effect.is_empty() and float(effect.get("expires_at",0))>float(state.time):
		var food := DB.item(str(effect.get("item","")))
		var modifiers: Dictionary=food.get("effect",{})
		var value := float(modifiers.get(kind,modifiers.get(Stats.food_key(kind),0)))
		if not is_zero_approx(value): sources.append({"name":food.name,"value":value})
	var skill := Stats.attribute_skill(kind)
	if skill!="": sources.append({"name":Stats.skill_name(skill).replace("技能","等级"),"value":skill_level(skill)*.01})
	return sources
func bonus(kind: String) -> float:
	var value := 0.0
	for source in bonus_sources(kind): value+=float(source.value)
	return value
func crop_lock_reason(id: String) -> String:
	var required := int(DB.crop(id).get("required_level",1))
	return "需要种植 Lv.%d"%required if skill_level("planting")<required else ""
func resource_required(id: String) -> int:
	var item := DB.item(id)
	return maxi(int(item.get("required_level",1)),int(DB.item(str(item.get("tool",""))).get("required_level",1)))
func resource_lock_reason(id: String) -> String:
	var skill := Stats.work_skill("gather",id)
	var required := resource_required(id)
	return "需要%s Lv.%d"%[Stats.skill_name(skill).replace("技能",""),required] if skill_level(skill)<required else ""
func recipe_lock_reason(id: String) -> String:
	var required := int(DB.recipe(id).get("required_level",1))
	return "需要烹饪 Lv.%d"%required if skill_level("cooking")<required else ""
func critical_chance(skill: String,required: int,minimum: float,maximum: float) -> float:
	return lerpf(minimum,maximum,clampf((skill_level(skill)-required)/10.0,0,1))
func roll_critical(chance: float) -> bool:
	return reward_random.randf()<chance
func crop_yield(plot: Dictionary) -> int:
	var definition := DB.crop(plot.crop)
	var quality := clampi(int(plot.get("quality",0)),0,DB.crop_quality_max(plot.crop))
	return roundi(int(definition.get("yield",3))*(1.0+.5*quality/float(DB.crop_quality_max(plot.crop))))
func multiplier(kind: String) -> float: return maxf(.2,1.0+bonus(kind))
func stamina_max() -> float: return maxf(1,floor(100.0*multiplier("stamina_capacity")))
func tick_stamina(delta: float) -> void:
	if delta<=0: return
	state.stamina=clampf(floor(float(state.stamina)+.000001),0,stamina_max())
	if running and state.stamina>0:
		var elapsed: float=float(state.get("stamina_run_elapsed",0))+delta
		var points:=int(floor((elapsed+.0000001)/RUN_POINT_SECONDS))
		state.stamina=maxf(0,state.stamina-points)
		state.stamina_run_elapsed=maxf(0,elapsed-points*RUN_POINT_SECONDS)
	# Natural recovery uses real elapsed seconds, including while moving.
	if state.stamina<stamina_max():
		var elapsed: float=float(state.get("stamina_recovery_elapsed",0))+delta*multiplier("stamina_regen")*(2.0 if sleeping else 1.0)
		var points:=int(floor((elapsed+.0000001)/RECOVERY_POINT_SECONDS))
		state.stamina=minf(stamina_max(),state.stamina+points)
		state.stamina_recovery_elapsed=maxf(0,elapsed-points*RECOVERY_POINT_SECONDS) if state.stamina<stamina_max() else 0.0
	else: state.stamina_recovery_elapsed=0.0
func reserve_work_stamina(cost: int=1) -> bool:
	if state.stamina<cost: return false
	state.stamina-=cost
	return true
func reserved_work_stamina(work: Dictionary) -> int:
	return int(work.get("stamina_cost",1)) if work.get("stamina_reserved",false) else 0
func refund_work_stamina(work: Dictionary) -> void:
	state.stamina=minf(stamina_max(),float(state.stamina)+reserved_work_stamina(work))
func rejected_work(work: Dictionary,message: String) -> Dictionary:
	refund_work_stamina(work)
	return {"type":"rejected","message":message}
func action_duration(verb: String,item: String="") -> float:
	var kind: String=verb if verb in ["water","plant","weed","harvest"] else ({"limestone":"stone","copper":"mining","branch":"wood","orange":"harvest","birch":"wood","iron":"mining","sandstone":"stone"}.get(item,"") if verb=="gather" else "")
	return (5.0 if item in ["birch","iron","sandstone"] else ACTION_SECONDS)/multiplier(kind)
func fail(message: String) -> Dictionary: return {"ok":false,"message":message,"revision":revision}
func execute(command: Dictionary) -> Dictionary:
	var token: String = command.get("id","")
	if token!="" and seen_commands.has(token): return seen_commands[token].duplicate(true)
	if int(command.get("protocol",1))!=1 or command.get("player_id",state.player_id)!=state.player_id: return fail("会话协议或角色身份不匹配。")
	var result := _apply(command)
	if result.ok:
		revision += 1
		state.revision = revision
		result.revision = revision
		if token!="": seen_commands[token] = result.duplicate(true)
		if seen_commands.size()>512: seen_commands.erase(seen_commands.keys()[0])
	return result
func _apply(c: Dictionary) -> Dictionary:
	var verb: String = c.get("verb","")
	var item: String = c.get("item","")
	var map_id: String=state.get("map_id","city")
	if verb=="travel":
		if not job.is_empty() or state.get("rest_mode","")!="": return fail("先完成手上的事情，再坐船吧。")
		var destination: String=c.get("destination","")
		if destination!=("valley" if map_id=="city" else "city") or not near_position(Valley.dock(map_id),3.6): return fail("请来到码头，再和小船一起出发。")
		var fare:=10 if map_id=="city" else 0
		if state.coins<fare: return fail("船票需要 10 贝壳币。")
		state.coins-=fare;state.map_id=destination;state.player_position=Valley.arrival(destination)
		return {"ok":true,"message":"出发，去听山谷的风。" if destination=="valley" else "海岛城，我们回来啦。"}
	if map_id!="city" and verb in ["buy","sell","plant","water","weed","harvest","craft","eat","rest"]: return fail("这件事要回海岛城才能做哦。")
	var definition := DB.item(item)
	var quantity := int(c.get("quantity",1))
	if verb in ["buy","sell"]:
		var shop: String=c.get("shop","")
		if not DB.shops().has(shop) or not near_position(DB.shops()[shop],4.8): return fail("请先来到对应商店，再进行交易。")
		if quantity<1 or quantity>99 or definition.is_empty(): return fail("物品或数量不正确。")
		if not job.is_empty(): return fail("先完成手上的事情吧。")
		if verb=="buy":
			if not definition.has("price") or definition.get("shop","")!=c.get("shop",""): return fail("这家店没有这件物品。")
			if definition.kind in ["tool","clothing"] and (count(item)>0 or quantity!=1): return fail("这件已经拥有啦。")
			var cost := int(definition.price)*quantity
			if state.coins<cost: return fail("贝壳币还不够。")
			state.coins -= cost
			add(item,quantity)
			return {"ok":true,"message":"买到了 %s × %d"%[definition.name,quantity]}
		if c.get("shop","")!="farm" or int(definition.get("sell",0))<=0 or count(item)<quantity: return fail("这件物品暂时不能卖出。")
		add(item,-quantity)
		state.coins += int(definition.sell)*quantity
		return {"ok":true,"message":"卖出 %s，获得 %d 贝壳币。"%[definition.name,int(definition.sell)*quantity]}
	if verb=="equip":
		var slot: String = c.get("slot","")
		if slot not in ["head","body","neck"]: return fail("装饰位置不正确。")
		if item!="" and (count(item)<1 or definition.get("slot","")!=slot): return fail("背包中没有这件装饰。")
		state.equipment[slot] = item
		return {"ok":true,"message":"换好啦。"}
	if verb=="cancel":
		refund_work_stamina(job)
		job.clear()
		return {"ok":true,"message":"动作已取消，物品没有消耗。"}
	if verb=="wake":
		state.rest_mode="";state.rest_bed="";sleeping=false
		return {"ok":true,"message":""}
	if verb=="rest":
		if not job.is_empty() or c.get("target","")!="home_bed" or not near_position(DB.facilities().home_bed,3.4): return fail("先来到床边，再好好睡一觉吧。")
		state.rest_mode="sleep";state.rest_bed="home_bed";sleeping=true;running=false
		return {"ok":true,"message":""}
	if state.get("rest_mode","")=="sleep": return fail("先起床，伸个懒腰吧。")
	if not job.is_empty(): return fail("%s一次只能认真做一件事情。"%actor_name())
	var target: String = c.get("target","")
	if verb=="craft":
		var recipe_id: String=c.get("recipe","")
		var recipe:=DB.recipe(recipe_id)
		if target!="kitchen" or recipe.is_empty() or recipe.station!="kitchen" or not near_position(DB.facilities().kitchen,3.8): return fail("请来到海风小厨房的料理台。")
		var locked := recipe_lock_reason(recipe_id)
		if locked!="": return fail(locked)
		for ingredient in recipe.ingredients:
			if count(ingredient)<int(recipe.ingredients[ingredient]): return fail("还缺少%s。"%DB.item(ingredient).name)
		if not reserve_work_stamina(): return fail("%s耐力不够啦，歇一会儿再做吧。"%actor_name())
		job={"verb":verb,"target":target,"recipe":recipe_id,"item":recipe.output,"elapsed":0.0,"duration":float(recipe.seconds)/multiplier("cook")}
		job.stamina_reserved=true
		return {"ok":true,"message":"正在烹饪%s，完成后才会使用材料。"%recipe.name}
	if verb=="snack":
		if definition.get("edible",{}).is_empty() or count(item)<1: return fail("口袋里没有可以吃的橘子。")
		if state.stamina>=stamina_max(): return fail("耐力已满，留着一会儿吃吧。")
		job={"verb":verb,"target":"","item":item,"elapsed":0.0,"duration":float(definition.edible.seconds)}
		return {"ok":true,"message":""}
	if verb=="eat":
		if target!="dining" or not near_position(DB.facilities().dining,3.8): return fail("请先来到厨房旁的餐桌。")
		if definition.get("kind","")!="food" or count(item)<1: return fail("背包里没有这份料理。")
		if definition.get("effect",{}).is_empty() and int(definition.get("stamina_restore",0))>0 and state.stamina>=stamina_max(): return fail("耐力已满，留着一会儿吃吧。")
		job={"verb":verb,"target":target,"item":item,"elapsed":0.0,"duration":6.0}
		return {"ok":true,"message":"坐下来，慢慢享用%s。"%definition.name}
	if verb=="gather":
		var source: Dictionary = {}
		for r in DB.all_resources():
			if r.id==target: source=r; break
		if source.is_empty() or source.get("map","city")!=map_id or not near_position(Vector2(source.x,source.z),3.5) or not state.resources[target].available: return fail("这里已经采集过了，过会儿再来吧。")
		var resource_item := DB.item(source.item)
		if count(resource_item.get("tool",""))<1 and resource_item.has("tool"): return fail("需要%s，工具店可以买到。"%DB.item(resource_item.tool).name)
		var locked := resource_lock_reason(source.item)
		if locked!="": return fail(locked)
		var cost:=Stats.work_tier(source.item)
		if not reserve_work_stamina(cost): return fail("耐力不足，需要 %d 点。"%cost)
		job={"verb":verb,"target":target,"item":source.item,"elapsed":0.0,"duration":action_duration(verb,source.item)}
		job.stamina_reserved=true
		job.stamina_cost=cost
		return {"ok":true,"message":"正在采集…"}
	if not state.plots.has(target): return fail("这块土地不属于菜园。")
	var position_: Vector2=Vector2.ZERO
	for plot in DB.plots():
		if plot.id==target: position_=Vector2(plot.x,plot.z); break
	if not near_position(position_,3.5): return fail("请靠近这块菜地。")
	var p: Dictionary = state.plots[target]
	var need := needs(p)
	var crop_id: String=definition.get("crop","") if verb=="plant" else str(p.crop)
	if crop_id!="":
		var locked := crop_lock_reason(crop_id)
		if locked!="": return fail(locked)
	match verb:
		"plant":
			if p.crop!="" or definition.get("kind","")!="seed" or count(item)<1: return fail("需要空地和背包里的种子。")
		"water":
			if p.crop=="" or not need.water: return fail("这株作物现在不缺水。")
			if count("watering_can")<1: return fail("需要木水壶，工具店可以买到。")
		"weed":
			if p.crop=="" or not need.weed: return fail("这里现在没有杂草。")
			if count("herbicide")<1: return fail("需要除草剂，种子商店可以买到。")
		"harvest":
			if not need.ready: return fail("作物还没成熟，先照料它吧。")
		_: return fail("暂时不支持这个动作。")
	if not reserve_work_stamina(): return fail("%s耐力不够啦，歇一会儿再照料吧。"%actor_name())
	job={"verb":verb,"target":target,"item":item,"elapsed":0.0,"duration":action_duration(verb,item),"stamina_reserved":true}
	return {"ok":true,"message":"%s开始认真干活了。"%actor_name()}

func tick(delta: float) -> Array:
	var events: Array = []
	if delta<=0: return events
	tick_stamina(delta)
	state.time += delta
	if not state.food_effect.is_empty() and float(state.food_effect.expires_at)<=float(state.time):
		state.food_effect={}
		state.stamina=minf(state.stamina,stamina_max())
		events.append({"type":"effect_expired","message":"这一餐的美味记忆结束啦。"})
	for id in state.plots:
		var p: Dictionary = state.plots[id]
		if p.crop=="": continue
		# Stop precisely at the next care threshold, even after a long save interval.
		var remaining := delta
		while remaining>.00001:
			var need := needs(p)
			if need.water or need.weed or need.ready: break
			var total := float(DB.crop(p.crop).days)*DAY_SECONDS
			var stages := DB.care_stages(p.crop).size()
			var gate := minf(total,(floor(float(p.growth)/total*stages+.00001)+1)*total/stages)
			var advance := minf(remaining,maxf(0,gate-float(p.growth)))
			if advance<.00001: break
			p.growth += advance
			remaining -= advance
	for id in state.resources:
		var r: Dictionary = state.resources[id]
		if not r.available and state.time>=r.respawn_at:
			r.available=true
			r.generation+=1
			events.append({"type":"respawn","target":id})
	if not job.is_empty():
		job.elapsed += delta
		if job.elapsed>=job.duration:
			var done := job.duplicate(true)
			job.clear()
			events.append(complete(done))
	return events

func complete(j: Dictionary) -> Dictionary:
	var target: String = j.target
	var message := ""
	var amount := 0
	var critical := false
	var quality_gain := false
	var quality := 0
	if j.verb=="craft":
		var recipe:=DB.recipe(j.recipe)
		if not near_position(DB.facilities().kitchen,3.8): return rejected_work(j,"离开了料理台，材料没有消耗。")
		for ingredient in recipe.ingredients:
			if count(ingredient)<int(recipe.ingredients[ingredient]): return rejected_work(j,"材料不足，烹饪已取消。")
		for ingredient in recipe.ingredients: add(ingredient,-int(recipe.ingredients[ingredient]))
		add(recipe.output,1)
		amount=1
		message="做好了 %s × 1"%recipe.name
	elif j.verb=="snack":
		var edible: Dictionary=DB.item(j.item).get("edible",{})
		if edible.is_empty() or count(j.item)<1: return rejected_work(j,"橘子已经不在口袋里了。")
		add(j.item,-1)
		var before := float(state.stamina)
		state.stamina=minf(stamina_max(),before+int(edible.stamina))
		message="吃了一颗橘子，耐力 +%d"%int(state.stamina-before)
	elif j.verb=="eat":
		if not near_position(DB.facilities().dining,3.8) or count(j.item)<1: return rejected_work(j,"用餐已取消，食物没有消耗。")
		add(j.item,-1)
		var food:=DB.item(j.item)
		if not food.get("effect",{}).is_empty(): state.food_effect={"item":j.item,"expires_at":float(state.time)+DAY_SECONDS}
		state.stamina=minf(state.stamina,stamina_max())
		if int(food.get("stamina_restore",0))>0: state.stamina=minf(stamina_max(),state.stamina+int(food.stamina_restore))
		message="吃饱啦！%s"%DB.effect_summary(j.item)
	elif j.verb=="gather":
		if not state.resources[target].available: return rejected_work(j,"资源已经被采集。")
		state.resources[target].available=false
		state.resources[target].respawn_at=state.time+DB.refresh_delay(target,int(state.resources[target].generation))
		amount=3+int(state.resources[target].generation)%3 if j.item=="orange" else int(DB.item(j.item).get("gather_yield",1))
		if j.item!="orange":
			critical=roll_critical(critical_chance(Stats.work_skill("gather",j.item),resource_required(j.item),.05,.25))
			if critical: amount*=2
		add(j.item,amount)
		message="摘到了%d个橘子"%amount if j.item=="orange" else ("双倍收获！%s × %d" if critical else "获得 %s × %d")%[DB.item(j.item).name,amount]
	else:
		var p: Dictionary = state.plots[target]
		match j.verb:
			"plant":
				if count(j.item)<1 or p.crop!="": return rejected_work(j,"播种条件发生变化。")
				add(j.item,-1)
				p.crop=DB.item(j.item).crop
				p.quality=0
				message="种下了%s，记得先浇水。"%DB.crop(p.crop).name
			"water": p.water_stage=mini(DB.care_stages(p.crop).size()-1,int(floor(float(p.growth)/(float(DB.crop(p.crop).days)*DAY_SECONDS)*DB.care_stages(p.crop).size()+.00001))); message="浇好水啦。"
			"weed":
				if count("herbicide")<1: return rejected_work(j,"除草剂不足。")
				add("herbicide",-1)
				p.weed_stage=mini(DB.care_stages(p.crop).size()-1,int(floor(float(p.growth)/(float(DB.crop(p.crop).days)*DAY_SECONDS)*DB.care_stages(p.crop).size()+.00001)))
				message="杂草清理干净啦。"
			"harvest":
				var crop_id: String = p.crop
				amount=crop_yield(p)
				add(crop_id,amount)
				state.plots[target]=empty_plot()
				message="收获了 %s × %d"%[DB.crop(crop_id).name,amount]
		if j.verb in ["plant","water","weed"]:
			quality_gain=roll_critical(critical_chance("planting",int(DB.crop(p.crop).get("required_level",1)),.10,.50))
			if quality_gain: p.quality=mini(DB.crop_quality_max(p.crop),int(p.get("quality",0))+1)
			quality=int(p.get("quality",0))
			if quality_gain: message="照料得真好！品质 +1"
	var skill: String=Stats.work_skill(j.verb,j.item)
	var skill_gain:=0
	var previous_level:=skill_level(skill) if skill!="" else 1
	if skill!="":
		skill_gain=int(DB.recipe(j.recipe).get("skill_experience",1)) if j.verb=="craft" else Stats.work_tier(j.item)
		state.skill_experience[skill]=mini(Stats.skill_start(Stats.MAX_LEVEL),int(state.skill_experience.get(skill,0))+skill_gain)
		state.skills[skill]=Stats.skill_progress(state.skill_experience[skill]).level
		if int(state.skills[skill])>previous_level: message+="\n%s Lv.%d"%[Stats.skill_name(skill),int(state.skills[skill])]
	var earned:=skill_gain
	state.experience+=earned
	revision+=1
	state.revision=revision
	return {"experience":earned,"skill":skill,"skill_experience":skill_gain,"type":"completed","verb":j.verb,"target":target,"message":message,"amount":amount,"critical":critical,"quality_increased":quality_gain,"quality":quality}

func near_position(target: Vector2,radius: float) -> bool:
	var p: Array=state.player_position
	return Vector2(float(p[0]),float(p[2])).distance_to(target)<=radius
