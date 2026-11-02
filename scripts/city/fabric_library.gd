extends RefCounted
## Geometry, monochrome fabric mask and dye are independent, shared resources.
const PATTERNS := {
	"solid":{"name":"纯色","texture":"","scale":1.0},
	"tartan":{"name":"暖格纹","texture":"res://assets/fabrics/tartan.svg","scale":12.0},
	"sprig":{"name":"花叶小点","texture":"res://assets/fabrics/sprig.svg","scale":3.2}}
static var shaders: Dictionary={}
static var textures: Dictionary={}
static func shader_for(cut: String) -> Shader:
	if shaders.has(cut): return shaders[cut]
	var clip: String={"vest":"if(v.z>0.12 && abs(v.x)<0.28) discard;","overalls":"if(v.y>0.20) discard;"}.get(cut,"")
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
RENDER_MODE
varying vec3 p; varying vec3 n; varying vec3 v;
uniform vec4 dye: source_color; uniform vec4 accent: source_color;
uniform sampler2D fabric_mask: filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool patterned=false; uniform float pattern_scale=12.0;
void vertex(){v=VERTEX;vec3 s=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));p=VERTEX*s;n=normalize(NORMAL/s);}
void fragment(){CLIP
vec3 fabric=dye.rgb;
if(patterned){vec3 w=pow(abs(normalize(n)),vec3(4));w/=max(w.x+w.y+w.z,.0001);float mask=texture(fabric_mask,p.zy*pattern_scale).r*w.x+texture(fabric_mask,p.xz*pattern_scale).r*w.y+texture(fabric_mask,p.xy*pattern_scale).r*w.z;fabric=mix(dye.rgb,accent.rgb,mask*.78);}
ALBEDO=fabric; ROUGHNESS=.96; SPECULAR=.25;}
""".replace("CLIP",clip).replace("RENDER_MODE","render_mode cull_disabled;" if cut in ["drape","bow"] else "")
	if cut=="bow": shader.code=shader.code.replace("ROUGHNESS=.96; SPECULAR=.25;","ROUGHNESS=.46; SPECULAR=.42;").replace("RENDER_MODE","render_mode cull_disabled;")
	shaders[cut]=shader
	return shader
static func material(item: Dictionary,cut: String="") -> ShaderMaterial:
	var fabric:=ShaderMaterial.new()
	fabric.shader=shader_for(cut)
	fabric.set_shader_parameter("dye",Color(item.get("color","629184")))
	fabric.set_shader_parameter("accent",Color(item.get("accent","f7e5bc")))
	var pattern: String=item.get("pattern","solid")
	var definition: Dictionary=PATTERNS.get(pattern,PATTERNS.solid)
	if definition.texture!="":
		if not textures.has(pattern): textures[pattern]=load(definition.texture)
		fabric.set_shader_parameter("fabric_mask",textures[pattern])
		fabric.set_shader_parameter("patterned",true)
		fabric.set_shader_parameter("pattern_scale",item.get("pattern_scale",definition.scale))
	return fabric
