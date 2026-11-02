extends Node
signal status_changed
const BASE_URL := "https://47.119.37.251/tutuworld/"
const Trust=preload("res://scripts/services/update_trust.gd")
const MANIFEST_URL := BASE_URL+"manifest.json"
const LAUNCHER_VERSION := 2
const MAX_PACK_BYTES := 268435456
var current_build := preload("res://scripts/services/release.gd").BUILD
var state := "idle"
var message := "准备检查更新"
var manifest: Dictionary={}
var envelope: Dictionary={}
var progress := 0.0
var storage := "user://updates"
var http: HTTPRequest
var downloading := false
var expected_file := ""
var last_download_bytes:=0
var last_download_progress:=0
func _ready() -> void:
	http=HTTPRequest.new()
	http.use_threads=true
	http.timeout=18
	http.max_redirects=3
	http.set_tls_options(preload("res://scripts/services/network_trust.gd").options())
	http.request_completed.connect(on_response)
	add_child(http)
func set_status(s: String,text: String) -> void:
	state=s
	message=text
	status_changed.emit()
func check_updates(url: String=MANIFEST_URL) -> void:
	if state in ["checking","downloading"]: return
	downloading=false
	http.download_file=""
	http.body_size_limit=65536
	http.timeout=20
	set_status("checking","正在和海岛邮局确认新版本…")
	var error:=http.request(url,PackedStringArray(["Cache-Control: no-cache"]))
	if error!=OK: set_status("error","暂时联系不到更新服务，可以直接开始游戏。")
static func verify_envelope(value: Variant) -> Dictionary:
	return Trust.verify_envelope(value)
func on_response(result: int,code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
		if downloading and expected_file!="": DirAccess.remove_absolute(expected_file)
		set_status("error","更新服务暂时不可用，稍后再试也没关系。")
		return
	if not downloading:
		var value=JSON.parse_string(body.get_string_from_utf8())
		manifest=verify_envelope(value)
		if manifest.is_empty(): set_status("error","更新信息校验失败，保留当前版本。") ; return
		envelope=value
		if int(manifest.get("min_launcher",1))>LAUNCHER_VERSION:
			set_status("installer","需要下载新版安装包，再继续海岛旅程。")
		elif int(manifest.build)>current_build: set_status("available","发现新版本 %s · %s"%[manifest.version,manifest.get("notes","新的海岛故事正在等你。")])
		else: set_status("latest","已经是最新版本 %s。"%manifest.version)
		return
	var downloaded:=FileAccess.open(expected_file,FileAccess.READ)
	var downloaded_size: int=downloaded.get_length() if downloaded!=null else -1
	if downloaded!=null:downloaded.close()
	if FileAccess.get_sha256(expected_file)!=str(manifest.pack.sha256) or downloaded_size!=int(manifest.pack.bytes):
		DirAccess.remove_absolute(expected_file)
		set_status("error","更新包校验失败，当前游戏不受影响。")
		return
	var filename:="build-%d.pck"%int(manifest.build)
	var final_path:=storage+"/"+filename
	if FileAccess.file_exists(final_path): DirAccess.remove_absolute(final_path)
	if DirAccess.rename_absolute(expected_file,final_path)!=OK: set_status("error","无法保存更新，请检查磁盘空间。") ; return
	var pending:=FileAccess.open(storage+"/pending.json.tmp",FileAccess.WRITE)
	if pending==null: set_status("error","更新保存失败，可以重新下载。") ; return
	pending.store_string(JSON.stringify({"file":filename,"envelope":envelope}))
	pending.close()
	if DirAccess.rename_absolute(storage+"/pending.json.tmp",storage+"/pending.json")!=OK:set_status("error","无法登记更新，请检查磁盘空间。");return
	progress=1
	set_status("ready","更新已下载并校验完成，可以重新启程啦。")
func download_update() -> void:
	if state!="available" or manifest.is_empty(): return
	DirAccess.make_dir_recursive_absolute(storage)
	expected_file=storage+"/build-%d.pck.part"%int(manifest.build)
	http.download_file=expected_file
	http.body_size_limit=MAX_PACK_BYTES
	http.timeout=0
	downloading=true
	progress=0
	last_download_bytes=0;last_download_progress=Time.get_ticks_msec()
	set_status("downloading","正在下载新故事…")
	var error:=http.request(str(manifest.pack.url))
	if error!=OK: set_status("error","下载暂未开始，点击检查更新重试。")
func cancel_download() -> void:
	http.cancel_request()
	if expected_file!="" and FileAccess.file_exists(expected_file): DirAccess.remove_absolute(expected_file)
	downloading=false
	set_status("idle","下载已取消，当前版本可以继续游戏。")
func _process(_delta: float) -> void:
	if state=="downloading":
		var bytes:=http.get_downloaded_bytes()
		if bytes!=last_download_bytes:last_download_bytes=bytes;last_download_progress=Time.get_ticks_msec()
		elif Time.get_ticks_msec()-last_download_progress>45000:
			cancel_download();set_status("error","下载暂时停住了，检查网络后可以重新下载。");return
		progress=clampf(float(bytes)/maxf(1,float(manifest.pack.bytes)),0,1)
		status_changed.emit()
func restart() -> void:
	if state!="ready": return
	if OS.has_feature("editor"):
		set_status("ready","更新已就绪。编辑器试玩请停止后再次运行；安装版会自动重启。")
		return
	var pid:=OS.create_instance([])
	if pid>0:get_tree().quit()
	else:set_status("ready","未能自动重启，请关闭后重新打开游戏。")
