extends RefCounted
## Owner-only, fenced construction sessions. Only finish publishes a layout.
const Land=preload("res://scripts/building/parcels.gd")
const L=preload("res://scripts/building/layout.gd")
const Sites=preload("res://scripts/building/construction_sites.gd")
const Safety=preload("res://scripts/building/build_safety.gd")
const TTL_MS:=60000
var manager: Node
var leases: Dictionary={}
var notices: Dictionary={}
func public_sites() -> Dictionary:
	var result: Dictionary={}
	for id in leases:result[id]={"owner_id":leases[id].owner,"name":leases[id].name}
	return result
func sync_state() -> void:
	manager.state().building_sites=public_sites()
	for a in manager.actors.values():
		a.state.build_layout=manager.state().build_layout;a.state.icefield_build_layout=manager.state().icefield_build_layout;a.state.land_parcels=manager.state().land_parcels;a.state.building_sites=manager.state().building_sites
func owned_site(owner: String) -> String:
	for id in leases:
		if leases[id].owner==owner:return id
	return ""
func fail(message: String) -> Dictionary:return {"ok":false,"message":message}
func apply(id: String,verb: String,args: Dictionary) -> Dictionary:
	notices.clear()
	var a=manager.actors[id];var pawn=manager.pawns[id];var parcel: Variant=args.get("parcel_id","")
	if not parcel is String or Land.map_for(parcel)!=a.state.map_id:return fail("请选择当前岛上的地皮。")
	var map_id: String=a.state.map_id
	var layout_key:=Land.layout_key(map_id)
	var previous: Dictionary=manager.state()[layout_key]
	if verb=="build_begin":
		if not Land.owns(a.state,parcel) or Land.distance_to(parcel,pawn.position)>Land.REACH:return fail("请走到自己购买的地皮旁再建造。")
		if not a.job.is_empty() or not a.state.get("net_pose",{}).is_empty():return fail("请先结束当前互动。")
		if leases.has(parcel) or owned_site(id)!="":return fail("这块地皮已经处于施工状态。")
		leases[parcel]={"owner":id,"name":a.actor_name(),"token":Crypto.new().generate_random_bytes(16).hex_encode(),"revision":int(a.state.land_parcels.plots[parcel].revision),"expires":Time.get_ticks_msec()+TTL_MS}
		sync_state()
		# Plan every visitor's landing before changing a pawn, balance, job or lock.
		var destinations: Dictionary={};var reserved: Array=[]
		for other in manager.pawns:
			if other==id or manager.actors[other].state.map_id!=map_id or not Land.bounds(parcel).grow(.65).has_point(Vector2(manager.pawns[other].position.x,manager.pawns[other].position.z)):continue
			var point:=outside_landing(parcel,other,reserved)
			if point.is_empty():leases.erase(parcel);sync_state();return fail("地皮外暂时没有安全落脚点，请稍后再开工。")
			destinations[other]=point.position;reserved.append(point.position)
		for other in destinations:
			var actor=manager.actors[other];var visitor=manager.pawns[other]
			actor.execute({"verb":"cancel"});manager.release_all(other)
			manager.clear_home_bed(map_id,visitor)
			visitor.stand_up(destinations[other]);visitor.work_align_active=false;visitor.reset_network_motion()
			actor.state.net_pose={};actor.state.rest_mode="";actor.state.rest_bed="";actor.sleeping=false;actor.state.player_position=manager.vector_array(visitor.position)
			notices[other]="地皮主人开始施工，已将你送到地皮外的安全位置。"
		pawn.can_move=false;pawn.velocity=Vector3.ZERO;pawn.reset_network_motion()
		return {"ok":true,"message":"施工区域已关闭，确认完成后才会向大家展示修改。","lease":leases[parcel].token,"parcel_revision":leases[parcel].revision}
	var lease: Dictionary=leases.get(parcel,{})
	if lease.is_empty() or lease.owner!=id or args.get("lease","")!=lease.token:return fail("施工状态已经结束，请重新进入建造。")
	if lease.get("publishing",false) and verb!="build_ping":return fail("正在更新已确认的建筑，请稍等。")
	if verb=="build_ping":lease.expires=Time.get_ticks_msec()+TTL_MS;return {"ok":true,"message":""}
	if verb=="build_cancel":release(id);return {"ok":true,"message":"已放弃本次修改，地皮重新开放。"}
	if verb!="build_finish":return fail("未知施工操作。")
	var expected: Variant=args.get("expected_revision",-1)
	if not (expected is int or expected is float) or not is_finite(float(expected)) or float(expected)!=lease.revision or int(a.state.land_parcels.plots[parcel].revision)!=lease.revision:return fail("地皮版本已更新，请放弃本次施工后重新进入。")
	var payload: Variant=args.get("elements")
	if not payload is Array or payload.size()>4096:return fail("建造布局格式或容量不正确。")
	var candidate:=L.empty(map_id);candidate.next_id=int(previous.next_id)
	# Never accept client migration exemptions, prices, ownership or other parcels.
	var used: Dictionary={}
	for row in Land.outside(previous,parcel):used[row.id]=true;candidate.elements.append(row.duplicate(true))
	var id_map: Dictionary={}
	for value in payload:
		if not valid_row(value):return fail("物件记录格式不正确。")
		var old: String=value.id
		if id_map.has(old):return fail("物件编号重复。")
		var next:=old
		if used.has(next):
			next="build_%d"%candidate.next_id
			while used.has(next):candidate.next_id+=1;next="build_%d"%candidate.next_id
			candidate.next_id+=1
		id_map[old]=next;used[next]=true
	for value in payload:
		var row: Dictionary=value.duplicate(true);row.id=id_map[value.id]
		for field in ["wall","support"]:
			if row.get(field,"")!="":
				if field=="support" and row.get("type","")=="object" and row[field]=="ceiling:%d"%int(row.get("storey",0)) and preload("res://scripts/building/catalog.gd").mount(row)=="ceiling":continue
				if not id_map.has(row[field]):return fail("门窗或家具不能依附其他地皮。")
				row[field]=id_map[row[field]]
		candidate.elements.append(row)
	# Reserve above every submitted serial, including compressed floor/wall IDs.
	for row in candidate.elements:
		if row.id.begins_with("build_") and row.id.trim_prefix("build_").length()<=12 and row.id.trim_prefix("build_").is_valid_int():candidate.next_id=maxi(candidate.next_id,int(row.id.trim_prefix("build_"))+1)
	var checked:=L.validate(candidate)
	if not checked.ok:return checked
	var scope:=Land.validate_edit(a.state,parcel,checked.layout,lease.revision)
	if not scope.ok:return scope
	for row in checked.layout.elements:
		if row.id in id_map.values() and not Land.contains_row(parcel,row,checked.layout):return fail("请将所有建筑留在当前地皮内。")
	for other in manager.pawns:
		if manager.actors[other].state.map_id==map_id and not Safety.safe(previous,checked.layout,manager.pawns[other].position-Vector3.UP*Land.base_height(map_id)):return fail("角色正在使用这层地板或楼梯，请先离开后再确认完成。")
	manager.state()[layout_key]=checked.layout;manager.state().land_parcels.plots[parcel].revision+=1
	manager.state().building_revision=int(manager.state().get("building_revision",0))+1
	lease.publishing=true
	return {"ok":true,"message":"建造已完成，地图已更新，地皮重新开放。"}
