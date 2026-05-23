# VPSMonitor

[English](README.md)

VPSMonitor 是一个轻量级 macOS 菜单栏应用，用于监控 Komari VPS 节点。它可以在菜单栏和弹窗面板中展示节点健康状态、CPU、内存、磁盘、网络流量、延迟、丢包、运行时间和到期信息。

本应用是 [Komari](https://github.com/komari-monitor/komari) 的 macOS 菜单栏客户端。Komari 是一个轻量级自托管服务器监控工具。使用本应用前，你需要先部署可访问的 Komari 服务，并准备 API 或会话凭据。

## 功能

- 使用 SwiftUI 和 AppKit 构建的原生 macOS 菜单栏应用。
- 菜单栏中显示紧凑的节点状态概览。
- 弹窗面板展示资源用量、流量、延迟、丢包、运行时间和到期信息。
- 支持 WebSocket 实时更新，并在不可用时回退到轮询。
- 支持在弹窗中控制开机自启。

## 要求

- macOS 14 或更高版本。
- Swift 6 工具链或较新的 Xcode Command Line Tools。
- 一个可通过 RPC/API 访问的 Komari 实例。

## 配置

应用从以下路径读取本地私有配置：

```text
~/.config/komari-swiftbar/config.json
```

首次启动时，应用会打开设置窗口，你可以填写 Komari 地址和凭据。之后也可以从弹窗中的 **Settings** 重新打开设置。

如果你更喜欢手动编辑配置文件，可以先创建目录并复制示例：

```bash
mkdir -p ~/.config/komari-swiftbar
cp config.example.json ~/.config/komari-swiftbar/config.json
```

然后把复制出来的文件改成你自己的 Komari 地址和凭据。

请不要提交真实的 `config.json`。它可能包含 API Key、Cookie 或会话 Token。

## 构建

构建命令行可执行文件：

```bash
swift build -c release
```

构建并安装菜单栏应用到 `~/Applications/VPSMonitor.app`：

```bash
./scripts/build-app.sh
```

运行已安装的应用：

```bash
open ~/Applications/VPSMonitor.app
```

## 仓库安全

本仓库已主动忽略本地配置、构建输出、应用包、压缩包、日志和常见私钥文件。

## 致谢

感谢 [Komari](https://github.com/komari-monitor/komari) 提供轻量级自托管服务器监控平台和 API，本菜单栏客户端基于它构建。

弹窗卡片 UI 参考并受到 [komari-theme-Lumina](https://github.com/stqfdyr/komari-theme-Lumina) 启发。感谢 Lumina 主题作者提供的视觉方向。

## 许可证

MIT
