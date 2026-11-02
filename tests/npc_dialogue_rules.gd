extends SceneTree
const People=preload("res://scripts/city/npc_profiles.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label_: String) -> void:
	checks+=1
	if not ok: failures.append(label_);print("FAIL ",label_)
func _initialize() -> void:
	var ids: Array=["Merchant_farm","Merchant_tools","Merchant_clothes","Passerby0","Passerby1","Passerby2","Passerby3","CatTeacher","Youmu","Panda","ValleyVisitor0","ValleyVisitor1"]
	for id in ids:
		var profile:=People.profile(id)
		check(profile.lines.size()==8,"Eight lines for "+id)
		var texts: Dictionary={}
		for line in profile.lines: texts[line.text]=true
		check(texts.size()==8,"Distinct lines for "+id)
		for tick in range(96):
			var hour:=tick*.25
			var available:=People.available_lines(id,hour)
			check(available.size()>=2,"No empty or single-choice dialogue window "+id+str(hour))
			var previous:=""
			for repeat in range(12):
				var current:=People.line_for_npc(id,previous,hour)
				check(available.has(current) and current!=previous,"World time and anti-repeat "+id)
				previous=current
	check(People.in_window({"start":21,"end":6},23) and People.in_window({"start":21,"end":6},3) and not People.in_window({"start":21,"end":6},12),"Cross-midnight windows work")
	check(not People.in_window({"start":6,"end":11},11) and People.in_window({"start":6,"end":11},6),"Start inclusive end exclusive")
	for id in ids:
		for line in People.available_lines(id,1):
			check(not line.contains("太阳") and not line.begins_with("早") and not line.contains("光线不错"),"No daytime greeting or sunshine at night "+id)
	print("NPC_DIALOGUE_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
