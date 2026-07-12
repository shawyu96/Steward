# Steward

macOS 本地开发服务管理工具。添加任意命令行进程，一键启停。

## 功能

- **服务生命周期** — 添加 CLI 命令，启动 / 停止 / 重启
- **Shell 集成** — 自动捕获 PATH 和 alias，开箱即用
- **进程恢复** — 重启 app 后 `pgrep` 自动匹配仍在运行的进程
- **日志流** — stdout/stderr 实时捕获，支持展开查看
- **崩溃检测** — 非零退出标为异常并显示退出码，手动停止不误标
- **远程服务器** — SSH 连接管理（密钥/密码），一键打开 Terminal 终端，远程命令执行
- **IPC 桥接** — `~/.steward/` 文件协议，Hermes Agent 可直接读写服务状态和执行命令
- **快捷命令** — 保存常用命令（部署/构建/迁移），一键执行
- **分组过滤** — 侧栏按组筛选
- **开机自启** — 菜单栏开关

## 环境要求

- macOS 14+ (Sonoma)
- Xcode 16+ 或 Swift 6 工具链

## 构建

```bash
swift build
bash scripts/build_app.sh
open .build/arm64-apple-macosx/debug/Steward.app
```

首次打开为空，按 **⌘N** 或点 **＋ 添加服务** 添加第一个服务。

## 配置

服务和命令保存在 `~/Library/Application Support/Steward/`。

## 协议

MIT
