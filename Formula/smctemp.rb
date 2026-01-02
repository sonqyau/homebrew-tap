class Smctemp < Formula
    desc "Check Temperature by using Apple System Management Control (Smc) tool"
    homepage "https://github.com/narugit/smctemp"
    url "https://github.com/narugit/smctemp/archive/refs/tags/0.6.0.tar.gz"
    sha256 "834be81fab5d85e32bdc6eb13cd2664cb2f82b5b2e7cacd45401dcd5ccaa06f4"
    license "GPL-2.0-only"

    depends_on :macos
  
    def install
      system "make"
      bin.install "smctemp"
    end
  
    test do
      assert_match version.to_s, shell_output("#{bin}/smctemp -v")
    end
  end