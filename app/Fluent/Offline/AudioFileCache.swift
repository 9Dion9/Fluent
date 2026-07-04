//
//  AudioFileCache.swift
//  Fluent
//
//  Local file cache for TTS audio (CLAUDE.md §8: "App caches audio locally
//  ... so replays are free and offline"). Keyed the same way the Worker's R2
//  cache is (sha256 of lang+text) — not because the key needs to match the
//  server's, just because it's already a proven, collision-safe scheme.
//

import CryptoKit
import Foundation

enum AudioFileCache {
    private static let directory: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tts-audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func read(text: String, lang: String) -> Data? {
        try? Data(contentsOf: fileURL(text: text, lang: lang))
    }

    static func write(_ data: Data, text: String, lang: String) {
        try? data.write(to: fileURL(text: text, lang: lang))
    }

    private static func fileURL(text: String, lang: String) -> URL {
        let digest = SHA256.hash(data: Data("\(lang):\(text)".utf8))
        let key = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(key).appendingPathExtension("m4a")
    }
}
