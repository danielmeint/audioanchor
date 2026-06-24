# Starter Homebrew cask. Copy into your tap (e.g. danielmeint/homebrew-tap) and fill
# in the sha256 once you've published a notarized release zip.
cask "audioanchor" do
  version "0.1.0"
  sha256 :no_check # replace with the real sha256 of the release zip

  url "https://github.com/danielmeint/audioanchor/releases/download/v#{version}/AudioAnchor-#{version}.zip"
  name "AudioAnchor"
  desc "Menu bar app that keeps your preferred audio input/output device as default"
  homepage "https://github.com/danielmeint/audioanchor"

  depends_on macos: ">= :ventura"

  app "AudioAnchor.app"

  zap trash: [
    "~/Library/Preferences/com.danielmeint.audioanchor.plist",
  ]
end
