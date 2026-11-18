extends RefCounted
## Periodic world directions, continuous at midnight. The night key is moonlight,
## never a sun clamped just above the sea's horizon.
static func at_time(fraction: float) -> Dictionary:
	var t:=fposmod(fraction,1.);var phase: float=(t-.25)*TAU
	var sun:=Vector3(cos(phase)*.90,sin(phase)*.68,sin(phase)*.60).normalized()
	var moon: Vector3=-sun
	var solar:=smoothstep(-.06,.18,sun.y)
	var lunar:=smoothstep(.02,.30,moon.y)*(1.-solar)
	var direction: Vector3=sun if sun.y>=-.035 else moon
	return {"sun_direction":sun,"moon_direction":moon,"key_direction":direction,"solar":solar,"lunar":lunar,"energy":1.24*solar+.085*lunar,"specular":.70*solar+.035*lunar}
