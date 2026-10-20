import SwiftUI

/// The popover shown under the status item: target picker, simulator list, drop zone, last result.
struct DropPanel: View {
    @Environment(HubDropModel.self) private var model
    @State private var isTargeted = false

    private let rowHeight: CGFloat = 26
    private let maxListHeight: CGFloat = 200

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("HubDrop")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await model.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh simulators")
            }

            Picker("Send to", selection: $model.target) {
                ForEach(HubDropModel.Target.allCases) { target in
                    Text(target.title).tag(target)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            simulatorList

            dropZone

            if let outcome = model.outcome {
                OutcomeRow(outcome: outcome)
            }

            Divider()

            HStack {
                Toggle("Launch at Login", isOn: $model.launchesAtLogin)
                    .toggleStyle(.checkbox)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 320)
        .task { await model.refresh() }
    }

    @ViewBuilder
    private var simulatorList: some View {
        if model.simulators.isEmpty {
            Text("No iOS or visionOS simulators found.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 48)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(model.simulators) { simulator in
                        SimulatorRow(
                            simulator: simulator,
                            showsCheckbox: model.target == .selected,
                            isSelected: isSelected(simulator)
                        )
                        .frame(height: rowHeight)
                    }
                }
            }
            .frame(height: min(CGFloat(model.simulators.count) * rowHeight, maxListHeight))
        }
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.6))
            .background(
                isTargeted ? Color.accentColor.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .frame(height: 84)
            .overlay {
                VStack(spacing: 6) {
                    if model.isBusy {
                        ProgressView()
                            .controlSize(.small)
                        Text("Adding…")
                    } else {
                        Image(systemName: "photo.badge.plus")
                            .font(.title2)
                        Text("Drop photos, videos, or contacts")
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .dropDestination(for: URL.self) { urls, _ in
                Task { await model.add(urls) }
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
            }
    }

    private func isSelected(_ simulator: Simulator) -> Binding<Bool> {
        Binding {
            model.selectedUDIDs.contains(simulator.udid)
        } set: { selected in
            if selected {
                model.selectedUDIDs.insert(simulator.udid)
            } else {
                model.selectedUDIDs.remove(simulator.udid)
            }
        }
    }
}

private struct SimulatorRow: View {
    let simulator: Simulator
    let showsCheckbox: Bool
    @Binding var isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            if showsCheckbox {
                Toggle(simulator.name, isOn: $isSelected)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
            Circle()
                .fill(simulator.isBooted ? Color.green : Color.secondary.opacity(0.35))
                .frame(width: 8, height: 8)
                .accessibilityLabel(simulator.isBooted ? "Booted" : "Shut down")
            Text(simulator.name)
                .lineLimit(1)
            Spacer()
            Text(simulator.runtime)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if showsCheckbox {
                isSelected.toggle()
            }
        }
    }
}

private struct OutcomeRow: View {
    let outcome: HubDropModel.Outcome

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            switch outcome {
            case .success(let fileCount, let simulatorNames):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Added ^[\(fileCount) file](inflect: true) to \(simulatorNames.formatted(.list(type: .and))).")
            case .failure(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .lineLimit(3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    DropPanel()
        .environment(HubDropModel())
}
