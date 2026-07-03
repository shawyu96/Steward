import Foundation

/// File-based IPC for Hermes agent integration.
/// Steward watches ~/.steward/cmd.json. I write a command, Steward executes it.
/// ponytail: file watching + JSON, no timers, no networking.
@MainActor
func startIpcServer(serviceManager: ServiceManager, remoteServerManager: RemoteServerManager) {
    let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".steward")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let cmdPath = dir.appendingPathComponent("cmd.json")
    let resultPath = dir.appendingPathComponent("result.json")
    FileManager.default.createFile(atPath: cmdPath.path, contents: Data("{}".utf8))
    FileManager.default.createFile(atPath: resultPath.path, contents: Data("{}".utf8))

    let fd = open(cmdPath.path, O_EVTONLY)
    guard fd >= 0 else { return }
    let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .global(qos: .background))
    source.setEventHandler {
        Task { @MainActor in
            await handleCommand(cmdPath, resultPath: resultPath, sm: serviceManager, rsm: remoteServerManager)
        }
    }
    source.resume()
}

@MainActor
private func handleCommand(_ cmdPath: URL, resultPath: URL, sm: ServiceManager, rsm: RemoteServerManager) async {
    guard let data = try? Data(contentsOf: cmdPath),
          let cmd = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let action = cmd["action"] as? String else { return }

    let seq = cmd["seq"] as? Int ?? 0
    let result: [String: Any]

    switch action {
    case "get-state":
        result = [
            "services": sm.services.map { s in
                ["name": s.name, "status": s.status.rawValue, "uptime": s.uptimeSeconds ?? 0] as [String: Any]
            },
            "servers": rsm.servers.map { s in
                ["name": s.name, "host": s.host, "port": s.port, "online": rsm.statuses[s.name] ?? false] as [String: Any]
            },
        ]

    case "service":
        guard let name = cmd["name"] as? String, let op = cmd["op"] as? String else { return }
        if let svc = sm.services.first(where: { $0.name == name }) {
            switch op {
            case "start": sm.start(svc); result = ["ok": true]
            case "stop":  sm.stop(svc);  result = ["ok": true]
            case "restart": sm.restart(svc); result = ["ok": true]
            default: result = ["error": "unknown op"]
            }
        } else {
            result = ["error": "not found"]
        }

    case "server-ping":
        guard let name = cmd["name"] as? String else { return }
        if let srv = rsm.servers.first(where: { $0.name == name }) {
            let ok = await rsm.ping(srv)
            result = ["online": ok]
        } else {
            result = ["error": "not found"]
        }

    case "server-command":
        guard let name = cmd["name"] as? String, let command = cmd["command"] as? String else { return }
        if let srv = rsm.servers.first(where: { $0.name == name }) {
            let r = await rsm.runCommand(srv, command)
            result = ["output": r.output, "exitCode": Int(r.exitCode)]
        } else {
            result = ["error": "not found"]
        }

    default:
        result = ["error": "unknown action"]
    }

    let resp: [String: Any] = ["seq": seq, "result": result]
    guard let respData = try? JSONSerialization.data(withJSONObject: resp, options: [.prettyPrinted, .sortedKeys]) else { return }
    try? respData.write(to: resultPath, options: .atomic)
    try? "{}".write(to: cmdPath, atomically: true, encoding: .utf8) // ponytail: prevent re-fire on same command
}
