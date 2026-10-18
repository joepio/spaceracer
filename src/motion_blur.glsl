#[compute]
#version 450
// Per-pixel motion blur from Godot's velocity buffer. Pixels that move with
// the camera (the player's own craft) have no velocity and stay sharp; the
// track and city streak along their own screen motion.
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba16f, set = 0, binding = 0) uniform restrict image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D source;
layout(set = 0, binding = 2) uniform sampler2D velocity;
layout(rgba16f, set = 0, binding = 3) uniform restrict writeonly image2D source_image;
layout(push_constant, std430) uniform Params {
	vec2 size;
	float scale;    // shutter time / frame time, times strength
	float max_px;   // longest streak in pixels
	float copy;     // 1: first pass, copy the frame into the source texture
	float pad0;
	float pad1;
	float pad2;
} p;

const int TAPS = 12;

void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	if (px.x >= int(p.size.x) || px.y >= int(p.size.y)) return;
	if (p.copy > .5) {
		imageStore(source_image, px, imageLoad(color_image, px));
		return;
	}
	vec2 uv = (vec2(px) + .5) / p.size;
	vec4 original = textureLod(source, uv, 0.);
	vec2 v = textureLod(velocity, uv, 0.).xy * p.scale;
	float len = length(v * p.size);
	if (len < .75) {
		imageStore(color_image, px, original);
		return;
	}
	if (len > p.max_px) v *= p.max_px / len;
	len = min(len, p.max_px);
	vec3 sum = original.rgb;
	float weight = 1.;
	for (int i = 0; i < TAPS; i++) {
		float t = (float(i) + .5) / float(TAPS) - .5;
		vec2 at = clamp(uv + v * t, vec2(.5) / p.size, vec2(1.) - vec2(.5) / p.size);
		// A tap landing on something that barely moves (the player's craft)
		// must not smear it over the road behind.
		float moving = length(textureLod(velocity, at, 0.).xy * p.scale * p.size);
		float w = smoothstep(.0, .5, moving / len);
		sum += textureLod(source, at, 0.).rgb * w;
		weight += w;
	}
	imageStore(color_image, px, vec4(sum / weight, original.a));
}
