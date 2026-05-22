import Foundation

struct Config: Codable, Equatable {
    var baseURL: String
    var apiKey: String
    var sessionToken: String
    var cookie: String
    var verifyTLS: Bool

    enum CodingKeys: String, CodingKey {
        case baseURL = "base_url"
        case apiKey = "api_key"
        case sessionToken = "session_token"
        case cookie
        case verifyTLS = "verify_tls"
    }

    static let path = NSString(string: "~/.config/komari-swiftbar/config.json").expandingTildeInPath

    static var empty: Config {
        Config(baseURL: "", apiKey: "", sessionToken: "", cookie: "", verifyTLS: true)
    }

    static func load() throws -> Config {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        var config = try JSONDecoder().decode(Config.self, from: data)
        config.normalize()
        return config
    }

    static func save(_ config: Config) throws {
        var normalized = config
        normalized.normalize()
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(normalized)
        try data.write(to: url, options: [.atomic])
    }

    mutating func normalize() {
        baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if baseURL.hasSuffix("/") {
            baseURL.removeLast()
        }
        apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        sessionToken = sessionToken.trimmingCharacters(in: .whitespacesAndNewlines)
        cookie = cookie.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct NodeInfo: Identifiable {
    let id: String
    var name: String
    var region: String
    var os: String
    var arch: String
    var virtualization: String
    var cpuCores: Int
    var trafficLimit: Double
    var expiresAt: Date?
}

struct NodeStatus {
    var online = false
    var cpu = 0.0
    var memUsed = 0.0
    var memTotal = 0.0
    var diskUsed = 0.0
    var diskTotal = 0.0
    var netUp = 0.0
    var netDown = 0.0
    var trafficUp = 0.0
    var trafficDown = 0.0
    var load1 = 0.0
    var load5 = 0.0
    var load15 = 0.0
    var uptime = 0.0
    var updatedAt = Date.distantPast

    var memPct: Double { memTotal > 0 ? memUsed / memTotal * 100 : 0 }
    var diskPct: Double { diskTotal > 0 ? diskUsed / diskTotal * 100 : 0 }
    var trafficUsed: Double { trafficUp + trafficDown }
}

struct PingInfo {
    var latency: Double?
    var loss: Double?
    var latencies: [Double] = []
    var drops: [Bool] = []
}

struct NodeViewModel: Identifiable {
    var node: NodeInfo
    var status: NodeStatus
    var ping: PingInfo

    var id: String { node.id }

    var trafficPct: Double {
        node.trafficLimit > 0 ? status.trafficUsed / node.trafficLimit * 100 : 0
    }

    var currentLoss: Bool {
        ping.drops.last ?? false
    }
}
