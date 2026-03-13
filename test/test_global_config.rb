require "minitest/autorun"
require "tmpdir"
require "yaml"
require "bonchi"

class TestGlobalConfig < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @original_env = ENV.to_h.slice("WORKTREE_ROOT", "XDG_CONFIG_HOME")
    ENV.delete("WORKTREE_ROOT")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
    ENV.delete("WORKTREE_ROOT")
    ENV.delete("XDG_CONFIG_HOME")
    @original_env.each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
  end

  def test_default_worktree_root
    ENV.delete("XDG_CONFIG_HOME")
    config = Bonchi::GlobalConfig.new
    assert_equal File.join(Dir.home, "dev", "worktrees"), config.worktree_root
  end

  def test_worktree_root_from_config_file
    config_path = File.join(@tmpdir, "config.yml")
    File.write(config_path, YAML.dump("worktree_root" => "/custom/worktrees"))

    ENV["XDG_CONFIG_HOME"] = @tmpdir
    FileUtils.mkdir_p(File.join(@tmpdir, "bonchi"))
    FileUtils.cp(config_path, File.join(@tmpdir, "bonchi", "config.yml"))

    config = Bonchi::GlobalConfig.new
    assert_equal "/custom/worktrees", config.worktree_root
  end

  def test_env_var_takes_precedence_over_config_file
    config_path = File.join(@tmpdir, "bonchi", "config.yml")
    FileUtils.mkdir_p(File.dirname(config_path))
    File.write(config_path, YAML.dump("worktree_root" => "/from/config"))

    ENV["XDG_CONFIG_HOME"] = @tmpdir
    ENV["WORKTREE_ROOT"] = "/from/env"

    config = Bonchi::GlobalConfig.new
    assert_equal "/from/env", config.worktree_root
  end

  def test_config_path_uses_xdg_when_set
    ENV["XDG_CONFIG_HOME"] = @tmpdir
    path = Bonchi::GlobalConfig.config_path
    assert_equal File.join(@tmpdir, "bonchi", "config.yml"), path
  end

  def test_config_path_falls_back_to_home
    ENV.delete("XDG_CONFIG_HOME")
    path = Bonchi::GlobalConfig.config_path
    assert_equal File.expand_path("~/.bonchi.yml"), path
  end

  def test_missing_config_file_returns_defaults
    ENV["XDG_CONFIG_HOME"] = @tmpdir
    FileUtils.mkdir_p(File.join(@tmpdir, "bonchi"))
    # no config.yml written

    config = Bonchi::GlobalConfig.new
    assert_equal File.join(Dir.home, "dev", "worktrees"), config.worktree_root
  end
end
