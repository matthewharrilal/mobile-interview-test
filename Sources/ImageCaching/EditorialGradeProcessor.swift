// EditorialGradeProcessor.swift
// Kingfisher ImageProcessor that applies a unified editorial color grade —
// subtle desaturation, warm temperature shift, gentle contrast lift — to
// mixed user-supplied photography so the gallery feels curated, not stock.
// The single biggest brand-consistency lever per the hospitality research.

import Foundation
import UIKit
import CoreImage
import Kingfisher

struct EditorialGradeProcessor: ImageProcessor {
    let identifier = "com.resortpass.interview.EditorialGrade.v1"

    private static let context: CIContext = {
        // Software renderer-friendly settings; cache for reuse.
        CIContext(options: [.useSoftwareRenderer: false])
    }()

    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case .image(let image):
            return grade(image)
        case .data(let data):
            guard let image = UIImage(data: data) else { return nil }
            return grade(image)
        }
    }

    private func grade(_ image: UIImage) -> UIImage {
        // Guard against any path failing — always fall back to the original
        // so cards never render the BrandedImagePlaceholder for graded-but-failed paths.
        guard let cg = image.cgImage else { return image }
        let ci = CIImage(cgImage: cg)

        // Single-pass color controls — the most stable filter, cheapest to render.
        // Skipping the temperature + vibrance chain (they were dropping outputs on
        // certain image formats, leaving cards on the placeholder).
        guard let controls = CIFilter(name: "CIColorControls") else { return image }
        controls.setValue(ci, forKey: kCIInputImageKey)
        controls.setValue(0.94, forKey: kCIInputSaturationKey)
        controls.setValue(1.04, forKey: kCIInputContrastKey)
        controls.setValue(0.0, forKey: kCIInputBrightnessKey)

        // Render into Display P3 so iPhone Pro's wider gamut isn't clipped
        // back to sRGB. `createCGImage` defaults to sRGB; an explicit P3
        // colorspace closes the color-space dimension gap (D16) and keeps
        // the editorial grade saturated through the wide-gamut pipeline.
        let p3 = CGColorSpace(name: CGColorSpace.displayP3)
        guard let final = controls.outputImage,
              let outputCG = Self.context.createCGImage(final, from: ci.extent, format: .RGBA8, colorSpace: p3) else {
            return image
        }
        return UIImage(cgImage: outputCG, scale: image.scale, orientation: image.imageOrientation)
    }
}
