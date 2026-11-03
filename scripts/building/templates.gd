extends RefCounted
const Layout=preload("res://scripts/building/layout.gd")
static func cottage() -> Dictionary:
	var data:={"schema":1,"next_id":1,"elements":[]}
	data=Layout.add(data,{"type":"floor","a":[73.,5.],"b":[85.,15.],"color":"cda56e","style":"wood"})
	for endpoints in [[[73.,15.],[85.,15.]],[[85.,5.],[73.,5.]],[[73.,5.],[73.,15.]],[[85.,15.],[85.,5.]]]:data=Layout.add(data,{"type":"wall","a":endpoints[0],"b":endpoints[1],"color":"eadcc5","style":"plaster"})
	data=Layout.add(data,{"type":"door","wall":"build_2","offset":6.,"color":"739b8d","style":"wood"})
	data=Layout.add(data,{"type":"window","wall":"build_3","offset":4.,"color":"eee2c6","style":"wood"})
	data=Layout.add(data,{"type":"window","wall":"build_4","offset":4.5,"color":"eee2c6","style":"wood"})
	data=Layout.add(data,{"type":"roof","a":[73.,5.],"b":[85.,15.],"color":"688d81","style":"original"})
	for item in [["bed",82.,8.,0],["sofa",75.,11.5,90],["tea_table",77.,11.5,90],["desk",75.5,7.,0],["bookshelf",84.,12.5,90],["forest_rug",77.5,11.5,0],["forest_planter",84.,6.5,0]]:data=Layout.add(data,{"type":"object","kind":item[0],"position":[item[1],item[2]],"yaw":item[3],"color":"b8c4a3","style":"original"})
	data=Layout.normalize(data)
	data=Layout.add(data,{"type":"object","kind":"pendant","position":[79.,10.],"yaw":0.,"support":"build_9","color":"eadcc5","style":"original"})
	return Layout.validate(data).layout
