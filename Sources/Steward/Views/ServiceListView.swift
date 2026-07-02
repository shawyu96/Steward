import SwiftUI

struct ServiceListView: View {
    @EnvironmentObject private var serviceManager: ServiceManager
    @Binding var selectedService: ServiceModel?
    @Binding var hoveredServiceID: String?
    var selectedGroup: String?

    @State private var filterStatus: FilterStatus = .all
    @State private var showLogPopover = false
    @State private var logServiceID: String?

    enum FilterStatus: String, CaseIterable {
        case all, running, stopped, error
        var label: String {
            switch self {
            case .all:     return "全部"
            case .running: return "运行中"
            case .stopped: return "已停止"
            case .error:   return "异常"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            filterBar
            serviceList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Text("所有服务")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.primaryText)
            Text("共 \(filteredServices.count) 个服务 · \(serviceManager.runningCount) 个运行中")
                .font(.system(size: 12))
                .foregroundColor(Theme.tertiaryText)
            Spacer()
            toolbarButton("↻ 全部重启") { serviceManager.restartAll() }
            toolbarButton("■ 全部停止", danger: true) { serviceManager.stopAll() }
            toolbarButton("＋ 添加服务", primary: true) { serviceManager.showingAddService = true }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .overlay(Divider().overlay(Theme.hairline), alignment: .bottom)
    }

    private func toolbarButton(_ title: String, danger: Bool = false, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(primary ? .white : danger ? Theme.red : Theme.secondaryText)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(primary ? Theme.blueLink : Color.white.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(danger ? Theme.red.opacity(0.3) : Color.white.opacity(0.10)))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 6) {
            ForEach(FilterStatus.allCases, id: \.self) { filter in
                let count = statusCount(filter)
                Button {
                    withAnimation(.none) { filterStatus = filter }
                } label: {
                    Text("\(filter.label) \(count)")
                        .font(.system(size: 12))
                        .foregroundColor(filterStatus == filter ? Theme.accent : Theme.mutedText)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(filterStatus == filter ? Theme.accent.opacity(0.15) : Color.white.opacity(0.06))
                                .overlay(Capsule().stroke(filterStatus == filter ? Theme.accent.opacity(0.30) : Color.clear))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
        .overlay(Divider().overlay(Theme.separator), alignment: .bottom)
    }

    private func statusCount(_ filter: FilterStatus) -> Int {
        let base = filteredServices
        switch filter {
        case .all:     return base.count
        case .running: return base.filter { $0.status == .running }.count
        case .stopped: return base.filter { $0.status == .stopped }.count
        case .error:   return base.filter { $0.status == .error }.count
        }
    }

    // MARK: - Service List

    private var serviceList: some View {
        Group {
            if filteredServices.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredServices) { service in
                            serviceCard(service)
                                .onHover { hoveredServiceID = $0 ? service.id : nil }
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if selectedService?.id == service.id {
                                            selectedService = nil
                                        } else {
                                            selectedService = service
                                        }
                                    }
                                }
                                .contextMenu { contextMenuItems(service) }
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .font(.system(size: 32))
                .foregroundColor(Theme.mutedText)
            Text("还没有添加任何服务")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.tertiaryText)
            Text("点工具栏「＋ 添加服务」或按 ⌘N 添加你的第一个服务")
                .font(.system(size: 11))
                .foregroundColor(Theme.mutedText)
            Button {
                serviceManager.showingAddService = true
            } label: {
                Text("＋ 添加服务")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Theme.blueLink))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
    }

