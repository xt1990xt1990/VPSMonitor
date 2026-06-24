import ServiceManagement
import AppKit
import SwiftUI

enum MonitorPopoverLayout {
    static let maxWidth: CGFloat = 1_460
    static let minWidth: CGFloat = 360
    static let cardMinWidth: CGFloat = 318
    static let cardExpandedWidth: CGFloat = 340
    static let cardBaseHeight: CGFloat = 394
    static let cardSpacing: CGFloat = 10
    static let chromeHeight: CGFloat = 104
    static let cardAreaPadding: CGFloat = 20

    static func contentWidth(nodeCount: Int) -> CGFloat {
        let count = max(1, nodeCount)
        let columns = columnCount(nodeCount: count)
        let cardWidth = displayCardWidth(nodeCount: count)
        let ideal = CGFloat(columns) * cardWidth
            + CGFloat(max(0, columns - 1)) * cardSpacing
            + 28
        return min(availableWidth, max(minWidth, ideal))
    }

    static func contentHeight(nodeCount: Int) -> CGFloat {
        let count = max(1, nodeCount)
        let rows = rowCount(nodeCount: count)
        let ideal = chromeHeight
            + CGFloat(rows) * displayCardHeight(nodeCount: count)
            + CGFloat(max(0, rows - 1)) * cardSpacing
            + cardAreaPadding
        return min(availableHeight, max(360, ideal))
    }

    static func columnCount(nodeCount: Int) -> Int {
        let count = max(1, nodeCount)
        let maxColumnsByWidth = Int((availableWidth - 28 + cardSpacing) / (cardExpandedWidth + cardSpacing))
        return min(count, 4, max(1, maxColumnsByWidth))
    }

    static func rowCount(nodeCount: Int) -> Int {
        let columns = columnCount(nodeCount: nodeCount)
        return Int(ceil(Double(max(1, nodeCount)) / Double(columns)))
    }

    static func cardScale(nodeCount: Int) -> CGFloat {
        1
    }

    static func displayCardWidth(nodeCount: Int) -> CGFloat {
        cardExpandedWidth * cardScale(nodeCount: nodeCount)
    }

    static func displayCardHeight(nodeCount: Int) -> CGFloat {
        cardBaseHeight * cardScale(nodeCount: nodeCount)
    }

    private static var availableWidth: CGFloat {
        max(minWidth, min(maxWidth, (NSScreen.main?.visibleFrame.width ?? maxWidth) - 48))
    }

    private static var availableHeight: CGFloat {
        max(430, min(980, (NSScreen.main?.visibleFrame.height ?? 980) - 48))
    }
}

