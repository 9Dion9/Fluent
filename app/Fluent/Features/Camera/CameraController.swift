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
    ///
    /// Deliberately does NOT hop to `sessionQueue` here (unlike `start()`/`stop()`,
    /// which block and belong off the main thread) — `capturePhoto(with:delegate:)`
    /// is safe to call directly, and calling it matters, since this method runs on
    /// MainActor (the project's default isolation): storing `photoContinuation`
    /// synchronously *before* the call, on the same actor, is what guarantees the
    /// delegate callback below can never fire before it's stored. An earlier
    /// version stored it via a separately-scheduled `Task { @MainActor in ... }`
    /// after already starting the capture — a real race where a fast camera
    /// response could fire the delegate while `photoContinuation` was still nil,
    /// silently dropping the result and leaving the `await` hung forever.
    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            photoContinuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
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

        // Set once, here, not per-capture: re-setting videoRotationAngle on an
        // already-active connection right before each capturePhoto() call was
        // the likely cause of every shot after the first coming back as a
        // frozen repeat of the first frame — repeatedly nudging the
        // connection's rotation appears to disrupt the sensor pipeline from
        // ever latching a fresh buffer for subsequent requests. Without this,
        // AVCapturePhotoOutput's connection also defaults to landscape framing
        // (every still rotated 90° from the portrait viewfinder), which was a
        // second, separate reason a VLM could misidentify an object.
        if let connection = photoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        return true
    }
}

extension CameraController: @preconcurrency AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // An errored capture's `photo` can carry stale/unusable sensor data —
        // treat it as a failed shot rather than risk resolving with it.
        let image = error == nil ? photo.fileDataRepresentation().flatMap { UIImage(data: $0) } : nil
        Task { @MainActor in
            photoContinuation?.resume(returning: image)
            photoContinuation = nil
        }
    }
}
