import ServiceManagement
import SwiftUI

enum MonitorPopoverLayout {
    static let maxWidth: CGFloat = 1_220
    static let minWidth: CGFloat = 900
    static let contentHeight: CGFloat = 332
    static let cardMinWidth: CGFloat = 240
    static let cardExpandedWidth: CGFloat = 278
    static let cardSpacing: CGFloat = 12

    static func contentWidth(nodeCount: Int) -> CGFloat {
        let count = max(1, nodeCount)
        if count <= 4 {
            let ideal = CGFloat(count) * cardExpandedWidth
                + CGFloat(max(0, count - 1)) * cardSpacing
                + 28
            return min(maxWidth, max(minWidth, ideal))
        }
        let ideal = CGFloat(count * 312 + 44)
        return min(maxWidth, ideal)
    }
}

struct MonitorPopover: View {
    @ObservedObject var store: KomariStore
    let onOpenSettings: () -> Void
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    private var contentWidth: CGFloat {
        MonitorPopoverLayout.contentWidth(nodeCount: store.nodes.count)
    }
    private var contentHeight: CGFloat { MonitorPopoverLayout.contentHeight }
    private var needsScroll: Bool { store.nodes.count > 4 }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.35)
            if needsScroll {
                ScrollView(.horizontal) {
                    cards
                }
            } else {
                cards
            }
            footer
        }
        .frame(width: contentWidth, height: contentHeight)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.16),
                        Color(red: 0.01, green: 0.08, blue: 0.11).opacity(0.26)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var cards: some View {
        Group {
            if store.nodes.count <= 4 {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: MonitorPopoverLayout.cardMinWidth), spacing: MonitorPopoverLayout.cardSpacing, alignment: .top), count: max(1, store.nodes.count)),
                    alignment: .leading,
                    spacing: MonitorPopoverLayout.cardSpacing
                ) {
                    ForEach(store.nodes) { item in
                        NodeCard(item: item)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: MonitorPopoverLayout.cardSpacing) {
                    ForEach(store.nodes) { item in
                        NodeCard(item: item)
                            .frame(width: 300, alignment: .topLeading)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("VPSMonitor")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.94))
                Text("\(store.nodes.filter { $0.status.online }.count) online / \(store.nodes.count) nodes")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.62))
            }
            Spacer()
            LossStrip(samples: store.nodes.map { $0.currentLoss || !$0.status.online }, width: max(1, store.nodes.count), segmentWidth: 4, gap: 3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(store.connected ? "WebSocket connected" : "Polling")
                .foregroundStyle(store.connected ? Theme.green : .white.opacity(0.62))
            Spacer()
            Toggle("开机自启", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .foregroundStyle(.white.opacity(0.72))
                .onChange(of: launchAtLogin) { _, enabled in
                    setLaunchAtLogin(enabled)
                }
                .onAppear {
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            Button("Refresh") { store.refresh() }
            Button("Settings", action: onOpenSettings)
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .font(.system(size: 11))
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

struct MissingConfigView: View {
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("VPSMonitor")
                .font(.system(size: 18, weight: .semibold))
            Text("Komari connection settings are missing. Add your server URL and credentials to start monitoring.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            HStack {
                Button("Settings", action: onOpenSettings)
                    .keyboardShortcut(.defaultAction)
                Button("Quit", action: onQuit)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}

struct NodeCard: View {
    let item: NodeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Circle()
                    .fill(item.status.online ? Theme.green : Theme.red)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 0.5))
                Text("\(item.node.region)  \(item.node.name)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.93))
                Spacer()
            }

            Text(systemSummary)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.58))

            MetricRow(label: "CPU", value: Fmt.pct(item.status.cpu), pct: item.status.cpu, color: Theme.blue)
            MetricRow(label: "RAM", value: "\(Fmt.bytes(item.status.memUsed))/\(Fmt.bytes(item.status.memTotal))", pct: item.status.memPct, color: Theme.purple)
            MetricRow(label: "DSK", value: "\(Fmt.bytes(item.status.diskUsed))/\(Fmt.bytes(item.status.diskTotal))", pct: item.status.diskPct, color: Theme.orange)

            HStack {
                Text("NET")
                    .metricLabel()
                Text("↑ \(Fmt.rate(item.status.netUp))")
                    .contentTransition(.numericText())
                Spacer()
                Text("↓ \(Fmt.rate(item.status.netDown))")
                    .contentTransition(.numericText())
            }
            .metricText(Theme.cyan)

            MetricRow(
                label: "TOT",
                value: "\(Fmt.bytes(item.status.trafficUsed))/\(Fmt.bytes(item.node.trafficLimit))",
                pct: item.trafficPct,
                color: usageColor(item.trafficPct)
            )
            HStack {
                Color.clear.frame(width: 28)
                TrafficSplit(label: "IN", value: Fmt.bytes(item.status.trafficDown), color: Theme.cyan)
                Divider().frame(height: 14).opacity(0.35)
                TrafficSplit(label: "OUT", value: Fmt.bytes(item.status.trafficUp), color: Theme.cyan)
                Spacer()
            }
            .font(.system(size: 11, design: .monospaced))

            LatencyRow(latency: item.ping.latency, samples: item.ping.latencies)

            HStack(spacing: 8) {
                Text("LOS")
                    .metricLabel()
                Text(item.ping.loss.map { String(format: "%.1f%%", $0) } ?? "-")
                    .frame(width: 48, alignment: .trailing)
                LossStrip(samples: item.ping.drops, width: 18, segmentWidth: 4, gap: 3)
                Spacer()
            }
            .metricText(item.currentLoss ? Theme.red : Theme.green)

            Text("META  uptime \(Fmt.uptime(item.status.uptime))   age \(Fmt.age(item.status.updatedAt))   expire \(Fmt.expiry(item.node.expiresAt))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.08), Color.black.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var systemSummary: String {
        var parts = [item.node.os, item.node.arch, item.node.virtualization].filter { !$0.isEmpty }
        if item.node.cpuCores > 0 {
            parts.append("\(item.node.cpuCores) core\(item.node.cpuCores == 1 ? "" : "s")")
        }
        return parts.isEmpty ? "No system metadata" : parts.joined(separator: " · ")
    }
}

