extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const T=preload("res://scripts/building/templates.gd")
var failures: Array=[]
var checks:=0
func check(value: bool,label_: String) -> void:
	checks+=1
	if not value:failures.append(label_);print("FAIL ",label_)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for kind in ["single_one","two_storey"]:
		var data:=T.player_sample(kind);check(not data.is_empty(),"Extracted template validates: "+kind)
		if data.is_empty():continue
		check(L.validate(L.merge_template(L.empty(),data,L.template_origin(data))).ok,"Template ID remapping preserves attachments: "+kind)
		for wall in data.elements.filter(func(row):return row.type=="wall"):
			for offset in [0.,1.,2.,4.,6.,9.,12.]:
				var row:={"type":"window","wall":wall.id,"offset":offset,"storey":wall.get("storey",0)}
				check(L.preview_opening(data,row).ok==L.validate(L.add(data,row)).ok,"Preview matches commit: "+kind+"/"+wall.id+"/"+str(offset))
	var lights:=L.add(L.empty(),{"type":"floor","a":[61.,-7.],"b":[120.,27.]})
	for i in range(L.MAX_LIGHTS):lights=L.add(lights,{"type":"object","kind":"floor_lamp","position":[63.+(i%12)*4.,-5.+floori(i/12.)*4.],"yaw":0.})
	check(L.validate(lights).ok,"48 separated light fixtures validate")
	lights=L.add(lights,{"type":"object","kind":"floor_lamp","position":[63.,15.],"yaw":0.})
	check(not L.validate(lights).ok,"49th light remains bounded")
	print("BUILDING_FEEDBACK_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
