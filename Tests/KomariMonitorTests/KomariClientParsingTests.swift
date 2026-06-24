import XCTest
@testable import KomariMonitor

final class KomariClientParsingTests: XCTestCase {
    func testParsesHomepagePingBindingsFromThemeSettings() {
        let response: [String: Any] = [
            "status": "success",
            "data": [
                "theme_settings": [
                    "homepagePingBindings": [
                        "6": ["node-a", "node-b"],
                        "9": ["node-c", "node-a"]
                    ]
                ]
            ]
        ]

        XCTAssertEqual(
            parseHomepagePingBindings(response),
            [
                "node-a": 6,
                "node-b": 6,
                "node-c": 9
            ]
        )
    }

    func testHomepagePingRecordsUseOnlyBoundTask() {
        let records: [[String: Any]] = [
            [
                "task_id": 3,
                "client": "node-a",
                "time": "2026-06-24T00:00:00Z",
                "value": 194
            ],
            [
                "task_id": 6,
                "client": "node-a",
                "time": "2026-06-24T00:01:00Z",
                "value": 67
            ],
            [
                "task_id": 6,
                "client": "node-a",
                "time": "2026-06-24T00:02:00Z",
                "value": 68
            ]
        ]

        let ping = parsePingRecords(taskId: 6, records: records)["node-a"]

        XCTAssertEqual(ping?.latency, 68)
        XCTAssertEqual(ping?.loss, 0)
        XCTAssertEqual(ping?.latencies, [67, 68])
        XCTAssertEqual(ping?.drops, [false, false])
    }

    func testHomepagePingRecordsTreatZeroAndNegativeAsLossLikeFrontend() {
        let records: [[String: Any]] = [
            [
                "task_id": 6,
                "client": "node-a",
                "time": "2026-06-24T00:00:00Z",
                "value": 0
            ],
            [
                "task_id": 6,
                "client": "node-a",
                "time": "2026-06-24T00:01:00Z",
                "value": -1
            ],
            [
                "task_id": 6,
                "client": "node-a",
                "time": "2026-06-24T00:02:00Z",
                "value": 35
            ]
        ]

        let ping = parsePingRecords(taskId: 6, records: records)["node-a"]

        XCTAssertEqual(ping?.latency, 35)
        XCTAssertEqual(ping?.loss ?? -1, 200.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(ping?.latencies, [-1, -1, 35])
        XCTAssertEqual(ping?.drops, [true, true, false])
    }

    func testParsesPingTaskListAsEmptyHomepageBindings() {
        let tasks: [[String: Any]] = [
            [
                "id": 3,
                "clients": ["node-a", "node-b"],
                "interval": 60
            ]
        ]

        XCTAssertEqual(parseHomepagePingBindings(tasks), [:])
    }

    func testExtractsRootLevelWebSocketDataMap() {
        let payload: [String: Any] = [
            "online": ["node-a"],
            "data": [
                "node-a": [
                    "cpu": ["usage": 12.5],
                    "updated_at": "2026-06-24T00:00:00Z"
                ]
            ],
            "status": "success"
        ]

        let records = realtimeRecords(from: payload)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?["uuid"] as? String, "node-a")
        XCTAssertEqual(records.first?["client"] as? String, "node-a")
        XCTAssertEqual(records.first?["online"] as? Bool, true)
    }

    func testExtractsNestedWebSocketDataMap() {
        let payload: [String: Any] = [
            "status": "success",
            "data": [
                "online": ["node-b"],
                "data": [
                    "node-b": [
                        "cpu": ["usage": 20],
                        "updated_at": "2026-06-24T00:00:00Z"
                    ]
                ]
            ]
        ]

        let records = realtimeRecords(from: payload)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?["uuid"] as? String, "node-b")
        XCTAssertEqual(records.first?["client"] as? String, "node-b")
        XCTAssertEqual(records.first?["online"] as? Bool, true)
    }
}
