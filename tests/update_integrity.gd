extends SceneTree
const Updates=preload("res://scripts/services/update_client.gd")
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var fixture:=args[args.find("--fixture")+1] if args.has("--fixture") else ""
	var envelope=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	check(not Updates.verify_envelope(envelope).is_empty(),"Authentic signed release accepted")
	var changed: Dictionary=envelope.duplicate(true)
	changed.payload=str(changed.payload)+" "
	check(Updates.verify_envelope(changed).is_empty(),"Tampered payload rejected")
	changed=envelope.duplicate(true)
	changed.signature=Marshalls.raw_to_base64(PackedByteArray([1,2,3]))
	check(Updates.verify_envelope(changed).is_empty(),"Forged signature rejected")
	check(Updates.verify_envelope({}).is_empty(),"Malformed release rejected")
	check(Updates.verify_envelope(null).is_empty(),"Absent release rejected")
	print("UPDATE_INTEGRITY_RESULT ","PASS" if failures.is_empty() else "FAIL"," failures=",failures)
	quit(0 if failures.is_empty() else 1)