struct MonitorPopover: View {
    @ObservedObject var store: KomariStore
    let onOpenSettings: () -> Void
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    private var contentWidth: CGFloat {
        MonitorPopoverLayout.contentWidth(nodeCount: store.nodes.count)
    }
    private var contentHeight: CGFloat {
        MonitorPopoverLayout.contentHeight(nodeCount: store.nodes.count)
    }
    private var cardScale: CGFloat {
        MonitorPopoverLayout.cardScale(nodeCount: store.nodes.count)
    }
    private var displayedCardWidth: CGFloat {
        MonitorPopoverLayout.displayCardWidth(nodeCount: store.nodes.count)
    }
    private var displayedCardHeight: CGFloat {
        MonitorPopoverLayout.displayCardHeight(nodeCount: store.nodes.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            LuminaDivider()
            cards
            footer
        }
        .frame(width: contentWidth, height: contentHeight)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Theme.luminaShellTop,
                        Theme.luminaShellBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.luminaBorderStrong.opacity(0.78), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.42), radius: 22, x: 0, y: 16)
    }

    private var cards: some View {
        ScrollView(.vertical) {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.fixed(displayedCardWidth), spacing: MonitorPopoverLayout.cardSpacing, alignment: .top),
                    count: MonitorPopoverLayout.columnCount(nodeCount: store.nodes.count)
                ),
                alignment: .leading,
                spacing: MonitorPopoverLayout.cardSpacing
            ) {
                ForEach(store.nodes) { item in
                    NodeCard(item: item)
                        .frame(width: MonitorPopoverLayout.cardExpandedWidth, alignment: .topLeading)
                        .scaleEffect(cardScale, anchor: .topLeading)
                        .frame(width: displayedCardWidth, height: displayedCardHeight, alignment: .topLeading)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Theme.luminaShellBody)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("VPSMonitor")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.luminaTextPrimary)
                HStack(spacing: 7) {
                    Circle()
                        .fill(store.connected ? Theme.luminaOnline : Theme.luminaTextTertiary)
                        .frame(width: 6, height: 6)
                    Text("\(store.nodes.filter { $0.status.online }.count) online / \(store.nodes.count) nodes")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.luminaTextSecondary)
                }
            }
            Spacer()
            LossStrip(samples: store.nodes.map { $0.currentLoss || !$0.status.online }, width: max(1, store.nodes.count), segmentWidth: 4, gap: 3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.luminaShellHeader)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(store.connected ? Theme.luminaOnline : Theme.luminaTextTertiary)
                    .frame(width: 6, height: 6)
                Text(store.connected ? "WebSocket connected" : "Polling")
                    .foregroundStyle(store.connected ? Theme.luminaOnline : Theme.luminaTextTertiary)
            }
            .font(.system(size: 11, weight: .semibold))
            Spacer()
            Button {
                launchAtLogin.toggle()
                setLaunchAtLogin(launchAtLogin)
            } label: {
                Label("开机自启", systemImage: launchAtLogin ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(LuminaControlButtonStyle(isActive: launchAtLogin))
            .onAppear {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
            Button {
                store.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(LuminaControlButtonStyle())
            Button {
                onOpenSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(LuminaControlButtonStyle())
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(LuminaControlButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.luminaShellFooter)
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
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(alignment: .leading, spacing: 13) {
                metricGrid
                trafficGrid
                LuminaDivider()
                healthGrid
                LuminaDivider()
                metaGrid
            }
        }
        .padding(.top, 18)
        .padding(.horizontal, 16)
        .padding(.bottom, 13)
        .frame(maxWidth: .infinity, minHeight: 394, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: item.status.online
                    ? [Theme.luminaSurface, Theme.luminaSurfaceBottom]
                    : [Theme.luminaOfflineSurfaceTop, Theme.luminaOfflineSurfaceBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(item.status.online ? Theme.luminaBorder : Theme.luminaOffline.opacity(0.42), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: 12)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(flagDisplay(item.node.region))
                        .font(.system(size: 15))
                        .frame(width: 22, alignment: .leading)
                    Text(item.node.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(item.status.online ? Theme.luminaTextPrimary : Theme.luminaOffline.opacity(0.86))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text(systemSummary)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.luminaTextSecondary.opacity(0.82))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            Circle()
                .fill(item.status.online ? Theme.luminaOnline : Theme.luminaOffline)
                .frame(width: item.status.online ? 8 : 10, height: item.status.online ? 8 : 10)
                .overlay(Circle().stroke(Color.black.opacity(0.22), lineWidth: 1))
                .shadow(color: (item.status.online ? Theme.luminaOnline : Theme.luminaOffline).opacity(0.60), radius: 6)
                .padding(.top, 2)
        }
    }

    private var metricGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 14, alignment: .top),
                GridItem(.flexible(), spacing: 14, alignment: .top)
            ],
            alignment: .leading,
            spacing: 11
        ) {
            LuminaMetricItem(
                icon: "cpu",
                label: "CPU",
                value: String(format: "%.2f", item.status.cpu),
                unit: "%",
                detail: "\(max(0, item.node.cpuCores)) 核",
                fraction: item.status.cpu / 100,
                color: Theme.luminaCpu
            )
            LuminaMetricItem(
                icon: "memorychip",
                label: "内存",
                value: String(format: "%.2f", item.status.memPct),
                unit: "%",
                detail: "\(luminaBytes(item.status.memUsed)) / \(luminaBytes(item.status.memTotal))",
                fraction: item.status.memPct / 100,
                color: Theme.luminaMemory
            )
            LuminaMetricItem(
                icon: "internaldrive",
                label: "磁盘",
                value: String(format: "%.1f", item.status.diskPct),
                unit: "%",
                detail: "\(luminaBytes(item.status.diskUsed)) / \(luminaBytes(item.status.diskTotal))",
                fraction: item.status.diskPct / 100,
                color: Theme.luminaDisk
            )
            LuminaMetricItem(
                icon: "speedometer",
                label: "负载",
                value: String(format: "%.2f", item.status.load1),
                unit: nil,
                detail: nil,
                fraction: item.node.cpuCores > 0 ? item.status.load1 / Double(item.node.cpuCores) : 0,
                color: Theme.luminaMemory
            )
        }
    }

    private var trafficGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 14, alignment: .top),
                GridItem(.flexible(), spacing: 14, alignment: .top)
            ],
            alignment: .leading,
            spacing: 14
        ) {
            LuminaTrafficStat(
                icon: "arrow.up",
                direction: "上行",
                totalLabel: "出站",
                rate: item.status.netUp,
                total: luminaBytes(item.status.trafficUp),
                live: item.status.online,
                color: Theme.luminaCpu
            )
            LuminaTrafficStat(
                icon: "arrow.down",
                direction: "下行",
                totalLabel: "入站",
                rate: item.status.netDown,
                total: luminaBytes(item.status.trafficDown),
                live: item.status.online,
                color: Theme.luminaNetwork
            )
        }
    }

    private var healthGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 14, alignment: .top),
                GridItem(.flexible(), spacing: 14, alignment: .top)
            ],
            alignment: .leading,
            spacing: 14
        ) {
            LuminaHealthBlock(
                icon: "clock",
                label: "延迟",
                value: item.ping.latency.map { "\(Int($0.rounded()))" } ?? "无样本",
                unit: item.ping.latency == nil ? nil : "ms",
                color: luminaLatencyColor(item.ping.latency)
            ) {
                LuminaLatencyBars(samples: item.ping.latencies, current: item.ping.latency)
            }
            LuminaHealthBlock(
                icon: "cable.connector.slash",
                label: "丢包率",
                value: item.ping.loss.map { String(format: "%.1f", $0) } ?? "无样本",
                unit: item.ping.loss == nil ? nil : "%",
                color: luminaLossColor(item.ping.loss)
            ) {
                LuminaLossBars(samples: item.ping.drops, loss: item.ping.loss)
            }
        }
    }

    private var metaGrid: some View {
        let expiry = luminaExpiry(item.node.expiresAt)
        let uptime = luminaUptime(item.status.uptime)
        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 14, alignment: .top),
                GridItem(.flexible(), spacing: 14, alignment: .top)
            ],
            alignment: .leading,
            spacing: 14
        ) {
            LuminaMetaItem(
                icon: "calendar",
                label: "到期",
                value: expiry.value,
                unit: expiry.unit,
                color: expiry.color
            )
            LuminaMetaItem(
                icon: "arrow.triangle.2.circlepath",
                label: "在线",
                value: uptime.value,
                unit: uptime.unit,
                color: Theme.luminaCpu
            )
        }
    }

    private var systemSummary: String {
        let parts = [item.node.os, item.node.arch, item.node.virtualization].filter { !$0.isEmpty }
        return parts.isEmpty ? "No system metadata" : parts.joined(separator: " · ")
    }
}

