import Foundation
import os

/// A simulator that `simctl` knows about and that can receive media.
struct Simulator: Identifiable, Hashable, Sendable {
    let udid: String
    let name: String
    /// Human-readable runtime, for example "iOS 27.1".
    let runtime: String
    let state: String

    var id: String { udid }
    var isBooted: Bool { state == "Booted" }
}

/// A non-zero exit from `xcrun`, carrying whatever the tool printed.
struct CommandFailure: LocalizedError {
    let arguments: [String]
    let status: Int32
    let output: String

    var errorDescription: String? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "\(arguments.joined(separator: " ")) exited with status \(status)." : trimmed
    }
}

/// Thin wrapper around `xcrun simctl`. All work happens in child processes;
/// nothing here touches the main thread for longer than it takes to spawn one.
enum SimulatorService {
    nonisolated private static let logger = Logger(subsystem: "com.flixel.HubDrop", category: "simctl")

    /// Platforms whose simulators have a Photos library that `addmedia` can populate.
    private static let supportedPlatforms: Set<String> = ["iOS", "xrOS"]

    /// Lists available iOS and visionOS simulators, booted ones first.
    static func listSimulators() async throws -> [Simulator] {
        let json = try await run(["simctl", "list", "devices", "-j"])
        let list = try JSONDecoder().decode(DeviceList.self, from: Data(json.utf8))

        var simulators: [Simulator] = []
        for (runtimeIdentifier, devices) in list.devices {
            guard let platform = platform(from: runtimeIdentifier), supportedPlatforms.contains(platform) else { continue }
            let runtime = runtimeName(from: runtimeIdentifier)
            for device in devices where device.isAvailable {
                simulators.append(Simulator(udid: device.udid, name: device.name, runtime: runtime, state: device.state))
            }
        }
        return simulators.sorted { lhs, rhs in
            (lhs.isBooted ? 0 : 1, lhs.name, lhs.runtime) < (rhs.isBooted ? 0 : 1, rhs.name, rhs.runtime)
        }
    }

    /// Boots the simulator if necessary and waits until it is ready to accept commands.
    static func boot(_ simulator: Simulator) async throws {
        logger.info("Booting \(simulator.name, privacy: .public)")
        _ = try await run(["simctl", "bootstatus", simulator.udid, "-b"])
    }

    /// Adds photos, videos, Live Photo pairs, and vCards to the simulator's library.
    static func addMedia(_ files: [URL], to simulator: Simulator) async throws {
        logger.info("Adding \(files.count) file(s) to \(simulator.name, privacy: .public)")
        _ = try await run(["simctl", "addmedia", simulator.udid] + files.map { $0.path(percentEncoded: false) })
    }

    // MARK: - Runtime identifiers

    /// "com.apple.CoreSimulator.SimRuntime.iOS-27-1" → "iOS"
    private static func platform(from identifier: String) -> String? {
        identifier.split(separator: ".").last?.split(separator: "-").first.map(String.init)
    }

    /// "com.apple.CoreSimulator.SimRuntime.iOS-27-1" → "iOS 27.1"
    private static func runtimeName(from identifier: String) -> String {
        guard let raw = identifier.split(separator: ".").last else { return identifier }
        let parts = raw.split(separator: "-")
        guard let platform = parts.first else { return String(raw) }
        let displayPlatform = platform == "xrOS" ? "visionOS" : String(platform)
        return "\(displayPlatform) \(parts.dropFirst().joined(separator: "."))"
    }

    // MARK: - Process plumbing

    private struct DeviceList: Decodable {
        let devices: [String: [Device]]
    }

    private struct Device: Decodable {
        let udid: String
        let name: String
        let state: String
        let isAvailable: Bool
    }

    /// Runs `xcrun` with the given arguments and returns its standard output.
    nonisolated private static func run(_ arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/xcrun")
        process.arguments = arguments

        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError

        // Drain both pipes while the child runs. A large `list -j` payload would
        // otherwise fill the pipe buffer and the child would block before exiting.
        async let outputData = readToEnd(standardOutput.fileHandleForReading)
        async let errorData = readToEnd(standardError.fileHandleForReading)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { _ in continuation.resume() }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }

        let output = String(decoding: try await outputData, as: UTF8.self)
        let errorOutput = String(decoding: try await errorData, as: UTF8.self)

        guard process.terminationStatus == 0 else {
            logger.error("xcrun \(arguments.joined(separator: " "), privacy: .public) failed: \(errorOutput, privacy: .public)")
            throw CommandFailure(arguments: arguments, status: process.terminationStatus, output: errorOutput.isEmpty ? output : errorOutput)
        }
        return output
    }

    nonisolated private static func readToEnd(_ handle: FileHandle) async throws -> Data {
        try await Task.detached {
            try handle.readToEnd() ?? Data()
        }.value
    }
}
