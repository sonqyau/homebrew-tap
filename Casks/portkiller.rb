cask "portkiller" do
  version "3.1.0"
  sha256 "9d6b52e19da6da818f39414b4e06125fe959d6cba53fa8ae3982eaa4de098f26"

  url "https://github.com/productdevbook/port-killer/releases/download/v#{version}/PortKiller-v#{version}-macos-arm64.dmg"
  name "PortKiller"
  desc "Menu bar app to find and kill processes running on open ports"
  homepage "https://github.com/productdevbook/port-killer"

  depends_on macos: ">= :sequoia"
  depends_on arch: :arm64

  app "PortKiller.app"

  zap trash: [
    "~/Library/Preferences/com.productdevbook.PortKiller.plist",
    "~/Library/Caches/com.productdevbook.PortKiller",
  ]
end
