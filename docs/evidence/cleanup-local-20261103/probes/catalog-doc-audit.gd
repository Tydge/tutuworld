extends SceneTree
func _initialize() -> void:
 var DB=load("res://scripts/services/game_data.gd")
 var data: Dictionary=DB.catalog().duplicate(true)
 data["counts"]={"species":load("res://scripts/characters/animal_catalog.gd").ids().size(),"plots":DB.plots().size(),"resources":DB.all_resources().size(),"clothing":data.items.values().filter(func(row):return row.kind=="clothing").size()}
 var f:=FileAccess.open("res://.qa-artifacts/catalog-doc-audit.json",FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close()
 print("CATALOG_DOC_EXPORT items=",data.items.size()," recipes=",data.recipes.size()," crops=",data.crops.size()," counts=",data.counts)
 quit()
