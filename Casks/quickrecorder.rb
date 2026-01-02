cask "quickrecorder" do
  homepage "https://github.com/lihaoyun6/QuickRecorder"
  url "https://github.com/lihaoyun6/QuickRecorder/releases/download/#{version}/QuickRecorder_v#{version}.dmg"
  version "1.6.7"
  sha256 "c2bd457ca9e5335852e5ac1f08d0c30f29a606167952e8d263be1c170c2f6da0"
  license "MIT"
  head "https://github.com/lihaoyun6/QuickRecorder.git", branch: "main"

  livecheck do
    url "https://github.com/lihaoyun6/QuickRecorder/releases/latest"
    strategy :page_match
    regex(%r{href=.*?/tag/v?(\d+(?:\.\d+)+)["' >]}i)
  end

  depends_on macos: ">= :monterey"

  app "QuickRecorder.app"

  zap trash: [
    "~/Library/HTTPStorages/com.lihaoyun6.QuickRecorder",
    "~/Library/Preferences/com.lihaoyun6.QuickRecorder.plist",
  ]
end
