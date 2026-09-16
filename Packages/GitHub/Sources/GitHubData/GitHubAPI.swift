import Foundation
import GitHubDomain
import NetworkingDomain

struct GitHubAPI {
    let networking: NetworkingService

    func pages<Page: Decodable, Item>(
        _ type: Page.Type,
        path: String,
        token: GitHubAppAccessToken,
        query: [URLQueryItem] = [],
        items: (Page) -> [Item]
    ) async throws -> [Item] {
        var result: [Item] = []
        var page = 1
        while true {
            try Task.checkCancellation()
            let request = request(
                path: path, token: token,
                query: query + [
                    URLQueryItem(name: "per_page", value: "100"), URLQueryItem(name: "page", value: String(page))
                ])
            let response = await networking.load(type, from: request)
            if let limit = GitHubRateLimitError(response: response.httpURLResponse) { throw limit }
            let decoded = try response.map(\.value)
            let batch = items(decoded)
            result.append(contentsOf: batch)
            guard batch.count == 100 else {
                return result
            }
            page += 1
        }
    }

    func request(path: String, token: GitHubAppAccessToken, query: [URLQueryItem] = []) -> URLRequest {
        var components = URLComponents(
            url: URL(string: "https://api.github.com")!.appending(path: path),
            resolvingAgainstBaseURL: false)!
        components.queryItems = query.isEmpty ? nil : query
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token.rawValue)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.timeoutInterval = 30
        return request
    }
}
