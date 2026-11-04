extends Node3D
## A bounded number of looping voices; listeners follow the avatar, not camera zoom.
const Valley=preload("res://scripts/valley/valley_layout.gd")
var city: Node3D
var listener: AudioListener3D
var waves: AudioStreamPlayer3D
var gulls: AudioStreamPlayer3D
var creek: AudioStreamPlayer3D
var shore: PackedVector2Array=[]
var timer:=0.
var base_volumes: Dictionary={}
var updates:=0
func voice(id: String,volume: float,radius: float,reach: float) -> AudioStreamPlayer3D:
	var player:=AudioStreamPlayer3D.new();player.name=id;player.stream=load("res://assets/audio/ambient/"+id+".ogg");player.stream.loop=true;player.volume_db=volume;player.unit_size=radius;player.max_distance=reach;player.max_db=0.;player.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE;player.panning_strength=.7;player.attenuation_filter_cutoff_hz=3800.;player.attenuation_filter_db=-12.;player.doppler_tracking=AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED;add_child(player);base_volumes[player]=volume;player.play();return player
func _ready() -> void:
	listener=AudioListener3D.new();listener.name="PlayerAudioListener";add_child(listener);listener.make_current()
	waves=voice("ocean_waves",-13.,8.,62.);gulls=voice("seagulls",-13.,7.,48.)
	if city.map_id=="valley":creek=voice("creek",-13.,6.,34.)
	for i in range(65):var angle:=i*TAU/64.;shore.append(Vector2(cos(angle)*52.,sin(angle)*52.*.88))
	update_sources();update_listener()
func update_listener() -> void:
	if not is_instance_valid(city.bunny):return
	listener.global_position=city.bunny.get_global_transform_interpolated().origin+Vector3.UP*1.65
	if is_instance_valid(city.camera):listener.global_basis=Basis(Vector3.UP,city.camera.global_rotation.y)
func _process(delta: float) -> void:
	update_listener();timer+=delta
	if timer<.1:return
	timer=fmod(timer,.1);update_sources()
static func nearest_on(points: PackedVector2Array,p: Vector2) -> Vector2:
	var best:=points[0];var distance_:=INF
	for i in range(points.size()-1):
		var candidate:=Geometry2D.get_closest_point_to_segment(p,points[i],points[i+1]);var d:=p.distance_squared_to(candidate)
		if d<distance_:best=candidate;distance_=d
	return best
func ocean_point(p: Vector2) -> Vector3:
	if city.map_id=="valley":return Vector3(-13.,-.5,54.)
	var point:=nearest_on(shore,p)
	# The eastern construction island shares the same voice instead of adding
	# a decoder at every shore marker. The connector's inland edge is omitted.
	var site: Rect2=preload("res://scripts/building/site.gd").PAD
	var plot:=PackedVector2Array([site.position,Vector2(site.end.x,site.position.y),site.end,Vector2(site.position.x,site.end.y)])
	var east:=nearest_on(plot,p)
	if east.distance_squared_to(p)<point.distance_squared_to(p):point=east
	return Vector3(point.x,-.10,point.y)
func creek_point(p: Vector2) -> Vector3:
	var points:=PackedVector2Array()
	for z in range(-44,53,3):points.append(Vector2(Valley.river_x(z),z))
	var point:=nearest_on(points,p);return Vector3(point.x,Valley.water_level(point.y)+.12,point.y)
func update_sources() -> void:
	if not is_instance_valid(city.bunny):return
	var p:=Vector2(city.bunny.global_position.x,city.bunny.global_position.z);waves.global_position=ocean_point(p)
	if creek!=null:creek.global_position=creek_point(p)
	var bird_time:=gulls.get_playback_position();var between_calls: bool=bird_time<5. or (bird_time>14. and bird_time<22.) or (bird_time>27. and bird_time<37.) or bird_time>42.
	if between_calls or gulls.position==Vector3.ZERO:
		var anchors: Array=[Vector3(-13,5,47)] if city.map_id=="valley" else [Vector3(-24,5,-35),Vector3(18,5,40),Vector3(95,5,19),Vector3(156,5,19)]
		anchors.sort_custom(func(a,b):return Vector2(a.x,a.z).distance_squared_to(p)<Vector2(b.x,b.z).distance_squared_to(p));gulls.global_position=anchors[0]
	var indoors: float=city.interior_weight()
	for player in base_volumes:
		var night: float=0. if player!=gulls else 6.*(1.-city.ambient_day)
		player.volume_db=float(base_volumes[player])-indoors*12.-night
	updates+=1
func _exit_tree() -> void:
	# Release Vorbis playback before the outgoing map and audio server are torn down.
	for player in base_volumes:
		if is_instance_valid(player):player.stop();player.stream=null
	base_volumes.clear()
