extends RefCounted
## One shared recline, with the head rotating about the neck rather than detaching.
const BODY_ANGLE:=-85.0*PI/180.0
const HEAD_ANGLE:=10.0*PI/180.0
const MATTRESS_TOP:=.90
static func layout(profile: Resource) -> Dictionary:
	var body_basis:=Basis(Vector3.RIGHT,BODY_ANGLE)
	var head_basis:=body_basis*Basis(Vector3.RIGHT,HEAD_ANGLE)
	var head_position: Vector3=profile.neck_center+Basis(Vector3.RIGHT,HEAD_ANGLE)*(profile.head_center-profile.neck_center)
	var head_center: Vector3=body_basis*head_position
	var body_center: Vector3=body_basis*profile.body_center
	var body_vertical:=sqrt(pow(profile.body_radii.y*body_basis.y.y,2)+pow(profile.body_radii.z*body_basis.z.y,2))
	var head_vertical:=sqrt(pow(profile.head_radii.y*head_basis.y.y,2)+pow(profile.head_radii.z*head_basis.z.y,2))
	var support_root: float=MATTRESS_TOP+body_vertical-body_center.y+.012
	var pillow_top: float=maxf(1.12,support_root+head_center.y-head_vertical)
	var root_y: float=pillow_top+head_vertical-head_center.y
	var support_z: float=-(pow(profile.head_radii.y,2)*head_basis.y.z*head_basis.y.y+pow(profile.head_radii.z,2)*head_basis.z.z*head_basis.z.y)/head_vertical
	var root_z: float=-.60-head_center.z-support_z
	return {"root":Vector3(0,root_y,root_z),"head":head_position,"pillow_height":pillow_top-MATTRESS_TOP,"cover_height":root_y+body_center.y+body_vertical-.985+.045,"head_vertical":head_vertical,"head_support_z":support_z}