struct TrafficSplit: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(color.opacity(0.70))
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .frame(minWidth: 72, alignment: .leading)
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    let pct: Double
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .metricLabel()
            Text(Fmt.pct(pct))
                .frame(width: 48, alignment: .trailing)
                .contentTransition(.numericText())
            ProgressStrip(pct: pct, color: color)
            Text(value)
                .lineLimit(1)
                .contentTransition(.numericText())
            Spacer(minLength: 0)
        }
        .metricText(color)
    }
}

struct LatencyRow: View {
    let latency: Double?
    let samples: [Double]

    var body: some View {
        HStack(spacing: 8) {
            Text("LAT")
                .metricLabel()
            Text(latency.map { String(format: "%.0fms", $0) } ?? "-")
                .frame(width: 48, alignment: .trailing)
            LatencySpark(samples: samples)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(color.opacity(0.82))
            Spacer(minLength: 0)
        }
        .metricText(color)
    }

    private var color: Color { latencyColor(latency) }

    private var label: String {
        guard let latency else { return "NO DATA" }
        if latency < 0 { return "LOSS" }
        if latency >= 300 { return "HIGH" }
        if latency >= 160 { return "MID" }
        return "LOW"
    }
}

struct LatencySpark: View {
    let samples: [Double]

    var body: some View {
        let clipped = Array(samples.suffix(18))
        let valid = clipped.filter { $0 >= 0 }
        let maxValue = max(80, min(500, valid.max() ?? 80))
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<18, id: \.self) { idx in
                let padded = Array(repeating: -1.0, count: max(0, 18 - clipped.count)) + clipped
                let value = padded[idx]
                let height = value < 0 ? 10 : max(3, min(10, CGFloat(value / maxValue) * 10))
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(value < 0 ? Theme.red : latencyColor(value).opacity(0.9))
                    .frame(width: 4, height: height)
            }
        }
        .frame(width: 123, height: 10, alignment: .bottomLeading)
    }
}

struct ProgressStrip: View {
    let pct: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.13))
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.96), color.opacity(0.58)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * min(100, max(0, pct)) / 100)
            }
        }
        .frame(width: 120, height: 10)
    }
}

struct LossStrip: View {
    let samples: [Bool]
    let width: Int
    let segmentWidth: CGFloat
    let gap: CGFloat

    var body: some View {
        let values = padded
        HStack(spacing: gap) {
            ForEach(values.indices, id: \.self) { idx in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(values[idx] ? Theme.red : Theme.green)
                    .frame(width: segmentWidth, height: 10)
            }
        }
    }

    private var padded: [Bool] {
        let clipped = Array(samples.suffix(width))
        return Array(repeating: false, count: max(0, width - clipped.count)) + clipped
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

extension Text {
    func metricLabel() -> some View {
        self.font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.40))
            .frame(width: 28, alignment: .center)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06)))
    }
}

extension View {
    func metricText(_ color: Color) -> some View {
        self.font(.system(size: 11, design: .monospaced))
            .foregroundStyle(color)
    }
}

enum Theme {
    static let blue = Color(red: 0.40, green: 0.70, blue: 1.00)
    static let purple = Color(red: 0.78, green: 0.58, blue: 1.00)
    static let orange = Color(red: 1.00, green: 0.67, blue: 0.38)
    static let cyan = Color(red: 0.35, green: 0.96, blue: 0.92)
    static let green = Color(red: 0.13, green: 0.63, blue: 0.42)
    static let red = Color(red: 1.00, green: 0.28, blue: 0.32)
    static let yellow = Color(red: 0.98, green: 0.90, blue: 0.34)
}

func usageColor(_ pct: Double) -> Color {
    if pct >= 90 { return Theme.red }
    if pct >= 75 { return Theme.orange }
    return Theme.green
}

func latencyColor(_ latency: Double?) -> Color {
    guard let latency else { return .secondary }
    if latency < 0 { return .secondary }
    if latency >= 300 { return Theme.red }
    if latency >= 160 { return Theme.yellow }
    return Theme.green
}
