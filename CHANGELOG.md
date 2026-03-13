## [Unreleased]

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
