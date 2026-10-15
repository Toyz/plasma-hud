#version 440
// One Gray-Scott step. R = A, G = B. Feed/kill drift across space and time, so
// coral, spots and worms regions coexist and migrate. With useImage, seeding follows
// the image's contours and feed/kill follow its brightness.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float seed;
    float init;
    float dropOn;
    float useImage;
    vec2 texel;
    vec2 drop;
};
layout(binding = 1) uniform sampler2D prev;
layout(binding = 2) uniform sampler2D src;

float lum(vec2 uv, float lod) { return dot(textureLod(src, uv, lod).rgb, vec3(0.299, 0.587, 0.114)); }

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

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = texel.y / texel.x;
    if (init > 0.5) {
        float n = hash(floor(uv / texel / 5.0) + seed * 17.0);
        float b = step(0.86, n);
        if (useImage > 0.5) {
            // Seed along the image's contours.
            vec2 px = texel * 2.0;
            float e = length(vec2(lum(uv + vec2(px.x, 0), 1.0) - lum(uv - vec2(px.x, 0), 1.0),
                                  lum(uv + vec2(0, px.y), 1.0) - lum(uv - vec2(0, px.y), 1.0)));
            b = step(0.55, n) * step(0.12, e);
        }
        fragColor = vec4(1.0, b, 0.0, 1.0);
        return;
    }
    vec2 c = texture(prev, uv).rg;
    vec2 lap = -c
        + 0.2 * (texture(prev, uv + vec2(texel.x, 0)).rg + texture(prev, uv - vec2(texel.x, 0)).rg
               + texture(prev, uv + vec2(0, texel.y)).rg + texture(prev, uv - vec2(0, texel.y)).rg)
        + 0.05 * (texture(prev, uv + texel).rg + texture(prev, uv - texel).rg
                + texture(prev, uv + vec2(texel.x, -texel.y)).rg + texture(prev, uv + vec2(-texel.x, texel.y)).rg);

    vec2 q = uv * vec2(aspect, 1.0) * 1.4 + seed * 9.0;
    float f = mix(0.022, 0.058, noise(q + time * 0.004));
    float k = mix(0.050, 0.064, noise(q + 7.3 - time * 0.003));
    if (useImage > 0.5) {
        // Black areas are a kill zone so growth stays on the subject.
        float l = lum(uv, 3.0);
        f = mix(0.020, 0.055, l);
        k = mix(0.070, 0.057, smoothstep(0.05, 0.4, l));
    }
    float A = c.x, B = c.y;
    float r = A * B * B;
    A += 1.0 * lap.x - r + f * (1.0 - A);
    B += 0.5 * lap.y + r - (k + f) * B;

    if (dropOn > 0.5 && length((uv - drop) * vec2(aspect, 1.0)) < 0.01) B = 1.0;
    fragColor = vec4(clamp(A, 0.0, 1.0), clamp(B, 0.0, 1.0), 0.0, 1.0);
}
