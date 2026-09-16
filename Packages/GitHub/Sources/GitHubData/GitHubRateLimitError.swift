import Foundation

struct GitHubRateLimitError: LocalizedError {
    let retryDate: Date

    var errorDescription: String? {
        "GitHub API rate limit reached. Checks will resume after \(retryDate.formatted())."
    }

    init?(response: HTTPURLResponse?) {
        guard let response,
              response.statusCode == 429
                || (response.statusCode == 403
                        && (response.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0"
                                || response.value(forHTTPHeaderField: "Retry-After") != nil))
        else { return nil }
        if let seconds = response.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init) {
            retryDate = Date().addingTimeInterval(max(1, seconds))
        } else if let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap(Double.init) {
            retryDate = max(Date().addingTimeInterval(1), Date(timeIntervalSince1970: reset))
        } else {
            retryDate = Date().addingTimeInterval(60)
        }
    }
}
