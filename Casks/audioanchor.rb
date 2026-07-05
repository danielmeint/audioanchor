# Source of truth for the cask in danielmeint/homebrew-tap. The release workflow
# copies it there with version and sha256 rewritten to the published zip.
cask "audioanchor" do
  version "0.1.0"
  sha256 :no_check # rewritten by the release workflow

  url "https://github.com/danielmeint/audioanchor/releases/download/v#{version}/AudioAnchor-#{version}.zip"
  name "AudioAnchor"
  desc "Menu bar app that keeps your preferred audio input/output device as default"
  homepage "https://github.com/danielmeint/audioanchor"

  depends_on macos: :ventura

  app "AudioAnchor.app"

  zap trash: [
    "~/Library/Preferences/com.danielmeint.audioanchor.plist",
  ]
end
