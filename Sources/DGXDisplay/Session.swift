import DGXDisplayCore
import Foundation

/// Keeps a single `ssh` process open. A dropped session reconnects with a
/// short backoff. A changed host, user, or key starts a new session.
final class HeadSession {
    private let queue = DispatchQueue(label: "dgx-display-mac.session")
    private weak var store: Store?
    private var process: Process?
    private var stdout: FileHandle?
    private var stderr: FileHandle?
    private var buffer = Data()
    private var errorBuffer = Data()
    private var generation = 0
    private var wantsRun = false
    private var backoff: TimeInterval = 1
    private let maxBackoff: TimeInterval = 15
    private var current: SSHLaunch?

    func bind(_ store: Store) {
        self.store = store
    }

    func start(_ launch: SSHLaunch) {
        queue.async {
            self.wantsRun = true
            self.generation += 1
            self.backoff = 1
            self.spawn(self.generation, launch)
        }
    }

    func retarget(_ launch: SSHLaunch) {
        queue.async {
            guard self.wantsRun else { return }
            if launch == self.current, self.process?.isRunning == true {
                return
            }
            let changed = self.current != nil && launch != self.current
            self.generation += 1
            self.backoff = 1
            let gen = self.generation
            self.killProcess()
            if changed {
                self.publish(gen) { $0.resetForNewTarget(gen: gen) }
            }
            self.spawn(gen, launch)
        }
    }

    func stop() {
        queue.sync {
            self.wantsRun = false
            self.generation += 1
            self.killProcess()
            self.current = nil
        }
    }

    func noteLive() {
        queue.async {
            self.backoff = 1
        }
    }

    /// Starts a new session when the previous `ssh` has already exited.
    /// Used after macOS grants Local Network access.
    func retryIfDown() {
        queue.async {
            guard self.wantsRun, let launch = self.current else { return }
            if self.process?.isRunning == true { return }
            self.generation += 1
            self.backoff = 1
            self.spawn(self.generation, launch)
        }
    }

    private func spawn(_ gen: Int, _ launch: SSHLaunch) {
        guard wantsRun, gen == generation else { return }
        killProcess()
        current = launch
        buffer.removeAll()
        errorBuffer.removeAll()

        guard !launch.host.isEmpty, !launch.user.isEmpty else {
            publish(gen) { $0.setLink(gen: gen, trouble: "Set the head host", running: false) }
            schedule(gen)
            return
        }
        guard FileManager.default.isReadableFile(atPath: launch.identityPath) else {
            publish(gen) { $0.setLink(gen: gen, trouble: "Key file is missing", running: false) }
            schedule(gen)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = launch.arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        process.standardInput = FileHandle.nullDevice
        let outHandle = out.fileHandleForReading
        let errHandle = err.fileHandleForReading
        outHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            }
            self?.queue.async {
                self?.acceptStdout(data, gen: gen)
            }
        }
        errHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            }
            self?.queue.async {
                self?.acceptStderr(data, gen: gen)
            }
        }
        process.terminationHandler = { [weak self] proc in
            self?.queue.async {
                self?.handleExit(gen, status: proc.terminationStatus)
            }
        }
        do {
            try process.run()
        } catch {
            publish(gen) { $0.setLink(gen: gen, trouble: error.localizedDescription, running: false) }
            schedule(gen)
            return
        }
        self.process = process
        stdout = outHandle
        stderr = errHandle
        publish(gen) { store in
            if store.sample == nil {
                store.setLink(gen: gen, trouble: "Waiting for the writer", running: true)
            } else {
                store.setLink(gen: gen, trouble: nil, running: true)
            }
        }
    }

    private func acceptStdout(_ data: Data, gen: Int) {
        guard gen == generation, !data.isEmpty else { return }
        buffer.append(data)
        var lines: [String] = []
        while let range = buffer.firstRange(of: Data([0x0A])) {
            let chunk = buffer.subdata(in: 0..<range.lowerBound)
            buffer.removeSubrange(0..<range.upperBound)
            if let text = String(data: chunk, encoding: .utf8) {
                lines.append(text)
            } else {
                buffer.removeAll()
                break
            }
        }
        if buffer.count > 8192 {
            buffer.removeAll()
        }
        guard !lines.isEmpty else { return }
        publish(gen) { store in
            for line in lines {
                store.ingest(gen: gen, line: line)
            }
        }
    }

    private func acceptStderr(_ data: Data, gen: Int) {
        guard gen == generation, !data.isEmpty else { return }
        errorBuffer.append(data)
        if errorBuffer.count > 2048 {
            errorBuffer.removeFirst(errorBuffer.count - 2048)
        }
    }

    private func handleExit(_ gen: Int, status: Int32) {
        guard wantsRun, gen == generation else { return }
        releaseHandles()
        let message = sshTrouble(lastErrorLine() ?? "SSH exited (\(status))")
        publish(gen) { $0.setLink(gen: gen, trouble: message, running: false) }
        schedule(gen)
    }

    private func lastErrorLine() -> String? {
        guard let text = String(data: errorBuffer, encoding: .utf8) else { return nil }
        let lines = text.split(whereSeparator: \.isNewline).map {
            $0.trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }
        return lines.last
    }

    private func schedule(_ gen: Int) {
        let delay = backoff
        backoff = min(backoff * 2, maxBackoff)
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.wantsRun, self.generation == gen, let launch = self.current else { return }
            self.spawn(gen, launch)
        }
    }

    private func releaseHandles() {
        stdout?.readabilityHandler = nil
        stderr?.readabilityHandler = nil
        stdout = nil
        stderr = nil
        process = nil
    }

    private func killProcess() {
        let running = process
        if let running, running.isRunning {
            running.terminationHandler = nil
        }
        releaseHandles()
        if let running, running.isRunning {
            running.terminate()
        }
    }

    private func publish(_ gen: Int, _ apply: @escaping @MainActor (Store) -> Void) {
        guard gen == generation else { return }
        let store = self.store
        Task { @MainActor in
            guard let store else { return }
            apply(store)
        }
    }
}
