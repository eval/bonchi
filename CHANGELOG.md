## [Unreleased]

## 0.6.0

### ✨ Features

- `bonchi list` — annotate worktrees with `dirty` and `merged` status, show `~` for home directory
- `bonchi remove` — automatically delete merged branches on worktree removal
- `rmf` — force-remove a worktree (and merged branch)
- `rmrf` — force-remove a worktree and delete branch regardless of merge status
- `bonchi switch -c` — create a new branch (like `git switch -c`)
- `bonchi create` falls back to existing branch instead of erroring
- `bonchi switch`, `bonchi pr` — run setup automatically when `.worktree.yml` exists
- `merged` detection checks both local and remote base branch
- Shell completions for `rmf`, `rmrf` (bash and zsh)
- `--upto STEP` for `bonchi setup` and `bonchi create` — run setup steps only up to a specific step (copy, link, ports, replace, pre_setup, setup)

## 0.5.0

### ✨ Features

- `min_version` in `.worktree.yml` — abort with upgrade message if bonchi is too old
- [GitHub attestations](https://github.com/eval/bonchi/attestations) for published gems — verify with `gem fetch bonchi -v <version> && gh attestation verify bonchi-<version>.gem --owner eval`

## 0.4.0

### ✨ Features

- `link` directive in `.worktree.yml` — symlink files/directories from the main worktree
- `bonchi remove --force` — force removal of worktrees with uncommitted changes

### 🐛 Fixes

- Ensure parent directories exist before copying/linking files
- `cd` back to main worktree after removing a worktree

## 0.3.0

### ✨ Features

- `replace` in `.worktree.yml` — regex-based find-and-replace in files with env var expansion
  - Short form (`file: [{match: replacement}]`) and full form (`match:`, `with:`, `missing:`)
  - `missing: warn` to warn instead of halt when a match isn't found
- New environment variables: `$WORKTREE_ROOT`, `$WORKTREE_BRANCH`, `$WORKTREE_BRANCH_SLUG`

### ⚠️ Breaking changes

- Renamed env var `$MAIN_WORKTREE` → `$WORKTREE_MAIN`
- Renamed env var `$WORKTREE` → `$WORKTREE_LINKED`

### 🐛 Fixes

- Warn/error on invalid `.worktree.yml` format

## 0.2.0

### ✨ Features

- `bonchi init` — generate a `.worktree.yml` template in the current project
- Global config (`~/.bonchi.yml`) for `worktree_root` setting
- Detailed help for all commands via `bonchi help <command>`
- CI workflow testing Ruby 3.3, 3.4, and head

### 📦 Changes

- Loosen minimum Ruby version to 3.1
- Fancier README with badges and nav

### 🐛 Fixes

- Fix auto-cd not changing directory after create/switch/pr

## 0.1.0

First release
