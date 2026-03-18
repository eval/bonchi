require "thor"

module Bonchi
  class CLI < Thor
    include Colors

    def self.exit_on_failure?
      true
    end

    desc "version", "Print version"
    def version
      puts "bonchi #{VERSION}"
    end
    map "--version" => :version
    map "-v" => :version

    desc "create BRANCH [BASE]", "Create new branch + worktree"
    long_desc <<~DESC
      Create a new branch and worktree. BASE defaults to the repository's default branch
      (e.g. main). If a worktree for BRANCH already exists, switches to it instead.

      When a .worktree.yml exists in the main worktree, setup runs automatically
      (copy files, allocate ports, run pre_setup and setup commands).
      Skip with --no-setup, or use --upto STEP to run only up to a specific step.
    DESC
    option :setup, type: :boolean, default: true, desc: "Run setup after creating worktree"
    option :upto, type: :string, desc: "Run setup steps up to and including STEP (copy, link, ports, replace, pre_setup, setup)"
    def create(branch, base = nil)
      base ||= Git.default_base_branch
      path = Git.worktree_dir(branch)

      existing = Git.worktree_path_for(branch)
      if existing
        puts "Worktree already exists: #{existing}"
        signal_cd(existing)
        return
      end

      Git.worktree_add_new_branch(path, branch, base)
      puts "Worktree created at: #{path}"

      signal_cd(path)

      if options[:setup] && Config.from_main_worktree
        puts ""
        Setup.new(worktree: path).run(upto: options[:upto])
      end
    end

    desc "switch BRANCH", "Switch to existing branch in worktree"
    long_desc <<~DESC
      Create a worktree for an existing branch and cd into it.
      If a worktree for BRANCH already exists, switches to it instead.

      The branch must already exist locally or on the remote.
      To create a new branch, use `bonchi create` instead.
    DESC
    def switch(branch)
      existing = Git.worktree_path_for(branch)
      if existing
        puts "Worktree already exists: #{existing}"
        signal_cd(existing)
        return
      end

      unless Git.branch_exists?(branch)
        abort "Error: Branch '#{branch}' does not exist\nUse 'bonchi create #{branch}' to create a new branch"
      end

      path = Git.worktree_dir(branch)
      Git.worktree_add(path, branch)
      puts "Worktree created at: #{path}"

      signal_cd(path)
    end

    desc "pr NUMBER_OR_URL", "Checkout GitHub PR in worktree"
    long_desc <<~DESC
      Fetch a GitHub pull request and check it out in a new worktree.
      Accepts a PR number (e.g. 123) or a full GitHub PR URL.

      The worktree branch will be named pr-<number>.
      If the worktree already exists, switches to it instead.
    DESC
    def pr(input)
      pr_number = extract_pr_number(input)
      branch = "pr-#{pr_number}"
      path = Git.worktree_dir(branch)

      existing = Git.worktree_path_for(branch)
      if existing
        puts "Worktree already exists: #{existing}"
        signal_cd(existing)
        return
      end

      Git.fetch_pr(pr_number)
      Git.worktree_add(path, branch)
      puts "PR ##{pr_number} checked out at: #{path}"

      signal_cd(path)
    end

    desc "init", "Generate a .worktree.yml in the current project"
    long_desc <<~DESC
      Generate a .worktree.yml config file in the current directory with
      sensible defaults. Edit the file to customize which files to copy,
      which ports to allocate, and what setup command to run.
    DESC
    def init
      path = File.join(Dir.pwd, ".worktree.yml")
      if File.exist?(path)
        abort "Error: .worktree.yml already exists"
      end

      File.write(path, WORKTREE_YML_TEMPLATE)
      puts "Created #{path}"
    end

    desc "setup [-- ARGS...]", "Run setup in current worktree (ports, copy, pre_setup, setup cmd)"
    option :upto, type: :string, desc: "Run steps up to and including STEP (copy, link, ports, replace, pre_setup, setup)"
    def setup(*args)
      Setup.new.run(args, upto: options[:upto])
    end

    desc "list", "List all worktrees"
    def list
      lines = Git.worktree_list
      base = Git.default_base_branch
      home = Dir.home

      lines.each do |line|
        branch = line[/\[([^\]]+)\]/, 1]
        path = line.split(/\s+/).first
        line = line.sub(home, "~")

        unless branch
          puts line
          next
        end

        if branch == base
          puts line
          next
        end

        merged = Git.merged?(branch, into: base)
        clean = Git.clean?(path)
        tags = []
        tags << "#{color(:yellow)}dirty#{reset}" unless clean
        tags << "#{color(:green)}merged#{reset}" if merged

        if tags.any?
          puts "#{line}  #{tags.join(" ")}"
        else
          puts line
        end
      end
    end

    desc "remove BRANCH", "Remove a worktree"
    long_desc <<~DESC
      Remove a worktree and its directory. Refuses to remove worktrees
      with uncommitted changes or untracked files unless --force is used.

      Aliases: rm
    DESC
    option :force, type: :boolean, default: false, desc: "Force removal even with uncommitted changes"
    def remove(branch)
      path = Git.worktree_path_for(branch)
      abort "Error: No worktree found for branch: #{branch}" unless path

      Git.worktree_remove(path, force: options[:force])
      puts "Removed worktree: #{path}"
      signal_cd(Git.main_worktree)
    end

    desc "prune", "Prune stale worktree admin files"
    long_desc <<~DESC
      Clean up stale worktree tracking data. Git internally tracks worktrees in
      .git/worktrees/. When a worktree directory is deleted manually (e.g. rm -rf)
      instead of via `bonchi remove`, the tracking data becomes stale.

      This runs `git worktree prune` to remove those orphaned entries.
    DESC
    def prune
      Git.worktree_prune
      puts "Pruned stale worktree administrative files"
    end

    desc "shellenv", "Output shell function for auto-cd + completions"
    def shellenv
      puts SHELL_ENV
    end

    map "sw" => :switch
    map "ls" => :list
    map "rm" => :remove

    private

    def signal_cd(path)
      cd_file = ENV["BONCHI_CD_FILE"]
      if cd_file
        File.write(cd_file, path)
      else
        puts "cd #{path}"
      end
    end

    def extract_pr_number(input)
      case input
      when %r{^https://github.com/.*/pull/(\d+)}
        $1
      when /^\d+$/
        input
      else
        abort "Error: Invalid PR number or URL: #{input}"
      end
    end

    WORKTREE_YML_TEMPLATE = <<~YAML
      # Worktree configuration for bonchi.
      # See https://github.com/eval/bonchi

      # Minimum bonchi version required.
      # min_version: #{VERSION}

      # Files to copy from the main worktree before setup.
      # copy:
      #   - .env.local

      # Files to symlink from the main worktree (useful for large directories).
      # link:
      #   - node_modules

      # Env var names to allocate unique ports for (from global pool).
      # ports:
      #   - PORT

      # Regex replacements in copied files. Env vars ($VAR) are expanded.
      # Short form:
      # replace:
      #   .env.local:
      #     - "^PORT=.*": "PORT=$PORT"
      # Full form (with optional missing: warn, default: halt):
      # replace:
      #   .env.local:
      #     - match: "^PORT=.*"
      #       with: "PORT=$PORT"
      #       missing: warn

      # Commands to run before the setup command (port env vars are available).
      # pre_setup:
      #   - echo "preparing..."

      # The setup command to run (default: bin/setup).
      setup: bin/setup
    YAML

    SHELL_ENV = <<~'SHELL'
      bonchi() {
          local bonchi_cd_file="${TMPDIR:-/tmp}/bonchi_cd.$$"
          BONCHI_CD_FILE="$bonchi_cd_file" command bonchi "$@"
          local exit_code=$?
          if [ $exit_code -eq 0 ] && [ -f "$bonchi_cd_file" ]; then
              cd "$(cat "$bonchi_cd_file")"
              rm -f "$bonchi_cd_file"
          fi
          return $exit_code
      }

      # Bash completion
      if [ -n "$BASH_VERSION" ]; then
          _bonchi_complete() {
              local cur prev commands
              COMPREPLY=()
              cur="${COMP_WORDS[COMP_CWORD]}"
              prev="${COMP_WORDS[COMP_CWORD-1]}"
              commands="create switch sw pr setup list ls remove rm prune shellenv help"

              if [ $COMP_CWORD -eq 1 ]; then
                  COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
                  return 0
              fi

              case "$prev" in
                  switch|sw|remove|rm)
                      local branches
                      branches=$(git worktree list 2>/dev/null | sed -n 's/.*\[\([^]]*\)\].*/\1/p' | tail -n +2)
                      COMPREPLY=( $(compgen -W "$branches" -- "$cur") )
                      return 0
                      ;;
              esac
          }
          complete -F _bonchi_complete bonchi
      fi

      # Zsh completion
      if [ -n "$ZSH_VERSION" ]; then
          _bonchi_complete_zsh() {
              local -a commands branches
              commands=(
                  'create:Create new branch + worktree'
                  'switch:Switch to existing branch in worktree'
                  'sw:Switch to existing branch in worktree'
                  'pr:Checkout GitHub PR in worktree'
                  'setup:Run setup in current worktree'
                  'list:List all worktrees'
                  'ls:List all worktrees'
                  'remove:Remove a worktree'
                  'rm:Remove a worktree'
                  'prune:Prune stale worktree admin files'
                  'shellenv:Output shell function for auto-cd'
              )

              if (( CURRENT == 2 )); then
                  _describe 'command' commands
              elif (( CURRENT == 3 )); then
                  case "$words[2]" in
                      switch|sw|remove|rm)
                          branches=(${(f)"$(git worktree list 2>/dev/null | sed -n 's/.*\[\([^]]*\)\].*/\1/p' | tail -n +1)"})
                          _describe 'branch' branches
                          ;;
                  esac
              fi
          }
          compdef _bonchi_complete_zsh bonchi
      fi
    SHELL
  end
end
