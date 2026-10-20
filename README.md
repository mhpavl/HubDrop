# HubDrop

A macOS menu bar app that adds photos, videos, Live Photos, and vCards to iOS and visionOS simulators. Drop files on the icon and they land in the simulator's Photos library or Contacts.

It fills the gap left by Device Hub in Xcode 27, which has no way to seed a simulator's media from the UI.

## Install

1. Download the latest `HubDrop-<version>.zip` from [Releases](../../releases).
2. Unzip it and move `HubDrop.app` to `/Applications`.
3. Open it. HubDrop appears in the menu bar with no Dock icon.

The app is signed with a Developer ID and notarized by Apple, so Gatekeeper opens it without warnings.

Requirements: an Apple silicon Mac running macOS 26 or later, and Xcode 27 or later with at least one simulator runtime installed. HubDrop uses the `xcrun` from your active Xcode, so `xcode-select -p` should point at it.

## Use

- Drop files on the HubDrop icon in the menu bar. They go to every booted simulator.
- Click the icon to open the panel. Switch **Send to** to **Selected** and tick specific simulators. Shut-down simulators are booted first.
- Drop a folder to add every media file at its top level, which makes re-seeding an erased simulator a single gesture.
- The icon flashes a checkmark on success. On failure it opens the panel with the error from `simctl`.
- Press Cmd-comma to open Settings, which has the Launch at Login toggle.

Physical devices are out of scope. `devicectl` has no equivalent of `addmedia`.

## How it works

HubDrop is a thin front end for `simctl`:

```
xcrun simctl list devices -j
xcrun simctl bootstatus <udid> -b
xcrun simctl addmedia <udid> <files…>
```

Because it spawns `xcrun`, the app is not sandboxed. It runs with the hardened runtime and asks for no other entitlements. `DESIGN.md` records the architecture and the decisions behind it.

## Build from source

Open `HubDrop.xcodeproj` in Xcode 27 or later and run the HubDrop scheme.

The project is set to the maintainer's development team. If you are not on that team, Xcode will ask you to pick your own in **Signing & Capabilities**. Any Apple Development signing works for local runs; nothing in the app depends on a provisioning profile.

For Launch at Login to survive rebuilds, copy the built app to `/Applications` and enable the toggle from that copy.

The app icon is an Icon Composer file, `HubDrop/AppIcon.icon`. Its layer images are drawn in code: edit `Scripts/make-icon.swift` and run `swift Scripts/make-icon.swift` to regenerate them, then open the icon file in Icon Composer to adjust the glass, blend, and translucency settings.

## Release

Maintainers cut a release with:

```
Scripts/release.sh
```

The script archives a Release build, exports it with Developer ID, submits it to Apple's notary service, staples the ticket, and writes `build/release/HubDrop-<version>.zip`. Run `Scripts/release.sh --help` for the one-time setup of notarization credentials. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` on the target before cutting a release.

## Contributing

Issues and pull requests are welcome. Read `DESIGN.md` first; it records what was ruled out and why. Keep changes focused, use SwiftUI except where only AppKit has the API, and use `os.Logger` rather than `print`.

## License

HubDrop is released under the [MIT License](LICENSE).
