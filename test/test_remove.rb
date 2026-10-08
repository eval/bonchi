require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "bonchi"

class TestRemove < Minitest::Test
  def setup
    @tmpdir = File.realpath(Dir.mktmpdir)
    @main = File.join(@tmpdir, "repo")
    @worktree = File.join(@tmpdir, "feature")
    @orig_pwd = Dir.pwd

    git "init", "-q", "-b", "main", @main
    git "-C", @main, "commit", "-q", "--allow-empty", "-m", "init"
    git "-C", @main, "worktree", "add", "-q", @worktree, "-b", "feature"

    @cd_file = File.join(@tmpdir, "cd")
    @orig_cd_file = ENV["BONCHI_CD_FILE"]
    ENV["BONCHI_CD_FILE"] = @cd_file
  end

  def teardown
    Dir.chdir(@orig_pwd)
    ENV["BONCHI_CD_FILE"] = @orig_cd_file
    FileUtils.remove_entry(@tmpdir)
  end

  def git(*args)
    system("git", "-c", "user.name=t", "-c", "user.email=t@t", *args, exception: true)
  end

  def test_remove_from_inside_worktree
    Dir.chdir(@worktree)

    capture_io { Bonchi::CLI.start(["remove", "feature"]) }

    refute Dir.exist?(@worktree)
    assert_equal @main, Dir.pwd
    assert_equal @main, File.read(@cd_file)
    refute_includes `git -C #{@main} branch --list feature`, "feature"
  end
end
