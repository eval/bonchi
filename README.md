<p align="center">
  <img src="bonchi.svg" alt="Bonchi" width="120">
</p>

<h1 align="center">Bonchi</h1>

<p align="center">
  <strong>Git worktree manager with automatic port allocation, file copying, and project setup</strong>
</p>

<p align="center">
  <a href="https://rubygems.org/gems/bonchi"><img src="https://img.shields.io/gem/v/bonchi.svg?style=flat-square&color=blue" alt="Gem Version"></a>
  <a href="https://github.com/eval/bonchi/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/eval/bonchi/ci.yml?branch=main&style=flat-square&label=CI" alt="CI Status"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-green.svg?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <a href="#install">Install</a> •
  <a href="#usage">Usage</a> •
  <a href="#project-config">Project Config</a> •
  <a href="#global-config">Global Config</a>
</p>

Inspired by [tree-me](https://github.com/haacked/dotfiles/blob/main/bin/README-tree-me.md).

## Install

```sh
gem install bonchi
```

## Setup

Add to your `~/.zshrc` or `~/.bashrc`:

```sh
source <(bonchi shellenv)
```

This gives you auto-cd (jumps into the worktree after create/switch/pr) and tab completions.

## Usage

```sh
bonchi init                       # Generate a .worktree.yml in current project
bonchi create my-feature          # New branch + worktree off default base
bonchi create my-feature develop  # New branch off develop
bonchi switch existing-branch     # Existing branch → new worktree
bonchi pr 123                     # Checkout PR #123
bonchi pr https://github.com/org/repo/pull/123
bonchi list                       # List all worktrees
bonchi remove my-feature          # Remove a worktree
bonchi prune                      # Clean up stale admin files
bonchi setup                      # Run setup in current worktree
```

Run `bonchi help <command>` for detailed info on any command.

Worktrees are created at `~/dev/worktrees/<repo>/<branch>`. Customize via global config or `WORKTREE_ROOT` env var (env var takes precedence).

## Project config

Drop a `.worktree.yml` in your project root:

```yaml
copy:
  - mise.toml
  - .env.local

ports:
  - PORT
  - WEBPACK_PORT

pre_setup:
  - mise trust
  - sed -i '' "s|^PORT=.*|PORT=$PORT|" mise.toml

setup: mise exec -- bin/setup
```

| Key | Description |
|-----|-------------|
| `copy` | Files copied from main worktree before setup |
| `ports` | Env var names — unique ports allocated from a global pool |
| `pre_setup` | Commands run before the setup command (port env vars are available) |
| `setup` | The setup command to run (default: `bin/setup`) |

`bonchi create` auto-runs setup when `.worktree.yml` exists. Skip with `--no-setup`.

## Global config

Settings are stored in `~/.bonchi.yml` (or `$XDG_CONFIG_HOME/bonchi/config.yml`):

```yaml
worktree_root: ~/worktrees

port_pool:
  min: 4000
  max: 5000
```

| Key | Description |
|-----|-------------|
| `worktree_root` | Where worktrees are created (default: `~/dev/worktrees`) |
| `port_pool.min` | Minimum port number (default: 4000) |
| `port_pool.max` | Maximum port number (default: 5000) |

Stale port allocations for removed worktrees are pruned automatically.

## Development

```bash
# Setup
bin/setup  # Make sure it exits with code 0

# Run tests
rake
```

Using [mise](https://mise.jdx.dev/) for env-vars is recommended.

### Releasing

Create a signed git tag and push:

```bash
# Regular release
git tag -s 1.2.3 -m "Release 1.2.3"

# Prerelease
git tag -s 1.2.3.rc1 -m "Release 1.2.3.rc1"

git push origin --tags

# then change version.rb for the next dev-cycle
VERSION = "1.2.4.dev"
```

CI will build, sign (Sigstore attestation), push to RubyGems, and create a GitHub release.

## License

MIT
