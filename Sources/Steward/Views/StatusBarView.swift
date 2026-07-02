import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject private var serviceManager: ServiceManager

    var body: some View {
        HStack(spacing: 16) {
            statusIndicator(count: runningCount, color: Theme.green, label: "个运行中")
            statusIndicator(count: stoppedCount, color: Theme.gray, label: "个已停止")
            statusIndicator(count: errorCount, color: Theme.red, label: "个异常")

            Spacer()

            Text("Steward v1.0")
                .font(.system(size: 10.5))
                .foregroundColor(Theme.accent)
        }
        .padding(.horizontal, 16)
        .frame(height: 26)
        .background(Theme.statusBar)
        .overlay(Divider().overlay(Theme.hairline), alignment: .top)
    }

    private var runningCount: Int { serviceManager.runningCount }
    private var stoppedCount: Int { serviceManager.services.filter { $0.status == .stopped }.count }
    private var errorCount: Int { serviceManager.services.filter { $0.status == .error }.count }

    private func statusIndicator(count: Int, color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(count) \(label)")
                .font(.system(size: 10.5))
                .foregroundColor(color == Theme.gray ? Theme.tertiaryText : color)
        }
    }
}
