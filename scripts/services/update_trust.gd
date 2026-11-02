extends RefCounted
## Bootstrap-only trust anchor. Do not preload gameplay/version scripts here.
const BASE_URL:="https://47.119.37.251/tutuworld/"
const LAUNCHER:=2
const MAX_PACK_BYTES:=268435456
static func verify_envelope(value: Variant) -> Dictionary:
	if not value is Dictionary or not value.get("payload",null) is String or not value.get("signature",null) is String:return {}
	var payload: String=value.payload
	if payload.length()>60000:return {}
	var key:=CryptoKey.new()
	if key.load("res://config/release_public.pem",true)!=OK:return {}
	if not Crypto.new().verify(HashingContext.HASH_SHA256,payload.sha256_buffer(),Marshalls.base64_to_raw(value.signature),key):return {}
	var data=JSON.parse_string(payload)
	if not data is Dictionary or data.get("schema",0)!=1 or not (data.get("build") is float or data.get("build") is int):return {}
	if not data.get("pack") is Dictionary:return {}
	var pack: Dictionary=data.pack
	if not str(pack.get("url","")).begins_with(BASE_URL+"releases/") or not str(pack.get("url","")).ends_with(".pck"):return {}
	if str(pack.get("sha256","")).length()!=64 or not str(pack.sha256).is_valid_hex_number(false):return {}
	if int(pack.get("bytes",0))<=0 or int(pack.bytes)>MAX_PACK_BYTES:return {}
	if int(data.build)<1 or float(data.build)!=floor(float(data.build)) or str(data.get("version","")).is_empty() or int(data.get("min_launcher",1))<1:return {}
	return data
