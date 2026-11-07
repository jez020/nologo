# NoLogo

NoLogo is a small macOS app for turning your MacBook Pro’s logo light on or off.

[Website](https://jez020.github.io/nologo/) · [Download NoLogo](https://github.com/jez020/nologo/releases/latest) · [View releases](https://github.com/jez020/nologo/releases) · [Report an issue](https://github.com/jez020/nologo/issues)

The website source lives in [`docs/`](docs/). GitHub Pages publishes it alongside the
Sparkle update feed whenever the latest release is published.

## Features

- Turn the logo light on or off from the app or menu bar
- Use a global keyboard shortcut from any app
- Create automations with Apple Shortcuts or Siri
- Open NoLogo automatically when you log in
- Hide the Dock icon for a menu-bar-only experience
- Check for updates inside the app

## Requirements

- macOS 27.0.1 or later for the current release
- A supported MacBook Pro with a PROLED XDR display (Any model with a light up apple logo)
- Administrator approval during first-time setup

Supported model identifiers: `Mac17,10`, `Mac17,11`, `Mac17,12`, and `Mac17,13`.

To find your model identifier, open **System Information → Hardware** and look for **Model Identifier**.

## Install

1. Download the app ZIP from the [latest release](https://github.com/jez020/nologo/releases/latest).
2. Open the ZIP and move **NoLogo.app** to **Applications**.
3. Open NoLogo.
4. Select **Set Up Logo Control** and approve the administrator prompt.

Setup installs a small helper so you will not need to enter your password every time you change the light.

## Use NoLogo

Select **Turn Light On** or **Turn Light Off** in the app. You can also click the lightbulb in the menu bar.

The default global shortcut is **Command–Shift–L**. Change it in **Settings → Keyboard shortcut**.

Closing the main window keeps NoLogo running in the menu bar. The menu bar gives you quick access to the light control, Settings, updates, and Quit.

### Apple Shortcuts and Siri

In the Shortcuts app, search for NoLogo and add either action:

- **Turn Logo Light On**
- **Turn Logo Light Off**

These actions can run in the background after NoLogo’s helper has been set up.

### Settings

- **Open at Login** starts NoLogo when you sign in.
- **Show in Dock** lets you use NoLogo as a regular app or only from the menu bar.
- **Record Shortcut** changes the global keyboard shortcut.
- **Remove Helper** removes the logo-control helper.

## Updates

Choose **Check for Updates…** from the NoLogo menu or the menu bar popup. Updates are delivered through Sparkle.

If an older version cannot check for updates, download the latest release and replace the existing app in Applications.

## Troubleshooting

- **Unsupported Mac:** Check that your model identifier is listed above.
- **Retry Connection:** Retry once. If it still fails, remove the helper in Settings and run setup again.
- **Shortcut does nothing:** Make sure NoLogo is running and helper setup is complete. Try a different shortcut if another app uses the same one.
- **No Dock icon:** Use the menu bar lightbulb to open Settings and enable **Show in Dock**.

Still stuck? [Open an issue](https://github.com/jez020/nologo/issues) with your macOS version, model identifier, NoLogo version, and the error message. Do not include passwords or your Mac’s serial number.

## Uninstall

1. Turn the light on first if you want it left on.
2. Disable **Open at Login** in Settings.
3. Select **Remove Helper** in Settings.
4. Quit NoLogo and move it to the Trash.

## Build from source

Open `NoLogo.xcodeproj` in Xcode and allow Swift Package Manager to resolve Sparkle. You will need a compatible macOS SDK and your own signing configuration.

See the [publishing guide](NoLogo/SparkleSetup.md) for release and notarization instructions.
