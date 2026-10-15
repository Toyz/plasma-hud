#version 140
// Gate in: the window assembles from data cells. Rows near the middle arrive first,
// each cell on its own beat; a cell flashes data-cyan as it locks in and a thin gold
// rule rides the arrival front. progress runs 0 -> 1.

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
    vec2 id = floor(px / cell);
    vec2 local = fract(px / cell);

    // When this cell arrives (0..1): middle rows first, plus jitter.
    float due = abs(texcoord0.y - 0.5) * 1.1 * 0.6 + hash(id) * 0.4;
    float t = progress * 1.18;
    float here = smoothstep(due - 0.03, due + 0.05, t);
    float flash = (1.0 - smoothstep(0.0, 0.16, t - due)) * step(due - 0.03, t);

    vec4 c = texture(sampler, texcoord0);
    float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    const vec3 cyan = vec3(0.56, 0.89, 1.0);
    const vec3 gold = vec3(0.72, 0.58, 0.35);
    // Premultiplied alpha: scale every channel by presence, add glow inside the cell.
    c.rgb = mix(c.rgb, cyan * (0.35 + l) * c.a, flash * 0.7);
    float edge = step(0.88, max(local.x, local.y));
    c.rgb += cyan * edge * flash * 0.35 * c.a;
    // Gold rule at the arrival front (a horizontal band per row).
    float front = (1.0 - smoothstep(0.0, 0.025, abs(t - due))) * (1.0 - step(0.12, abs(local.y - 0.5)));
    c.rgb += gold * front * 0.6 * c.a;
    c *= here;
    fragColor = c * modulation;
}
