import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingFailed(Error)
    case serverError(Int, String?)
    case networkError(Error)
    case unauthorized
    case mockMode

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noData: return "No data received"
        case .decodingFailed(let e): return "Decoding failed: \(e.localizedDescription)"
        case .serverError(let code, let msg): return "Server error \(code): \(msg ?? "Unknown")"
        case .networkError(let e): return e.localizedDescription
        case .unauthorized: return "Unauthorized"
        case .mockMode: return "Running in mock mode"
        }
    }
}
