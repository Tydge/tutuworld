extends SceneTree
const Factory=preload("res://scripts/building/module_factory.gd")
const L=preload("res://scripts/building/layout.gd")
class Host extends Node3D:
	var scenery: Node3D
	var camera: Camera3D
	var bunny: CharacterBody3D
var result: Dictionary={}
func _initialize() -> void:call_deferred("run")
func update(room: Node3D,layout: Dictionary,host: Node3D) -> void:result=await Factory.sync_incremental(room,layout,host)
func run() -> void:
	var host:=Host.new();host.scenery=Node3D.new();host.add_child(host.scenery);root.add_child(host)
	var room:=Factory.shell(host);var layout: Dictionary=L.validate(L.add(L.empty(),{"type":"floor","a":[78.,-14.],"b":[100.,6.]})).layout
	update(room,layout,host)
	for i in range(6):await process_frame
	host.queue_free();await process_frame
	var deadline:=Time.get_ticks_msec()+5000
	while result.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	var ok: bool=result.get("cancelled",false)
	print("BUILDING_UPDATE_LIFECYCLE_RESULT ","PASS" if ok else "FAIL"," checks=1 result=",result);quit(0 if ok else 1)
