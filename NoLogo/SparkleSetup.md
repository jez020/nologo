# Sparkle updates for NoLogo

Repository: https://github.com/jez020/NoLogo
Update feed: https://jez020.github.io/NoLogo/appcast.xml

## Configuration status

Sparkle 2.10.1 is resolved and its product is linked to NoLogo. The target uses NoLogo/Info.plist together with generated bundle metadata, so SUFeedURL and SUPublicEDKey are included in the built app. Hardened Runtime is enabled.

The configured public key was verified against Sparkle’s default Keychain account using generate_keys -p. Keep this key for subsequent releases.

The app builds successfully. The configured GitHub Pages feed currently returns HTTP 404; publish the feed using the workflow below before distributing the app. The checked-in feed is empty and advertises no updates. Installation and relaunch still need an end-to-end check using two signed releases.

## App configuration

The existing Info.plist contains SUFeedURL and SUPublicEDKey. Keep the current public key; future updates must be signed using its matching private key. Never commit the private key.

UpdateManager starts Sparkle in the GUI process and supplies Check for Updates in the application menu and Settings. It does not start in the privileged helper process. The Sparkle package product must be linked to the NoLogo target. If Xcode reports “No such module Sparkle”, add https://github.com/sparkle-project/Sparkle using File > Add Package Dependencies and select the Sparkle product for NoLogo.

Keep Hardened Runtime enabled and use Apple Development signing for local builds. For distribution, export with Developer ID, notarize, and staple. This app is not sandboxed; SUEnableInstallerLauncherService remains false.

## Check the signing key

Locate bin/generate_keys in Xcode's downloaded Sparkle package artifacts. Run:

```sh
/path/to/Sparkle/bin/generate_keys -p
```

Its public key must match SUPublicEDKey in NoLogo's Info settings. If you originally used a custom Keychain account, supply the same --account argument to Sparkle's tools. Do not generate a replacement key for an already distributed app without following Sparkle's key-rotation instructions. Back up the matching private key securely outside the repository.

## Publish the feed on GitHub

1. Commit and push docs/appcast.xml, docs/.nojekyll, and .github/workflows/publish-appcast.yml.
2. In jez020/NoLogo, open Settings > Pages and choose GitHub Actions as the source.
3. In Actions, run Publish Sparkle feed on main.
4. Open https://jez020.github.io/NoLogo/appcast.xml and confirm it returns XML.

An empty appcast advertises no updates. The feed must be reachable before shipping the app.

## Publish an update

1. Increase CFBundleVersion for every release and set the visible version.
2. Archive, export with Developer ID, notarize, and staple NoLogo.app.
3. Package it, preserving symlinks:

```sh
mkdir -p /path/to/updates
ditto -c -k --sequesterRsrc --keepParent /path/to/NoLogo.app /path/to/updates/NoLogo-1.0.1.zip
```

4. Generate the signed appcast with Sparkle's tool using the matching Keychain key:

```sh
/path/to/Sparkle/bin/generate_appcast --download-url-prefix https://github.com/jez020/NoLogo/releases/download/v1.0.1/ /path/to/updates
```

5. Create the GitHub Release tagged v1.0.1. Upload the exact archive and any delta or release-note files referenced by the generated feed. Do not modify archives after signing.
6. Copy the generated appcast.xml into docs/appcast.xml. Verify every referenced URL downloads successfully. Review download prefixes when retaining older releases.
7. Commit and push the feed, then run Publish Sparkle feed again.
8. Test Check for Updates from an older signed build and confirm installation and relaunch.

GitHub hosting and a successful build alone do not verify an end-to-end update.

## Privileged helper

Sparkle updates the main app, not the separate installed root helper. If a release changes the helper protocol, users must remove the helper in Settings and set it up again.

## References

- https://sparkle-project.org/documentation/
- https://sparkle-project.org/documentation/programmatic-setup/
- https://sparkle-project.org/documentation/publishing/
