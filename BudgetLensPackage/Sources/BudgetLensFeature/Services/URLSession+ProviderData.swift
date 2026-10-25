import Foundation

extension URLSession {
    func providerData(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ProviderFailure.serviceUnavailable }
            return (data, http)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw ProviderFailure.connection
        }
    }

    /// POSTs `body` as JSON and returns the reply bytes; failing HTTP statuses become `ProviderFailure`.
    func postJSON<Body: Encodable>(to url: URL, headers: [String: String], body: Body) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, http) = try await providerData(for: request)
        if let failure = ProviderStatusMapping.classify(status: http.statusCode, body: data) { throw failure }
        return data
    }
}
