namespace :gem do
  task "write_version", [:version] do |_task, args|
    if args[:version]
      version = args[:version].split("=").last
      version_file = File.expand_path("../../lib/bonchi/version.rb", __FILE__)

      system(<<~CMD, exception: true)
        ruby -pi -e 'gsub(/VERSION = ".*"/, %{VERSION = "#{version}"})' #{version_file}
      CMD
      Bundler.ui.confirm "Version #{version} written to #{version_file}."
    else
      Bundler.ui.warn "No version provided, keeping version.rb as is."
    end
  end

  desc "Build and install as bonchi-dev with dev version (current version + SHA)"
  task "install_dev" do
    require "tmpdir"

    sha = `git rev-parse --short HEAD`.strip
    base_version = Bonchi::VERSION.sub(/\.dev$/, "")
    dev_version = "#{base_version}.dev.#{sha}"
    root = File.expand_path("../..", __FILE__)

    Dir.mktmpdir do |dir|
      # Create dev gemspec
      spec = File.read(File.join(root, "bonchi.gemspec"))
      spec.gsub!('spec.name = "bonchi"', 'spec.name = "bonchi-dev"')
      spec.gsub!("spec.version = Bonchi::VERSION", "spec.version = \"#{dev_version}\"")
      spec.gsub!('spec.executables = ["bonchi"]', 'spec.executables = ["bonchi-dev"]')
      File.write(File.join(dir, "bonchi-dev.gemspec"), spec)

      # Copy files into tmpdir and write dev version
      FileUtils.cp_r(File.join(root, "lib"), dir)
      version_file = File.join(dir, "lib", "bonchi", "version.rb")
      File.write(version_file, %(module Bonchi\n  VERSION = "#{dev_version}"\nend\n))
      FileUtils.cp(File.join(root, "LICENSE.txt"), dir)
      FileUtils.mkdir_p(File.join(dir, "exe"))
      FileUtils.cp(File.join(root, "exe", "bonchi"), File.join(dir, "exe", "bonchi-dev"))

      # Build and install
      gem_file = File.join(dir, "bonchi-dev-#{dev_version}.gem")
      Dir.chdir(dir) do
        system("gem", "build", "bonchi-dev.gemspec", "--output", gem_file, exception: true)
      end
      system("gem", "install", gem_file, exception: true)
    end

    puts "Installed bonchi-dev #{dev_version}"
  end
end
