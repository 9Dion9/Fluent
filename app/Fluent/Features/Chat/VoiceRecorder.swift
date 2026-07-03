//
//  VoiceRecorder.swift
//  Fluent
//
//  Hold-to-record -> on-device STT (CLAUDE.md §8). Uses SFSpeechRecognizer's
//  live buffer recognition so the transcript is ready the instant the user
//  releases, rather than a separate record-then-transcribe pass.
//

import AVFoundation
import Speech

@Observable
final class VoiceRecorder {
    private(set) var isRecording = false
    private(set) var transcript = ""
    /// False once we've established recording genuinely can't happen (mic or
    /// speech permission denied, no recognizer for this locale) — the mic
    /// button shows a hint per CLAUDE.md §13's degradation matrix ("STT
    /// unavailable -> voice button falls back to server STT or hides with a
    /// hint"). Starts `true`; only sours after a real failed attempt, since
    /// authorization status alone shouldn't hide the button pre-emptively.
    private(set) var isAvailable = true
    /// Set when the recognizer reports an error (e.g. no network for a locale
    /// with no on-device model) — surfaced in the UI instead of failing silently.
    private(set) var lastErrorMessage: String?

    private var recognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func configure(forTargetLang lang: String) {
        let localeID = lang == "de" ? "de-DE" : "en-US"
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID))
    }

    /// Starts recording, requesting mic/speech permission first if it hasn't
    /// been granted yet. Returns `false` (and sets `isAvailable = false`) if
    /// permission was denied or recording couldn't start for any reason.
    @discardableResult
    func startRecording() async -> Bool {
        guard !isRecording else { return true }

        guard await ensureAuthorized() else {
            isAvailable = false
            return false
        }
        guard let recognizer, recognizer.isAvailable else {
            isAvailable = false
            lastErrorMessage = "Speech recognition isn't available right now."
            return false
        }
        transcript = ""
        lastErrorMessage = nil

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            isAvailable = false
            return false
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let engine = AVAudioEngine()
        audioEngine = engine
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        // Captures `request` directly (not `self`) — SFSpeechAudioBufferRecognitionRequest.append
        // is safe to call from the real-time audio thread this tap runs on.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            isAvailable = false
            teardownEngine()
            return false
        }
        isRecording = true
        isAvailable = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // SFSpeechRecognitionTask's handler isn't guaranteed to fire on the
            // main thread — hop explicitly so @Observable's change tracking
            // (and therefore the SwiftUI view) actually sees these mutations.
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if let error {
                    self.lastErrorMessage = (error as NSError).localizedDescription
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.teardownEngine()
                }
            }
        }
        return true
    }

    @discardableResult
    func stopRecording() -> String {
        recognitionRequest?.endAudio()
        teardownEngine()
        isRecording = false
        return transcript
    }

    /// Checks current authorization and prompts for whichever permission
    /// hasn't been decided yet. Cheap (no UI) once both are already granted.
    private func ensureAuthorized() async -> Bool {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let speechAuthorized: Bool
        switch speechStatus {
        case .authorized:
            speechAuthorized = true
        case .notDetermined:
            speechAuthorized = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        default:
            speechAuthorized = false
        }
        guard speechAuthorized else { return false }

        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .undetermined:
            return await AVAudioApplication.requestRecordPermission()
        default:
            return false
        }
    }

    private func teardownEngine() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
    }
}
