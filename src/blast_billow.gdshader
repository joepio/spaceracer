// Adapted from ontola/growing-guns scripts/violence.gd, commit 68cd40fc080acf6b5016fa8fd49b909816bc3099.
// See third_party/growing-guns/README.md for provenance and port changes.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float anim = 0.0;          // 0..1, tweened once per layer
uniform float is_fire = 0.0;
uniform float edge_power = 2.1;
uniform float lump_amount = 0.32;
uniform float growth_min = 0.35;
uniform float tail_power = 1.5;    // <1 = long lingering tail, >1 = quick fade
uniform float sky_mode = 0.0;      // 1 = persistent sky clouds (no blast fade)
// Blackout rounds crush this toward 0 (set via RenderingServer global):
// unshaded smoke/cloud bodies would otherwise keep their baked daytime
// grey and read as glowing blobs against the dark sky. Fire stays bright.
uniform float world_light_dim = 1.0;
// Hue for the (otherwise greyscale) smoke body — white = classic smoke,
// red = the colosseum's blood mist. Only the non-fire branch uses it.
uniform vec3 smoke_tint : source_color = vec3(1.0);
uniform vec3 warm_glow : source_color = vec3(1.0, 0.45, 0.12);
uniform vec3 fire_cool : source_color = vec3(1.0, 0.5, 0.16);
uniform vec3 fire_hot : source_color = vec3(1.0, 0.97, 0.86);
uniform float fire_glow_lo = 14.0;
uniform float fire_glow_hi = 65.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
varying float v_age;
varying float v_heat;
varying vec3 v_body;
varying float v_opk;
varying float v_shade;   // per-region darkness variation (free — reuses lump noise)
void vertex() {
	float seed = INSTANCE_CUSTOM.x;
	float delay = INSTANCE_CUSTOM.y;
	v_heat = INSTANCE_CUSTOM.z;
	v_body = COLOR.rgb;
	v_opk = COLOR.a;
	// Staggered local age so puffs don't all pop at once. Sky clouds use a
	// fixed hold age per puff (INSTANCE_CUSTOM.y) instead of the blast tween.
	if (sky_mode > 0.5) {
		v_age = clamp(delay, 0.0, 1.0);
	} else {
		v_age = clamp((anim - delay) * (1.0 + INSTANCE_CUSTOM.w) / max(1.0 - delay, 0.001), 0.0, 1.0);
	}
	// Per-instance lumpy displacement (seed varies every puff).
	float s = seed * 100.0;
	float a = sin(VERTEX.x * 6.3 + s) * sin(VERTEX.y * 5.1 + s * 1.7) * sin(VERTEX.z * 7.2 + s * 0.9);
	float b = sin(VERTEX.x * 13.0 + s * 2.1) * sin(VERTEX.z * 11.0 + s * 1.3);
	// Finer-frequency octave used only for shading so darkness varies across
	// the puff surface (mixed with the lump shape).
	float c = sin(VERTEX.x * 21.0 + s * 3.3) * sin(VERTEX.y * 18.0 + s * 2.1) * sin(VERTEX.z * 25.0 + s * 1.5);
	v_shade = (a * 0.7 + b * 0.3) * 0.55 + c * 0.45;
	VERTEX += NORMAL * (a * 0.7 + b * 0.3) * lump_amount;
	// Growth 0.35 -> 1.0 at a CONSTANT rate (linear — keeps expanding, no
	// ease-out settling at the end). The slow fade is the alpha's job.
	VERTEX *= mix(growth_min, 1.0, v_age);
}
void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float fres = pow(1.0 - facing, edge_power);
	float fade_in = smoothstep(0.0, 0.12, v_age);
	float t = clamp((v_age - 0.12) / 0.88, 0.0, 1.0);
	// Long lingering tail (tail_power < 1) but with a SOFT landing — the last
	// stretch eases gently to zero instead of dropping off a cliff at the end.
	float fade_out = pow(1.0 - t, tail_power) * (1.0 - smoothstep(0.5, 1.0, t));
	if (sky_mode > 0.5) {
		fade_in = 1.0;
		fade_out = 1.0;
	}
	ALPHA = v_opk * fade_in * fade_out * smoothstep(0.0, 0.85, facing);
	// Soft particles: dissolve where the puff meets solid geometry so it
	// doesn't slice into walls/ground with a hard polygon edge.
	float scene_d = texture(depth_tex, SCREEN_UV).r;
	if (CLIP_SPACE_FAR < 0.0) { scene_d = scene_d * 2.0 - 1.0; }
	vec4 vpos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_d, 1.0);
	float scene_z = (vpos.xyz / vpos.w).z;
	ALPHA *= clamp((VERTEX.z - scene_z) / 1.6, 0.0, 1.0);
	vec2 px_cell = floor(UV * vec2(8.0, 5.0));
	float cell_band = mod(px_cell.x + px_cell.y, 3.0) - 1.0;
	if (is_fire > 0.5) {
		float heat = clamp(v_heat + cell_band * 0.06, 0.0, 1.0);
		float age_cool = 1.0 - smoothstep(0.0, 0.75, v_age);
		float fire_band = clamp(heat * 0.6 + facing * 0.25 + age_cool * 0.15, 0.0, 1.0);
		// fire_band computed smoothly above (no hard banding).
		vec3 c0 = vec3(0.03, 0.025, 0.02);
		vec3 c1 = vec3(0.30, 0.09, 0.025);
		vec3 c2 = vec3(1.00, 0.24, 0.04);
		vec3 c3 = vec3(1.00, 0.62, 0.12);
		vec3 c4 = vec3(1.00, 0.95, 0.72);
		vec3 color = c0;
		color = mix(color, c1, smoothstep(0.05, 0.34, fire_band));
		color = mix(color, c2, smoothstep(0.30, 0.54, fire_band));
		color = mix(color, c3, smoothstep(0.52, 0.74, fire_band));
		color = mix(color, c4, smoothstep(0.74, 0.94, fire_band));
		ALBEDO = color * mix(0.45, 16.0, fire_band);
	} else {
		// Darkness varies across the surface — some patches near-black, some
		// lighter — for turbulent, non-uniform smoke.
		float shade = 0.45 + 0.85 * (v_shade * 0.5 + 0.5);
		shade = clamp(shade + cell_band * 0.05, 0.0, 1.0);
		float grey = dot(v_body, vec3(0.3333)) * shade * 0.42;
		grey = mix(grey, grey * 0.22, fres);
		if (sky_mode > 0.5) {
			vec3 warm = warm_glow * (0.18 + v_heat * 0.42) * (0.35 + fres * 0.65);
			grey = clamp(grey + warm.r * 0.55, 0.0, 1.0);
		}
		// Keep the upstream turbulent shading, with continuous gradients for close racing cameras.
		ALBEDO = vec3(grey * world_light_dim) * smoke_tint;
	}
}
