extends "res://scripts/valley/valley_world.gd"
var manager: Node
func _ready() -> void:
	session=manager
	preload("res://server/host_setup.gd").setup(self)
func _process(_delta: float) -> void:preload("res://server/host_setup.gd").update(self)
func _unhandled_input(_event: InputEvent) -> void:pass
func play_tone(_frequency: float,_duration: float=.12,_volume: float=.1) -> void:pass
func footstep(_position: Vector3) -> void:pass
func end_dialogue() -> void:talking_npc=""
func _exit_tree() -> void:pass
func online_players() -> Array:
	var out: Array=[]
	for pawn in manager.pawns.values():
		if pawn.get_parent()==self:out.append(pawn)
	return out
func chatting_with(id: String) -> CharacterBody3D:
	var row: Dictionary=manager.locks.get(map_id+":"+id,{})
	return manager.pawns.get(row.get("owner",""))
func safe_npc_exit(actor: CharacterBody3D,position_: Vector3) -> Dictionary:return manager.safe_position(map_id,position_,str(actor.name),actor)
