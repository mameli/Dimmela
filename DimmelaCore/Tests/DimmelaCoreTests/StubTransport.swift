import Foundation

/// Records requests and returns prepared replies: no network calls.
final class StubTransport: @unchecked Sendable {
    private(set) var requests: [URLRequest] = []
    var status = 200
    var reply = "Testo rifinito."

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let content = String(data: try JSONEncoder().encode(reply), encoding: .utf8)!
        let body = status == 200
            ? #"{"choices":[{"message":{"role":"assistant","content":"# + content + "}}]}"
            : #"{"error":{"message":"overloaded"}}"#
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }

    /// The text of the `role` message of request number `index`.
    func message(_ index: Int, _ role: String) -> String? {
        guard let body = requests[index].httpBody,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let messages = json["messages"] as? [[String: String]]
        else { return nil }
        return messages.first { $0["role"] == role }?["content"]
    }
}

/// A folder of its own in the temporary directory, deleted when the test ends.
final class TemporaryFolder {
    let url = FileManager.default.temporaryDirectory.appending(path: "dimmela-tests-\(UUID().uuidString)")

    init() {
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    @discardableResult
    func write(_ path: String, _ text: String) -> URL {
        let file = url.appending(path: path)
        try! FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! text.write(to: file, atomically: true, encoding: .utf8)
        return file
    }
}
