extends RefCounted
## Screenshots and test evidence stay local and portable across developer machines.
static func output_dir() -> String:
	var path:=OS.get_environment("TUTU_QA_OUTPUT")
	if path.is_empty(): path=ProjectSettings.globalize_path("res://.qa-artifacts/screenshots")
	DirAccess.make_dir_recursive_absolute(path)
	return path.trim_suffix("/")
