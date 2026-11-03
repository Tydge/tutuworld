extends RefCounted
## Durable building-only checkpoint. Periodic/full saves consolidate it atomically.
static func write(path: String,generation: String,world_id: String,layout: Dictionary) -> bool:
	var payload:=JSON.stringify(layout);var record:={"schema":2,"base":generation,"world_id":world_id,"sha256":payload.sha256_text(),"payload":payload}
	return preload("res://scripts/services/atomic_file.gd").write(path+".building",JSON.stringify(record))
static func replay(path: String,data: Dictionary,generation: String) -> void:
	var world: Dictionary=data.get("world",data.get("state",{}));var world_id:=str(world.get("world_id","local"))
	for file in [path+".building",path+".building.bak"]:
		if not FileAccess.file_exists(file):continue
		var parser:=JSON.new()
		if parser.parse(FileAccess.get_file_as_string(file))!=OK:continue
		var record: Variant=parser.data
		if not record is Dictionary or (record.get("schema",0)!=1 and record.get("schema",0)!=2) or record.get("base","")!=generation or record.get("world_id","")!=world_id:continue
		var raw: Variant
		if record.get("schema",0)==2:
			if not record.get("payload") is String or record.payload.sha256_text()!=record.get("sha256",""):continue
			if parser.parse(record.payload)!=OK:continue
			raw=parser.data
		else:raw=record.get("layout")
		var checked: Dictionary=preload("res://scripts/building/layout.gd").validate(raw)
		if record.get("schema",0)==1:
			if not checked.ok:continue
			var legacy: Dictionary=checked.layout.duplicate(true)
			if not raw.has("lighting_version"):legacy.erase("lighting_version");legacy.erase("legacy_fireplaces");legacy.erase("legacy_light_limit")
			if JSON.stringify(legacy).sha256_text()!=record.get("sha256","") and JSON.stringify(raw).sha256_text()!=record.get("sha256",""):continue
		if checked.ok:world.build_layout=checked.layout;return
static func consolidate(path: String) -> void:
	for name_ in [path+".building",path+".building.bak"]:
		if FileAccess.file_exists(name_):DirAccess.remove_absolute(name_)