private struct LuminaMetricItem: View {
    let icon: String
    let label: String
    let value: String
    let unit: String?
    let detail: String?
    let fraction: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(Theme.luminaTextSecondary)
                Spacer(minLength: 6)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.luminaTextPrimary)
                    if let unit {
                        Text(unit)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.luminaTextTertiary)
                    }
                }
                .lineLimit(1)
                .contentTransition(.numericText())
            }
            Text(detail ?? " ")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.luminaTextPrimary.opacity(0.82))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(Theme.luminaSurfaceElev.opacity(0.42)))
                .overlay(Capsule().stroke(Theme.luminaBorderSubtle.opacity(0.55), lineWidth: 1))
                .opacity(detail == nil ? 0 : 1)
            SegmentedMeter(fraction: fraction, color: color)
        }
    }
}

private struct LuminaTrafficStat: View {
    let icon: String
    let direction: String
    let totalLabel: String
    let rate: Double
    let total: String
    let live: Bool
    let color: Color

    private var rateParts: RateParts { luminaRate(rate) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                    Text(direction)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(color)
                Spacer(minLength: 6)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(rateParts.value)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                    Text(rateParts.unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.luminaTextTertiary)
                }
                .contentTransition(.numericText())
            }
            HStack(spacing: 8) {
                TrafficDotStrip(rate: rate, color: color)
                HStack(spacing: 5) {
                    Circle()
                        .fill(live ? Theme.luminaOnline : Theme.luminaOffline.opacity(0.72))
                        .frame(width: 5, height: 5)
                    Text(live ? "实时" : "离线")
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(live ? Theme.luminaTextTertiary : Theme.luminaOffline)
            }
            HStack(spacing: 7) {
                HStack(spacing: 5) {
                    Image(systemName: "globe")
                        .font(.system(size: 12, weight: .medium))
                    Text(totalLabel)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(color)
                Spacer(minLength: 6)
                Text(total)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.luminaTextSecondary)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
        }
    }
}

