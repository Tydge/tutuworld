extends SceneTree
const Buffer=preload("res://scripts/services/motion_buffer.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:
 var buffer=Buffer.new()
 var deliveries: Array=[]
 for i in range(25):
  var sent: float=i*.1
  var delay: float=[.13,.17,.15,.12,.19][i%5]
  deliveries.append({"at":sent+delay,"tick":i*6,"row":{"position":[sent*4.76,0,0],"velocity":[4.76,0,0],"grounded":true,"generation":1,"yaw":0}})
 var index:=0;var previous:=-1.0;var max_step:=0.0;var stalls:=0
 for frame in range(155):
  var now: float=frame/60.0
  while index<deliveries.size() and float(deliveries[index].at)<=now:
   var packet: Dictionary=deliveries[index];buffer.push(packet.row,packet.tick,packet.at);index+=1
  var row: Dictionary=buffer.sample(now)
  if row.is_empty():continue
  var x: float=row.position[0]
  if previous>=0 and frame>40:
   check(x>=previous-.001,"Remote interpolation never reverses")
   max_step=maxf(max_step,x-previous)
   if x-previous<.001:stalls+=1
  previous=x
 check(max_step<.11,"Jittered 10 Hz packets render in small 60 Hz steps")
 check(stalls==0,"Interpolation buffer absorbs normal packet jitter")
 buffer.push({"position":[50,0,0],"velocity":[0,0,0],"generation":2},200,3.4)
 check(absf(buffer.sample(3.4).position[0]-50)<.001,"Teleport generation clears old interpolation")
 print("MOTION_BUFFER_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," max_step=",max_step," stalls=",stalls," failures=",failures)
 quit(0 if failures.is_empty() else 1)
func check(ok: bool,label_: String) -> void:
 checks+=1
 if not ok:failures.append(label_)
