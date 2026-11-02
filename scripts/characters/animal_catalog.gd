extends RefCounted
## Shared species registry for creation, saves, previews and world actors.
const SCENES={"bunny":"res://scenes/bunny.tscn","cat_teacher":"res://scenes/cat_teacher.tscn","panda":"res://scenes/panda.tscn"}
const NAMES={"bunny":"兔兔","cat_teacher":"猫咪","panda":"熊猫"}
static func ids() -> Array: return SCENES.keys()
static func supports(id: String) -> bool: return SCENES.has(id)
static func display_name(id: String) -> String: return NAMES.get(id,"兔兔")