private struct LuminaHealthBlock<Bars: View>: View {
    let icon: String
    let label: String
    let value: String
    let unit: String?
    let color: Color
    @ViewBuilder let bars: () -> Bars

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Theme.luminaTextSecondary)
                Spacer(minLength: 6)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: unit == nil ? 10 : 15, weight: .semibold))
                        .foregroundStyle(unit == nil ? Theme.luminaTextTertiary : color)
                    if let unit {
                        Text(unit)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.luminaTextTertiary)
                    }
                }
                .contentTransition(.numericText())
            }
            bars()
        }
    }
}

private struct LuminaMetaItem: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Theme.luminaTextSecondary)
            Spacer(minLength: 6)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.luminaTextTertiary)
                }
            }
            .contentTransition(.numericText())
        }
    }
}

private struct SegmentedMeter: View {
    let fraction: Double
    let color: Color
    var count = 16
    var height: CGFloat = 9

    var body: some View {
        HStack(spacing: 1.8) {
            ForEach(0..<count, id: \.self) { idx in
                let amount = max(0, min(1, fraction * Double(count) - Double(idx)))
                RoundedRectangle(cornerRadius: 2)
                    .fill(amount > 0 ? color.opacity(0.42 + 0.56 * amount) : Theme.luminaProgressBg.opacity(0.58))
                    .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                    .shadow(color: Color.black.opacity(0.18), radius: 0.5, y: 0.5)
            }
        }
        .frame(height: height)
    }
}

private struct TrafficDotStrip: View {
    let rate: Double
    let color: Color
    private let count = 16

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { idx in
                Circle()
                    .fill(idx < activeCount ? color.opacity(0.52 + 0.46 * Double(idx + 1) / Double(activeCount)) : Theme.luminaProgressBg.opacity(0.62))
                    .frame(width: 4, height: 4)
                    .shadow(color: idx < activeCount ? color.opacity(0.30) : .clear, radius: 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var activeCount: Int {
        guard rate > 0 else { return 1 }
        let scaled = Int(log10(rate + 1) * 4)
        return min(count, max(2, scaled))
    }
}

private struct LuminaLatencyBars: View {
    let samples: [Double]
    let current: Double?
    private let count = 20

    var body: some View {
        let clipped = Array(samples.suffix(count))
        let valid = clipped.filter { $0 >= 0 }
        let maxValue = max(80, min(500, valid.max() ?? current ?? 80))
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<count, id: \.self) { idx in
                let padded = Array(repeating: -1.0, count: max(0, count - clipped.count)) + clipped
                let value = padded[idx]
                let barHeight = value < 0 ? 4 : max(4, min(14, CGFloat(value / maxValue) * 14))
                RoundedRectangle(cornerRadius: 1.2)
                    .fill(value < 0 ? Theme.luminaProgressBg.opacity(0.55) : luminaLatencyColor(value).opacity(0.92))
                    .frame(maxWidth: .infinity, minHeight: barHeight, maxHeight: barHeight)
            }
        }
        .frame(height: 14, alignment: .bottomLeading)
    }
}

private struct LuminaLossBars: View {
    let samples: [Bool]
    let loss: Double?
    private let count = 20

    var body: some View {
        let clipped = Array(samples.suffix(count))
        let padded = Array(repeating: false, count: max(0, count - clipped.count)) + clipped
        let hasSamples = !samples.isEmpty || loss != nil
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<count, id: \.self) { idx in
                RoundedRectangle(cornerRadius: 2)
                    .fill(lossFill(for: padded[idx], hasSamples: hasSamples))
                    .frame(maxWidth: .infinity, minHeight: 13, maxHeight: 13)
            }
        }
        .frame(height: 14, alignment: .bottomLeading)
    }

    private func lossFill(for dropped: Bool, hasSamples: Bool) -> Color {
        if !hasSamples { return Theme.luminaProgressBg.opacity(0.55) }
        return dropped ? Theme.luminaOffline.opacity(0.96) : Theme.luminaOnline.opacity(0.92)
    }
}

