extends SceneTree
const Trust=preload("res://scripts/services/update_trust.gd")
const Updates=preload("res://scripts/services/update_client.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1
	if not ok:failures.append(label_);print("FAIL ",label_)
func run() -> void:
	var path:=OS.get_environment("TUTU_TEST_MANIFEST")
	if path=="":push_error("Set TUTU_TEST_MANIFEST to a signed release envelope");quit(1);return
	var envelope=JSON.parse_string(FileAccess.get_file_as_string(path))
	var payload:=Trust.verify_envelope(envelope)
	check(not payload.is_empty(),"Accept genuine signed release")
	var modified: Dictionary=envelope.duplicate();modified.payload=str(modified.payload)+" "
	check(Trust.verify_envelope(modified).is_empty(),"Reject edited signed payload")
	modified=envelope.duplicate();modified.signature="AA=="
	check(Trust.verify_envelope(modified).is_empty(),"Reject invalid signature")
	check(Trust.verify_envelope({}).is_empty() and Trust.verify_envelope([]).is_empty(),"Reject malformed envelope")
	var updater=Updates.new();root.add_child(updater)
	updater.storage=preload("res://tests/test_support.gd").output_dir()+"/updater-negative"
	DirAccess.make_dir_recursive_absolute(updater.storage)
	updater.manifest=payload;updater.envelope=envelope;updater.downloading=true
	updater.expected_file=updater.storage+"/corrupted.pck.part"
	var file:=FileAccess.open(updater.expected_file,FileAccess.WRITE);file.store_string("truncated and modified pack");file.close()
	updater.on_response(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),PackedByteArray())
	check(updater.state=="error" and not FileAccess.file_exists(updater.expected_file),"Reject and delete corrupt pack")
	check(not FileAccess.file_exists(updater.storage+"/pending.json"),"Bad pack never becomes pending")
	updater.downloading=false;updater.state="idle";updater.current_build=2
	var manifest_url:=OS.get_environment("TUTU_TEST_MANIFEST_URL")
	updater.check_updates(manifest_url if manifest_url!="" else Updates.MANIFEST_URL)
	var start:=Time.get_ticks_msec()
	while updater.state=="checking" and Time.get_ticks_msec()-start<25000:await process_frame
	check(updater.state=="available","HTTPS release check verifies signature")
	updater.download_update();await create_timer(.15).timeout;updater.cancel_download()
	check(updater.state=="idle" and not FileAccess.file_exists(updater.expected_file),"Cancel deletes partial download")
	print("UPDATE_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
