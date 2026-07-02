import SwiftUI

struct RemoteServerListView: View {
    @EnvironmentObject private var serverManager: RemoteServerManager
    @State private var showAddSheet = false
    @State private var editServer: RemoteServerConfig?
    @State private var commandServer: RemoteServerConfig?

    var body: some View {
        VStack(spacing: 0) {
            // Header — ponytail: match ServiceListView toolbar style
            HStack(spacing: 10) {
                Text("远程服务器")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                Text("共 \(serverManager.servers.count) 台服务器")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.tertiaryText)
                Spacer()
                Button("↻ 刷新") {
                    Task { await serverManager.refreshAll() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(Theme.secondaryText)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.10)))
                )

                Button("＋ 添加服务器") { showAddSheet = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Theme.blueLink))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .overlay(Divider().overlay(Theme.hairline), alignment: .bottom)

            if serverManager.servers.isEmpty {
                emptyPlaceholder
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(serverManager.servers) { server in
                            ServerRow(
                                server: server,
                                isOnline: serverManager.statuses[server.name] ?? false,
                                onTerminal: { serverManager.openTerminal(server) },
                                onCommand: { commandServer = server },
                                onEdit: { editServer = server },
                                onDelete: { serverManager.remove(server.name) }
                            )
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(Theme.windowBG)
        .sheet(isPresented: $showAddSheet) {
            AddRemoteServerSheet(isPresented: $showAddSheet)
                .environmentObject(serverManager)
        }
        .sheet(item: $commandServer) { server in
            CommandSheet(server: server, isPresented: $commandServer)
                .environmentObject(serverManager)
        }
        .sheet(item: $editServer) { server in
            AddRemoteServerSheet(isPresented: Binding(
                get: { editServer != nil },
                set: { if !$0 { editServer = nil } }
            ), editConfig: server)
                .environmentObject(serverManager)
        }
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "network")
                .font(.system(size: 32))
                .foregroundColor(Theme.mutedText)
            Text("还没有远程服务器")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.tertiaryText)
            Text("点工具栏「＋ 添加服务器」添加你的第一台服务器")
                .font(.system(size: 11))
                .foregroundColor(Theme.mutedText)
            Button {
                showAddSheet = true
            } label: {
                Text("＋ 添加服务器")
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
}

// MARK: - Server Row

struct ServerRow: View {
    let server: RemoteServerConfig
    let isOnline: Bool
    let onTerminal: () -> Void
    let onCommand: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            // Status dot — ponytail: reuse ServiceListView pattern
            Circle()
                .fill(isOnline ? Theme.green : Theme.gray)
                .frame(width: 10, height: 10)
                .shadow(color: isOnline ? Theme.green.opacity(0.6) : .clear, radius: 3)