private struct LuminaDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.luminaHairline)
            .frame(height: 1)
    }
}

private struct LossStrip: View {
    let samples: [Bool]
    let width: Int
    let segmentWidth: CGFloat
    let gap: CGFloat

    var body: some View {
        let values = padded
        HStack(spacing: gap) {
            ForEach(values.indices, id: \.self) { idx in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(values[idx] ? Theme.luminaOffline : Theme.luminaOnline)
                    .frame(width: segmentWidth, height: 10)
            }
        }
    }

    private var padded: [Bool] {
        let clipped = Array(samples.suffix(width))
        return Array(repeating: false, count: max(0, width - clipped.count)) + clipped
    }
}

private struct LuminaControlButtonStyle: ButtonStyle {
    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.titleAndIcon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isActive ? Theme.luminaOnline : Theme.luminaTextSecondary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(configuration.isPressed ? Theme.luminaControlPressed : Theme.luminaControl)
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? Theme.luminaOnline.opacity(0.25) : Theme.luminaBorderSubtle.opacity(0.80), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
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

    static let luminaSurface = Color(red: 0.059, green: 0.059, blue: 0.063)
    static let luminaSurfaceBottom = Color(red: 0.052, green: 0.052, blue: 0.056)
    static let luminaSurfaceElev = Color(red: 0.071, green: 0.071, blue: 0.078)
    static let luminaOfflineSurfaceTop = Color(red: 0.095, green: 0.062, blue: 0.059)
    static let luminaOfflineSurfaceBottom = Color(red: 0.071, green: 0.052, blue: 0.052)
    static let luminaBorder = Color.white.opacity(0.055)
    static let luminaBorderSubtle = Color.white.opacity(0.040)
    static let luminaBorderStrong = Color.white.opacity(0.105)
    static let luminaHairline = Color.white.opacity(0.060)
    static let luminaShellTop = Color(red: 0.067, green: 0.067, blue: 0.071)
    static let luminaShellBottom = Color(red: 0.037, green: 0.038, blue: 0.041)
    static let luminaShellHeader = Color(red: 0.043, green: 0.043, blue: 0.047).opacity(0.96)
    static let luminaShellBody = Color(red: 0.047, green: 0.052, blue: 0.055).opacity(0.70)
    static let luminaShellFooter = Color(red: 0.043, green: 0.043, blue: 0.047).opacity(0.97)
    static let luminaControl = Color.white.opacity(0.070)
    static let luminaControlPressed = Color.white.opacity(0.120)
    static let luminaProgressBg = Color(red: 0.149, green: 0.149, blue: 0.165)
    static let luminaTextPrimary = Color(red: 0.866, green: 0.866, blue: 0.875)
    static let luminaTextSecondary = Color(red: 0.647, green: 0.647, blue: 0.667)
    static let luminaTextTertiary = Color(red: 0.463, green: 0.463, blue: 0.486)
    static let luminaCpu = Color(red: 0.365, green: 0.533, blue: 1.0)
    static let luminaMemory = Color(red: 0.639, green: 0.361, blue: 0.961)
    static let luminaDisk = Color(red: 0.945, green: 0.529, blue: 0.239)
    static let luminaNetwork = Color(red: 0.357, green: 0.733, blue: 0.541)
    static let luminaOnline = Color(red: 0.380, green: 0.753, blue: 0.561)
    static let luminaOffline = Color(red: 0.847, green: 0.306, blue: 0.271)
}

private struct RateParts {
    let value: String
    let unit: String
}

private struct ExpiryDisplay {
    let value: String
    let unit: String
    let color: Color
}

private struct UptimeDisplay {
    let value: String
    let unit: String
}

private func luminaBytes(_ value: Double, decimals: Int = 2) -> String {
    guard value > 0 else { return "0 B" }
    let units = ["B", "KB", "MB", "GB", "TB", "PB"]
    var amount = value
    var index = 0
    while amount >= 1024, index < units.count - 1 {
        amount /= 1024
        index += 1
    }
    if index == 0 { return "\(Int(amount.rounded())) \(units[index])" }
    let places = amount >= 100 ? 0 : amount >= 10 ? 1 : decimals
    return String(format: "%.\(places)f %@", amount, units[index])
}