func valid_row(value: Variant) -> bool:
	if not value is Dictionary or not value.get("id") is String or value.id.is_empty() or value.id.length()>64 or not value.get("type") is String:return false
	if value.type=="object" and not preload("res://scripts/building/catalog.gd").OBJECTS.has(value.get("kind","")):return false
	for field in ["kind","color","style","form","wall","support"]:
		if value.has(field) and not value[field] is String:return false
	for field in ["yaw","storey","axis","offset","support_level","mount_height"]:
		if value.has(field) and (not (value[field] is int or value[field] is float) or not is_finite(float(value[field])) or absf(float(value[field]))>1000000):return false
	return true
func outside_landing(parcel: String,id: String,reserved: Array) -> Dictionary:
	var rect:=Land.bounds(parcel);var p: Vector3=manager.pawns[id].position;var center:=rect.get_center()
	var map_id:=Land.map_for(parcel);var y:=Land.base_height(map_id)+.1
	var points: Array[Vector3]=[Vector3(clampf(p.x,rect.position.x,rect.end.x),y,rect.end.y+2.2),Vector3(clampf(p.x,rect.position.x,rect.end.x),y,rect.position.y-2.2),Vector3(rect.position.x-2.2,y,center.y),Vector3(rect.end.x+2.2,y,center.y)]
	points.sort_custom(func(a,b):return a.distance_squared_to(p)<b.distance_squared_to(p))
	for point in points:
		var landing: Dictionary=manager.safe_position(map_id,point,id,manager.pawns[id])
		if not landing.is_empty() and reserved.all(func(other):return other.distance_to(landing.position)>2.):return landing
	return {}
func release(id: String,force: bool=false) -> void:
	var parcel:=owned_site(id)
	if parcel!="" and leases[parcel].get("publishing",false) and not force:return
	if parcel!="":leases.erase(parcel)
	if manager.pawns.has(id):manager.pawns[id].can_move=true;manager.pawns[id].reset_network_motion()
	sync_state()
func refresh() -> void:
	for map_id in ["city","icefield"]:
		if manager.maps.has(map_id):Sites.sync(manager.maps[map_id],public_sites())
	for peer_id in manager.peers:
		var id: String=manager.peers[peer_id].character
		if id!="":
			manager.send_snapshot(peer_id)
			if notices.has(id):manager.send(peer_id,{"type":"event","event":{"type":"notice","message":notices[id],"ok":true}})
	notices.clear()
func expire() -> void:
	for parcel in leases.keys():
		if not leases[parcel].get("publishing",false) and Time.get_ticks_msec()>leases[parcel].expires:
			var id: String=leases[parcel].owner;release(id);notices[id]="施工连接已过期，本次修改未发布，地皮重新开放。";refresh()
