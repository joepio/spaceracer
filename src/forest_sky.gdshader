shader_type sky;

// Static procedural cloud deck: shared sky/radiance across all split-screen views.
uniform vec3 top_color = vec3(.07, .38, .8);
uniform vec3 horizon_color = vec3(.5, .78, .95);
uniform vec3 sun_direction = vec3(.4, .8, .2);

float hash(highp vec2 p) {
    highp vec3 q = fract(vec3(p.xyx) * .1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}
float noise(vec2 p) {
    vec2 cell = floor(p), f = fract(p);
    f = f * f * (3. - 2. * f);
    return mix(mix(hash(cell), hash(cell + vec2(1., 0.)), f.x),
               mix(hash(cell + vec2(0., 1.)), hash(cell + vec2(1., 1.)), f.x), f.y);
}
float cloud_noise(vec2 p) {
    float value = 0., weight = .52;
    for (int i = 0; i < 5; i++) {
        value += noise(p) * weight;
        p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + vec2(13.1, 7.7);
        weight *= .48;
    }
    return value;
}
void sky() {
    vec3 ray = normalize(EYEDIR);
    float elevation = max(ray.y, 0.);
    COLOR = mix(horizon_color, top_color, pow(elevation, .48));
    float sun = max(dot(ray, normalize(sun_direction)), 0.);
    COLOR += vec3(1., .86, .62) * (pow(sun, 80.) * .24 + pow(sun, 1800.) * 4.);
    // Project onto a high cloud plane; soften its distant edge into the horizon.
    if (ray.y > .025) {
        vec2 p = ray.xz / (ray.y + .12) * 1.6 + vec2(4.8, 2.1);
        float shape = cloud_noise(p);
        float coverage = smoothstep(.43, .61, shape) * smoothstep(.025, .16, ray.y);
        float silver = smoothstep(.50, .76, shape);
        vec3 cloud = mix(vec3(.62, .78, .98), vec3(1.4, 1.43, 1.4), silver);
        COLOR = mix(COLOR, cloud, coverage);
    }
}
