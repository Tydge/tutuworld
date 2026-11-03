// Shared two-color pattern sampling for clothing and the deformable bed quilt.
vec3 fabric_color(vec2 uv){
 float mask=patterned?texture(fabric_mask,uv).r:0.;
 return mix(dye.rgb,accent.rgb,mask*pattern_strength);
}