private func luminaRate(_ value: Double) -> RateParts {
    guard value > 0, value.isFinite else {
        return RateParts(value: "0", unit: "bps")
    }
    let bits = value * 8
    let units: [(String, Double)] = [
        ("Tbps", 1_000_000_000_000),
        ("Gbps", 1_000_000_000),
        ("Mbps", 1_000_000),
        ("Kbps", 1_000)
    ]
    for (unit, divisor) in units where bits >= divisor {
        return RateParts(value: luminaCompactNumber(bits / divisor), unit: unit)
    }
    let valueText = bits >= 100 ? String(Int(bits.rounded())) : String(format: "%.1f", bits)
    return RateParts(value: valueText, unit: "bps")
}

private func luminaCompactNumber(_ value: Double) -> String {
    if value >= 100 { return String(Int(value.rounded())) }
    if value >= 10 { return trimZeros(String(format: "%.1f", value)) }
    if value >= 1 { return trimZeros(String(format: "%.2f", value)) }
    return trimZeros(String(format: "%.3f", value))
}

private func trimZeros(_ text: String) -> String {
    var text = text
    while text.contains("."), text.hasSuffix("0") {
        text.removeLast()
    }
    if text.hasSuffix(".") {
        text.removeLast()
    }
    return text
}

private func luminaUptime(_ seconds: Double) -> UptimeDisplay {
    guard seconds > 0 else { return UptimeDisplay(value: "-", unit: "") }
    let days = floor(seconds / 86_400)
    if days >= 1 { return UptimeDisplay(value: String(Int(days)), unit: "天") }
    let hours = floor(seconds / 3_600)
    if hours >= 1 { return UptimeDisplay(value: String(Int(hours)), unit: "小时") }
    let minutes = max(0, floor(seconds / 60))
    return UptimeDisplay(value: String(Int(minutes)), unit: "分钟")
}

private func luminaExpiry(_ date: Date?) -> ExpiryDisplay {
    guard let date else {
        return ExpiryDisplay(value: "-", unit: "", color: Theme.luminaTextTertiary)
    }
    let days = Int(floor(date.timeIntervalSinceNow / 86_400))
    if days > 36_500 {
        return ExpiryDisplay(value: "长期", unit: "", color: Theme.luminaOnline)
    }
    if days > 30 {
        return ExpiryDisplay(value: "\(days)", unit: "天", color: Theme.luminaOnline)
    }
    if days > 7 {
        return ExpiryDisplay(value: "\(days)", unit: "天", color: Theme.yellow)
    }
    if days > 0 {
        return ExpiryDisplay(value: "\(days)", unit: "天", color: Theme.luminaDisk)
    }
    if days == 0 {
        return ExpiryDisplay(value: "今日", unit: "", color: Theme.luminaDisk)
    }
    return ExpiryDisplay(value: "已过期", unit: "", color: Theme.luminaOffline)
}

private func luminaLatencyColor(_ latency: Double?) -> Color {
    guard let latency, latency.isFinite, latency > 0 else {
        return Theme.luminaTextTertiary
    }
    if latency <= 100 { return hslColor(hue: 145 - 18 * latency / 100, saturation: 62 + 8 * latency / 100, lightness: 48 + 3 * latency / 100) }
    if latency <= 150 {
        let t = (latency - 100) / 50
        return hslColor(hue: 127 - 47 * t, saturation: 70 + 6 * t, lightness: 51 + t)
    }
    if latency <= 200 {
        let t = (latency - 150) / 50
        return hslColor(hue: 80 - 30 * t, saturation: 76 + 6 * t, lightness: 52 + t)
    }
    if latency <= 300 {
        let t = (latency - 200) / 100
        return hslColor(hue: 50 - 20 * t, saturation: 82 + 4 * t, lightness: 53 - t)
    }
    let t = min(1, (latency - 300) / 300)
    return hslColor(hue: 30 - 24 * t, saturation: 86 - 2 * t, lightness: 52 - 8 * t)
}

