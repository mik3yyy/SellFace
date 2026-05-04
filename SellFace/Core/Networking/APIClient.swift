import Foundation

final class APIClient {
    static let shared = APIClient()

    var mockMode = false

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        session = URLSession(configuration: config)
    }

    // Persistent device UUID — used as X-Device-ID on every request
    private var deviceId: String {
        if let stored = UserDefaults.standard.string(forKey: "sf_device_id") { return stored }
        if let identity = LocalStorageManager.shared.loadUserIdentity() {
            UserDefaults.standard.set(identity.id, forKey: "sf_device_id")
            return identity.id
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: "sf_device_id")
        return new
    }

    // Snake_case + ISO8601 (with fractional seconds) decoder
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let s = try container.decode(String.self)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: s) { return date }
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot parse date: \(s)")
        }
        return d
    }()

    private func addHeaders(to req: inout URLRequest) {
        req.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
    }

    func request<T: Decodable>(
        endpoint: APIEndpoint,
        body: Encodable? = nil,
        responseType: T.Type
    ) async throws -> T {
        guard !mockMode else { throw APIError.mockMode }
        guard let url = endpoint.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = endpoint.method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addHeaders(to: &req)

        if let body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            req.httpBody = try encoder.encode(body)
        }

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw APIError.noData }
            guard (200...299).contains(http.statusCode) else {
                let message = String(data: data, encoding: .utf8)
                if http.statusCode == 401 { throw APIError.unauthorized }
                throw APIError.serverError(http.statusCode, message)
            }
            return try Self.decoder.decode(T.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingFailed(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    func upload(endpoint: APIEndpoint, multipartData: MultipartFormData) async throws -> Data {
        guard !mockMode else { throw APIError.mockMode }
        guard let url = endpoint.url else { throw APIError.invalidURL }

        let boundary = UUID().uuidString
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        addHeaders(to: &req)
        req.httpBody = multipartData.build(boundary: boundary)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Upload failed"
            throw APIError.serverError(0, message)
        }
        return data
    }

    func downloadData(from url: URL) async throws -> Data {
        let (data, _) = try await session.data(from: url)
        return data
    }
}

struct MultipartFormData {
    private var parts: [(name: String, filename: String?, mimeType: String, data: Data)] = []

    mutating func append(data: Data, name: String, filename: String? = nil, mimeType: String = "application/octet-stream") {
        parts.append((name, filename, mimeType, data))
    }

    func build(boundary: String) -> Data {
        var body = Data()
        let crlf = "\r\n"
        for part in parts {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            var disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
            if let filename = part.filename { disposition += "; filename=\"\(filename)\"" }
            body.append("\(disposition)\(crlf)".data(using: .utf8)!)
            body.append("Content-Type: \(part.mimeType)\(crlf)\(crlf)".data(using: .utf8)!)
            body.append(part.data)
            body.append(crlf.data(using: .utf8)!)
        }
        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
        return body
    }
}
