extends Node
signal snapshot_received(snapshot: Dictionary)
signal command_result(id: String,result: Dictionary)
signal message_received(message: Dictionary)
signal connection_lost
signal update_required(version: String)
const Release=preload("res://scripts/services/release.gd")
const Codec=preload("res://scripts/services/packet_codec.gd")
const PROTOCOL_VERSION:=Release.PROTOCOL
var socket:=WebSocketPeer.new()
var connected:=false
var connecting:=false
var pending: Dictionary={}
var endpoint:=Release.WORLD_URL
var sequence:=0
var heartbeat:=0.0
var handshake_sent:=false
var required_version:=""
func connect_world(url: String=Release.WORLD_URL,_token: String="") -> Error:
	if connected or connecting:return OK
	if not url.begins_with("wss://") and not (OS.get_cmdline_user_args().has("--test") and url.begins_with("ws://127.0.0.1:")):return ERR_UNAUTHORIZED
	endpoint=url;socket=WebSocketPeer.new();socket.inbound_buffer_size=Codec.MAX_BYTES;socket.outbound_buffer_size=Codec.MAX_BYTES
	socket.heartbeat_interval=10;handshake_sent=false;required_version=""
	var error:=socket.connect_to_url(url)
	connecting=error==OK
	return error
func ensure_connected(url: String=Release.WORLD_URL) -> bool:
	if connected:return true
	if connect_world(url)!=OK:return false
	var start:=Time.get_ticks_msec()
	while connecting and Time.get_ticks_msec()-start<15000:await get_tree().process_frame
	if not connected:connecting=false;socket.close()
	return connected
func send(data: Dictionary) -> Error:
	if socket.get_ready_state()!=WebSocketPeer.STATE_OPEN:return ERR_CONNECTION_ERROR
	return socket.put_packet(Codec.encode(data))
func request(verb: String,args: Dictionary={}) -> Dictionary:
	if not connected:return {"ok":false,"message":"与小岛的连接中断了，正在重新联系…"}
	sequence+=1
	var id:=Crypto.new().generate_random_bytes(12).hex_encode()+":"+str(sequence)
	pending[id]={"done":false,"result":{}}
	if send({"type":"request","id":id,"verb":verb,"args":args})!=OK:pending.erase(id);return {"ok":false,"message":"消息还没送到，请稍后再试。"}
	var start:=Time.get_ticks_msec()
	while pending.has(id) and not pending[id].done and connected and Time.get_ticks_msec()-start<18000:await get_tree().process_frame
	var result: Dictionary=pending.get(id,{}).get("result",{})
	pending.erase(id)
	return result if not result.is_empty() else {"ok":false,"message":"暂时没有收到回复，请稍后再试。"}
func close() -> void:
	var was_connected:=connected
	connected=false;connecting=false;socket.close(1000,"Leaving");socket.poll();socket=WebSocketPeer.new()
	if was_connected:connection_lost.emit()
func _process(delta: float) -> void:
	if not connected and not connecting:return
	socket.poll()
	var state:=socket.get_ready_state()
	if state==WebSocketPeer.STATE_OPEN:
		if not handshake_sent:
			handshake_sent=true;send({"type":"hello","build":get_meta("build",Release.BUILD),"protocol":Release.PROTOCOL})
		while socket.get_available_packet_count()>0:
			var data:=Codec.decode(socket.get_packet())
			match str(data.get("type","")):
				"welcome":connected=true;connecting=false
				"update_required":required_version=str(data.get("version",""));connecting=false;connected=false;socket.close();update_required.emit(required_version)
				"result":
					var id:=str(data.get("id",""))
					var result: Dictionary=data.get("result",{})
					if pending.has(id):pending[id].result=result;pending[id].done=true
					command_result.emit(id,result)
				"snapshot":snapshot_received.emit(data)
			message_received.emit(data)
		heartbeat+=delta
		if heartbeat>10:heartbeat=0;send({"type":"ping"})
	elif state==WebSocketPeer.STATE_CLOSED:
		var notify:=connected
		connected=false;connecting=false
		if notify:connection_lost.emit()
