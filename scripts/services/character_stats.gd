extends RefCounted
const MAX_LEVEL := 100
const PROGRESSION_VERSION := 2
const ROWS: Array = [
	["stamina_capacity","耐力值"],["stamina_regen","耐力回复速度"],["move","移动速度"],["run_speed","奔跑速度"],
	["water","浇水速度"],["plant","播种速度"],["weed","除草速度"],["harvest","收获速度"],
	["cook","烹饪速度"],["stone","采石速度"],["mining","采矿速度"],["wood","采木速度"]]
const SKILLS: Array = [["planting","种植技能","seed_carrot"],["cooking","烹饪技能","food_pumpkin_soup"],["mining","采矿技能","pickaxe"],["quarrying","采石技能","stone_hammer"],["woodcutting","伐木技能","branch"]]
static func defaults() -> Dictionary:
	var out: Dictionary={}
	for row in ROWS: out[row[0]]=0.0
	return out
static func skill_defaults() -> Dictionary:
	var out: Dictionary={}
	for row in SKILLS: out[row[0]]=1
	return out
static func food_key(kind: String) -> String:
	if kind in ["plant","weed","harvest"]: return "farm"
	if kind=="stone": return "mining"
	return kind

# Total skill XP is authoritative. One percent speed per earned level, including Lv.1.
static func skill_xp_defaults() -> Dictionary:
	var out: Dictionary={}
	for row in SKILLS: out[row[0]]=0
	return out
static func skill_required(level: int) -> int:
	var current := clampi(level,1,MAX_LEVEL)
	return (current+1)*(current+4)
static func skill_start(level: int) -> int:
	var total:=0
	for previous in range(1,clampi(level,1,MAX_LEVEL)): total+=skill_required(previous)
	return total
static func skill_progress(total: int) -> Dictionary:
	var level:=1
	var remaining:=maxi(0,total)
	while level<MAX_LEVEL and remaining>=skill_required(level):
		remaining-=skill_required(level);level+=1
	return {"level":level,"current":0 if level==MAX_LEVEL else remaining,"required":0 if level==MAX_LEVEL else skill_required(level)}
static func attribute_skill(kind: String) -> String:
	return {"plant":"planting","water":"planting","weed":"planting","harvest":"planting","cook":"cooking","mining":"mining","stone":"quarrying","wood":"woodcutting"}.get(kind,"")
static func skill_name(id: String) -> String:
	for row in SKILLS:
		if row[0]==id: return row[1]
	return "技能"
static func skill_description(id: String) -> String:
	return {
		"planting":"每级提升1%播种、浇水、除草和收获速度。等级越高，越容易把作物照料得更丰盛。",
		"cooking":"每级提升1%烹饪速度。提升等级，尝试更丰富的料理。",
		"mining":"每级提升1%采矿速度。满足工具和矿石等级后可采集，熟练时有机会收获双份。",
		"quarrying":"每级提升1%采石速度。满足工具和石材等级后可采集，熟练时有机会收获双份。",
		"woodcutting":"每级提升1%采木速度。满足工具和木材等级后可采集，熟练时有机会收获双份。"
	}.get(id,"")
static func work_skill(verb: String,item: String) -> String:
	if verb in ["plant","water","weed","harvest"]: return "planting"
	if verb=="craft": return "cooking"
	if verb!="gather": return ""
	return {"orange":"planting","branch":"woodcutting","birch":"woodcutting","copper":"mining","iron":"mining","limestone":"quarrying","sandstone":"quarrying"}.get(item,"")
static func work_tier(item: String) -> int:
	return 2 if item in ["birch","iron","sandstone"] else 1
