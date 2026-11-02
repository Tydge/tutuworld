extends RefCounted
## Acknowledge past input, replay only unacknowledged input. Never chase a stale position.
var generation:=0
var sequence:=0
var acknowledged:=0
var history: Array=[]
var outgoing: Array=[]
var pending: Dictionary={}
var corrections:=0
var hard_corrections:=0
var max_error:=0.0
func reset(actor: CharacterBody3D,row: Dictionary) -> void:
	generation=int(row.get("generation",0));sequence=int(row.get("ack",0));acknowledged=sequence
	history.clear();outgoing.clear();pending.clear()
	actor.restore_movement_state(row);actor.presentation_offset=Vector3.ZERO;actor.reset_physics_interpolation()
func record(actor: CharacterBody3D,direction: Vector3,jump: bool,running: bool) -> void:
	if generation<=0:return
	sequence+=1
	var input:={"seq":sequence,"direction":[direction.x,0,direction.z],"jump":jump,"running":running}
	history.append({"input":input,"state":actor.movement_state()});outgoing.append(input)
	if history.size()>600:history.pop_front()
func take_packet() -> Dictionary:
	if outgoing.is_empty():return {}
	var batch:=outgoing.slice(0,12);outgoing=outgoing.slice(batch.size())
	return {"type":"motion","generation":generation,"inputs":batch}
func receive(row: Dictionary) -> void:
	if int(row.get("generation",0))<generation:return
	if not pending.is_empty() and int(row.get("generation",0))==int(pending.get("generation",0)) and int(row.get("ack",0))<=int(pending.get("ack",0)):return
	pending=row.duplicate(true)
func reconcile(actor: CharacterBody3D) -> void:
	if pending.is_empty():return
	var row:=pending;pending={}
	if int(row.get("generation",0))!=generation:reset(actor,row);return
	var ack:=int(row.get("ack",0))
	if ack<=acknowledged:return
	acknowledged=ack
	var found: Dictionary={}
	for frame in history:
		if int(frame.input.seq)==ack:found=frame;break
	if found.is_empty():return
	var p: Array=found.state.position;var q: Array=row.position
	var error:=Vector3(q[0]-p[0],q[1]-p[1],q[2]-p[2])
	max_error=maxf(max_error,error.length())
	var remaining: Array=[]
	for frame in history:
		if int(frame.input.seq)>ack:remaining.append(frame)
	history=remaining
	# Tiny rounding errors do not warrant a physics rewind.
	var v: Array=found.state.velocity;var w: Array=row.velocity
	if error.length()<.025 and Vector3(v[0]-w[0],v[1]-w[1],v[2]-w[2]).length()<.1:return
	var before:=actor.position
	var yaw: float=actor.visual.rotation.y;var step: float=actor.step_phase
	actor.restore_movement_state(row)
	for frame in history:
		var input: Dictionary=frame.input
		actor.run_enabled=bool(input.running)
		actor.simulate_movement(actor.INPUT_STEP,Vector3(input.direction[0],0,input.direction[2]),bool(input.jump),false,true)
		frame.state=actor.movement_state()
	actor.visual.rotation.y=yaw;actor.step_phase=step
	corrections+=1
	if before.distance_to(actor.position)>3:
		actor.presentation_offset=Vector3.ZERO;actor.reset_physics_interpolation();hard_corrections+=1
	else:
		actor.presentation_offset+=before-actor.position
		actor.reset_physics_interpolation()
