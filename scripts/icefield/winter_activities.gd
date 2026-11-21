extends RefCounted
const Trail=preload("res://scripts/icefield/snow_trail.gd")
const DB=preload("res://scripts/services/game_data.gd")
const JOBS:={
	"bake":{"kind":"bakery","seconds":6.,"ingredients":{"wheat":1,"branch":1},"animation":"cook"},
	"brew_tea":{"kind":"tea","seconds":4.,"ingredients":{"branch":1},"animation":"tea"},
	"warm":{"kind":"hearth","seconds":5.,"ingredients":{},"animation":"warm"}
}
static func begin(authority: RefCounted,verb: String,target: String) -> Dictionary:
	if verb=="stamp":
		if authority.state.map_id!="icefield" or not target.begins_with("snow_stamp:") or not reachable(authority,target,"stamp"):return authority.fail("这枚印章要亲自走到路牌边盖。")
		var stamp:=target.trim_prefix("snow_stamp:")
		if not Trail.STAMPS.has(stamp):return authority.fail("没找到这枚印章。")
		var trail: Dictionary=authority.state.snow_trail
		if stamp in trail.stamps:return authority.fail("这枚印章已经盖在图册上啦。")
		trail.stamps.append(stamp)
		return {"ok":true,"message":"在图册上盖下了「%s」 · %d / %d"%[Trail.STAMPS[stamp].name,trail.stamps.size(),Trail.STAMPS.size()]}
	if verb=="claim_trail":
		if not reachable(authority,target,"atlas"):return authority.fail("回到图册旁交上你的印章。")
		var trail: Dictionary=authority.state.snow_trail
		if trail.claimed or trail.stamps.size()!=Trail.STAMPS.size():return authority.fail("三枚印章集齐后，就能领取踏雪回礼。")
		trail.claimed=true
		authority.state.coins+=Trail.REWARD_COINS
		authority.add(Trail.LOAF,2)
		return {"ok":true,"message":"踏遍雪路啦！收下 %d 贝壳币和两份雪绒路粮。"%Trail.REWARD_COINS}
	var station: Dictionary=JOBS[verb]
	if not reachable(authority,target,station.kind):return authority.fail("请站到可以操作的位置。")
	var check:=ready_for_job(authority,verb)
	if not check.is_empty():return authority.fail(check)
	authority.job={"verb":verb,"target":target,"item":Trail.LOAF if verb=="bake" else (Trail.TEA if verb=="brew_tea" else ""),"elapsed":0.0,"duration":station.seconds}
	return {"ok":true,"message":""}

static func reachable(authority: RefCounted,target: String,kind: String) -> bool:
	return authority.activity_access.is_valid() and authority.activity_access.call(target,kind)

static func ready_for_job(authority: RefCounted,verb: String) -> String:
	if verb=="warm":
		if authority.state.stamina>=authority.stamina_max():return "爪子暖暖的，耐力已满。"
		if float(authority.state.get("hearth_ready_at",0))>float(authority.state.time):return "身上还暖着，过会儿再来烤火吧。"
	if verb=="brew_tea" and authority.state.food_effect.get("item","")==Trail.TEA:return "刚喝过松针茶，茶香还在呢。"
	for ingredient in JOBS[verb].ingredients:
		if authority.count(ingredient)<int(JOBS[verb].ingredients[ingredient]):return "还需要%s。"%DB.item(ingredient).name
	return ""

static func complete(authority: RefCounted,job: Dictionary) -> Dictionary:
	var verb: String=job.verb
	var station: Dictionary=JOBS[verb]
	if not reachable(authority,job.target,station.kind):return authority.rejected_work(job,"离开了陈设，手里的材料都放回口袋了。")
	var check:=ready_for_job(authority,verb)
	if not check.is_empty():return authority.rejected_work(job,check)
	for ingredient in station.ingredients:authority.add(ingredient,-int(station.ingredients[ingredient]))
	var message: String
	match verb:
		"bake":
			authority.add(Trail.LOAF,1)
			message="出炉啦！雪绒路粮 × 1，带在路上吃能恢复 24 点耐力。"
		"brew_tea":
			authority.state.food_effect={"item":Trail.TEA,"expires_at":float(authority.state.time)+600.}
			message="喝完热茶，接下来 10 分钟耐力恢复加快 50%。"
		"warm":
			var before: float=authority.state.stamina
			authority.state.stamina=minf(authority.stamina_max(),before+12.)
			authority.state.hearth_ready_at=float(authority.state.time)+180.
			message="爪子暖起来了，耐力 +%d。"%int(authority.state.stamina-before)
	return {"type":"completed","verb":verb,"target":job.target,"message":message}
