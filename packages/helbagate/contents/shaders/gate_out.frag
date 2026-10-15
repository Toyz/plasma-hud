#version 140
// Gate out: the window drains away like Data Drain. Cells lift upward on their own
// beat, top rows first, tinting toward data-cyan and shrinking as they go, leaving
// faint gold cell edges behind. progress runs 0 -> 1.

uniform sampler2D sampler;
uniform vec4 modulation;
uniform float progress;

in vec2 texcoord0;
out vec4 fragColor;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 size = vec2(textureSize(sampler, 0));
    vec2 px = texcoord0 * size;
    const float cell = 14.0;
    const vec3 cyan = vec3(0.56, 0.89, 1.0);
    const vec3 gold = vec3(0.72, 0.58, 0.35);

    // A cell's content moves up by `rise` pixels: look below for what lands here.
    float t = progress * 1.2;
    vec4 acc = vec4(0.0);
    for (int k = 0; k < 3; k++) {
        vec2 src = px + vec2(0.0, float(k) * cell);
        vec2 id = floor(src / cell);
        float due = texcoord0.y * 0.45 + hash(id) * 0.45;
        float lift = clamp((t - due) / 0.35, 0.0, 1.0);
        float rise = lift * lift * cell * 2.2;
        vec2 from = px + vec2(0.0, rise);
        if (floor(from.y / cell) != id.y) continue;
        vec2 local = fract(from / cell);
        float shrink = 0.5 * (1.0 - lift * 0.6);
        if (max(abs(local.x - 0.5), abs(local.y - 0.5)) > shrink) continue;
        vec4 c = texture(sampler, from / size);
        float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
        c.rgb = mix(c.rgb, cyan * (0.25 + l) * c.a, lift * 0.75);
        c *= 1.0 - lift;
        acc = max(acc, c);
    }
    // Faint gold grid where cells have left.
    vec2 g = fract(px / cell);
    float grid = step(0.93, max(g.x, g.y)) * smoothstep(0.1, 0.5, t) * (1.0 - smoothstep(0.7, 1.0, t));
    acc.rgb += gold * grid * 0.35;
    acc.a = max(acc.a, grid * 0.35);
    fragColor = acc * modulation;
}
