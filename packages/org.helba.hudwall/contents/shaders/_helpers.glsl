// ---- shared math ------------------------------------------------------------
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    mat2 m = mat2(1.6, 1.2, -1.2, 1.6);
    for (int i = 0; i < 6; i++) { v += a * noise(p); p = m * p; a *= 0.5; }
    return v;
}
mat2 rot(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }
vec3 screenBlend(vec3 a, vec3 b) { return 1.0 - (1.0 - a) * (1.0 - b); }
vec3 vignette(vec3 c, vec2 uv) {
    vec2 d = uv - 0.5;
    return c * mix(1.0, 0.55, smoothstep(0.25, 0.85, dot(d, d) * 2.2));
}
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
// Image luminance, blurred by mip level. src is mipmapped.
float L(vec2 uv, float lod) { return luma(textureLod(src, uv, lod).rgb); }
vec2 gradL(vec2 uv, float lod, vec2 px) {
    return vec2(L(uv + vec2(px.x, 0), lod) - L(uv - vec2(px.x, 0), lod),
                L(uv + vec2(0, px.y), lod) - L(uv - vec2(0, px.y), lod));
}

// Chroma drift: only genuinely colored pixels (not grays, not near-black) get a small,
// slow hue swing. Phase depends on the pixel's own hue, so each color wanders on its own.
vec3 chromaDrift(vec3 c, vec2 uv, float amount) {
    if (amount <= 0.0) return c;
    vec3 hsv = rgb2hsv(c);
    float m = smoothstep(0.12, 0.40, hsv.y) * smoothstep(0.06, 0.2, hsv.z);
    float ph = hsv.x * 12.566 + time * 0.5 + seed * 6.0 + (uv.x + uv.y) * 1.3;
    // amount 1 swings about +-54 degrees; the default 0.55 is about +-30.
    hsv.x = fract(hsv.x + amount * 0.15 * m * sin(ph));
    return hsv2rgb(hsv);
}
