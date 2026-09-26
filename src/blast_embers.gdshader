// Adapted from ontola/growing-guns scripts/violence.gd, commit 68cd40fc080acf6b5016fa8fd49b909816bc3099.
// See third_party/growing-guns/README.md for provenance and port changes.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
uniform float anim = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 0.7, 0.3);
uniform float brightness = 6.0;
uniform float size_scale = 1.0;
uniform float elong_max = 8.0;
uniform float fade_start = 0.35;
varying float v_b;
void vertex() {
	vec3 travel = INSTANCE_CUSTOM.xyz;     // world target offset from blast centre
	float delay = INSTANCE_CUSTOM.w;
	float size = COLOR.r * size_scale;
	float elong = 1.0 + COLOR.g * (elong_max - 1.0);
	float grow_start = COLOR.b;
	float age = clamp((anim - delay) / max(1.0 - delay, 0.001), 0.0, 1.0);
	float prog = 1.0 - pow(1.0 - age, 2.0);   // decelerating
	float dist = length(travel);
	vec3 dir = dist > 0.0001 ? travel / dist : vec3(0.0, 1.0, 0.0);
	// Orthonormal frame with Y aligned to the travel direction.
	vec3 upv = abs(dir.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 ex = normalize(cross(upv, dir));
	vec3 ez = cross(dir, ex);
	float grow = mix(grow_start, 1.0, prog);
	vec3 v = VERTEX;
	v.x *= size * grow;
	v.z *= size * grow;
	v.y *= size * grow * mix(1.0, elong, prog);   // stretch into a streak/petal as it flies
	// Orient (mesh Y -> dir) then fly outward from centre to target.
	VERTEX = ex * v.x + dir * v.y + ez * v.z + travel * prog;
	v_b = (1.0 - smoothstep(fade_start, 1.0, age)) * COLOR.a;
}
void fragment() {
	ALBEDO = tint * brightness;   // additive (blend_add); HDR brightness blooms
	ALPHA = v_b;                  // fade modulates the added light
}
