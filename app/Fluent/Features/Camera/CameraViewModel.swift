//
//  CameraViewModel.swift
//  Fluent
//
//  Capture -> on-device Vision classify -> POST /v1/vision/identify -> WordCard
//  (CLAUDE.md §9). The label lookup vs. VLM fallback split lives server-side;
//  this just always sends the image alongside a confident-enough label so the
//  Worker can fall back automatically on an unmapped label.
//

import UIKit
import Vision
import os

@Observable
final class CameraViewModel {
    enum State: Equatable {
        case idle
        case identifying
        case caught(WordCard)
        case failed(String)
    }

    private(set) var state: State = .idle

    /// CLAUDE.md §9: "confidence < 0.4 or no mapping -> app sends the image".
    private static let confidenceThreshold: Float = 0.4
    private static let maxUploadDimension: CGFloat = 768

    private let apiClient: APIClient
    // TEMPORARY diagnostic logging (see docs/RUNBOOK.md "camera repeats last
    // object" investigation) — remove once the root cause is confirmed.
    private static let debugLog = Logger(subsystem: "com.fluent.app", category: "camera-debug")

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func reset() {
        state = .idle
    }

    func fail(_ message: String) {
        state = .failed(message)
    }

    func identify(_ image: UIImage) async {
        state = .identifying

        guard let jpeg = Self.resizedJPEG(image) else {
            state = .failed("Couldn't process that photo — try again.")
            return
        }

        let (label, confidence) = await Self.classify(image)
        let detectedLabel = confidence >= Self.confidenceThreshold ? label : nil
        Self.debugLog.debug(
            "capture: jpegBytes=\(jpeg.count) visionLabel=\(label ?? "nil") confidence=\(confidence) sentLabel=\(detectedLabel ?? "nil (image-only)")"
        )

        do {
            let word = try await apiClient.identifyVision(
                imageB64: jpeg.base64EncodedString(),
                detectedLabel: detectedLabel
            )
            Self.debugLog.debug("result: word=\(word.word) source=\(word.source ?? "nil") id=\(word.id)")
            state = .caught(word)
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? "Couldn't identify that — try again.")
        }
    }

    private static func classify(_ image: UIImage) async -> (label: String?, confidence: Float) {
        guard let cgImage = image.cgImage else { return (nil, 0) }
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            guard let top = request.results?.first else { return (nil, 0) }
            return (top.identifier.lowercased(), top.confidence)
        } catch {
            return (nil, 0)
        }
    }

    /// Downscales to <=768px on the long edge (CLAUDE.md §9) before base64-encoding
    /// for upload — the VLM fallback only ever needs a modest-resolution image.
    private static func resizedJPEG(_ image: UIImage) -> Data? {
        let longEdge = max(image.size.width, image.size.height)
        let scale = min(1, maxUploadDimension / longEdge)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
}
