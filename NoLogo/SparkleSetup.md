# Publishing NoLogo

NoLogo is the product name everywhere. “Logo illumination” describes the feature.
Keep the bundle identifier, helper service identifier, saved preferences, signing key,
and existing feed URL stable so installed apps keep working.

## One-time setup

1. Install GitHub CLI (`brew install gh`) and run `gh auth login` with access to jez020/nologo.
2. Merge this release script and `.github/workflows/publish.yml` into the protected `main` branch.
3. In GitHub Settings → Pages, select **GitHub Actions**.
4. Build NoLogo in Xcode once to download Sparkle’s signing tools. The existing matching
   private key must be in your login Keychain. The script checks its public key without exporting secrets.

## Each release

1. In Xcode, create a branch named for the version, such as `release-v1.0.1`.
2. Increase **Version** and **Build**, update `release-notes.md`, commit the release source,
   and push the `release-v1.0.1` branch from Xcode.
3. Open a pull request from `release-v1.0.1` into the protected `main` branch. Complete review
   and merge it. Do not generate a stable update from the release branch.
4. In Xcode, switch to `main` and pull so local `main` exactly matches `origin/main`.
5. Archive the merged source in Xcode. Distribute with **Developer ID**, notarize, and export
   the stapled **NoLogo.app**.
6. Publish from the clean local `main` checkout:

   ```sh
   python3 scripts/release.py "/path/to/NoLogo.app" --publish
   ```

For the very first release, if the feed still returns HTTP 404, also add
`--first-release`. Omit `--publish` to prepare and validate files locally.
Use `--notes release-notes.md` for a Markdown changelog shared by Sparkle and GitHub Releases;
otherwise the script retrieves GitHub-generated notes and uses those in both places.
Empty changelogs stop publication. Sparkle embeds the notes in the appcast, so no separate
release-note hosting is needed. The update dialog also links to the GitHub release history.

```sh
./scripts/release.sh "/path/to/NoLogo.app" --notes release-notes.md
```

Review and update release-notes.md before each release. This affects newly generated feeds;
already-published releases are not changed automatically.

The command reads the version from the exported app, verifies signing and notarization,
checks the Sparkle Keychain key, preserves existing feed entries, packages the app,
and signs the update. It uploads the ZIP and appcast to a draft release, then publishes
it. The **Publish NoLogo updates** workflow deploys the release’s appcast to GitHub Pages.
There is no manual XML editing, asset uploading, or feed commit.

The script fetches `origin/main` and stops unless the current branch is a clean `main`
checkout at that exact commit. It creates the version tag from the merged `main` commit,
or verifies that an existing tag already points there. This prevents a stable update from
being published before its release pull request is merged. The command does not build,
notarize, commit, push branches, or merge pull requests. Existing releases are not overwritten.
Wait for feed deployment to finish before publishing another release.

## Verification and recovery

- Wait for **Publish NoLogo updates** to pass in GitHub Actions.
- Confirm https://jez020.github.io/nologo/appcast.xml serves the new version.
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
