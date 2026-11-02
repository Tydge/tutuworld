extends SceneTree
var updater: Node
var deadline := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	updater=load("res://scripts/services/update_client.gd").new()
	updater.current_build=1
	updater.storage="user://qa-updates"
	root.add_child(updater)
	updater.check_updates()
	deadline=Time.get_ticks_msec()+90000
	while updater.state=="checking" and Time.get_ticks_msec()<deadline: await process_frame
	if updater.state!="available":
		print("UPDATE_DOWNLOAD_RESULT FAIL check=",updater.state," message=",updater.message)
		quit(1)
		return
	print("PASS HTTPS signed manifest downloaded")
	updater.download_update()
	while updater.state=="downloading" and Time.get_ticks_msec()<deadline: await process_frame
	var pass_: bool=updater.state=="ready" and FileAccess.file_exists("user://qa-updates/pending.json")
	if pass_:
		print("PASS HTTPS pack staged and SHA256 verified")
		var path: String="user://qa-updates/build-%d.pck"%int(updater.manifest.build)
		print("PASS Verified pack size=",FileAccess.get_file_as_bytes(path).size())
	else: print("UPDATE_ERROR ",updater.state," ",updater.message)
	print("UPDATE_DOWNLOAD_RESULT ","PASS" if pass_ else "FAIL")
	quit(0 if pass_ else 1)
