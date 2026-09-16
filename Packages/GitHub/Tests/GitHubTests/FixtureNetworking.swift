import Foundation
import NetworkingDomain

final class FixtureNetworking: NetworkingService {
    var requests: [URLRequest] = []
    var metadata: (URLRequest) -> HTTPURLResponse? = { _ in nil }
    var response: (URLRequest) throws -> Data

    init(response: @escaping (URLRequest) throws -> Data) { self.response = response }

    func data(from request: URLRequest) async -> NetworkResponse<Data> {
        requests.append(request)
        do {
            let data = try response(request)
            let http = metadata(request)
            if let http, http.statusCode >= 400 {
                return .failure(withError: NSError(domain: "HTTP", code: http.statusCode), httpURLResponse: http)
            }
            return .success(with: data, httpURLResponse: http)
        } catch {
            return .failure(withError: error)
        }
    }

    func load<T: Decodable>(_ valueType: T.Type, from request: URLRequest) async -> NetworkResponse<T> {
        await data(from: request).map { parameters in
            .success(with: try JSONDecoder().decode(valueType, from: parameters.value),
                     httpURLResponse: parameters.httpURLResponse)
        }
    }
}
