# Publishing NoLogo

NoLogo is the product name everywhere. “Logo illumination” describes the feature.
Keep the bundle identifier, helper service identifier, saved preferences, signing key,
and existing feed URL stable so installed apps keep working.

## One-time setup

1. Install GitHub CLI (`brew install gh`) and run `gh auth login` with access to jez020/nologo.
2. Push this release script and `.github/workflows/publish.yml` to the repository’s default branch.
3. In GitHub Settings → Pages, select **GitHub Actions**.
4. Build NoLogo in Xcode once to download Sparkle’s signing tools. The existing matching
   private key must be in your login Keychain. The script checks its public key without exporting secrets.

## Each release

1. Increase **Version** and **Build** in Xcode. Commit the release source and push its matching tag:
   `git tag v1.0.1 && git push origin v1.0.1`.
2. Archive that source in Xcode. Distribute with **Developer ID**, notarize, and export
   the stapled **NoLogo.app**.
3. Publish:

   ```sh
   python3 scripts/release.py "/path/to/NoLogo.app" --publish
   ```

For the very first release, if the feed still returns HTTP 404, also add
`--first-release`. Omit `--publish` to prepare and validate files locally.
Use `--notes release-notes.md` for custom GitHub release notes; otherwise GitHub generates them.

The command reads the version from the exported app, verifies signing and notarization,
checks the Sparkle Keychain key, preserves existing feed entries, packages the app,
and signs the update. It uploads the ZIP and appcast to a draft release, then publishes
it. The **Publish NoLogo updates** workflow deploys the release’s appcast to GitHub Pages.
There is no manual XML editing, asset uploading, or feed commit.

The command requires the matching source tag to exist on GitHub. It does not build,
notarize, commit source, or create tags. Existing releases are not overwritten.
Wait for feed deployment to finish before publishing another release.

## Verification and recovery

- Wait for **Publish NoLogo updates** to pass in GitHub Actions.
- Confirm https://jez020.github.io/NoLogo/appcast.xml serves the new version.
- Check for Updates from an older installed, signed NoLogo build and verify installation
  and relaunch. A successful build alone does not validate the update.
- If asset upload fails, inspect the draft release and the local output directory printed
  by the script. Complete the draft’s ZIP and appcast uploads before publishing it.
- If feed deployment fails after publication, rerun the workflow or use **Run workflow**
  with the latest published tag. It rejects older tags to avoid rolling back the feed.
- GitHub Pages must serve the exact configured URL, including path capitalization.
  If your repository’s Pages URL differs, resolve that before distributing the app.
- Use `--sparkle-bin /path/to/Sparkle/bin` if automatic discovery fails, or
  `--account NAME` for a custom Sparkle Keychain account.
- The script requires Python 3 and macOS’s command-line developer tools.

Sparkle updates the main app, not the installed privileged helper. Releases that change
the helper protocol still require removing and reinstalling the helper in Settings.

## Configuration

Sparkle is linked through Swift Package Manager. The target merges NoLogo/Info.plist
with generated bundle metadata and enables Hardened Runtime. Never replace the
existing SUPublicEDKey casually or commit its matching private key.

The checked-in docs/appcast.xml is only the empty first-release seed; the live feed is
deployed from release assets.

References: [Sparkle publishing](https://sparkle-project.org/documentation/publishing/),
[GitHub release CLI](https://cli.github.com/manual/gh_release_create).
