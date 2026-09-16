# Build and install a test release

The Inventas build supports **Apple Silicon Macs running macOS 14 or later**. Tart and a prepared base VM must be installed separately. Xcode is needed to build Tartelet, but it is not needed to run the app itself. Jobs that build Apple apps still need Xcode in the base VM.

## Install on the other Mac

1. Download the ZIP and `SHA256SUMS.txt` from the Inventas GitHub prerelease.
2. In the download directory, run `shasum -a 256 -c SHA256SUMS.txt` to check the ZIP.
3. Extract the ZIP and copy `Tartelet.app` into `/Applications`.
4. Open Tartelet. This first test build is **ad-hoc signed and not notarized**. If macOS blocks it, follow [Apple's instructions for opening an app from an unidentified developer](https://support.apple.com/en-us/102445): after the blocked launch, open **System Settings → Privacy & Security → Open Anyway**. Do this only for the expected Inventas test build. No global Gatekeeper setting change is needed.
5. Configure the base VM, its SSH credentials, and the GitHub accounts as described in [multiple-account setup](multiple-accounts.md).

The distribution bundle identifier is `com.inventas.Tartelet`. It has separate preferences from the upstream app and the local development build. Configure it on the new machine; the ZIP does not contain account credentials, private keys, caches, or VM images. Settings from those other bundle identifiers are not imported automatically.

To test the shared VM pool, queue matching jobs in two accounts. Check that no more than two VMs run, that each runner registers with the expected organization or personal repository, and that its VM clone and runner registration disappear after the job. Live VM jobs have not been validated by the automated tests.

## Build the ZIP

Install Xcode and XcodeGen, then run from a clean checkout:

```sh
./script/build_distribution.sh
```

Set `XCODEGEN` to an executable path if it is not on `PATH`. The script creates a Release archive, an app, a ZIP, a SHA-256 checksum, and `BUILD-INFO.txt` under a new `build/Distribution/` directory. `build/Distribution/latest-path.txt` identifies the last successful output. It does not stop the development app or start VMs.

The default output is an ad-hoc signed test build. Set `TARTELET_VERSION`, `TARTELET_BUILD_NUMBER`, `TARTELET_RELEASE_LABEL`, or `TARTELET_BUNDLE_ID` when a different version or app identifier is needed. The source commit is recorded in the app and build information. Builds from a modified checkout are marked `dirty`; publish builds from a clean commit.

## Developer ID signing and notarization

For normal distribution without a manual Gatekeeper exception, install a **Developer ID Application** certificate and its private key. An **Apple Distribution** certificate is a different certificate type and does not replace Developer ID signing for this workflow.

Store notarization credentials with `xcrun notarytool store-credentials`, then supply the profile name and signing identity:

```sh
TARTELET_SIGNING_IDENTITY='Developer ID Application: Your Company (TEAMID)' \
TARTELET_DEVELOPMENT_TEAM='TEAMID' \
TARTELET_NOTARY_PROFILE='your-notary-profile' \
./script/build_distribution.sh
```

The script enables the hardened runtime, submits a ZIP to Apple, requires an accepted result, staples the ticket, checks Gatekeeper acceptance, and creates the final ZIP. Omitting `TARTELET_NOTARY_PROFILE` produces a signed but unnotarized app. It does not read passwords from files or put credentials in the ZIP. See [Apple's notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).
