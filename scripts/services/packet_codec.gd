extends RefCounted
const MAX_BYTES:=1048576
static func encode(value: Dictionary) -> PackedByteArray:
	return JSON.stringify(value).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
static func decode(packet: PackedByteArray) -> Dictionary:
	if packet.is_empty() or packet.size()>MAX_BYTES:return {}
	var bytes:=packet.decompress_dynamic(MAX_BYTES,FileAccess.COMPRESSION_GZIP)
	if bytes.is_empty():return {}
	var data=JSON.parse_string(bytes.get_string_from_utf8())
	return data if data is Dictionary else {}
