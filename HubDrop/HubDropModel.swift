import Foundation
import Observation
import ServiceManagement
import UniformTypeIdentifiers
import os

/// Application state: the simulator list, which simulators receive drops, and the last result.
@Observable
final class HubDropModel {
    enum Target: String, CaseIterable, Identifiable {
        case allBooted
        case selected

        var id: Self { self }

        var title: LocalizedStringResource {
            switch self {
            case .allBooted: "All Booted"
            case .selected: "Selected"
            }
        }
    }

    enum Outcome: Equatable {
        case success(fileCount: Int, simulatorNames: [String])
        case failure(String)
    }

    private(set) var simulators: [Simulator] = []
    private(set) var isBusy = false
    private(set) var outcome: Outcome?

    var target: Target {
        didSet { UserDefaults.standard.set(target.rawValue, forKey: Keys.target) }
    }

    var selectedUDIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(selectedUDIDs), forKey: Keys.selectedUDIDs) }
    }

    var launchesAtLogin: Bool {
        didSet { applyLaunchAtLogin() }
    }

    /// Called after every drop so the status item can flash the result.
    @ObservationIgnored var feedback: ((Outcome) -> Void)?

    private enum Keys {
        static let target = "target"
        static let selectedUDIDs = "selectedUDIDs"
    }

    nonisolated private static let acceptedTypes: [UTType] = [.image, .movie, .vCard]
    private let logger = Logger(subsystem: "com.flixel.HubDrop", category: "model")

    init() {
        let defaults = UserDefaults.standard
        target = Target(rawValue: defaults.string(forKey: Keys.target) ?? "") ?? .allBooted
        selectedUDIDs = Set(defaults.stringArray(forKey: Keys.selectedUDIDs) ?? [])
        launchesAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// The simulators a drop would be sent to right now.
    var targetSimulators: [Simulator] {
        switch target {
        case .allBooted: simulators.filter(\.isBooted)
        case .selected: simulators.filter { selectedUDIDs.contains($0.udid) }
        }
    }

    func refresh() async {
        do {
            simulators = try await SimulatorService.listSimulators()
        } catch {
            logger.error("Failed to list simulators: \(error.localizedDescription, privacy: .public)")
            outcome = .failure(error.localizedDescription)
        }
    }

    /// Adds the dropped items to the target simulators, booting shut-down ones first.
    func add(_ urls: [URL]) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        let files = mediaFiles(in: urls)
        guard !files.isEmpty else {
            report(.failure("No photos, videos, or contacts in the dropped items."))
            return
        }

        await refresh()
        let targets = targetSimulators
        guard !targets.isEmpty else {
            report(.failure(target == .allBooted ? "No simulators are booted." : "No simulators are selected."))
            return
        }

        do {
            for simulator in targets {
                if !simulator.isBooted {
                    try await SimulatorService.boot(simulator)
                }
                try await SimulatorService.addMedia(files, to: simulator)
            }
            report(.success(fileCount: files.count, simulatorNames: targets.map(\.name)))
            await refresh()
        } catch {
            report(.failure(error.localizedDescription))
        }
    }

    private func report(_ result: Outcome) {
        outcome = result
        feedback?(result)
    }

    /// Filters the drop down to files `addmedia` accepts. A dropped folder is expanded
    /// one level so a directory of sample media can be seeded in one gesture.
    private func mediaFiles(in urls: [URL]) -> [URL] {
        var files: [URL] = []
        for url in urls {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            if values?.isDirectory == true {
                let contents = (try? FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.contentTypeKey],
                    options: [.skipsHiddenFiles]
                )) ?? []
                files += contents
                    .filter(Self.isMedia)
                    .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            } else if Self.isMedia(url) {
                files.append(url)
            }
        }
        return files
    }

    nonisolated private static func isMedia(_ url: URL) -> Bool {
        guard let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType else { return false }
        return acceptedTypes.contains { type.conforms(to: $0) }
    }

    private func applyLaunchAtLogin() {
        let service = SMAppService.mainApp
        let isEnabled = service.status == .enabled
        guard launchesAtLogin != isEnabled else { return }
        do {
            if launchesAtLogin {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            logger.error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
            launchesAtLogin = isEnabled
        }
    }
}
