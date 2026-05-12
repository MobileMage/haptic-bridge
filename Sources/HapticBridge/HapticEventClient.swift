import Foundation

final class HapticEventClient {

    static let shared = HapticEventClient()

    private var host = "127.0.0.1"
    private var port = 49374
    private var verbose = false
    private let queue = DispatchQueue(label: "com.haptic-bridge.client", qos: .userInteractive)

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 0.4
        config.timeoutIntervalForResource = 0.6
        config.waitsForConnectivity = false
        config.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: config)
    }()

    private lazy var encoder = JSONEncoder()

    private init() {}

    func configure(host: String, port: Int, verbose: Bool) {
        self.host = host
        self.port = port
        self.verbose = verbose
    }

    func send(_ event: HapticEvent) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard let url = URL(string: "http://\(self.host):\(self.port)/haptic"),
                  let body = try? self.encoder.encode(event) else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body

            self.session.dataTask(with: request) { _, _, error in
                if let error = error, self.verbose {
                    NSLog("[HapticBridge] forward failed: \(error.localizedDescription)")
                }
            }.resume()
        }
    }
}
