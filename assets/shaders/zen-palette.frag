/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Adapted from Zen Browser, commit 412731f37e567223097101d9fae9f9d364708b6b.
 * See licenses/README.md for source mapping and modification details.
 * Alternatively, the contents of this file may be used under the terms
 * of the GNU General Public License Version 3 or (at your option) later.
 * This file is free software: you may copy, redistribute and/or modify it
 * under those terms as published by the Free Software Foundation.
 * This file is distributed WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see https://www.gnu.org/licenses/.
 */
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec4 firstColor;
    vec4 secondColor;
    vec4 thirdColor;
    vec4 baseColor;
    float colorCount;
    float paletteOpacity;
    float grain;
};
// CSS screen blend followed by source-over, in premultiplied form.
vec4 screenLayer(vec4 back, vec3 color, float alpha) {
    vec3 b = back.a > 0.0 ? back.rgb / back.a : vec3(0.0);
    vec3 blended = 1.0 - (1.0-b)*(1.0-color);
    vec3 c = (1.0-back.a)*color + back.a*blended;
    return vec4(alpha*c + (1.0-alpha)*back.rgb, alpha+(1.0-alpha)*back.a);
}
float linearPosition(vec2 uv, float degrees) {
    float angle = radians(degrees);
    vec2 direction = vec2(sin(angle), -cos(angle));
    float length = abs(resolution.x*direction.x)+abs(resolution.y*direction.y);
    return 0.5+dot((uv-0.5)*resolution,direction)/max(length,1.0);
}
float radialPosition(vec2 uv, vec2 center) {
    vec2 farthest = max(center,1.0-center)*resolution;
    return length((uv-center)*resolution)/max(length(farthest),1.0);
}
// Mix both integer pixel coordinates before the avalanche. A sine/dot hash
// loses precision at desktop-sized coordinates and produces repeated diagonal
// patterns. Keep 24 output bits so conversion to float is exact and below 1.
float pixelGrain(uvec2 pixel) {
    uint hash = (pixel.x * 0x9e3779b9u) ^ (pixel.y * 0x85ebca6bu);
    hash ^= hash >> 16u;
    hash *= 0x7feb352du;
    hash ^= hash >> 15u;
    hash *= 0x846ca68bu;
    hash ^= hash >> 16u;
    return float(hash >> 8u) * (1.0 / 16777216.0);
}
void main() {
    vec2 uv = qt_TexCoord0;
    // Zen Linux opaque-window path: each color is blended with the toolbar
    // base using the opacity control before composing the background layers.
    vec3 c0 = floor(mix(baseColor.rgb,firstColor.rgb,paletteOpacity)*255.0+0.5)/255.0;
    vec3 c1 = floor(mix(baseColor.rgb,secondColor.rgb,paletteOpacity)*255.0+0.5)/255.0;
    vec3 c2 = floor(mix(baseColor.rgb,thirdColor.rgb,paletteOpacity)*255.0+0.5)/255.0;
    vec4 result = vec4(c0,1.0);
    if (colorCount > 1.5 && colorCount < 2.5) {
        float t = clamp(linearPosition(uv,-45.0),0.0,1.0);
        result = screenLayer(vec4(0.0),c1,1.0-t);
        result = screenLayer(result,c0,t);
    } else if (colorCount > 2.5) {
        result = screenLayer(vec4(0.0),c0,1.0-clamp((radialPosition(uv,vec2(0.0))-0.1)/0.6,0.0,1.0));
        result = screenLayer(result,c1,1.0-clamp(radialPosition(uv,vec2(0.95,0.0))/0.75,0.0,1.0));
        result = screenLayer(result,c2,1.0-clamp((linearPosition(uv,-5.0)-0.1)/0.7,0.0,1.0));
    }
    vec3 color = result.rgb + baseColor.rgb*(1.0-result.a);
    // Independent deterministic monochrome grain, ordinary alpha overlay
    // as on Zen's background (hard-light belongs only to its knob preview).
    float noise = pixelGrain(uvec2(floor(uv*resolution)));
    color = mix(color,vec3(noise),grain*0.16);
    fragColor = vec4(color,1.0)*qt_Opacity;
}
