require "thor"

module Bonchi
  class CLI < Thor
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
    option :setup, type: :boolean, default: true, desc: "Run setup after creating worktree"
    def create(branch, base = nil)
      base ||= Git.default_base_branch
      path = Git.worktree_dir(branch)

      existing = Git.worktree_path_for(branch)
      if existing
        puts "Worktree already exists: #{existing}"
        puts "BONCHI_CD:#{existing}"
        return
      end

      Git.worktree_add_new_branch(path, branch, base)
      puts "Worktree created at: #{path}"

      if options[:setup] && Config.from_main_worktree
        puts ""
        Setup.new(worktree: path).run
      else
        puts "BONCHI_CD:#{path}"
      end
    end

    desc "switch BRANCH", "Switch to existing branch in worktree"
    def switch(branch)
      existing = Git.worktree_path_for(branch)
      if existing
        puts "Worktree already exists: #{existing}"
        puts "BONCHI_CD:#{existing}"
        return
      end

      unless Git.branch_exists?(branch)
        abort "Error: Branch '#{branch}' does not exist\nUse 'bonchi create #{branch}' to create a new branch"
      end

      path = Git.worktree_dir(branch)
      Git.worktree_add(path, branch)
      puts "Worktree created at: #{path}"

      puts "BONCHI_CD:#{path}"
    end

    desc "pr NUMBER_OR_URL", "Checkout GitHub PR in worktree"
    def pr(input)
      pr_number = extract_pr_number(input)
      branch = "pr-#{pr_number}"
      path = Git.worktree_dir(branch)

      existing = Git.worktree_path_for(branch)
      if existing
        puts "Worktree already exists: #{existing}"
        puts "BONCHI_CD:#{existing}"
        return
      end

      Git.fetch_pr(pr_number)
      Git.worktree_add(path, branch)
      puts "PR ##{pr_number} checked out at: #{path}"

      puts "BONCHI_CD:#{path}"
    end

    desc "setup", "Run setup in current worktree (ports, copy, pre_setup, setup cmd)"
    def setup
      Setup.new.run
    end

    desc "list", "List all worktrees"
    def list
      Git.worktree_list.each { |line| puts line }
    end

    desc "remove BRANCH", "Remove a worktree"
    def remove(branch)
      path = Git.worktree_path_for(branch)
      abort "Error: No worktree found for branch: #{branch}" unless path

      Git.worktree_remove(path)
      puts "Removed worktree: #{path}"
    end

    desc "prune", "Prune stale worktree admin files"
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

    SHELL_ENV = <<~'SHELL'
      bonchi() {
          local output
          output=$(command bonchi "$@")
          local exit_code=$?
          echo "$output"
          if [ $exit_code -eq 0 ]; then
              local cd_path=$(echo "$output" | grep "^BONCHI_CD:" | cut -d: -f2-)
              [ -n "$cd_path" ] && cd "$cd_path"
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
