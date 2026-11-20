// SPDX-License-Identifier: GPL-2.0-or-later
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;
    float strength;
};
layout(binding = 1) uniform sampler2D source;

void main()
{
    vec4 pixel = texture(source, qt_TexCoord0);
    float gray = dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722)) / max(pixel.a, 0.00001);
    // Shift midtones toward the tint while preserving black, white and alpha.
    vec3 color = gray + strength * gray * (1.0 - gray) * (2.0 * tint.rgb - 1.0);
    fragColor = vec4(color * pixel.a, pixel.a) * qt_Opacity;
}
