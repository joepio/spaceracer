shader_type sky;

// Hot, hazy afternoon: dusty horizon, a large soft sun and thin wind-swept cirrus.
uniform vec3 top_color = vec3(.10, .30, .62);
uniform vec3 horizon_color = vec3(.95, .76, .52);
uniform vec3 sun_direction = vec3(.4, .5, .2);

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
float streaks(vec2 p) {
    float value = 0., weight = .55;
    for (int i = 0; i < 4; i++) {
        value += noise(p) * weight;
        p = p * 2.1 + vec2(5.3, 1.7);
        weight *= .5;
    }
    return value;
}
void sky() {
    vec3 ray = normalize(EYEDIR);
    float elevation = max(ray.y, 0.);
    vec3 sun_dir = normalize(sun_direction);
    float sun = max(dot(ray, sun_dir), 0.);
    // Warm dust scatter is strongest near the horizon and toward the sun.
    vec3 haze = mix(horizon_color, vec3(1., .82, .58), pow(sun, 6.) * .6);
    COLOR = mix(haze, top_color, pow(elevation, .55));
    COLOR = mix(COLOR, horizon_color * .82, smoothstep(.02, -.12, ray.y));
    COLOR += vec3(1., .78, .48) * (pow(sun, 24.) * .35 + pow(sun, 400.) * .9 + pow(sun, 3000.) * 5.);
    if (ray.y > .02) {
        // Long cirrus streaks stretched along one wind direction.
        vec2 p = ray.xz / (ray.y + .1);
        vec2 q = vec2(p.x * .35 + p.y * .2, p.y * 2.4 - p.x * .4) + vec2(3.1, 7.4);
        float shape = streaks(q);
        float cover = smoothstep(.58, .8, shape) * smoothstep(.02, .22, ray.y) * .42;
        vec3 cloud = mix(vec3(1., .86, .7), vec3(1.25, 1.18, 1.08), smoothstep(.6, .85, shape));
        COLOR = mix(COLOR, cloud, cover);
    }
}
