# NoLogo

Control your MacBook’s logo illumination from a simple macOS app, the menu bar, or a keyboard shortcut.

[Download the latest release](https://github.com/jez020/nologo/releases/latest) · [Release history](https://github.com/jez020/nologo/releases) · [Report an issue](https://github.com/jez020/nologo/issues)

## Requirements

- **macOS 27.2 or later** for the current project configuration. Check the release notes for the requirements of the version you download.
- **A supported Mac with controllable logo illumination.** The current app accepts only the model identifiers listed below; other models show **Unsupported Mac**.
- **Administrator approval** to install or remove the logo-control helper.
- An internet connection to download the app and check for updates. NoLogo must remain running for its menu bar controls and global shortcut to work.

### Supported model identifiers

The app’s current compatibility list is:

| Model identifier | Accepted by NoLogo |
| --- | --- |
| `Mac17,10` | Yes |
| `Mac17,11` | Yes |
| `Mac17,12` | Yes |
| `Mac17,13` | Yes |

To check yours, open **System Information → Hardware → Model Identifier**, or run this read-only command in Terminal:

```sh
sysctl -n hw.model
```

This list reflects the app’s compatibility check, not a guarantee of support for other Macs with similar names. NoLogo cannot add illumination to hardware that does not have it.

## Install

1. Open the [latest release](https://github.com/jez020/nologo/releases/latest).
2. Under **Assets**, download **NoLogo-<version>.zip**. Choose the app archive, not GitHub’s source-code archives or `appcast.xml`.
3. Double-click the ZIP to extract **NoLogo.app**.
4. Drag **NoLogo.app** into **Applications**.
5. Open NoLogo from Applications. If macOS asks whether to open the downloaded app, confirm that you want to open it.

No Terminal commands or Xcode installation are needed to use a released app.

### First-time setup

1. In NoLogo, click **Set Up Logo Control**.
2. Approve the macOS administrator prompt to install the helper.
3. Wait for the app to show the current illumination setting.
4. Click **Turn Light Off** or **Turn Light On**.

The helper performs the privileged setting change so ordinary toggles do not require repeated administrator prompts. Canceling setup leaves logo control unavailable until you complete it.

## Use NoLogo

| What you want to do | How |
| --- | --- |
| Turn illumination on or off | Use **Turn Light On / Off** in the app or lightbulb popup. |
| Control it from another app | Press **⌘⇧L** (Command–Shift–L), the default global shortcut. |
| Access the menu bar controls | Click the **lightbulb** near the right side of the macOS menu bar. |
| Reopen the main window | Click the lightbulb, then **Open App**. |
| Open Settings | Click **Settings** in the app or lightbulb popup. |
| Quit | Use **NoLogo → Quit NoLogo**, or **Quit** in the lightbulb popup. |

Closing the main window keeps NoLogo running in the menu bar. The global shortcut requires completed helper setup and an available key combination.

### Customize Settings

- **Startup → Open at Login:** start NoLogo when you sign in. If approval is required, use **Open Login Items Settings…** and allow NoLogo in System Settings.
- **App appearance → Show in Dock:** hide or show the Dock icon. With it hidden, use the menu bar lightbulb to access the app.
- **Keyboard shortcut → Record Shortcut…:** choose a letter or number with Command, Option, or Control. Shift can be added. Press Escape to cancel, or use **Restore Default** to return to ⌘⇧L. Common app shortcuts and combinations already in use may be unavailable.
- **Info:** find the installed version and build number at the bottom of Settings.

## Updates and changelogs

With NoLogo active, choose **NoLogo → Check for Updates…** in the app menu at the top of the screen. If the Dock icon is hidden, first use **Open App** from the lightbulb popup to bring the app forward.

Updates are delivered through Sparkle. Newly published releases using the current release script include a changelog in the update window. You can also read the [release history](https://github.com/jez020/nologo/releases).

If an older version cannot check for updates, download the latest ZIP, quit NoLogo, and replace the app in Applications. Early builds used an incorrectly capitalized update-feed URL and require this manual update.

Some releases may require a helper update. If instructed by the release notes or the app, remove the old helper in Settings, then complete setup again.

## Troubleshooting

| Message or problem | What to try |
| --- | --- |
| **Unsupported Mac** | Compare your model identifier with the list above. Updating macOS alone does not make unsupported hardware compatible. |
| **Retry Connection** | Click it to reconnect. If the problem persists, use **Settings → Logo-control helper → Remove Helper…**, then run **Set Up Logo Control** again. |
| Setup was canceled | Click **Set Up Logo Control** again and approve the administrator prompt. |
| Shortcut does nothing | Confirm NoLogo is running and helper setup is complete. Record another combination if another app uses the shortcut. |
| Open at Login needs approval | Follow the button in Settings to macOS Login Items settings and allow NoLogo. |
| Error retrieving update information | Check your connection and try again. If it persists, install the latest release manually. |
| No Dock icon | Click the menu bar lightbulb, open Settings, and enable **Show in Dock**. |

For unresolved issues, [open a GitHub issue](https://github.com/jez020/nologo/issues) with your macOS version, model identifier, NoLogo version/build, and the exact error message. Do not include passwords or your Mac’s serial number.

## Uninstall

1. If you want illumination on after uninstalling, click **Turn Light On** first.
2. Turn off **Settings → Startup → Open at Login**.
3. Select **Settings → Logo-control helper → Remove Helper…** and approve removal.
4. Quit NoLogo.
5. Move **NoLogo.app** from Applications to the Trash.

Removing the helper leaves the current illumination setting unchanged. Remove it before deleting the app so you can use NoLogo’s built-in removal flow.

## Building and publishing

Developers can open `NoLogo.xcodeproj` in Xcode and let Swift Package Manager resolve Sparkle. Local builds need a compatible macOS SDK and signing configuration. Released downloads do not require any development tools.

See [the publishing guide](NoLogo/SparkleSetup.md) for Developer ID export, notarization, Sparkle signing, changelogs, and the release script.
