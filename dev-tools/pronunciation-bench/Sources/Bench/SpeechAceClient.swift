import Foundation

public struct SpeechAceResult {
    public let score: Double?
    public let rawJSON: String?
}

public struct SpeechAceClient {

    public let apiKey: String
    public let session: URLSession
    private let endpoint: URL

    public init(
        apiKey: String,
        session: URLSession = .shared,
        endpoint: URL = URL(string: "https://api.speechace.co/api/scoring/text/v9/json")!
    ) {
        self.apiKey = apiKey
        self.session = session
        self.endpoint = endpoint
    }

    public func score(audio: Data, text: String) async -> SpeechAceResult {
        let request = buildRequest(audio: audio, text: text)
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return SpeechAceResult(score: nil, rawJSON: String(data: data, encoding: .utf8))
            }
            return Self.parse(responseData: data)
        } catch {
            return SpeechAceResult(score: nil, rawJSON: nil)
        }
    }

    public func buildRequest(audio: Data, text: String) -> URLRequest {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "dialect", value: "en-us"),
        ]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = Self.multipartBody(boundary: boundary, audio: audio, text: text)
        return req
    }

    static func multipartBody(boundary: String, audio: Data, text: String) -> Data {
        var body = Data()
        func append(_ s: String) { body.append(s.data(using: .utf8)!) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"text\"\r\n\r\n\(text)\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"user_audio_file\"; filename=\"clip.wav\"\r\n")
        append("Content-Type: audio/wav\r\n\r\n")
        body.append(audio)
        append("\r\n--\(boundary)--\r\n")
        return body
    }

    static func parse(responseData data: Data) -> SpeechAceResult {
        let raw = String(data: data, encoding: .utf8)
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let textScore = json["text_score"] as? [String: Any],
            let quality = textScore["quality_score"] as? Double
        else {
            return SpeechAceResult(score: nil, rawJSON: raw)
        }
        return SpeechAceResult(score: quality, rawJSON: raw)
    }
}
