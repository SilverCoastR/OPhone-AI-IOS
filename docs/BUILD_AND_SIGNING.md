# Build and signing

## Unsigned CI artifact

`.github/workflows/ios.yml` runs on GitHub's macOS runner. It installs XcodeGen, generates the project, chooses an available iPhone simulator, runs unit tests, archives the `iphoneos` target with code signing disabled, and packages the application as `OPhone-AI-iOS-unsigned.ipa`.

Download it from the workflow run's **Artifacts** section. It is a compile artifact and cannot be installed as a normal iOS application.

## Installable signed IPA

Add these GitHub Actions secrets:

| Secret | Value |
| --- | --- |
| `IOS_CERTIFICATE_P12_BASE64` | Base64-encoded Apple distribution or development `.p12` |
| `IOS_CERTIFICATE_PASSWORD` | Password of the `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64-encoded profile for bundle ID `ai.ophone.ios` |
| `IOS_DEVELOPMENT_TEAM` | Apple Developer Team ID |
| `IOS_KEYCHAIN_PASSWORD` | Optional temporary CI keychain password |

Optionally set repository variable `IOS_EXPORT_METHOD` to `development`, `ad-hoc`, or the export method that matches the profile. Then run **Build signed iOS IPA** manually. Signing assets stay in encrypted GitHub secrets and are installed only in the temporary runner keychain.

For App Store distribution, use an App Store provisioning profile, review the privacy manifest and App Store metadata, and upload the exported archive through Apple's supported delivery tool.
