require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "bonchi"

class TestSetupEdits < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @setup = Bonchi::Setup.allocate
    @setup.instance_variable_set(:@worktree, @tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def write(file, content)
    path = File.join(@tmpdir, file)
    File.write(path, content)
    path
  end

  def read(file)
    File.read(File.join(@tmpdir, file))
  end

  def apply(file, entries)
    @setup.send(:replace_in_files, {file => entries})
  end

  def silenced
    out = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = out
  end

  # ----- existing replace behavior -----

  def test_short_form_replace
    write("f", "PORT=1234\n")
    silenced { apply("f", [{"^PORT=.*" => "PORT=4000"}]) }
    assert_equal "PORT=4000\n", read("f")
  end

  def test_full_form_replace_with_env
    ENV["WORKTREE_BRANCH_SLUG"] = "feat_x"
    write("f", "DATABASE_URL=postgres:///old\n")
    silenced { apply("f", [{"match" => "^DATABASE_URL=.*", "with" => "DATABASE_URL=postgres:///app_$WORKTREE_BRANCH_SLUG"}]) }
    assert_equal "DATABASE_URL=postgres:///app_feat_x\n", read("f")
  ensure
    ENV.delete("WORKTREE_BRANCH_SLUG")
  end

  def test_replace_missing_warn
    write("f", "hello\n")
    silenced { apply("f", [{"match" => "^NOPE", "with" => "x", "missing" => "warn"}]) }
    assert_equal "hello\n", read("f")
  end

  def test_replace_missing_halts
    write("f", "hello\n")
    assert_raises(SystemExit) do
      silenced { apply("f", [{"match" => "^NOPE", "with" => "x"}]) }
    end
  end

  # ----- append -----

  def test_append_adds_line
    write("f", "FOO=bar\n")
    silenced { apply("f", [{"append" => "BAZ=qux"}]) }
    assert_equal "FOO=bar\nBAZ=qux\n", read("f")
  end

  def test_append_normalizes_missing_trailing_newline
    write("f", "FOO=bar")
    silenced { apply("f", [{"append" => "BAZ=qux"}]) }
    assert_equal "FOO=bar\nBAZ=qux\n", read("f")
  end

  def test_append_expands_env_vars
    ENV["WORKTREE_BRANCH"] = "feat/x"
    write("f", "")
    silenced { apply("f", [{"append" => "BRANCH=$WORKTREE_BRANCH"}]) }
    assert_equal "BRANCH=feat/x\n", read("f")
  ensure
    ENV.delete("WORKTREE_BRANCH")
  end

  def test_append_aborts_on_missing_env_var
    write("f", "")
    assert_raises(SystemExit) do
      silenced { apply("f", [{"append" => "X=$NOPE_NOT_SET_ANYWHERE"}]) }
    end
  end

  # ----- upsert -----

  def test_upsert_replaces_when_pattern_matches
    write("f", "FOO=old\nBAR=keep\n")
    silenced { apply("f", [{"upsert" => "^FOO=.*", "with" => "FOO=new"}]) }
    assert_equal "FOO=new\nBAR=keep\n", read("f")
  end

  def test_upsert_appends_when_pattern_missing
    write("f", "BAR=keep\n")
    silenced { apply("f", [{"upsert" => "^FOO=", "with" => "FOO=new"}]) }
    assert_equal "BAR=keep\nFOO=new\n", read("f")
  end

  def test_upsert_appended_value_normalizes_trailing_newline
    write("f", "BAR=keep")
    silenced { apply("f", [{"upsert" => "^FOO=", "with" => "FOO=new"}]) }
    assert_equal "BAR=keep\nFOO=new\n", read("f")
  end

  def test_upsert_without_with_aborts
    write("f", "x\n")
    assert_raises(SystemExit) do
      silenced { apply("f", [{"upsert" => "^FOO="}]) }
    end
  end

  # ----- mixed list -----

  def test_mixed_entries_run_in_order
    write("f", "PORT=1234\n")
    entries = [
      {"^PORT=.*" => "PORT=4000"},
      {"append" => "FOO=bar"},
      {"upsert" => "^FOO=.*", "with" => "FOO=baz"}
    ]
    silenced { apply("f", entries) }
    assert_equal "PORT=4000\nFOO=baz\n", read("f")
  end

  def test_missing_file_aborts
    assert_raises(SystemExit) do
      silenced { apply("nope", [{"append" => "x"}]) }
    end
  end
end

class TestSetupConfigSource < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @main = File.join(@tmpdir, "main")
    @linked = File.join(@tmpdir, "linked")
    FileUtils.mkdir_p(@main)
    FileUtils.mkdir_p(@linked)
    @setup = Bonchi::Setup.allocate
    @setup.instance_variable_set(:@worktree, @linked)
    @setup.instance_variable_set(:@main_worktree, @main)
    ENV["WORKTREE_ROOT"] = @tmpdir
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
    %w[WORKTREE_ROOT WORKTREE_BRANCH WORKTREE_BRANCH_SLUG WORKTREE_MAIN WORKTREE_LINKED].each { |k| ENV.delete(k) }
  end

  def write(dir, file, content)
    path = File.join(dir, file)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def silenced
    out = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = out
  end

  def run_setup(upto:)
    Bonchi::Git.stub(:main_worktree, @main) do
      Bonchi::Git.stub(:current_branch, "feat/x") do
        silenced { @setup.run([], upto: upto) }
      end
    end
  end

  def test_linked_copy_takes_precedence_over_main
    write(@main, "from-main.txt", "main\n")
    write(@main, "from-linked.txt", "linked\n")
    write(@main, ".worktree.yml", "copy:\n  - from-main.txt\n")
    write(@linked, ".worktree.yml", "copy:\n  - from-linked.txt\n")

    run_setup(upto: "copy")

    refute File.exist?(File.join(@linked, "from-main.txt")), "main's copy entry should be ignored when linked config exists"
    assert_equal "linked\n", File.read(File.join(@linked, "from-linked.txt"))
  end

  def test_linked_link_takes_precedence_over_main
    write(@main, "from-main", "m\n")
    write(@main, "from-linked", "l\n")
    write(@main, ".worktree.yml", "link:\n  - from-main\n")
    write(@linked, ".worktree.yml", "link:\n  - from-linked\n")

    run_setup(upto: "link")

    refute File.exist?(File.join(@linked, "from-main"))
    assert File.symlink?(File.join(@linked, "from-linked"))
    assert_equal File.join(@main, "from-linked"), File.readlink(File.join(@linked, "from-linked"))
  end

  def test_falls_back_to_main_when_linked_has_no_config
    write(@main, "tool.toml", "m\n")
    write(@main, ".worktree.yml", "copy:\n  - tool.toml\n")

    run_setup(upto: "copy")

    assert_equal "m\n", File.read(File.join(@linked, "tool.toml"))
  end

  def test_aborts_when_neither_worktree_has_config
    assert_raises(SystemExit) do
      run_setup(upto: "copy")
    end
  end
end
