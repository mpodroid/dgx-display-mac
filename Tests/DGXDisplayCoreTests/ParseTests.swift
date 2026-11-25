import XCTest
@testable import DGXDisplayCore

final class ParseTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testFixtureParsesSS1Line() {
        let line = """
        SS1 {"host":"spark-b1fa","state":"serve","model":"GLM-5.3-Flash-EXL3","loading":false,"gpu_c":72.0,"soc_c":71.0,"cpu_c":68.0,"mem_gib":18.4,"decode_tps":62.0,"decode_age_s":0.0,"prefill_tps":1480.0,"prefill_age_s":0.0,"ip":"192.168.2.133","gw":"192.168.2.1","mgmt_rx":1250000,"mgmt_tx":84000,"roce_rx":410000000,"roce_tx":12000000,"mgmt_err":0,"ddev":"nvme0n1","dri":1200,"daw":1.2,"dps":0.4,"dcache":0.9,"dswap":105,"dswtotal":16384,"mtot":121.7,"mused":116.5,"dpm":0,"role":"head","engine_ok":true,"waiting":2,"connections":1,"pair_stalled":false,"pair_broken":false,"roce":["up","up"],"net":"up"}
        """
        let sample = parseSS1(line, receivedAt: now)
        XCTAssertEqual(sample?.host, "spark-b1fa")
        XCTAssertEqual(sample?.model, "GLM-5.3-Flash-EXL3")
        XCTAssertEqual(sample?.role, "head")
        XCTAssertEqual(sample?.state, "serve")
        XCTAssertEqual(sample?.loading, false)
        XCTAssertEqual(sample?.engineOK, true)
        XCTAssertEqual(sample?.decodeTPS, 62)
        XCTAssertEqual(sample?.prefillTPS, 1480)
        XCTAssertEqual(sample?.waiting, 2)
        XCTAssertEqual(sample?.connections, 1)
        XCTAssertEqual(sample?.queue, 3)
        XCTAssertEqual(sample?.socC, 71)
        XCTAssertEqual(sample?.gpuC, 72)
        XCTAssertEqual(sample?.cpuC, 68)
        XCTAssertEqual(sample?.memGiB, 18.4)
        XCTAssertEqual(sample?.ip, "192.168.2.133")
        XCTAssertEqual(sample?.gateway, "192.168.2.1")
        XCTAssertEqual(sample?.mgmtRX, 1_250_000)
        XCTAssertEqual(sample?.roceRX, 410_000_000)
        XCTAssertEqual(sample?.roce0, "up")
        XCTAssertEqual(sample?.roce1, "up")
        XCTAssertEqual(sample?.diskDevice, "nvme0n1")
        XCTAssertEqual(sample?.readIOPS, 1200)
        XCTAssertEqual(sample?.awaitMS, 1.2)
        XCTAssertEqual(sample?.memTotalGiB, 121.7)
        XCTAssertEqual(sample?.memUsedGiB, 116.5)
        XCTAssertEqual(sample?.pairWord, "OK")
        XCTAssertEqual(sample?.pairColor, .serve)
        XCTAssertEqual(sample?.linkColor, .serve)
        XCTAssertEqual(Face.resolve(sample: sample, now: now, sessionAge: nil), .serve)
    }

    func testFaceFollowsFirmwareOrder() {
        XCTAssertEqual(face(#"{"state":"halt","decode_tps":40}"#, age: 9), .halt)
        XCTAssertEqual(face(#"{"decode_tps":62,"role":"head"}"#, age: 5), .serve)
        XCTAssertEqual(face(#"{"decode_tps":62,"role":"head"}"#, age: 5.01), .wedge)
        XCTAssertEqual(face(#"{"loading":true,"decode_tps":62,"role":"head"}"#), .load)
        XCTAssertEqual(face(#"{"stall":"disk","stall_s":5,"decode_tps":10,"role":"head"}"#), .stall)
        XCTAssertEqual(face(#"{"stall":"disk","stall_s":4,"role":"head"}"#), .idle)
        XCTAssertEqual(face(#"{"engine_ok":false,"role":"head","decode_tps":20}"#), .down)
        XCTAssertEqual(face(#"{"engine_ok":false,"role":"worker","decode_tps":20}"#), .up)
        XCTAssertEqual(face(#"{"engine_ok":false}"#), .up)
        XCTAssertEqual(face(#"{"role":"worker","decode_tps":80}"#), .up)
        XCTAssertEqual(face(#"{"state":"serve","role":"head"}"#), .idle)
        XCTAssertEqual(Face.resolve(sample: nil, now: now, sessionAge: 1), .boot)
        XCTAssertEqual(Face.resolve(sample: nil, now: now, sessionAge: 5.01), .wedge)
        XCTAssertEqual(Face.resolve(sample: nil, now: now, sessionAge: nil), .boot)
    }

    func testMissingAndNegativeFields() {
        let empty = parseSS1("SS1 {}", receivedAt: now)
        XCTAssertEqual(empty?.host, "spark")
        XCTAssertEqual(empty?.state, "up")
        XCTAssertEqual(empty?.roce0, "down")
        XCTAssertEqual(empty?.roce1, "down")
        XCTAssertEqual(empty?.engineOK, nil)
        XCTAssertEqual(Face.resolve(sample: empty, now: now, sessionAge: nil), .idle)

        let oneLink = parseSS1(#"SS1 {"roce":["up"]}"#, receivedAt: now)
        XCTAssertEqual(oneLink?.roce0, "up")
        XCTAssertEqual(oneLink?.roce1, "down")
        XCTAssertEqual(oneLink?.linkColor, .wedge)

        let negative = parseSS1(#"SS1 {"mgmt_rx":-5,"waiting":-3,"pct":140,"eta_s":-1}"#, receivedAt: now)
        XCTAssertNil(negative?.mgmtRX)
        XCTAssertEqual(negative?.waiting, 0)
        XCTAssertEqual(negative?.percent, 100)
        XCTAssertNil(negative?.etaSeconds)

        XCTAssertNil(parseSS1("not a sample"))
        XCTAssertNil(parseSS1("SS1 "))
        XCTAssertNil(parseSS1("SS1 []"))
        XCTAssertNil(parseSS1("SS1 {"))
    }

    func testRatesCountsAndDuration() {
        XCTAssertEqual(formatRate(999), "999B/s")
        XCTAssertEqual(formatRate(1000), "1.0k/s")
        XCTAssertEqual(formatRate(1_500_000), "1.5M/s")
        XCTAssertEqual(formatRate(1_500_000_000), "1.5G/s")
        XCTAssertEqual(formatRate(nil), "--")
        XCTAssertEqual(formatCount(999), "999")
        XCTAssertEqual(formatCount(1000), "1k")
        XCTAssertEqual(formatCount(1_500_000), "1.5M")
        XCTAssertEqual(formatDuration(45), "45s")
        XCTAssertEqual(formatDuration(90), "1m30s")
        XCTAssertEqual(formatDuration(3700), "1h01m")
    }

    func testRateOpacityFades() {
        let sample = parseSS1(#"SS1 {"decode_tps":10,"decode_age_s":0,"prefill_tps":10,"prefill_age_s":0}"#, receivedAt: now)
        XCTAssertEqual(sample?.decodeOpacity(at: now.addingTimeInterval(7)), 1)
        XCTAssertEqual(sample?.decodeOpacity(at: now.addingTimeInterval(8.5)) ?? -1, 0.5, accuracy: 0.001)
        XCTAssertEqual(sample?.decodeOpacity(at: now.addingTimeInterval(10)), 0)
        XCTAssertEqual(sample?.prefillOpacity(at: now.addingTimeInterval(2)), 1)
        XCTAssertEqual(sample?.prefillOpacity(at: now.addingTimeInterval(4)), 0)
    }

    func testPageOrderAndSSHArguments() {
        XCTAssertEqual(PanelPage.face.next, .service)
        XCTAssertEqual(PanelPage.service.next, .disk)
        XCTAssertEqual(PanelPage.disk.next, .network)
        XCTAssertEqual(PanelPage.network.next, .memory)
        XCTAssertEqual(PanelPage.memory.next, .cluster)
        XCTAssertEqual(PanelPage.cluster.next, .face)

        let launch = SSHLaunch(user: "admin", host: "spark-b1fa.local", identityPath: "/tmp/nvsync.key")
        XCTAssertEqual(launch.arguments, [
            "-4",
            "-o", "BatchMode=yes",
            "-o", "IdentitiesOnly=yes",
            "-o", "PasswordAuthentication=no",
            "-o", "KbdInteractiveAuthentication=no",
            "-o", "ConnectTimeout=8",
            "-o", "ServerAliveInterval=5",
            "-o", "ServerAliveCountMax=2",
            "-o", "StrictHostKeyChecking=accept-new",
            "-i", "/tmp/nvsync.key",
            "admin@spark-b1fa.local",
            "/usr/bin/dgx-display-writer --follow",
        ])
        XCTAssertEqual(
            sshTrouble("ssh: connect to host spark-b1fa.local port 22: No route to host"),
            "No route to host. Allow Local Network for DGX Display."
        )
        XCTAssertEqual(sshTrouble("SSH exited (255)"), "SSH exited (255)")
        XCTAssertTrue(SSHLaunch.defaultIdentity.hasSuffix("Library/Application Support/NVIDIA/Sync/config/nvsync.key"))
        XCTAssertEqual(expandTilde("~/Library/key"), SSHLaunch.defaultIdentity.replacingOccurrences(
            of: "Application Support/NVIDIA/Sync/config/nvsync.key",
            with: "key"
        ))
    }

    func testMenuBarReportsServeRatesAndStallIO() {
        let line = """
        SS1 {"host":"spark-b1fa","state":"serve","role":"head","decode_tps":62.0,"decode_age_s":0,"prefill_tps":1480.0,"prefill_age_s":0,"dri":1200,"dwi":40}
        """
        let sample = parseSS1(line, receivedAt: now)
        let serving = menuMark(face: .serve, sample: sample, now: now)
        XCTAssertEqual(serving.state.text, "SERVE")
        XCTAssertEqual(serving.state.rgb, .serve)
        XCTAssertEqual(serving.title, "62  1480")
        XCTAssertEqual(serving.tooltip, "DGX Display SERVE  decode 62 t/s, prefill 1480 t/s")

        let faded = menuMark(face: .serve, sample: sample, now: now.addingTimeInterval(5))
        XCTAssertEqual(faded.state.rgb, .serve)
        XCTAssertEqual(faded.title, "62  --")

        let stalled = parseSS1(
            #"SS1 {"stall":"disk","stall_s":6,"dri":98000,"dwi":2000,"role":"head"}"#,
            receivedAt: now
        )
        XCTAssertEqual(Face.resolve(sample: stalled, now: now, sessionAge: nil), .stall)
        let stall = menuMark(face: .stall, sample: stalled, now: now)
        XCTAssertEqual(stall.state.text, "STALL")
        XCTAssertEqual(stall.state.rgb, .stall)
        XCTAssertEqual(stall.title, "100k io/s")
        XCTAssertEqual(stall.tooltip, "DGX Display STALL  IO requests 100k io/s")

        let quiet = parseSS1(#"SS1 {"stall":"mem","stall_s":5,"role":"head"}"#, receivedAt: now)
        let quietMark = menuMark(face: .stall, sample: quiet, now: now)
        XCTAssertEqual(quietMark.state.rgb, .stall)
        XCTAssertEqual(quietMark.title, "--")
        let idle = menuMark(face: .idle, sample: nil, now: now)
        XCTAssertEqual(idle.state.text, "IDLE")
        XCTAssertEqual(idle.title, "")
        XCTAssertEqual(formatMenuCount(1200), "1200")
        XCTAssertEqual(formatMenuCount(9999), "9999")
        XCTAssertEqual(formatMenuCount(10_000), "10k")
    }

    func testColorsMatchThePanel() {
        XCTAssertEqual(Face.serve.rgb, RGB(r: 40, g: 210, b: 120))
        XCTAssertEqual(Face.wedge.rgb, RGB(r: 255, g: 50, b: 50))
        XCTAssertEqual(Face.stall.rgb, RGB(r: 255, g: 150, b: 0))
        XCTAssertEqual(Face.load.rgb, Face.boot.rgb)
        XCTAssertEqual(severityColor(80_000, amber: 50_000, red: 80_000), .wedge)
        XCTAssertEqual(severityColor(50_000, amber: 50_000, red: 80_000), .stall)
        XCTAssertEqual(oomColor(1.5), .wedge)
        XCTAssertEqual(oomColor(4), .stall)
        XCTAssertEqual(oomColor(18), .serve)
        XCTAssertEqual(oomColor(nil), .dim)
    }

    private func face(_ json: String, age: TimeInterval = 0) -> Face {
        let sample = parseSS1("SS1 " + json, receivedAt: now.addingTimeInterval(-age))
        return Face.resolve(sample: sample, now: now, sessionAge: nil)
    }
}
