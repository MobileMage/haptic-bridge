#if os(macOS)
import Foundation
import Network

final class HapticServer {

    private let port: NWEndpoint.Port
    private let player: HapticPlayer
    private let verbose: Bool
    private let decoder = JSONDecoder()
    private var listener: NWListener?

    init(port: UInt16, verbose: Bool, leadDelay: TimeInterval) {
        self.port = NWEndpoint.Port(rawValue: port) ?? 49374
        self.player = HapticPlayer(verbose: verbose, leadDelay: leadDelay)
        self.verbose = verbose
    }

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters, on: port)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                print("[haptic-bridge-host] listening on 127.0.0.1:\(self.port.rawValue)")
            case .failed(let error):
                FileHandle.standardError.write(Data("[haptic-bridge-host] listener failed: \(error)\n".utf8))
                exit(1)
            default: break
            }
        }
        listener.start(queue: .main)
        self.listener = listener
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .main)
        receive(connection, buffer: Data())
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            var combined = buffer
            if let data = data, !data.isEmpty { combined.append(data) }

            if let (headers, body) = self.splitHTTP(combined) {
                self.dispatch(headers: headers, body: body)
                self.respond(connection)
                return
            }

            if isComplete || error != nil {
                connection.cancel()
                return
            }

            self.receive(connection, buffer: combined)
        }
    }

    private func dispatch(headers: String, body: Data) {
        guard !body.isEmpty else { return }
        do {
            let event = try decoder.decode(HapticHostEvent.self, from: body)
            player.play(event)
        } catch {
            if verbose {
                FileHandle.standardError.write(Data("[haptic-bridge-host] decode failed: \(error)\n".utf8))
            }
        }
    }

    private func respond(_ connection: NWConnection) {
        let response = "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func splitHTTP(_ data: Data) -> (String, Data)? {
        let separator = Data("\r\n\r\n".utf8)
        guard let range = data.range(of: separator) else { return nil }
        let headerData = data.subdata(in: 0..<range.lowerBound)
        let bodyStart = range.upperBound
        var body = data.subdata(in: bodyStart..<data.count)

        guard let headers = String(data: headerData, encoding: .utf8) else { return nil }

        if let contentLength = parseContentLength(headers), body.count < contentLength {
            return nil // need more bytes
        } else if let contentLength = parseContentLength(headers), body.count > contentLength {
            body = body.subdata(in: 0..<contentLength)
        }

        return (headers, body)
    }

    private func parseContentLength(_ headers: String) -> Int? {
        for line in headers.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 && parts[0].lowercased() == "content-length" {
                return Int(parts[1])
            }
        }
        return nil
    }
}
#endif
