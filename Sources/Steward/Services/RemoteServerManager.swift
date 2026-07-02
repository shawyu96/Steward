import Foundation
import AppKit

@MainActor
final class RemoteServerManager: ObservableObject {
    @Published var servers: [RemoteServerConfig] = []
    @Published var statuses: [String: Bool] = [:]

    // MARK: - Persistence

    private let saveURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Steward", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("servers.json")
    }()

    func load() {
        guard let data = try? Data(contentsOf: saveURL),
              let decoded = try? JSONDecoder().decode([RemoteServerConfig].self, from: data) else {
            servers = []; return
        }
        servers = decoded.map {
            var s = $0
            if s.hasPassword { s.password = KeychainHelper.read(account: s.keychainAccount) }
            return s
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(servers) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    func add(_ server: RemoteServerConfig, previousName: String? = nil) {
        if let old = previousName, old != server.name {
            KeychainHelper.delete(account: "server:\(old)") // ponytail: prevent keychain leak on rename
        }
        if let pw = server.password {
            KeychainHelper.store(account: server.keychainAccount, password: pw)
        }
        var clean = server
        clean.password = nil
        if let idx = servers.firstIndex(where: { $0.name == server.name }) {
            servers[idx] = clean
        } else {
            servers.append(clean)
        }
        save()
    }

    func remove(_ name: String) {
        KeychainHelper.delete(account: "server:\(name)")
        servers.removeAll { $0.name == name }
        statuses.removeValue(forKey: name)
        save()
    }

    // MARK: - Status

    func refreshAll() async {
        await withTaskGroup(of: (String, Bool).self) { group in
            for server in servers {
                group.addTask { (server.name, await self.ping(server)) }
            }
            for await (name, ok) in group {
                statuses[name] = ok
            }
        }
    }

    private func ping(_ server: RemoteServerConfig) async -> Bool {
        let pw = server.password ?? KeychainHelper.read(account: server.keychainAccount)
        let args = sshArgs(server, command: "echo ok", extra: ["-o", "ConnectTimeout=3"])
        return await runSSH(args, password: pw).exitCode == 0
    }

    // MARK: - Command Execution

    struct SSHResult { let exitCode: Int32; let output: String }

    func runCommand(_ server: RemoteServerConfig, _ command: String) async -> SSHResult {
        let pw = server.password ?? KeychainHelper.read(account: server.keychainAccount)
        let args = sshArgs(server, command: command, extra: ["-o", "ConnectTimeout=5"])
        return await runSSH(args, password: pw)
    }

    // MARK: - Open Terminal

    func openTerminal(_ server: RemoteServerConfig) {
        let user = server.sshUser ?? NSUserName()
        if server.hasPassword {
            guard let pw = server.password ?? KeychainHelper.read(account: server.keychainAccount) else { return }
            let host = server.host
            let port = server.port
            let (useBrace, safePw) = Self.tclSafe(pw)
            let setP = useBrace ? "set p {\(safePw)}" : "set p \"\(safePw)\""
            let script = """
            set timeout 15
            \(setP)
            spawn ssh -o StrictHostKeyChecking=no -p \(port) \(user)@\(host)
            expect {
                "password:" { send "$p\\r" }
                "(yes/no" { send "yes\\r"; exp_continue }
            }
            interact
            """
            let content = "#!/usr/bin/expect -f\n\(script)\n"
            let id = UUID().uuidString
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("steward-\(id).command")
            try? content.write(to: fileURL, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fileURL.path)
            NSWorkspace.shared.open(fileURL)
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                try? FileManager.default.removeItem(at: fileURL)
            }
        } else {
            guard let url = URL(string: "ssh://\(user)@\(server.host):\(server.port)") else { return }
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - SSH Helpers

    private func sshArgs(_ server: RemoteServerConfig, command: String, extra: [String] = []) -> [String] {
        let user = server.sshUser ?? NSUserName()
        var args: [String] = []
        args.append(contentsOf: extra)
        args.append(contentsOf: ["-p", "\(server.port)"])
        if server.password == nil { args += ["-o", "BatchMode=yes"] }
        if let kp = server.keyPath, !kp.isEmpty { args.append(contentsOf: ["-i", kp]) }
        args.append("\(user)@\(server.host)")
        args.append("--")
        args.append(command)
        return args
    }

    private func runSSH(_ arguments: [String], password: String?) async -> SSHResult {
        await withCheckedContinuation { cont in
            let task = Process()
            if let pw = password {
                task.executableURL = URL(fileURLWithPath: "/usr/bin/expect")
                task.arguments = ["-c", expectScript(sshArgs: arguments, password: pw)]
            } else {
                task.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
                task.arguments = arguments
            }
            let outPipe = Pipe()
            let errPipe = Pipe()
            task.standardOutput = outPipe
            task.standardError = errPipe
            task.terminationHandler = { proc in
                let out = (try? outPipe.fileHandleForReading.readToEnd()).flatMap {
                    String(data: $0, encoding: .utf8)
                } ?? ""
                let err = (try? errPipe.fileHandleForReading.readToEnd()).flatMap {
                    String(data: $0, encoding: .utf8)
                } ?? ""
                let output = (out + err).trimmingCharacters(in: .whitespacesAndNewlines)
                cont.resume(returning: SSHResult(exitCode: proc.terminationStatus, output: output))
            }
            do {
                try task.run()
            } catch {
                cont.resume(returning: SSHResult(exitCode: -1, output: "launch failed: \(error.localizedDescription)"))
            }
        }
    }

    private func expectScript(sshArgs: [String], password: String) -> String {
        let (useBrace, safePw) = Self.tclSafe(password)
        let setP = useBrace ? "set p {\(safePw)}" : "set p \"\(safePw)\""
        let cmd = sshArgs.joined(separator: " ")
        return """
        set timeout 15
        \(setP)
        spawn ssh \(cmd)
        expect "password:"
        send "$p\\r"
        expect eof
        catch wait result
        exit [lindex $result 3]
        """
    }

    /// Returns (true, pw) for Tcl `set p {pw}`, or (false, escaped) for `set p "escaped"`.
    /// `{...}` in Tcl does NOT nest, so we must NOT embed `}` in the password.
    private static func tclSafe(_ pw: String) -> (Bool, String) {
        if pw.contains("}") { return (false, Self.escapeTcl(pw)) }
        return (true, pw)
    }

    private static func escapeTcl(_ s: String) -> String {
        var r = s
        let m: [(String, String)] = [("\\", "\\\\"), ("\"", "\\\""), ("$", "\\$"), ("[", "\\["), ("]", "\\]")]
        for (a, b) in m { r = r.replacingOccurrences(of: a, with: b) }
        return r
    }
}
