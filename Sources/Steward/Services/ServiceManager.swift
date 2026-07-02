import Foundation
import ServiceManagement
import AppKit

/// Manages user-defined services and their lifecycle.
@MainActor
final class ServiceManager: ObservableObject {
    @Published var services: [ServiceModel] = []
    @Published var configs: [ServiceConfig] = []
    @Published var searchText = ""
    @Published var showingAddService = false
    @Published var selectedService: ServiceModel?
    @Published var commands: [SavedCommand] = []

    var runningCount: Int { services.filter { $0.status == .running }.count }

    private var processes: [String: Process] = [:]
    private var startTimes: [String: Date] = [:]
    private var restartCounts: [String: Int] = [:]
    /// Persists last non-zero exit code so error state survives refresh.
    private var lastExitCodes: [String: Int] = [:]

    /// Persists PIDs matched via pgrep on startup so they survive subsequent refreshAll() calls.
    private var knownRunningPIDs: [String: Int] = [:]

    /// Build the dictionary key used to store a custom process.
    private func processKey(_ name: String) -> String { "custom-\(name)" }
    private var uptimeTimer: Timer?

    /// On startup, matches each config's command against running processes via `pgrep`.
    private func matchRunningProcesses() {
        for config in configs {
            let key = processKey(config.name)
            if processes[key] != nil { continue }

            // Resolve aliases to get the real command
            let resolved = resolveAliases(config.command)
            // Use the last non-flag argument (script path) as match key,
            // since the interpreter path may vary (python3 vs full framework path)
            let searchKey: String = {
                let parts = resolved.split(separator: " ", omittingEmptySubsequences: true)
                // Pick the last part that looks like a file/script path
                for part in parts.reversed() {
                    let s = String(part)
                    if s.contains("/") || s.hasSuffix(".py") || s.hasSuffix(".js") || s.hasSuffix(".sh") {
                        // Use only the filename (last component) since tilde won't expand in pgrep
                        let filename = s.split(separator: "/").last.map(String.init) ?? s
                        return filename
                    }
                }
                // Fallback: use the resolved command's last argument
                return parts.last.map(String.init) ?? resolved
            }()
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            task.arguments = ["-f", searchKey]
            let outPipe = Pipe()
            task.standardOutput = outPipe
            task.standardError = FileHandle.nullDevice
            try? task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { continue }

            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            let pids = String(data: data, encoding: .utf8)?
                .split(separator: "\n")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? []

            if let pid = pids.first {
                knownRunningPIDs[key] = pid
                startTimes[key] = Date().addingTimeInterval(-5)
            }
        }
        if !knownRunningPIDs.isEmpty {
            stewardLog("Matched \(knownRunningPIDs.count) running services via pgrep")
        }
    }

    /// User's PATH from their shell — collected once at startup.
    private let userShellPath: String = {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-l", "-i", "-c", "echo $PATH"]
        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !path.isEmpty {
            stewardLog("Captured user PATH: \(path)")
            return path
        }
        stewardLog("Failed to capture user PATH, using fallback")
        return "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    }()

    /// User's shell aliases captured once at startup — avoids needing `zsh -i` at runtime.
    private let userAliases: [String: String] = {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-i", "-c", "alias"]
        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        var aliases: [String: String] = [:]
        // Format from `zsh -i -c "alias"`: name='value' or name=value
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            // Strip optional "alias " prefix (some shells include it)
            let stripped = trimmed.hasPrefix("alias ") ? String(trimmed.dropFirst(6)) : trimmed
            if let eqIdx = stripped.firstIndex(of: "=") {
                let name = String(stripped[..<eqIdx])
                let value = String(stripped[stripped.index(after: eqIdx)...])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                if !name.isEmpty {
                    aliases[name] = value
                }
            }
        }
        if !aliases.isEmpty {
            stewardLog("Captured \(aliases.count) shell aliases")
        }
        return aliases
    }()

    /// Resolves the leading command in `command` if it's a known alias.
    private func resolveAliases(_ command: String) -> String {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        // Extract the first word (the command name)
        let firstSpace = trimmed.firstIndex(of: " ") ?? trimmed.endIndex
        let cmdName = String(trimmed[..<firstSpace])
        let rest = firstSpace < trimmed.endIndex ? String(trimmed[firstSpace...]) : ""

        if let expansion = userAliases[cmdName] {
            // Recursively resolve (alias could point to another alias)
            return resolveAliases("\(expansion)\(rest)")
        }
        return trimmed
    }

    init() {
        loadConfigs()
        loadCommands()
        matchRunningProcesses()
        refreshAll()
        startTimers()
        if UserDefaults.standard.bool(forKey: Self.autoStartKey) {
            try? SMAppService.mainApp.register()
        }
    }

