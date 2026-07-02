import Foundation

struct RemoteServerConfig: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let host: String
    let port: Int
    let sshUser: String?
    let hasPassword: Bool
    let keyPath: String?
    let group: String?

    /// Transient — never persisted in JSON, loaded from Keychain at runtime.
    var password: String?

    var keychainAccount: String { "server:\(name)" }

    var connectionString: String {
        let u = sshUser ?? NSUserName()
        return "\(u)@\(host):\(port)"
    }

    enum CodingKeys: String, CodingKey {
        case name, host, port, sshUser, hasPassword, keyPath, group
    }

    static let `default` = RemoteServerConfig(
        name: "",
        host: "",
        port: 22,
        sshUser: nil,
        hasPassword: false,
        keyPath: nil,
        group: nil
    )
}
