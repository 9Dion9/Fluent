//
//  APIClient.swift
//  Fluent
//
//  Actor wrapping URLSession, generated against /shared contracts (CLAUDE.md §3).
//  This is the ONLY thing in the app that talks to the network — the app never
//  calls the inference gateway directly (CLAUDE.md §2).
//

import Foundation

nonisolated enum APIError: Error, LocalizedError, Sendable {
    case notAuthenticated
    case server(code: String, message: String, retryable: Bool)
    case transport(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Not signed in yet."
        case .server(_, let message, _): message
        case .transport: "Couldn't reach the server — check your connection."
        case .decoding: "Got an unexpected response from the server."
        }
    }
}

actor APIClient {
    static let shared = APIClient(baseURL: AppConfig.workerBaseURL)

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Set once per process after `/v1/auth/device` succeeds (or on launch, from Keychain).
    private var bearerToken: String?

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func setBearerToken(_ token: String?) {
        bearerToken = token
    }

    // MARK: Auth

    func authenticateDevice(pubid: String, secret: String) async throws -> DeviceAuthResponse {
        struct Body: Encodable {
            let devicePubid: String
            let deviceSecret: String
            enum CodingKeys: String, CodingKey {
                case devicePubid = "device_pubid"
                case deviceSecret = "device_secret"
            }
        }
        let response: DeviceAuthResponse = try await request(
            path: "/v1/auth/device",
            method: "POST",
            body: Body(devicePubid: pubid, deviceSecret: secret),
            authenticated: false
        )
        setBearerToken(response.token)
        return response
    }

    // MARK: Profile

    func getProfile() async throws -> Profile {
        try await request(path: "/v1/profile", method: "GET", body: Optional<String>.none)
    }

    func updateProfile(_ update: ProfileUpdate) async throws -> Profile {
        try await request(path: "/v1/profile", method: "PUT", body: update)
    }

    // MARK: Chat

    func sendChat(text: String, conversationID: String?, scenarioID: String? = nil) async throws -> ChatReply {
        try await request(
            path: "/v1/chat",
            method: "POST",
            body: ChatRequest(conversationID: conversationID, scenarioID: scenarioID, text: text)
        )
    }

    // MARK: TTS

    func requestTTS(text: String, lang: String) async throws -> URL {
        let response: TTSResponse = try await request(
            path: "/v1/tts",
            method: "POST",
            body: TTSRequest(text: text, lang: lang)
        )
        return response.audioURL
    }

    // MARK: SRS

    func getDueCards() async throws -> [Card] {
        try await request(path: "/v1/srs/due", method: "GET", body: Optional<String>.none)
    }

    func submitReviews(_ reviews: [ReviewSubmission]) async throws -> [ReviewResult] {
        try await request(path: "/v1/srs/review", method: "POST", body: reviews)
    }

    // MARK: Daily

    func getDaily() async throws -> DailySet {
        try await request(path: "/v1/daily", method: "GET", body: Optional<String>.none)
    }

    func completeDaily(date: String) async throws -> StreakUpdate {
        try await request(path: "/v1/daily/complete", method: "POST", body: DailyCompleteRequest(date: date))
    }

    // MARK: Quiz

    func getNextQuiz(types: [String] = []) async throws -> Quiz {
        var queryItems: [URLQueryItem] = []
        if !types.isEmpty {
            queryItems.append(URLQueryItem(name: "types", value: types.joined(separator: ",")))
        }
        return try await request(path: "/v1/quiz/next", method: "GET", body: Optional<String>.none, queryItems: queryItems)
    }

    // MARK: Core request plumbing

    private func request<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Body?,
        authenticated: Bool = true,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        var url = baseURL.appendingPathComponent(path)
        if !queryItems.isEmpty, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems = queryItems
            if let composedURL = components.url {
                url = composedURL
            }
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method

        if authenticated {
            guard let bearerToken else { throw APIError.notAuthenticated }
            urlRequest.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try encoder.encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.transport(URLError(.badServerResponse))
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorBody = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.server(
                    code: errorBody.error.code,
                    message: errorBody.error.message,
                    retryable: errorBody.error.retryable
                )
            }
            throw APIError.transport(URLError(.badServerResponse))
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}
