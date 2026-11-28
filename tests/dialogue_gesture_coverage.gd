extends SceneTree

const Profiles = preload("res://scripts/city/npc_profiles.gd")
const Jade = preload("res://scripts/jade/residents.gd")
const Winter = preload("res://scripts/icefield/winter_neighbors.gd")
const Gestures = preload("res://scripts/city/dialogue_gestures.gd")
const Emotes = preload("res://scripts/characters/emote_motion.gd")

func _initialize() -> void:
	var ids: Array = ["CatTeacher","Youmu","Panda","ValleyVisitor0","ValleyVisitor1","JadeEmperor"]
	ids.append_array(Profiles.MERCHANTS.keys())
	ids.append_array(Winter.DIALOGUE.keys())
	for i in Profiles.PEOPLE.size():ids.append("Passerby"+str(i))
	for i in Jade.PEOPLE.size():ids.append("JadeCitizen_"+str(i))
	for shop in Jade.SHOPS:ids.append("JadeVendor_"+shop)
	var lines := {}
	for id in ids:
		for row in Profiles.profile(id).lines:lines[row.text]=true
	for row in Jade.AFTER_WORK.values():lines[row[1]]=true
	for request in preload("res://scripts/jade/rounds/scholars.gd").REQUESTS:
		for district in range(4,7):lines[request[district]+"。多亏殿里那道朱批。"]=true
	var ok := Gestures.BY_LINE.size()*5 >= lines.size()
	for line in Gestures.BY_LINE:
		var action: String=Gestures.BY_LINE[line]
		if not lines.has(line) or not Emotes.is_known(action) or Emotes.is_dance(action):
			push_error("Unmatched dialogue or gesture: "+line)
			ok=false
	print("DIALOGUE_COVERAGE_RESULT ", "PASS" if ok else "FAIL", " lines=", lines.size(), " matched=", Gestures.BY_LINE.size())
	quit(0 if ok else 1)
