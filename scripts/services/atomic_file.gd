extends RefCounted
## Verify flushed bytes before replacing either a save or its previous backup.
static func stage(path: String,bytes: PackedByteArray) -> bool:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return false
	file.store_buffer(bytes);file.flush()
	var error:=file.get_error();file.close()
	if error!=OK:return false
	var verify:=FileAccess.open(path,FileAccess.READ)
	if verify==null:return false
	var actual:=verify.get_buffer(verify.get_length());verify.close()
	return actual==bytes
static func copy_verified(source: String,target: String) -> bool:
	var file:=FileAccess.open(source,FileAccess.READ)
	if file==null:return false
	var length_:=file.get_length();var bytes:=file.get_buffer(length_);file.close()
	if bytes.size()!=length_ or not stage(target+".tmp",bytes):return false
	return DirAccess.rename_absolute(target+".tmp",target)==OK
static func write(path: String,text: String,backup: bool=true) -> bool:
	if not stage(path+".tmp",text.to_utf8_buffer()):return false
	if backup and FileAccess.file_exists(path) and not copy_verified(path,path+".bak"):return false
	return DirAccess.rename_absolute(path+".tmp",path)==OK
