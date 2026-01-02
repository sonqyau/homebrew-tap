class Pecker < Formula
  desc "Pecker: woshiccm/Pecker"
  homepage "https://github.com/woshiccm/Pecker"
  url "https://github.com/woshiccm/Pecker.git",
      :tag => "0.4.0"
  head "https://github.com/woshiccm/Pecker.git"

  depends_on :xcode => ["10.0", :build]

  def install
    system "make", "install", "PREFIX=#{prefix}"
  end
end
