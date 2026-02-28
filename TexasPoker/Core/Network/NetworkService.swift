import Foundation

protocol NetworkServiceProtocol {
    func fetch<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func post<T: Decodable, U: Encodable>(_ endpoint: Endpoint, body: U) async throws -> T
}

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let headers: [String: String]?
    let queryItems: [URLQueryItem]?

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }

    init(
        path: String,
        method: HTTPMethod = .get,
        headers: [String: String]? = nil,
        queryItems: [URLQueryItem]? = nil
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
    }
}

final class NetworkService: NetworkServiceProtocol {
    static let shared = NetworkService()

    private let baseURL = "https://api.example.com"
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        self.encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func fetch<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let request = try buildRequest(for: endpoint)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    func post<T: Decodable, U: Encodable>(_ endpoint: Endpoint, body: U) async throws -> T {
        var request = try buildRequest(for: endpoint)
        request.httpBody = try encoder.encode(body)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    private func buildRequest(for endpoint: Endpoint) throws -> URLRequest {
        var components = URLComponents(string: baseURL + endpoint.path)
        components?.queryItems = endpoint.queryItems

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        endpoint.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw NetworkError.unauthorized
        case 404:
            throw NetworkError.notFound
        case 500...599:
            throw NetworkError.serverError
        default:
            throw NetworkError.unknown(httpResponse.statusCode)
        }
    }
}

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case serverError
    case unknown(Int)

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .unauthorized:
            return "Unauthorized"
        case .notFound:
            return "Not found"
        case .serverError:
            return "Server error"
        case .unknown(let code):
            return "Unknown error: \(code)"
        }
    }
}
