class Lazyshell < Formula
  desc "GPT powered utility for Zsh that helps you write and modify console commands"
  homepage "https://github.com/LaurentFough/lazyshell"
  url "https://github.com/LaurentFough/lazyshell.git"
  sha256 "a05fab60db8515ef12d9061574177e4af7ed9dd2dfe0db33d6f49ec334af2c25"
  version "0.0.3"
  license "MIT"

  uses_from_macos "zsh" => [:build, :test]

  def install
    system "make", "install", "PREFIX=#{prefix}"
  end

  def caveats
    <<~EOS
      To activate the Chat GPT integration, add the following at the end of your .zshrc:
        # Add the following lines to your .zshrc
        export OPENAI_API_KEY=<your_api_key>
        [ -f #{HOMEBREW_PREFIX}/share/lazyshell/lazyshell.zsh ] && source #{HOMEBREW_PREFIX}/share/lazyshell/lazyshell.zsh

    EOS
  end

  test do
    assert_match "#{version}\n",
      shell_output("zsh -c '. #{pkgshare}/lazyshell.zsh && echo $LAZYSHELL_VERSION'")
  end
end
