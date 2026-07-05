# Releasing AudioAnchor

A GUI app shipped outside the App Store must be **Developer ID–signed and
notarized**, or Gatekeeper blocks it (and Homebrew quarantines casks). This is
automated by [`.github/workflows/release.yml`](.github/workflows/release.yml),
triggered by pushing a `v*` tag.

## One-time setup

### 1. Apple Developer account → Developer ID cert
- Join the Apple Developer Program ($99/yr).
- In Xcode (Settings → Accounts → Manage Certificates) or the Developer portal,
  create a **Developer ID Application** certificate.
- Export it from Keychain Access as a `.p12` (set a password).

### 2. App Store Connect API key (for notarytool)
- App Store Connect → Users and Access → Integrations → Keys → generate a key
  with the **Developer** role. Download the `.p8` (one-time download).
- Note the **Key ID** and the **Issuer ID**.

### 3. GitHub repo secrets
Add these under Settings → Secrets and variables → Actions:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_CERT_P12_BASE64` | `base64 -i cert.p12 \| pbcopy` |
| `DEVELOPER_ID_CERT_PASSWORD` | the `.p12` password |
| `KEYCHAIN_PASSWORD` | any random string (temp keychain) |
| `NOTARY_API_KEY_P8_BASE64` | `base64 -i AuthKey_XXXX.p8 \| pbcopy` |
| `NOTARY_API_KEY_ID` | the key's Key ID |
| `NOTARY_API_ISSUER_ID` | the Issuer ID |
| `TAP_DEPLOY_KEY` | ed25519 private key whose public half is a write-enabled deploy key on `danielmeint/homebrew-tap` (auto-bumps the cask) |

## Cutting a release

```sh
# bump VERSION in build.sh (and Casks/audioanchor.rb if not auto-bumping)
git tag v0.1.0
git push origin v0.1.0
```

The workflow then: builds a universal binary → signs → notarizes → staples →
attaches `AudioAnchor-<version>.zip` to a GitHub Release → (optionally) bumps the
cask in your tap.

## Homebrew tap

```sh
# one-time
gh repo create danielmeint/homebrew-tap --public

# users install with
brew tap danielmeint/tap
brew install --cask audioanchor
```

The cask in [`Casks/audioanchor.rb`](Casks/audioanchor.rb) is the source of truth;
the release workflow copies it into the tap with the version + sha256 filled in.

## Local notarized build (without CI)

```sh
SIGN_ID="Developer ID Application: Daniel Meint (TEAMID)" ./build.sh --universal
ditto -c -k --keepParent dist/AudioAnchor.app AudioAnchor-0.1.0.zip
xcrun notarytool submit AudioAnchor-0.1.0.zip \
  --key AuthKey_XXXX.p8 --key-id KEYID --issuer ISSUERID --wait
xcrun stapler staple dist/AudioAnchor.app
shasum -a 256 AudioAnchor-0.1.0.zip   # → cask sha256
```
