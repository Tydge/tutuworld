extends RefCounted
## Cosmetic meal clock. Inventory/effects are still settled by the six-second job.
const START:=.30
const CYCLE:=1.65
const SWALLOW:=.90
const BITES:=3
static func utensil(item: String) -> String:
	if item in ["food_honey_wheat_cake","food_rustic_wheat_bread"]:return "hand"
	if item in ["food_garden_salad","food_vegetable_omelette"]:return "fork"
	return "spoon"
static func sample(elapsed: float,duration: float=6.) -> Dictionary:
	var t:=maxf(0.,elapsed)*6./maxf(.01,duration)
	var bites:=clampi(int(floor((t-START-SWALLOW)/CYCLE))+1,0,BITES)
	if t<START or t>=START+CYCLE*BITES:return {"lift":0.,"chew":0.,"loaded":false,"bites":bites,"cycle":clampi(bites,0,2)}
	var phase:=fposmod(t-START,CYCLE)
	var lift:=smoothstep(.30,.73,phase)*(1.-smoothstep(1.07,1.49,phase))
	var chew:=smoothstep(.86,.99,phase)*(1.-smoothstep(1.25,1.57,phase))
	return {"lift":lift,"chew":chew,"loaded":phase>=.22 and phase<SWALLOW,"bites":bites,"cycle":mini(2,int((t-START)/CYCLE))}
