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
        guard let cg = image.cgImage else { return image }
        let ci = CIImage(cgImage: cg)

        // Step 1: gentle saturation pull-down + slight contrast lift.
        guard let controls = CIFilter(name: "CIColorControls") else { return image }
        controls.setValue(ci, forKey: kCIInputImageKey)
        controls.setValue(0.92, forKey: kCIInputSaturationKey)   // subtle desaturation
        controls.setValue(1.06, forKey: kCIInputContrastKey)     // gentle contrast lift
        controls.setValue(0.02, forKey: kCIInputBrightnessKey)   // a hair brighter
        guard let step1 = controls.outputImage else { return image }

        // Step 2: warm temperature shift (5500K → 5200K). Brings cool ocean
        // photos toward the editorial-warm look of luxury hospitality apps.
        guard let temperature = CIFilter(name: "CITemperatureAndTint") else { return image }
        temperature.setValue(step1, forKey: kCIInputImageKey)
        temperature.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
        temperature.setValue(CIVector(x: 5800, y: 8), forKey: "inputTargetNeutral")
        guard let step2 = temperature.outputImage else { return image }

        // Step 3: vibrance — protects skin tones while pulling back loud colors.
        guard let vibrance = CIFilter(name: "CIVibrance") else { return image }
        vibrance.setValue(step2, forKey: kCIInputImageKey)
        vibrance.setValue(0.12, forKey: "inputAmount")
        guard let final = vibrance.outputImage else { return image }

        guard let outputCG = Self.context.createCGImage(final, from: final.extent) else {
            return image
        }
        return UIImage(cgImage: outputCG, scale: image.scale, orientation: image.imageOrientation)
    }
}
