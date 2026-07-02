import SwiftUI

struct QuickCommandsView: View {
    @EnvironmentObject private var serviceManager: ServiceManager
    @State private var selectedTab = "全部"
    @State private var showingAddCommand = false

    let categories = ["全部", "部署", "构建", "数据库", "工具"]

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            tabBar
            commandGrid
        }
        .sheet(isPresented: $showingAddCommand) {
            AddCommandModalView(isPresented: $showingAddCommand)
                .environmentObject(serviceManager)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Text("快捷命令")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.primaryText)
            Text("存储常用命令，一键执行")
                .font(.system(size: 12))
                .foregroundColor(Theme.tertiaryText)
            Spacer()
            toolbarButton("＋ 新建命令", primary: true) {
                showingAddCommand = true
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .overlay(Divider().overlay(Theme.hairline), alignment: .bottom)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(categories, id: \.self) { tab in
                Button {
                    withAnimation(.none) { selectedTab = tab }
                } label: {
                    Text(tab == "全部" ? "全部 (\(filteredCommands.count))" : tab)
                        .font(.system(size: 13))
                        .foregroundColor(selectedTab == tab ? Theme.accent : Theme.mutedText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .overlay(
                            Rectangle()
                                .fill(selectedTab == tab ? Theme.accent : Color.clear)
                                .frame(height: 2),
                            alignment: .bottom
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .overlay(Divider().overlay(Theme.separator), alignment: .bottom)
    }

    private var commandGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ], spacing: 10) {
                ForEach(filteredCommands) { cmd in
                    commandCard(cmd)
                }
                addPlaceholder
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }

    private var filteredCommands: [SavedCommand] {
        if selectedTab == "全部" { return serviceManager.commands }
        return serviceManager.commands.filter { $0.category == selectedTab }
    }

    private func commandCard(_ cmd: SavedCommand) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(cmd.icon)
                .font(.system(size: 22))
                .padding(.bottom, 8)

            Text(cmd.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.primaryText)

            Text(cmd.desc)
                .font(.system(size: 11))
                .foregroundColor(Theme.tertiaryText)
                .padding(.top, 2)
                .lineLimit(2)

            Text(cmd.command)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(Theme.mutedText)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05))
                .cornerRadius(4)
                .padding(.top, 8)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.cardBG)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline))
        )
        .overlay(alignment: .topTrailing) {
            Button {
                serviceManager.runCommand(cmd)
            } label: {
                Text("▶")
                    .font(.system(size: 12))
                    .frame(width: 24, height: 24)
                    .foregroundColor(Theme.green)
                    .background(Theme.green.opacity(0.12))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .padding(6)
        }
        .contextMenu {
            Button("运行") { serviceManager.runCommand(cmd) }
            Divider()
            Button("删除命令", role: .destructive) {
                serviceManager.removeCommand(cmd.id)
            }
        }
    }

    private var addPlaceholder: some View {
        Button {
            showingAddCommand = true
        } label: {
            VStack(spacing: 6) {
                Text("＋")
                    .font(.system(size: 24))
                    .foregroundColor(Theme.tertiaryText)
                Text("新建命令")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.tertiaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundColor(Theme.mutedText)
            )
        }
        .buttonStyle(.plain)
        .opacity(0.45)
    }

    private func toolbarButton(_ title: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(primary ? Theme.blueLink : Color.white.opacity(0.07))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Command Modal

struct AddCommandModalView: View {
    @EnvironmentObject private var serviceManager: ServiceManager
    @Binding var isPresented: Bool

    @State private var icon = "🚀"
    @State private var name = ""
    @State private var desc = ""
    @State private var command = ""
    @State private var category = "工具"
    @State private var workDir = ""

    let categories = ["部署", "构建", "数据库", "工具"]
    let icons = ["🚀", "🏗️", "🗄️", "🧪", "🔍", "📦", "💾", "🔄", "⚡", "🎯", "🛠️", "📋"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text("⌘")
                    .font(.system(size: 18))
                Text("新建快捷命令")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.primaryText)
                Spacer()
                Button { isPresented = false } label: {
                    Text("✕")
                        .font(.system(size: 14))
                        .frame(width: 26, height: 26)
                        .foregroundColor(Theme.secondaryText)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .overlay(Divider().overlay(Theme.hairline), alignment: .bottom)

            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        formGroup("图标") {
                            Picker("", selection: $icon) {
                                ForEach(icons, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 56)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder)))
                        }
                        .frame(width: 56)

                        formGroup("命令名称") {
                            TextField("例：部署到测试环境", text: $name)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .foregroundColor(Theme.primaryText)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder)))
                        }
                    }

                    formGroup("描述") {
                        TextField("简短描述这个命令的作用", text: $desc)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundColor(Theme.primaryText)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder)))
                    }

                    formGroup("命令内容 *") {
                        TextEditor(text: $command)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Theme.primaryText)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 70)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder)))
                    }

                    HStack(spacing: 12) {
                        formGroup("分类标签") {
                            Picker("", selection: $category) {
                                ForEach(categories, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .foregroundColor(Theme.secondaryText)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder)))
                        }
                        formGroup("工作目录") {
                            TextField("~/projects/…", text: $workDir)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(Theme.primaryText)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder)))
                        }
                    }
                }
                .padding(20)
            }

            HStack(spacing: 8) {
                Spacer()
                Button("取消") { isPresented = false }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.secondaryText)
                    .padding(.horizontal, 16).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder)))

                Button("保存命令") {
                    save()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 18).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.blueLink))
                .disabled(name.isEmpty || command.isEmpty)
                .keyboardShortcut(.return)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .overlay(Divider().overlay(Theme.hairline), alignment: .top)
        }
        .frame(width: 440)
        .background(Theme.panelBG)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10)))
        .shadow(color: Theme.windowShadow, radius: 40)
    }

    private func formGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(Theme.secondaryText)
            content()
        }
    }

    private func save() {
        let cmd = SavedCommand(
            icon: icon,
            name: name.trimmingCharacters(in: .whitespaces),
            desc: desc.trimmingCharacters(in: .whitespaces),
            command: command.trimmingCharacters(in: .whitespaces),
            category: category,
            workDir: workDir.isEmpty ? nil : workDir
        )
        serviceManager.addCommand(cmd)
        isPresented = false
    }
}
