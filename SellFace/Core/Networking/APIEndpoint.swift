import Foundation

enum APIEndpoint {
    // Reads API_BASE_URL from Info.plist (set via xcconfig / build settings).
    // Debug builds default to localhost; Release builds require the key to be set.
    static let baseURL: String = {
        if let url = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !url.isEmpty, url != "$(API_BASE_URL)" {
            return url
        }
        #if DEBUG
        return "http://localhost:8000"
        #else
        // Set API_BASE_URL in your Release xcconfig before shipping.
        fatalError("API_BASE_URL is not set in Info.plist for Release builds")
        #endif
    }()

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
