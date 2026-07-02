import SwiftUI

struct AddServiceModalView: View {
    @EnvironmentObject private var serviceManager: ServiceManager
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var command = ""
    @State private var group = ""
    @State private var showAdvanced = false
    @State private var workDir = ""
    @State private var port = ""
    @State private var autoRestart = false
    @State private var envVars: [(key: String, value: String)] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                Text("添加服务")
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
                    // Name
                    formField("服务名称") {
                        TextField("例：API 后端", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundColor(Theme.primaryText)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder)))
                    }

                    // Command
                    formField("启动命令") {
                        TextEditor(text: $command)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Theme.primaryText)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 56)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder)))
                    }

                    // Group (quick inline)
                    formField("分组（可选）") {
                        TextField("例：后端服务、数据库", text: $group)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
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
                            // Work dir + port side by side
                            HStack(spacing: 12) {
                                formField("工作目录") {
                                    TextField("~/projects/my-app", text: $workDir)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(Theme.primaryText)
                                        .padding(8)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder)))
                                }

                                formField("端口") {
                                    TextField("自动检测", text: $port)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(Theme.primaryText)
                                        .padding(8)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder)))
                                }
                                .frame(width: 110)
                            }

                            // Environment variables
                            formField("环境变量") {
                                VStack(spacing: 0) {
                                    ForEach(envVars.indices, id: \.self) { idx in
                                        HStack(spacing: 8) {
                                            TextField("KEY", text: $envVars[idx].key)
                                                .textFieldStyle(.plain)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(Theme.accent)
                                                .padding(7)
                                                .background(Color.white.opacity(0.04))
                                            Text("=")
                                                .font(.system(size: 11))
                                                .foregroundColor(Theme.tertiaryText)
                                            TextField("value", text: $envVars[idx].value)
                                                .textFieldStyle(.plain)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(Theme.secondaryText)
                                                .padding(7)
                                                .background(Color.white.opacity(0.04))
                                            Button { envVars.remove(at: idx) } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 8))
                                                    .foregroundColor(Theme.red.opacity(0.5))
                                                    .frame(width: 20)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .overlay(Divider().overlay(Theme.separator), alignment: .bottom)
                                    }
                                    Button {
                                        envVars.append(("", ""))
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 9))
                                            Text("添加环境变量")
                                                .font(.system(size: 11))
                                        }
                                        .foregroundColor(Theme.mutedText)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.04))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder))
                                )
                            }

                            Toggle(isOn: $autoRestart) {
                                Text("崩溃后自动重启")
                                    .font(.system(size: 11))
                            }
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(20)
            }

            // Footer
            HStack(spacing: 8) {
                Spacer()
                Button("取消") { isPresented = false }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.secondaryText)
                    .padding(.horizontal, 16).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.inputBorder)))
                    .keyboardShortcut(.escape)

                Button("添加并启动") {
                    saveAndStart()
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

    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(Theme.secondaryText)
            content()
        }
    }

    private func saveAndStart() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !command.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let env = envVars.filter { !$0.key.isEmpty }.reduce(into: [String: String]()) { dict, pair in
            dict[pair.key] = pair.value
        }

        let config = ServiceConfig(
            name: trimmedName,
            type: ServiceModel.ServiceType.customProcess.rawValue,
            command: command.trimmingCharacters(in: .whitespaces),
            arguments: [],
            workingDirectory: workDir.isEmpty ? nil : workDir,
            environment: env.isEmpty ? nil : env,
            group: group.isEmpty ? nil : group,
            port: Int(port),
            autoStart: false,
            watch: autoRestart,
            logEnabled: true
        )
        serviceManager.addConfig(config)
        isPresented = false
    }
}
