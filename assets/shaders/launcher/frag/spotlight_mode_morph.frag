#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec4 fillColor;
    vec2 mainCenter;
    vec2 mainSize;
    float mainRadius;
    vec2 button0Center;
    vec2 button1Center;
    vec2 button2Center;
    float button0Radius;
    float button1Radius;
    float button2Radius;
    float button0Blend;
    float button1Blend;
    float button2Blend;
    float button0BridgeRadius;
    float button1BridgeRadius;
    float button2BridgeRadius;
    float edgeSoftness;
} ubuf;

float roundedBoxDistance(vec2 point, vec2 halfSize, float radius)
{
    vec2 edgeDistance = abs(point) - halfSize + vec2(radius);
    return min(max(edgeDistance.x, edgeDistance.y), 0.0)
        + length(max(edgeDistance, vec2(0.0)))
        - radius;
}

float circleDistance(vec2 point, float radius)
{
    return length(point) - radius;
}

float capsuleDistance(vec2 point, vec2 start, vec2 end, float radius)
{
    vec2 fromStart = point - start;
    vec2 segment = end - start;
    float segmentLengthSquared = dot(segment, segment);
    float along = segmentLengthSquared > 0.001
        ? clamp(dot(fromStart, segment) / segmentLengthSquared, 0.0, 1.0)
        : 0.0;
    return length(fromStart - segment * along) - radius;
}

float smoothMinimum(float first, float second, float radius)
{
    if (radius <= 0.001)
        return min(first, second);

    float influence = max(radius - abs(first - second), 0.0) / radius;
    return min(first, second) - influence * influence * radius * 0.25;
}

void main()
{
    vec2 pixel = qt_TexCoord0 * ubuf.resolution;
    float surface = roundedBoxDistance(
        pixel - ubuf.mainCenter,
        ubuf.mainSize * 0.5,
        ubuf.mainRadius
    );

    vec2 mainBridgeAnchor = vec2(
        ubuf.mainCenter.x + ubuf.mainSize.x * 0.5
            - ubuf.mainRadius * 0.42,
        ubuf.mainCenter.y
    );

    surface = smoothMinimum(
        surface,
        circleDistance(pixel - ubuf.button0Center, ubuf.button0Radius),
        ubuf.button0Blend
    );
    if (ubuf.button0BridgeRadius > 0.001) {
        float bridge0 = capsuleDistance(
            pixel,
            mainBridgeAnchor,
            ubuf.button0Center,
            ubuf.button0BridgeRadius
        );
        surface = smoothMinimum(
            surface,
            bridge0,
            ubuf.button0BridgeRadius * 0.75
        );
    }

    surface = smoothMinimum(
        surface,
        circleDistance(pixel - ubuf.button1Center, ubuf.button1Radius),
        ubuf.button1Blend
    );
    if (ubuf.button1BridgeRadius > 0.001) {
        float bridge1 = capsuleDistance(
            pixel,
            ubuf.button0Center,
            ubuf.button1Center,
            ubuf.button1BridgeRadius
        );
        surface = smoothMinimum(
            surface,
            bridge1,
            ubuf.button1BridgeRadius * 0.75
        );
    }

    surface = smoothMinimum(
        surface,
        circleDistance(pixel - ubuf.button2Center, ubuf.button2Radius),
        ubuf.button2Blend
    );
    if (ubuf.button2BridgeRadius > 0.001) {
        float bridge2 = capsuleDistance(
            pixel,
            ubuf.button1Center,
            ubuf.button2Center,
            ubuf.button2BridgeRadius
        );
        surface = smoothMinimum(
            surface,
            bridge2,
            ubuf.button2BridgeRadius * 0.75
        );
    }

    // Strong smooth unions make the necks legible, but their mathematical
    // field can otherwise swell beyond the original pill height. Intersecting
    // the unified field with this horizontal band preserves the reference's
    // constant outer height while retaining the inward gooey waists.
    float verticalBand = abs(pixel.y - ubuf.mainCenter.y)
        - ubuf.mainRadius;
    surface = max(surface, verticalBand);

    float alpha = 1.0 - smoothstep(
        -ubuf.edgeSoftness,
        ubuf.edgeSoftness,
        surface
    );
    fragColor = ubuf.fillColor * alpha * ubuf.qt_Opacity;
}
