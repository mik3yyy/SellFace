import Foundation

enum APIEndpoint {
    static let baseURL = "http://localhost:8000"

    case getStyles
    case createPersona
    case getPersonas
    case getPersona(id: String)
    case uploadPersonaImages(personaId: String)
    case createGenerationJob
    case getGenerationJob(id: String)
    case getPersonaResults(personaId: String, styleBundleId: String? = nil)
    case registerDeviceToken

    var path: String {
        switch self {
        case .getStyles: return "/styles"
        case .createPersona: return "/personas"
        case .getPersonas: return "/personas"
        case .getPersona(let id): return "/personas/\(id)"
        case .uploadPersonaImages(let id): return "/personas/\(id)/images"
        case .createGenerationJob: return "/generation-jobs"
        case .getGenerationJob(let id): return "/generation-jobs/\(id)"
        case .getPersonaResults(let id, _): return "/personas/\(id)/results"
        case .registerDeviceToken: return "/devices/register-token"
        }
    }

    var method: String {
        switch self {
        case .getStyles, .getPersonas, .getPersona, .getGenerationJob, .getPersonaResults:
            return "GET"
        default:
            return "POST"
        }
    }

    var url: URL? {
        var components = URLComponents(string: Self.baseURL + path)
        if case .getPersonaResults(_, let bundleId) = self, let bundleId {
            components?.queryItems = [URLQueryItem(name: "style_bundle_id", value: bundleId)]
        }
        return components?.url
    }
}
