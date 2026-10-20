import SwiftUI

@main
struct HubDropApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // HubDrop has no windows of its own. The status item and its popover
        // belong to AppDelegate; this scene only backs the ⌘, Settings command.
        Settings {
            SettingsView()
                .environment(appDelegate.model)
        }
    }
}

private struct SettingsView: View {
    @Environment(HubDropModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Toggle("Launch HubDrop at login", isOn: $model.launchesAtLogin)
            Text("Drop photos, videos, or vCards on the HubDrop menu bar icon, or open it and drop into the panel.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 360)
    }
}
