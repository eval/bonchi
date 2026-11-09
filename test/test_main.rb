require "minitest/autorun"
require "minitest/mock"
require "tmpdir"
require "fileutils"
require "stringio"
require "bonchi"

class TestMain < Minitest::Test
  def setup
    @tmpdir = File.realpath(Dir.mktmpdir)
    @main = File.join(@tmpdir, "repo")
    @linked = File.join(@tmpdir, "linked")
    @orig_pwd = Dir.pwd

    git "init", "-q", "-b", "main", @main
    git "-C", @main, "commit", "-q", "--allow-empty", "-m", "init"
    git "-C", @main, "worktree", "add", "-q", @linked, "-b", "feature"
    FileUtils.mkdir_p(File.join(@linked, "server"))
    FileUtils.mkdir_p(File.join(@main, "lib"))
  end

  def teardown
    Dir.chdir(@orig_pwd)
    FileUtils.remove_entry(@tmpdir)
  end

  def git(*args)
    system("git", "-c", "user.name=t", "-c", "user.email=t@t", *args, exception: true)
  end

  def capture
    out = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = out
  end

  def test_main_prints_main_worktree_from_linked_subdir
    Dir.chdir(File.join(@linked, "server"))
    assert_equal "#{@main}\n", capture { Bonchi::CLI.new.main }
  end

  def test_main_prints_main_worktree_from_main_subdir
    Dir.chdir(File.join(@main, "lib"))
    assert_equal "#{@main}\n", capture { Bonchi::CLI.new.main }
  end

  def test_main_aborts_outside_git_repo
    Bonchi::Git.stub(:toplevel, nil) do
      assert_raises(SystemExit) { capture { Bonchi::CLI.new.main } }
    end
  end

  # ~[main] is a zsh dynamic named directory defined by `bonchi shellenv`.
  def test_zsh_named_dir_main_resolves_from_any_worktree
    skip "zsh not available" unless system("which zsh > /dev/null 2>&1")

    shellenv = capture { Bonchi::CLI.new.shellenv }
    # compdef only exists once compinit ran; stub it for this non-interactive shell.
    # A failed ~[name] expansion is a fatal shell error, hence the subshell.
    script = <<~ZSH
      compdef() { :; }
      #{shellenv}
      cd #{File.join(@linked, "server")} && print -r -- ~[main]
      cd #{File.join(@main, "lib")} && print -r -- ~[main]
      cd #{@tmpdir} && { (print -r -- ~[main]) 2>/dev/null || print -r -- UNRESOLVED }
    ZSH

    out = IO.popen(["zsh", "-f", "-c", script], &:read)
    assert_equal [@main, @main, "UNRESOLVED"], out.lines.map(&:chomp)
  end
end
