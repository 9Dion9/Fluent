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
    /// False when STT genuinely can't run (denied permission, unsupported
    /// locale, no recognizer) — the mic button hides/disables per CLAUDE.md
    /// §13's degradation matrix ("STT unavailable -> voice button falls back
    /// to server STT or hides with a hint"). Since the recognizer already
    /// falls back to Apple's server recognition automatically, this only
    /// goes false when even that path is unavailable.
    private(set) var isAvailable = true

    private var recognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func configure(forTargetLang lang: String) {
        let localeID = lang == "de" ? "de-DE" : "en-US"
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID))
        isAvailable = recognizer?.isAvailable ?? false
    }

    func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            isAvailable = false
            return false
        }

        let micGranted = await AVAudioApplication.requestRecordPermission()
        if !micGranted { isAvailable = false }
        return micGranted
    }

    func startRecording() {
        guard let recognizer, recognizer.isAvailable else {
            isAvailable = false
            return
        }
        transcript = ""

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            isAvailable = false
            return
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
            return
        }
        isRecording = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.transcript = result.bestTranscription.formattedString
            }
            if error != nil || (result?.isFinal ?? false) {
                self.teardownEngine()
            }
        }
    }

    @discardableResult
    func stopRecording() -> String {
        recognitionRequest?.endAudio()
        teardownEngine()
        isRecording = false
        return transcript
    }

    private func teardownEngine() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
    }
}
