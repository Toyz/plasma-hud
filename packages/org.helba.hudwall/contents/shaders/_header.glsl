#version 440
// Shared uniform block for every FX pass. ShaderEffect maps QML properties by name.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float intensity;
    float hasImage;
    float seed;
    vec2 resolution;   // this screen, logical px
    vec4 span;         // xy: this screen's offset in the span, zw: span size
    vec4 accent;
    vec4 accent2;
    float chroma;      // global color-drift amount, stacked on every effect
};
layout(binding = 1) uniform sampler2D src;
