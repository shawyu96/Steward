import SwiftUI

// MARK: - Content View (root layout)

struct ContentView: View {
    @EnvironmentObject private var serviceManager: ServiceManager
    @EnvironmentObject private var remoteServerManager: RemoteServerManager
    @State private var selectedPage: Page = .services
    @State private var selectedService: ServiceModel?
    @State private var hoveredServiceID: String?
    @State private var selectedGroup: String?

    enum Page: String, CaseIterable {
        case services = "所有服务"
        case commands = "快捷命令"
        case remoteServers = "远程服务器"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebarView

                VStack(spacing: 0) {
                    // Title bar spacer (traffic light area) — only for content area
                    Color.clear
                        .frame(height: 28)

                    mainContentArea
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if selectedPage == .services, selectedService != nil {
                    DetailPanelView(service: $selectedService)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .environmentObject(serviceManager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            StatusBarView()
        }
        .background(Theme.windowBG)
        .frame(minWidth: 1024, minHeight: 660)
        .sheet(isPresented: $serviceManager.showingAddService) {
            AddServiceModalView(isPresented: $serviceManager.showingAddService)
                .environmentObject(serviceManager)
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(spacing: 0) {
            searchField
            sectionLabel("视图")
            navButton(.services, icon: "▤")
            navButton(.commands, icon: "⌘")
            navButton(.remoteServers, icon: "🔗")

            sectionLabel("分组")

            // "全部" option
            groupButton(icon: "📋", label: "全部", count: serviceManager.services.count, isActive: selectedGroup == nil) {
                selectedGroup = nil
            }

            // Dynamically list groups from services
            let groups = extractGroups()
            ForEach(groups, id: \.self) { group in
                let count = serviceManager.services.filter { $0.group == group }.count
                groupButton(icon: groupIcon(group), label: group, count: count, isActive: selectedGroup == group) {
                    selectedGroup = group
                }
            }

            Spacer()

            VStack(spacing: 0) {
                Divider().overlay(Theme.separator)
                addServiceButton
            }
        }
        .frame(width: 220)
        .background(Theme.sidebarBG)
    }

    private func extractGroups() -> [String] {
        let all = serviceManager.services.compactMap { $0.group }
        return Array(Set(all)).sorted()
    }

    private func groupIcon(_ name: String) -> String {
        switch name {
        case "前端服务": return "🌐"
        case "后端服务": return "⚙️"
        case "数据库":   return "🗄️"
        case "中间件":   return "📦"
        case "系统服务": return "🔧"
        case "用户代理": return "👤"
        case "Homebrew": return "🍺"
        default: return "📁"
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(Theme.tertiaryText)
            TextField("搜索服务…", text: $serviceManager.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(Theme.secondaryText)
        }
        .padding(6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.10)))
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundColor(Theme.tertiaryText)
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private func navButton(_ page: Page, icon: String) -> some View {
        let active = selectedPage == page
        return Button {
            withAnimation(.none) { selectedPage = page; selectedService = nil }
        } label: {
            HStack(spacing: 9) {
                Text(icon).font(.system(size: 14)).frame(width: 18)
                Text(page.rawValue).font(.system(size: 13))
                Spacer()
                Text("\(page == .services ? serviceManager.runningCount : page == .commands ? serviceManager.commands.count : remoteServerManager.servers.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(active ? Theme.accent : Theme.mutedText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(active ? Theme.accent.opacity(0.15) : Color.white.opacity(0.12)))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(active ? Theme.accent.opacity(0.18) : Color.clear))
            .foregroundColor(active ? Theme.accent : Theme.secondaryText)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }

    private func groupButton(icon: String, label: String, count: Int, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Text(icon).font(.system(size: 14)).frame(width: 18)
                Text(label).font(.system(size: 13))
                Spacer()
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isActive ? Theme.accent : Theme.mutedText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(isActive ? Theme.accent.opacity(0.15) : Color.white.opacity(0.12)))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(isActive ? Theme.accent.opacity(0.18) : Color.clear))
            .foregroundColor(isActive ? Theme.accent : Theme.secondaryText)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }

    private var addServiceButton: some View {
        Button {
            serviceManager.showingAddService = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                Text("添加服务").font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundColor(.white)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.blueLink))
            .padding(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Main Content Area

    private var mainContentArea: some View {
        VStack(spacing: 0) {
            switch selectedPage {
            case .services:
                ServiceListView(
                    selectedService: $selectedService,
                    hoveredServiceID: $hoveredServiceID,
                    selectedGroup: selectedGroup
                )
            case .commands:
                QuickCommandsView()
            case .remoteServers:
                RemoteServerListView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.windowBG)
    }
}