    private func startTimers() {
        uptimeTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateUptimes() }
        }
    }

    // MARK: - Discovery

    /// Scans only user-defined custom process configs.
    func refreshAll() {
        var all: [ServiceModel] = []
        all += scanCustomProcesses()

        for i in all.indices {
            let sid = all[i].id
            if let st = startTimes[sid] { all[i].startTime = st }
            if let rc = restartCounts[sid] { all[i].restartCount = rc }
            if processes[sid] != nil { all[i].status = .running }
        }

        services = all.sorted { $0.name.lowercased() < $1.name.lowercased() }
        updateUptimes()
    }

    private func updateUptimes() {
        let now = Date()
        for i in services.indices where services[i].status == .running {
            if let st = services[i].startTime {
                services[i].uptimeSeconds = now.timeIntervalSince(st)
            }
        }
    }

    // MARK: - Lifecycle

    func start(_ service: ServiceModel) {
        guard services.contains(where: { $0.id == service.id }),
              let config = configs.first(where: { $0.name == service.name }) else { return }
        lastExitCodes.removeValue(forKey: processKey(config.name))
        startProcess(config: config)
        refreshAll()
    }

    func stop(_ service: ServiceModel) {
        if let process = processes[service.id] {
            process.terminate()
            processes.removeValue(forKey: service.id)
            startTimes.removeValue(forKey: service.id)
        } else if let pid = knownRunningPIDs[service.id] {
            kill(pid_t(pid), SIGTERM) // ponytail: pgrep-matched orphan
        }
        knownRunningPIDs.removeValue(forKey: service.id)
        refreshAll()
    }

    func restart(_ service: ServiceModel) {
        restartCounts[service.id] = (restartCounts[service.id] ?? 0) + 1
        stop(service)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.start(service)
        }
    }

    func stopAll() {
        for service in services where service.status == .running { stop(service) }
    }

    func restartAll() {
        for service in services where service.status == .running {
            restartCounts[service.id] = (restartCounts[service.id] ?? 0) + 1
        }
        for service in services where service.status == .running { stop(service) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            for service in self.services { self.start(service) }
        }
    }

    // MARK: - Quick Commands

    private let commandsURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Steward", isDirectory: true)
        return dir.appendingPathComponent("commands.json")
    }()

    func loadCommands() {
        guard let data = try? Data(contentsOf: commandsURL),
              let decoded = try? JSONDecoder().decode([SavedCommand].self, from: data) else {
            commands = []; return
        }
        commands = decoded
    }

    func saveCommands() {
        guard let data = try? JSONEncoder().encode(commands) else { return }
        try? data.write(to: commandsURL, options: .atomic)
    }

    func addCommand(_ cmd: SavedCommand) { commands.append(cmd); saveCommands() }
    func removeCommand(_ id: UUID) { commands.removeAll { $0.id == id }; saveCommands() }

    func runCommand(_ cmd: SavedCommand) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        let resolved = resolveAliases(cmd.command)
        process.arguments = ["-c", resolved]
        if let wd = cmd.workDir { process.currentDirectoryURL = URL(fileURLWithPath: wd) }
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = userShellPath
        env["TERM"] = "xterm-256color"
        process.environment = env
        process.standardInput = FileHandle.nullDevice
        try? process.run()
    }

    // MARK: - Config Management

    private let configURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Steward", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("services.json")
    }()

    func loadConfigs() {
        guard let data = try? Data(contentsOf: configURL),
              let decoded = try? JSONDecoder().decode([ServiceConfig].self, from: data) else {
            configs = []; return
        }
        configs = decoded
    }

    func saveConfigs() {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        try? data.write(to: configURL, options: .atomic)
    }

    func addConfig(_ config: ServiceConfig) {
        if let idx = configs.firstIndex(where: { $0.name == config.name }) {
            configs[idx] = config
        } else {
            configs.append(config)
        }
        saveConfigs()
        refreshAll()
        if config.autoStart { startProcess(config: config) }
    }

    func removeConfig(_ name: String) {
        configs.removeAll { $0.name == name }
        saveConfigs()
        refreshAll()
    }

    // MARK: - Auto-start (Login Item)

    private static let autoStartKey = "steward_autoStart"

    var isAutoStartEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.autoStartKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.autoStartKey)
            applyAutoStart(newValue)
        }
    }

    private func applyAutoStart(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            stewardLog("Auto-start \(enabled ? "register" : "unregister") failed: \(error)")
        }
    }

    // MARK: - Private: Custom Processes

    private func scanCustomProcesses() -> [ServiceModel] {
        configs.map { config in
            let key = processKey(config.name)
            let isRunning = processes[key] != nil || knownRunningPIDs[key] != nil
            let runningPID: Int? = {
                if let proc = processes[key] { return Int(proc.processIdentifier) }
                return knownRunningPIDs[key]
            }()
            let ports: [Int] = {
                if let p = config.port { return [p] }
                if let extracted = Self.extractPort(from: config.command) { return [extracted] }
                return []
            }()
            return ServiceModel(
                id: "custom-\(config.name)",
                name: config.name,
                type: .customProcess,
                status: isRunning ? .running : (lastExitCodes[key] != nil ? .error : .stopped),
                pid: runningPID,
                command: config.command,
                group: config.group,
                ports: ports,
                startTime: startTimes[config.name],
                restartCount: restartCounts[key] ?? 0,
                exitCode: isRunning ? nil : lastExitCodes[key],
                environment: config.environment,
                logPath: logURL(for: config.name).path,
                configPath: config.command,
                workDir: config.workingDirectory
            )
        }
    }

    private func startProcess(config: ServiceConfig) {
        guard processes[processKey(config.name)] == nil else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        let resolvedCommand = resolveAliases("\(config.command) \(config.arguments.joined(separator: " "))")
        process.arguments = ["-c", "exec " + resolvedCommand] // ponytail: single-command only; compound (&&, |) needs a script wrapper

        if let wd = config.workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: wd)
        }

        var env = ProcessInfo.processInfo.environment
        if let extraEnv = config.environment {
            env.merge(extraEnv) { _, new in new }
        }
        // Inject user's shell PATH so CLI tools installed via Homebrew etc. are found
        env["PATH"] = userShellPath
        // Set TERM so .zshrc scripts that depend on it don't bail out
        env["TERM"] = "xterm-256color"
        process.environment = env
        // Close stdin so process never hangs waiting for input
        process.standardInput = FileHandle.nullDevice

        if config.logEnabled { setupLogging(for: config.name, process: process) }

        process.terminationHandler = { [weak self] process in
            let exitCode = Int(process.terminationStatus)
            Task { @MainActor [weak self] in
                guard let self else { return }
                let key = processKey(config.name)
                self.processes.removeValue(forKey: key)
                self.knownRunningPIDs.removeValue(forKey: key)
                if exitCode != 0 {
                    self.lastExitCodes[key] = exitCode
                }
                self.refreshAll()
            }
        }

        do {
            try process.run()
            processes[processKey(config.name)] = process
            startTimes[config.name] = Date()
        } catch {
            stewardLog("Failed to start process \(config.name): \(error)")
        }
    }

    private func setupLogging(for name: String, process: Process) {
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData; guard !data.isEmpty else { return }
            Task { @MainActor [weak self] in self?.appendLog(name, data: data) }
        }
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData; guard !data.isEmpty else { return }
            Task { @MainActor [weak self] in self?.appendLog(name, data: data) }
        }
    }

    // MARK: - Logging

    private let logDir: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Steward/logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private func logURL(for name: String) -> URL { logDir.appendingPathComponent("\(name).log") }

    private func appendLog(_ name: String, data: Data) {
        guard !data.isEmpty else { return }
        let url = logURL(for: name)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile(); handle.write(data); try? handle.close()
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    func logContent(for name: String) -> String {
        let url = logURL(for: name)
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return "" }
        let lines = text.split(separator: "\n")
        return lines.suffix(100).joined(separator: "\n")
    }

    // MARK: - Helpers

    static func extractPort(from command: String) -> Int? {
        let patterns: [NSRegularExpression] = [
            try! NSRegularExpression(pattern: ":(\\d{4,5})(?:\\s|$|/)"),
            try! NSRegularExpression(pattern: "--port\\s+(\\d{4,5})"),
            try! NSRegularExpression(pattern: "-p\\s+(\\d{4,5})"),
            try! NSRegularExpression(pattern: "PORT=(\\d{4,5})"),
            try! NSRegularExpression(pattern: "port=(\\d{4,5})"),
        ]
        for pattern in patterns {
            let range = NSRange(location: 0, length: command.utf16.count)
            if let match = pattern.firstMatch(in: command, range: range) {
                let numRange = match.range(at: 1)
                if numRange.location != NSNotFound,
                   let num = Int(command[command.utf16.index(command.utf16.startIndex, offsetBy: numRange.location)..<command.utf16.index(command.utf16.startIndex, offsetBy: numRange.location + numRange.length)]) {
                    return num
                }
            }
        }
        return nil
    }
}

// MARK: - Saved Quick Command

struct SavedCommand: Identifiable, Codable, Hashable {
    var id = UUID()
    let icon: String
    let name: String
    let desc: String
    let command: String
    let category: String
    let workDir: String?
}

// MARK: - Helper

func stewardLog(_ message: String) {
    let logURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("Steward/app.log")
    let line = "[\(Date())] \(message)\n"
    guard let data = line.data(using: .utf8) else { return }
    if let handle = try? FileHandle(forWritingTo: logURL) {
        handle.seekToEndOfFile(); handle.write(data); try? handle.close()
    } else {
        try? data.write(to: logURL, options: .atomic)
    }
}
