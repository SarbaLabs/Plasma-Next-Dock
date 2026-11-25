// SPDX-License-Identifier: GPL-2.0-or-later
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 shift;
    vec4 tint;
};
layout(binding = 1) uniform sampler2D silhouette;
layout(binding = 2) uniform sampler2D softness;

void main()
{
    float outside = 1.0 - texture(silhouette, qt_TexCoord0).a;
    fragColor = tint * (qt_Opacity * outside * texture(softness, qt_TexCoord0 - shift).a);
}
