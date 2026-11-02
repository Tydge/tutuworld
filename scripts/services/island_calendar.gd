extends RefCounted
const MONTH_DAYS := [31,28,31,30,31,30,31,31,30,31,30,31]
static func parts(seconds: float) -> Dictionary:
	var days:=maxi(0,int(floor(seconds/3600.0)))
	var year:=days/365+1
	var day:=days%365
	var month:=1
	for length in MONTH_DAYS:
		if day<int(length): break
		day-=int(length);month+=1
	var minute:=int(floor(fposmod(seconds,3600.0)*.4))
	return {"year":year,"month":month,"day":day+1,"hour":minute/60,"minute":minute%60}
static func text(seconds: float) -> String:
	var p:=parts(seconds)
	return "海岛年%d年%d月%d日  %02d:%02d"%[p.year,p.month,p.day,p.hour,p.minute]
