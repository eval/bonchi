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
