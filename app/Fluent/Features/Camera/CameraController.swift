//
//  CameraController.swift
//  Fluent
//
//  Thin AVCaptureSession wrapper: back camera, still-photo capture only (no
//  continuous frame classification — CLAUDE.md §9's "capture -> classify"
//  pipeline runs Vision on one still per tap, not every frame).
//

import AVFoundation
import UIKit

@Observable
final class CameraController: NSObject {
    let session = AVCaptureSession()

    private(set) var isAuthorized = false
    private(set) var lastErrorMessage: String?

    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "fluent.camera.session")
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?

    /// Requests camera permission if needed, then configures and starts the session.
    /// Returns false (and sets `lastErrorMessage`) if permission was denied or no
    /// back camera exists — the view shows a degraded state instead of a blank preview.
    @discardableResult
    func start() async -> Bool {
        let granted = await ensureAuthorized()
        isAuthorized = granted
        guard granted else {
            lastErrorMessage = "Camera access is off — turn it on in Settings to spot objects around you."
            return false
        }

        guard configureSessionIfNeeded() else {
            lastErrorMessage = "Couldn't find a camera on this device."
            return false
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [session] in
                if !session.isRunning { session.startRunning() }
                continuation.resume()
            }
        }
        return true
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Captures one still image. Resolves `nil` if capture failed.
    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }
                Task { @MainActor in
                    self.photoContinuation = continuation
                }
                let settings = AVCapturePhotoSettings()
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private func ensureAuthorized() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func configureSessionIfNeeded() -> Bool {
        guard session.inputs.isEmpty else { return true } // already configured

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device)
        else {
            return false
        }

        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()
        return true
    }
}

extension CameraController: @preconcurrency AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        Task { @MainActor in
            photoContinuation?.resume(returning: image)
            photoContinuation = nil
        }
    }
}
