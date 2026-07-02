import Foundation

/// Represents a managed service on the local machine.
struct ServiceModel: Identifiable, Hashable {
    let id: String
    let name: String
    let type: ServiceType
    var status: ServiceStatus
    var pid: Int?
    var command: String?
    var group: String?
    var ports: [Int] = []
    var startTime: Date?
    var uptimeSeconds: TimeInterval?
    var restartCount: Int = 0
    var exitCode: Int?
    var cpuUsage: Double?
    var memoryUsage: String?
    var environment: [String: String]?
    var logPath: String?
    var configPath: String?
    var workDir: String?

    enum ServiceType: String, CaseIterable, Identifiable, Codable {
        case customProcess = "Process"

        var id: String { rawValue }

        var icon: String { "📦" }
    }

    enum ServiceStatus: String, CaseIterable {
        case running  = "Running"
        case stopped  = "Stopped"
        case error    = "Error"
        case starting = "Starting"
        case stopping = "Stopping"
    }
}

/// A resolved service configuration — what the user defines.
struct ServiceConfig: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let type: String  // rawValue of ServiceType
    let command: String
    let arguments: [String]
    let workingDirectory: String?
    let environment: [String: String]?
    let group: String?
    let port: Int?
    let autoStart: Bool
    let watch: Bool
    let logEnabled: Bool

    var serviceType: ServiceModel.ServiceType {
        ServiceModel.ServiceType(rawValue: type) ?? .customProcess
    }

    static let defaultConfig = ServiceConfig(
        name: "new-service",
        type: ServiceModel.ServiceType.customProcess.rawValue,
        command: "",
        arguments: [],
        workingDirectory: nil,
        environment: nil,
        group: nil,
        port: nil,
        autoStart: false,
        watch: false,
        logEnabled: true
    )
}
