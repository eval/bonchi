require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "stringio"
require "bonchi"

class TestPortPool < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @prev_xdg = ENV["XDG_CONFIG_HOME"]
    ENV["XDG_CONFIG_HOME"] = @tmpdir
  end

  def teardown
    if @prev_xdg
      ENV["XDG_CONFIG_HOME"] = @prev_xdg
    else
      ENV.delete("XDG_CONFIG_HOME")
    end
    FileUtils.remove_entry(@tmpdir)
  end

  def write_config(min:, max:)
    path = Bonchi::GlobalConfig.config_path
    File.write(path, YAML.dump("port_pool" => {"min" => min, "max" => max, "allocated" => {}}))
  end

  def silenced
    out = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = out
  end

  def test_skips_browser_unsafe_port_in_range
    write_config(min: 4045, max: 4046) # 4045 (lockd) is unsafe, 4046 is fine
    pool = Bonchi::PortPool.new
    result = pool.stub(:port_available?, true) do
      silenced { pool.allocate(@tmpdir, ["web"]) }
    end
    assert_equal 4046, result["web"]
  end

  def test_aborts_when_only_unsafe_ports_available
    write_config(min: 4045, max: 4045) # nothing but the unsafe port to hand out
    pool = Bonchi::PortPool.new
    assert_raises(SystemExit) do
      pool.stub(:port_available?, true) do
        silenced { pool.allocate(@tmpdir, ["web"]) }
      end
    end
  end

  def test_allocates_normally_when_range_is_safe
    write_config(min: 4100, max: 4101)
    pool = Bonchi::PortPool.new
    result = pool.stub(:port_available?, true) do
      silenced { pool.allocate(@tmpdir, ["web"]) }
    end
    assert_equal 4100, result["web"]
  end
end
