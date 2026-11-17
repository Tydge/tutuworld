// Static interleaved gradient noise avoids the visible 4x4 checkerboard after
// spatial upscaling. Near and far use the same sample, with opposite coverage.
float vegetation_noise(vec2 pixel){return fract(52.9829189*fract(dot(floor(pixel),vec2(.06711056,.00583715))));}
