import Foundation

enum ADBError: LocalizedError {
    case adbNotFound(String)
    case commandFailed(exitCode: Int32, stderr: String)
    case transferFailed(exitCode: Int32, stderr: String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .adbNotFound(let path):
            return "ADB not found at: \(path)"
        case .commandFailed(let code, let stderr):
            return "ADB command failed (exit \(code)): \(stderr)"
        case .transferFailed(let code, let stderr):
            return "Transfer failed (exit \(code)): \(stderr)"
        case .parseError(let msg):
            return "Parse error: \(msg)"
        }
    }
}

actor ADBService {
    static let adbPathKey = "adbPath"

    var adbPath: String
    var adbFound: Bool

    init() {
        let (path, found) = ADBService.resolveADBPath()
        self.adbPath = path
        self.adbFound = found
    }

    func updateADBPath(_ path: String) {
        self.adbPath = path
        self.adbFound = FileManager.default.isExecutableFile(atPath: path)
        if adbFound {
            UserDefaults.standard.set(path, forKey: ADBService.adbPathKey)
        }
    }

    static func resolveADBPath() -> (path: String, found: Bool) {
        // 1. Check user-configured path from UserDefaults
        if let saved = UserDefaults.standard.string(forKey: adbPathKey),
           !saved.isEmpty,
           FileManager.default.isExecutableFile(atPath: saved) {
            return (saved, true)
        }

        // 2. Check well-known candidate locations
        let candidates = [
            NSHomeDirectory() + "/Library/Android/sdk/platform-tools/adb",
            "/opt/homebrew/bin/adb",
            "/usr/local/bin/adb",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return (path, true)
            }
        }

        // 3. Try `which adb`
        if let resolved = try? runSyncProcess("/usr/bin/which", arguments: ["adb"]).stdout.trimmingCharacters(in: .whitespacesAndNewlines),
           !resolved.isEmpty,
           FileManager.default.isExecutableFile(atPath: resolved) {
            return (resolved, true)
        }

        return ("adb", false)
    }

    private static func runSyncProcess(_ executable: String, arguments: [String]) throws -> (stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()
        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (stdout, stderr)
    }

    // MARK: - Command Execution

    private func runADB(arguments: [String]) async throws -> String {
        guard FileManager.default.isExecutableFile(atPath: adbPath) else {
            throw ADBError.adbNotFound(adbPath)
        }

        return try await withCheckedThrowingContinuation { continuation in
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: adbPath)
                process.arguments = arguments

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                try process.run()
                process.waitUntilExit()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                if process.terminationStatus != 0 {
                    continuation.resume(throwing: ADBError.commandFailed(exitCode: process.terminationStatus, stderr: stderr))
                } else {
                    continuation.resume(returning: stdout)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Device Management

    func listDevices() async throws -> [DeviceInfo] {
        let output = try await runADB(arguments: ["devices"])
        return parseDeviceList(output)
    }

    private func parseDeviceList(_ output: String) -> [DeviceInfo] {
        var devices: [DeviceInfo] = []
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("List of") || trimmed.hasPrefix("*") {
                continue
            }
            let parts = trimmed.components(separatedBy: "\t")
            if parts.count >= 2 {
                devices.append(DeviceInfo(serial: parts[0], state: parts[1]))
            }
        }
        return devices
    }

    // MARK: - Shell Commands

    func shellCommand(device: String, command: String) async throws -> String {
        try await runADB(arguments: ["-s", device, "shell", command])
    }

    func listDirectory(device: String, path: String) async throws -> [AndroidFile] {
        // Append trailing slash so `ls` follows symlinks and lists contents
        let listPath = path.hasSuffix("/") ? path : path + "/"
        let output = try await shellCommand(device: device, command: "ls -la \(shellEscape(listPath))")
        return Self.parseLsOutput(output, parentPath: path)
    }

    // MARK: - File Transfers

    private final class TransferState: @unchecked Sendable {
        private let lock = NSLock()
        private var _stderrOutput = ""
        private var _resumed = false

        var stderrOutput: String {
            lock.withLock { _stderrOutput }
        }

        func appendStderr(_ text: String) {
            lock.withLock { _stderrOutput += text }
        }

        /// Returns `true` if this is the first call (i.e., we should resume the continuation).
        func tryResume() -> Bool {
            lock.withLock {
                if _resumed { return false }
                _resumed = true
                return true
            }
        }
    }

    func pull(device: String, remotePath: String, localPath: String, onProgress: @escaping @Sendable (Double) -> Void) async throws {
        try await runTransfer(arguments: ["-s", device, "pull", remotePath, localPath], onProgress: onProgress)
    }

    func push(device: String, localPath: String, remotePath: String, onProgress: @escaping @Sendable (Double) -> Void) async throws {
        try await runTransfer(arguments: ["-s", device, "push", localPath, remotePath], onProgress: onProgress)
    }

    private func runTransfer(arguments: [String], onProgress: @escaping @Sendable (Double) -> Void) async throws {
        guard FileManager.default.isExecutableFile(atPath: adbPath) else {
            throw ADBError.adbNotFound(adbPath)
        }

        let adbPath = self.adbPath
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: adbPath)
            process.arguments = arguments

            let stderrPipe = Pipe()
            process.standardOutput = FileHandle.nullDevice
            process.standardError = stderrPipe

            let state = TransferState()

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                state.appendStderr(text)
                if let progress = Self.parseProgress(text) {
                    onProgress(progress)
                }
            }

            process.terminationHandler = { proc in
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                guard state.tryResume() else { return }
                if proc.terminationStatus == 0 {
                    onProgress(1.0)
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ADBError.transferFailed(exitCode: proc.terminationStatus, stderr: state.stderrOutput))
                }
            }

            do {
                try process.run()
            } catch {
                guard state.tryResume() else { return }
                continuation.resume(throwing: error)
            }
        }
    }

    func deleteFile(device: String, path: String) async throws {
        _ = try await shellCommand(device: device, command: "rm -rf \(shellEscape(path))")
    }

    func createDirectory(device: String, path: String) async throws {
        _ = try await shellCommand(device: device, command: "mkdir -p \(shellEscape(path))")
    }

    // MARK: - Parsing

    static func parseLsOutput(_ output: String, parentPath: String) -> [AndroidFile] {
        let lines = output.components(separatedBy: "\n")
        var files: [AndroidFile] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        // Pattern: permissions linkcount owner group size date time name [-> target]
        // Example: drwxrwx--x   5 root sdcard_rw  4096 2024-09-19 00:03 Android
        // Example: -rw-rw----   1 root sdcard_rw 12345 2024-09-19 00:03 file.txt
        // Example: lrwxrwxrwx   1 root root        10 2024-09-19 00:03 link -> target
        let regex = try! NSRegularExpression(
            pattern: #"^([dlrwxst\-]+)\s+\d+\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2})\s+(.+)$"#,
            options: []
        )

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("total ") { continue }

            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            guard let match = regex.firstMatch(in: trimmed, options: [], range: range) else { continue }

            let permissions = String(trimmed[Range(match.range(at: 1), in: trimmed)!])
            let owner = String(trimmed[Range(match.range(at: 2), in: trimmed)!])
            let group = String(trimmed[Range(match.range(at: 3), in: trimmed)!])
            let sizeStr = String(trimmed[Range(match.range(at: 4), in: trimmed)!])
            let dateStr = String(trimmed[Range(match.range(at: 5), in: trimmed)!])
            var nameField = String(trimmed[Range(match.range(at: 6), in: trimmed)!])

            // Skip . and ..
            if nameField == "." || nameField == ".." { continue }

            // Skip entries with ? permissions (inaccessible)
            if permissions.contains("?") { continue }

            let isDirectory = permissions.hasPrefix("d")
            let isSymlink = permissions.hasPrefix("l")
            var symlinkTarget: String? = nil

            if isSymlink, let arrowRange = nameField.range(of: " -> ") {
                symlinkTarget = String(nameField[arrowRange.upperBound...])
                nameField = String(nameField[..<arrowRange.lowerBound])
            }

            let size = Int64(sizeStr) ?? 0
            let date = dateFormatter.date(from: dateStr)

            let normalizedParent = parentPath.hasSuffix("/") ? String(parentPath.dropLast()) : parentPath
            let fullPath = "\(normalizedParent)/\(nameField)"

            files.append(AndroidFile(
                name: nameField,
                path: fullPath,
                isDirectory: isDirectory,
                isSymlink: isSymlink,
                symlinkTarget: symlinkTarget,
                permissions: permissions,
                owner: owner,
                group: group,
                size: size,
                modifiedDate: date
            ))
        }

        return files
    }

    static func parseProgress(_ text: String) -> Double? {
        // ADB progress format: "[ 45%]" or "45%"
        let pattern = #"(\d+)%"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
              let range = Range(match.range(at: 1), in: text),
              let value = Double(text[range]) else {
            return nil
        }
        return value / 100.0
    }

    private func shellEscape(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
