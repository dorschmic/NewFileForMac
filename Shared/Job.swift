import Foundation

/// Ein Auftrag, den die Finder-Extension an die Haupt-App schickt.
///
/// Swift erzeugt `Codable` für Enums mit assoziierten Werten automatisch.
/// Transportiert wird der Auftrag als JSON (Base64URL) in einer URL:
///     newfileformac://job?data=eyJuZXdGaWxlIjp7…
/// Die Extension öffnet diese URL, macOS startet bei Bedarf die App und
/// übergibt sie an `AppDelegate.application(_:open:)`.
enum Job: Codable, Equatable {
    case newFile(template: String, directory: String)
    case convert(files: [String], targetExtension: String)

    static let urlScheme = "newfileformac"

    func url() throws -> URL {
        let json = try JSONEncoder().encode(self)
        var components = URLComponents()
        components.scheme = Self.urlScheme
        components.host = "job"
        components.queryItems = [URLQueryItem(name: "data", value: json.base64URLEncodedString())]
        guard let url = components.url else { throw URLError(.badURL) }
        return url
    }

    init?(url: URL) {
        guard url.scheme == Self.urlScheme,
              let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                  .queryItems?.first(where: { $0.name == "data" })?.value,
              let json = Data(base64URLEncoded: value),
              let job = try? JSONDecoder().decode(Job.self, from: json)
        else { return nil }
        self = job
    }
}

extension Data {
    /// Base64 ohne `+`, `/` und `=` – sicher in URLs.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        s += String(repeating: "=", count: (4 - s.count % 4) % 4)
        self.init(base64Encoded: s)
    }
}
