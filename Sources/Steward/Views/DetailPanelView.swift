import SwiftUI

struct DetailPanelView: View {
    @EnvironmentObject private var serviceManager: ServiceManager
    @Binding var service: ServiceModel?
    @State private var showLogSheet = false

    var body: some View {
        VStack(spacing: 0) {
            if let service {
                headerView(service)
                Divider().overlay(Theme.hairline)
                ScrollView {
                    VStack(spacing: 0) {
                        basicInfoSection(service)
                        commandSection(service)
                        if let env = service.environment, !env.isEmpty {
                            envVarsSection(env)
                        }
                        logSection(service)
                    }
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
            } else {
                emptyPlaceholder
            }
        }
        .frame(width: 340)
        .background(Theme.sidebarBG)
        .onChange(of: service?.id) { _, _ in showLogSheet = false }
        .sheet(isPresented: $showLogSheet) {
            if let svc = service {
                LogViewerSheet(serviceName: svc.name, logContent: serviceManager.logContent(for: svc.name))
            }
        }
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "shippingbox")
                .font(.system(size: 28))
                .foregroundColor(Theme.mutedText)
            Text("选择一个服务查看详情")
                .font(.system(size: 12))
                .foregroundColor(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private func headerView(_ svc: ServiceModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(svc.type.icon).font(.system(size: 18))
                Text(svc.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.primaryText)
                Spacer()
                statusBadge(svc.status)
                Button { service = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.tertiaryText)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("关闭 (Esc)")
                .keyboardShortcut(.escape)
            }

            HStack(spacing: 8) {
                detailActionButton("↻ 重启", color: Theme.yellow) {
                    serviceManager.restart(svc)
                }
                detailActionButton("■ 停止", color: Theme.red) {
                    serviceManager.stop(svc)
                }
                detailActionButton("≡ 日志", color: Theme.accent) {
                    // Could scroll to log via ScrollViewReader
                }
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func statusBadge(_ status: ServiceModel.ServiceStatus) -> some View {
        Group {
            switch status {
            case .running:
                Text("运行中").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.green)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Theme.green.opacity(0.15)))
            case .stopped:
                Text("已停止").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.tertiaryText)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08)))
            case .error:
                Text("异常").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.red)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Theme.red.opacity(0.15)))
            case .starting, .stopping:
                Text(status.rawValue).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.yellow)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Theme.yellow.opacity(0.15)))
            }
        }
    }

    private func detailActionButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundColor(color)
                .frame(maxWidth: .infinity).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sections

    private func basicInfoSection(_ svc: ServiceModel) -> some View {
        detailSection("基本信息") {
            detailRow("PID", svc.pid.map { "\($0)" } ?? "—")
            if let uptime = svc.uptimeSeconds {
                detailRow("运行时长", uptimeDisplay(uptime), color: Theme.green)
            }
            if let port = svc.ports.first {
                detailRow("端口", "\(port)", color: Theme.accent)
            }
            if let wd = svc.workDir {
                detailRow("工作目录", wd, fontSize: 11)
            }
            if let st = svc.startTime {
                detailRow("启动时间", dateFormatter.string(from: st))
            }
            detailRow("重启次数", "\(svc.restartCount)")
        }
    }

    private func commandSection(_ svc: ServiceModel) -> some View {
        detailSection("启动命令") {
            VStack(alignment: .leading, spacing: 4) {
                Text(svc.command ?? "—")
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundColor(Theme.secondaryText)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.logBG))

                if svc.type == .customProcess {
                    HStack(spacing: 0) {
                        Text("自动重启：").font(.system(size: 11)).foregroundColor(Theme.mutedText)
                        Text("已启用").font(.system(size: 11)).foregroundColor(Theme.green)
                        Text(" · 失败重试 3 次").font(.system(size: 11)).foregroundColor(Theme.mutedText)
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private func envVarsSection(_ env: [String: String]) -> some View {
        detailSection("环境变量") {
            VStack(spacing: 0) {
                ForEach(Array(env.keys.sorted()), id: \.self) { key in
                    HStack(spacing: 0) {
                        Text(key).foregroundColor(Theme.accent)
                        Text(" = ").foregroundColor(Theme.tertiaryText)
                        Text(env[key] ?? "").foregroundColor(Theme.yellow)
                        Spacer()
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.vertical, 1)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.logBG))
        }
    }

    private func logSection(_ svc: ServiceModel) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("实时日志")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(Theme.tertiaryText)
                Spacer()
                Text("展开 →")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.accent)
                    .onTapGesture { showLogSheet = true }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 4)

            let logText = serviceManager.logContent(for: svc.name)
            let logLines = logText.isEmpty
                ? ["[等待日志输出…]"]
                : logText.split(separator: "\n").map(String.init)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(logLines.suffix(30).enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundColor(logColor(line))
                            .lineLimit(1)
                    }
                }
            }
            .frame(height: 130)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.logBG))
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
    }

    private func logColor(_ line: String) -> Color {
        if line.contains("✓") || line.contains("✅") || line.contains("success") || line.contains("OK") { return Theme.green }
        if line.contains("⚠") || line.contains("warn") || line.contains("WARN") { return Theme.yellow }
        if line.contains("✕") || line.contains("error") || line.contains("ERROR") || line.contains("Error") { return Theme.red }
        if line.contains("○") || line.contains("info") || line.contains("INFO") { return Theme.accent }
        return Theme.tertiaryText
    }

    // MARK: - Helpers

    private func detailSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(Theme.tertiaryText)
            content()
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private func detailRow(_ label: String, _ value: String, color: Color? = nil, fontSize: CGFloat = 12) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: fontSize))
                .foregroundColor(Theme.mutedText)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundColor(color ?? Theme.secondaryText)
                .lineLimit(1)
            Spacer()
        }
        .padding(.vertical, 5)
        .overlay(Divider().overlay(Theme.separator), alignment: .bottom)
    }

    private func uptimeDisplay(_ seconds: TimeInterval) -> String {
        let hrs = Int(seconds) / 3600; let mins = (Int(seconds) % 3600) / 60; let secs = Int(seconds) % 60
        if hrs > 0 { return "\(hrs)h \(mins)m \(secs)s" }
        if mins > 0 { return "\(mins)m \(secs)s" }
        return "\(secs)s"
    }
}

private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f
}()

// MARK: - Log Viewer Sheet

struct LogViewerSheet: View {
    let serviceName: String
    let logContent: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("日志 — \(serviceName)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.secondaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .overlay(Divider().overlay(Theme.hairline), alignment: .bottom)

            ScrollView {
                Text(logContent.isEmpty ? "[暂无日志]" : logContent)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .textSelection(.enabled)
            }
            .background(Theme.logBG)
            .scrollIndicators(.visible)
        }
        .frame(width: 640, height: 480)
        .background(Theme.panelBG)
    }
}
