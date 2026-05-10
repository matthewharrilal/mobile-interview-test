// EditorialShaders.metal
// Metal shader functions invoked from SwiftUI via `.layerEffect(...)`.
// Compiled into the default metallib by Xcode's Metal compiler so the
// SwiftUI `ShaderLibrary.default[<name>]` lookup resolves them.
//
// Cohesion-supplemental: applied to NON-MATCHED-GEOMETRY surfaces only
// (currently `BrandedImagePlaceholder` skeleton fill). The shader runs
// CoreAnimation-side at the display's native refresh rate and never
// touches a `.matchedTransitionSource` or `matchedGeometryEffect` view.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Soft skeleton-shimmer: returns the source pixel modulated by a slow
// horizontal gradient sweep parameterised by `time`. The amplitude is
// kept very low (±0.06) so the shimmer reads as "this region is
// loading" rather than as a cosmetic decoration.
//
// Signature matches SwiftUI's `.layerEffect(_:maxSampleOffset:isEnabled:)`
// requirements: (float2 position, SwiftUI::Layer layer, ...args).
[[ stitchable ]]
half4 skeletonShimmer(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float time
) {
    half4 color = layer.sample(position);
    float u = position.x / max(size.x, 1.0);
    // Sine wave swept by `time`; period = ~1.6s for a calm cadence.
    float phase = sin((u - time * 0.6) * 6.2831853);
    half modulation = (half)(0.06 * phase);
    return half4(color.rgb + modulation, color.a);
}
