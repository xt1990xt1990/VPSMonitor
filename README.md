# VPSMonitor

A lightweight macOS menu bar monitor for Komari VPS nodes. It shows node health, CPU, memory, disk, network traffic, latency, loss, uptime, and expiry metadata from the menu bar.

This app is a macOS menu bar client for [Komari](https://github.com/komari-monitor/komari), a lightweight self-hosted server monitoring tool. You need a running Komari server and API/session credentials for this app to display data.

## Features

- Native macOS menu bar app built with SwiftUI and AppKit.
- Compact per-node status strip in the menu bar.
- Popover dashboard with resource usage, traffic, latency, packet loss, uptime, and expiry.
- WebSocket realtime updates with polling fallback.
- Optional launch-at-login control from the popover.

## Requirements

- macOS 14 or later.
- Swift 6 toolchain / recent Xcode command line tools.
- A Komari instance with RPC/API access.

## Configuration

The app reads its private config from:

```text
~/.config/komari-swiftbar/config.json
```

On first launch, the app opens a settings window where you can enter your Komari URL and credentials. You can also reopen it from the popover with **Settings**.

If you prefer editing the config file manually, create the directory and copy the example:

```bash
mkdir -p ~/.config/komari-swiftbar
cp config.example.json ~/.config/komari-swiftbar/config.json
```

Then edit the copied file with your own Komari URL and credentials.

Do not commit your real `config.json`. It may contain API keys, cookies, or session tokens.

## Build

Build the command line executable:

```bash
swift build -c release
```

Build and install the menu bar app to `~/Applications/VPSMonitor.app`:

```bash
./scripts/build-app.sh
```

Run the installed app:

```bash
open ~/Applications/VPSMonitor.app
```

## Repository Safety

This repository intentionally ignores local configuration, build output, app bundles, archives, logs, and common private key files.

## Acknowledgements

Thanks to [Komari](https://github.com/komari-monitor/komari) for providing the lightweight self-hosted server monitoring platform and API that this menu bar client builds on.

## License

MIT
