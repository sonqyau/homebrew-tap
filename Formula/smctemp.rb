class Smctemp < Formula
  desc "Smctemp: narugit/smctemp"
  homepage "https://github.com/narugit/smctemp"
  url "https://github.com/narugit/smctemp/archive/refs/tags/0.6.0.tar.gz"
  version "0.5"
  sha256 "834be81fab5d85e32bdc6eb13cd2664cb2f82b5b2e7cacd45401dcd5ccaa06f4"
  license "GPL-2.0-only"
  head "https://github.com/narugit/smctemp.git", branch: "main"

  depends_on :macos

  def install
    system "make"
    bin.install "smctemp"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/smctemp -v")
  end
end
