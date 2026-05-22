import Foundation

@MainActor
final class KomariStore: ObservableObject {
    @Published private(set) var nodes: [NodeViewModel] = []
    @Published private(set) var connected = false
    @Published private(set) var lastError: String?
    @Published private(set) var realtimeMode = "polling"

    private let client: KomariClient
    private var nodeInfo: [String: NodeInfo] = [:]
    private var statuses: [String: NodeStatus] = [:]
    private var pings: [String: PingInfo] = [:]
    private var refreshTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var statusPollTask: Task<Void, Never>?
    private var realtimeFlushTask: Task<Void, Never>?
    private var realtimeDirty = false

    init(config: Config) {
        self.client = KomariClient(config: config)
    }

    func start() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            await self?.bootstrap()
            await self?.client.connectWebSocket { [weak self] data in
                Task { @MainActor in
                    self?.connected = true
                    self?.applyRealtime(data)
                }
            } onClose: { [weak self] message in
                Task { @MainActor in
                    self?.connected = false
                    self?.realtimeMode = "polling"
                }
            }
        }
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                await self?.refreshPing()
            }
        }
        statusPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                await self?.pollStatusIfNeeded()
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        pingTask?.cancel()
        statusPollTask?.cancel()
        realtimeFlushTask?.cancel()
        client.disconnect()
    }

    func refresh() {
        Task { await bootstrap() }
    }

    private func bootstrap() async {
        do {
            let fetchedNodes = try await client.fetchNodes()
            nodeInfo = Dictionary(uniqueKeysWithValues: fetchedNodes.map { ($0.id, $0) })
            statuses = try await client.fetchLatestStatus(uuids: fetchedNodes.map(\.id))
            pings = try await client.fetchPingSummary()
            rebuild()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func refreshPing() async {
        do {
            pings = try await client.fetchPingSummary()
            rebuild()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func pollStatusIfNeeded() async {
        guard !connected else { return }
        do {
            statuses = try await client.fetchLatestStatus(uuids: Array(nodeInfo.keys))
            rebuild()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func applyRealtime(_ data: Data) {
        guard let payload = try? JSONSerialization.jsonObject(with: data) else { return }
        let records: [[String: Any]]
        if let list = payload as? [[String: Any]] {
            records = list
        } else if let dict = payload as? [String: Any], let list = dict["clients"] as? [[String: Any]] {
            records = list
        } else if let dict = payload as? [String: Any], let list = dict["data"] as? [[String: Any]] {
            records = list
        } else if let dict = payload as? [String: Any],
                  let wrapper = dict["data"] as? [String: Any],
                  let map = wrapper["data"] as? [String: [String: Any]] {
            let online = Set(wrapper["online"] as? [String] ?? [])
            records = map.map { uuid, status in
                var copy = status
                copy["uuid"] = uuid
                copy["online"] = online.contains(uuid)
                return copy
            }
        } else if let dict = payload as? [String: Any] {
            records = [dict]
        } else {
            return
        }

        for record in records {
            let uuid = string(record["uuid"]).isEmpty ? string(record["client"]) : string(record["uuid"])
            guard !uuid.isEmpty else { continue }
            if let info = parseNodeInfo(record), nodeInfo[uuid] == nil {
                nodeInfo[uuid] = info
            }
            statuses[uuid] = parseStatus(record, node: nodeInfo[uuid])
        }
        realtimeMode = "websocket"
        scheduleRealtimeFlush()
    }

    private func scheduleRealtimeFlush() {
        realtimeDirty = true
        guard realtimeFlushTask == nil else { return }
        realtimeFlushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            await MainActor.run {
                guard let self else { return }
                self.realtimeFlushTask = nil
                if self.realtimeDirty {
                    self.realtimeDirty = false
                    self.rebuild()
                }
            }
        }
    }

    private func rebuild() {
        let ordered = nodeInfo.values.sorted { lhs, rhs in
            if lhs.region == rhs.region { return lhs.name < rhs.name }
            return lhs.region < rhs.region
        }
        nodes = ordered.map { info in
            NodeViewModel(
                node: info,
                status: statuses[info.id] ?? NodeStatus(),
                ping: pings[info.id] ?? PingInfo()
            )
        }
    }
}

final class KomariClient: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let config: Config
    private var wsTask: URLSessionWebSocketTask?
    private var wsGetLoopTask: Task<Void, Never>?
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    init(config: Config) {
        self.config = config
        super.init()
    }

    func fetchNodes() async throws -> [NodeInfo] {
        let result = try await rpc(method: "common:getNodes", params: [:])
        let list = unwrapList(result)
        return list.compactMap(parseNodeInfo)
    }

    func fetchLatestStatus(uuids: [String]) async throws -> [String: NodeStatus] {
        let result = try await rpc(method: "common:getNodesLatestStatus", params: ["uuids": uuids])
        var out: [String: NodeStatus] = [:]
        if let map = result as? [String: [String: Any]] {
            for (uuid, raw) in map {
                out[uuid] = parseStatus(raw, node: nil)
            }
        } else {
            for raw in unwrapList(result) {
                let uuid = string(raw["uuid"]).isEmpty ? string(raw["client"]) : string(raw["uuid"])
                if !uuid.isEmpty {
                    out[uuid] = parseStatus(raw, node: nil)
                }
            }
        }
        return out
    }

    func fetchPingSummary() async throws -> [String: PingInfo] {
        let result = try await rpc(method: "common:getRecords", params: ["type": "ping", "hours": 1, "maxCount": 500])
        guard let dict = result as? [String: Any] else { return [:] }
        var out: [String: PingInfo] = [:]

        for item in (dict["basic_info"] as? [[String: Any]] ?? dict["basicInfo"] as? [[String: Any]] ?? []) {
            let client = string(item["client"])
            guard !client.isEmpty else { continue }
            out[client, default: PingInfo()].loss = number(item["loss"])
        }

        var series: [String: [(Date, Double)]] = [:]
        for record in dict["records"] as? [[String: Any]] ?? [] {
            let client = string(record["client"])
            guard !client.isEmpty else { continue }
            let date = parseDate(record["time"]) ?? .distantPast
            series[client, default: []].append((date, number(record["value"])))
        }

        for (client, points) in series {
            let sorted = points.sorted { $0.0 < $1.0 }.suffix(18)
            let values = sorted.map(\.1)
            out[client, default: PingInfo()].latency = values.last
            out[client, default: PingInfo()].latencies = values
            out[client, default: PingInfo()].drops = values.map { $0 < 0 }
            if out[client]?.loss == nil, !values.isEmpty {
                out[client]?.loss = Double(values.filter { $0 < 0 }.count) / Double(values.count) * 100
            }
        }
        return out
    }

    func connectWebSocket(onMessage: @escaping @Sendable (Data) -> Void, onClose: @escaping @Sendable (String?) -> Void) async {
        disconnect()
        guard var components = URLComponents(string: config.baseURL) else {
            onClose("Invalid base URL")
            return
        }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = "/api/clients"
        guard let url = components.url else {
            onClose("Invalid WebSocket URL")
            return
        }

        var request = URLRequest(url: url)
        applyAuth(to: &request)
        request.setValue(config.baseURL, forHTTPHeaderField: "Origin")
        let task = session.webSocketTask(with: request)
        wsTask = task
        task.resume()
        startGetLoop(task: task)
        receiveLoop(task: task, onMessage: onMessage, onClose: onClose)
    }

    func disconnect() {
        wsGetLoopTask?.cancel()
        wsGetLoopTask = nil
        wsTask?.cancel(with: .goingAway, reason: nil)
        wsTask = nil
    }

    private func startGetLoop(task: URLSessionWebSocketTask) {
        wsGetLoopTask?.cancel()
        wsGetLoopTask = Task { [weak self, weak task] in
            while !Task.isCancelled {
                guard let self, let task, self.wsTask === task else { return }
                do {
                    try await task.send(.string("get"))
                } catch {
                    return
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func receiveLoop(task: URLSessionWebSocketTask, onMessage: @escaping @Sendable (Data) -> Void, onClose: @escaping @Sendable (String?) -> Void) {
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        onMessage(data)
                    }
                case .data(let data):
                    onMessage(data)
                @unknown default:
                    break
                }
                self.receiveLoop(task: task, onMessage: onMessage, onClose: onClose)
            case .failure(let error):
                onClose(error.localizedDescription)
                DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                    Task { await self.connectWebSocket(onMessage: onMessage, onClose: onClose) }
                }
            }
        }
    }

    private func rpc(method: String, params: [String: Any]) async throws -> Any {
        var request = URLRequest(url: URL(string: config.baseURL + "/api/rpc2")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuth(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "id": Int(Date().timeIntervalSince1970 * 1000) % 1_000_000,
            "method": method,
            "params": params
        ])
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data)
        guard let dict = json as? [String: Any] else { return json }
        if let error = dict["error"] {
            throw NSError(domain: "Komari", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(error)"])
        }
        return dict["result"] ?? json
    }

    private func applyAuth(to request: inout URLRequest) {
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        var cookie = config.cookie
        if !config.sessionToken.isEmpty {
            cookie = cookie.isEmpty ? "session_token=\(config.sessionToken)" : "\(cookie); session_token=\(config.sessionToken)"
        }
        if !cookie.isEmpty {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
    }
}

func unwrapList(_ value: Any) -> [[String: Any]] {
    if let list = value as? [[String: Any]] { return list }
    if let dict = value as? [String: Any] {
        for key in ["nodes", "records", "data"] {
            if let list = dict[key] as? [[String: Any]] { return list }
            if let map = dict[key] as? [String: [String: Any]] {
                return map.map { key, value in
                    var copy = value
                    copy["uuid"] = copy["uuid"] ?? key
                    return copy
                }
            }
        }
        if dict["uuid"] != nil { return [dict] }
        if dict.values.allSatisfy({ $0 is [String: Any] }) {
            return dict.compactMap { key, value in
                guard var copy = value as? [String: Any] else { return nil }
                copy["uuid"] = copy["uuid"] ?? key
                return copy
            }
        }
    }
    return []
}

func parseNodeInfo(_ raw: [String: Any]) -> NodeInfo? {
    let uuid = string(raw["uuid"]).isEmpty ? string(raw["client"]) : string(raw["uuid"])
    guard !uuid.isEmpty else { return nil }
    return NodeInfo(
        id: uuid,
        name: string(raw["name"]).isEmpty ? String(uuid.prefix(8)) : string(raw["name"]),
        region: string(raw["region"]),
        os: string(raw["os"]),
        arch: string(raw["arch"]),
        virtualization: string(raw["virtualization"]),
        cpuCores: Int(number(raw["cpu_cores"])),
        trafficLimit: number(raw["traffic_limit"]),
        expiresAt: parseDate(raw["expired_at"]) ?? parseDate(raw["expire_at"]) ?? parseDate(raw["expiry"])
    )
}

func parseStatus(_ raw: [String: Any], node: NodeInfo?) -> NodeStatus {
    func nested(_ key: String, _ child: String) -> Any? {
        (raw[key] as? [String: Any])?[child]
    }
    let updatedAt = parseDate(raw["updated_at"]) ?? parseDate(raw["time"]) ?? Date()
    let memTotal = number(nested("ram", "total") ?? raw["ram_total"] ?? raw["mem_total"])
    let memUsedRaw = nested("ram", "used") ?? raw["ram"]
    let memUsed = number(memUsedRaw) <= 100 && memTotal > 0 ? memTotal * number(memUsedRaw) / 100 : number(memUsedRaw)
    let diskTotal = number(nested("disk", "total") ?? raw["disk_total"])
    let diskUsedRaw = nested("disk", "used") ?? raw["disk"]
    let diskUsed = number(diskUsedRaw) <= 100 && diskTotal > 0 ? diskTotal * number(diskUsedRaw) / 100 : number(diskUsedRaw)

    var status = NodeStatus()
    status.online = (raw["online"] as? Bool) ?? (Date().timeIntervalSince(updatedAt) < 180)
    status.cpu = min(100, max(0, number(nested("cpu", "usage") ?? raw["cpu"])))
    status.memUsed = memUsed
    status.memTotal = memTotal
    status.diskUsed = diskUsed
    status.diskTotal = diskTotal
    status.netUp = number(nested("network", "up") ?? raw["net_out"] ?? raw["net_up"])
    status.netDown = number(nested("network", "down") ?? raw["net_in"] ?? raw["net_down"])
    status.trafficUp = number(nested("network", "totalUp") ?? raw["net_total_up"])
    status.trafficDown = number(nested("network", "totalDown") ?? raw["net_total_down"])
    status.load1 = number(nested("load", "load1") ?? raw["load"])
    status.load5 = number(nested("load", "load5") ?? raw["load5"])
    status.load15 = number(nested("load", "load15") ?? raw["load15"])
    status.uptime = number(raw["uptime"])
    status.updatedAt = updatedAt
    return status
}
