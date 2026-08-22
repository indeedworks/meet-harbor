import Foundation

@MainActor
final class SignalingClient: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var events: [SignalingEvent] = []

    private var task: URLSessionWebSocketTask?
    private let decoder = JSONDecoder.remoteMeetingSignalingDecoder

    func connect(baseURLString: String, token: String, meetingNo: String) {
        disconnect()

        guard var components = URLComponents(string: baseURLString) else {
            return
        }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = "/ws/signaling"
        components.queryItems = [
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "meetingNo", value: meetingNo)
        ]
        guard let url = components.url else {
            return
        }

        let task = URLSession.shared.webSocketTask(with: url)
        self.task = task
        isConnected = true
        task.resume()
        receiveNext()
    }

    func send(type: String, payload: [String: String]) {
        var event = payload
        event["type"] = type
        guard let data = try? JSONSerialization.data(withJSONObject: event),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        task?.send(.string(json)) { _ in }
    }

    func disconnect() {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        isConnected = false
    }

    private func receiveNext() {
        task?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(.string(let text)):
                    self.appendEvent(text)
                    self.receiveNext()
                case .success(.data(let data)):
                    if let text = String(data: data, encoding: .utf8) {
                        self.appendEvent(text)
                    }
                    self.receiveNext()
                case .failure:
                    self.isConnected = false
                @unknown default:
                    self.receiveNext()
                }
            }
        }
    }

    private func appendEvent(_ text: String) {
        guard let data = text.data(using: .utf8),
              let event = try? decoder.decode(SignalingEvent.self, from: data) else {
            return
        }
        events.insert(event, at: 0)
        if events.count > 30 {
            events.removeLast(events.count - 30)
        }
    }
}

private extension JSONDecoder {
    static var remoteMeetingSignalingDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = DateParser.parse(string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        return decoder
    }
}
