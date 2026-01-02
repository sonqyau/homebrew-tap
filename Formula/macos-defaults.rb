class MacosDefaults < Formula
  desc "dsully/macos-defaults"
  homepage "https://github.com/dsully/macos-defaults"
  url "https://github.com/dsully/macos-defaults/releases/download/0.3.0/macos-defaults-aarch64-apple-darwin.tar.xz"
  sha256 "9ab07bc12726db44409120f60a06e765899a7345a7d6d7b51a73f6cd2f399086"
  license "MIT"
  head "https://github.com/dsully/macos-defaults.git", branch: "main"

  BINARY_ALIASES = {
    "aarch64-apple-darwin": {},
  }.freeze

  def target_triple
    cpu = Hardware::CPU.arm? ? "aarch64" : "x86_64"
    os = OS.mac? ? "apple-darwin" : "unknown-linux-gnu"

    "#{cpu}-#{os}"
  end

  def install_binary_aliases!
    BINARY_ALIASES[target_triple.to_sym].each do |source, dests|
      dests.each do |dest|
        bin.install_symlink bin / source.to_s => dest
      end
    end
  end

  def install
    bin.install "macos-defaults" if OS.mac? && Hardware::CPU.arm?

    install_binary_aliases!

    # Homebrew will automatically install these, so we don't need to do that
    doc_files = Dir["README.*", "readme.*", "LICENSE", "LICENSE.*", "CHANGELOG.*"]
    leftover_contents = Dir["*"] - doc_files

    # Install any leftover files in pkgshare; these are probably config or
    # sample files.
    pkgshare.install(*leftover_contents) unless leftover_contents.empty?
  end
end
