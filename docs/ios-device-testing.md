# Test on a Physical iPhone

This guide installs and runs IGN Itinéraires on a personal iPhone from a Mac.
The first pairing and installation use a USB cable. After that, Xcode and
Flutter can run the application over the local network.

The iOS target requires iOS 13 or later. A free Apple developer account is
enough for local testing; App Store distribution requires Apple Developer
Program membership.

## Prerequisites

- A Mac with a recent Xcode version and its command-line tools
- Flutter 3.44.1, or a compatible stable release
- An Apple Account added in **Xcode > Settings > Accounts**
- An unlocked iPhone and a compatible USB cable
- The Mac and iPhone on the same local network for wireless use

Check the toolchain and fetch the project dependencies from the repository
root:

```sh
flutter doctor -v
flutter pub get --enforce-lockfile
```

Resolve any iOS or Xcode error reported by `flutter doctor` before continuing.

## First Installation with a Cable

1. Connect the unlocked iPhone to the Mac, then accept **Trust This Computer**
   on the phone if prompted.
2. Open the iOS workspace from the repository root:

   ```sh
   open ios/Runner.xcworkspace
   ```

3. In Xcode, select the **Runner** project, then the **Runner** target and
   **Signing & Capabilities**.
4. Keep **Automatically manage signing** enabled and select your personal or
   organization development team.
5. If Xcode cannot register `fr.ign.itineraires`, set a unique local bundle
   identifier, such as `com.yourname.ignitineraires`.
6. Select the connected iPhone as the Runner destination at the top of Xcode,
   then press **Run**.
7. If requested, enable **Settings > Privacy & Security > Developer Mode** on
   the iPhone. The phone restarts and asks for confirmation.
8. If iOS asks whether to trust the developer, use
   **Settings > General > VPN & Device Management**, select the developer
   certificate, and trust it. This menu can appear only after the first
   installation attempt.

The first build can take several minutes while Xcode prepares the device and
copies its shared cache symbols. Later builds are normally faster.

> [!IMPORTANT]
> Team and bundle identifier changes are local signing settings. Do not commit
> them unless the project maintainers explicitly request it. Check with
> `git diff -- ios/Runner.xcodeproj/project.pbxproj` before committing.

## Enable Wireless Testing

Keep the iPhone connected by cable for this one-time setup:

1. In Xcode, open **Window > Devices and Simulators**.
2. Select the iPhone in the **Devices** tab.
3. Enable **Connect via network** and wait until pairing completes.
4. Disconnect the cable, keep the iPhone unlocked, and confirm that it remains
   available as a Runner destination in Xcode.

The Mac and iPhone must be able to reach each other on the local network. A VPN,
guest Wi-Fi client isolation, firewall, or managed network can prevent wireless
discovery.

You can now choose the iPhone in Xcode and press **Run**, or launch through
Flutter:

```sh
flutter devices
flutter run -d <DEVICE_ID>
```

Replace `<DEVICE_ID>` with the identifier displayed by `flutter devices`.
Flutter uses debug mode by default, which enables hot reload but is not
representative of application performance.

For route and guidance performance tests, use a physical device in profile
mode:

```sh
flutter run --profile -d <DEVICE_ID>
```

Use debug mode while developing and profile mode when investigating startup,
map, search, or guidance lag.

## Test the Application

On first launch:

1. Allow location access **While Using the App**.
2. Keep **Precise Location** enabled so route guidance can evaluate GPS quality.
3. Test an address search, route calculation, map pinch zoom, full-route view,
   and foreground guidance.
4. Test driving guidance only as a passenger, never while driving.

Application-owned map, search, and routing requests require access to
`data.geopf.fr`. A `Connection reset by peer` message for this host indicates a
network or remote-service interruption, not an iOS signing failure.

## Troubleshooting

### Signing requires a development team

Select a team under **Runner > Signing & Capabilities** and keep automatic
signing enabled. With a personal team, use a bundle identifier that is unique to
your Apple Account.

### `PLA Update available`

Sign in to the [Apple Developer account](https://developer.apple.com/account/)
and accept the latest agreement. For an organization team, its Account Holder
or an administrator might need to accept it. Return to Xcode and select
**Try Again**.

### No provisioning profile was found

Confirm that the Apple Account is present in Xcode, the correct team is
selected, the bundle identifier is unique, and automatic signing is enabled.
Keep the iPhone connected and unlocked, then retry the build.

### The iPhone disappears after unplugging it

Reconnect the cable and check **Connect via network** again. Verify that both
devices are on the same non-isolated network, temporarily disconnect any VPN,
and keep Xcode open while the phone reconnects.

### The app feels slow or freezes in debug mode

Debug builds run Dart in JIT mode and may stutter. Reproduce the issue with
`flutter run --profile -d <DEVICE_ID>` before treating it as a performance bug.
Keep the terminal open to retain Flutter logs.

## References

- [Flutter: Set up iOS development](https://docs.flutter.dev/platform-integration/ios/setup)
- [Flutter build modes](https://docs.flutter.dev/testing/build-modes)
- [Apple: Enable Developer Mode on a device](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
- [Apple: Distribute an app to registered devices](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices)