private func luminaLossColor(_ loss: Double?) -> Color {
    guard let loss, loss.isFinite, loss >= 0 else {
        return Theme.luminaTextTertiary
    }
    if loss <= 1 {
        let t = loss / 1
        return hslColor(hue: 145 - 18 * t, saturation: 62 + 8 * t, lightness: 48 + 3 * t)
    }
    if loss <= 3 {
        let t = (loss - 1) / 2
        return hslColor(hue: 127 - 47 * t, saturation: 70 + 6 * t, lightness: 51 + t)
    }
    if loss <= 5 {
        let t = (loss - 3) / 2
        return hslColor(hue: 80 - 30 * t, saturation: 76 + 6 * t, lightness: 52 + t)
    }
    if loss <= 10 {
        let t = (loss - 5) / 5
        return hslColor(hue: 50 - 20 * t, saturation: 82 + 4 * t, lightness: 53 - t)
    }
    let t = min(1, (loss - 10) / 20)
    return hslColor(hue: 30 - 24 * t, saturation: 86 - 2 * t, lightness: 52 - 8 * t)
}

private func hslColor(hue: Double, saturation: Double, lightness: Double) -> Color {
    let h = max(0, min(360, hue)) / 360
    let s = max(0, min(100, saturation)) / 100
    let l = max(0, min(100, lightness)) / 100
    if s == 0 {
        return Color(red: l, green: l, blue: l)
    }
    let q = l < 0.5 ? l * (1 + s) : l + s - l * s
    let p = 2 * l - q
    return Color(
        red: hueComponent(p: p, q: q, t: h + 1 / 3),
        green: hueComponent(p: p, q: q, t: h),
        blue: hueComponent(p: p, q: q, t: h - 1 / 3)
    )
}

private func hueComponent(p: Double, q: Double, t: Double) -> Double {
    var t = t
    if t < 0 { t += 1 }
    if t > 1 { t -= 1 }
    if t < 1 / 6 { return p + (q - p) * 6 * t }
    if t < 1 / 2 { return q }
    if t < 2 / 3 { return p + (q - p) * (2 / 3 - t) * 6 }
    return p
}

private func flagDisplay(_ region: String) -> String {
    let normalized = region.trimmingCharacters(in: .whitespacesAndNewlines)
    if normalized.isEmpty { return "🌐" }
    if normalized.unicodeScalars.contains(where: { $0.value >= 127_462 && $0.value <= 127_487 }) {
        return normalized
    }
    if normalized.count == 2, normalized.range(of: "^[A-Za-z]{2}$", options: .regularExpression) != nil {
        return regionalFlag(normalized.uppercased())
    }
    if let code = regionNameToCountryCode[normalized.lowercased()] {
        return regionalFlag(code)
    }
    return "🌐"
}

private func regionalFlag(_ code: String) -> String {
    let scalars = code.uppercased().unicodeScalars.compactMap { scalar -> UnicodeScalar? in
        guard scalar.value >= 65, scalar.value <= 90 else { return nil }
        return UnicodeScalar(127_397 + scalar.value)
    }
    guard scalars.count == 2 else { return "🌐" }
    return String(String.UnicodeScalarView(scalars))
}

private let regionNameToCountryCode: [String: String] = [
    "us": "US",
    "usa": "US",
    "united states": "US",
    "america": "US",
    "美国": "US",
    "jp": "JP",
    "japan": "JP",
    "日本": "JP",
    "hk": "HK",
    "hong kong": "HK",
    "香港": "HK",
    "sg": "SG",
    "singapore": "SG",
    "新加坡": "SG",
    "tw": "TW",
    "taiwan": "TW",
    "台湾": "TW",
    "kr": "KR",
    "korea": "KR",
    "south korea": "KR",
    "韩国": "KR",
    "cn": "CN",
    "china": "CN",
    "中国": "CN",
    "de": "DE",
    "germany": "DE",
    "德国": "DE",
    "gb": "GB",
    "uk": "GB",
    "united kingdom": "GB",
    "英国": "GB",
    "fr": "FR",
    "france": "FR",
    "法国": "FR",
    "nl": "NL",
    "netherlands": "NL",
    "荷兰": "NL",
    "ca": "CA",
    "canada": "CA",
    "加拿大": "CA",
    "au": "AU",
    "australia": "AU",
    "澳大利亚": "AU"
]
