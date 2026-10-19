require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "bonchi"

class TestList < Minitest::Test
  def setup
    @tmpdir = File.realpath(Dir.mktmpdir)
    @main = File.join(@tmpdir, "repo")
    @orig_pwd = Dir.pwd

    git "init", "-q", "-b", "main", @main
    git "-C", @main, "commit", "-q", "--allow-empty", "-m", "init"
    Dir.chdir(@main)
  end

  def teardown
    Dir.chdir(@orig_pwd)
    FileUtils.remove_entry(@tmpdir)
  end

  def git(*args)
    system("git", "-c", "user.name=t", "-c", "user.email=t@t", *args, exception: true)
  end

  def add_worktree(name, created_at)
    path = File.join(@tmpdir, name)
    git "worktree", "add", "-q", path, "-b", name
    FileUtils.touch(File.join(@main, ".git", "worktrees", name, "gitdir"), mtime: created_at)
    path
  end

  def test_worktree_list_is_in_creation_order
    now = Time.now
    zeta = add_worktree("zeta", now - 300)
    alpha = add_worktree("alpha", now - 200)
    mid = add_worktree("mid", now - 100)

    paths = Bonchi::Git.worktree_list.map { |line| line.split(/\s+/).first }

    assert_equal [@main, zeta, alpha, mid], paths
  end

  def test_worktree_list_without_linked_worktrees
    paths = Bonchi::Git.worktree_list.map { |line| line.split(/\s+/).first }

    assert_equal [@main], paths
  end
end
