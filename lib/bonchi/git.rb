require "shellwords"

module Bonchi
  module Git
    WORKTREE_ROOT = ENV.fetch("WORKTREE_ROOT", File.join(Dir.home, "dev", "worktrees"))

    module_function

    def repo_name
      url = `git remote get-url origin 2>/dev/null`.strip
      base = url.empty? ? `git rev-parse --show-toplevel`.strip : url
      File.basename(base, ".git")
    end

    def default_base_branch
      ref = `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null`.strip
      ref.empty? ? "main" : ref.sub(%r{^refs/remotes/origin/}, "")
    end

    def main_worktree
      `git worktree list --porcelain`.lines.first.sub("worktree ", "").strip
    end

    def worktree_list
      `git worktree list`.lines.map(&:strip).reject(&:empty?)
    end

    def worktree_branches
      worktree_list.filter_map { |line| line[/\[([^\]]+)\]/, 1] }
    end

    def worktree_path_for(branch)
      line = `git worktree list`.lines.find { |l| l.include?("[#{branch}]") }
      line&.split(/\s+/)&.first
    end

    def branch_exists?(branch)
      system("git show-ref --verify --quiet refs/heads/#{branch.shellescape}") ||
        system("git show-ref --verify --quiet refs/remotes/origin/#{branch.shellescape}")
    end

    def worktree_add(path, branch)
      system("git", "worktree", "add", path, branch) || abort("Failed to add worktree")
    end

    def worktree_add_new_branch(path, branch, base)
      system("git", "worktree", "add", path, "-b", branch, base) || abort("Failed to add worktree")
    end

    def worktree_remove(path)
      system("git", "worktree", "remove", path) || abort("Failed to remove worktree")
    end

    def worktree_prune
      system("git", "worktree", "prune")
    end

    def fetch_pr(pr_number)
      system("git", "fetch", "origin", "pull/#{pr_number}/head:pr-#{pr_number}")
    end

    def worktree_dir(branch)
      File.join(WORKTREE_ROOT, repo_name, branch)
    end
  end
end
