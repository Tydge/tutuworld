extends SceneTree
const Release=preload("res://scripts/services/release.gd")
const Transport=preload("res://scripts/services/remote_transport.gd")
const Updates=preload("res://scripts/services/update_client.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1
	if not ok:failures.append(label_);print("FAIL ",label_)
func run() -> void:
	var updater=Updates.new();root.add_child(updater);updater.check_updates()
	var start:=Time.get_ticks_msec()
	while updater.state=="checking" and Time.get_ticks_msec()-start<25000:await process_frame
	check(updater.state=="latest" and int(updater.manifest.get("build",0))==Release.BUILD,"Public HTTPS manifest signed and current")
	var client=Transport.new();root.add_child(client)
	check(await client.ensure_connected(),"Public TLS WebSocket current build accepted")
	var result: Dictionary=await client.request("characters")
	check(not result.get("ok",false),"Unauthenticated roster denied")
	client.close();client.queue_free()
	var old=Transport.new();old.set_meta("build",2);root.add_child(old)
	check(not await old.ensure_connected() and old.required_version==Release.VERSION,"Public service refuses outdated build")
	old.close();old.queue_free()
	print("MULTIPLAYER_PUBLIC_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
