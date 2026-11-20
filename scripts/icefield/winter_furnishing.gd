extends RefCounted
## Furniture uses the editor's real models, footprints, seats and materials.
## These arrangements are baked once when generating the island.
const Builder=preload("res://scripts/building/furniture_builder.gd")
const Props=preload("res://scripts/icefield/winter_props.gd")
# kind, x, z, yaw; optional height for pieces placed on a table or shelf.
const ROOMS={
	"home":[["bed",-3.2,-1.8,0],["bedside",-1.25,-3.15,0],["clock",-1.25,-3.15,0,.8],["tile_stove",3.8,-2.8,0],["chair",3.,1.,-50],["woven_basket",-3.7,2.,15]],
	"study":[["desk",-3.4,-1.5,90],["field_journal",-3.4,-1.5,75,1.14],["chair",-1.8,-1.5,-90],["bed",3.55,-1.7,0],["atlas_stand",-2.9,2.,32]],
	"lodge":[["bed",-3.55,-1.8,0],["bed",3.55,-1.8,0],["bedside",1.55,-3.,0],["cup",1.55,-3.,0,.8],["tile_stove",0.,-3.6,0],["woven_basket",-3.5,1.75,12]],
	"bakery":[["bread_case",-2.8,-.55,0],["bread_case",.1,-.55,0],["kitchen_cart",-3.6,-2.95,90],["spice_jars",-3.6,-2.95,90,1.2],["tile_stove",3.55,-2.65,0],["chair",3.4,1.4,-45]],
	"library":[["bookshelf",-3.4,-3.65,0],["bookshelf",-1.5,-3.65,0],["atlas_stand",2.95,-2.4,-18],["petal_armchair",-3.,.65,28],["tea_table",2.75,1.,0],["field_journal",2.75,1.,0,.735]],
	"tea":[["sofa",-3.4,-1.3,90],["tea_table",-1.55,-1.3,90],["tea_service",-1.55,-1.3,90,.735],["tile_stove",2.9,-3.,0],["petal_armchair",2.95,.7,-32]],
	"dining":[["dining_table",-2.8,-1.,90],["dining_chair",-4.15,-1.,90],["dining_chair",-1.2,-1.,-90],["tea_service",-2.8,-1.,0,1.14],["kitchen_cart",3.6,-2.85,0],["spice_jars",3.6,-2.85,0,1.2],["bread_case",3.1,.65,-60]],
	"hall":[["atlas_stand",0.,-2.8,0],["forest_settee",-3.4,.15,90],["forest_settee",3.4,.15,-90],["clock",2.3,-3.3,0,.8],["bedside",2.3,-3.3,0]]
}
var furniture:=Builder.new()
var models: Dictionary={}

func arrange(room: Node3D,theme: String) -> void:
	var furnishing:=room.get_node("Furnishing") as Node3D
	furnishing.position.y=room.floor_level
	var rows: Array=ROOMS[theme].duplicate()
	rows.append(["wall_clock" if theme in ["hall","bakery","library","study"] else "wall_botanical",0.,-4.27,0,2.03])
	if theme in ["tea","lodge","bakery","hall"]:rows.append(["forest_rug",0.,1.2,0])
	if theme=="library":
		for x in [-3.4,-1.5]:
			for y in [.18,.88,1.58]:
				for j in range(5):rows.append(["standing_book",x-.46+j*.20,-3.65,0,y])
	for i in range(rows.size()):
		var row: Array=rows[i];var kind: String=row[0]
		var item: Node3D
		if not models.has(kind):
			item=Props.group(furnishing,"Item")
			furniture.build_item(item,kind)
			models[kind]=item
		else:
			item=models[kind].duplicate()
			furnishing.add_child(item)
		item.name="%s_%d"%[kind,i]
		item.position=Vector3(row[1],row[4] if row.size()>4 else 0.,row[2])
		item.rotation.y=deg_to_rad(row[3])
	var light:=OmniLight3D.new()
	light.name="RoomFill";light.position=Vector3(0,3.8,0);light.omni_range=7.5
	light.light_color=Color("ffdfb8");light.shadow_enabled=false;furnishing.add_child(light)