    private var filteredServices: [ServiceModel] {
        var result = serviceManager.services

        // Group filter
        if let group = selectedGroup {
            result = result.filter { $0.group == group }
        }

        // Search filter
        if !serviceManager.searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(serviceManager.searchText) }
        }

        // Status filter
        switch filterStatus {
        case .all:     break
        case .running: result = result.filter { $0.status == .running }
        case .stopped: result = result.filter { $0.status == .stopped }
        case .error:   result = result.filter { $0.status == .error }
        }
        return result
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(_ service: ServiceModel) -> some View {
        Group {
            if service.status == .running {
                Button("停止", action: { serviceManager.stop(service) })
                Button("重启", action: { serviceManager.restart(service) })
            } else {
                Button("启动", action: { serviceManager.start(service) })
            }
            Divider()
            Button("查看日志") {
                selectedService = service
            }
            if service.type == .customProcess {
                Divider()
                Button("删除服务", role: .destructive) {
                    serviceManager.removeConfig(service.name)
                }
            }
        }
    }

    // MARK: - Service Card

    private func serviceCard(_ service: ServiceModel) -> some View {
        let isSelected = selectedService?.id == service.id
        let isHovered = hoveredServiceID == service.id

        return HStack(spacing: 14) {
            statusDot(service.status)
            iconView(service)
            serviceInfoView(service)
            Spacer()
            serviceStatsView(service)
            actionButtons(service)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Theme.accent.opacity(0.06) : (isHovered ? Theme.cardHover : Theme.cardBG))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Theme.accent.opacity(0.40) : Theme.hairline))
        )
    }

    private func statusDot(_ status: ServiceModel.ServiceStatus) -> some View {
        Circle()
            .fill(statusColor(status))
            .frame(width: 10, height: 10)
            .shadow(color: status == .running ? Theme.green.opacity(0.6) : .clear, radius: 3)
    }

    private func statusColor(_ status: ServiceModel.ServiceStatus) -> Color {
        switch status {
        case .running:   return Theme.green
        case .stopped:   return Theme.gray
        case .error:     return Theme.red
        case .starting, .stopping: return Theme.yellow
        }
    }

    private func iconView(_ service: ServiceModel) -> some View {
        Text(service.type.icon)
            .font(.system(size: 18))
            .frame(width: 40, height: 40)
            .background(RoundedRectangle(cornerRadius: 10).fill(iconTint(service.type).opacity(0.12)))
    }

    private func iconTint(_ type: ServiceModel.ServiceType) -> Color {
        Theme.blueLink
    }

    private func serviceInfoView(_ service: ServiceModel) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(service.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                Text(statusLabel(service.status))
                    .font(.system(size: 10))
                    .foregroundColor(statusColor(service.status))
            }

            if let cmd = service.command {
                Text(cmd)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.tertiaryText)
                    .lineLimit(1).truncationMode(.middle)
            }

            HStack(spacing: 5) {
                tag(service.type.rawValue, color: Theme.tertiaryText, bg: Color.white.opacity(0.08))
                if let port = service.ports.first {
                    tag(":\(port)", color: Theme.accent, bg: Theme.accent.opacity(0.15))
                }
                if let group = service.group {
                    tag(group, color: Theme.yellow, bg: Theme.yellow.opacity(0.10))
                }
            }
        }
    }

    private func statusLabel(_ s: ServiceModel.ServiceStatus) -> String {
        switch s {
        case .running:   return "● 运行中"
        case .stopped:   return "● 已停止"
        case .error:     return "● 异常退出"
        case .starting:  return "● 启动中"
        case .stopping:  return "● 停止中"
        }
    }

    private func tag(_ text: String, color: Color, bg: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(bg))
    }

    private func serviceStatsView(_ service: ServiceModel) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            if service.status == .running {
                Text("↑ \(uptimeDisplay(service.uptimeSeconds))")
                    .font(.system(size: 11)).foregroundColor(Theme.green)
                if let pid = service.pid {
                    Text("PID \(pid)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.tertiaryText)
                }
            }
            if service.status == .error {
                Text("✕ 退出码 \(service.exitCode ?? 1)")
                    .font(.system(size: 11)).foregroundColor(Theme.red)
            }
            if service.status == .stopped {
                Text("已停止").font(.system(size: 11)).foregroundColor(Theme.tertiaryText)
            }
        }
    }

    private func uptimeDisplay(_ seconds: TimeInterval?) -> String {
        guard let s = seconds else { return "—" }
        let hrs = Int(s) / 3600; let mins = (Int(s) % 3600) / 60
        if hrs > 0 { return "\(hrs)h \(mins)m" }
        if mins > 0 { return "\(mins)m \(Int(s) % 60)s" }
        return "\(Int(s))s"
    }

    @ViewBuilder
    private func actionButtons(_ service: ServiceModel) -> some View {
        HStack(spacing: 6) {
            switch service.status {
            case .running:
                iconButton("↻", color: Theme.yellow) { serviceManager.restart(service) }
                iconButton("■", color: Theme.red) { serviceManager.stop(service) }
            case .stopped, .error:
                iconButton("▶", color: Theme.green) { serviceManager.start(service) }
            case .starting, .stopping:
                iconButton("⋯", color: Theme.mutedText) {}
            }
            iconButton("≡", color: Theme.secondaryText) { selectedService = service }
            iconButton("⋯", color: Theme.secondaryText) {
                // Show context menu programmatically is tricky, so we select + show detail
                selectedService = service
            }
        }
    }

    private func iconButton(_ icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(icon)
                .font(.system(size: 13))
                .frame(width: 30, height: 30)
                .foregroundColor(color)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(color.opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.10)))
                )
        }
        .buttonStyle(.plain)
    }
}
