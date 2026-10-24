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
}