            // Icon
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 18))
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.blueLink.opacity(0.12)))

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(server.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.primaryText)
                    Text(isOnline ? "● 在线" : "○ 离线")
                        .font(.system(size: 10))
                        .foregroundColor(isOnline ? Theme.green : Theme.tertiaryText)
                }
                Text(server.connectionString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.tertiaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 6) {
                iconButton("›_", Theme.accent, onTerminal)
                iconButton("⌘", Theme.yellow, onCommand)
            }

            // Menu
            Menu {
                Button("编辑") { onEdit() }
                Button("删除", role: .destructive, action: onDelete)
            } label: {
                Text("⋯")
                    .font(.system(size: 13))
                    .frame(width: 30, height: 30)
                    .foregroundColor(Theme.secondaryText)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.white.opacity(0.07))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.10)))
                    )
            }
            .buttonStyle(.plain)
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Theme.cardHover : Theme.cardBG)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline))
        )
        .contextMenu {
            Button("打开终端", action: onTerminal)
            Divider()
            Button("编辑", action: onEdit)
            Button("删除", role: .destructive, action: onDelete)
        }
        .onHover { isHovered = $0 }
        .onTapGesture { onTerminal() } // ponytail: click = open Terminal.app
    }

    private func iconButton(_ icon: String, _ color: Color, _ action: @escaping () -> Void) -> some View {
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

// MARK: - Add Sheet

struct AddRemoteServerSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var serverManager: RemoteServerManager
    let editConfig: RemoteServerConfig?

    init(isPresented: Binding<Bool>, editConfig: RemoteServerConfig? = nil) {
        self._isPresented = isPresented
        self.editConfig = editConfig
        if let c = editConfig {
            _name = .init(initialValue: c.name)
            _host = .init(initialValue: c.host)
            _port = .init(initialValue: "\(c.port)")
            _sshUser = .init(initialValue: c.sshUser ?? "")
            _keyPath = .init(initialValue: c.keyPath ?? "")
            _group = .init(initialValue: c.group ?? "")
        }
    }

    @State private var name = ""
    @State private var host = ""
    @State private var port = "22"
    @State private var sshUser = ""
    @State private var keyPath = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var group = ""
    @State private var showAdvanced = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                Text(editConfig != nil ? "编辑远程服务器" : "添加远程服务器")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.primaryText)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
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
                    formField("服务器名称") {
                        TextField("例：生产环境 API", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.primaryText)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder)))
                    }

                    formField("主机地址") {
                        TextField("192.168.1.100 或 hostname", text: $host)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Theme.primaryText)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder)))
                    }

                    // Advanced toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showAdvanced.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .rotationEffect(.degrees(showAdvanced ? 90 : 0))
                            Text("高级选项")
                                .font(.system(size: 12))
                            Spacer()
                        }
                        .foregroundColor(Theme.secondaryText)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if showAdvanced {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                formField("SSH 端口") {
                                    TextField("22", text: $port)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(Theme.primaryText)
                                        .padding(8)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder)))
                                }
                                .frame(width: 100)

                                formField("SSH 用户") {
                                    TextField("当前用户", text: $sshUser)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(Theme.primaryText)
                                        .padding(8)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder)))
                                }
                            }

                            formField("SSH 密钥路径") {
                                TextField("~/.ssh/id_ed25519（可选）", text: $keyPath)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Theme.primaryText)
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder)))
                            }

                            formField("SSH 密码") {
                                HStack(spacing: 6) {
                                    if showPassword {
                                        TextField("macOS 原生支持", text: $password)
                                            .textFieldStyle(.plain)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(Theme.primaryText)
                                            .padding(8)
                                    } else {
                                        SecureField("macOS 原生支持", text: $password)
                                            .textFieldStyle(.plain)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(Theme.primaryText)
                                            .padding(8)
                                    }
                                    Button { showPassword.toggle() } label: {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .font(.system(size: 12))
                                            .foregroundColor(Theme.mutedText)
                                    }
                                    .buttonStyle(.plain)
                                    .help(showPassword ? "隐藏密码" : "显示密码")
                                }
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder)))
                            }

                            formField("分组（可选）") {
                                TextField("例：生产环境、开发环境", text: $group)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.primaryText)
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder)))
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
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
                    .keyboardShortcut(.escape)

                Button(editConfig != nil ? "保存" : "添加") {
                    save()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 18).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.blueLink))
                .disabled(name.isEmpty || host.isEmpty)
                .keyboardShortcut(.return)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .overlay(Divider().overlay(Theme.hairline), alignment: .top)
        }
        .frame(width: 460)
        .background(Theme.panelBG)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10)))
        .shadow(color: Theme.windowShadow, radius: 40)
    }

    private func save() {
        let hasPw = !password.isEmpty
        let config = RemoteServerConfig(
            name: name.trimmingCharacters(in: .whitespaces),
            host: host.trimmingCharacters(in: .whitespaces),
            port: Int(port) ?? 22,
            sshUser: sshUser.trimmingCharacters(in: .whitespaces).isEmpty ? nil : sshUser.trimmingCharacters(in: .whitespaces),
            hasPassword: hasPw,
            keyPath: keyPath.trimmingCharacters(in: .whitespaces).isEmpty ? nil : keyPath.trimmingCharacters(in: .whitespaces),
            group: group.trimmingCharacters(in: .whitespaces).isEmpty ? nil : group.trimmingCharacters(in: .whitespaces),
            password: hasPw ? password : nil
        )
        serverManager.add(config, previousName: editConfig?.name)
        isPresented = false
    }

    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(Theme.secondaryText)
            content()
        }
    }
}

// MARK: - Command Sheet

struct CommandSheet: View {
    let server: RemoteServerConfig
    @Binding var isPresented: RemoteServerConfig?
    @EnvironmentObject private var serverManager: RemoteServerManager
    @State private var command = ""
    @State private var output = ""
    @State private var running = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "terminal")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.accent)
                Text("远程命令 — \(server.name)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                Spacer()
                Button { isPresented = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.secondaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .overlay(Divider().overlay(Theme.hairline), alignment: .bottom)

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    TextField("输入命令…", text: $command)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.primaryText)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)).overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.inputBorder)))
                        .onSubmit { run() }

                    Button("执行", action: run)
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(running ? Theme.mutedText : .white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(running ? Color.gray.opacity(0.3) : Theme.blueLink))
                        .disabled(running || command.isEmpty)
                }

                ScrollView {
                    Text(output.isEmpty ? (running ? "连接中…" : "输入命令后点击执行") : output)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(output.isEmpty ? Theme.mutedText : Theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .textSelection(.enabled)
                }
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.logBG))
            }
            .padding(12)
        }
        .frame(width: 560, height: 360)
        .background(Theme.panelBG)
    }

    private func run() {
        guard !command.isEmpty else { return }
        running = true; output = ""
        Task {
            let result = await serverManager.runCommand(server, command)
            output = result.output.isEmpty ? "(无输出，退出码: \(result.exitCode))" : result.output
            running = false
            command = "" // ponytail: clear for next command
        }
    }
}
