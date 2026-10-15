#!/bin/sh
# Assemble header + helpers + body for each FX pass and compile to .qsb, plus a
# matching vertex stage per uniform layout (GLES needs both stages to share a version).
# Sources: _header.glsl, _helpers.glsl, *.body, rd_step.glsl. Intermediates go to .build/.
set -eu
cd "$(dirname "$0")"
QSB=${QSB:-/usr/lib/qt6/bin/qsb}
flags='--glsl 300es,310es,320es,150,330 --hlsl 50 --msl 12'
mkdir -p .build

vert() { # $1 = file holding the uniform block, $2 = output name
    {
        echo '#version 440'
        echo 'layout(location = 0) in vec4 qt_Vertex;'
        echo 'layout(location = 1) in vec2 qt_MultiTexCoord0;'
        echo 'layout(location = 0) out vec2 qt_TexCoord0;'
        sed -n '/^layout(std140/,/^};/p' "$1"
        echo 'out gl_PerVertex { vec4 gl_Position; };'
        echo 'void main() { qt_TexCoord0 = qt_MultiTexCoord0; gl_Position = qt_Matrix * qt_Vertex; }'
    } > ".build/$2.vert"
    $QSB $flags -o "$2.vert.qsb" ".build/$2.vert"
}

vert _header.glsl fx
vert rd_step.glsl rd_step
for body in *.body; do
    name=${body%.body}
    cat _header.glsl _helpers.glsl "$body" > ".build/$name.frag"
    $QSB $flags -o "$name.frag.qsb" ".build/$name.frag"
done
cp rd_step.glsl .build/rd_step.frag
$QSB $flags -o rd_step.frag.qsb .build/rd_step.frag
echo "shaders built"
