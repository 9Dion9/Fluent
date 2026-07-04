//
//  TTSPlayer.swift
//  Fluent
//
//  Reply audio auto-play with a mute toggle (DESIGN.md §8). `TTSProvider`
//  seam (CLAUDE.md §2): PiperProvider via the Worker's R2-cached /v1/tts,
//  falling back to on-device AVSpeechSynthesizer whenever the gateway is
//  napping, offline, or the render otherwise fails — voice never hard-fails
//  (CLAUDE.md §8, §13).
//

import AVFoundation

@Observable
final class TTSPlayer {
    var isMuted = false

    private var audioPlayer: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func speak(text: String, lang: String) async {
        guard !isMuted, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if let cached = AudioFileCache.read(text: text, lang: lang), (try? playRemoteAudio(cached)) != nil {
            return // free, offline replay — no network touched (CLAUDE.md §8)
        }

        do {
            let url = try await apiClient.requestTTS(text: text, lang: lang)
            let (data, _) = try await URLSession.shared.data(from: url)
            AudioFileCache.write(data, text: text, lang: lang)
            try playRemoteAudio(data)
        } catch {
            speakOnDevice(text: text, lang: lang)
        }
    }

    private func playRemoteAudio(_ data: Data) throws {
        try configurePlaybackSession()
        let player = try AVAudioPlayer(data: data)
        audioPlayer = player
        player.play()
    }

    private func speakOnDevice(text: String, lang: String) {
        try? configurePlaybackSession()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: lang == "de" ? "de-DE" : "en-US")
        synthesizer.speak(utterance)
    }

    private func configurePlaybackSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: .duckOthers)
        try session.setActive(true)
    }
}
